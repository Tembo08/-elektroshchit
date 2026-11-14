/// Модели нормативных данных (загружаются из YAML).
library;

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
  final int maxLightingPointsPerGroup;
  final int socketsMaxAmps;
  final int lightingMaxAmps;
  final int powerfulMinAmps;
  final double heavyLoadKw;
  final double heavyMinSection;
  final double minSectionLighting;
  final double minSectionSockets;
  final double minSectionPowerful;
  final List<int> rcdRatings;
  final int bathRcdMa;
  final int fireRcdMa;
  final String fireRcdType;
  final String rcdType;

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
    this.maxLightingPointsPerGroup = 15,
    this.socketsMaxAmps = 16,
    this.lightingMaxAmps = 16,
    this.powerfulMinAmps = 16,
    this.heavyLoadKw = 3.5,
    this.heavyMinSection = 4.0,
    this.minSectionLighting = 1.5,
    this.minSectionSockets = 2.5,
    this.minSectionPowerful = 2.5,
    this.rcdRatings = const [16, 25, 32, 40, 50, 63, 80, 100],
    this.bathRcdMa = 10,
    this.fireRcdMa = 100,
    this.fireRcdType = 'S',
    this.rcdType = 'AC',
  });

  /// Найти минимальное подходящее сечение под ток.
  /// Возвращает null, если таблица сечений не покрывает ток — считать молча
  /// «последнее сечение» нельзя, это скрытая ошибка расчёта.
  CableSectionNorm? sectionForCurrent(double currentA) {
    final sorted = [...cableSections]
      ..sort((a, b) => a.sectionMm2.compareTo(b.sectionMm2));
    for (final s in sorted) {
      if (s.maxCurrentA >= currentA) return s;
    }
    return null;
  }

  /// Ближайшее сечение не меньше заданного.
  CableSectionNorm? sectionAtLeast(double sectionMm2) {
    final sorted = [...cableSections]
      ..sort((a, b) => a.sectionMm2.compareTo(b.sectionMm2));
    for (final s in sorted) {
      if (s.sectionMm2 >= sectionMm2 - 0.001) return s;
    }
    return null;
  }

  /// Наибольшее сечение в каталоге.
  CableSectionNorm? get largestSection {
    if (cableSections.isEmpty) return null;
    return [...cableSections]
        .reduce((a, b) => a.sectionMm2 >= b.sectionMm2 ? a : b);
  }

  /// Найти автомат по току (не меньше расчётного). null — ряд не покрывает.
  BreakerNorm? breakerForCurrent(double currentA) {
    final sorted = [...breakers]..sort((a, b) => a.amps.compareTo(b.amps));
    for (final b in sorted) {
      if (b.amps >= currentA) return b;
    }
    return null;
  }

  /// Автомат с точным номиналом (для явно выбранного ввода) или ближайший сверху.
  BreakerNorm? breakerByAmps(int amps) {
    final sorted = [...breakers]..sort((a, b) => a.amps.compareTo(b.amps));
    for (final b in sorted) {
      if (b.amps == amps) return b;
    }
    return breakerForCurrent(amps.toDouble());
  }

  /// Ближайший номинал УЗО не меньше заданного тока.
  int rcdRatingAtLeast(double amps) {
    final sorted = [...rcdRatings]..sort();
    for (final a in sorted) {
      if (a >= amps) return a;
    }
    return sorted.isEmpty ? amps.ceil() : sorted.last;
  }
}
