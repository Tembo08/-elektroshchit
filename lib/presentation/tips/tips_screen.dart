import 'package:flutter/material.dart';

import '../../core/tips.dart';

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
      appBar: AppBar(title: const Text('Шпаргалка электрика')),
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
        ],
      ),
    );
  }
}
