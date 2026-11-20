import 'package:flutter/material.dart';

import '../../core/theme.dart';

class _Step {
  final String id;
  final String title;
  final String note;

  const _Step(this.id, this.title, this.note);
}

/// Чек-лист «принять 380 В на объекте». Отметки живут в памяти сеанса —
/// это памятка на выезд, а не отчёт.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Set<String> _done = {};

  static const _steps = [
    _Step(
      'tu',
      'Сверить ТУ',
      'Мощность, число фаз, граница балансовой принадлежности, тип учёта. '
          'Если в ТУ 15 кВт — больше не будет, сколько бы проводов ни пришло.',
    ),
    _Step(
      'wires',
      'Осмотреть ввод',
      'Сколько проводов: 4 (PEN) или 5 (N и PE)? Сечение, изоляция, '
          'состояние контактов. Записать фото до работ.',
    ),
    _Step(
      'off',
      'Отключить и проверить отсутствие напряжения',
      'На всех парах: L1-N, L2-N, L3-N, L1-L2, L2-L3, L1-L3, N-PE. '
          '380 В убивает — никакой работы под напряжением.',
    ),
    _Step(
      'phase',
      'Определить фазы, N и PE',
      'Индикатором — L1/L2/L3, по цвету и прозвонке — N и PE. '
          'Если пришло 4 провода — разделить PEN на вводе (TN-C → TN-C-S).',
    ),
    _Step(
      'measure',
      'Измерить напряжения',
      'L-N ≈ 230 В, L-L ≈ 400 В, N-PE ≈ 0 В (для TN-C-S), PE-земля ≈ 0. '
          'Перекос фаз под нагрузкой — не больше ~10–15%.',
    ),
    _Step(
      'ground',
      'Проверить заземление',
      'Связь PE с шиной, повторное заземление на вводе, надёжность '
          'контакта. PE не разрывается автоматами.',
    ),
    _Step(
      'qf',
      'Поставить вводной автомат',
      '3P по току ТУ (15 кВт → 25 А), не больше того, что держит '
          'вводной кабель и счётчик.',
    ),
    _Step(
      'rcd',
      'УЗО 4P 100 мА тип S',
      'Противопожарное, селективное. Групповые УЗО — 30 мА, тип A для '
          'техники с импульсными БП. Не больше 4 линий на аппарат.',
    ),
    _Step(
      'spd',
      'УЗИП тип 2',
      'После вводного автомата, с предохранителем по паспорту. '
          'Особенно важно для дома с воздушным вводом.',
    ),
    _Step(
      'meter',
      'Счётчик и пломбы',
      'Подключить, снять показания, вызвать на пломбировку. '
          'Записать номер и дату акта.',
    ),
    _Step(
      'balance',
      'Разложить нагрузки по фазам',
      'Тяжёлое — на разные фазы, трёхфазное — на все три. '
          'Проверить перекос после включения.',
    ),
    _Step(
      'final',
      'Сдать: протяжка, маркировка, фото',
      'Протянуть клеммы, подписать линии, сфотографировать щит до закрытия, '
          'повесить схему на дверцу. Протокол измерений — если требуется.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _done.length;
    final total = _steps.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Принять 380 В'),
        actions: [
          IconButton(
            tooltip: 'Сбросить отметки',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(_done.clear),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пройдено $done из $total',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Памятка на выезд, не заменяет проект и протоколы.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++)
            _stepCard(context, i + 1, _steps[i]),
        ],
      ),
    );
  }

  Widget _stepCard(BuildContext context, int number, _Step step) {
    final isDone = _done.contains(step.id);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          if (isDone) {
            _done.remove(step.id);
          } else {
            _done.add(step.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.ok
                      : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : Text(
                        '$number',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.note,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
