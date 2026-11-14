import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/main.dart';

void main() {
  testWidgets('приложение запускается и показывает главный экран', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ElektroshchitApp()));
    await tester.pumpAndSettle();

    // Нормы грузятся из assets: либо главный экран, либо понятная ошибка.
    final hasButton = find.text('Начать проект').evaluate().isNotEmpty;
    final hasError = find.textContaining('Ошибка норм').evaluate().isNotEmpty;
    expect(hasButton || hasError, isTrue);
    expect(hasError, isFalse,
        reason: 'нормы должны загружаться из assets приложения');
  });
}
