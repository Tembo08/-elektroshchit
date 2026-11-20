import 'dart:ui' show Rect, Offset;

import 'package:electrical_core/electrical_core.dart' as core;

/// Прямоугольник комнаты на плане, в метрах от левого верхнего угла.
class PlanRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const PlanRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  double get area => width * height;

  Offset get center => Offset(left + width / 2, top + height / 2);

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  PlanRect copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) =>
      PlanRect(
        left: left ?? this.left,
        top: top ?? this.top,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  /// Перемещение с сохранением размера.
  PlanRect movedTo(double newLeft, double newTop) =>
      PlanRect(left: newLeft, top: newTop, width: width, height: height);

  /// Изменение размера за правый нижний угол.
  PlanRect resizedTo(double newRight, double newBottom) => PlanRect(
        left: left,
        top: top,
        width: (newRight - left).clamp(0.5, double.infinity),
        height: (newBottom - top).clamp(0.5, double.infinity),
      );

  Rect toRect() => Rect.fromLTWH(left, top, width, height);

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'w': width,
        'h': height,
      };

  static PlanRect fromJson(Map<String, dynamic> json) => PlanRect(
        left: (json['l'] as num?)?.toDouble() ?? 0,
        top: (json['t'] as num?)?.toDouble() ?? 0,
        width: (json['w'] as num?)?.toDouble() ?? 3,
        height: (json['h'] as num?)?.toDouble() ?? 3,
      );
}

/// Комната на плане. Связана с расчётной комнатой по id.
class PlanRoom {
  final String id;
  final String name;
  final core.RoomType type;
  final PlanRect rect;

  const PlanRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.rect,
  });

  PlanRoom copyWith({String? name, core.RoomType? type, PlanRect? rect}) =>
      PlanRoom(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        rect: rect ?? this.rect,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'rect': rect.toJson(),
      };

  static PlanRoom fromJson(Map<String, dynamic> json) {
    var type = core.RoomType.other;
    for (final t in core.RoomType.values) {
      if (t.name == json['type']) type = t;
    }
    return PlanRoom(
      id: json['id'] as String? ?? 'room',
      name: json['name'] as String? ?? 'Комната',
      type: type,
      rect: PlanRect.fromJson(
        Map<String, dynamic>.from(json['rect'] as Map? ?? const {}),
      ),
    );
  }
}

/// Щит на плане: точка, к которой сходятся линии.
class PlanPanel {
  final double x;
  final double y;

  /// Размер условного обозначения щита, м (рисуется, как в схемах).
  static const widthM = 0.9;
  static const heightM = 0.6;

  const PlanPanel({required this.x, required this.y});

  Offset get center => Offset(x, y);

  PlanPanel copyWith({double? x, double? y}) => PlanPanel(x: x ?? this.x, y: y ?? this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  static PlanPanel fromJson(Map<String, dynamic> json) => PlanPanel(
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
      );
}

/// Тип точки на плане.
enum PlanPointType { socket, light, switchPoint, powerful }

extension PlanPointTypeInfo on PlanPointType {
  String get label => switch (this) {
        PlanPointType.socket => 'Розетка',
        PlanPointType.light => 'Свет',
        PlanPointType.switchPoint => 'Выключатель',
        PlanPointType.powerful => 'Мощный',
      };

  core.ConsumerType get consumerType => switch (this) {
        PlanPointType.socket => core.ConsumerType.socket,
        PlanPointType.light => core.ConsumerType.lightPoint,
        PlanPointType.switchPoint => core.ConsumerType.switchSingle,
        PlanPointType.powerful => core.ConsumerType.otherPowerful,
      };
}

/// Точка на плане: розетка, светильник или мощный прибор.
class PlanDevice {
  final String id;
  final PlanPointType type;
  final double x;
  final double y;

  /// Комната, к которой относится точка (id PlanRoom).
  final String roomId;

  const PlanDevice({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.roomId,
  });

  PlanDevice movedTo(double nx, double ny) =>
      PlanDevice(id: id, type: type, x: nx, y: ny, roomId: roomId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'room': roomId,
      };

  static PlanDevice fromJson(Map<String, dynamic> json) {
    var type = PlanPointType.socket;
    for (final t in PlanPointType.values) {
      if (t.name == json['type']) type = t;
    }
    return PlanDevice(
      id: json['id'] as String? ?? 'd',
      type: type,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      roomId: json['room'] as String? ?? '',
    );
  }
}

/// План помещения целиком.
class FloorPlan {
  final double widthM;
  final double heightM;
  final List<PlanRoom> rooms;
  final List<PlanDevice> devices;
  final PlanPanel panel;

  /// Горизонталь, по которой идут магистрали (y в метрах).
  /// null — трассы вести напрямую (ручной режим).
  final double? corridorY;

  const FloorPlan({
    this.widthM = 9,
    this.heightM = 9,
    this.rooms = const [],
    this.devices = const [],
    this.panel = const PlanPanel(x: 0.8, y: 0.8),
    this.corridorY,
  });

  bool get isEmpty => rooms.isEmpty && devices.isEmpty;

  FloorPlan copyWith({
    double? widthM,
    double? heightM,
    List<PlanRoom>? rooms,
    List<PlanDevice>? devices,
    PlanPanel? panel,
    double? corridorY,
  }) =>
      FloorPlan(
        widthM: widthM ?? this.widthM,
        heightM: heightM ?? this.heightM,
        rooms: rooms ?? this.rooms,
        devices: devices ?? this.devices,
        panel: panel ?? this.panel,
        corridorY: corridorY ?? this.corridorY,
      );

  /// Точки выбранного типа в комнате — для подсчёта количества.
  List<PlanDevice> devicesIn(String roomId, {PlanPointType? type}) => devices
      .where((d) => d.roomId == roomId && (type == null || d.type == type))
      .toList();

  int deviceCount(String roomId, PlanPointType type) =>
      devicesIn(roomId, type: type).length;

  Map<String, dynamic> toJson() => {
        'w': widthM,
        'h': heightM,
        'panel': panel.toJson(),
        'corridor': corridorY,
        'rooms': [for (final r in rooms) r.toJson()],
        'devices': [for (final d in devices) d.toJson()],
      };

  static FloorPlan fromJson(Map<String, dynamic> json) {
    final roomsRaw = json['rooms'];
    final devicesRaw = json['devices'];
    return FloorPlan(
      widthM: (json['w'] as num?)?.toDouble() ?? 9,
      heightM: (json['h'] as num?)?.toDouble() ?? 9,
      panel: PlanPanel.fromJson(
        Map<String, dynamic>.from(json['panel'] as Map? ?? const {}),
      ),
      corridorY: (json['corridor'] as num?)?.toDouble(),
      rooms: roomsRaw is List
          ? [
              for (final r in roomsRaw)
                if (r is Map) PlanRoom.fromJson(Map<String, dynamic>.from(r)),
            ]
          : const [],
      devices: devicesRaw is List
          ? [
              for (final d in devicesRaw)
                if (d is Map) PlanDevice.fromJson(Map<String, dynamic>.from(d)),
            ]
          : const [],
    );
  }
}
