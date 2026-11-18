/// Группа / линия в щите
class CircuitGroup {
  final String id;
  final String name; // "Гр. 3 — Розетки кухня"
  final List<String> consumerIds;
  final double totalPowerKw;
  final double calculatedCurrentA;
  final double cableSectionMm2;
  final int breakerAmps;
  final String breakerCurve; // "B", "C", "D"
  final bool hasRcd;
  final int? rcdMa; // 10, 30, 100, 300
  final int? rcdAmps; // номинальный ток УЗО (только для своей защиты)
  final String? rcdType; // 'AC' / 'A' / 'S' для своей защиты
  final bool isDifferentialBreaker; // true = дифавтомат
  final int dinModules;
  final String cableType; // "ВВГнг-LS 3×2.5"
  final String? phase; // "L1", "L2", "L3"
  final List<String> warnings;

  /// Полюсов у автомата: 1 — однофазный, 3 — трёхфазный.
  final int poles;

  /// id УЗО-родителя; null = своя защита (диф / отдельное УЗО)
  final String? parentRcdId;

  /// Полюсов у УЗО-родителя (2 или 4); null — своей защиты нет.
  final int? parentRcdPoles;

  /// Коэффициент спроса для этой линии: 1.0 — всё, что указано, может
  /// работать одновременно; 0.7 — розетки, которые почти никогда не
  /// нагружены полностью.
  final double demandFactor;

  /// Длина линии, м (0 — неизвестна).
  final double lengthM;

  /// Падение напряжения на линии, % (0 — не считалось).
  final double voltageDropPercent;

  const CircuitGroup({
    required this.id,
    required this.name,
    required this.consumerIds,
    required this.totalPowerKw,
    required this.calculatedCurrentA,
    required this.cableSectionMm2,
    required this.breakerAmps,
    this.breakerCurve = 'C',
    this.hasRcd = false,
    this.rcdMa,
    this.rcdAmps,
    this.rcdType,
    this.isDifferentialBreaker = false,
    required this.dinModules,
    required this.cableType,
    this.phase,
    this.warnings = const [],
    this.poles = 1,
    this.parentRcdId,
    this.parentRcdPoles,
    this.demandFactor = 1.0,
    this.lengthM = 0,
    this.voltageDropPercent = 0,
  });

  /// Расчётная (приведённая) мощность с учётом коэффициента спроса.
  double get demandPowerKw => totalPowerKw * demandFactor;

  CircuitGroup copyWith({
    String? id,
    String? name,
    List<String>? consumerIds,
    double? totalPowerKw,
    double? calculatedCurrentA,
    double? cableSectionMm2,
    int? breakerAmps,
    String? breakerCurve,
    bool? hasRcd,
    int? rcdMa,
    int? rcdAmps,
    String? rcdType,
    bool? isDifferentialBreaker,
    int? dinModules,
    String? cableType,
    String? phase,
    List<String>? warnings,
    int? poles,
    String? parentRcdId,
    int? parentRcdPoles,
    double? demandFactor,
    double? lengthM,
    double? voltageDropPercent,
  }) {
    return CircuitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      consumerIds: consumerIds ?? this.consumerIds,
      totalPowerKw: totalPowerKw ?? this.totalPowerKw,
      calculatedCurrentA: calculatedCurrentA ?? this.calculatedCurrentA,
      cableSectionMm2: cableSectionMm2 ?? this.cableSectionMm2,
      breakerAmps: breakerAmps ?? this.breakerAmps,
      breakerCurve: breakerCurve ?? this.breakerCurve,
      hasRcd: hasRcd ?? this.hasRcd,
      rcdMa: rcdMa ?? this.rcdMa,
      rcdAmps: rcdAmps ?? this.rcdAmps,
      rcdType: rcdType ?? this.rcdType,
      isDifferentialBreaker:
          isDifferentialBreaker ?? this.isDifferentialBreaker,
      dinModules: dinModules ?? this.dinModules,
      cableType: cableType ?? this.cableType,
      phase: phase ?? this.phase,
      warnings: warnings ?? this.warnings,
      poles: poles ?? this.poles,
      parentRcdId: parentRcdId ?? this.parentRcdId,
      parentRcdPoles: parentRcdPoles ?? this.parentRcdPoles,
      demandFactor: demandFactor ?? this.demandFactor,
      lengthM: lengthM ?? this.lengthM,
      voltageDropPercent: voltageDropPercent ?? this.voltageDropPercent,
    );
  }
}
