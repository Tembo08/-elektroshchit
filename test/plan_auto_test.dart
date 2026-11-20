import 'dart:io';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/plan/plan_auto.dart';
import 'package:elektroshchit/plan/plan_models.dart';

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

ProjectDraft sampleDraft() => const ProjectDraft(
      name: 'Квартира',
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.single,
      allowedPowerKw: 15,
      rooms: [
        RoomDraft(
          id: 'r1',
          name: 'Прихожая',
          type: core.RoomType.entrance,
          area: 5,
          socketsNormal: 2,
          lights: 1,
          switches: 1,
        ),
        RoomDraft(
          id: 'r2',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 10,
          socketsNormal: 6,
          lights: 2,
          switches: 1,
          dedicated: {
            core.ConsumerType.electricStove: ApplianceSpec(
              quantity: 1,
              powerKw: 6,
            ),
          },
        ),
        RoomDraft(
          id: 'r3',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          area: 20,
          socketsNormal: 8,
          lights: 2,
          switches: 2,
        ),
        RoomDraft(
          id: 'r4',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
          socketsNormal: 2,
          lights: 1,
          switches: 1,
        ),
        RoomDraft(
          id: 'r5',
          name: 'Балкон',
          type: core.RoomType.balcony,
          area: 3,
          socketsNormal: 1,
          lights: 0,
          switches: 0,
        ),
      ],
    );

core.Project projectOf(ProjectDraft draft) => core.Project(
      id: 'p',
      name: draft.name,
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.single,
      allowedPowerKw: draft.allowedPowerKw,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 42,
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
            ],
          ),
      ],
    );

void main() {
  late core.NormsCatalog norms;

  setUpAll(() => norms = loadNorms());

  test('план строится автоматически и содержит все комнаты', () {
    final draft = sampleDraft();
    final result = core.CircuitCalculator(norms)
        .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
    final built = PlanAuto.build(draft: draft, result: result);

    expect(built.plan.rooms.length, draft.rooms.length);
    for (final room in draft.rooms) {
      expect(built.plan.rooms.any((r) => r.name == room.name), isTrue);
    }
  });

  test('порядок комнат: прихожая, кухня, зал, санузел, балкон', () {
    final draft = sampleDraft();
    final result = core.CircuitCalculator(norms)
        .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
    final names =
        PlanAuto.build(draft: draft, result: result).plan.rooms.map((r) => r.name).toList();
    expect(names.first, 'Прихожая');
    expect(names.indexOf('Кухня'), lessThan(names.indexOf('Зал')));
    expect(names.indexOf('Санузел'), lessThan(names.indexOf('Балкон')));
  });

  test('щит стоит вне квартиры, слева от комнат', () {
    final draft = sampleDraft();
    final result = core.CircuitCalculator(norms)
        .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
    final plan = PlanAuto.build(draft: draft, result: result).plan;

    // Раньше щит был внутри прихожей; на бытовых планах он вынесен наружу.
    for (final room in plan.rooms) {
      expect(room.rect.contains(plan.panel.x, plan.panel.y), isFalse,
          reason: 'щит не должен стоять внутри комнаты ${room.name}');
    }
    final leftmost = plan.rooms
        .map((r) => r.rect.left)
        .reduce((a, b) => a < b ? a : b);
    expect(plan.panel.x, lessThan(leftmost));
  });

  test('точек столько же, сколько в проекте', () {
    final draft = sampleDraft();
    final result = core.CircuitCalculator(norms)
        .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
    final plan = PlanAuto.build(draft: draft, result: result).plan;

    final sockets = draft.rooms.fold<int>(0, (s, r) => s + r.socketsNormal);
    final switches =
        draft.rooms.fold<int>(0, (s, r) => s + r.switches);
    expect(
      plan.devices.where((d) => d.type == PlanPointType.socket).length,
      sockets,
    );
    expect(
      plan.devices.where((d) => d.type == PlanPointType.switchPoint).length,
      switches,
    );
  });

  test('комнаты не наезжают друг на друга', () {
    final draft = sampleDraft();
    final result = core.CircuitCalculator(norms)
        .calculate(projectOf(draft), socketLines: 2, lightingLines: 2);
    final plan = PlanAuto.build(draft: draft, result: result).plan;

    for (var i = 0; i < plan.rooms.length; i++) {
      for (var j = i + 1; j < plan.rooms.length; j++) {
        final a = plan.rooms[i].rect;
        final b = plan.rooms[j].rect;
        final ix = (a.right < b.right ? a.right : b.right) -
            (a.left > b.left ? a.left : b.left);
        final iy = (a.bottom < b.bottom ? a.bottom : b.bottom) -
            (a.top > b.top ? a.top : b.top);
        expect(ix <= 0.01 || iy <= 0.01, isTrue,
            reason: '${plan.rooms[i].name} и ${plan.rooms[j].name} пересекаются');
      }
    }
  });
}
