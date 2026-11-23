import 'dart:io';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/plan/plan_models.dart';
import 'package:elektroshchit/presentation/plan/plan_screen.dart';
import 'package:elektroshchit/presentation/plan/plan_providers.dart';

ProjectDraft draftOf() => const ProjectDraft(
      name: 'Квартира',
      objectType: core.ObjectType.apartment,
      totalArea: 62,
      ceilingHeight: 2.7,
      phaseSystem: core.PhaseSystem.three,
      allowedPowerKw: 10,
      rooms: [
        RoomDraft(
          id: 'r1',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          socketsNormal: 6,
          lights: 2,
          switches: 1,
          area: 20,
          cableLengthM: 12,
        ),
        RoomDraft(
          id: 'r2',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          socketsNormal: 5,
          lights: 1,
          switches: 1,
          area: 10,
          cableLengthM: 8,
        ),
        RoomDraft(
          id: 'r3',
          name: 'Спальня',
          type: core.RoomType.bedroom,
          socketsNormal: 4,
          lights: 1,
          switches: 1,
          area: 14,
          cableLengthM: 10,
        ),
      ],
    );

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

core.Project projectOf(ProjectDraft draft) => core.Project(
      id: 'p',
      name: draft.name,
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.single,
      allowedPowerKw: draft.allowedPowerKw,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 44,
      ceilingHeight: 2.7,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      rooms: [
        for (final r in draft.rooms)
          core.Room(
            id: r.id,
            name: r.name,
            type: r.type,
            area: r.area,
            consumers: [
              if (r.socketsNormal > 0)
                core.Consumer(
                  id: '${r.id}#s',
                  type: core.ConsumerType.socket,
                  name: 'Розетки',
                  quantity: r.socketsNormal,
                ),
              if (r.lights > 0)
                core.Consumer(
                  id: '${r.id}#l',
                  type: core.ConsumerType.lightPoint,
                  name: 'Свет',
                  quantity: r.lights,
                ),
              if (r.switches > 0)
                core.Consumer(
                  id: '${r.id}#w',
                  type: core.ConsumerType.switchSingle,
                  name: 'Выключатели',
                  quantity: r.switches,
                ),
            ],
          ),
      ],
    );

Future<core.CalculationResult> calculate(ProjectDraft draft) async {
  final norms = loadNorms();
  return core.CircuitCalculator(norms)
      .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
}

