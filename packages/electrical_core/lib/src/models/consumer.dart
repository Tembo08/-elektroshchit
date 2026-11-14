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

  /// Сколько фаз питает прибор: 1 — однофазный (по умолчанию), 3 — трёхфазный.
  /// Для трёхфазного автомат трёхполюсный, ток считается по 230·√3.
  final int phases;

  const Consumer({
    required this.id,
    required this.type,
    required this.name,
    this.powerKw,
    this.quantity = 1,
    this.isPowerful = false,
    this.requiresRcd = false,
    this.note,
    this.phases = 1,
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
    int? phases,
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
      phases: phases ?? this.phases,
    );
  }
}
