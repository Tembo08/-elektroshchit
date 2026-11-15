import 'package:yaml/yaml.dart';

import '../models/template.dart';
import 'norms_models.dart';

/// Загружает каталог норм из YAML-строк (или Map).
/// Flutter передаёт содержимое assets, тесты — содержимое файлов.
class NormsLoader {
  /// Собирает NormsCatalog из уже прочитанных YAML-текстов.
  ///
  /// Отсутствующие необязательные ключи заменяются значениями по умолчанию,
  /// но обязательные структуры (`sections`, `breakers`) проверяются явно:
  /// лучше понятная ошибка загрузки, чем молча неверный щиток.
  static NormsCatalog fromYamlTexts({
    required String version,
    required String cableSectionsYaml,
    required String breakersYaml,
    required String rcdYaml,
    required String groupingRulesYaml,
    String? roomDefaultsYaml,
  }) {
    final cables = _map(loadYaml(cableSectionsYaml), 'cable_sections');
    final breakersMap = _map(loadYaml(breakersYaml), 'breakers');
    final rcdMap = _map(loadYaml(rcdYaml), 'rcd');
    final grouping = _map(loadYaml(groupingRulesYaml), 'grouping_rules');

    final cableSections = <CableSectionNorm>[];
    for (final item in _list(cables['sections'], 'sections')) {
      final m = _map(item, 'sections[]');
      cableSections.add(CableSectionNorm(
        sectionMm2: _num(m['section_mm2'], 'section_mm2').toDouble(),
        maxCurrentA: _num(m['max_current_a'], 'max_current_a').toDouble(),
        typicalUse: m['typical_use']?.toString() ?? '',
        cores: _num(m['cores'], 'cores').toInt(),
        description: m['description']?.toString() ?? '',
      ));
    }

    final breakers = <BreakerNorm>[];
    for (final item in _list(breakersMap['breakers'], 'breakers')) {
      final m = _map(item, 'breakers[]');
      breakers.add(BreakerNorm(
        amps: _num(m['amps'], 'amps').toInt(),
        curve: m['curve']?.toString() ?? 'C',
        typicalUse: m['typical_use']?.toString() ?? '',
        dinModules: _num(m['din_modules'], 'din_modules').toInt(),
      ));
    }

    final rcdOptions = <RcdNorm>[];
    for (final item in _list(rcdMap['rcd_options'], 'rcd_options')) {
      final m = _map(item, 'rcd_options[]');
      rcdOptions.add(RcdNorm(
        ma: _num(m['ma'], 'ma').toInt(),
        typicalUse: m['typical_use']?.toString() ?? '',
        dinModules: _num(m['din_modules'], 'din_modules').toInt(),
      ));
    }

    final minSections = cables['min_section_by_load'] is YamlMap
        ? _map(cables['min_section_by_load'], 'min_section_by_load')
        : YamlMap();
    final groupingLimits = grouping['limits'] is YamlMap
        ? _map(grouping['limits'], 'grouping_rules.limits')
        : YamlMap();
    final selection = breakersMap['selection_rules'] is YamlMap
        ? _map(breakersMap['selection_rules'], 'selection_rules')
        : YamlMap();
    final rcdRules = rcdMap['rules'] is YamlMap
        ? _map(rcdMap['rules'], 'rcd.rules')
        : YamlMap();

    final templates = <ProjectTemplate>[];
    final defaultPower = <String, double>{};
    if (roomDefaultsYaml != null && roomDefaultsYaml.trim().isNotEmpty) {
      final roomDefaults = _map(loadYaml(roomDefaultsYaml), 'room_defaults');
      final powerMap = roomDefaults['default_power_kw'];
      if (powerMap is YamlMap) {
        for (final entry in powerMap.entries) {
          final value = entry.value;
          if (value is num) defaultPower[entry.key.toString()] = value.toDouble();
        }
      }
      final templatesMap = roomDefaults['templates'];
      if (templatesMap is YamlMap) {
        for (final entry in templatesMap.entries) {
          final m = entry.value;
          if (m is! YamlMap) continue;
          final rooms = <TemplateRoom>[];
          final roomsList = m['rooms'];
          if (roomsList is YamlList) {
            for (final r in roomsList) {
              if (r is! YamlMap) continue;
              final consumers = <TemplateConsumer>[];
              final consumersList = r['consumers'];
              if (consumersList is YamlList) {
                for (final c in consumersList) {
                  if (c is! YamlMap) continue;
                  consumers.add(TemplateConsumer(
                    type: c['type']?.toString() ?? '',
                    quantity: _intOr(c['quantity'], 1),
                    powerKw: (c['power_kw'] is num)
                        ? (c['power_kw'] as num).toDouble()
                        : null,
                    isPowerful: c['is_powerful'] == true,
                  ));
                }
              }
              rooms.add(TemplateRoom(
                type: r['type']?.toString() ?? 'other',
                name: r['name']?.toString() ?? '',
                area: _doubleOr(r['area'], 0),
                consumers: consumers,
              ));
            }
          }
          templates.add(ProjectTemplate(
            id: entry.key.toString(),
            name: m['name']?.toString() ?? entry.key.toString(),
            description: m['description']?.toString() ?? '',
            objectType: m['object_type']?.toString() ?? 'apartment',
            suggestedPowerKw: _doubleOr(m['suggested_power_kw'], 0),
            rooms: rooms,
          ));
        }
      }
    }

    final ratings = <int>[];
    if (rcdMap['ratings_a'] is YamlList) {
      for (final a in _list(rcdMap['ratings_a'], 'ratings_a')) {
        ratings.add(_num(a, 'ratings_a[]').toInt());
      }
    }

    return NormsCatalog(
      version: version,
      cableTypeDefault: cables['cable_type_default']?.toString() ?? 'ВВГнг-LS',
      cableSections: cableSections,
      breakers: breakers,
      rcdOptions: rcdOptions,
      powerfulTypes: _toStringList(grouping['powerful_types']),
      lightingTypes: _toStringList(grouping['lighting_types']),
      socketTypes: _toStringList(grouping['socket_types']),
      wetRoomTypes: _toStringList(grouping['wet_room_types']),
      maxSocketsPerGroup: _intOr(groupingLimits['max_sockets_per_group'], 10),
      maxPowerKwPerSocketGroup:
          _doubleOr(groupingLimits['max_power_kw_per_socket_group'], 3.5),
      maxLightingPointsPerGroup:
          _intOr(groupingLimits['max_lighting_points_per_group'], 15),
      defaultRcdMa: _intOr(rcdRules['default_rcd_ma'], 30),
      bathRcdMa: _intOr(rcdRules['bath_rcd_ma'], 10),
      fireRcdMa: _intOr(rcdRules['fire_protection_rcd_ma'], 100),
      maxLinesPerRcd: _intOr(rcdRules['max_lines_per_rcd'], 4),
      fireRcdType: rcdRules['fire_rcd_type']?.toString().toUpperCase() ?? 'S',
      typeARcdType: rcdRules['type_a_rcd_type']?.toString().toUpperCase() ?? 'A',
      typeAElectronicTypes: rcdRules['type_a_types'] is YamlList
          ? _toStringList(rcdRules['type_a_types'])
          : const [
              'washingMachine',
              'dishwasher',
              'evCharger',
              'airConditioner',
              'underfloorHeating',
            ],
      defaultPowerKw: defaultPower,
      templates: templates,
      rcdType: rcdRules['rcd_type']?.toString().toUpperCase() ?? 'AC',
      rcdRatings: ratings.isEmpty
          ? const [16, 25, 32, 40, 50, 63, 80, 100]
          : ratings,
      lightingDefaultAmps: _intOr(selection['lighting_default_a'], 10),
      socketsDefaultAmps: _intOr(selection['sockets_default_a'], 16),
      socketsMaxAmps: _intOr(selection['sockets_max_a'], 16),
      powerfulMinAmps: _intOr(selection['powerful_min_a'], 16),
      lightingMaxAmps: _intOr(selection['lighting_max_a'], 16),
      heavyLoadKw: _doubleOr(minSections['heavy_load_kw'], 3.5),
      heavyMinSection: _doubleOr(minSections['heavy_min_section'], 4.0),
      minSectionLighting: _doubleOr(minSections['lighting'], 1.5),
      minSectionSockets: _doubleOr(minSections['sockets'], 2.5),
      minSectionPowerful: _doubleOr(minSections['powerful'], 2.5),
    );
  }

  static YamlMap _map(dynamic value, String what) {
    if (value is YamlMap) return value;
    throw FormatException(
      'Нормы: ожидался раздел "$what" (map), получено ${value.runtimeType}',
    );
  }

  static YamlList _list(dynamic value, String what) {
    if (value is YamlList) return value;
    throw FormatException(
      'Нормы: ожидался список "$what" (list), получено ${value.runtimeType}',
    );
  }

  static num _num(dynamic value, String what) {
    if (value is num) return value;
    throw FormatException('Нормы: "$what" должен быть числом, получено $value');
  }

  static int _intOr(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return fallback;
  }

  static double _doubleOr(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return fallback;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
