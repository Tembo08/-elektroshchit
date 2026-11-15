import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Стилизованный щит: корпус, вводной автомат, реле напряжения, счётчик,
/// две DIN-рейки с УЗО и автоматами, шины N (синяя) и PE (жёлто-зелёная),
/// провода фаз. Всё рисуется кодом — работает в светлой и тёмной теме.
class PanelIllustration extends StatelessWidget {
  final double width;

  /// Насколько подробно рисовать провода и подписи.
  final bool detailed;

  const PanelIllustration({
    super.key,
    this.width = 240,
    this.detailed = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: width * 1.18,
      child: CustomPaint(
        painter: _PanelPainter(
          dark: scheme.brightness == Brightness.dark,
          accent: scheme.primary,
          detailed: detailed,
        ),
      ),
    );
  }
}

class _PanelPainter extends CustomPainter {
  final bool dark;
  final Color accent;
  final bool detailed;

  _PanelPainter({
    required this.dark,
    required this.accent,
    required this.detailed,
  });

  // Цвета
  Color get _body => dark ? const Color(0xFF20242B) : const Color(0xFFF4F6FA);
  Color get _edge => dark ? const Color(0xFF3B424C) : const Color(0xFF9AA4B2);
  Color get _moduleColor =>
      dark ? const Color(0xFF2C323B) : const Color(0xFFE3E8F0);
  Color get _moduleEdge =>
      dark ? const Color(0xFF454D59) : const Color(0xFFB6BFCC);
  Color get _slot => dark ? const Color(0xFF4A5360) : const Color(0xFFC2CAD6);
  Color get _text => dark ? const Color(0xFFE8ECF2) : const Color(0xFF1E2430);

  static const _phase = Color(0xFFD64545); // красный — фаза
  static const _neutral = Color(0xFF3D7BD6); // синий — N
  static const _earth = Color(0xFF4CAF50); // зелёный — PE
  static const _screen = Color(0xFF7FD1C7); // дисплей

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем в системе 240 × 283 и масштабируем под фактический размер.
    const designW = 240.0;
    const designH = 283.0;
    final scale = math.min(size.width / designW, size.height / designH);
    canvas.save();
    canvas.translate(
      (size.width - designW * scale) / 2,
      (size.height - designH * scale) / 2,
    );
    canvas.scale(scale);

    _drawEnclosure(canvas);
    _drawBuses(canvas);
    _drawTopRow(canvas);
    _drawRail(canvas, railY: 84, withRcd: true, breakers: 4);
    _drawRail(canvas, railY: 172, withRcd: true, breakers: 3);
    _drawWires(canvas);
    _drawGlands(canvas);

