import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_canvas.dart';
import '../../plan/plan_models.dart';
import '../../plan/svg_import.dart';

/// Импорт плана из CorelDRAW / Inkscape.
///
/// Пользователь рисует план в привычном редакторе, раскладывая объекты по
/// слоям (`walls`, `doors`, `windows`, `socket`, `light`, `switch`, `panel`),
/// сохраняет SVG — приложение читает слои и получает настоящую геометрию.
class SvgImportScreen extends ConsumerStatefulWidget {
  const SvgImportScreen({super.key});

  @override
  ConsumerState<SvgImportScreen> createState() => _SvgImportScreenState();
}

class _SvgImportScreenState extends ConsumerState<SvgImportScreen> {
  SvgImportResult? _result;
  String? _fileName;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('План из Corel / Inkscape'),
        actions: [
          IconButton(
            tooltip: 'Скачать шаблон SVG',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _saveTemplate(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _instruction(context, scheme),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _pickFile(context),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Выбрать SVG'),
              ),
              const SizedBox(width: 10),
              if (result != null)
                FilledButton.tonalIcon(
                  onPressed: () => _apply(context, result),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Применить'),
                ),
            ],
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text(
              'Файл: $_fileName',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            _summary(scheme, result),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              _warnings(scheme, result.warnings),
            ],
            const SizedBox(height: 16),
            _preview(scheme, result.plan),
          ],
        ],
      ),
    );
  }

  // ── блоки экрана ─────────────────────────────────────────────────

  Widget _instruction(BuildContext context, ColorScheme scheme) {
    return Card(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Как подготовить файл',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Откройте шаблон в CorelDRAW или Inkscape.\n'
              '2. Рисуйте на готовых слоях — тип элемента берётся из имени '
              'слоя.\n'
              '3. Размер листа в миллиметрах = реальные размеры помещения.\n'
              '4. Сохраните как SVG и выберите файл здесь.',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final layer in const [
                  'walls',
                  'doors',
                  'windows',
                  'socket',
                  'light',
                  'switch',
                  'panel',
                ])
                  Chip(
                    label: Text(layer, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(ColorScheme scheme, SvgImportResult result) {
    Widget stat(String label, int value, IconData icon) => Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 4),
              Text('$label: $value', style: const TextStyle(fontSize: 13)),
            ],
          ),
        );

    if (result.isEmpty) {
      return Card(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'В файле не нашлось ни стен, ни символов. Проверьте, что слои '
            'называются walls, doors, windows, socket, light, switch, panel.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прочитано: ${result.plan.widthM.toStringAsFixed(1)} × '
              '${result.plan.heightM.toStringAsFixed(1)} м',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              children: [
                stat('Стены', result.wallsCount, Icons.horizontal_rule),
                stat('Двери', result.doorsCount, Icons.sensor_door_outlined),
                stat('Окна', result.windowsCount, Icons.window_outlined),
                stat('Розетки', result.sockets, Icons.power_outlined),
                stat('Свет', result.lights, Icons.lightbulb_outline),
                stat('Выключатели', result.switches, Icons.toggle_on_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _warnings(ColorScheme scheme, List<String> warnings) {
    return Card(
      color: scheme.tertiaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final warning in warnings.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $warning',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _preview(ColorScheme scheme, FloorPlan plan) {
    final width = plan.widthM > 0 ? plan.widthM : 1.0;
    final height = plan.heightM > 0 ? plan.heightM : 1.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: width / height,
        child: ColoredBox(
          color: Colors.white,
          child: PlanCanvas(
            plan: plan,
            showGrid: false,
            tool: PlanTool.rooms,
            selectedRoomId: null,
            selectedDeviceId: null,
            groupLabels: const {},
            onTap: (_) {},
            onRoomGrab: (_, _) {},
            onRoomDragTo: (_, _) {},
            onRoomDrop: (_) {},
            onDeviceGrab: (_) {},
            onDeviceDragTo: (_, _) {},
            onPanelDragTo: (_) {},
            onSelectRoom: (_) {},
            onSelectDevice: (_) {},
          ),
        ),
      ),
    );
  }

  // ── действия ─────────────────────────────────────────────────────

  Future<void> _pickFile(BuildContext context) async {
    const group = XTypeGroup(label: 'SVG', extensions: ['svg']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final svg = await File(file.path).readAsString();
      final parsed = SvgPlanImport.parse(svg);
      if (!mounted) return;
      setState(() {
        _result = parsed;
        _fileName = file.name;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прочитать файл: $e')),
      );
    }
  }

  void _apply(BuildContext context, SvgImportResult result) {
    ref.read(projectDraftProvider.notifier).setPlan(result.plan);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('План загружен в проект')),
    );
  }

  Future<void> _saveTemplate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svg = await rootBundle.loadString('assets/plan_template.svg');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/шаблон_плана.svg');
      await file.writeAsString(svg);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Шаблон сохранён: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось сохранить шаблон: $e')),
      );
    }
  }
}
