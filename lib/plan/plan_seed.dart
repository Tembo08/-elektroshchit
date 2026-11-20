import 'dart:math' as math;

import 'package:electrical_core/electrical_core.dart' as core;

import '../core/project_draft.dart';
import 'plan_models.dart';

/// Собирает план из комнат проекта, чтобы проектировщику не рисовать
/// квартиры с нуля: комнаты уже есть — их надо только расставить.
///
/// Если в проекте нет зала, прихожей или балкона, они добавляются пустыми:
/// план должен показывать всю квартиру, а не только посчитанные комнаты.
class PlanSeed {
  /// Отступ между комнатами, м.
  static const gap = 0.25;

  /// Комнаты, которые добавляем, если их нет в проекте.
  static const _typical = [
    (core.RoomType.livingRoom, 'Зал', 4.0, 3.0),
    (core.RoomType.entrance, 'Прихожая', 2.0, 2.0),
    (core.RoomType.balcony, 'Балкон', 1.2, 3.0),
  ];

  static FloorPlan fromDraft(ProjectDraft draft) {
    final rooms = <PlanRoom>[];
    final hasType = <core.RoomType>{};
    for (final room in draft.rooms) {
      hasType.add(room.type);
    }

    // Размеры по площади: корень из площади даёт правдоподобный квадрат.
    final specs = <({String name, core.RoomType type, double w, double h})>[];
    for (final room in draft.rooms) {
      final area = room.area > 0 ? room.area : 12.0;
      final side = math.sqrt(area);
      final w = math.max(2.0, double.parse((side * 1.25).toStringAsFixed(2)));
      final h = math.max(1.6, double.parse((area / w).toStringAsFixed(2)));
      specs.add((name: room.name, type: room.type, w: w, h: h));
    }

    for (final (type, name, w, h) in _typical) {
      if (hasType.contains(type)) continue;
      // Зал и прихожую добавляем всегда, балкон — только если он есть
      // в проекте или проект небольшой (студия без балкона допустима).
      if (type == core.RoomType.balcony && draft.rooms.length < 2) continue;
      specs.add((name: name, type: type, w: w, h: h));
    }

    // Раскладка «полками»: слева направо, с переносом на новую полосу.
    // Сверху оставляем полосу под щит, чтобы его значок не перекрывал
    // подпись первой комнаты (проверено по скриншоту).
    const sheetW = 9.0;
    const topBand = 1.1;
    var x = gap;
    var y = topBand;
    var rowHeight = 0.0;

    for (final spec in specs) {
      var w = math.min(spec.w, sheetW - gap * 2);
      if (x + w + gap > sheetW && x > gap) {
        x = gap;
        y += rowHeight + gap;
        rowHeight = 0;
      }
      rooms.add(PlanRoom(
        id: 'p_${rooms.length + 1}',
        name: spec.name,
        type: spec.type,
        rect: PlanRect(
          left: _round(x),
          top: _round(y),
          width: _round(w),
          height: _round(spec.h),
        ),
      ));
      x += w + gap;
      rowHeight = math.max(rowHeight, spec.h);
    }

    final sheetH = y + rowHeight + gap;

    // Щит — у входа: слева сверху, если прихожая есть, иначе в углу.
    return FloorPlan(
      widthM: _round(math.max(sheetW, x + gap)),
      heightM: _round(math.max(6.0, sheetH)),
      rooms: rooms,
      panel: const PlanPanel(x: 0.55, y: 0.5),
    );
  }

  /// Переносит точки и длины из плана в черновик: комнаты сопоставляются
  /// по имени, поэтому пользователь может сначала нарисовать, а потом
  /// считать — или наоборот.
  static ProjectDraft applyToDraft(ProjectDraft draft, FloorPlan plan) {
    final rooms = [
      for (final room in draft.rooms)
        room.copyWith(
          area: _areaOf(plan, room) ?? room.area,
          cableLengthM: _lengthOf(plan, room) ?? room.cableLengthM,
        ),
    ];
    return draft.copyWith(rooms: rooms, plan: plan);
  }

  static double? _areaOf(FloorPlan plan, RoomDraft room) {
    for (final planRoom in plan.rooms) {
      if (planRoom.name.trim().toLowerCase() == room.name.trim().toLowerCase()) {
        return double.parse(planRoom.rect.area.toStringAsFixed(1));
      }
    }
    return null;
  }

  static double? _lengthOf(FloorPlan plan, RoomDraft room) {
    for (final planRoom in plan.rooms) {
      if (planRoom.name.trim().toLowerCase() != room.name.trim().toLowerCase()) {
        continue;
      }
      final devices =
          plan.devices.where((d) => d.roomId == planRoom.id).toList();
      if (devices.isEmpty) return null;
      var longest = 0.0;
      for (final device in devices) {
        final length = (device.x - plan.panel.x).abs() +
            (device.y - plan.panel.y).abs();
        final withReserve = length * 1.15;
        if (withReserve > longest) longest = withReserve;
      }
      return double.parse(longest.toStringAsFixed(1));
    }
    return null;
  }

  static double _round(double v) => (v * 4).roundToDouble() / 4;
}
