import 'dart:io';

import 'package:electrical_core/electrical_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/main.dart';
import 'package:elektroshchit/core/template_mapper.dart';
import 'package:elektroshchit/presentation/checklist/checklist_screen.dart';
import 'package:elektroshchit/presentation/project/input_config_screen.dart';
import 'package:elektroshchit/presentation/templates/templates_screen.dart';
import 'package:elektroshchit/presentation/project/overview_screen.dart';
import 'package:elektroshchit/presentation/project/room_wizard_screen.dart';
import 'package:elektroshchit/presentation/project/rooms_flow_screen.dart';

const _normsDir = 'packages/electrical_core/lib/src/norms/ru_2026';

NormsCatalog loadNorms() {
  return NormsLoader.fromYamlTexts(
    version: 'ru_2026',
    cableSectionsYaml: File('$_normsDir/cable_sections.yaml').readAsStringSync(),
    breakersYaml: File('$_normsDir/breakers.yaml').readAsStringSync(),
    rcdYaml: File('$_normsDir/rcd.yaml').readAsStringSync(),
    groupingRulesYaml: File('$_normsDir/grouping_rules.yaml').readAsStringSync(),
    roomDefaultsYaml: File('$_normsDir/room_defaults.yaml').readAsStringSync(),
  );
}

