import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/plan/plan_geometry.dart';
import 'package:elektroshchit/plan/plan_seed.dart';

ProjectDraft draftWith(List<RoomDraft> rooms) => ProjectDraft(
      name: 'Квартира',
      objectType: core.ObjectType.apartment,
      totalArea: 62,
      rooms: rooms,
    );

void main() {
  group('план из проекта', () {
    test('комнаты проекта попадают на план', () {
      final plan = PlanSeed.fromDraft(draftWith(const [
        RoomDraft(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          area: 12,
        ),
        RoomDraft(
          id: 'r2',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
        ),
      ]));
      expect(plan.rooms.any((r) => r.name == 'Кухня'), isTrue);
      expect(plan.rooms.any((r) => r.name == 'Санузел'), isTrue);
    });

    test('добавляет зал и прихожую, если их нет', () {
      final plan = PlanSeed.fromDraft(draftWith(const [
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen),
      ]));
      expect(plan.rooms.any((r) => r.type == core.RoomType.livingRoom), isTrue,
          reason: 'зал должен добавиться');
      expect(plan.rooms.any((r) => r.type == core.RoomType.entrance), isTrue,
          reason: 'прихожая должна добавиться');
    });

    test('комнаты не наезжают друг на друга и влезают в лист', () {
      final plan = PlanSeed.fromDraft(draftWith(const [
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 12),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 22),
        RoomDraft(
          id: 'r3',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          area: 4,
        ),
        RoomDraft(
          id: 'r4',
          name: 'Спальня',
          type: core.RoomType.bedroom,
          area: 14,
        ),
      ]));

      for (final room in plan.rooms) {
        expect(PlanGeometry.fits(plan, room.rect), isTrue,
            reason: '${room.name} вылезла за лист');
        expect(
          PlanGeometry.overlaps(plan, room.rect, ignoreId: room.id),
          isFalse,
          reason: '${room.name} наезжает на другую комнату',
        );
      }
    });

    test('площади комнат сохраняются в размерах', () {
      final plan = PlanSeed.fromDraft(draftWith(const [
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 12),
      ]));
      final kitchen = plan.rooms.firstWhere((r) => r.name == 'Кухня');
      expect(kitchen.rect.area, closeTo(12, 1.5));
    });
  });
}
