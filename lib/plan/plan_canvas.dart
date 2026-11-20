import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plan_geometry.dart';
import 'plan_models.dart';
import 'plan_walls.dart';

/// Какая грань комнаты тянется.
enum PlanEdge { left, right, top, bottom, corner }

/// Режим работы пальца в редакторе.
enum PlanTool { rooms, points, panel }

/// Цвета чертежа: белый лист, чёрные линии, проводники по ПУЭ.
class PlanInk {
  static const sheet = Color(0xFFFFFFFF);
  static const grid = Color(0xFFE8EBEF);
  static const gridBold = Color(0xFFD5DAE1);
  static const ink = Color(0xFF111827);
  static const inkSoft = Color(0xFF4B5563);
  static const phase = Color(0xFFD32F2F); // L — красный
  static const neutral = Color(0xFF1565C0); // N — синий
  static const earth = Color(0xFF7CB342); // PE — жёлто-зелёный

  /// Цвета групп: одна линия на группу, как на бытовых планах.
  static const group = [
    Color(0xFF00ACC1), // голубая
    Color(0xFFE91E63), // розовая
    Color(0xFFD32F2F), // красная
    Color(0xFF1565C0), // синяя
    Color(0xFF43A047), // зелёная
    Color(0xFFFB8C00), // оранжевая
  ];
}

/// Чертим план как схему: белый лист, чёрные контуры, УГО точек и
/// трёхцветные линии (фаза, ноль, земля).
class PlanCanvas extends StatelessWidget {
  final FloorPlan plan;
  final PlanTool tool;
  final String? selectedRoomId;
  final String? selectedDeviceId;

  /// Номера групп по комнатам: roomId → «1, 2» (для подписи у трассы).
  final Map<String, String> groupLabels;

  /// Подпись под щитом: «ввод 25 А» — чтобы на плане был виден ввод (Гр.1).
  final String? panelNote;

  /// Сетка нужна в редакторе (привязка), но на монтажном листе это шум.
  final bool showGrid;

  /// Электрика: на этапе геометрии щит и точки скрыты.
  final bool showElectrical;

  final void Function(Offset meters) onTap;
  final void Function(String roomId, PlanEdge? edge) onRoomGrab;
  final void Function(String roomId, Offset pointMeters) onRoomDragTo;
  final void Function(String roomId) onRoomDrop;
  final void Function(String deviceId) onDeviceGrab;
  final void Function(String deviceId, Offset pointMeters) onDeviceDragTo;
  final void Function(Offset meters) onPanelDragTo;
  final void Function(String roomId) onSelectRoom;
  final void Function(String deviceId) onSelectDevice;

