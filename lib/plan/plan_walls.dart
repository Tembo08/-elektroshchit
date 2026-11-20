import 'dart:ui' show Offset;

import 'plan_models.dart';

/// Стена на плане: отрезок с толщиной.
class PlanWall {
  final Offset a;
  final Offset b;
  final double thickness;

  const PlanWall(this.a, this.b, {this.thickness = 0.16});

  double get length => (b - a).distance;

  bool get horizontal => (a.dy - b.dy).abs() < (a.dx - b.dx).abs();

  /// Прямоугольник стены (для заливки) — с учётом толщины.
  PlanRect get rect {
    final half = thickness / 2;
    return PlanRect(
      left: (a.dx < b.dx ? a.dx : b.dx) - half,
      top: (a.dy < b.dy ? a.dy : b.dy) - half,
      width: (a.dx - b.dx).abs() + thickness,
      height: (a.dy - b.dy).abs() + thickness,
    );
  }
}

/// Тип проёма.
enum PlanOpeningType { door, entry, window }

/// Проём в стене: двери и окна.
///
/// Отрезок `a..b` — это участок стены, который вырезан. Такой формат
/// удобно рисовать и легко сериализовать: не нужны индексы стен.
class PlanOpening {
  final Offset a;
  final Offset b;
  final PlanOpeningType type;

  const PlanOpening({
    required this.a,
    required this.b,
    this.type = PlanOpeningType.door,
  });

  bool get horizontal => (a.dy - b.dy).abs() < (a.dx - b.dx).abs();

  double get width => (b - a).distance;

  Map<String, dynamic> toJson() => {
        'ax': a.dx,
        'ay': a.dy,
        'bx': b.dx,
        'by': b.dy,
        'type': type.name,
      };

  static PlanOpening fromJson(Map<String, dynamic> json) => PlanOpening(
        a: Offset(
          (json['ax'] as num?)?.toDouble() ?? 0,
          (json['ay'] as num?)?.toDouble() ?? 0,
        ),
        b: Offset(
          (json['bx'] as num?)?.toDouble() ?? 0,
          (json['by'] as num?)?.toDouble() ?? 0,
        ),
        type: PlanOpeningType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PlanOpeningType.door,
        ),
      );
}

/// Строит стены и проёмы из прямоугольников комнат.
///
/// Логика как в редакторах планов: комнаты дают отрезки стен, соседние
/// комнаты делят одну стену, а не рисуют две. Проёмы — вырезанные участки
/// стены: входная дверь, межкомнатные двери, окна на фасаде.
class PlanWalls {
  static const thickness = 0.16;

  /// Ширина двери, м.
  static const doorWidth = 0.8;
  static const entryWidth = 1.0;

  /// Ширина окна, м.
  static const windowWidth = 1.4;

  static ({List<PlanWall> walls, List<PlanOpening> openings}) build({
    required List<PlanRoom> rooms,
    required String? Function(PlanRoom room) hostOf,
    required double planWidth,
    required double planHeight,
  }) {
    final walls = _mergeWalls(rooms);
    final openings = <PlanOpening>[];

    // Окна — только на НАРУЖНЫХ стенах жилых комнат и кухни.
    // Раньше окно ставилось на верхнюю стену, даже если она внутренняя:
    // получалось окно между залом и кухней.
    const eps = 0.02;
    for (final room in rooms) {
      if (hostOf(room) == null) continue;
      final r = room.rect;

      // Порядок: верх, низ, лево, право — что первое окажется наружным.
      final candidates = <({bool horizontal, double x, double y, double len})>[
        if (r.top.abs() < eps)
          (horizontal: true, x: r.left, y: r.top, len: r.width),
        if ((r.bottom - planHeight).abs() < 0.2)
          (horizontal: true, x: r.left, y: r.bottom, len: r.width),
        if (r.left.abs() < eps)
          (horizontal: false, x: r.left, y: r.top, len: r.height),
        if ((r.right - planWidth).abs() < 0.2)
          (horizontal: false, x: r.right, y: r.top, len: r.height),
      ];

      final host = candidates
          .where((c) => c.len >= windowWidth + 0.3)
          .firstOrNull;
      if (host == null) continue;

      if (host.horizontal) {
        final x = host.x + (host.len - windowWidth) / 2;
        openings.add(PlanOpening(
          a: Offset(x, host.y),
          b: Offset(x + windowWidth, host.y),
          type: PlanOpeningType.window,
        ));
      } else {
        final y = host.y + (host.len - windowWidth) / 2;
        openings.add(PlanOpening(
          a: Offset(host.x, y),
          b: Offset(host.x, y + windowWidth),
          type: PlanOpeningType.window,
        ));
      }
    }

    return (walls: walls, openings: openings);
  }

