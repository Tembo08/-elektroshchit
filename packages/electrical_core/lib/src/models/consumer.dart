import 'enums.dart';

/// Потребитель / точка (розетка, светильник, мощная техника и т.д.)
class Consumer {
  final String id;
  final ConsumerType type;
  final String name;
  final double? powerKw;       // Обязательно для мощных потребителей
  final int quantity;
  final bool isPowerful;       // Требует отдельной линии
  final bool requiresRcd;
  final String? note;

  const Consumer({
    required this.id,
    required this.type,
    required this.name,
    this.powerKw,
    this.quantity = 1,
    this.isPowerful = false,
    this.requiresRcd = false,
    this.note,
  });

  Consumer copyWith({
    String? id,
    ConsumerType? type,
    String? name,
    double? powerKw,
    int? quantity,
    bool? isPowerful,
    bool? requiresRcd,
    String? note,
  }) {
    return Consumer(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      powerKw: powerKw ?? this.powerKw,
      quantity: quantity ?? this.quantity,
      isPowerful: isPowerful ?? this.isPowerful,
      requiresRcd: requiresRcd ?? this.requiresRcd,
      note: note ?? this.note,
    );
  }
}
