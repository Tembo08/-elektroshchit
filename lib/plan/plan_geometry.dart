import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'plan_models.dart';

/// Геометрия плана: привязка к сетке, попадания, длины трасс.
///
/// Длина считается по манхэттену (кабель идёт по стенам и потолку, а не
/// по диагонали) с запасом [_reserve] на обходы и подъёмы. Это оценка,
/// а не проектная длина — так и подписано в интерфейсе.
class PlanGeometry {
  /// Шаг сетки при перетаскивании и изменении размера, м.
  static const gridStep = 0.25;

  /// Запас на обходы, подъёмы и разделку.
  static const reserve = 1.15;

  /// Минимальный размер комнаты, м.
  static const minRoomSize = 1.0;

  static double snap(double value, [double step = gridStep]) =>
      (value / step).round() * step;

  /// Длина трассы от щита до точки, м.
  static double routeLength(FloorPlan plan, PlanDevice device) {
    final dx = (device.x - plan.panel.x).abs();
    final dy = (device.y - plan.panel.y).abs();
    return (dx + dy) * reserve;
  }

  /// Самая длинная трасса среди точек комнаты (0 — точек нет).
  static double roomLength(FloorPlan plan, String roomId) {
    var longest = 0.0;
    for (final d in plan.devices) {
      if (d.roomId != roomId) continue;
      final len = routeLength(plan, d);
      if (len > longest) longest = len;
    }
    return longest;
  }

  /// Углы ортогонального маршрута щит → точка (для отрисовки линии).
  static List<Offset> route(FloorPlan plan, PlanDevice device) {
    final panel = Offset(plan.panel.x, plan.panel.y);
    final target = Offset(device.x, device.y);
    final midX = plan.panel.x +
        (device.x >= plan.panel.x ? PlanPanel.widthM / 2 + 0.1 : -PlanPanel.widthM / 2 - 0.1);
    return [
      Offset(panel.dx + (device.x >= plan.panel.x ? PlanPanel.widthM / 2 : -PlanPanel.widthM / 2), panel.dy),
      Offset(midX, panel.dy),
      Offset(midX, target.dy),
      target,
    ];
  }

  /// Комната под точкой (x, y); null — пустое место.
  static PlanRoom? roomAt(FloorPlan plan, double x, double y) {
    for (final room in plan.rooms) {
      if (room.rect.contains(x, y)) return room;
    }
    return null;
  }

  /// Ближайшая точка плана в пределах [radius] метров.
  static PlanDevice? deviceAt(
    FloorPlan plan,
    double x,
    double y, {
    double radius = 0.45,
  }) {
    PlanDevice? best;
    var bestDistance = radius;
    for (final d in plan.devices) {
      final distance = math.sqrt((d.x - x) * (d.x - x) + (d.y - y) * (d.y - y));
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = d;
      }
    }
    return best;
  }

  /// Влезает ли прямоугольник в границы плана.
  static bool fits(FloorPlan plan, PlanRect rect) =>
      rect.left >= 0 &&
      rect.top >= 0 &&
      rect.right <= plan.widthM + 0.001 &&
      rect.bottom <= plan.heightM + 0.001;

  /// Пересечение с другими комнатами (для проверки при добавлении).
  static bool overlaps(FloorPlan plan, PlanRect rect, {String? ignoreId}) {
    for (final room in plan.rooms) {
      if (room.id == ignoreId) continue;
      final a = room.rect;
      final overlapX = math.min(a.right, rect.right) - math.max(a.left, rect.left);
      final overlapY = math.min(a.bottom, rect.bottom) - math.max(a.top, rect.top);
      if (overlapX > 0.05 && overlapY > 0.05) return true;
    }
    return false;
  }

  /// Ставит пачку точек в ряд от указанного места.
  ///
  /// Розетки в комнате обычно идут вдоль стены с шагом 0.5 м, поэтому
  /// пачка раскладывается горизонтально; если упирается в границу
  /// комнаты — переносится ниже.
  static List<PlanDevice> placeBatch({
    required FloorPlan plan,
    required String roomId,
    required PlanPointType type,
    required double x,
    required double y,
    required int count,
    required String idPrefix,
    int startIndex = 0,
  }) {
    final room = plan.rooms.where((r) => r.id == roomId).firstOrNull;
    final devices = <PlanDevice>[];
    var cx = x;
    var cy = y;
    for (var i = 0; i < count; i++) {
      if (room != null && cx > room.rect.right - 0.3) {
        cx = room.rect.left + 0.3;
        cy += 0.5;
      }
      devices.add(PlanDevice(
        id: '${idPrefix}_${startIndex + i}',
        type: type,
        x: snap(cx),
        y: snap(cy),
        roomId: roomId,
      ));
      cx += 0.5;
    }
    return devices;
  }
}