  /// Кладёт дверь на общей границе двух комнат.
  static PlanOpening? doorBetween(PlanRect a, PlanRect b, {double width = doorWidth}) {
    // Общая вертикальная стена.
    if ((a.right - b.left).abs() < 0.02 || (b.right - a.left).abs() < 0.02) {
      final x = (a.right - b.left).abs() < 0.02 ? a.right : a.left;
      final top = a.top > b.top ? a.top : b.top;
      final bottom = a.bottom < b.bottom ? a.bottom : b.bottom;
      final shared = bottom - top;
      if (shared < width + 0.25) return null;
      final center = (top + bottom) / 2;
      return PlanOpening(
        a: Offset(x, center - width / 2),
        b: Offset(x, center + width / 2),
      );
    }

    // Общая горизонтальная стена.
    if ((a.bottom - b.top).abs() < 0.02 || (b.bottom - a.top).abs() < 0.02) {
      final y = (a.bottom - b.top).abs() < 0.02 ? a.bottom : a.top;
      final left = a.left > b.left ? a.left : b.left;
      final right = a.right < b.right ? a.right : b.right;
      final shared = right - left;
      if (shared < width + 0.25) return null;
      final center = (left + right) / 2;
      return PlanOpening(
        a: Offset(center - width / 2, y),
        b: Offset(center + width / 2, y),
      );
    }

    return null;
  }

  /// Входная дверь на наружной стене комнаты.
  static PlanOpening entryOn(PlanRect rect) => PlanOpening(
        a: Offset(rect.left, rect.center.dy - entryWidth / 2),
        b: Offset(rect.left, rect.center.dy + entryWidth / 2),
        type: PlanOpeningType.entry,
      );

  /// Собирает стены из комнат и склеивает общие участки.
  static List<PlanWall> _mergeWalls(List<PlanRoom> rooms) {
    final horizontal = <double, List<(double, double)>>{};
    final vertical = <double, List<(double, double)>>{};

    void addHorizontal(double y, double x1, double x2) {
      final key = _r(y);
      horizontal.putIfAbsent(key, () => []).add((x1 < x2 ? x1 : x2, x1 > x2 ? x1 : x2));
    }

    void addVertical(double x, double y1, double y2) {
      final key = _r(x);
      vertical.putIfAbsent(key, () => []).add((y1 < y2 ? y1 : y2, y1 > y2 ? y1 : y2));
    }

    for (final room in rooms) {
      final r = room.rect;
      addHorizontal(r.top, r.left, r.right);
      addHorizontal(r.bottom, r.left, r.right);
      addVertical(r.left, r.top, r.bottom);
      addVertical(r.right, r.top, r.bottom);
    }

    final walls = <PlanWall>[];

    for (final entry in horizontal.entries) {
      for (final seg in _merge(entry.value)) {
        walls.add(PlanWall(Offset(seg.$1, entry.key), Offset(seg.$2, entry.key),
            thickness: thickness));
      }
    }
    for (final entry in vertical.entries) {
      for (final seg in _merge(entry.value)) {
        walls.add(PlanWall(Offset(entry.key, seg.$1), Offset(entry.key, seg.$2),
            thickness: thickness));
      }
    }
    return walls;
  }

  /// Склеивает и дедуплицирует интервалы на одной прямой.
  static List<(double, double)> _merge(List<(double, double)> segments) {
    final sorted = [...segments]..sort((a, b) => a.$1.compareTo(b.$1));
    final result = <(double, double)>[];
    for (final seg in sorted) {
      if (result.isEmpty) {
        result.add(seg);
        continue;
      }
      final last = result.removeLast();
      if (seg.$1 <= last.$2 + 0.02) {
        result.add((last.$1, seg.$2 > last.$2 ? seg.$2 : last.$2));
      } else {
        result.add(last);
        result.add(seg);
      }
    }
    return result;
  }

  static double _r(double v) => (v * 20).roundToDouble() / 20;
}
