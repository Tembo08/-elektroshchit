import 'dart:math' as math;

import 'package:electrical_core/electrical_core.dart' as core;

import 'package:flutter/material.dart' show Offset, Size;
import 'package:treemap/treemap.dart';

import '../core/project_draft.dart';
import 'plan_models.dart';
import 'plan_walls.dart';

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

  /// Толщина стен/перегородок, м (совпадает с PlanWalls).
  static const thickness = PlanWalls.thickness;

  /// Ширина входной двери, м.
  static const entryWidth = PlanWalls.entryWidth;

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

    double areaOf(RoomDraft r) => r.area > 0 ? r.area : _defaultArea(r.type);

    // Балкон живёт полосой за внешней стеной, в раскладке не участвует.
    final balcony =
        rooms.where((r) => r.type == core.RoomType.balcony).firstOrNull;
    final inside =
        rooms.where((r) => r.type != core.RoomType.balcony).toList();

    // Фасад: жилые комнаты и кухня (им нужны окна).
    final front = inside
        .where((r) =>
            _living.contains(r.type) || r.type == core.RoomType.kitchen)
        .toList();
    // Средняя полоса: прихожая, коридор, санузлы и прочее без окон.
    final hall = inside
        .where((r) =>
            r.type == core.RoomType.entrance ||
            r.type == core.RoomType.hallway)
        .toList();
    final service = inside
        .where((r) =>
            _service.contains(r.type) &&
            r.type != core.RoomType.entrance &&
            r.type != core.RoomType.hallway)
        .toList();
    // Комнаты, которые не попали ни в одну полосу (редкий тип).
    final rest = inside
        .where((r) => !front.contains(r) && !hall.contains(r) && !service.contains(r))
        .toList();

    final frontArea = front.fold<double>(0, (s, r) => s + areaOf(r));
    final backArea = [...hall, ...service, ...rest]
        .fold<double>(0, (s, r) => s + areaOf(r));

    // Габариты: ширину задаёт пропорция квартиры, глубину — площади полос.
    final totalArea = frontArea + backArea;
    final ratio = totalArea < 40
        ? 1.25
        : totalArea < 70
            ? 1.5
            : 1.7;
    var width = math.sqrt(totalArea * ratio);
    width = width.clamp(4.5, 14.0);

    final frontDepth = front.isEmpty
        ? 0.0
        : (frontArea / width).clamp(3.0, 5.5);
    // 1.5 м коридора добавляем к площади полосы, чтобы он не съедал комнаты.
    final bandArea = backArea + width * corridorWidth * 0.55;
    final bandHeight = (bandArea / width).clamp(1.8, 3.4);

    final top = balcony != null ? balconyDepth + thickness : 0.0;
    const noOrder = <String, int>{};

    // ── фасадная полоса ─────────────────────────────────────────
    final frontRooms = _pack(
      rooms: front,
      left: 0,
      top: top,
      width: width,
      height: frontDepth,
      areaOf: areaOf,
      order: noOrder,
    );

    // ── средняя полоса: прихожая + сервис + коридор ─────────────
    final corridorArea = width * 1.5;
    final bandRooms = <RoomDraft>[
      ...hall,
      ...service,
      ...rest,
      RoomDraft(
        id: 'corridor_auto',
        name: 'Коридор',
        type: core.RoomType.hallway,
        area: corridorArea,
      ),
    ];

    final band = _pack(
      rooms: bandRooms,
      left: 0,
      top: top + frontDepth,
      width: width,
      height: bandHeight,
      areaOf: areaOf,
      order: noOrder,
    );

    final planRooms = [...frontRooms, ...band];
    final doors = <PlanDoor>[];

    // ── двери ───────────────────────────────────────────────────
    // Дверь ставим на общую границу с коридором/прихожей; если такой нет —
    // на границу с соседом, у которого дверь уже есть.
    final corridorRooms = planRooms
        .where((r) =>
            r.type == core.RoomType.hallway ||
            r.type == core.RoomType.entrance)
        .toList();
    // Двери ставим обходом графа соседства от коридора: так каждая комната
    // получает дверь, и не появляется проход «кухня — санузел».
    final visited = <String>{for (final c in corridorRooms) c.id};
    var frontier = [...corridorRooms];

    while (frontier.isNotEmpty) {
      final next = <PlanRoom>[];
      for (final from in frontier) {
        for (final room in planRooms) {
          if (visited.contains(room.id)) continue;
          if (_forbiddenPair(from.type, room.type)) continue;
          final door = PlanWalls.doorBetween(from.rect, room.rect);
          if (door == null) continue;
          doors.add(_doorFrom(door));
          visited.add(room.id);
          next.add(room);
        }
      }
      frontier = next;
    }

    // Комнаты, до которых не добрались (нет общей стены) — дверь в коридор
    // по ближайшей стене, чтобы без двери никто не остался.
    for (final room in planRooms) {
      if (visited.contains(room.id)) continue;
      final host = corridorRooms.firstOrNull;
      if (host == null) continue;
      final door = PlanWalls.doorBetween(
        room.rect,
        host.rect,
        width: PlanWalls.entryWidth,
      );
      if (door != null) doors.add(_doorFrom(door));
    }

    // Входная дверь — в прихожую (или в коридор) на левой наружной стене.
    final entrance = corridorRooms.firstOrNull;
    if (entrance != null) {
      doors.add(PlanDoor(
        x: _q(entrance.rect.left),
        y: _q(entrance.rect.center.dy - entryWidth / 2),
        width: entryWidth,
        horizontal: false,
        entrance: true,
      ));
    }

    // ── стены и проёмы ──────────────────────────────────────────
    final wallsBuilt = PlanWalls.build(
      rooms: planRooms,
      hostOf: (room) {
        // окна — только жилым комнатам и кухне
        final isLiving = _living.contains(room.type) ||
            room.type == core.RoomType.kitchen;
        return isLiving ? room.id : null;
      },
    );

    final openings = <PlanOpening>[
      ...wallsBuilt.openings,
      // дверные проёмы из PlanDoor переводим в проёмы стен
      for (final door in doors)
        PlanOpening(
          a: Offset(door.x, door.y),
          b: door.horizontal
              ? Offset(door.x + door.width, door.y)
              : Offset(door.x, door.y + door.width),
          type: door.entrance
              ? PlanOpeningType.entry
              : PlanOpeningType.door,
        ),
    ];

    // ── балкон ──────────────────────────────────────────────────
    if (balcony != null) {
      final host = frontRooms
              .where((r) => _living.contains(r.type))
              .firstOrNull ??
          frontRooms.firstOrNull;
      if (host != null) {
        planRooms.add(PlanRoom(
          id: balcony.id,
          name: balcony.name,
          type: balcony.type,
          rect: PlanRect(
            left: host.rect.left,
            top: 0,
            width: host.rect.width,
            height: balconyDepth,
          ),
        ));
        openings.add(PlanOpening(
          a: Offset(host.rect.center.dx - 0.4, top),
          b: Offset(host.rect.center.dx + 0.4, top),
        ));
      }
    }

    final maxBottom =
        planRooms.map((r) => r.rect.bottom).reduce((a, b) => a > b ? a : b);
    final maxRight =
        planRooms.map((r) => r.rect.right).reduce((a, b) => a > b ? a : b);

    return FloorPlan(
      widthM: _q(maxRight + thickness),
      heightM: _q(maxBottom + thickness),
      rooms: planRooms,
      doors: doors,
      walls: wallsBuilt.walls,
      openings: openings,
      panel: PlanPanel(x: _q(0.5), y: _q(top + frontDepth + bandHeight / 2)),
      corridorY: _q(top + frontDepth + bandHeight / 2),
    );
  }

  static List<PlanRoom> _pack({
    required List<RoomDraft> rooms,
    required double left,
    required double top,
    required double width,
    required double height,
    required double Function(RoomDraft) areaOf,
    required Map<String, int> order,
  }) {
    if (rooms.isEmpty) return const [];

    final arranged = [...rooms];
    arranged.sort((a, b) => areaOf(b).compareTo(areaOf(a)));

    final tree = TreeMap(
      root: TreeNode.node(children: [
        for (final room in arranged) TreeNode.leaf(value: areaOf(room)),
      ]),
      size: Size(width, height),
      tile: const Squarify(),
    );

    final leaves = tree.leaves;
    final result = <PlanRoom>[];
    for (var i = 0; i < arranged.length && i < leaves.length; i++) {
      final leaf = leaves[i];
      final room = arranged[i];
      // Округляем только края, а ширину считаем как разницу: иначе соседние
      // комнаты «наезжают» друг на друга на 0.05 из-за двойного округления.
      final l = _q(left + leaf.left);
      final r = _q(left + leaf.right);
      final t = _q(top + leaf.top);
      final b = _q(top + leaf.bottom);
      result.add(PlanRoom(
        id: room.id,
        name: room.name,
        type: room.type,
        rect: PlanRect(left: l, top: t, width: r - l, height: b - t),
      ));
    }
    return result;
  }

  /// Пары, между которыми дверь не ставим (кухня — санузел).
  static bool _forbiddenPair(core.RoomType a, core.RoomType b) {
    bool wet(core.RoomType t) =>
        t == core.RoomType.bathroom ||
        t == core.RoomType.combinedBathroom ||
        t == core.RoomType.toilet;
    bool cook(core.RoomType t) => t == core.RoomType.kitchen;
    return (wet(a) && cook(b)) || (cook(a) && wet(b));
  }

  static PlanDoor _doorFrom(PlanOpening door) => PlanDoor(
        x: _q(door.a.dx),
        y: _q(door.a.dy),
        width: _q(door.width),
        horizontal: door.horizontal,
      );

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
