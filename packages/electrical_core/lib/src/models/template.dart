/// Готовые шаблоны объектов (студия, 1к, дом и т.д.).
///
/// Шаблон — это заготовка комнат и потребителей, которую пользователь
/// подставляет и правит под свой объект. Не расчёт и не проект.
class TemplateConsumer {
  final String type; // имя ConsumerType
  final int quantity;
  final double? powerKw;
  final bool isPowerful;

  const TemplateConsumer({
    required this.type,
    this.quantity = 1,
    this.powerKw,
    this.isPowerful = false,
  });
}

class TemplateRoom {
  final String type; // имя RoomType
  final String name;
  final double area;
  final List<TemplateConsumer> consumers;

  const TemplateRoom({
    required this.type,
    required this.name,
    this.area = 0,
    this.consumers = const [],
  });
}

class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String objectType; // apartment | privateHouse
  final double suggestedPowerKw;
  final List<TemplateRoom> rooms;

  const ProjectTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.objectType = 'apartment',
    this.suggestedPowerKw = 0,
    this.rooms = const [],
  });

  int get totalSockets {
    var n = 0;
    for (final r in rooms) {
      for (final c in r.consumers) {
        if (c.type == 'socket') n += c.quantity;
      }
    }
    return n;
  }

  int get totalLights {
    var n = 0;
    for (final r in rooms) {
      for (final c in r.consumers) {
        if (c.type == 'lightPoint' ||
            c.type == 'chandelier' ||
            c.type == 'ledStrip') {
          n += c.quantity;
        }
      }
    }
    return n;
  }
}
