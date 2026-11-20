import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_models.dart';

/// План по подложке: фото или скан плана + символы поверх.
///
/// Идея простая: не рисуем стены заново, а берём готовую картинку
/// (фото плана от застройщика, скан, экспорт из Corel/Inkscape).
/// Пользователь задаёт масштаб по известному размеру, а дальше ставит
/// символы пальцем или мышью — приложение считает метры само.
class UnderlayScreen extends ConsumerStatefulWidget {
  const UnderlayScreen({super.key});

  @override
  ConsumerState<UnderlayScreen> createState() => _UnderlayScreenState();
}

/// Что ставим следующим тапом.
enum _Mode { socket, light, switchPoint, panel, calibrate }

class _UnderlayScreenState extends ConsumerState<UnderlayScreen> {
  _Mode _mode = _Mode.socket;

  /// Точки калибровки (в координатах картинки).
  final List<Offset> _calibration = [];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = ref.watch(projectDraftProvider);
    final plan = draft.plan;
    final hasImage = plan?.underlayPath != null &&
        File(plan!.underlayPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('План по фото'),
        actions: [
          if (hasImage)
            IconButton(
              tooltip: 'Заменить фото',
              icon: const Icon(Icons.image_outlined),
              onPressed: () => _pickImage(context),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasImage) _toolbar(scheme, plan),
          Expanded(
            child: hasImage
                ? _canvas(context, plan)
                : _empty(context, scheme),
          ),
          if (hasImage) _statusBar(scheme, plan),
        ],
      ),
    );
  }

  // ── пустое состояние ─────────────────────────────────────────────

  Widget _empty(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Загрузите план помещения',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Подойдёт фото плана от застройщика, скан или картинка '
              'из CorelDRAW/Inkscape. Дальше зададите масштаб и расставите '
              'розетки, светильники и выключатели.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _pickImage(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Выбрать картинку'),
            ),
          ],
        ),
      ),
    );
  }

  // ── панель инструментов ──────────────────────────────────────────

  Widget _toolbar(ColorScheme scheme, FloorPlan plan) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _chip('Розетка', _Mode.socket, Icons.power_outlined),
          _chip('Свет', _Mode.light, Icons.lightbulb_outline),
          _chip('Выключатель', _Mode.switchPoint, Icons.toggle_on_outlined),
          _chip('Щит', _Mode.panel, Icons.electrical_services_outlined),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.straighten, size: 16),
            label: const Text('Масштаб'),
            selected: _mode == _Mode.calibrate,
            onSelected: (_) {
              setState(() {
                _mode = _Mode.calibrate;
                _calibration.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Mode mode, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: _mode == mode,
        onSelected: (_) => setState(() => _mode = mode),
      ),
    );
  }

  // ── холст: картинка + символы ────────────────────────────────────

  Widget _canvas(BuildContext context, FloorPlan plan) {
    final image = File(plan.underlayPath!);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Картинка вписывается в экран, символы позиционируются в её
        // координатах — масштаб пересчитываем один раз.
        final picture = Image.file(image, fit: BoxFit.contain);

        return InteractiveViewer(
          maxScale: 8,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                Positioned.fill(child: picture),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _onTap(
                      details.localPosition,
                      Size(constraints.maxWidth, constraints.maxHeight),
                      plan,
                    ),
                    child: CustomPaint(
                      painter: _SymbolsPainter(
                        plan: plan,
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        calibration: _calibration,
                        mode: _mode,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── действия ─────────────────────────────────────────────────────

  Future<void> _pickImage(BuildContext context) async {
    const typeGroup = XTypeGroup(
      label: 'Картинки',
      extensions: ['png', 'jpg', 'jpeg', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return;

    // Копируем в папку приложения: исходник могут удалить или перенести.
    final dir = await getApplicationSupportDirectory();
    final name = 'plan_${DateTime.now().millisecondsSinceEpoch}'
        '.${file.path.split('.').last}';
    final target = File('${dir.path}/$name');
    await target.writeAsBytes(await file.readAsBytes());

    // Размер картинки — чтобы правильно считать метры на пиксель.
    final bytes = await target.readAsBytes();
    final decoded = await decodeImageFromList(bytes);

    if (!mounted) return;
    ref.read(projectDraftProvider.notifier).setPlan(
          FloorPlan(
            widthM: 0,
            heightM: 0,
            underlayPath: target.path,
            underlayWidthPx: decoded.width.toDouble(),
            underlayHeightPx: decoded.height.toDouble(),
          ),
        );
    setState(() {
      _mode = _Mode.calibrate;
      _calibration.clear();
    });
    _snack('Картинка загружена. Отметьте две точки и укажите размер');
  }

  void _onTap(Offset local, Size viewSize, FloorPlan plan) {
    final px = _toImagePixels(local, viewSize, plan);

    if (_mode == _Mode.calibrate) {
      setState(() => _calibration.add(px));
      if (_calibration.length == 2) _askMeters(plan);
      return;
    }

    if (_mode == _Mode.panel) {
      _save(plan.copyWith(
        panel: PlanPanel(
          x: px.dx * plan.metersPerPixel,
          y: px.dy * plan.metersPerPixel,
        ),
      ));
      return;
    }

    final type = switch (_mode) {
      _Mode.socket => PlanPointType.socket,
      _Mode.light => PlanPointType.light,
      _Mode.switchPoint => PlanPointType.switchPoint,
      _ => PlanPointType.socket,
    };

    final device = PlanDevice(
      id: 'u${DateTime.now().microsecondsSinceEpoch}',
      roomId: 'underlay',
      type: type,
      x: px.dx * plan.metersPerPixel,
      y: px.dy * plan.metersPerPixel,
    );

    _save(plan.copyWith(devices: [...plan.devices, device]));
  }

  /// Точка на экране → координаты картинки в пикселях.
  Offset _toImagePixels(Offset local, Size viewSize, FloorPlan plan) {
    // Картинка вписана по contain: считаем фактические поля.
    final imgW = plan.underlayWidthPx;
    final imgH = plan.underlayHeightPx;
    if (imgW <= 0 || imgH <= 0) return local;

    final scale = math.min(viewSize.width / imgW, viewSize.height / imgH);
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final dx = (viewSize.width - drawW) / 2;
    final dy = (viewSize.height - drawH) / 2;

    return Offset((local.dx - dx) / scale, (local.dy - dy) / scale);
  }

  Future<void> _askMeters(FloorPlan plan) async {
    final controller = TextEditingController(text: '3');
    final meters = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Какой это размер?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Укажите реальную длину между двумя отмеченными точками, '
              'например длину стены по плану.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Метров',
                suffixText: 'м',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              Navigator.of(context).pop(value);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );

    if (meters == null || meters <= 0) {
      setState(() => _calibration.clear());
      return;
    }

    final a = _calibration[0];
    final b = _calibration[1];
    final pixels = (b - a).distance;
    final mpp = pixels > 0 ? meters / pixels : 0.0;

    setState(() {
      _calibration.clear();
      _mode = _Mode.socket;
    });

    _save(plan.copyWith(
      metersPerPixel: mpp,
      widthM: plan.underlayWidthPx * mpp,
      heightM: plan.underlayHeightPx * mpp,
    ));
    _snack('Масштаб: 1 м = ${(1 / mpp).toStringAsFixed(0)} px');
  }

  void _save(FloorPlan plan) {
    ref.read(projectDraftProvider.notifier).setPlan(plan);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  // ── строка состояния ─────────────────────────────────────────────

  Widget _statusBar(ColorScheme scheme, FloorPlan plan) {
    final sockets =
        plan.devices.where((d) => d.type == PlanPointType.socket).length;
    final lights =
        plan.devices.where((d) => d.type == PlanPointType.light).length;
    final switches =
        plan.devices.where((d) => d.type == PlanPointType.switchPoint).length;
    final scale = plan.metersPerPixel > 0
        ? '1 м = ${(1 / plan.metersPerPixel).toStringAsFixed(0)} px'
        : 'масштаб не задан';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Розетки: $sockets · Свет: $lights · '
              'Выключатели: $switches · $scale',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          if (plan.devices.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _save(plan.copyWith(devices: const []));
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Очистить'),
            ),
        ],
      ),
    );
  }
}

/// Рисует символы поверх подложки — по ГОСТ 21.614 и с учётом масштаба.
class _SymbolsPainter extends CustomPainter {
  final FloorPlan plan;
  final Size size;
  final List<Offset> calibration;
  final _Mode mode;

  _SymbolsPainter({
    required this.plan,
    required this.size,
    required this.calibration,
    required this.mode,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final mpp = plan.metersPerPixel;
    if (mpp <= 0) return;

    // Экранный масштаб картинки (contain) → символы в пикселях картинки.
    final imgW = plan.underlayWidthPx;
    final imgH = plan.underlayHeightPx;
    if (imgW <= 0 || imgH <= 0) return;
    final fit = math.min(size.width / imgW, size.height / imgH);
    final dx = (size.width - imgW * fit) / 2;
    final dy = (size.height - imgH * fit) / 2;

    Offset toScreen(Offset meters) => Offset(
          dx + (meters.dx / mpp) * fit,
          dy + (meters.dy / mpp) * fit,
        );

    final ink = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final r = 9.0; // радиус символа на экране

    for (final device in plan.devices) {
      final p = toScreen(Offset(device.x, device.y));
      // белая подложка, чтобы символ читался на любом фото
      canvas.drawCircle(p, r + 2, Paint()..color = Colors.white);

      switch (device.type) {
        case PlanPointType.socket:
          canvas.drawArc(
            Rect.fromCircle(center: p, radius: r),
            0,
            math.pi,
            false,
            ink,
          );
          canvas.drawLine(p + Offset(-r, 0), p + Offset(r, 0), ink);
          canvas.drawLine(
              p + Offset(-r * 0.42, 0), p + Offset(-r * 0.42, -r * 0.85), ink);
          canvas.drawLine(
              p + Offset(r * 0.42, 0), p + Offset(r * 0.42, -r * 0.85), ink);
          canvas.drawLine(p, p + Offset(0, r * 1.1), ink);
        case PlanPointType.light:
          canvas.drawCircle(p, r, ink);
          canvas.drawLine(
              p + Offset(-r * 0.6, -r * 0.6), p + Offset(r * 0.6, r * 0.6), ink);
          canvas.drawLine(
              p + Offset(-r * 0.6, r * 0.6), p + Offset(r * 0.6, -r * 0.6), ink);
        case PlanPointType.switchPoint:
          canvas.drawLine(p + Offset(-r, 0), p + Offset(r * 0.3, 0), ink);
          canvas.drawLine(
              p + Offset(r * 0.3, 0), p + Offset(r, -r), ink);
        case PlanPointType.powerful:
          canvas.drawCircle(p, r, ink);
          canvas.drawCircle(p, r * 0.5, ink);
      }
    }

    // Щит
    if (plan.panel.x > 0 || plan.panel.y > 0) {
      final p = toScreen(Offset(plan.panel.x, plan.panel.y));
      final rect = Rect.fromCenter(center: p, width: 34, height: 22);
      canvas.drawRect(rect, Paint()..color = Colors.white);
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFF111827)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Точки калибровки
    if (calibration.isNotEmpty) {
      final mark = Paint()
        ..color = const Color(0xFFD32F2F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final c in calibration) {
        final p = Offset(dx + c.dx * fit, dy + c.dy * fit);
        canvas.drawCircle(p, 6, mark);
        canvas.drawLine(p + const Offset(-9, 0), p + const Offset(9, 0), mark);
        canvas.drawLine(p + const Offset(0, -9), p + const Offset(0, 9), mark);
      }
      if (calibration.length == 2) {
        canvas.drawLine(
          Offset(dx + calibration[0].dx * fit, dy + calibration[0].dy * fit),
          Offset(dx + calibration[1].dx * fit, dy + calibration[1].dy * fit),
          mark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolsPainter old) =>
      old.plan != plan ||
      old.size != size ||
      old.calibration.length != calibration.length ||
      old.mode != mode;
}
