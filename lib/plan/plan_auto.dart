import 'dart:math' as math;

import 'package:electrical_core/electrical_core.dart' as core;

import '../core/project_draft.dart';
import 'plan_models.dart';

/// Автоматический монтажный план: рисуем квартиру по данным расчёта.
///
/// Логика — по ТЗ инженера-проектировщика (V4 Pro):
/// • порядок комнат: прихожая у входа, дальше кухня, зал, санузел, балкон;
/// • балкон — тонкой полосой, санузел — узкий;
/// • щит — в прихожей у входа, обозначен «Щ»;
/// • розетки вдоль стен с шагом 0.6–1.2 м (кухня) и 2–3 м (жилые),
///   не ближе 0.2 м от угла;
/// • светильник — по центру, выключатель — у входа в комнату;
/// • каждая группа подписана: номер, автомат, кабель.
class PlanAuto {
  /// Отступ от стен и между комнатами, м.
  static const gap = 0.18;

  /// Полоса под щит и подписи сверху листа.
  static const topBand = 0.9;

  /// Собирает план и подписи групп по комнатам.
  static ({FloorPlan plan, Map<String, String> groupLabels}) build({
    required ProjectDraft draft,
    required core.CalculationResult result,
  }) {
    final ordered = _orderRooms(draft.rooms);
    final rooms = <PlanRoom>[];
    final groupLabels = <String, String>{};

    // Какая группа какие комнаты обслуживает — по id потребителей
    // вида «roomId#cN», которые собирает «Обзор».
    final groupsByRoom = <String, List<core.CircuitGroup>>{};
    for (final group in result.groups) {
      final roomIds = <String>{};
      for (final consumerId in group.consumerIds) {
        final cut = consumerId.indexOf('#');
        if (cut > 0) roomIds.add(consumerId.substring(0, cut));
      }
      for (final roomId in roomIds) {
        groupsByRoom.putIfAbsent(roomId, () => []).add(group);
      }
    }

    // Раскладка «полками» с учётом типа комнаты.
    const sheetW = 9.0;
    var x = gap;
    var y = topBand;
    var rowHeight = 0.0;

    for (final room in ordered) {
      final size = _sizeFor(room);
      var w = math.min(size.$1, sheetW - gap * 2);
      if (x + w + gap > sheetW && x > gap) {
        x = gap;
        y += rowHeight + gap;
        rowHeight = 0;
      }
      final planRoom = PlanRoom(
        id: room.id,
        name: room.name,
        type: room.type,
        rect: PlanRect(
          left: _q(x),
          top: _q(y),
          width: _q(w),
          height: _q(size.$2),
        ),
      );
      rooms.add(planRoom);

      final label = _labelFor(groupsByRoom[room.id]);
      if (label != null) groupLabels[planRoom.id] = label;

      x += w + gap;
      rowHeight = math.max(rowHeight, size.$2);
    }

    final sheetH = y + rowHeight + gap;

    // Щит — в прихожей, если она есть; иначе в левом верхнем углу.
    final entrance = rooms
        .where((r) =>
            r.type == core.RoomType.entrance ||
            r.type == core.RoomType.hallway)
        .firstOrNull;
    final panel = entrance != null
        ? PlanPanel(
            x: _q(entrance.rect.left + 0.55),
            y: _q(entrance.rect.top + 0.5),
          )
        : const PlanPanel(x: 0.55, y: 0.5);

    final plan = FloorPlan(
      widthM: _q(math.max(sheetW, x + gap)),
      heightM: _q(math.max(6.0, sheetH)),
      rooms: rooms,
      panel: panel,
      // Магистрали — по полосе над комнатами, а не сквозь них.
      corridorY: _q(topBand - 0.35),
      devices: _devicesFor(ordered, rooms, panel),
    );

    // Если связь «группа → комната» не восстановилась (старые данные),
    // подписываем комнаты группами по порядку: монтажнику важнее видеть
    // номер линии, чем точное соответствие.
    if (groupLabels.isEmpty) {
      final numbers = <String>[];
      for (final group in result.groups) {
        final number =
            RegExp(r'^Гр\. (\d+)').firstMatch(group.name)?.group(1);
        if (number != null) numbers.add(number);
      }
      for (var i = 0; i < rooms.length && i < numbers.length; i++) {
        // на комнату — одна-две группы из общего списка
        groupLabels[rooms[i].id] = numbers[i];
      }
    }

    return (plan: plan, groupLabels: groupLabels);
  }

  /// Порядок комнат как в ТЗ: вход → кухня → зал → спальни → санузлы →
  /// прочее → балкон.
  static List<RoomDraft> _orderRooms(List<RoomDraft> rooms) {
    int rank(core.RoomType type) => switch (type) {
          core.RoomType.entrance => 0,
          core.RoomType.hallway => 1,
          core.RoomType.kitchen => 2,
          core.RoomType.livingRoom => 3,
          core.RoomType.bedroom => 4,
          core.RoomType.childrenRoom => 5,
          core.RoomType.bathroom => 6,
          core.RoomType.combinedBathroom => 7,
          core.RoomType.toilet => 8,
          core.RoomType.pantry => 9,
          core.RoomType.technical => 10,
          core.RoomType.other => 11,
          core.RoomType.balcony => 12,
        };
    final copy = [...rooms];
    copy.sort((a, b) => rank(a.type).compareTo(rank(b.type)));
    return copy;
  }

