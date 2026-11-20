import 'dart:io';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/core/theme.dart';
import 'package:elektroshchit/presentation/home/home_screen.dart';
import 'package:elektroshchit/presentation/project/object_type_screen.dart';
import 'package:elektroshchit/presentation/project/overview_screen.dart';
import 'package:elektroshchit/presentation/project/room_wizard_screen.dart';
import 'package:elektroshchit/presentation/plan/plan_editor_screen.dart';
import 'package:elektroshchit/plan/plan_models.dart';
import 'package:elektroshchit/presentation/plan/plan_sheet_screen.dart';
import 'package:elektroshchit/plan/plan_seed.dart';
import 'package:elektroshchit/presentation/project/rooms_flow_screen.dart';
import 'package:elektroshchit/presentation/projects/projects_screen.dart';
import 'package:elektroshchit/presentation/result/result_screen.dart';

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

/// Тема для скриншотов: DejaVu во всех стилях, иначе кириллица — квадратики.
ThemeData shotTheme() {
  final base = buildDarkTheme();
  const family = 'DejaVu';
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: family),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: const TextStyle(
        fontFamily: family,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );
}

Future<void> loadFonts() async {
  final loader = FontLoader('DejaVu');
  final bytes = File('assets/fonts/DejaVuSans.ttf').readAsBytesSync();
  loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// Телефон 360×640 dp → 1080×1920 px, как в магазине.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 96);
}

core.Project demoProject() => core.Project(
      id: 'p1',
      name: 'Квартира, Ленина 5',
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.three,
      allowedPowerKw: 15,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 62,
      ceilingHeight: 2.7,
      createdAt: DateTime(2026, 11, 20),
      updatedAt: DateTime(2026, 11, 20),
      rooms: [
        core.Room(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 12,
          cableLengthM: 18,
          consumers: const [
            core.Consumer(
              id: 'c1',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 6,
            ),
            core.Consumer(
              id: 'r1#c2',
              type: core.ConsumerType.electricStove,
              name: 'Варочная панель',
              quantity: 1,
              powerKw: 7.0,
              isPowerful: true,
              requiresRcd: true,
            ),
          ],
        ),
        core.Room(
          id: 'r2',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
          cableLengthM: 12,
          consumers: const [
            core.Consumer(
              id: 'r2#c3',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 2,
            ),
            core.Consumer(
              id: 'r2#c4',
              type: core.ConsumerType.washingMachine,
              name: 'Стиральная машина',
              quantity: 1,
              powerKw: 2.2,
              isPowerful: true,
              requiresRcd: true,
            ),
          ],
        ),
        core.Room(
          id: 'r3',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          area: 22,
          cableLengthM: 25,
          consumers: const [
            core.Consumer(
              id: 'r3#c5',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 8,
            ),
            core.Consumer(
              id: 'r3#c6',
              type: core.ConsumerType.lightPoint,
              name: 'Свет',
              quantity: 3,
            ),
          ],
        ),
      ],
    );