    canvas.restore();
  }

  // ───────────────────────── корпус ─────────────────────────
  void _drawEnclosure(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8, 6, 224, 271),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, Paint()..color = _body);
    canvas.drawRRect(
      body,
      Paint()
        ..color = _edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    // внутренняя рамка двери
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 14, 208, 255),
        const Radius.circular(7),
      ),
      Paint()
        ..color = _edge.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // петля и «замок»
    canvas.drawLine(
      const Offset(12, 30),
      const Offset(12, 60),
      Paint()
        ..color = _edge
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(216, 141), 2.6, Paint()..color = _edge);
  }

  // ───────────────────────── шины ─────────────────────────
  void _drawBuses(Canvas canvas) {
    // N — слева, синяя
    final nBar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 88, 7, 164),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(nBar, Paint()..color = _neutral);
    // PE — справа, жёлто-зелёная (чередование сегментов)
    final peBar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(211, 88, 7, 164),
      const Radius.circular(3.5),
    );
    canvas.save();
    canvas.clipRRect(peBar);
    canvas.drawRect(const Rect.fromLTWH(211, 88, 7, 164),
        Paint()..color = _earth);
    for (var y = 88.0; y < 252; y += 14) {
      canvas.drawRect(Rect.fromLTWH(211, y, 7, 7),
          Paint()..color = const Color(0xFFF0C419));
    }
    canvas.restore();

    // клеммы на шинах
    final nTick = Paint()
      ..color = const Color(0xFFDDE6F7)
      ..strokeWidth = 1.4;
    final peTick = Paint()
      ..color = const Color(0xFFEAF3D8)
      ..strokeWidth = 1.4;
    for (var y = 98.0; y < 246; y += 12) {
      canvas.drawLine(Offset(23, y), Offset(28, y), nTick);
      canvas.drawLine(Offset(212, y), Offset(217, y), peTick);
    }
  }

  // ───────────────────────── провода ─────────────────────────
  void _drawWires(Canvas canvas) {
    final phase = Paint()
      ..color = _phase
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Фазы на вводе (сверху в вводной автомат)
    for (final x in [50.0, 62.0, 74.0]) {
      canvas.drawLine(Offset(x, 15), Offset(x, 25), phase);
    }

    // Вводной автомат → УЗО первой рейки
    final toRcd1 = Path()
      ..moveTo(62, 62)
      ..cubicTo(62, 74, 55, 80, 55, 91);
    canvas.drawPath(toRcd1, phase);

    // Гребёнка первой рейки: от УЗО вниз и по низу автоматов
    canvas.drawPath(
      Path()
        ..moveTo(55, 138)
        ..lineTo(55, 147),
      phase,
    );
    canvas.drawLine(const Offset(55, 147), const Offset(186, 147), phase);
    for (final x in _breakerCenters(railY: 84, breakers: 4)) {
      canvas.drawLine(Offset(x, 147), Offset(x, 139), phase);
    }

    // Переход на вторую рейку (слева, за шиной N)
    canvas.drawPath(
      Path()
        ..moveTo(38, 147)
        ..lineTo(38, 179)
        ..lineTo(55, 179),
      phase,
    );

    // Гребёнка второй рейки
    canvas.drawPath(
      Path()
        ..moveTo(55, 226)
        ..lineTo(55, 235),
      phase,
    );
    canvas.drawLine(const Offset(55, 235), const Offset(186, 235), phase);
    for (final x in _breakerCenters(railY: 172, breakers: 3)) {
      canvas.drawLine(Offset(x, 235), Offset(x, 227), phase);
    }

    // N от левой шины к УЗО
    final neutral = Paint()
      ..color = _neutral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(
      Path()
        ..moveTo(29, 112)
        ..cubicTo(38, 112, 40, 112, 44, 114),
      neutral,
    );
    canvas.drawPath(
      Path()
        ..moveTo(29, 200)
        ..cubicTo(38, 200, 40, 200, 44, 202),
      neutral,
    );
    canvas.drawLine(const Offset(29, 88), const Offset(29, 62), neutral);

    // PE от правой шины
    final earth = Paint()
      ..color = _earth
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(
      Path()
        ..moveTo(211, 120)
        ..cubicTo(203, 120, 200, 118, 192, 116),
      earth,
    );
    canvas.drawPath(
      Path()
        ..moveTo(211, 208)
        ..cubicTo(203, 208, 200, 206, 192, 204),
      earth,
    );
    canvas.drawLine(const Offset(211, 88), const Offset(211, 62), earth);
  }

  /// Центры автоматов на рейке — чтобы гребёнка точно попадала в зажимы.
  List<double> _breakerCenters({required double railY, required int breakers}) {
    const start = 34.0;
    const rcdW = 52.0;
    const gap = 8.0;
    final x = start + rcdW + gap;
    const right = 206.0;
    const moduleGap = 4.0;
    final total = right - x;
    final w = (total - moduleGap * (breakers - 1)) / breakers;
    return List.generate(
      breakers,
      (i) => x + i * (w + moduleGap) + w / 2,
    );
  }

  /// Кабельные вводы снизу: три «сальника».
  void _drawGlands(Canvas canvas) {
    final paint = Paint()
      ..color = _slot
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final x in [70.0, 120.0, 170.0]) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, 276), width: 22, height: 14),
        3.14,
        3.14,
        false,
        paint,
      );
    }
    canvas.drawLine(
      const Offset(70, 269),
      const Offset(170, 269),
      Paint()
        ..color = _edge.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
  }

  // ─────────────────────── верхний ряд ───────────────────────
  void _drawTopRow(Canvas canvas) {
    // вводной автомат 3P
    _module(canvas, const Rect.fromLTWH(40, 26, 48, 36), poles: 3);
    // реле напряжения
    _relay(canvas, const Rect.fromLTWH(96, 26, 38, 36));
    // счётчик
    _meter(canvas, const Rect.fromLTWH(142, 26, 64, 36));
  }

  void _module(
    Canvas canvas,
    Rect rect, {
    int poles = 1,
    bool rcd = false,
    double toggleAt = 0.0,
  }) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));
    canvas.drawRRect(r, Paint()..color = _moduleColor);
    canvas.drawRRect(
      r,
      Paint()
        ..color = _moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // деления по полюсам
    final step = rect.width / poles;
    for (var i = 1; i < poles; i++) {
      final x = rect.left + step * i;
      canvas.drawLine(
        Offset(x, rect.top + 3),
        Offset(x, rect.bottom - 3),
        Paint()
          ..color = _moduleEdge.withValues(alpha: 0.7)
          ..strokeWidth = 0.9,
      );
    }

    // рукоятка автомата
    final cx = rect.left + rect.width / 2 + toggleAt;
    final handleW = math.min(step * 0.45, 9.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, rect.top + rect.height * 0.42),
          width: handleW,
          height: rect.height * 0.42,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = _slot,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, rect.top + rect.height * 0.78),
          width: step * 0.5,
          height: 3.2,
        ),
        const Radius.circular(1.4),
      ),
      Paint()..color = accent,
    );

    if (rcd) {
      // кнопка «Тест»
      canvas.drawCircle(
        Offset(rect.right - 7, rect.top + 8),
        2.6,
        Paint()..color = accent,
      );
    }
  }

  void _relay(Canvas canvas, Rect rect) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(3.5));
    canvas.drawRRect(r, Paint()..color = _moduleColor);
    canvas.drawRRect(
      r,
      Paint()
        ..color = _moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // дисплей
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: rect.width - 10,
          height: 11,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = _screen.withValues(alpha: 0.85),
    );
    // кнопки
    canvas.drawCircle(
      Offset(rect.left + 6, rect.bottom - 6),
      1.9,
      Paint()..color = _slot,
    );
    canvas.drawCircle(
      Offset(rect.left + 13, rect.bottom - 6),
      1.9,
      Paint()..color = _slot,
    );
  }

  void _meter(Canvas canvas, Rect rect) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(r, Paint()..color = _moduleColor);
    canvas.drawRRect(
      r,
      Paint()
        ..color = _moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    // экран со «строчкой цифр»
    final screen = Rect.fromLTWH(
      rect.left + 6,
      rect.top + 6,
      rect.width - 12,
      rect.height - 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(2.5)),
      Paint()..color = _screen.withValues(alpha: 0.9),
    );
    final seg = Paint()
      ..color = _text.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      final x = screen.left + 6 + i * 11;
      canvas.drawLine(Offset(x, screen.center.dy), Offset(x + 6, screen.center.dy), seg);
    }
    // индикатор
    canvas.drawCircle(
      Offset(rect.right - 8, rect.bottom - 5),
      1.9,
      Paint()..color = accent,
    );
  }

  // ───────────────────────── DIN-рейки ─────────────────────────
  void _drawRail(
    Canvas canvas, {
    required double railY,
    required bool withRcd,
    required int breakers,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, railY, 176, 4),
        const Radius.circular(1.5),
      ),
      Paint()..color = _slot,
    );

    var x = 34.0;
    if (withRcd) {
      _module(
        canvas,
        Rect.fromLTWH(x, railY + 8, 52, 46),
        poles: 2,
        rcd: true,
      );
      x += 60;
    }
    const right = 206.0;
    const gap = 4.0;
    final total = right - x;
    final w = (total - gap * (breakers - 1)) / breakers;
    for (var i = 0; i < breakers; i++) {
      _module(canvas, Rect.fromLTWH(x + i * (w + gap), railY + 8, w, 46));
    }
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) =>
      old.dark != dark || old.accent != accent || old.detailed != detailed;
}
