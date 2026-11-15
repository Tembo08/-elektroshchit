import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/tips.dart';
import 'package:elektroshchit/presentation/tips/tips_screen.dart';
import 'package:elektroshchit/presentation/widgets/tip_card.dart';

void main() {
  test('подсказки: уникальные id и хотя бы одна на каждый экран', () {
    final ids = kTips.map((t) => t.id).toSet();
    expect(ids.length, kTips.length, reason: 'id подсказок должны быть уникальны');
    for (final screen in TipScreen.values) {
      expect(tipsFor(screen), isNotEmpty, reason: 'нет подсказки для $screen');
    }
  });

  testWidgets('карточка подсказки закрывается и листается', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: TipCard(screen: TipScreen.rooms))),
      ),
    );

    expect(find.textContaining('Розеточная группа'), findsOneWidget);

    await tester.tap(find.text('Другая'));
    await tester.pumpAndSettle();
    expect(find.textContaining('отдельные линии'), findsOneWidget);

    // Закрываем по одной: карточка остаётся, пока есть непрочитанные советы.
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Санузел'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Розеточная группа'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('шпаргалка показывает все разделы', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TipsScreen()));
    expect(find.text('Шпаргалка электрика'), findsOneWidget);
    expect(find.text('Комнаты и потребители'), findsOneWidget);
    expect(find.text('Ввод и ТУ'), findsOneWidget);
  });
}
