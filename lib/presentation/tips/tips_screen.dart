import 'package:flutter/material.dart';

import '../../core/tips.dart';
import '../checklist/checklist_screen.dart';

/// «Шпаргалка» — все подсказки списком. Можно показать заказчику или
/// пролистать перед выездом.
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static const _titles = {
    TipScreen.rooms: 'Комнаты и потребители',
    TipScreen.input: 'Ввод и ТУ',
    TipScreen.lines: 'Линии',
    TipScreen.overview: 'Обзор',
    TipScreen.result: 'Результат',
    TipScreen.home: 'Общее',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = [
      TipScreen.rooms,
      TipScreen.input,
      TipScreen.lines,
      TipScreen.overview,
      TipScreen.result,
      TipScreen.home,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шпаргалка электрика'),
        actions: [
          IconButton(
            tooltip: 'Чек-лист «Принять 380 В»',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChecklistScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Короткие правила, которые чаще всего спасают от переделок. '
            'Это практика, а не замена ПУЭ.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.electrical_services,
                  color: Theme.of(context).colorScheme.primary),
              title: const Text(
                'Чек-лист: принять 380 В',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                '12 шагов от осмотра ввода до сдачи щита',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChecklistScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final screen in order) ...[
            Text(
              _titles[screen] ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...tipsFor(screen).map(
              (t) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.text,
                          style: const TextStyle(fontSize: 14, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Text(
            'Расшифровка',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._glossary.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${e.$1} — ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: e.$2),
                  ],
                ),
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _glossary = [
    ('ТУ', 'технические условия на присоединение — разрешённая мощность '
        'из договора с энергоснабжающей организацией'),
    ('УЗО', 'устройство защитного отключения — защищает от утечки тока'),
    ('АВ', 'автоматический выключатель, «автомат»'),
    ('EV', 'electric vehicle — зарядка электромобиля'),
    ('DIN-модуль', 'стандартное место в щите шириной 17.5 мм'),
    ('ВВГнг-LS', 'тип кабеля: медь, ПВХ-изоляция, пониженное дымовыделение'),
    ('ПУЭ', 'правила устройства электроустановок — основной свод норм'),
  ];
}
