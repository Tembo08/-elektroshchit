import 'package:electrical_core/electrical_core.dart' as core;

import 'project_draft.dart';

/// Превращает шаблон из норм в черновик комнат приложения.
///
/// Сокеты санузлов уходят в «розетку у зеркала» (отдельное УЗО 10 мА),
/// мощные приборы — в отдельные линии, остальное — в счётчики комнаты.
List<RoomDraft> roomsFromTemplate(
  core.ProjectTemplate template,
  core.NormsCatalog norms,
) {
  final rooms = <RoomDraft>[];
  var roomIndex = 0;

  for (final tRoom in template.rooms) {
    roomIndex++;
    final roomType = _roomType(tRoom.type);
    final isBath = roomType == core.RoomType.bathroom ||
        roomType == core.RoomType.combinedBathroom ||
        roomType == core.RoomType.toilet;

    var sockets = 0;
    var mirror = 0;
    var lights = 0;
    var switches = 0;
    final dedicated = <core.ConsumerType, ApplianceSpec>{};

    for (final c in tRoom.consumers) {
      final type = _consumerType(c.type);
      final powerful = c.isPowerful || norms.powerfulTypes.contains(c.type);

      if (powerful && type != null) {
        final old = dedicated[type];
        dedicated[type] = ApplianceSpec(
          quantity: (old?.quantity ?? 0) + c.quantity,
          powerKw: c.powerKw ?? old?.powerKw,
          phases: old?.phases ?? 1,
        );
        continue;
      }

      switch (type) {
        case core.ConsumerType.socket:
          if (isBath) {
            mirror += c.quantity;
          } else {
            sockets += c.quantity;
          }
        case core.ConsumerType.lightPoint:
        case core.ConsumerType.chandelier:
        case core.ConsumerType.ledStrip:
          lights += c.quantity;
        case core.ConsumerType.switchSingle:
        case core.ConsumerType.switchDouble:
        case core.ConsumerType.switchPassThrough:
          switches += c.quantity;
        default:
          // Холодильник/вытяжка и прочее — тоже точки розеток.
          sockets += c.quantity;
      }
    }

    rooms.add(
      RoomDraft(
        id: 'r_${DateTime.now().microsecondsSinceEpoch}_$roomIndex',
        name: tRoom.name,
        type: roomType,
        socketsNormal: sockets,
        lights: lights,
        switches: switches,
        mirrorSockets: mirror,
        dedicated: dedicated,
      ),
    );
  }

  return rooms;
}

core.RoomType _roomType(String name) {
  for (final t in core.RoomType.values) {
    if (t.name == name) return t;
  }
  return core.RoomType.other;
}

core.ConsumerType? _consumerType(String name) {
  for (final t in core.ConsumerType.values) {
    if (t.name == name) return t;
  }
  return null;
}
