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
  final bool isDifferentialBreaker; // true = дифавтомат
  final int dinModules;
  final String cableType; // "ВВГнг-LS 3×2.5"
  final String? phase; // "L1", "L2", "L3"
  final List<String> warnings;

  /// id УЗО-родителя; null = своя защита (диф / отдельное УЗО)
  final String? parentRcdId;

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
    this.isDifferentialBreaker = false,
    required this.dinModules,
    required this.cableType,
    this.phase,
    this.warnings = const [],
    this.parentRcdId,
  });

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
    bool? isDifferentialBreaker,
    int? dinModules,
    String? cableType,
    String? phase,
    List<String>? warnings,
    String? parentRcdId,
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
      isDifferentialBreaker:
          isDifferentialBreaker ?? this.isDifferentialBreaker,
      dinModules: dinModules ?? this.dinModules,
      cableType: cableType ?? this.cableType,
      phase: phase ?? this.phase,
      warnings: warnings ?? this.warnings,
      parentRcdId: parentRcdId ?? this.parentRcdId,
    );
  }
}
