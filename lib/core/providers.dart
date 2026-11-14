import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electrical_core/electrical_core.dart' as core;

/// Загрузка норм из assets
final normsProvider = FutureProvider<core.NormsCatalog>((ref) async {
  final cable =
      await rootBundle.loadString('assets/norms/ru_2026/cable_sections.yaml');
  final breakers =
      await rootBundle.loadString('assets/norms/ru_2026/breakers.yaml');
  final rcd = await rootBundle.loadString('assets/norms/ru_2026/rcd.yaml');
  final grouping =
      await rootBundle.loadString('assets/norms/ru_2026/grouping_rules.yaml');
  final roomDefaults =
      await rootBundle.loadString('assets/norms/ru_2026/room_defaults.yaml');

  return core.NormsLoader.fromYamlTexts(
    version: 'ru_2026',
    cableSectionsYaml: cable,
    breakersYaml: breakers,
    rcdYaml: rcd,
    groupingRulesYaml: grouping,
    roomDefaultsYaml: roomDefaults,
  );
});

/// Демо-проект (кухня) для первого экрана
core.Project buildDemoProject() {
  final now = DateTime.now();
  return core.Project(
    id: 'demo_1',
    name: 'Демо: кухня 1к',
    objectType: core.ObjectType.apartment,
    phaseSystem: core.PhaseSystem.single,
    allowedPowerKw: 7,
    groundingSystem: core.GroundingSystem.tnCs,
    totalArea: 35,
    ceilingHeight: 2.7,
    createdAt: now,
    updatedAt: now,
    rooms: [
      core.Room(
        id: 'r1',
        name: 'Кухня',
        type: core.RoomType.kitchen,
        area: 10,
        consumers: const [
          core.Consumer(
            id: 'c1',
            type: core.ConsumerType.socket,
            name: 'Розетки',
            quantity: 6,
          ),
          core.Consumer(
            id: 'c2',
            type: core.ConsumerType.washingMachine,
            name: 'Стиралка',
            powerKw: 2.0,
            isPowerful: true,
            requiresRcd: true,
          ),
          core.Consumer(
            id: 'c3',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: 2,
          ),
        ],
      ),
    ],
  );
}
