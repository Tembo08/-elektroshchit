import 'circuit_group.dart';
import 'protection_device.dart';

/// Элемент спецификации материалов
class MaterialItem {
  final String name;
  final String unit; // "м", "шт"
  final double quantity;
  final String? note;

  const MaterialItem({
    required this.name,
    required this.unit,
    required this.quantity,
    this.note,
  });
}

/// Результат расчёта щитка
class PanelResult {
  final int totalDinModules;
  final int recommendedPanelModules; // с запасом 20–30%
  final String recommendedPanelSize; // "36 модулей", "2×18" и т.д.
  final List<CircuitGroup> groups;
  /// Установленная мощность: сумма всех групп как есть.
  final double installedPowerKw;

  /// Расчётная мощность: с коэффициентами спроса (по ней сверяемся с ТУ).
  final double totalCalculatedPowerKw;

  final double loadFactor;
  final bool isInputSufficient;
  final List<MaterialItem> materials;
  final List<ProtectionDevice> protectionDevices;

  const PanelResult({
    required this.totalDinModules,
    required this.recommendedPanelModules,
    required this.recommendedPanelSize,
    required this.groups,
    double? installedPowerKw,
    required this.totalCalculatedPowerKw,
    required this.loadFactor,
    required this.isInputSufficient,
    required this.materials,
    this.protectionDevices = const [],
  }) : installedPowerKw = installedPowerKw ?? totalCalculatedPowerKw;

  /// Насколько установленная мощность больше расчётной (для подсказки в UI).
  double get demandSavingKw => installedPowerKw - totalCalculatedPowerKw;
}
