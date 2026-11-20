import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/plan/plan_geometry.dart';
import 'package:elektroshchit/plan/plan_models.dart';

FloorPlan samplePlan() => const FloorPlan(
      widthM: 8,
      heightM: 6,
      panel: PlanPanel(x: 0.5, y: 0.5),
      rooms: [
        PlanRoom(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          rect: PlanRect(left: 0, top: 0, width: 4, height: 3),
        ),
        PlanRoom(
          id: 'r2',
          name: 'Зал',
          type: core.RoomType.livingRoom,
          rect: PlanRect(left: 4, top: 0, width: 4, height: 3),
        ),
        PlanRoom(
          id: 'r3',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          rect: PlanRect(left: 0, top: 3, width: 2, height: 3),
        ),
      ],
      devices: [
        PlanDevice(id: 'd1', type: PlanPointType.socket, x: 3, y: 2, roomId: 'r1'),
        PlanDevice(id: 'd2', type: PlanPointType.socket, x: 7, y: 2, roomId: 'r2'),
        PlanDevice(id: 'd3', type: PlanPointType.light, x: 1, y: 1, roomId: 'r1'),
      ],
    );

void main() {
  group('геометрия плана', () {
    test('длина трассы — манхэттен с запасом', () {
      final plan = samplePlan();
      // от (0.5, 0.5) до (3, 2): 2.5 + 1.5 = 4 м, с запасом 1.15 → 4.6
      expect(
        PlanGeometry.routeLength(plan, plan.devices.first),
        closeTo(4.6, 0.001),
      );
    });

    test('длина комнаты — самая дальняя точка', () {
      final plan = samplePlan();
      // Кухня: (3,2) → 4.6 м, (1,1) → 1.15 м. Берём 4.6.
      expect(PlanGeometry.roomLength(plan, 'r1'), closeTo(4.6, 0.001));
      // Зал: от (0.5,0.5) до (7,2): 6.5 + 1.5 = 8 м, с запасом → 9.2
      expect(PlanGeometry.roomLength(plan, 'r2'), closeTo(9.2, 0.01));
      expect(PlanGeometry.roomLength(plan, 'нет такой'), 0);
    });

    test('привязка к сетке 0.25 м', () {
      expect(PlanGeometry.snap(1.13), closeTo(1.25, 0.001));
      expect(PlanGeometry.snap(1.11), closeTo(1.0, 0.001));
      expect(PlanGeometry.snap(2.0), closeTo(2.0, 0.001));
    });

    test('какая комната под точкой', () {
      final plan = samplePlan();
      expect(PlanGeometry.roomAt(plan, 1, 1)?.id, 'r1');
      expect(PlanGeometry.roomAt(plan, 5, 1)?.id, 'r2');
      expect(PlanGeometry.roomAt(plan, 5, 5), isNull, reason: 'пустое место');
    });

    test('поиск точки рядом', () {
      final plan = samplePlan();
      expect(PlanGeometry.deviceAt(plan, 3.1, 2.1)?.id, 'd1');
      expect(PlanGeometry.deviceAt(plan, 6, 5), isNull);
    });

    test('проверка границ и пересечений', () {
      final plan = samplePlan();
      expect(
        PlanGeometry.fits(plan, const PlanRect(left: 0, top: 0, width: 2, height: 2)),
        isTrue,
      );
      expect(
        PlanGeometry.fits(plan, const PlanRect(left: 7, top: 5, width: 3, height: 3)),
        isFalse,
      );
      expect(
        PlanGeometry.overlaps(
          plan,
          const PlanRect(left: 1, top: 1, width: 2, height: 2),
        ),
        isTrue,
      );
      expect(
        PlanGeometry.overlaps(
          plan,
          const PlanRect(left: 6, top: 3.5, width: 1.5, height: 2),
        ),
        isFalse,
      );
    });

    test('пачка розеток раскладывается в ряд с шагом 0.5 м', () {
      final plan = samplePlan().copyWith(devices: const []);
      final batch = PlanGeometry.placeBatch(
        plan: plan,
        roomId: 'r1',
        type: PlanPointType.socket,
        x: 0.5,
        y: 2.5,
        count: 4,
        idPrefix: 's',
      );
      expect(batch.length, 4);
      expect(batch.map((d) => d.x).toList(), [0.5, 1.0, 1.5, 2.0]);
      expect(batch.every((d) => d.y == 2.5), isTrue);
      expect(batch.every((d) => d.roomId == 'r1'), isTrue);
    });

    test('пачка переносится на строку ниже, если упирается в стену', () {
      final plan = samplePlan().copyWith(devices: const []);
      final batch = PlanGeometry.placeBatch(
        plan: plan,
        roomId: 'r1',
        type: PlanPointType.socket,
        x: 3.5,
        y: 0.5,
        count: 3,
        idPrefix: 's',
      );
      // Первая у правой стены, остальные уезжают на следующую строку.
      expect(batch.first.x, 3.5);
      expect(batch[1].y, greaterThan(batch.first.y));
      expect(batch[2].y, batch[1].y);
    });
  });

  group('сериализация плана', () {
    test('план переживает сохранение и загрузку', () {
      final plan = samplePlan();
      final restored = FloorPlan.fromJson(plan.toJson());

      expect(restored.widthM, 8);
      expect(restored.heightM, 6);
      expect(restored.rooms.length, 3);
      expect(restored.devices.length, 3);
      expect(restored.panel.x, 0.5);
      expect(restored.panel.y, 0.5);

      final kitchen = restored.rooms.first;
      expect(kitchen.name, 'Кухня');
      expect(kitchen.type, core.RoomType.kitchen);
      expect(kitchen.rect.width, 4);
      expect(restored.devices.first.type, PlanPointType.socket);
    });

    test('битые данные не роняют план', () {
      final plan = FloorPlan.fromJson({
        'w': null,
        'rooms': 'не список',
        'devices': [null, 42, {'id': 'ok', 'x': 1, 'y': 1, 'room': 'r1'}],
      });
      expect(plan.rooms, isEmpty);
      expect(plan.devices.length, 1);
      expect(plan.devices.first.id, 'ok');
    });
  });
}
