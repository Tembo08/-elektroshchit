import 'dart:io';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/core/theme.dart';
import 'package:elektroshchit/presentation/project/object_type_screen.dart';
import 'package:elektroshchit/presentation/project/room_wizard_screen.dart';
import 'package:elektroshchit/presentation/projects/projects_screen.dart';

const _normsDir = 'packages/electrical_core/lib/src/norms/ru_2026';

core.NormsCatalog loadNorms() => core.NormsLoader.fromYamlTexts(
      version: 'ru_2026',
      cableSectionsYaml:
          File('$_normsDir/cable_sections.yaml').readAsStringSync(),
      breakersYaml: File('$_normsDir/breakers.yaml').readAsStringSync(),
      rcdYaml: File('$_normsDir/rcd.yaml').readAsStringSync(),
      groupingRulesYaml:
          File('$_normsDir/grouping_rules.yaml').readAsStringSync(),
      roomDefaultsYaml:
          File('$_normsDir/room_defaults.yaml').readAsStringSync(),
      stopScenariosYaml:
          File('$_normsDir/stop_scenarios.yaml').readAsStringSync(),
    );

/// Телефон 360×800 с панелью навигации 48 dp снизу — как в реальности.
void phoneWithNavBar(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(bottom: 144, top: 72);
}

/// В тестах нет системного шрифта — грузим DejaVu, иначе кириллица
/// превращается в квадратики и скриншот бесполезен для проверки.
Future<void> loadFonts() async {
  final loader = FontLoader('DejaVu');
  final bytes = File('assets/fonts/DejaVuSans.ttf').readAsBytesSync();
  loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// Тема для скриншотов: везде DejaVu, иначе заголовки и надписи на кнопках
/// остаются квадратиками (в тестовом окружении нет системных шрифтов).
ThemeData shotTheme() {
  final base = buildDarkTheme();
  const family = 'DejaVu';
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: const TextStyle(
        fontFamily: family,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );
}

void main() {
  late core.NormsCatalog norms;

  setUpAll(() async {
    norms = loadNorms();
    await loadFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    Widget screen,
    String name,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/$name.png'),
    );
  }

  testWidgets('объект с панелью навигации', (tester) async {
    phoneWithNavBar(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);
    n.startProject(core.ObjectType.apartment, core.PhaseSystem.single);
    n.setMeta(
      name: 'ленина 42',
      totalArea: 34,
      groundingSystem: core.GroundingSystem.tnCs,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: ObjectTypeScreen(norms: norms),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/object_navbar.png'),
    );
  });

  testWidgets('визард комнаты с панелью навигации', (tester) async {
    phoneWithNavBar(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    await shoot(tester, RoomWizardScreen(norms: norms), 'wizard_navbar');
  });

  testWidgets('пояснение про заземление открывается снизу', (tester) async {
    phoneWithNavBar(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: ObjectTypeScreen(norms: norms),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Что значат TN-C-S, TN-S и TT?'));
    await tester.pumpAndSettle();

    // В листе должны быть все три системы с пояснениями.
    expect(find.textContaining('TN-C-S — самая частая'), findsOneWidget);
    expect(find.textContaining('TN-S — пять проводов'), findsOneWidget);
    expect(find.textContaining('TT — заземление своё'), findsOneWidget);
    expect(find.textContaining('УЗО нужно на каждой'), findsOneWidget);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/grounding_sheet.png'),
    );
  });

  testWidgets('проекты с панелью навигации', (tester) async {
    phoneWithNavBar(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: ProjectsScreen(norms: norms),
        ),
      ),
    );
    // Список грузится из хранилища асинхронно: спиннер не даёт settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/projects_navbar.png'),
    );
  });
}