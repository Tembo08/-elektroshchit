import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_auto.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final draft = ref.watch(projectDraftProvider);
    final built = PlanAuto.build(draft: draft, result: result);
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

    final sockets =
        plan.devices.where((d) => d.type == PlanPointType.socket).length;
    final lights =
        plan.devices.where((d) => d.type == PlanPointType.light).length;
    final switches =
        plan.devices.where((d) => d.type == PlanPointType.switchPoint).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Изменить вручную',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlanEditorScreen(
                    draft: draft.copyWith(plan: plan),
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // Полотно чертежа: белый лист с УГО.
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: PlanInk.sheet,
              child: PlanCanvas(
                plan: plan,
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
          const SizedBox(height: 10),
          _legend(context, scheme),
          const SizedBox(height: 10),
          _groupsTable(context, scheme),
          const SizedBox(height: 10),
          _stamp(context, scheme, sockets, lights, switches),
        ],
      ),
    );
  }

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
                  '${_section(group.cableSectionMm2)} мм² · '
                  '${group.name.replaceFirst(RegExp(r'^Гр\. \d+ — '), '')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: scheme.onSurface),
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
            'Высоты: розетки 0.3 м, выключатели 0.9 м от пола. '
            'В санузле — только зона 3, УЗО 30 мА. Черновик, требует '
            'проверки электриком.',
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
