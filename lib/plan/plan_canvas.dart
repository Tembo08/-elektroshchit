import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plan_geometry.dart';
import 'plan_models.dart';

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

  /// Отложенные подписи групп: рисуются поверх щита и символов.
  final List<(Offset, String)> _pendingLabels = [];

  _PlanPainter({
    required this.plan,
    required this.scale,
    required this.origin,
    required this.fontFamily,
    required this.groupLabels,
    required this.showGrid,
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
    _wires(canvas);
    _devices(canvas);
    _panel(canvas);
    _roomLabels(canvas);
    _groupLabels(canvas);
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
      canvas.drawRect(
        rect,
        Paint()
          ..color = selected ? const Color(0xFF1D4ED8) : PlanInk.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2.8 : 2.2,
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

  /// Три проводника вдоль одной трассы: L, N, PE.
  ///
  /// Магистраль ведём по одной на комнату (до ближайшей к щиту точки):
  /// тянуть отдельную линию к каждой розетке — «паутина», в которой
  /// монтажник ничего не разберёт.
  void _wires(Canvas canvas) {
    const gap = 2.4;
    final colors = [PlanInk.phase, PlanInk.neutral, PlanInk.earth];

    _pendingLabels.clear();
    final byRoom = <String, List<PlanDevice>>{};
    for (final device in plan.devices) {
      byRoom.putIfAbsent(device.roomId, () => []).add(device);
    }

    for (final entry in byRoom.entries) {
      final roomDevices = entry.value;
      var nearest = roomDevices.first;
      var best = double.infinity;
      for (final device in roomDevices) {
        final length = (device.x - plan.panel.x).abs() +
            (device.y - plan.panel.y).abs();
        if (length < best) {
          best = length;
          nearest = device;
        }
      }

      final device = nearest;
      final route = PlanGeometry.route(plan, device);
      for (var i = 0; i < colors.length; i++) {
        final shift = (i - 1) * gap;
        final paint = Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        for (var p = 0; p < route.length; p++) {
          final point = _px(route[p].dx, route[p].dy);
          // Смещаем каждую жилу перпендикулярно сегменту — так три
          // разноцветные линии не сливаются в одну.
          final prev = p > 0 ? route[p - 1] : route[p];
          final next = p < route.length - 1 ? route[p + 1] : route[p];
          final horizontal = (next.dx - prev.dx).abs() >= (next.dy - prev.dy).abs();
          final offset = horizontal ? Offset(0, shift) : Offset(shift, 0);
          if (p == 0) {
            path.moveTo(point.dx + offset.dx, point.dy + offset.dy);
          } else {
            path.lineTo(point.dx + offset.dx, point.dy + offset.dy);
          }
        }
        canvas.drawPath(path, paint);
      }

      // Номер группы — у магистрали (в коридоре). Саму подпись рисуем
      // последним проходом: иначе её закрывает символ щита.
      final label = groupLabels[entry.key];
      if (label == null || label.isEmpty) continue;
      final corridor = plan.corridorY;
      final anchor = corridor != null
          ? _px(device.x, corridor)
          : _px(nearest.x, nearest.y);
      _pendingLabels.add((anchor, 'Гр. $label'));
    }
  }

  /// Подписи групп: тонкая выноска под 45° и номер справа.
  ///
  /// Номера выравниваем по одной вертикали со ступенькой — так 20+ номеров
  /// не наезжают друг на друга (приём из ТЗ проектировщика).
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

      // Ступенька, чтобы соседние номера не сливались.
      final step = (i % 4) * 7.0;
      final end = anchor + Offset(10, -10 - step);
      canvas.drawLine(anchor, end, leader);

      final box = Rect.fromLTWH(
        end.dx + 1,
        end.dy - painter.height / 2,
        painter.width + 3,
        painter.height,
      );
      canvas.drawRect(box, Paint()..color = Colors.white);
      painter.paint(canvas, box.topLeft + const Offset(1.5, 0));
    }
  }

  /// УГО по ГОСТ: розетка — полукруг с двумя штрихами, свет — кружок с
  /// крестом, мощный прибор — кружок в кольце.
  void _devices(Canvas canvas) {
    final ink = Paint()
      ..color = PlanInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9;

    for (final device in plan.devices) {
      final p = _px(device.x, device.y);
      final selected = device.id == selectedDeviceId;
      final r = selected ? 7.0 : 5.5;

      // Белый ореол: символы читаются поверх трасс.
      canvas.drawCircle(p, r + 3.2, Paint()..color = Colors.white);
      if (selected) {
        canvas.drawCircle(
          p,
          r + 5,
          Paint()..color = const Color(0xFF1D4ED8).withValues(alpha: 0.15),
        );
      }

      switch (device.type) {
        case PlanPointType.socket:
          // полукруг на стене + две насечки внутрь помещения
          canvas.drawArc(
            Rect.fromCircle(center: p, radius: r),
            math.pi,
            math.pi,
            false,
            ink,
          );
          canvas.drawLine(p + Offset(-r, 0), p + Offset(r, 0), ink);
          canvas.drawLine(
              p + Offset(-r * 0.45, 0), p + Offset(-r * 0.45, -r * 1.1), ink);
          canvas.drawLine(
              p + Offset(r * 0.45, 0), p + Offset(r * 0.45, -r * 1.1), ink);
        case PlanPointType.light:
          canvas.drawCircle(p, r, ink);
          canvas.drawLine(
              p + Offset(-r, -r) * 0.72, p + Offset(r, r) * 0.72, ink);
          canvas.drawLine(
              p + Offset(-r, r) * 0.72, p + Offset(r, -r) * 0.72, ink);
        case PlanPointType.switchPoint:
          // отрезок с наклонной насечкой под 45° — как на образце
          canvas.drawLine(p + Offset(-r, 0), p + Offset(r, 0), ink);
          canvas.drawLine(
              p + Offset(r * 0.55, 0), p + Offset(-r * 0.1, -r * 1.5), ink);
        case PlanPointType.powerful:
          canvas.drawCircle(p, r, ink);
          canvas.drawCircle(p, r + 2.5, ink);
      }
    }
  }

  void _panel(Canvas canvas) {
    final rect = Rect.fromCenter(
      center: _px(plan.panel.x, plan.panel.y),
      width: PlanPanel.widthM * scale,
      height: PlanPanel.heightM * scale,
    );
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(
      rect,
      Paint()
        ..color = PlanInk.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.bottomRight,
      Paint()
        ..color = PlanInk.ink
        ..strokeWidth = 1.4,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'Щит',
        style: TextStyle(
          color: PlanInk.ink,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(rect.center.dx - label.width / 2, rect.bottom + 2),
    );

    if (panelNote != null && panelNote!.isNotEmpty) {
      final note = TextPainter(
        text: TextSpan(
          text: panelNote,
          style: TextStyle(
            color: PlanInk.inkSoft,
            fontSize: 7,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      note.paint(
        canvas,
        Offset(rect.center.dx - note.width / 2, rect.bottom + 2 + label.height),
      );
    }
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
      old.showGrid != showGrid;
}
