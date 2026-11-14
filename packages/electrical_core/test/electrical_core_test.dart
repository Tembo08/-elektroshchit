import 'dart:io';

import 'package:electrical_core/electrical_core.dart';
import 'package:test/test.dart';

void main() {
  late NormsCatalog norms;

  setUpAll(() {
    final base = 'lib/src/norms/ru_2026';
    norms = NormsLoader.fromYamlTexts(
      version: 'ru_2026',
      cableSectionsYaml: File('$base/cable_sections.yaml').readAsStringSync(),
      breakersYaml: File('$base/breakers.yaml').readAsStringSync(),
      rcdYaml: File('$base/rcd.yaml').readAsStringSync(),
      groupingRulesYaml: File('$base/grouping_rules.yaml').readAsStringSync(),
    );
  });

  test('norms load', () {
    expect(norms.cableSections, isNotEmpty);
    expect(norms.defaultRcdMa, 30);
  });

  test('lighting and sockets share parent RCDs', () {
    final now = DateTime.now();
    final project = Project(
      id: 'p1',
      name: 'Тест',
      objectType: ObjectType.apartment,
      phaseSystem: PhaseSystem.single,
      allowedPowerKw: 7,
      groundingSystem: GroundingSystem.tnCs,
      totalArea: 45,
      ceilingHeight: 2.7,
      lightingGrouping: LightingGrouping.twoZones,
      createdAt: now,
      updatedAt: now,
      rooms: [
        Room(
          id: 'r1',
          name: 'Комната',
          type: RoomType.livingRoom,
          area: 18,
          consumers: const [
            Consumer(
              id: 'c1',
              type: ConsumerType.socket,
              name: 'Розетки',
              quantity: 4,
            ),
            Consumer(
              id: 'c2',
              type: ConsumerType.lightPoint,
              name: 'Свет',
              quantity: 3,
            ),
          ],
        ),
        Room(
          id: 'r2',
          name: 'Кухня',
          type: RoomType.kitchen,
          area: 10,
          consumers: const [
            Consumer(
              id: 'c3',
              type: ConsumerType.socket,
              name: 'Розетки',
              quantity: 4,
            ),
            Consumer(
              id: 'c4',
              type: ConsumerType.lightPoint,
              name: 'Свет',
              quantity: 2,
            ),
          ],
        ),
      ],
    );

    final result = CircuitCalculator(norms).calculate(
      project,
      lightingLines: 2,
      socketLines: 2,
    );

    // Есть УЗО-родители
    expect(result.panel.protectionDevices, isNotEmpty);
    final lightRcd = result.panel.protectionDevices
        .where((d) => d.name.contains('освещение'));
    final sockRcd = result.panel.protectionDevices
        .where((d) => d.name.contains('розетки'));
    expect(lightRcd, isNotEmpty);
    expect(sockRcd, isNotEmpty);

    // Линии света без собственного УЗО, но с parentRcdId
    final lightGroups =
        result.groups.where((g) => g.name.contains('Освещение'));
    expect(lightGroups, isNotEmpty);
    for (final g in lightGroups) {
      expect(g.parentRcdId, isNotNull);
      expect(g.hasRcd, isFalse);
    }
  });

  test('washer is separate powerful line min 16A', () {
    final now = DateTime.now();
    final project = Project(
      id: 'p2',
      name: 'Стиралка',
      objectType: ObjectType.apartment,
      phaseSystem: PhaseSystem.single,
      allowedPowerKw: 7,
      groundingSystem: GroundingSystem.tnCs,
      totalArea: 40,
      ceilingHeight: 2.7,
      createdAt: now,
      updatedAt: now,
      rooms: [
        Room(
          id: 'r1',
          name: 'Ванная',
          type: RoomType.bathroom,
          area: 4,
          consumers: const [
            Consumer(
              id: 'c1',
              type: ConsumerType.washingMachine,
              name: 'Стиралка',
              quantity: 1,
              powerKw: 2.0,
              isPowerful: true,
              requiresRcd: true,
            ),
          ],
        ),
      ],
    );

    final result = CircuitCalculator(norms).calculate(project);
    final washer = result.groups.where((g) => g.name.contains('Стиралка'));
    expect(washer, isNotEmpty);
    expect(washer.first.breakerAmps, greaterThanOrEqualTo(16));
  });

  test('bathroom sockets get 10mA parent RCD', () {
    final now = DateTime.now();
    final project = Project(
      id: 'p3',
      name: 'С/у',
      objectType: ObjectType.apartment,
      phaseSystem: PhaseSystem.single,
      allowedPowerKw: 7,
      groundingSystem: GroundingSystem.tnCs,
      totalArea: 40,
      ceilingHeight: 2.7,
      createdAt: now,
      updatedAt: now,
      rooms: [
        Room(
          id: 'r1',
          name: 'Ванная',
          type: RoomType.bathroom,
          area: 4,
          consumers: const [
            Consumer(
              id: 'c1',
              type: ConsumerType.socket,
              name: 'Зеркало',
              quantity: 1,
              requiresRcd: true,
            ),
          ],
        ),
      ],
    );

    final result = CircuitCalculator(norms).calculate(project);
    final bathRcd = result.panel.protectionDevices
        .where((d) => d.rcdMa == 10);
    expect(bathRcd, isNotEmpty);
  });
}