  const PlanCanvas({
    super.key,
    required this.plan,
    required this.tool,
    required this.onTap,
    required this.onRoomGrab,
    required this.onRoomDragTo,
    required this.onRoomDrop,
    required this.onDeviceGrab,
    required this.onDeviceDragTo,
    required this.onPanelDragTo,
    required this.onSelectRoom,
    required this.onSelectDevice,
    this.selectedRoomId,
    this.selectedDeviceId,
    this.groupLabels = const {},
    this.panelNote,
    this.showGrid = true,
    this.showElectrical = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          (constraints.maxWidth - 20) / plan.widthM,
          (constraints.maxHeight - 20) / plan.heightM,
        );
        final offset = Offset(
          (constraints.maxWidth - plan.widthM * scale) / 2,
          (constraints.maxHeight - plan.heightM * scale) / 2,
        );
        // TextPainter не наследует тему — семейство шрифта передаём явно,
        // иначе подписи комнат рисуются квадратами.
        final fontFamily =
            Theme.of(context).textTheme.bodyMedium?.fontFamily;

        Offset toMeters(Offset pixels) => Offset(
              (pixels.dx - offset.dx) / scale,
              (pixels.dy - offset.dy) / scale,
            );

        // Что схватили: грань комнаты, саму комнату, точку или щит.
        String? grabbedRoom;
        PlanEdge? grabbedEdge;
        String? grabbedDevice;

        void grab(Offset meters) {
          grabbedRoom = null;
          grabbedEdge = null;
          grabbedDevice = null;

          if (tool == PlanTool.points) {
            final device = PlanGeometry.deviceAt(plan, meters.dx, meters.dy);
            if (device != null) {
              grabbedDevice = device.id;
              onSelectDevice(device.id);
              return;
            }
            return;
          }
          if (tool != PlanTool.rooms) return;

          final room = PlanGeometry.roomAt(plan, meters.dx, meters.dy);
          if (room == null) return;
          onSelectRoom(room.id);
          grabbedRoom = room.id;
          grabbedEdge = _edgeAt(room.rect, meters, scale);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final meters = toMeters(details.localPosition);
            if (tool == PlanTool.points) {
              final device = PlanGeometry.deviceAt(plan, meters.dx, meters.dy);
              if (device != null) {
                onSelectDevice(device.id);
                return;
              }
            }
            if (tool == PlanTool.rooms) {
              final room = PlanGeometry.roomAt(plan, meters.dx, meters.dy);
              if (room != null) {
                onSelectRoom(room.id);
                return;
              }
            }
            onTap(meters);
          },
          onPanStart: (details) {
            final meters = toMeters(details.localPosition);
            grab(meters);
            if (grabbedDevice != null) onDeviceGrab(grabbedDevice!);
            if (grabbedRoom != null) onRoomGrab(grabbedRoom!, grabbedEdge);
          },
          onPanUpdate: (details) {
            final meters = toMeters(details.localPosition);
            if (tool == PlanTool.panel) {
              onPanelDragTo(meters);
              return;
            }
            if (grabbedDevice != null) {
              onDeviceDragTo(grabbedDevice!, meters);
              return;
            }
            if (grabbedRoom != null) {
              onRoomDragTo(grabbedRoom!, meters);
            }
          },
          onPanEnd: (_) {
            if (grabbedRoom != null) onRoomDrop(grabbedRoom!);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _PlanPainter(
              plan: plan,
              scale: scale,
              origin: offset,
              fontFamily: fontFamily,
              groupLabels: groupLabels,
              panelNote: panelNote,
              showGrid: showGrid,
              showElectrical: showElectrical,
              selectedRoomId: selectedRoomId,
              selectedDeviceId: selectedDeviceId,
            ),
          ),
        );
      },
    );
  }

  /// Какая грань под пальцем: допуск 0.3 м, чтобы «взять за линию».
  PlanEdge? _edgeAt(PlanRect rect, Offset meters, double scale) {
    const tolerance = 0.35;
    final nearLeft = (meters.dx - rect.left).abs() < tolerance;
    final nearRight = (meters.dx - rect.right).abs() < tolerance;
    final nearTop = (meters.dy - rect.top).abs() < tolerance;
    final nearBottom = (meters.dy - rect.bottom).abs() < tolerance;
    final insideY = meters.dy >= rect.top - tolerance &&
        meters.dy <= rect.bottom + tolerance;
    final insideX = meters.dx >= rect.left - tolerance &&
        meters.dx <= rect.right + tolerance;

    if ((nearRight && nearBottom) || (nearLeft && nearBottom)) {
      return PlanEdge.corner;
    }
    if (nearLeft && insideY) return PlanEdge.left;
    if (nearRight && insideY) return PlanEdge.right;
    if (nearTop && insideX) return PlanEdge.top;
    if (nearBottom && insideX) return PlanEdge.bottom;
    return null;
  }
}

class _PlanPainter extends CustomPainter {
  final FloorPlan plan;
  final double scale;
  final Offset origin;
  final String? selectedRoomId;
  final String? selectedDeviceId;
  final String? fontFamily;
  final Map<String, String> groupLabels;
  final String? panelNote;
  final bool showGrid;
  final bool showElectrical;

