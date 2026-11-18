import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Пять стилей оформления щитка. Пока используются только для витрины:
/// после выбора один из них станет главной иллюстрацией приложения.
enum PanelStyle { flat, realistic, outline, isometric, neon }

class PanelVariant extends StatefulWidget {
  final PanelStyle style;
  final double width;

  /// Шрифт подписей. На витрине передаём конкретное семейство, в приложении —
  /// null, чтобы подписи наследовали системный шрифт.
  final String? fontFamily;

  /// Включить анимацию прорисовки проводов (в приложении — да).
  final bool animate;

  /// Фиксированный кадр 0..1 вместо анимации (для скриншотов и тестов).
  final double? progress;

  const PanelVariant({
    super.key,
    required this.style,
    this.width = 320,
    this.fontFamily,
    this.animate = false,
    this.progress,
  });

  @override
  State<PanelVariant> createState() => _PanelVariantState();
}

class _PanelVariantState extends State<PanelVariant>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _VariantPainter(
      widget.style,
      widget.fontFamily,
      widget.progress ?? 1,
    );
    return SizedBox(
      width: widget.width,
      height: widget.width * 1.1,
      child: _controller == null
          ? CustomPaint(painter: painter)
          : AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) => CustomPaint(
                painter: _VariantPainter(
                  widget.style,
                  widget.fontFamily,
                  Curves.easeInOut.transform(_controller!.value) * 0.98 + 0.02,
                ),
              ),
            ),
    );
  }
}

class _Palette {
  final Color bg;
  final Color body;
  final Color bodyTop;
  final Color bodyEdge;
  final Color module;
  final Color moduleTop;
  final Color moduleEdge;
  final Color slot;
  final Color text;
  final Color screen;
  final Color phase;
  final Color neutral;
  final Color earth;
  final Color accent;
  final Color stripe;
  final bool outlineOnly;
  final bool glow;
  final bool gradient;
  final bool shadows;

  const _Palette({
    required this.bg,
    required this.body,
    required this.bodyTop,
    required this.bodyEdge,
    required this.module,
    required this.moduleTop,
    required this.moduleEdge,
    required this.slot,
    required this.text,
    required this.screen,
    required this.phase,
    required this.neutral,
    required this.earth,
    required this.accent,
    required this.stripe,
    this.outlineOnly = false,
    this.glow = false,
    this.gradient = false,
    this.shadows = false,
  });
}

const _phase = Color(0xFFD64545);
const _neutral = Color(0xFF3D7BD6);
const _earth = Color(0xFF4CAF50);
const _yellow = Color(0xFFF0C419);

