import 'package:electrical_core/electrical_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/tips.dart';
import '../widgets/tip_card.dart';

class ResultScreen extends StatelessWidget {
  final CalculationResult result;
  final String projectName;

  const ResultScreen({
    super.key,
    required this.result,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    final panel = result.panel;
    final input = result.inputGroup;
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName),
        actions: [
          IconButton(
            tooltip: 'На главную',
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _summaryCard(context, panel, input),
          if (result.phaseBalance != null) ...[
            const SizedBox(height: 12),
            _phaseCard(context, result.phaseBalance!),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Линии', style: titleStyle),
              const Spacer(),
              Text(
                '${result.groups.length} шт.',
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _legendDot(context, AppColors.ok, 'без замечаний'),
              const SizedBox(width: 14),
              _legendDot(context, AppColors.warn, 'есть предупреждение'),
            ],
          ),
          const SizedBox(height: 8),
          ..._linesSection(context),
          const SizedBox(height: 20),
          Text('Предупреждения', style: titleStyle),
          const SizedBox(height: 8),
          if (result.warnings.isEmpty)
            Text(
              'Предупреждений нет',
              style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
            )
          else
            ...result.warnings.map((w) => _warningTile(context, w)),
          const SizedBox(height: 20),
          Text('Спецификация (черновик)', style: titleStyle),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < panel.materials.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                  _materialRow(context, panel.materials[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gpp_maybe_outlined, color: scheme.error, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Черновик. Требует проверки квалифицированным '
                      'электриком. Не является проектной документацией.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TipCard(screen: TipScreen.result),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    PanelResult panel,
    CircuitGroup? input,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final ok = panel.isInputSufficient;
    final statusColor = ok ? AppColors.ok : AppColors.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ok ? 'Ввод достаточен' : 'Превышение ТУ',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                if (input != null)
                  Text(
                    'Ввод ${input.breakerAmps} А',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric(
                  context,
                  panel.totalCalculatedPowerKw.toStringAsFixed(1),
                  'кВт',
                  'Расчётная (с коэф. спроса)',
                ),
                _metric(
                  context,
                  '${(panel.loadFactor * 100).round()}',
                  '%',
                  'Загрузка ввода',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metric(
                  context,
                  '${panel.totalDinModules}',
                  'DIN',
                  'Модулей',
                ),
                _metric(
                  context,
                  panel.recommendedPanelSize.replaceAll(' модулей', '')
                      .replaceAll(' модуля', ''),
                  'мод.',
                  'Корпус',
                ),
              ],
            ),
            if (panel.demandSavingKw > 0.05) ...[
              const SizedBox(height: 8),
              Text(
                'Установленная ${panel.installedPowerKw.toStringAsFixed(1)} кВт '
                '· коэффициент спроса даёт −${panel.demandSavingKw.toStringAsFixed(1)} кВт',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (input != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                '${input.cableType} · УЗО ${input.rcdMa} мА'
                '${input.rcdAmps != null ? " / ${input.rcdAmps} А" : ""}',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _phaseCard(BuildContext context, PhaseBalance b) {
    final scheme = Theme.of(context).colorScheme;
    final color = b.isBalanced ? AppColors.ok : AppColors.warn;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Баланс фаз',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b.isBalanced
                        ? 'перекос ${b.imbalancePercent.toStringAsFixed(0)}%'
                        : 'перекос ${b.imbalancePercent.toStringAsFixed(0)}% — много',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _phaseRow(context, 'L1', b.l1Kw, b.currentL1A, b.maxKw),
            _phaseRow(context, 'L2', b.l2Kw, b.currentL2A, b.maxKw),
            _phaseRow(context, 'L3', b.l3Kw, b.currentL3A, b.maxKw),
            const SizedBox(height: 4),
            Text(
              'Практика: перекос больше 15% — перекиньте часть линий.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phaseRow(
    BuildContext context,
    String name,
    double kw,
    double amps,
    double maxKw,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = maxKw <= 0 ? 0.0 : kw / maxKw;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              '${kw.toStringAsFixed(1)} кВт · ${amps.toStringAsFixed(0)} А',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String value,
    String unit,
    String label,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _linesSection(BuildContext context) {
    final widgets = <Widget>[];
    final grouped = <String, List<CircuitGroup>>{};
    for (final d in result.panel.protectionDevices) {
      grouped[d.id] = result.groups.where((g) => g.parentRcdId == d.id).toList();
    }
    final standalone =
        result.groups.where((g) => g.parentRcdId == null).toList();

    for (final d in result.panel.protectionDevices) {
      final children = grouped[d.id] ?? const [];
      if (children.isEmpty) continue;
      widgets.add(
        _groupHeader(
          context,
          '${d.name} · ${d.amps} А · ${d.poles}P',
        ),
      );
      for (final g in children) {
        widgets.add(_lineRow(context, g, child: true));
      }
    }
    if (standalone.isNotEmpty) {
      widgets.add(_groupHeader(context, 'Отдельные линии'));
      for (final g in standalone) {
        widgets.add(_lineRow(context, g));
      }
    }
    return widgets;
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _groupHeader(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _lineRow(BuildContext context, CircuitGroup g, {bool child = false}) {
    final scheme = Theme.of(context).colorScheme;
    final hasWarning = g.warnings.isNotEmpty;
    final dotColor = hasWarning ? AppColors.warn : AppColors.ok;
    String? rcd;
    if (g.isDifferentialBreaker) {
      rcd = 'диф ${g.breakerAmps} А / ${g.rcdMa} мА';
    } else if (g.hasRcd && g.rcdMa != null) {
      rcd = 'УЗО ${g.rcdMa} мА${g.rcdType == null ? "" : " ${g.rcdType}"}';
    }
    final number = RegExp(r'^Гр\. (\d+)').firstMatch(g.name)?.group(1);
    final label = g.name.replaceFirst(RegExp(r'^Гр\. \d+ — '), '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(child ? 26 : 14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${g.totalPowerKw.toStringAsFixed(2)} кВт',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (number != null) _badge(context, 'Гр. $number'),
                _badge(context, '${g.calculatedCurrentA.toStringAsFixed(1)} А'),
                _badge(context, 'авт ${g.breakerAmps} А'),
                _badge(context, g.cableType),
                if (rcd != null) _badge(context, rcd),
                _badge(context, '${g.dinModules} DIN'),
                if (g.phase != null) _badge(context, g.phase!),
                if (g.voltageDropPercent > 0)
                  _badge(
                    context,
                    'ΔU ${g.voltageDropPercent.toStringAsFixed(1)}%',
                    highlight: g.voltageDropPercent > 5,
                  ),
              ],
            ),
            if (hasWarning) ...[
              const SizedBox(height: 8),
              Text(
                g.warnings.join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: AppColors.warn,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String text, {bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.warn.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          color: highlight ? AppColors.warn : null,
        ),
      ),
    );
  }

  Widget _warningTile(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    final isError = text.contains('Перегруз') ||
        text.contains('кончилась') ||
        text.contains('превышает') ||
        text.contains('нельзя');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 20,
            color: isError ? AppColors.error : scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialRow(BuildContext context, MaterialItem m) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(m.name, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Text(
            '${m.quantity % 1 == 0 ? m.quantity.toInt() : m.quantity} ${m.unit}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
