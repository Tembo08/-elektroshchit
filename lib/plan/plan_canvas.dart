import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'plan_geometry.dart';
import 'plan_models.dart';

/// Что делает палец в редакторе плана.
enum PlanTool { rooms, points, panel }

/// Канвас плана: сетка, комнаты, точки, щит и линии от щита.
///
/// Рисуем вручную через CustomPainter: так проще держать попадания и
/// перетаскивание под контролем, чем собирать это из виджетов.
class PlanCanvas extends StatelessWidget {
  final FloorPlan plan;
  final PlanTool tool;
  final String? selectedRoomId;
  final String? selectedDeviceId;
  final void Function(Offset meters) onTap;
  final void Function(String roomId, Offset deltaMeters) onRoomDrag;
  final void Function(String roomId, Offset cornerMeters) onRoomResize;
  final void Function(String deviceId, Offset meters) onDeviceDrag;
  final void Function(Offset meters) onPanelDrag;
  final void Function(String roomId) onSelectRoom;
  final void Function(String deviceId) onSelectDevice;

  const PlanCanvas({
    super.key,
    required this.plan,
    required this.tool,
    required this.onTap,
    required this.onRoomDrag,
    required this.onRoomResize,
    required this.onDeviceDrag,
    required this.onPanelDrag,
    required this.onSelectRoom,
    required this.onSelectDevice,
    this.selectedRoomId,
    this.selectedDeviceId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // План вписываем в доступное место с полями; масштаб — пиксели на метр.
        final scale = math.min(
          (constraints.maxWidth - 24) / plan.widthM,
          (constraints.maxHeight - 24) / plan.heightM,
        );
        final offset = Offset(
          (constraints.maxWidth - plan.widthM * scale) / 2,
          (constraints.maxHeight - plan.heightM * scale) / 2,
        );

        Offset toPixels(Offset meters) => Offset(
              offset.dx + meters.dx * scale,
              offset.dy + meters.dy * scale,
            );
        Offset toMeters(Offset pixels) => Offset(
              (pixels.dx - offset.dx) / scale,
              (pixels.dy - offset.dy) / scale,
            );

        return GestureDetector(
          onTapDown: (details) {
            final m = toMeters(details.localPosition);
            if (tool == PlanTool.points) {
              final device = PlanGeometry.deviceAt(plan, m.dx, m.dy);
              if (device != null) {
                onSelectDevice(device.id);
                return;
              }
            }
            if (tool == PlanTool.rooms) {
              final room = PlanGeometry.roomAt(plan, m.dx, m.dy);
              if (room != null) {
                onSelectRoom(room.id);
                return;
              }
            }
            onTap(m);
          },
          onPanStart: (details) {
            final m = toMeters(details.localPosition);
            if (tool == PlanTool.points) {
              final device = PlanGeometry.deviceAt(plan, m.dx, m.dy);
              if (device != null) {
                onSelectDevice(device.id);
                return;
              }
            }
            final room = PlanGeometry.roomAt(plan, m.dx, m.dy);
            if (room != null && tool == PlanTool.rooms) onSelectRoom(room.id);
          },
          onPanUpdate: (details) {
            final delta = details.delta / scale;
            if (tool == PlanTool.panel) {
              onPanelDrag(toMeters(details.localPosition));
              return;
            }
            if (tool == PlanTool.points && selectedDeviceId != null) {
              onDeviceDrag(selectedDeviceId!, toMeters(details.localPosition));
              return;
            }
            if (tool == PlanTool.rooms && selectedRoomId != null) {
              onRoomDrag(selectedRoomId!, delta);
            }
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _PlanPainter(
                  plan: plan,
                  scale: scale,
                  origin: offset,
                  scheme: scheme,
                  selectedRoomId: selectedRoomId,
                  selectedDeviceId: selectedDeviceId,
                ),
              ),
              // маркер «угол комнаты» для изменения размера
              if (tool == PlanTool.rooms && selectedRoomId != null)
                ..._resizeHandle(context, toPixels, scale),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _resizeHandle(
    BuildContext context,
    Offset Function(Offset) toPixels,
    double scale,
  ) {
    final room = plan.rooms.where((r) => r.id == selectedRoomId).firstOrNull;
    if (room == null) return const [];
    final corner = toPixels(Offset(room.rect.right, room.rect.bottom));
    return [
      Positioned(
        left: corner.dx - 18,
        top: corner.dy - 18,
        child: GestureDetector(
          onPanUpdate: (details) {
            onRoomResize(
              room.id,
              Offset(
                room.rect.right + details.delta.dx / scale,
                room.rect.bottom + details.delta.dy / scale,
              ),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(Icons.open_in_full, size: 18, color: Colors.white),
          ),
        ),
      ),
    ];
  }
}

class _PlanPainter extends CustomPainter {
  final FloorPlan plan;
  final double scale;
  final Offset origin;
  final ColorScheme scheme;
  final String? selectedRoomId;
  final String? selectedDeviceId;

  _PlanPainter({
    required this.plan,
    required this.scale,
    required this.origin,
    required this.scheme,
    this.selectedRoomId,
    this.selectedDeviceId,
  });

  Offset _px(double x, double y) =>
      Offset(origin.dx + x * scale, origin.dy + y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSheet(canvas);
    _drawGrid(canvas, size);
    _drawRooms(canvas);
    _drawWires(canvas);
    _drawDevices(canvas);
    _drawPanel(canvas);
  }

  void _drawSheet(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF12161C);
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, plan.widthM * scale,
          plan.heightM * scale),
      paint,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;

    // сетка по 0.5 м, каждая вторая линия — ярче (метр)
    for (var x = 0.0; x <= plan.widthM + 0.001; x += 0.5) {
      final isMeter = (x - x.roundToDouble()).abs() < 0.001;
      canvas.drawLine(_px(x, 0), _px(x, plan.heightM), isMeter ? thick : thin);
    }
    for (var y = 0.0; y <= plan.heightM + 0.001; y += 0.5) {
      final isMeter = (y - y.roundToDouble()).abs() < 0.001;
      canvas.drawLine(_px(0, y), _px(plan.widthM, y), isMeter ? thick : thin);
    }

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, plan.widthM * scale,
          plan.heightM * scale),
      border,
    );
  }

