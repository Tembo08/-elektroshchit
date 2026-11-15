import 'dart:math' as math;

/// Распределение нагрузки по фазам и перекос.
///
/// Считается по расчётным мощностям групп. Для трёхфазной группы мощность
/// делится на три фазы поровну (в реальности — по паспорту прибора).
class PhaseBalance {
  final double l1Kw;
  final double l2Kw;
  final double l3Kw;

  const PhaseBalance({
    required this.l1Kw,
    required this.l2Kw,
    required this.l3Kw,
  });

  double get totalKw => l1Kw + l2Kw + l3Kw;

  double get maxKw => math.max(l1Kw, math.max(l2Kw, l3Kw));

  double get minKw => math.min(l1Kw, math.min(l2Kw, l3Kw));

  /// Перекос в процентах: (максимум − минимум) / максимум × 100.
  /// Практика: больше 15% — уже стоит перекинуть линию.
  double get imbalancePercent => maxKw <= 0 ? 0 : (maxKw - minKw) / maxKw * 100;

  bool get isBalanced => imbalancePercent <= 15;

  double get currentL1A => l1Kw * 1000 / 230;
  double get currentL2A => l2Kw * 1000 / 230;
  double get currentL3A => l3Kw * 1000 / 230;
}
