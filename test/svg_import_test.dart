import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/plan/plan_models.dart';
import 'package:elektroshchit/plan/svg_import.dart';

void main() {
  group('импорт плана из Corel/Inkscape', () {
    late SvgImportResult result;

    setUpAll(() {
      final svg = File('test/fixtures/plan.svg').readAsStringSync();
      result = SvgPlanImport.parse(svg);
    });

    test('стены, проёмы и символы разобраны по слоям', () {
      // rect 4 стороны + 2 линии = 6 отрезков
      expect(result.wallsCount, 6);
      expect(result.doorsCount, 2);
      expect(result.windowsCount, 1);
      expect(result.sockets, 3);
      expect(result.lights, 1);
      expect(result.switches, 1);
    });

    test('миллиметры документа переводятся в метры', () {
      // документ 8000×6000 мм, стена начинается от 100 мм
      expect(result.plan.widthM, closeTo(7.9, 0.05));
      expect(result.plan.heightM, closeTo(5.9, 0.05));

      // розетка в точке (1000, 1200) мм → (1.0, 1.2) м
      final socket = result.plan.devices
          .firstWhere((d) => d.type == PlanPointType.socket);
      expect(socket.x, closeTo(1.0, 0.01));
      expect(socket.y, closeTo(1.2, 0.01));
    });

    test('щит и двери попадают в план', () {
      expect(result.plan.panel.x, closeTo(0.45, 0.02));
      expect(result.plan.panel.y, closeTo(3.4, 0.02));
      expect(result.plan.openings, isNotEmpty);
    });

    test('пустой документ даёт предупреждение, а не падение', () {
      final empty = SvgPlanImport.parse(
        '<svg xmlns="http://www.w3.org/2000/svg" width="100mm" '
        'height="100mm" viewBox="0 0 100 100"></svg>',
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.warnings, isNotEmpty);
    });
  });
}