  void _drawRooms(Canvas canvas) {
    for (final room in plan.rooms) {
      final rect = Rect.fromLTWH(
        origin.dx + room.rect.left * scale,
        origin.dy + room.rect.top * scale,
        room.rect.width * scale,
        room.rect.height * scale,
      );
      final selected = room.id == selectedRoomId;
      final fill = Paint()
        ..color = (selected ? scheme.primary : scheme.surfaceContainerHigh)
            .withValues(alpha: selected ? 0.22 : 0.55);
      final stroke = Paint()
        ..color = selected ? scheme.primary : Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 1.5;

      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);

      // название и площадь
      final label = '${room.name}\n${room.rect.area.toStringAsFixed(1)} м²';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: rect.width - 8);
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.center.dy - painter.height / 2,
        ),
      );
    }
  }

  void _drawWires(Canvas canvas) {
    final wire = Paint()
      ..color = const Color(0xFFD64545).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final device in plan.devices) {
      final points = PlanGeometry.route(plan, device);
      final path = Path()..moveTo(_px(points.first.dx, points.first.dy).dx,
          _px(points.first.dx, points.first.dy).dy);
      for (final p in points.skip(1)) {
        final px = _px(p.dx, p.dy);
        path.lineTo(px.dx, px.dy);
      }
      canvas.drawPath(path, wire);
    }
  }

  void _drawDevices(Canvas canvas) {
    for (final device in plan.devices) {
      final p = _px(device.x, device.y);
      final selected = device.id == selectedDeviceId;
      final (color, radius) = switch (device.type) {
        PlanPointType.socket => (const Color(0xFF4CE89E), 5.0),
        PlanPointType.light => (const Color(0xFFFFD166), 5.0),
        PlanPointType.powerful => (const Color(0xFFFF8C42), 6.0),
      };

      if (device.type == PlanPointType.light) {
        // свет — кружок с крестом, как на схемах
        canvas.drawCircle(p, radius + (selected ? 4 : 2),
            Paint()..color = color.withValues(alpha: selected ? 0.35 : 0.18));
        canvas.drawCircle(
            p, radius, Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawLine(p - Offset(radius, 0), p + Offset(radius, 0),
            Paint()..color = color..strokeWidth = 1.5);
        canvas.drawLine(p - Offset(0, radius), p + Offset(0, radius),
            Paint()..color = color..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(p, radius + (selected ? 5 : 2),
            Paint()..color = color.withValues(alpha: selected ? 0.35 : 0.15));
        canvas.drawCircle(p, radius, Paint()..color = color);
        if (device.type == PlanPointType.powerful) {
          canvas.drawCircle(
              p, radius + 3,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
        }
      }
    }
  }

  void _drawPanel(Canvas canvas) {
    final w = PlanPanel.widthM * scale;
    final h = PlanPanel.heightM * scale;
    final rect = Rect.fromCenter(
      center: _px(plan.panel.x, plan.panel.y),
      width: w,
      height: h,
    );

    // обозначение щита как на схемах: прямоугольник с диагональю,
    // залитая половина и подпись «Щит»
    canvas.drawRect(rect, Paint()..color = const Color(0xFF35E6FF));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF0B0F14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.bottom);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B0F14)
        ..strokeWidth = 2,
    );

    final painter = TextPainter(
      text: const TextSpan(
        text: 'Щит',
        style: TextStyle(
          color: Color(0xFF35E6FF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.bottom + 4),
    );
  }

  @override
  bool shouldRepaint(covariant _PlanPainter old) =>
      old.plan != plan ||
      old.scale != scale ||
      old.origin != origin ||
      old.selectedRoomId != selectedRoomId ||
      old.selectedDeviceId != selectedDeviceId;
}
