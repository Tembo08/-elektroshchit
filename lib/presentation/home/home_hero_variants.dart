import 'package:flutter/material.dart';

/// Варианты оформления главного экрана. Оставлены как витрина: после выбора
/// один из них останется в приложении, остальные можно удалить.
enum HomeHeroVariant { modules, singleLine, panel, typography }

/// Рисует эмблему и подпись для главного экрана в выбранном стиле.
class HomeHero extends StatelessWidget {
  final HomeHeroVariant variant;
  final String title;
  final String subtitle;

  const HomeHero({
    super.key,
    required this.variant,
    this.title = 'Электрощит',
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logo = switch (variant) {
      HomeHeroVariant.modules => _ModulesLogo(color: scheme.primary),
      HomeHeroVariant.singleLine => _SingleLineLogo(color: scheme.primary),
      HomeHeroVariant.panel => _PanelLogo(color: scheme.primary),
      HomeHeroVariant.typography => _BusMark(color: scheme.primary),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── 1. Модули ───────────────────────────
/// Тонкая «шина» с отводами — знак для типографического варианта.
class _BusMark extends StatelessWidget {
  final Color color;
  const _BusMark({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 168,
        height: 42,
        child: CustomPaint(painter: _BusPainter(color)),
      );
}

class _BusPainter extends CustomPainter {
  final Color color;
  _BusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(6, y),
      Offset(size.width - 6, y),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final xs = [0.16, 0.34, 0.5, 0.66, 0.84];
    for (final f in xs) {
      final x = size.width * f;
      final isCenter = f == 0.5;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, size.height - 4),
        Paint()
          ..color = color.withValues(alpha: isCenter ? 0.9 : 0.3)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(x, y),
        isCenter ? 5.5 : 3.5,
        Paint()..color = isCenter ? color : color.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BusPainter old) => old.color != color;
}

/// Три DIN-рейки с модулями: спокойный «инженерный» знак.
class _ModulesLogo extends StatelessWidget {
  final Color color;
  const _ModulesLogo({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 168,
        height: 168,
        child: CustomPaint(painter: _ModulesPainter(color)),
      );
}

class _ModulesPainter extends CustomPainter {
  final Color color;
  _ModulesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = color.withValues(alpha: 0.35);

    const rows = 3;
    const modules = [3, 4, 3];
    final railH = size.height / rows;
    final pad = size.width * 0.08;

    for (var r = 0; r < rows; r++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pad, r * railH + 10, size.width - pad * 2, railH - 20),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, rail);

      final count = modules[r];
      final gap = 5.0;
      final cellW = (rect.width - 14 - gap * (count - 1)) / count;
      for (var i = 0; i < count; i++) {
        final isAccent = (r == 1 && i == 1);
        final cell = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + 7 + i * (cellW + gap),
            rect.top + 5,
            cellW,
            rect.height - 10,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          cell,
          Paint()
            ..color = isAccent
                ? color
                : color.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModulesPainter old) => old.color != color;
}

// ─────────────────────── 2. Однолинейка ───────────────────────
/// Ввод, шина и три отвода — знак в стиле однолинейной схемы.
class _SingleLineLogo extends StatelessWidget {
  final Color color;
  const _SingleLineLogo({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 168,
        height: 168,
        child: CustomPaint(painter: _SingleLinePainter(color)),
      );
}

class _SingleLinePainter extends CustomPainter {
  final Color color;
  _SingleLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.35);

    final cx = size.width / 2;
    // ввод
    canvas.drawLine(Offset(cx, 6), Offset(cx, 26), line);
    // автомат на вводе
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 40), width: 26, height: 20),
        const Radius.circular(4),
      ),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(Offset(cx, 50), Offset(cx, 74), line);
    // шина
    final busY = 74.0;
    canvas.drawLine(Offset(14, busY), Offset(size.width - 14, busY), line);
    // отводы
    final xs = [26.0, cx, size.width - 26];
    for (var i = 0; i < xs.length; i++) {
      final x = xs[i];
      canvas.drawLine(Offset(x, busY), Offset(x, busY + 16), soft);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, busY + 28), width: 18, height: 16),
          const Radius.circular(3),
        ),
        Paint()
          ..color = i == 1 ? color : color.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawLine(Offset(x, busY + 36), Offset(x, busY + 56), soft);
    }
    // земля
    canvas.drawLine(
        Offset(14, size.height - 18), Offset(size.width - 14, size.height - 18),
        soft);
  }

  @override
  bool shouldRepaint(covariant _SingleLinePainter old) => old.color != color;
}

// ───────────────────────── 3. Панель ─────────────────────────
/// Щит с дверцей и модулями: «продуктовый» знак.
class _PanelLogo extends StatelessWidget {
  final Color color;
  const _PanelLogo({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 168,
        height: 168,
        child: CustomPaint(painter: _PanelPainter(color)),
      );
}

class _PanelPainter extends CustomPainter {
  final Color color;
  _PanelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 6, size.width - 24, size.height - 12),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    // акцентная полоса-«дверца»
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, 18, 8, size.height - 36),
        const Radius.circular(4),
      ),
      Paint()..color = color,
    );

    // модули 2×3
    const cols = 2;
    const rows = 3;
    final area = Rect.fromLTWH(44, 18, size.width - 68, size.height - 36);
    final cellW = (area.width - 8) / cols;
    final cellH = (area.height - 10) / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              area.left + c * (cellW + 8),
              area.top + r * (cellH + 5),
              cellW,
              cellH,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) => old.color != color;
}
