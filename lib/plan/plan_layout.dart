import 'dart:math' as math;

import 'package:electrical_core/electrical_core.dart' as core;

import '../core/project_draft.dart';
import 'plan_models.dart';

/// Планировка квартиры: правильная геометрия помещений.
///
/// Алгоритм по ТЗ проектировщика (V4 Pro): считаем габариты из суммы
/// площадей, ставим коридорную полосу между «фасадной» и «глухой» зонами,
/// на фасад выносим жилые комнаты и кухню, в глубину — санузел и прихожую.
/// Вход — с короткой стороны, в прихожую; двери — из коридора.
class PlanLayout {
  /// Толщина стен и перегородок, м (для отрисовки).
  static const wall = 0.12;

  /// Ширина коридорной полосы, м.
  static const corridorWidth = 1.5;

  /// Глубина балкона, м.
  static const balconyDepth = 1.1;

  static const _living = {
    core.RoomType.livingRoom,
    core.RoomType.bedroom,
    core.RoomType.childrenRoom,
  };
  static const _service = {
    core.RoomType.bathroom,
    core.RoomType.combinedBathroom,
    core.RoomType.toilet,
    core.RoomType.pantry,
    core.RoomType.technical,
  };

  /// Строит планировку по списку комнат черновика.
  static FloorPlan build(ProjectDraft draft) {
    final rooms = [...draft.rooms];
    if (rooms.isEmpty) {
      return const FloorPlan(widthM: 6, heightM: 4);
    }

    // Балкон выносим отдельно: он живёт полосой за внешней стеной.
    final balcony = rooms
        .where((r) => r.type == core.RoomType.balcony)
        .firstOrNull;
    final inside = rooms.where((r) => r.type != core.RoomType.balcony).toList();

    // Площади: если пользователь не ввёл — берём типовые.
    double areaOf(RoomDraft r) => r.area > 0 ? r.area : _defaultArea(r.type);

    final livingRooms =
        inside.where((r) => _living.contains(r.type)).toList();
    final kitchen = inside.where((r) => r.type == core.RoomType.kitchen).toList();
    final service = inside.where((r) => _service.contains(r.type)).toList();
    final hall = inside
        .where((r) =>
            r.type == core.RoomType.entrance ||
            r.type == core.RoomType.hallway)
        .toList();

    // Фасадная полоса: жилые комнаты + кухня (у них должны быть окна).
    final front = [...livingRooms, ...kitchen];
    final frontArea = front.fold<double>(0, (s, r) => s + areaOf(r));

    // Глухая полоса: санузлы и прочее без окон + прихожая.
    final back = [...service, ...hall];
    final backArea = back.fold<double>(0, (s, r) => s + areaOf(r));

    // Ширину листа задаёт фасадная полоса (глубина ~4.2 м), но не меньше
    // суммы минимальных ширин: иначе кухня станет щелью.
    const frontDepthTarget = 4.2;
    var minFrontWidth = 0.0;
    for (final room in front) {
      minFrontWidth += _minWidth(room.type);
    }
    var width = frontArea > 0 ? frontArea / frontDepthTarget : 4.0;
    if (width < minFrontWidth) width = minFrontWidth;
    width = math.max(width, 4.0);

    final frontDepth = frontArea > 0
        ? (frontArea / width).clamp(3.0, 5.5)
        : 0.0;

    // Сервисные помещения и прихожая живут в средней полосе вместе с
    // коридором. Отдельная «задняя» полоса при одном санузле превращалась
    // в кладовую на 15 м².
    // Высота средней полосы — стандартные 1.8 м (коридор/прихожая/санузел).
    // Больше делать нельзя: коридор разрастается до 20 м².
    final bandHeight = backArea > 0 ? 1.8 : corridorWidth;

    final planRooms = <PlanRoom>[];
    final doors = <PlanDoor>[];

    // Если есть балкон — фасадная полоса начинается ниже него, иначе
    // балкон уезжает в отрицательные координаты и ломает двери.
    final top = balcony != null ? balconyDepth + wall : 0.0;

    // ── фасадная полоса ─────────────────────────────────────────
    var x = 0.0;
    for (var i = 0; i < front.length; i++) {
      final room = front[i];
      final area = areaOf(room);
      // Ширина из площади, с минимумом по типу и добором остатка.
      // Ширина = площадь / глубина. Минимум учитываем при выборе глубины,
      // а не растягиванием комнаты (иначе соседние наезжают друг на друга).
      final isLast = i == front.length - 1;
      var w = area / frontDepth;
      if (isLast) w = width - x;
      if (x + w > width) w = width - x;

      final left = _q(x);
      final right = _q(x + w);
      planRooms.add(PlanRoom(
        id: room.id,
        name: room.name,
        type: room.type,
        rect: PlanRect(
          left: left,
          top: _q(top),
          width: right - left,
          height: _q(frontDepth),
        ),
      ));

      // Дверь снизу — из коридора.
      doors.add(PlanDoor(
        x: _q(x + w / 2 - 0.4),
        y: _q(top + frontDepth),
        width: 0.8,
        horizontal: true,
      ));

      x = right;
    }

    // ── коридорная полоса ───────────────────────────────────────
    final corridorY = top + frontDepth;
    final corridorHeight = bandHeight;

    // Прихожая — левая часть полосы (в неё входит входная дверь).
    var corridorX = 0.0;
    for (final room in hall) {
      final w = math.max(1.8, areaOf(room) / corridorHeight);
      planRooms.add(PlanRoom(
        id: room.id,
        name: room.name,
        type: room.type,
        rect: PlanRect(
          left: _q(corridorX),
          top: _q(corridorY),
          width: _q(math.min(w, width - corridorX)),
          height: _q(corridorHeight),
        ),
      ));
      corridorX += math.min(w, width - corridorX);
    }

    // Сервисные помещения (санузел и прочее) — следом за прихожей.
    for (final room in service) {
      final w = math.min(
        math.max(1.4, areaOf(room) / corridorHeight),
        width - corridorX,
      );
      if (w < 0.9) break;
      planRooms.add(PlanRoom(
        id: room.id,
        name: room.name,
        type: room.type,
        rect: PlanRect(
          left: _q(corridorX),
          top: _q(corridorY),
          width: _q(w),
          height: _q(corridorHeight),
        ),
      ));
      // Дверь в коридор — слева от помещения.
      doors.add(PlanDoor(
        x: _q(corridorX),
        y: _q(corridorY + corridorHeight / 2 - 0.35),
        width: 0.7,
        horizontal: false,
      ));
      corridorX += w;
    }

    // Остаток полосы — коридор (имя не занято — добавляем свой).
    if (corridorX < width - 0.6) {
      planRooms.add(PlanRoom(
        id: 'corridor_auto',
        name: 'Коридор',
        type: core.RoomType.hallway,
        rect: PlanRect(
          left: _q(corridorX),
          top: _q(corridorY),
          width: _q(width - corridorX),
          height: _q(corridorHeight),
        ),
      ));
    }

    // Входная дверь — в прихожую, с короткой стороны (левая стена).
    final entranceRoom = planRooms
        .where((r) =>
            r.type == core.RoomType.entrance ||
            r.type == core.RoomType.hallway)
        .firstOrNull;
    if (entranceRoom != null) {
      doors.add(PlanDoor(
        x: _q(entranceRoom.rect.left),
        y: _q(entranceRoom.rect.top + entranceRoom.rect.height / 2 - 0.5),
        width: 1.0,
        horizontal: false,
        entrance: true,
      ));
    } else {
      // Прихожей нет — вход ставим в коридор, на левую стену.
      doors.add(PlanDoor(
        x: 0,
        y: _q(corridorY + corridorHeight / 2 - 0.5),
        width: 1.0,
        horizontal: false,
        entrance: true,
      ));
    }

    // ── балкон ──────────────────────────────────────────────────
    if (balcony != null) {
      // Полоса за фасадной стеной, над залом (или над первой жилой).
      final host = planRooms
              .where((r) => _living.contains(r.type))
              .firstOrNull ??
          planRooms.first;
      planRooms.add(PlanRoom(
        id: balcony.id,
        name: balcony.name,
        type: balcony.type,
        rect: PlanRect(
          left: _q(host.rect.left),
          top: 0,
          width: _q(host.rect.width),
          height: balconyDepth,
        ),
      ));
      // Дверь на балкон — в верхней стене комнаты (в её нижнюю часть).
      doors.add(PlanDoor(
        x: _q(host.rect.left + host.rect.width / 2 - 0.4),
        y: _q(top),
        width: 0.8,
        horizontal: true,
      ));
    }

    final maxBottom = planRooms
        .map((r) => r.rect.bottom)
        .reduce((a, b) => a > b ? a : b);
    final maxRight = planRooms
        .map((r) => r.rect.right)
        .reduce((a, b) => a > b ? a : b);

    return FloorPlan(
      widthM: _q(maxRight + wall * 2),
      heightM: _q(maxBottom + wall * 2),
      rooms: planRooms,
      doors: doors,
      panel: PlanPanel(x: _q(0.6), y: _q(corridorY + corridorHeight / 2)),
      corridorY: _q(corridorY + corridorHeight / 2),
    );
  }

  static double _minWidth(core.RoomType type) => switch (type) {
        core.RoomType.livingRoom => 3.0,
        core.RoomType.bedroom => 2.4,
        core.RoomType.childrenRoom => 2.4,
        core.RoomType.kitchen => 2.2,
        core.RoomType.combinedBathroom => 1.5,
        core.RoomType.bathroom => 1.5,
        core.RoomType.toilet => 1.0,
        _ => 1.4,
      };

  static double _defaultArea(core.RoomType type) => switch (type) {
        core.RoomType.livingRoom => 18,
        core.RoomType.bedroom => 12,
        core.RoomType.childrenRoom => 11,
        core.RoomType.kitchen => 9,
        core.RoomType.bathroom || core.RoomType.combinedBathroom => 4,
        core.RoomType.toilet => 2,
        core.RoomType.entrance || core.RoomType.hallway => 5,
        core.RoomType.balcony => 3,
        _ => 8,
      };

  static double _q(double v) => (v * 20).roundToDouble() / 20;
}
