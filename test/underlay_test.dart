import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/plan/plan_models.dart';

void main() {
  group('подложка плана', () {
    test('масштаб, картинка и точки сохраняются в JSON', () {
      const plan = FloorPlan(
        widthM: 8,
        heightM: 6,
        underlayPath: '/tmp/plan.png',
        underlayWidthPx: 1600,
        underlayHeightPx: 1200,
        metersPerPixel: 0.005,
        devices: [
          PlanDevice(
            id: 'u1',
            roomId: 'underlay',
            type: PlanPointType.socket,
            x: 2.5,
            y: 3.0,
          ),
          PlanDevice(
            id: 'u2',
            roomId: 'underlay',
            type: PlanPointType.light,
            x: 4.0,
            y: 1.5,
          ),
        ],
      );

      final restored = FloorPlan.fromJson(plan.toJson());

      expect(restored.underlayPath, '/tmp/plan.png');
      expect(restored.underlayWidthPx, 1600);
      expect(restored.underlayHeightPx, 1200);
      expect(restored.metersPerPixel, closeTo(0.005, 1e-9));
      expect(restored.devices.length, 2);
      expect(restored.devices.first.type, PlanPointType.socket);
      expect(restored.devices.last.x, closeTo(4.0, 1e-9));
    });

    test('метры считаются из пикселей и масштаба', () {
      // 1 м = 200 px → точка на 600 px правее это 3 м
      const mpp = 0.005;
      final meters = 600 * mpp;
      expect(meters, closeTo(3.0, 1e-9));

      // габариты картинки 1600×1200 px → 8×6 м
      expect(1600 * mpp, closeTo(8.0, 1e-9));
      expect(1200 * mpp, closeTo(6.0, 1e-9));
    });

    test('без картинки план остаётся рабочим', () {
      const plan = FloorPlan(widthM: 5, heightM: 4);
      expect(plan.underlayPath, isNull);
      expect(plan.metersPerPixel, 0);
      expect(plan.devices, isEmpty);
    });
  });
}