_Palette _paletteFor(PanelStyle style) {
  switch (style) {
    case PanelStyle.flat:
      return const _Palette(
        bg: Color(0xFF14161A),
        body: Color(0xFF20242B),
        bodyTop: Color(0xFF20242B),
        bodyEdge: Color(0xFF3B424C),
        module: Color(0xFF2C323B),
        moduleTop: Color(0xFF2C323B),
        moduleEdge: Color(0xFF454D59),
        slot: Color(0xFF4A5360),
        text: Color(0xFFE8ECF2),
        screen: Color(0xFF7FD1C7),
        phase: _phase,
        neutral: _neutral,
        earth: _earth,
        accent: Color(0xFF9DBBF5),
        stripe: Color(0xFFF0C419),
      );
    case PanelStyle.realistic:
      return const _Palette(
        bg: Color(0xFF0E1013),
        body: Color(0xFF2A2F37),
        bodyTop: Color(0xFF3A424D),
        bodyEdge: Color(0xFF1B1F25),
        module: Color(0xFF3B434E),
        moduleTop: Color(0xFF525C6A),
        moduleEdge: Color(0xFF1E232A),
        slot: Color(0xFF6C7784),
        text: Color(0xFFF2F5F9),
        screen: Color(0xFF8FE3D6),
        phase: _phase,
        neutral: _neutral,
        earth: _earth,
        accent: Color(0xFFCFE0FF),
        stripe: _yellow,
        gradient: true,
        shadows: true,
      );
    case PanelStyle.outline:
      return const _Palette(
        bg: Color(0xFFF7F8FA),
        body: Color(0xFFFDFDFE),
        bodyTop: Color(0xFFFDFDFE),
        bodyEdge: Color(0xFF2E3440),
        module: Color(0x00FFFFFF),
        moduleTop: Color(0x00FFFFFF),
        moduleEdge: Color(0xFF2E3440),
        slot: Color(0xFFC6CDD8),
        text: Color(0xFF1D2330),
        screen: Color(0xFFBFE3DD),
        phase: _phase,
        neutral: _neutral,
        earth: _earth,
        accent: Color(0xFF2E63C8),
        stripe: Color(0xFFE0A800),
        outlineOnly: true,
      );
    case PanelStyle.isometric:
      return const _Palette(
        bg: Color(0xFF0F1216),
        body: Color(0xFF232830),
        bodyTop: Color(0xFF2E3540),
        bodyEdge: Color(0xFF121519),
        module: Color(0xFF343C47),
        moduleTop: Color(0xFF454F5C),
        moduleEdge: Color(0xFF1A1E24),
        slot: Color(0xFF59646F),
        text: Color(0xFFEAF0F7),
        screen: Color(0xFF9BE0D4),
        phase: _phase,
        neutral: _neutral,
        earth: _earth,
        accent: Color(0xFF9DBBF5),
        stripe: _yellow,
        gradient: true,
        shadows: true,
      );
    case PanelStyle.neon:
      return const _Palette(
        bg: Color(0xFF07090C),
        body: Color(0xFF0B0F14),
        bodyTop: Color(0xFF0B0F14),
        bodyEdge: Color(0xFF27E0C8),
        module: Color(0xFF0E141A),
        moduleTop: Color(0xFF0E141A),
        moduleEdge: Color(0xFF2B7F76),
        slot: Color(0xFF1C2B31),
        text: Color(0xFFD9FFF8),
        screen: Color(0xFF27E0C8),
        phase: Color(0xFFFF4D5A),
        neutral: Color(0xFF4DA3FF),
        earth: Color(0xFF49E27A),
        accent: Color(0xFF27E0C8),
        stripe: Color(0xFFFFD166),
        glow: true,
      );
  }
}

class _VariantPainter extends CustomPainter {
  final PanelStyle style;
  final String? fontFamily;
  final double wireProgress;
  _VariantPainter(this.style, this.fontFamily, this.wireProgress);

  static const designW = 300.0;
  static const designH = 330.0;

