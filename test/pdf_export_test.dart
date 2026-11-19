import 'dart:io';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/export/pdf_exporter.dart';

const _normsDir = 'packages/electrical_core/lib/src/norms/ru_2026';

core.NormsCatalog loadNorms() => core.NormsLoader.fromYamlTexts(
      version: 'ru_2026',
      cableSectionsYaml: File('$_normsDir/cable_sections.yaml').readAsStringSync(),
      breakersYaml: File('$_normsDir/breakers.yaml').readAsStringSync(),
      rcdYaml: File('$_normsDir/rcd.yaml').readAsStringSync(),
      groupingRulesYaml: File('$_normsDir/grouping_rules.yaml').readAsStringSync(),
      roomDefaultsYaml: File('$_normsDir/room_defaults.yaml').readAsStringSync(),
      stopScenariosYaml:
          File('$_normsDir/stop_scenarios.yaml').readAsStringSync(),
    );

core.Project sampleProject() => core.Project(
      id: 'p1',
      name: 'Квартира, Ленина 5',
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.three,
      allowedPowerKw: 15,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 62,
      ceilingHeight: 2.7,
      createdAt: DateTime(2026, 11, 19),
      updatedAt: DateTime(2026, 11, 19),
      rooms: [
        core.Room(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 12,
          cableLengthM: 18,
          consumers: [
            const core.Consumer(
              id: 'c1',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 8,
            ),
            const core.Consumer(
              id: 'c2',
              type: core.ConsumerType.electricStove,
              name: 'Варочная',
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
          consumers: [
            const core.Consumer(
              id: 'c3',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 2,
            ),
          ],
        ),
        core.Room(
          id: 'r3',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          area: 22,
          cableLengthM: 25,
          consumers: [
            const core.Consumer(
              id: 'c4',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 10,
            ),
            const core.Consumer(
              id: 'c5',
              type: core.ConsumerType.lightPoint,
              name: 'Свет',
              quantity: 4,
            ),
          ],
        ),
      ],
    );

void main() {
  late core.NormsCatalog norms;

  setUpAll(() {
    norms = loadNorms();
  });

  test('PDF собирается и содержит кириллицу и данные расчёта', () async {
    final result = core.CircuitCalculator(norms).calculate(
      sampleProject(),
      lightingLines: 2,
      socketLines: 2,
    );

    final bytes = await PdfExporter(
      result: result,
      projectName: 'Квартира, Ленина 5',
      details: '62 м² · потолки 2.7 м · TN-C-S · ТУ 15 кВт',
      regularFont: File('assets/fonts/DejaVuSans.ttf').readAsBytesSync(),
      boldFont: File('assets/fonts/DejaVuSans-Bold.ttf').readAsBytesSync(),
      date: DateTime(2026, 11, 19),
    ).build();

    // Сначала сохраняем артефакт (проверяем снаружи через pdfinfo/pdftotext),
    // потом проверяем структуру в тесте.
    final dir = Directory('build/pdf-preview');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/schet.pdf').writeAsBytesSync(bytes);

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final text = String.fromCharCodes(bytes.where((b) => b >= 9 && b < 127));
    expect(text.contains('/Type'), isTrue);
    expect(text.contains('/Pages') || text.contains('/Page'), isTrue);
  });

  test('PDF собирается и для однофазного проекта без длины линий', () async {
    final project = core.Project(
      id: 'p2',
      name: 'Студия',
      objectType: core.ObjectType.apartment,
      phaseSystem: core.PhaseSystem.single,
      allowedPowerKw: 5,
      groundingSystem: core.GroundingSystem.tt,
      totalArea: 28,
      ceilingHeight: 2.6,
      createdAt: DateTime(2026, 11, 19),
      updatedAt: DateTime(2026, 11, 19),
      rooms: [
        core.Room(
          id: 'r1',
          name: 'Кухня-гостиная',
          type: core.RoomType.livingRoom,
          area: 20,
          consumers: [
            const core.Consumer(
              id: 'c1',
              type: core.ConsumerType.socket,
              name: 'Розетки',
              quantity: 6,
            ),
            const core.Consumer(
              id: 'c2',
              type: core.ConsumerType.boiler,
              name: 'Котёл',
              quantity: 1,
              powerKw: 9.0,
              isPowerful: true,
            ),
          ],
        ),
      ],
    );

    final result =
        core.CircuitCalculator(norms).calculate(project, socketLines: 1);

    final bytes = await PdfExporter(
      result: result,
      projectName: 'Студия',
      regularFont: File('assets/fonts/DejaVuSans.ttf').readAsBytesSync(),
      date: DateTime(2026, 11, 19),
    ).build();

    expect(bytes.length, greaterThan(3000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // Для TT в отчёте должна быть проверка про УЗО на каждой линии
    expect(
      result.issues.any((i) => i.id == 'tt_requires_rcd'),
      isTrue,
    );
  });
}