void main() {
  late core.NormsCatalog norms;

  setUpAll(() async {
    norms = loadNorms();
    await loadFonts();
  });

  Future<void> snap(WidgetTester tester, String name) async {
    phone(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_shots/$name.png'),
    );
  }

  testWidgets('01 главная', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        ),
      ),
    );
    await snap(tester, '01_home');
  });

  testWidgets('02 объект', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);
    n.startProject(core.ObjectType.apartment, core.PhaseSystem.three);
    n.setMeta(name: 'Ленина 5', totalArea: 62, ceilingHeight: 2.7);
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
    await snap(tester, '02_object');
  });

  testWidgets('03 комнаты', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);
    n.startProject(core.ObjectType.apartment, core.PhaseSystem.three);
    n.replaceRooms(const [
      RoomDraft(
        id: 'r1',
        name: 'Кухня',
        type: core.RoomType.kitchen,
        socketsNormal: 6,
        lights: 2,
        switches: 1,
        area: 12,
        cableLengthM: 18,
        dedicated: {
          core.ConsumerType.electricStove: ApplianceSpec(
            quantity: 1,
            powerKw: 7,
          ),
        },
      ),
      RoomDraft(
        id: 'r2',
        name: 'Санузел',
        type: core.RoomType.combinedBathroom,
        socketsNormal: 2,
        lights: 1,
        area: 4,
        cableLengthM: 12,
      ),
      RoomDraft(
        id: 'r3',
        name: 'Зал',
        type: core.RoomType.livingRoom,
        socketsNormal: 8,
        lights: 3,
        switches: 2,
        area: 22,
        cableLengthM: 25,
      ),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: RoomsFlowScreen(norms: norms),
        ),
      ),
    );
    await snap(tester, '03_rooms');
  });

  testWidgets('04 комната — приборы', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: RoomWizardScreen(norms: norms),
        ),
      ),
    );
    await snap(tester, '04_room');
  });

  testWidgets('05 обзор', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);
    n.startProject(core.ObjectType.apartment, core.PhaseSystem.three);
    n.setMeta(name: 'Ленина 5', totalArea: 62, ceilingHeight: 2.7);
    n.setInput(allowedPowerKw: 15);
    n.replaceRooms(const [
      RoomDraft(
        id: 'r1',
        name: 'Кухня',
        type: core.RoomType.kitchen,
        socketsNormal: 6,
        lights: 2,
        area: 12,
        cableLengthM: 18,
        dedicated: {
          core.ConsumerType.electricStove: ApplianceSpec(
            quantity: 1,
            powerKw: 7,
          ),
        },
      ),
      RoomDraft(
        id: 'r2',
        name: 'Зал',
        type: core.RoomType.livingRoom,
        socketsNormal: 8,
        lights: 3,
        area: 22,
        cableLengthM: 25,
      ),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: OverviewScreen(norms: norms),
        ),
      ),
    );
    await snap(tester, '05_overview');
  });

  testWidgets('06 результат', (tester) async {
    phone(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(projectDraftProvider.notifier);
    n.startProject(core.ObjectType.apartment, core.PhaseSystem.three);
    n.setMeta(name: 'Квартира', totalArea: 62, ceilingHeight: 2.7);
    n.setInput(allowedPowerKw: 15);
    n.replaceRooms(const [
      RoomDraft(
        id: 'r1',
        name: 'Кухня',
        type: core.RoomType.kitchen,
        socketsNormal: 6,
        lights: 2,
        area: 12,
        cableLengthM: 18,
      ),
      RoomDraft(
        id: 'r2',
        name: 'Зал',
        type: core.RoomType.livingRoom,
        socketsNormal: 8,
        lights: 3,
        area: 22,
        cableLengthM: 25,
      ),
    ]);

    final result = core.CircuitCalculator(norms)
        .calculate(demoProject(), socketLines: 2, lightingLines: 2);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: ResultScreen(
            result: result,
            projectName: 'Квартира',
            projectDetails:
                'Ленина 5 · 62 м² · потолки 2.7 м · TN-C-S · ТУ 15 кВт',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_shots/06_result.png'),
    );
  });

  testWidgets('08 план помещения', (tester) async {
    phone(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});

    const draft = ProjectDraft(
      rooms: [
        RoomDraft(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 12,
        ),
        RoomDraft(
          id: 'r2',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          area: 20,
        ),
        RoomDraft(
          id: 'r3',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
        ),
      ],
    );

    // План из комнат проекта + расставленные точки: на скриншоте должны
    // быть видны УГО розеток и трёхцветные линии от щита.
    final seeded = PlanSeed.fromDraft(draft);
    final kitchen = seeded.rooms.firstWhere((r) => r.name == 'Кухня');
    final hall = seeded.rooms.firstWhere((r) => r.name == 'Зал');
    final bath = seeded.rooms.firstWhere((r) => r.name == 'Санузел');
    final plan = seeded.copyWith(devices: [
      PlanDevice(
        id: 's1',
        type: PlanPointType.socket,
        x: kitchen.rect.left + 0.6,
        y: kitchen.rect.bottom - 0.4,
        roomId: kitchen.id,
      ),
      PlanDevice(
        id: 's2',
        type: PlanPointType.socket,
        x: kitchen.rect.left + 1.6,
        y: kitchen.rect.bottom - 0.4,
        roomId: kitchen.id,
      ),
      PlanDevice(
        id: 'l1',
        type: PlanPointType.light,
        x: kitchen.rect.center.dx,
        y: kitchen.rect.center.dy,
        roomId: kitchen.id,
      ),
      PlanDevice(
        id: 's3',
        type: PlanPointType.socket,
        x: hall.rect.left + 0.6,
        y: hall.rect.bottom - 0.4,
        roomId: hall.id,
      ),
      PlanDevice(
        id: 'l2',
        type: PlanPointType.light,
        x: hall.rect.center.dx,
        y: hall.rect.center.dy,
        roomId: hall.id,
      ),
      PlanDevice(
        id: 'pw1',
        type: PlanPointType.powerful,
        x: bath.rect.left + 0.5,
        y: bath.rect.top + 0.5,
        roomId: bath.id,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: PlanEditorScreen(
            draft: draft.copyWith(plan: plan),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_shots/08_plan.png'),
    );
  });

  testWidgets('09 монтажный план', (tester) async {
    phone(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = demoDraft();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = core.CircuitCalculator(norms).calculate(
      demoProject(),
      socketLines: 2,
      lightingLines: 2,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: PlanSheetScreen(
            result: result,
            projectName: 'Квартира',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_shots/09_sheet.png'),
    );
  });

  testWidgets('07 проекты', (tester) async {
    phone(tester);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(projectStoreProvider);
    await store.upsert(
      draft: const ProjectDraft(
        name: 'Квартира, Ленина 5',
        objectType: core.ObjectType.apartment,
        allowedPowerKw: 15,
        rooms: [
          RoomDraft(id: 'a', name: 'Кухня', type: core.RoomType.kitchen),
        ],
      ),
      now: DateTime(2026, 11, 20, 10),
    );
    await store.upsert(
      draft: const ProjectDraft(
        name: 'Дом в Сосновке',
        objectType: core.ObjectType.privateHouse,
        allowedPowerKw: 25,
        rooms: [
          RoomDraft(id: 'b', name: 'Зал', type: core.RoomType.livingRoom),
        ],
      ),
      now: DateTime(2026, 11, 18, 18),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: shotTheme(),
          debugShowCheckedModeBanner: false,
          home: ProjectsScreen(norms: norms),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_shots/07_projects.png'),
    );
  });
}


/// Черновик для скриншота монтажного плана: те же комнаты, что в расчёте.
ProjectDraft demoDraft() => const ProjectDraft(
      name: 'Квартира',
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.three,
      allowedPowerKw: 15,
      totalArea: 62,
      rooms: [
        RoomDraft(
          id: 'r0',
          name: 'Прихожая',
          type: core.RoomType.entrance,
          area: 5,
          socketsNormal: 2,
          lights: 1,
          switches: 1,
        ),
        RoomDraft(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 12,
          socketsNormal: 6,
          lights: 2,
          switches: 1,
          dedicated: {
            core.ConsumerType.electricStove: ApplianceSpec(
              quantity: 1,
              powerKw: 7,
            ),
          },
        ),
        RoomDraft(
          id: 'r3',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          area: 22,
          socketsNormal: 8,
          lights: 2,
          switches: 2,
        ),
        RoomDraft(
          id: 'r2',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
          socketsNormal: 2,
          lights: 1,
          switches: 1,
        ),
      ],
    );
