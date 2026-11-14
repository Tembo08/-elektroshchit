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
  final int? rcdMa; // 10 / 30 / 100 / 300
  final int dinModules;
  /// id дочерних автоматов (только для УЗО-родителя)
  final List<String> childBreakerIds;

  /// Полюсов: 2 для однофазного УЗО, 4 для трёхфазного.
  final int poles;

  /// Тип УЗО по реагированию: 'AC', 'A', 'S' (селективное, для противопожарного).
  final String? rcdType;

  const ProtectionDevice({
    required this.id,
    required this.kind,
    required this.name,
    required this.amps,
    this.curve = 'C',
    this.rcdMa,
    required this.dinModules,
    this.childBreakerIds = const [],
    this.poles = 2,
    this.rcdType,
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
    int? poles,
    String? rcdType,
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
      poles: poles ?? this.poles,
      rcdType: rcdType ?? this.rcdType,
    );
  }
}
