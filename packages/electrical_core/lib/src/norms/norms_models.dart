/// Модели нормативных данных (загружаются из YAML)

class CableSectionNorm {
  final double sectionMm2;
  final double maxCurrentA;
  final String typicalUse;
  final int cores;
  final String description;

  const CableSectionNorm({
    required this.sectionMm2,
    required this.maxCurrentA,
    required this.typicalUse,
    required this.cores,
    required this.description,
  });
}

class BreakerNorm {
  final int amps;
  final String curve;
  final String typicalUse;
  final int dinModules;

  const BreakerNorm({
    required this.amps,
    required this.curve,
    required this.typicalUse,
    required this.dinModules,
  });
}

class RcdNorm {
  final int ma;
  final String typicalUse;
  final int dinModules;

  const RcdNorm({
    required this.ma,
    required this.typicalUse,
    required this.dinModules,
  });
}

/// Каталог всех норм одной версии (например ru_2026)
class NormsCatalog {
  final String version;
  final String cableTypeDefault;
  final List<CableSectionNorm> cableSections;
  final List<BreakerNorm> breakers;
  final List<RcdNorm> rcdOptions;
  final List<String> powerfulTypes;
  final List<String> lightingTypes;
  final List<String> socketTypes;
  final List<String> wetRoomTypes;
  final int maxSocketsPerGroup;
  final double maxPowerKwPerSocketGroup;
  final int defaultRcdMa;
  final int lightingDefaultAmps;
  final int socketsDefaultAmps;

  const NormsCatalog({
    required this.version,
    required this.cableTypeDefault,
    required this.cableSections,
    required this.breakers,
    required this.rcdOptions,
    required this.powerfulTypes,
    required this.lightingTypes,
    required this.socketTypes,
    required this.wetRoomTypes,
    required this.maxSocketsPerGroup,
    required this.maxPowerKwPerSocketGroup,
    required this.defaultRcdMa,
    required this.lightingDefaultAmps,
    required this.socketsDefaultAmps,
  });

  /// Найти минимальное подходящее сечение под ток
  CableSectionNorm? sectionForCurrent(double currentA) {
    final sorted = [...cableSections]
      ..sort((a, b) => a.sectionMm2.compareTo(b.sectionMm2));
    for (final s in sorted) {
      if (s.maxCurrentA >= currentA) return s;
    }
    return sorted.isNotEmpty ? sorted.last : null;
  }

  /// Найти автомат по току (не меньше расчётного)
  BreakerNorm? breakerForCurrent(double currentA) {
    final sorted = [...breakers]..sort((a, b) => a.amps.compareTo(b.amps));
    for (final b in sorted) {
      if (b.amps >= currentA) return b;
    }
    return sorted.isNotEmpty ? sorted.last : null;
  }
}
