import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_layout.dart';
import '../../plan/plan_canvas.dart';
import '../../plan/plan_models.dart';
import 'plan_editor_screen.dart';

/// Монтажный план: то, что показывает приложение по итогам расчёта.
///
/// Рисуется автоматически — комнаты, точки, щит, номера групп. Внизу
/// легенда и штамп, как на эскизе проектировщика. Ручная правка — по кнопке.
class PlanSheetScreen extends ConsumerWidget {
  final core.CalculationResult result;
  final String projectName;

  const PlanSheetScreen({
    super.key,
    required this.result,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(projectDraftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Изменить вручную',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // Сейчас шаг «геометрия»: планировка из PlanLayout.
          final built = _layoutOnly(draft);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlanEditorScreen(
                    draft: draft.copyWith(plan: built.plan),
                    onChanged: (next) => ref
                        .read(projectDraftProvider.notifier)
                        .setPlan(next),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // ПК: альбомный лист — план слева на 80 %, справа колонка данных.
          // Телефон: план сверху во всю ширину, данные ниже.
          final wide = constraints.maxWidth > 720;
          // Сейчас шаг «геометрия»: планировка из PlanLayout.
          final built = _layoutOnly(draft);
          final sheet = _sheet(context, built, ref);

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    // Лист держим в собственных пропорциях: он занимает всю
                    // высоту, а не висит мелким пятном в углу.
                    child: AspectRatio(
                      aspectRatio: built.plan.widthM / built.plan.heightM,
                      child: sheet,
                    ),
                  ),
                ),
                SizedBox(
                  width: 340,
                  child: _sidePanel(context, built),
                ),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.only(
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.62,
                child: sheet,
              ),
              _sidePanel(context, built),
            ],
          );
        },
      ),
    );
  }

  /// Только геометрия: комнаты, стены, двери. Электрику добавим позже.
  ({FloorPlan plan, Map<String, String> groupLabels}) _layoutOnly(
    ProjectDraft draft,
  ) {
    final plan = PlanLayout.build(draft);
    return (plan: plan, groupLabels: const <String, String>{});
  }

  /// Белый лист чертежа — во всю доступную площадь.
  Widget _sheet(
    BuildContext context,
    ({FloorPlan plan, Map<String, String> groupLabels}) built,
    WidgetRef ref,
  ) {
    final plan = built.plan;
    final groupNumbers = <String, String>{};
    for (final entry in built.groupLabels.entries) {
      final numbers = RegExp(r'Гр\.(\d+)')
          .allMatches(entry.value)
          .map((m) => m.group(1))
          .whereType<String>()
          .join(', ');
      if (numbers.isNotEmpty) groupNumbers[entry.key] = numbers;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: PlanInk.sheet,
        child: InteractiveViewer(
          maxScale: 4,
          minScale: 1,
          child: PlanCanvas(
            plan: plan,
            showGrid: false,
            showElectrical: false,
            tool: PlanTool.rooms,
            onTap: (_) {},
            onRoomGrab: (_, _) {},
            onRoomDragTo: (_, _) {},
            onRoomDrop: (_) {},
            onDeviceGrab: (_) {},
            onDeviceDragTo: (_, _) {},
            onPanelDragTo: (_) {},
            onSelectRoom: (_) {},
            onSelectDevice: (_) {},
            groupLabels: groupNumbers,
            panelNote: result.inputGroup == null
                ? null
                : 'ввод ${result.inputGroup!.breakerAmps} А',
          ),
        ),
      ),
    );
  }

  /// Колонка данных: легенда, группы, штамп.
  Widget _sidePanel(
    BuildContext context,
    ({FloorPlan plan, Map<String, String> groupLabels}) built,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final plan = built.plan;
    final sockets =
        plan.devices.where((d) => d.type == PlanPointType.socket).length;
    final lights =
        plan.devices.where((d) => d.type == PlanPointType.light).length;
    final switches =
        plan.devices.where((d) => d.type == PlanPointType.switchPoint).length;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
      children: [
        _explication(context, scheme, plan),
        const SizedBox(height: 10),
        // Шаг «геометрия»: электрики на плане пока нет, поэтому и легенда
        // с группами не нужна — показываем только пояснение к плану.
        _geometryNote(context, scheme, plan),
        const SizedBox(height: 10),
        _stamp(context, scheme, sockets, lights, switches),
      ],
    );
  }

  /// Пояснение к плану на этапе геометрии.
  Widget _geometryNote(BuildContext context, ColorScheme scheme, FloorPlan plan) {
    final area =
        plan.rooms.fold<double>(0, (s, r) => s + r.rect.area);
    final doors = plan.doors.length;
    final entrance = plan.doors.where((d) => d.entrance).length;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'О плане',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            row('Площадь по плану', '${area.toStringAsFixed(1)} м²'),
            row('Помещений', '${plan.rooms.length}'),
            row('Дверей', '$doors (входных: $entrance)'),
            const SizedBox(height: 6),
            Text(
              'Геометрия построена автоматически по площадям комнат. '
              'Стены, проёмы и балкон — схематично, без размеров.',
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Экспликация помещений: № / наименование / площадь.
  Widget _explication(
    BuildContext context,
    ColorScheme scheme,
    FloorPlan plan,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Экспликация помещений',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${plan.rooms.fold<double>(0, (s, r) => s + r.rect.area).toStringAsFixed(1)} м²',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < plan.rooms.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        plan.rooms[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                    Text(
                      plan.rooms[i].rect.area.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Легенда и таблица групп понадобятся на следующем шаге (электрика).
  // Держим их в файле, чтобы не потерять разметку.
  // ignore: unused_element
  Widget _legend(BuildContext context, ColorScheme scheme) {
    final items = [
      (_LegendKind.socket, 'Розетка'),
      (_LegendKind.light, 'Светильник'),
      (_LegendKind.switchPoint, 'Выключатель'),
      (_LegendKind.panel, 'Щит'),
    ];

    return Card(
      margin: EdgeInsets.zero,
      color: PlanInk.sheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Условные обозначения',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PlanInk.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final (kind, label) in items)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: _SymbolPainter(kind: kind),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PlanInk.ink,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (color, label) in [
                  (PlanInk.phase, 'L — фаза'),
                  (PlanInk.neutral, 'N — ноль'),
                  (PlanInk.earth, 'PE — земля'),
                ])
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 18, height: 3, color: color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: PlanInk.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Высоты: розетки 0.3 м, выключатели 0.9 м от пола. '
              'В санузле — только зона 3, УЗО 30 мА.',
              style: const TextStyle(fontSize: 10.5, color: PlanInk.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _groupsTable(BuildContext context, ColorScheme scheme) {
    final groups = result.groups;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Группы',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${_groupNumber(group)} · ${group.breakerAmps} А · '
                  '${_section(group.cableSectionMm2)} мм²\n'
                  '${group.name.replaceFirst(RegExp(r'^Гр\. \d+ — '), '')}',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: scheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stamp(
    BuildContext context,
    ColorScheme scheme,
    int sockets,
    int lights,
    int switches,
  ) {
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}.${now.year}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Монтажный план · $projectName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'без масштаба',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Площадь ${result.panel.installedPowerKw > 0 ? '' : ''}'
            '· мощность по ТУ ${result.panel.totalCalculatedPowerKw.toStringAsFixed(1)} кВт'
            '· ввод ${result.inputGroup?.breakerAmps ?? 0} А',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          Text(
            'Розеток $sockets · светильников $lights · выключателей $switches'
            ' · $date',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            'Черновик. Требует проверки квалифицированным электриком, '
            'не является проектной документацией.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.25,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _groupNumber(core.CircuitGroup group) =>
      RegExp(r'^Гр\. (\d+)').firstMatch(group.name)?.group(0) ?? 'Гр.';

  String _section(double mm2) =>
      mm2 == mm2.roundToDouble() ? '${mm2.toInt()}' : mm2.toString();
}

enum _LegendKind { socket, light, switchPoint, panel }

/// Рисует один символ легенды теми же штрихами, что и на плане.
class _SymbolPainter extends CustomPainter {
  final _LegendKind kind;

  const _SymbolPainter({required this.kind});

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = PlanInk.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final p = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.28;

    switch (kind) {
      case _LegendKind.socket:
        canvas.drawArc(Rect.fromCircle(center: p, radius: r), 3.14, 3.14,
            false, ink);
        canvas.drawLine(p + Offset(-r, 0), p + Offset(r, 0), ink);
        canvas.drawLine(
            p + Offset(-r * 0.45, 0), p + Offset(-r * 0.45, -r), ink);
        canvas.drawLine(p + Offset(r * 0.45, 0), p + Offset(r * 0.45, -r), ink);
      case _LegendKind.light:
        canvas.drawCircle(p, r, ink);
        canvas.drawLine(p + Offset(-r * 0.7, -r * 0.7),
            p + Offset(r * 0.7, r * 0.7), ink);
        canvas.drawLine(p + Offset(-r * 0.7, r * 0.7),
            p + Offset(r * 0.7, -r * 0.7), ink);
      case _LegendKind.switchPoint:
        canvas.drawLine(
            p + Offset(-r * 0.8, -r * 0.8), p + Offset(r * 0.8, r * 0.8), ink);
        canvas.drawLine(
            p + Offset(r * 0.8, -r * 0.8), p + Offset(-r * 0.8, r * 0.8), ink);
        canvas.drawLine(p + Offset(0, -r), p + Offset(0, -r * 2), ink);
      case _LegendKind.panel:
        final rect = Rect.fromCenter(
          center: p,
          width: size.width * 0.55,
          height: size.height * 0.4,
        );
        canvas.drawRect(rect, Paint()..color = Colors.white);
        canvas.drawRect(rect, ink);
        canvas.drawLine(rect.topLeft, rect.bottomRight, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) => old.kind != kind;
}