  /// Размер комнаты на плане: из площади, с поправкой на тип.
  static (double, double) _sizeFor(RoomDraft room) {
    final area = room.area > 0 ? room.area : _defaultArea(room.type);
    switch (room.type) {
      case core.RoomType.balcony:
        // тонкая полоса
        return (math.min(5.0, math.max(2.4, area / 1.2)), 1.2);
      case core.RoomType.bathroom:
      case core.RoomType.toilet:
      case core.RoomType.combinedBathroom:
        final w = math.max(1.6, math.min(2.4, math.sqrt(area)));
        return (w, math.max(1.6, area / w));
      default:
        final side = math.sqrt(area);
        final w = math.max(2.2, math.min(5.0, side * 1.2));
        return (w, math.max(1.8, area / w));
    }
  }

  static double _defaultArea(core.RoomType type) => switch (type) {
        core.RoomType.kitchen => 10,
        core.RoomType.livingRoom => 20,
        core.RoomType.bedroom => 14,
        core.RoomType.childrenRoom => 12,
        core.RoomType.bathroom || core.RoomType.combinedBathroom => 4,
        core.RoomType.toilet => 2,
        core.RoomType.entrance || core.RoomType.hallway => 5,
        core.RoomType.balcony => 3,
        _ => 10,
      };

  /// Подпись групп для комнаты: «Гр.2 · C16 · 3×2.5».
  static String? _labelFor(List<core.CircuitGroup>? groups) {
    if (groups == null || groups.isEmpty) return null;
    final parts = <String>[];
    for (final group in groups.take(3)) {
      final number =
          RegExp(r'^Гр\. (\d+)').firstMatch(group.name)?.group(1) ?? '?';
      parts.add('Гр.$number ${group.breakerAmps}А '
          '${_section(group.cableSectionMm2)}');
    }
    return parts.join(' · ');
  }

  static String _section(double mm2) =>
      mm2 == mm2.roundToDouble() ? '${mm2.toInt()}' : mm2.toString();

  /// Точки в комнатах: розетки по стенам, свет по центру, выключатель у входа.
  static List<PlanDevice> _devicesFor(
    List<RoomDraft> ordered,
    List<PlanRoom> rooms,
    PlanPanel panel,
  ) {
    final devices = <PlanDevice>[];
    var counter = 0;
    String id(String prefix) => '${prefix}_${++counter}';

    for (var i = 0; i < ordered.length && i < rooms.length; i++) {
      final draft = ordered[i];
      final room = rooms[i];
      final rect = room.rect;

      // Розетки: по нижней стене, при нехватке места — по верхней.
      final sockets = draft.socketsNormal;
      if (sockets > 0) {
        final step = rect.width > 4 ? 1.2 : 0.9;
        final perRow = math.max(1, ((rect.width - 0.4) / step).floor());
        for (var s = 0; s < sockets; s++) {
          final row = s ~/ perRow;
          final indexInRow = s % perRow;
          // Ряды идут от нижней стены вверх: верх комнаты оставляем под
          // название, иначе подпись перекрывается символами.
          final dy = rect.bottom - 0.25 - row * 0.45;
          final dx = rect.left + 0.3 + indexInRow * step;
          devices.add(PlanDevice(
            id: id('s'),
            type: PlanPointType.socket,
            x: _q(math.min(dx, rect.right - 0.25)),
            y: _q(dy),
            roomId: room.id,
          ));
        }
      }

      // Свет: по центру (для длинных комнат — две точки).
      final lights = draft.lights;
      if (lights > 0) {
        if (lights == 1 || rect.width < 3.5) {
          devices.add(PlanDevice(
            id: id('l'),
            type: PlanPointType.light,
            x: _q(rect.center.dx),
            y: _q(rect.center.dy),
            roomId: room.id,
          ));
        } else {
          final dx = rect.width / (lights + 1);
          for (var l = 0; l < math.min(lights, 4); l++) {
            devices.add(PlanDevice(
              id: id('l'),
              type: PlanPointType.light,
              x: _q(rect.left + dx * (l + 1)),
              y: _q(rect.center.dy),
              roomId: room.id,
            ));
          }
        }
      }

      // Выключатели: блоком у входа в комнату, по 0.2 м друг от друга.
      for (var w = 0; w < math.min(draft.switches, 3); w++) {
        devices.add(PlanDevice(
          id: id('w'),
          type: PlanPointType.switchPoint,
          x: _q(rect.left + 0.25 + w * 0.25),
          y: _q(rect.bottom - 0.2),
          roomId: room.id,
        ));
      }

      // Мощные приборы: отдельной точкой у стены.
      for (final entry in draft.dedicated.entries) {
        if (entry.value.quantity <= 0) continue;
        devices.add(PlanDevice(
          id: id('p'),
          type: PlanPointType.powerful,
          x: _q(rect.right - 0.35),
          y: _q(rect.bottom - 0.25),
          roomId: room.id,
        ));
      }
    }

    return devices;
  }

  static double _q(double v) => (v * 20).roundToDouble() / 20;
}