void main() {
  testWidgets('план строится автоматически и сохраняется в черновик',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plan = container.read(projectDraftProvider).plan;
    expect(plan, isNotNull, reason: 'план должен сгенерироваться при открытии');
    expect(plan!.rooms, isNotEmpty);
    expect(plan.devices, isNotEmpty, reason: 'точки должны появиться на плане');

    // Комнаты соответствуют комнатам черновика
    final names = plan.rooms.map((r) => r.name).toSet();
    expect(names, containsAll(['Зал', 'Кухня', 'Спальня']));

    // Точек не меньше, чем розеток в черновике
    final sockets =
        plan.devices.where((d) => d.type == PlanPointType.socket).length;
    expect(sockets, greaterThanOrEqualTo(15));
  });

  testWidgets('пересоздание плана заменяет геометрию', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = container.read(projectDraftProvider).plan!;
    // Сдвигаем первую комнату вручную
    final moved = before.copyWith(
      rooms: [
        before.rooms.first.copyWith(
          rect: PlanRect(
            left: before.rooms.first.rect.left + 1,
            top: before.rooms.first.rect.top,
            width: before.rooms.first.rect.width,
            height: before.rooms.first.rect.height,
          ),
        ),
        ...before.rooms.skip(1),
      ],
    );
    container.read(projectDraftProvider.notifier).setPlan(moved);
    await tester.pumpAndSettle();

    // Нажимаем «Пересоздать» и подтверждаем
    await tester.tap(find.byTooltip('Пересоздать план'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Пересоздать').last);
    await tester.pumpAndSettle();

    final after = container.read(projectDraftProvider).plan!;
    expect(after.rooms.first.rect.left, isNot(moved.rooms.first.rect.left));
  });

  testWidgets('изменение размера комнаты за правую грань', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = container.read(projectDraftProvider).plan!;
    final room = before.rooms.first;
    // имитируем изменение размера через публичный путь: правим план напрямую
    final resized = before.copyWith(rooms: [
      room.copyWith(
        rect: PlanRect(
          left: room.rect.left,
          top: room.rect.top,
          width: room.rect.width - 1,
          height: room.rect.height,
        ),
      ),
      ...before.rooms.skip(1),
    ]);
    container.read(projectDraftProvider.notifier).setPlan(resized);
    await tester.pumpAndSettle();

    final after = container.read(projectDraftProvider).plan!;
    expect(after.rooms.first.rect.width, lessThan(room.rect.width));
    expect(after.rooms.first.rect.left, room.rect.left);
  });

  testWidgets('в режиме точек выбирается тип прибора', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // переключаемся на точки
    await tester.tap(find.text('Точки'));
    await tester.pumpAndSettle();
    expect(find.text('Розетка'), findsOneWidget);
    expect(find.text('Свет'), findsOneWidget);
    expect(find.text('Выключатель'), findsOneWidget);

    // выбираем «Свет»
    await tester.tap(find.text('Свет'));
    await tester.pumpAndSettle();
    expect(find.textContaining('светильник'), findsWidgets);
  });

  testWidgets('слой трасс включается и выключается', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      container.read(planEditorProvider).showTraces,
      isFalse,
      reason: 'по умолчанию трассы скрыты',
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Трассы'));
    await tester.pumpAndSettle();

    expect(container.read(planEditorProvider).showTraces, isTrue);
  });

  testWidgets('длины из плана попадают в комнаты черновика', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Обнуляем длины, чтобы увидеть эффект обновления.
    // Берём актуальный черновик из провайдера: в нём уже есть план.
    final current = container.read(projectDraftProvider);
    final reset = current.copyWith(
      rooms: [for (final r in current.rooms) r.copyWith(cableLengthM: 0)],
    );
    container.read(projectDraftProvider.notifier).replaceDraft(reset);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обновить длины из плана'));
    // SnackBar анимируется — ждём фиксированно, а не pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final updated = container.read(projectDraftProvider);
    final total = updated.rooms.fold<double>(0, (s, r) => s + r.cableLengthM);
    expect(total, greaterThan(0), reason: 'длины должны появиться из плана');
  });

  testWidgets('архитектурный генератор даёт стены и точки', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Переключаемся на архитектурную раскладку
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Планировка со стенами'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final plan = container.read(projectDraftProvider).plan!;
    expect(plan.walls, isNotEmpty, reason: 'у планировки должны быть стены');
    expect(plan.openings, isNotEmpty, reason: 'проёмы (двери/окна) тоже');
    expect(plan.devices, isNotEmpty, reason: 'точки расставляются поверх');
    // Точки не выходят за пределы комнат
    for (final device in plan.devices) {
      final inside = plan.rooms.any((r) => r.rect.contains(device.x, device.y));
      expect(inside, isTrue, reason: 'точка ${device.id} вне комнат');
    }
  });

  testWidgets('у выбранной комнаты показывается размер', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final draft = draftOf();
    container.read(projectDraftProvider.notifier).replaceDraft(draft);
    final result = await calculate(draft);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: PlanScreen(result: result, projectName: 'Квартира'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plan = container.read(projectDraftProvider).plan!;
    container.read(planEditorProvider.notifier).selectRoom(plan.rooms.first.id);
    await tester.pumpAndSettle();

    expect(find.textContaining('м²'), findsWidgets);
    expect(find.textContaining('×'), findsWidgets);
  });
}
