/// Аппарат в щите: УЗО-родитель, автомат или диф
enum ProtectionKind {
  rcd,      // УЗО (может быть родителем для нескольких автоматов)
  breaker,  // автоматический выключатель
  dif,      // дифавтомат (один аппарат)
}

class ProtectionDevice {
  final String id;
  final ProtectionKind kind;
  final String name;
  final int amps;
  final String curve; // B/C для автомата; для УЗО часто ''
  final int? rcdMa; // 10 / 30 / 100
  final int dinModules;
  /// id дочерних автоматов (только для УЗО-родителя)
  final List<String> childBreakerIds;

  const ProtectionDevice({
    required this.id,
    required this.kind,
    required this.name,
    required this.amps,
    this.curve = 'C',
    this.rcdMa,
    required this.dinModules,
    this.childBreakerIds = const [],
  });

  ProtectionDevice copyWith({
    String? id,
    ProtectionKind? kind,
    String? name,
    int? amps,
    String? curve,
    int? rcdMa,
    int? dinModules,
    List<String>? childBreakerIds,
  }) {
    return ProtectionDevice(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      amps: amps ?? this.amps,
      curve: curve ?? this.curve,
      rcdMa: rcdMa ?? this.rcdMa,
      dinModules: dinModules ?? this.dinModules,
      childBreakerIds: childBreakerIds ?? this.childBreakerIds,
    );
  }
}