void main() {
  late NormsCatalog norms;

  setUpAll(() {
    norms = loadNorms();
  });

  test('черновик хранит комнаты, ТУ и линии после «назад»', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);

    n.startProject(ObjectType.privateHouse, PhaseSystem.three);
    n.addRoom(
      const RoomDraft(
        id: 'r1',
        name: 'Кухня',
        type: RoomType.kitchen,
        socketsNormal: 8,
        lights: 3,
        switches: 2,
        dedicated: {
          ConsumerType.electricStove: ApplianceSpec(quantity: 1, powerKw: 5.5),
        },
      ),
    );
    n.setInput(allowedPowerKw: 15, breakerAmps: 40);
    n.setLines(lightingLines: 3, socketLines: 2);

    final d = container.read(projectDraftProvider);
    expect(d.objectType, ObjectType.privateHouse);
    expect(d.phaseSystem, PhaseSystem.three);
    expect(d.allowedPowerKw, 15);
    expect(d.inputBreakerAmps, 40);
    expect(d.lightingLines, 3);
    expect(d.socketLines, 2);
    expect(d.rooms.single.totalSockets, 9);
    expect(d.rooms.single.dedicated[ConsumerType.electricStove]?.powerKw, 5.5);

    // Обновление комнаты не теряет остальные данные.
    n.updateRoom(d.rooms.single.copyWith(name: 'Кухня-гостиная'));
    expect(container.read(projectDraftProvider).rooms.single.name,
        'Кухня-гостиная');
    expect(container.read(projectDraftProvider).allowedPowerKw, 15);

    // Удаление и возврат (undo в UI).
    n.removeRoom('r1');
    expect(container.read(projectDraftProvider).rooms, isEmpty);
    n.addRoom(d.rooms.single);
    expect(container.read(projectDraftProvider).rooms, hasLength(1));
  });

  testWidgets('экран комнат берёт список из черновика', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(projectDraftProvider.notifier).addRoom(
          const RoomDraft(
            id: 'r1',
            name: 'Спальня',
            type: RoomType.bedroom,
            socketsNormal: 4,
            lights: 2,
            switches: 1,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RoomsFlowScreen(norms: norms)),
      ),
    );

    expect(find.text('Спальня'), findsOneWidget);
    expect(find.textContaining('Розетки: 4'), findsOneWidget);
    expect(find.text('Далее'), findsOneWidget);
  });

  testWidgets('ТУ из черновика подставляется в поле ввода', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(projectDraftProvider.notifier).setInput(
          allowedPowerKw: 10,
          breakerAmps: 40,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: InputConfigScreen(norms: norms)),
      ),
    );

    expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    expect(find.textContaining('40 А'), findsWidgets);
  });

  testWidgets('в визарде можно задать мощность и фазы прибора', (tester) async {
    // Большой экран, чтобы не бороться со скроллом в тесте.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    RoomDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  saved = await Navigator.of(context).push<RoomDraft>(
                    MaterialPageRoute(
                      builder: (_) => RoomWizardScreen(norms: norms),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Включаем варочную панель: у неё появится поле мощности и выбор фаз.
    final stoveLabel = find.text('Варочная панель');
    final row = find.ancestor(of: stoveLabel, matching: find.byType(Row)).first;
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      ),
    );
    await tester.pumpAndSettle();

    // Поле мощности — второй TextField (первый — название комнаты).
    final powerField = find.byType(TextField).at(1);
    expect(powerField, findsOneWidget);
    await tester.enterText(powerField, '5,5');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    final spec = saved?.dedicated[ConsumerType.electricStove];
    expect(spec, isNotNull);
    expect(spec!.quantity, 1);
    expect(spec.powerKw, 5.5);
    expect(spec.phases, 1);
  });

  testWidgets('сквозной сценарий: проект считается, «назад» не стирает ввод',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: ElektroshchitApp()));
    await tester.pumpAndSettle();

    // Главная → объект
    await tester.tap(find.text('Начать проект'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Квартира'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    // Комнаты: добавляем комнату по умолчанию
    expect(find.text('Комнаты'), findsOneWidget);
    // В пустом состоянии кнопка одна — большая, по центру.
    await tester.tap(find.text('Добавить комнату'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Гостиная'), findsOneWidget);

    // Ввод ТУ
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    // Линии → обзор → расчёт
    expect(find.text('Линии'), findsOneWidget);
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Обзор'), findsOneWidget);
    await tester.tap(find.text('Рассчитать щиток'));
    await tester.pumpAndSettle();

    // Результат посчитан
    expect(find.text('Линии'), findsOneWidget);
    expect(find.textContaining('Спецификация'), findsOneWidget);
    expect(find.text('Ввод достаточен'), findsOneWidget);

    // «Назад» до комнат (результат → обзор → линии → ввод → комнаты):
    // данные проекта на месте, раньше они терялись.
    for (var i = 0; i < 4; i++) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('Гостиная'), findsOneWidget,
        reason: 'список комнат не должен теряться при возврате');

    // И ТУ на шаге ввода сохранился
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '10'), findsOneWidget,
        reason: 'мощность по ТУ должна подставляться из черновика');
  });

  testWidgets('пустой экран комнат: одна кнопка добавления, без FAB',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: RoomsFlowScreen(norms: norms)),
      ),
    );

    expect(find.text('Добавить комнату'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('обзор не переполняется на узком экране с богатой комнатой',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(projectDraftProvider.notifier);
    notifier.startProject(ObjectType.apartment, PhaseSystem.single);
    notifier.setInput(allowedPowerKw: 18);
    notifier.addRoom(
      const RoomDraft(
        id: 'r1',
        name: 'Кухня-гостиная',
        type: RoomType.kitchen,
        socketsNormal: 12,
        lights: 6,
        switches: 4,
        dedicated: {
          ConsumerType.electricStove: ApplianceSpec(quantity: 2),
          ConsumerType.dishwasher: ApplianceSpec(quantity: 1),
        },
      ),
    );

    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: OverviewScreen(norms: norms)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'карточка не должна переполняться');
    expect(find.textContaining('Силовые: 3'), findsOneWidget);
    expect(find.textContaining('ТУ (тех. условия): 18'), findsOneWidget);
  });

  test('шаблон превращается в комнаты черновика', () {
    final t = norms.templates.firstWhere((t) => t.id == 'one_room');
    final rooms = roomsFromTemplate(t, norms);

    expect(rooms.length, 4);
    final kitchen = rooms.firstWhere((r) => r.name == 'Кухня');
    // 6 розеток + холодильник + вытяжка (они тоже точки розеточной группы)
    expect(kitchen.socketsNormal, 8);
    expect(kitchen.lights, 2);
    expect(kitchen.dedicated[ConsumerType.electricStove]?.powerKw, 7.0);

    final bath = rooms.firstWhere((r) => r.name == 'Санузел');
    expect(bath.mirrorSockets, 2, reason: 'розетки санузла идут к зеркалу');
    expect(
      bath.dedicated[ConsumerType.washingMachine]?.quantity,
      1,
    );
    expect(bath.type, RoomType.combinedBathroom);
  });

  testWidgets('шаблон применяется к проекту', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(projectDraftProvider.notifier).startProject(
          ObjectType.apartment,
          PhaseSystem.single,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TemplatesScreen(norms: norms),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Шаблоны объектов'), findsOneWidget);

    await tester.tap(find.text('Применить').first);
    await tester.pumpAndSettle();

    final draft = container.read(projectDraftProvider);
    expect(draft.rooms, isNotEmpty);
    expect(draft.rooms.length, norms.templates.first.rooms.length);
    expect(draft.allowedPowerKw,
        norms.templates.first.suggestedPowerKw);
  });

  testWidgets('чек-лист «Принять 380 В» отмечает шаги', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChecklistScreen()),
    );

    expect(find.text('Пройдено 0 из 12'), findsOneWidget);
    await tester.tap(find.text('Сверить ТУ'));
    await tester.pumpAndSettle();
    expect(find.text('Пройдено 1 из 12'), findsOneWidget);
  });
}