  _Palette get p => _paletteFor(style);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / (designW + 24), size.height / (designH + 24));
    canvas.save();
    canvas.translate(
      (size.width - (designW + 24) * scale) / 2,
      (size.height - (designH + 24) * scale) / 2,
    );
    canvas.scale(scale);

    _drawBackground(canvas);

    canvas.save();
    canvas.translate(12, 12);
    if (style == PanelStyle.isometric) {
      final m = Matrix4.identity()
        ..setEntry(3, 2, 0.0016)
        ..rotateX(0.09)
        ..rotateY(-0.26);
      canvas.transform(m.storage);
      canvas.translate(6, 2);
    }
    _drawEnclosure(canvas);
    _drawBusbars(canvas);
    _drawBuses(canvas);
    _drawTopRow(canvas);
    _drawRail(canvas, railY: 118, breakers: 6);
    _drawRail(canvas, railY: 206, breakers: 5);
    _drawWires(canvas);
    _drawLabels(canvas);
    canvas.restore();

    canvas.restore();
  }

  // ───────────────────────── фон ─────────────────────────
  void _drawBackground(Canvas canvas) {
    if (style == PanelStyle.outline) {
      final r = Rect.fromLTWH(0, 0, designW + 24, designH + 24);
      canvas.drawRect(r, Paint()..color = p.bg);
      // мягкая сетка, как на чертеже
      final grid = Paint()
        ..color = const Color(0xFFE3E7EE)
        ..strokeWidth = 0.6;
      for (var x = 0.0; x < r.width; x += 12) {
        canvas.drawLine(Offset(x, 0), Offset(x, r.height), grid);
      }
      for (var y = 0.0; y < r.height; y += 12) {
        canvas.drawLine(Offset(0, y), Offset(r.width, y), grid);
      }
      return;
    }
    final r = Rect.fromLTWH(0, 0, designW + 24, designH + 24);
    final shader = ui.Gradient.radial(
      Offset(r.width * 0.5, r.height * 0.35),
      r.width * 0.8,
      [p.bg, Color.lerp(p.bg, Colors.black, 0.55)!],
    );
    canvas.drawRect(r, Paint()..shader = shader);
  }

  // ───────────────────────── корпус ─────────────────────────
  void _drawEnclosure(Canvas canvas) {
    final rect = const Rect.fromLTWH(8, 8, 284, 314);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    if (p.shadows) {
      canvas.drawRRect(
        body.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    final Paint fill;
    if (p.gradient) {
      fill = Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [p.bodyTop, p.body],
        );
    } else {
      fill = Paint()..color = p.body;
    }
    if (p.outlineOnly) {
      canvas.drawRRect(body, Paint()..color = Colors.white);
    } else {
      canvas.drawRRect(body, fill);
    }
    canvas.drawRRect(
      body,
      Paint()
        ..color = p.bodyEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.glow ? 2.6 : 2.2,
    );

    // дверь
    final door = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, 268, 298),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      door,
      Paint()
        ..color = p.bodyEdge.withValues(alpha: p.outlineOnly ? 0.5 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // петля
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 40, 4, 34),
        const Radius.circular(2),
      ),
      Paint()..color = p.slot,
    );
    // замок
    canvas.drawCircle(const Offset(272, 166), 2.8, Paint()..color = p.slot);

    if (p.shadows) {
      // винты по углам
      for (final c in [
        const Offset(22, 22),
        const Offset(278, 22),
        const Offset(22, 308),
        const Offset(278, 308),
      ]) {
        canvas.drawCircle(c, 2.6, Paint()..color = p.slot);
        canvas.drawLine(
          c + const Offset(-1.6, 0),
          c + const Offset(1.6, 0),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.5)
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  // ──────────────── трёхфазная шина сверху ────────────────
  void _drawBusbars(Canvas canvas) {
    final colors = [p.phase, p.phase, p.phase];
    final ys = [30.0, 35.0, 40.0];
    for (var i = 0; i < 3; i++) {
      final y = ys[i];
      _stroke(canvas, [Offset(26, y), Offset(274, y)], colors[i], 2.4);
    }
    // подпись шин одной строкой (отдельные L1/L2/L3 наезжали друг на друга)
    _text(canvas, 'L1 · L2 · L3', const Offset(26, 15), 7.5,
        p.phase.withValues(alpha: 0.95));
  }

  // ───────────────────── шины N и PE ─────────────────────
  void _drawBuses(Canvas canvas) {
    _bar(canvas, const Rect.fromLTWH(24, 118, 8, 150), p.neutral);
    // PE — чередование
    final pe = RRect.fromRectAndRadius(
      const Rect.fromLTWH(268, 118, 8, 150),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(pe);
    canvas.drawRect(const Rect.fromLTWH(268, 118, 8, 150), Paint()..color = p.earth);
    for (var y = 118.0; y < 268; y += 14) {
      canvas.drawRect(Rect.fromLTWH(268, y, 8, 7), Paint()..color = _yellow);
    }
    canvas.restore();

    // клеммы
    for (var y = 128.0; y < 262; y += 12) {
      _stroke(canvas, [Offset(25, y), Offset(31, y)],
          Colors.white.withValues(alpha: 0.75), 1.2);
      _stroke(canvas, [Offset(269, y), Offset(275, y)],
          Colors.white.withValues(alpha: 0.75), 1.2);
    }
  }

  // ───────────────────── верхний ряд ─────────────────────
  void _drawTopRow(Canvas canvas) {
    // вводной 3P автомат
    _module(canvas, const Rect.fromLTWH(44, 50, 56, 42), poles: 3);
    // реле напряжения
    _relay(canvas, const Rect.fromLTWH(108, 50, 46, 42));
    // счётчик
    _meter(canvas, const Rect.fromLTWH(162, 50, 86, 42));
  }

  void _module(
    Canvas canvas,
    Rect rect, {
    int poles = 1,
    bool uzo = false,
  }) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    if (!p.outlineOnly) {
      final paint = p.gradient
          ? (Paint()
            ..shader = ui.Gradient.linear(
              rect.topCenter,
              rect.bottomCenter,
              [
                p.moduleTop,
                p.module,
              ],
            ))
          : (Paint()..color = p.module);
      canvas.drawRRect(r, paint);
      if (p.shadows) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.shift(const Offset(0, 1.2)),
            const Radius.circular(4),
          ),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
    canvas.drawRRect(
      r,
      Paint()
        ..color = p.moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.glow ? 1.6 : 1.2,
    );

    if (uzo) {
      // цветная полоса УЗО и подпись «30 мА» — во всех стилях, включая контур
      canvas.save();
      canvas.clipRRect(r);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, 5),
        Paint()..color = p.stripe,
      );
      canvas.restore();
      _text(canvas, '30 мА', Offset(rect.left + 5, rect.bottom - 10), 6.5,
          p.text.withValues(alpha: 0.92));
    }

    // деления полюсов
    final step = rect.width / poles;
    for (var i = 1; i < poles; i++) {
      final x = rect.left + step * i;
      _stroke(canvas, [Offset(x, rect.top + 4), Offset(x, rect.bottom - 4)],
          p.moduleEdge.withValues(alpha: 0.7), 0.8);
    }

    // рукоятка
    final cx = rect.left + rect.width / 2;
    final hw = math.min(step * 0.42, 8.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, rect.top + rect.height * 0.42),
          width: hw,
          height: rect.height * 0.36,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = p.slot,
    );
    // индикатор
    canvas.drawCircle(
      Offset(rect.right - 6, rect.top + 9),
      2.2,
      Paint()..color = p.accent,
    );
    if (p.glow) {
      canvas.drawCircle(
        Offset(rect.right - 6, rect.top + 9),
        4.5,
        Paint()
          ..color = p.accent.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _relay(Canvas canvas, Rect rect) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    if (!p.outlineOnly) {
      canvas.drawRRect(r, Paint()..color = p.module);
    }
    canvas.drawRRect(
      r,
      Paint()
        ..color = p.moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.glow ? 1.6 : 1.2,
    );
    final screen = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + 15),
      width: rect.width - 12,
      height: 13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(2.5)),
      Paint()..color = p.screen.withValues(alpha: p.outlineOnly ? 0.35 : 0.9),
    );
    // светодиод реле
    final led = Offset(rect.left + 8, rect.bottom - 9);
    canvas.drawCircle(led, 2.4, Paint()..color = p.earth);
    if (p.glow) {
      canvas.drawCircle(
        led,
        5,
        Paint()
          ..color = p.earth.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    _text(canvas, 'U~', Offset(rect.left + 16, rect.bottom - 12), 6,
        p.text.withValues(alpha: 0.8));
    // кнопки
    canvas.drawCircle(
        Offset(rect.right - 12, rect.bottom - 9), 1.8, Paint()..color = p.slot);
    canvas.drawCircle(
        Offset(rect.right - 6, rect.bottom - 9), 1.8, Paint()..color = p.slot);
  }

  void _meter(Canvas canvas, Rect rect) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    if (!p.outlineOnly) {
      canvas.drawRRect(r, Paint()..color = p.module);
    }
    canvas.drawRRect(
      r,
      Paint()
        ..color = p.moduleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.glow ? 1.6 : 1.2,
    );
    final screen = Rect.fromLTWH(
      rect.left + 7,
      rect.top + 7,
      rect.width - 14,
      rect.height - 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(3)),
      Paint()..color = p.screen.withValues(alpha: p.outlineOnly ? 0.35 : 0.92),
    );
    // «цифры» на экране
    for (var i = 0; i < 5; i++) {
      final x = screen.left + 6 + i * 13;
      _stroke(canvas, [Offset(x, screen.bottom - 5), Offset(x + 7, screen.bottom - 5)],
          p.text.withValues(alpha: 0.55), 1.2);
    }
    // светодиод счётчика
    final led = Offset(rect.right - 9, rect.bottom - 7);
    canvas.drawCircle(led, 2.2, Paint()..color = p.neutral);
    if (p.glow) {
      canvas.drawCircle(
        led,
        4.6,
        Paint()
          ..color = p.neutral.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    _text(canvas, 'кВт·ч', Offset(rect.left + 8, rect.bottom - 11), 6,
        p.text.withValues(alpha: 0.8));
  }

  // ───────────────────── DIN-рейки ─────────────────────
  void _drawRail(Canvas canvas, {required double railY, required int breakers}) {
    // рейка
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(32, railY, 236, 5),
      const Radius.circular(2),
    );
    if (!p.outlineOnly) {
      canvas.drawRRect(rail, Paint()..color = p.slot.withValues(alpha: 0.9));
    } else {
      canvas.drawRRect(
        rail,
        Paint()
          ..color = p.moduleEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // УЗО
    _module(canvas, Rect.fromLTWH(38, railY + 10, 64, 52), poles: 2, uzo: true);

    // автоматы
    final startX = 110.0;
    final right = 262.0;
    const gap = 3.0;
    final w = (right - startX - gap * (breakers - 1)) / breakers;
    for (var i = 0; i < breakers; i++) {
      _module(
        canvas,
        Rect.fromLTWH(startX + i * (w + gap), railY + 10, w, 52),
      );
    }
  }

  // ───────────────────── провода ─────────────────────
  void _drawWires(Canvas canvas) {
    final wires = <({List<Offset> pts, Color color, double width})>[];

    // фазы на вводе
    for (final x in [54.0, 66.0, 78.0]) {
      wires.add((
        pts: [Offset(x, 42), Offset(x, 50)],
        color: p.phase,
        width: 1.8,
      ));
    }
    // вводной автомат → УЗО первой рейки
    wires.add((
      pts: [const Offset(66, 92), const Offset(63, 106), const Offset(58, 122)],
      color: p.phase,
      width: 1.7,
    ));

    // гребёнка первой рейки
    final c1 = _breakerCenters(railY: 118, breakers: 6);
    wires.add((
      pts: [const Offset(58, 180), const Offset(58, 188)],
      color: p.phase,
      width: 1.7,
    ));
    wires.add((
      pts: [const Offset(58, 188), const Offset(252, 188)],
      color: p.phase,
      width: 1.7,
    ));
    for (final x in c1) {
      wires.add((
        pts: [Offset(x, 188), Offset(x, 180)],
        color: p.phase,
        width: 1.7,
      ));
    }

    // переход на вторую рейку
    wires.add((
      pts: [
        const Offset(40, 188),
        const Offset(36, 200),
        const Offset(40, 212),
        const Offset(58, 212),
      ],
      color: p.phase,
      width: 1.7,
    ));

    // гребёнка второй рейки
    final c2 = _breakerCenters(railY: 206, breakers: 5);
    wires.add((
      pts: [const Offset(58, 268), const Offset(58, 276)],
      color: p.phase,
      width: 1.7,
    ));
    wires.add((
      pts: [const Offset(58, 276), const Offset(252, 276)],
      color: p.phase,
      width: 1.7,
    ));
    for (final x in c2) {
      wires.add((
        pts: [Offset(x, 276), Offset(x, 268)],
        color: p.phase,
        width: 1.7,
      ));
    }

    // N и PE к УЗО
    wires.add((
      pts: [const Offset(32, 140), const Offset(40, 140), const Offset(40, 142)],
      color: p.neutral,
      width: 1.5,
    ));
    wires.add((
      pts: [const Offset(32, 228), const Offset(40, 228), const Offset(40, 230)],
      color: p.neutral,
      width: 1.5,
    ));
    wires.add((
      pts: [const Offset(268, 152), const Offset(258, 150), const Offset(246, 150)],
      color: p.earth,
      width: 1.5,
    ));
    wires.add((
      pts: [const Offset(268, 240), const Offset(258, 238), const Offset(246, 238)],
      color: p.earth,
      width: 1.5,
    ));

    // общая длина — чтобы прорисовка шла равномерно
    final metrics = <double>[];
    for (final w in wires) {
      final path = _poly(w.pts);
      final m = path.computeMetrics().isEmpty
          ? 0.0
          : path.computeMetrics().first.length;
      metrics.add(m);
    }
    final total = metrics.fold<double>(0, (a, b) => a + b);
    var consumed = 0.0;

    for (var i = 0; i < wires.length; i++) {
      final share = total == 0 ? 0.0 : metrics[i] / total;
      final local = ((wireProgress - consumed) / (share == 0 ? 1 : share))
          .clamp(0.0, 1.0);
      consumed += share;
      if (local <= 0) continue;

      final path = _poly(wires[i].pts);
      final metric = path.computeMetrics().first;
      final partial = metric.extractPath(0, metric.length * local);
      _drawPartial(canvas, partial, wires[i].color, wires[i].width);
    }
  }

  void _drawPartial(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (p.glow) {
      final glow = Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 2.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawPath(path, glow);
      paint.color = Color.lerp(color, Colors.white, 0.25)!;
    }
    canvas.drawPath(path, paint);
  }

  List<double> _breakerCenters({required double railY, required int breakers}) {
    const startX = 110.0;
    const right = 262.0;
    const gap = 3.0;
    final w = (right - startX - gap * (breakers - 1)) / breakers;
    return List.generate(
      breakers,
      (i) => startX + i * (w + gap) + w / 2,
    );
  }

  // ───────────────────── подписи ─────────────────────
  void _drawLabels(Canvas canvas) {
    // шильдик на дверце
    final plate = RRect.fromRectAndRadius(
      const Rect.fromLTWH(112, 292, 76, 18),
      const Radius.circular(3),
    );
    if (!p.outlineOnly) {
      canvas.drawRRect(plate, Paint()..color = p.bodyEdge.withValues(alpha: 0.35));
    }
    canvas.drawRRect(
      plate,
      Paint()
        ..color = p.bodyEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    _text(canvas, 'ЭЛЕКТРОЩИТ', const Offset(118, 297), 7.5, p.text);

    // подписи шин
    _text(canvas, 'N', const Offset(25, 270), 6.5, p.neutral);
    _text(canvas, 'PE', const Offset(266, 270), 6.5, p.earth);
  }

  // ───────────────────── примитивы ─────────────────────
  void _stroke(Canvas canvas, List<Offset> pts, Color color, double width) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (p.glow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawPath(_poly(pts), paint);
      paint.maskFilter = null;
      paint.strokeWidth = width * 0.7;
      paint.color = Color.lerp(color, Colors.white, 0.25)!;
    }
    canvas.drawPath(_poly(pts), paint);
  }

  Path _poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  void _bar(Canvas canvas, Rect rect, Color color) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(r, Paint()..color = color);
    if (p.glow) {
      canvas.drawRRect(
        r,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _text(Canvas canvas, String text, Offset offset, double size,
      Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant _VariantPainter old) =>
      old.style != style ||
      old.fontFamily != fontFamily ||
      old.wireProgress != wireProgress;
}
