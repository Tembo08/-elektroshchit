import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart';

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
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        );

    return Scaffold(
      appBar: AppBar(title: Text(projectName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.orange.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Черновик. Требует проверки квалифицированным электриком. '
                      'Не является проектной документацией.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Сводка', style: titleStyle),
          const SizedBox(height: 10),
          _infoTile(
            'Мощность расчётная',
            '${panel.totalCalculatedPowerKw.toStringAsFixed(2)} кВт',
          ),
          _infoTile(
            'Загрузка ввода',
            '${(panel.loadFactor * 100).toStringAsFixed(0)}%',
          ),
          _infoTile('Ввод достаточен', panel.isInputSufficient ? 'Да' : 'Нет'),
          _infoTile('DIN-модули', '${panel.totalDinModules}'),
          _infoTile('Рекомендуемый щит', panel.recommendedPanelSize),
          const SizedBox(height: 20),

          if (input != null) ...[
            Text('Ввод', style: titleStyle),
            const SizedBox(height: 10),
            _card(
              title: input.name,
              body:
                  'Автомат ${input.breakerAmps}А · ${input.cableType}\n'
                  'УЗО ${input.rcdMa ?? "—"} мА · DIN: ${input.dinModules}',
            ),
            const SizedBox(height: 20),
          ],

          // УЗО-родители + дочерние автоматы
          if (panel.protectionDevices.isNotEmpty) ...[
            Text('УЗО и группы', style: titleStyle),
            const SizedBox(height: 10),
            ...panel.protectionDevices.map((d) {
              final children = result.groups
                  .where((g) => g.parentRcdId == d.id)
                  .toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.name} · ${d.amps}А · DIN: ${d.dinModules}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...children.map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: Text(
                            '• ${g.name}\n'
                            '  Автомат ${g.breakerAmps}А · ${g.cableType} · '
                            'DIN: ${g.dinModules}',
                            style: const TextStyle(fontSize: 15, height: 1.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Отдельные линии (силовые и без parent)
          Builder(
            builder: (context) {
              final standalone = result.groups
                  .where((g) => g.parentRcdId == null)
                  .toList();
              if (standalone.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Отдельные линии', style: titleStyle),
                  const SizedBox(height: 10),
                  ...standalone.map(
                    (g) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'P=${g.totalPowerKw.toStringAsFixed(2)} кВт · '
                              'I=${g.calculatedCurrentA.toStringAsFixed(1)} А\n'
                              '${g.isDifferentialBreaker ? "Дифавтомат ${g.breakerAmps}А / ${g.rcdMa} мА" : "Автомат ${g.breakerAmps}А"}'
                              '${!g.isDifferentialBreaker && g.hasRcd ? " · УЗО ${g.rcdMa} мА" : ""}'
                              ' · ${g.cableType}\n'
                              'DIN: ${g.dinModules}',
                              style: const TextStyle(fontSize: 15, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),

          Text('Предупреждения', style: titleStyle),
          const SizedBox(height: 8),
          ...result.warnings.map(
            (w) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: Text(w, style: const TextStyle(fontSize: 15, height: 1.35)),
            ),
          ),
          const SizedBox(height: 12),

          Text('Спецификация (черновик)', style: titleStyle),
          const SizedBox(height: 8),
          ...panel.materials.map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.name, style: const TextStyle(fontSize: 16)),
              trailing: Text(
                '${m.quantity} ${m.unit}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({required String title, required String body}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 16, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          ),
        ],
      ),
    );
  }
}
