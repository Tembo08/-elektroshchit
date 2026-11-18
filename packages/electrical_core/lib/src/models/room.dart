import 'enums.dart';
import 'consumer.dart';

/// Комната
class Room {
  final String id;
  final String name;
  final RoomType type;
  final double area;          // м²
  final double? length;       // опционально
  final double? width;
  final List<Consumer> consumers;

  /// Длина трассы от щита до комнаты, м. 0 — неизвестна (проверка
  /// падения напряжения не выполняется).
  final double cableLengthM;

  const Room({
    required this.id,
    required this.name,
    required this.type,
    required this.area,
    this.length,
    this.width,
    this.consumers = const [],
    this.cableLengthM = 0,
  });

  Room copyWith({
    String? id,
    String? name,
    RoomType? type,
    double? area,
    double? length,
    double? width,
    List<Consumer>? consumers,
    double? cableLengthM,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      area: area ?? this.area,
      length: length ?? this.length,
      width: width ?? this.width,
      consumers: consumers ?? this.consumers,
      cableLengthM: cableLengthM ?? this.cableLengthM,
    );
  }
}

