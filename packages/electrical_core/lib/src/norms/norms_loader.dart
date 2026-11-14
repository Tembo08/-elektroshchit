import 'package:yaml/yaml.dart';

import 'norms_models.dart';

/// Загружает каталог норм из YAML-строк (или Map).
/// Flutter передаёт содержимое assets, тесты — содержимое файлов.
class NormsLoader {
  /// Собирает NormsCatalog из уже прочитанных YAML-текстов
  static NormsCatalog fromYamlTexts({
    required String version,
    required String cableSectionsYaml,
    required String breakersYaml,
    required String rcdYaml,
    required String groupingRulesYaml,
  }) {
    final cables = loadYaml(cableSectionsYaml) as YamlMap;
    final breakersMap = loadYaml(breakersYaml) as YamlMap;
    final rcdMap = loadYaml(rcdYaml) as YamlMap;
    final grouping = loadYaml(groupingRulesYaml) as YamlMap;

    final cableSections = <CableSectionNorm>[];
    for (final item in (cables['sections'] as YamlList)) {
      final m = item as YamlMap;
      cableSections.add(CableSectionNorm(
        sectionMm2: (m['section_mm2'] as num).toDouble(),
        maxCurrentA: (m['max_current_a'] as num).toDouble(),
        typicalUse: m['typical_use'] as String,
        cores: m['cores'] as int,
        description: m['description'] as String,
      ));
    }

    final breakers = <BreakerNorm>[];
    for (final item in (breakersMap['breakers'] as YamlList)) {
      final m = item as YamlMap;
      breakers.add(BreakerNorm(
        amps: m['amps'] as int,
        curve: m['curve'] as String,
        typicalUse: m['typical_use'] as String,
        dinModules: m['din_modules'] as int,
      ));
    }

    final rcdOptions = <RcdNorm>[];
    for (final item in (rcdMap['rcd_options'] as YamlList)) {
      final m = item as YamlMap;
      rcdOptions.add(RcdNorm(
        ma: m['ma'] as int,
        typicalUse: m['typical_use'] as String,
        dinModules: m['din_modules'] as int,
      ));
    }

    final limits = grouping['limits'] as YamlMap;
    final selection = breakersMap['selection_rules'] as YamlMap? ?? YamlMap();
    final rcdRules = rcdMap['rules'] as YamlMap? ?? YamlMap();

    return NormsCatalog(
      version: version,
      cableTypeDefault: cables['cable_type_default'] as String? ?? 'ВВГнг-LS',
      cableSections: cableSections,
      breakers: breakers,
      rcdOptions: rcdOptions,
      powerfulTypes: _toStringList(grouping['powerful_types']),
      lightingTypes: _toStringList(grouping['lighting_types']),
      socketTypes: _toStringList(grouping['socket_types']),
      wetRoomTypes: _toStringList(grouping['wet_room_types']),
      maxSocketsPerGroup: limits['max_sockets_per_group'] as int? ?? 10,
      maxPowerKwPerSocketGroup:
          (limits['max_power_kw_per_socket_group'] as num?)?.toDouble() ?? 3.5,
      defaultRcdMa: rcdRules['default_rcd_ma'] as int? ?? 30,
      lightingDefaultAmps: selection['lighting_default_a'] as int? ?? 10,
      socketsDefaultAmps: selection['sockets_default_a'] as int? ?? 16,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