  /// Отложенные подписи групп: рисуются поверх щита и символов.
  final List<(Offset, String)> _pendingLabels = [];

  _PlanPainter({
    required this.plan,
    required this.scale,
    required this.origin,
    required this.fontFamily,
    required this.groupLabels,
    required this.showGrid,
    required this.showElectrical,
    this.panelNote,
    this.selectedRoomId,
    this.selectedDeviceId,
  });

  Offset _px(double x, double y) =>
      Offset(origin.dx + x * scale, origin.dy + y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    _sheet(canvas);
    if (showGrid) _grid(canvas);
    _rooms(canvas);
    if (showElectrical) {
      _wires(canvas);
      _devices(canvas);
    }
    _walls(canvas);
    _openings(canvas);
    if (showElectrical) _panel(canvas);
    if (showElectrical) {
      _roomLabels(canvas);
      _groupLabels(canvas);
    } else {
      _roomLabels(canvas);
    }
    _scaleBar(canvas);
  }

  void _sheet(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, plan.widthM * scale,
          plan.heightM * scale),
      Paint()..color = PlanInk.sheet,
    );
  }

  void _grid(Canvas canvas) {
    final thin = Paint()
      ..color = PlanInk.grid
      ..strokeWidth = 1;
    final bold = Paint()
      ..color = PlanInk.gridBold
      ..strokeWidth = 1;

    for (var x = 0.0; x <= plan.widthM + 0.001; x += 0.5) {
      final meter = (x - x.roundToDouble()).abs() < 0.001;
      canvas.drawLine(_px(x, 0), _px(x, plan.heightM), meter ? bold : thin);
    }
    for (var y = 0.0; y <= plan.heightM + 0.001; y += 0.5) {
      final meter = (y - y.roundToDouble()).abs() < 0.001;
      canvas.drawLine(_px(0, y), _px(plan.widthM, y), meter ? bold : thin);
    }

    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, plan.widthM * scale,
          plan.heightM * scale),
      Paint()
        ..color = PlanInk.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _rooms(Canvas canvas) {
    for (final room in plan.rooms) {
      final rect = Rect.fromLTWH(
        origin.dx + room.rect.left * scale,
        origin.dy + room.rect.top * scale,
        room.rect.width * scale,
        room.rect.height * scale,
      );
      final selected = room.id == selectedRoomId;

      canvas.drawRect(
        rect,
        Paint()..color = selected
            ? const Color(0xFFEFF6FF)
            : Colors.white,
      );
      // стена «толщиной»: две линии — внешняя и внутренняя
      canvas.drawRect(
        rect,
        Paint()
          ..color = selected ? const Color(0xFF1D4ED8) : PlanInk.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 7.0 : 6.0,
      );
      canvas.drawRect(
        rect.deflate(2.6),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );

    }
  }

  /// Названия комнат — отдельным проходом поверх символов и трасс.
  void _roomLabels(Canvas canvas) {
    for (final room in plan.rooms) {
      final rect = Rect.fromLTWH(
        origin.dx + room.rect.left * scale,
        origin.dy + room.rect.top * scale,
        room.rect.width * scale,
        room.rect.height * scale,
      );
      if (rect.width < 30 || rect.height < 16) continue;

      final painter = TextPainter(
        text: TextSpan(
          text: room.name,
          style: TextStyle(
            color: PlanInk.ink,
            fontSize: 9.5,
            height: 1.1,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(20, rect.width - 10));

      var plate = Rect.fromLTWH(
        rect.left + 2,
        rect.top + 2,
        painter.width + 6,
        painter.height + 3,
      );

      // Если на этом месте стоит значок щита — сдвигаем подпись ниже,
      // иначе первая буква названия теряется под щитом.
      final panelRect = Rect.fromCenter(
        center: _px(plan.panel.x, plan.panel.y),
        width: PlanPanel.widthM * scale,
        height: PlanPanel.heightM * scale,
      ).inflate(4);
      if (plate.overlaps(panelRect)) {
        plate = plate.translate(0, panelRect.bottom - plate.top + 3);
      }

      canvas.drawRect(plate, Paint()..color = Colors.white);
      painter.paint(canvas, plate.topLeft + const Offset(3, 1.5));
    }
  }

  /// Одна цветная линия на группу, только по стенам и вертикалям.
  ///
  /// Раньше соседние точки соединялись напрямую — получались диагонали
  /// через комнату. Теперь: магистраль по коридору → вдоль стены → отвод
  /// вверх к светильнику.
  void _wires(Canvas canvas) {
    _pendingLabels.clear();
    final byRoom = <String, List<PlanDevice>>{};
    for (final device in plan.devices) {
      byRoom.putIfAbsent(device.roomId, () => []).add(device);
    }

    final rooms = {for (final r in plan.rooms) r.id: r};
    var colorIndex = 0;
    final wallOffset = 0.12;

    for (final entry in byRoom.entries) {
      final room = rooms[entry.key];
      final devices = [...entry.value];
      if (room == null || devices.isEmpty) continue;

      final color = PlanInk.group[colorIndex % PlanInk.group.length];
      colorIndex++;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      // Стена, вдоль которой идёт группа: низ комнаты.
      final wallY = room.rect.bottom - wallOffset;
      final sockets = devices
          .where((d) => d.type == PlanPointType.socket ||
              d.type == PlanPointType.switchPoint)
          .toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      final others = devices
          .where((d) => d.type == PlanPointType.light ||
              d.type == PlanPointType.powerful)
          .toList();

      final entryX = sockets.isNotEmpty ? sockets.first.x : room.rect.left + 0.3;

      // магистраль: щит → коридор → стена комнаты
      final path = Path();
      final start = _px(plan.panel.x + PlanPanel.widthM / 2 + 0.08, plan.panel.y);
      final corridor = _px(plan.panel.x, plan.corridorY ?? plan.panel.y);
      final alongCorridor = _px(entryX, plan.corridorY ?? plan.panel.y);
      final onWall = _px(entryX, wallY);
      path.moveTo(start.dx, start.dy);
      path.lineTo(corridor.dx, corridor.dy);
      path.lineTo(alongCorridor.dx, alongCorridor.dy);
      path.lineTo(onWall.dx, onWall.dy);
      canvas.drawPath(path, paint);

      // вдоль стены через все розетки и выключатели
      if (sockets.length > 1) {
        final left = _px(sockets.first.x, wallY);
        final right = _px(sockets.last.x, wallY);
        canvas.drawLine(left, right, paint);
      }

      // отводы вверх к светильникам и мощным приборам
      for (final device in others) {
        final from = _px(device.x, wallY);
        final to = _px(device.x, device.y);
        canvas.drawLine(from, to, paint);
      }

      final label = groupLabels[entry.key];
      if (label != null && label.isNotEmpty) {
        _pendingLabels.add((onWall, 'Гр. $label'));
      }
    }
  }

  /// Линейка масштаба: отрезок 1 м с подписью — чтобы читался размер.
  void _scaleBar(Canvas canvas) {
    final y = origin.dy + plan.heightM * scale + 12;
    final x0 = origin.dx + 4;
    final x1 = x0 + scale;
    final paint = Paint()
      ..color = PlanInk.ink
      ..strokeWidth = 1.6;

    canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
    canvas.drawLine(Offset(x0, y - 4), Offset(x0, y + 4), paint);
    canvas.drawLine(Offset(x1, y - 4), Offset(x1, y + 4), paint);

    final label = TextPainter(
      text: TextSpan(
        text: '1 м',
        style: TextStyle(
          color: PlanInk.ink,
          fontSize: 8,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(x1 + 4, y - label.height / 2));
  }

  /// Стены с толщиной: залитые прямоугольники, стыки перекрываются.
  void _walls(Canvas canvas) {
    if (plan.walls.isEmpty) return;
    final fill = Paint()..color = PlanInk.ink;

    for (final wall in plan.walls) {
      final r = wall.rect;
      canvas.drawRect(
        Rect.fromLTWH(
          origin.dx + r.left * scale,
          origin.dy + r.top * scale,
          r.width * scale,
          r.height * scale,
        ),
        fill,
      );
    }
  }

  /// Проёмы: вырезаем участок стены, двери — с дугой, окна — двумя линиями.
  void _openings(Canvas canvas) {
    if (plan.openings.isEmpty) return;

    final wall = PlanWalls.thickness * scale;
    final ink = Paint()
      ..color = PlanInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final opening in plan.openings) {
      final a = _px(opening.a.dx, opening.a.dy);
      final b = _px(opening.b.dx, opening.b.dy);
      final wipeWidth = wall + 2;

      // вырезаем проём
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Colors.white
          ..strokeWidth = wipeWidth,
      );

      switch (opening.type) {
        case PlanOpeningType.door:
        case PlanOpeningType.entry:
          final radius = (b - a).distance;
          if (opening.type == PlanOpeningType.entry) {
            canvas.drawLine(
              a,
              b,
              Paint()
                ..color = PlanInk.ink
                ..strokeWidth = 2.2,
            );
          }
          canvas.drawArc(
            Rect.fromCircle(center: a, radius: radius),
            opening.horizontal ? math.pi / 2 : 0,
            math.pi / 2,
            false,
            ink,
          );
        case PlanOpeningType.window:
          // окно: две линии по краям проёма и линия остекления посередине
          final normal =
              opening.horizontal ? const Offset(0, 1) : const Offset(1, 0);
          final paint = Paint()
            ..color = PlanInk.ink
            ..strokeWidth = 1.1;
          canvas.drawLine(a, b, paint);
          canvas.drawLine(
            a - normal * wall / 2,
            b - normal * wall / 2,
            paint,
          );
          canvas.drawLine(
            a + normal * wall / 2,
            b + normal * wall / 2,
            paint,
          );
      }
    }
  }

  /// Номера групп: тонкая выноска от трассы + номер, со ступенькой.
  void _groupLabels(Canvas canvas) {
    final leader = Paint()
      ..color = PlanInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var i = 0; i < _pendingLabels.length; i++) {
      final (anchor, text) = _pendingLabels[i];
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: PlanInk.ink,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final step = (i % 4) * 7.0;
      final end = anchor + Offset(9, 9 + step);
      canvas.drawLine(anchor, end, leader);

      final box = Rect.fromLTWH(
        end.dx - painter.width / 2,
        end.dy + 1,
        painter.width + 3,
        painter.height,
      );
      canvas.drawRect(box, Paint()..color = Colors.white);
      painter.paint(canvas, box.topLeft + const Offset(1.5, 0));
    }
  }

  /// УГО как на бытовом плане: розетка — кружок с двумя контактами и дугой,
  /// светильник — кружок с крестом, выключатель — отрезок с точками и
  /// наклонной чертой. Размеры привязаны к масштабу листа (≈2.5 % ширины).
  void _devices(Canvas canvas) {
    final ink = Paint()
      ..color = PlanInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    for (final device in plan.devices) {
      final p = _px(device.x, device.y);
      final r = 0.115 * scale; // ≈2.5 % ширины листа в диаметре
      final selected = device.id == selectedDeviceId;

      // Белая подложка: символ не сливается с трассами.
      canvas.drawCircle(p, r + 2, Paint()..color = Colors.white);
      if (selected) {
        canvas.drawCircle(
          p,
          r + 5,
          Paint()..color = const Color(0xFF1D4ED8).withValues(alpha: 0.15),
        );
      }

      switch (device.type) {
        case PlanPointType.socket:
          canvas.drawCircle(p, r, ink);
          // две точки-контакта
          canvas.drawCircle(p + Offset(-r * 0.35, 0), r * 0.13,
              Paint()..color = PlanInk.ink);
          canvas.drawCircle(p + Offset(r * 0.35, 0), r * 0.13,
              Paint()..color = PlanInk.ink);
          // дуга «личиком» вверх
          canvas.drawArc(
            Rect.fromCircle(center: p + Offset(0, r * 0.08), radius: r * 0.62),
            3.5,
            2.3,
            false,
            ink,
          );
        case PlanPointType.light:
          canvas.drawCircle(p, r, ink);
          canvas.drawLine(
              p + Offset(-r * 0.62, -r * 0.62), p + Offset(r * 0.62, r * 0.62), ink);
          canvas.drawLine(
              p + Offset(-r * 0.62, r * 0.62), p + Offset(r * 0.62, -r * 0.62), ink);
        case PlanPointType.switchPoint:
          // отрезок от стены, две точки и наклонная черта
          canvas.drawLine(p + Offset(-r * 1.4, 0), p + Offset(r * 0.2, 0), ink);
          canvas.drawCircle(p + Offset(-r * 1.4, 0), r * 0.12,
              Paint()..color = PlanInk.ink);
          canvas.drawCircle(p, r * 0.12, Paint()..color = PlanInk.ink);
          canvas.drawLine(
              p + Offset(r * 0.2, 0), p + Offset(r * 0.9, -r * 0.9), ink);
        case PlanPointType.powerful:
          canvas.drawCircle(p, r, ink);
          canvas.drawCircle(p, r * 0.55, ink);
      }
    }
  }

  /// Щит ВНЕ квартиры: пунктирная рамка, модули-автоматы, подпись ввода.
  void _panel(Canvas canvas) {
    final w = PlanPanel.widthM * scale;
    final h = PlanPanel.heightM * scale;
    final rect = Rect.fromCenter(
      center: _px(plan.panel.x, plan.panel.y),
      width: w,
      height: h,
    );

    // пунктирная рамка
    final dash = Paint()
      ..color = PlanInk.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final frame = rect.inflate(scale * 0.18);
    _dashedRect(canvas, frame, dash);

    // корпус щита
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(
      rect,
      Paint()
        ..color = PlanInk.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // модули-автоматы: три деления
    final moduleW = rect.width / 3;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(rect.left + moduleW * i, rect.top),
        Offset(rect.left + moduleW * i, rect.bottom),
        Paint()
          ..color = PlanInk.ink
          ..strokeWidth = 1,
      );
    }
    // тумблеры
    for (var i = 0; i < 3; i++) {
      final cx = rect.left + moduleW * (i + 0.5);
      canvas.drawLine(
        Offset(cx, rect.top + rect.height * 0.25),
        Offset(cx, rect.top + rect.height * 0.6),
        Paint()
          ..color = PlanInk.ink
          ..strokeWidth = 2,
      );
    }

    final label = TextPainter(
      text: TextSpan(
        text: panelNote ?? 'Щит',
        style: TextStyle(
          color: PlanInk.ink,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(rect.center.dx - label.width / 2, frame.bottom + 2),
    );
  }

  /// Пунктирная рамка вокруг щита.
  void _dashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var t = 0.0;
      while (t < total) {
        final end = math.min(t + dash, total);
        canvas.drawLine(a + dir * t, a + dir * end, paint);
        t = end + gap;
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }


  @override
  bool shouldRepaint(covariant _PlanPainter old) =>
      old.plan != plan ||
      old.scale != scale ||
      old.origin != origin ||
      old.selectedRoomId != selectedRoomId ||
      old.selectedDeviceId != selectedDeviceId ||
      old.fontFamily != fontFamily ||
      old.groupLabels != groupLabels ||
      old.panelNote != panelNote ||
      old.showGrid != showGrid ||
      old.showElectrical != showElectrical;
}
