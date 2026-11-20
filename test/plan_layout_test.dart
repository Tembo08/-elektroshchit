import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/plan/plan_layout.dart';
import 'package:elektroshchit/plan/plan_walls.dart';

ProjectDraft draft(List<RoomDraft> rooms) => ProjectDraft(
      name: 'Квартира',
      objectType: core.ObjectType.apartment,
      rooms: rooms,
    );

void main() {
  group('планировка квартиры', () {
    test('все комнаты попадают на план и не пересекаются', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r0', name: 'Прихожая', type: core.RoomType.entrance, area: 5),
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 10),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 20),
        RoomDraft(id: 'r3', name: 'Санузел', type: core.RoomType.combinedBathroom, area: 4),
        RoomDraft(id: 'r4', name: 'Спальня', type: core.RoomType.bedroom, area: 14),
      ]));

      // Прихожая + 5 комнат (коридор добавляется отдельно, если есть место)
      final named = plan.rooms.map((r) => r.name).toList();
      expect(named, containsAll(['Прихожая', 'Кухня', 'Зал', 'Санузел', 'Спальня']));

      for (var i = 0; i < plan.rooms.length; i++) {
        for (var j = i + 1; j < plan.rooms.length; j++) {
          final a = plan.rooms[i].rect;
          final b = plan.rooms[j].rect;
          final ix = (a.right < b.right ? a.right : b.right) -
              (a.left > b.left ? a.left : b.left);
          final iy = (a.bottom < b.bottom ? a.bottom : b.bottom) -
              (a.top > b.top ? a.top : b.top);
          expect(ix <= 0.02 || iy <= 0.02, isTrue,
              reason: '${plan.rooms[i].name} и ${plan.rooms[j].name} пересекаются');
        }
      }
    });

    test('есть входная дверь и двери в комнаты', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r0', name: 'Прихожая', type: core.RoomType.entrance, area: 5),
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 10),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 20),
        RoomDraft(id: 'r3', name: 'Санузел', type: core.RoomType.combinedBathroom, area: 4),
      ]));

      expect(plan.doors.where((d) => d.entrance).length, 1,
          reason: 'входная дверь должна быть ровно одна');
      // Двери есть у каждой комнаты, кроме коридора (он открыт в прихожую).
      final withoutCorridor =
          plan.rooms.where((r) => r.name != 'Коридор').length;
      expect(plan.doors.length, greaterThanOrEqualTo(withoutCorridor));
    });

    test('балкон идёт полосой сверху и не пересекает комнаты', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 9),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 18),
        RoomDraft(id: 'r4', name: 'Балкон', type: core.RoomType.balcony, area: 3),
      ]));

      final balcony = plan.rooms.firstWhere((r) => r.type == core.RoomType.balcony);
      expect(balcony.rect.top, 0);
      expect(balcony.rect.height, closeTo(PlanLayout.balconyDepth, 0.01));

      final others = plan.rooms.where((r) => r.type != core.RoomType.balcony);
      for (final room in others) {
        expect(room.rect.top, greaterThanOrEqualTo(balcony.rect.bottom - 0.01),
            reason: 'комната ${room.name} залезла на балкон');
      }
    });

    test('жилые комнаты на фасаде, санузел — в глубине', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r0', name: 'Прихожая', type: core.RoomType.entrance, area: 5),
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 10),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 20),
        RoomDraft(id: 'r3', name: 'Санузел', type: core.RoomType.combinedBathroom, area: 4),
      ]));

      final living = plan.rooms.firstWhere((r) => r.name == 'Зал');
      final kitchen = plan.rooms.firstWhere((r) => r.name == 'Кухня');
      final bath = plan.rooms.firstWhere((r) => r.name == 'Санузел');

      expect(bath.rect.top, greaterThan(living.rect.top),
          reason: 'санузел должен быть глубже жилой зоны');
      expect(bath.rect.top, greaterThan(kitchen.rect.top));
    });

    test('стены не дублируются и проёмы есть', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r0', name: 'Прихожая', type: core.RoomType.entrance, area: 5),
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 10),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 20),
        RoomDraft(id: 'r3', name: 'Санузел', type: core.RoomType.combinedBathroom, area: 4),
      ]));

      expect(plan.walls, isNotEmpty);
      expect(plan.openings, isNotEmpty);

      // Одна и та же стена не должна встречаться дважды.
      final keys = plan.walls
          .map((w) => '${w.a.dx},${w.a.dy}-${w.b.dx},${w.b.dy}')
          .toList();
      expect(keys.toSet().length, keys.length, reason: 'есть дубли стен');

      // Входная дверь ровно одна.
      expect(
        plan.openings.where((o) => o.type == PlanOpeningType.entry).length,
        1,
      );
      // Окна — только у жилых и кухни.
      expect(
        plan.openings.where((o) => o.type == PlanOpeningType.window).length,
        greaterThanOrEqualTo(1),
      );
    });

    test('комнаты не превращаются в щели', () {
      final plan = PlanLayout.build(draft(const [
        RoomDraft(id: 'r1', name: 'Кухня', type: core.RoomType.kitchen, area: 10),
        RoomDraft(id: 'r2', name: 'Зал', type: core.RoomType.livingRoom, area: 20),
        RoomDraft(id: 'r3', name: 'Спальня', type: core.RoomType.bedroom, area: 14),
      ]));

      for (final room in plan.rooms) {
        final w = room.rect.width;
        final h = room.rect.height;
        expect(w, greaterThan(1.0), reason: '${room.name} слишком узкая');
        expect(h, greaterThan(1.0), reason: '${room.name} слишком низкая');
        // Коридор и балкон — вытянутые по определению.
        final elongated = room.type == core.RoomType.hallway ||
            room.type == core.RoomType.entrance ||
            room.type == core.RoomType.balcony;
        final ratio = w > h ? w / h : h / w;
        expect(ratio, lessThan(elongated ? 12.0 : 4.5),
            reason: '${room.name} — щель ${ratio.toStringAsFixed(1)}');
      }
    });
  });
}
