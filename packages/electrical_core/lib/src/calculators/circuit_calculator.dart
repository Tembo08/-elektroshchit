import 'dart:math' as math;

import '../models/circuit_group.dart';
import '../models/consumer.dart';
import '../models/enums.dart';
import '../models/panel_result.dart';
import '../models/project.dart';
import '../models/room.dart';
import '../models/protection_device.dart';
import '../norms/norms_models.dart';

class CalculationResult {
  final List<CircuitGroup> groups;
  final PanelResult panel;
  final List<String> warnings;
  final CircuitGroup? inputGroup;

  const CalculationResult({
    required this.groups,
    required this.panel,
    required this.warnings,
    this.inputGroup,
  });
}

class CircuitCalculator {
  final NormsCatalog norms;

  const CircuitCalculator(this.norms);

  CalculationResult calculate(
    Project project, {
    int? inputBreakerAmps,
    int lightingLines = 2,
    int socketLines = 2,
  }) {
    final warnings = <String>[
      'Результат является черновиком и требует проверки квалифицированным электриком',
    ];

    final groups = <CircuitGroup>[];
    final devices = <ProtectionDevice>[];
    var groupIndex = 1;
    var deviceIndex = 1;

    // --- 1) Силовые и «прочее» по комнатам (отдельные линии) ---
    final allLighting = <Consumer>[];
    final allSockets = <({Room room, Consumer c})>[];
    final bathSockets = <({Room room, Consumer c})>[];

    for (final room in project.rooms) {
      final isBath =
          room.type == RoomType.bathroom ||
          room.type == RoomType.combinedBathroom ||
          room.type == RoomType.toilet;

      for (final c in room.consumers) {
        final typeName = c.type.name;
        if (c.isPowerful || norms.powerfulTypes.contains(typeName)) {
          groups.add(
            _buildGroup(
              index: groupIndex++,
              name: '${c.name} (${room.name})',
              consumers: [c],
              room: room,
              kind: _GroupKind.powerful,
              phaseSystem: project.phaseSystem,
              parentRcdId: null,
            ),
          );
        } else if (norms.lightingTypes.contains(typeName)) {
          allLighting.add(c);
        } else if (norms.socketTypes.contains(typeName)) {
          if (isBath) {
            bathSockets.add((room: room, c: c));
          } else {
            allSockets.add((room: room, c: c));
          }
        } else {
          // выключатели и прочее — к освещению не цепляем в щит как нагрузку
          if (typeName.startsWith('switch')) {
            // игнор для групп щита
          } else {
            groups.add(
              _buildGroup(
                index: groupIndex++,
                name: '${c.name} (${room.name})',
                consumers: [c],
                room: room,
                kind: _GroupKind.other,
                phaseSystem: project.phaseSystem,
                parentRcdId: null,
              ),
            );
          }
        }
      }
    }

    // --- 2) Освещение: N линий под одно УЗО 30 мА ---
    final lightChunks = _splitConsumers(allLighting, lightingLines);
    if (lightChunks.isNotEmpty) {
      final rcdId = 'rcd_light_${deviceIndex++}';
      final childIds = <String>[];
      final dummyRoom = project.rooms.isNotEmpty
          ? project.rooms.first
          : Room(
              id: 'x',
              name: 'Объект',
              type: RoomType.other,
              area: 1,
              consumers: const [],
            );

      for (var i = 0; i < lightChunks.length; i++) {
        final chunk = lightChunks[i];
        if (chunk.isEmpty) continue;
        final g = _buildGroup(
          index: groupIndex++,
          name: lightChunks.length == 1
              ? 'Освещение'
              : 'Освещение — линия ${i + 1}',
          consumers: chunk,
          room: dummyRoom,
          kind: _GroupKind.lighting,
          phaseSystem: project.phaseSystem,
          parentRcdId: rcdId,
          forceNoOwnRcd: true,
        );
        groups.add(g);
        childIds.add(g.id);
      }

      if (childIds.isNotEmpty) {
        devices.add(
          ProtectionDevice(
            id: rcdId,
            kind: ProtectionKind.rcd,
            name: 'УЗО 30 мА (освещение)',
            amps: _rcdAmpsForLighting(lightChunks.length),
            rcdMa: 30,
            dinModules: 2,
            childBreakerIds: childIds,
          ),
        );
      }
    }

    // --- 3) Обычные розетки: M линий под одно УЗО 30 мА ---
    final socketConsumers = allSockets.map((e) => e.c).toList();
    final socketChunks = _splitConsumers(socketConsumers, socketLines);
    if (socketChunks.isNotEmpty) {
      final rcdId = 'rcd_sock_${deviceIndex++}';
      final childIds = <String>[];
      final dummyRoom = project.rooms.isNotEmpty
          ? project.rooms.first
          : Room(
              id: 'x',
              name: 'Объект',
              type: RoomType.other,
              area: 1,
              consumers: const [],
            );

      for (var i = 0; i < socketChunks.length; i++) {
        final chunk = socketChunks[i];
        if (chunk.isEmpty) continue;
        final g = _buildGroup(
          index: groupIndex++,
          name: socketChunks.length == 1
              ? 'Розетки'
              : 'Розетки — линия ${i + 1}',
          consumers: chunk,
          room: dummyRoom,
          kind: _GroupKind.sockets,
          phaseSystem: project.phaseSystem,
          parentRcdId: rcdId,
          forceNoOwnRcd: true,
        );
        groups.add(g);
        childIds.add(g.id);
      }

      if (childIds.isNotEmpty) {
        devices.add(
          ProtectionDevice(
            id: rcdId,
            kind: ProtectionKind.rcd,
            name: 'УЗО 30 мА (розетки)',
            amps: _rcdAmpsForSockets(socketChunks.length),
            rcdMa: 30,
            dinModules: 2,
            childBreakerIds: childIds,
          ),
        );
      }
    }

    // --- 4) Розетки санузла: отдельное УЗО 10 мА ---
    if (bathSockets.isNotEmpty) {
      final rcdId = 'rcd_bath_${deviceIndex++}';
      final room = bathSockets.first.room;
      final list = bathSockets.map((e) => e.c).toList();
      final g = _buildGroup(
        index: groupIndex++,
        name: 'Розетки — санузел',
        consumers: list,
        room: room,
        kind: _GroupKind.sockets,
        phaseSystem: project.phaseSystem,
        parentRcdId: rcdId,
        forceNoOwnRcd: true,
        forceRcdMa: 10,
      );
      groups.add(g);
      devices.add(
        ProtectionDevice(
          id: rcdId,
          kind: ProtectionKind.rcd,
          name: 'УЗО 10 мА (санузел)',
          amps: 25,
          rcdMa: 10,
          dinModules: 2,
          childBreakerIds: [g.id],
        ),
      );
    }

    // Фазы
    if (project.phaseSystem == PhaseSystem.three) {
      _assignPhases(groups);
    } else {
      for (var i = 0; i < groups.length; i++) {
        groups[i] = groups[i].copyWith(phase: 'L');
      }
    }

    final inputGroup = _buildInputGroup(
      project,
      fixedBreakerAmps: inputBreakerAmps,
    );

    // DIN: ввод + УЗО-родители + автоматы групп
    final groupsDin = groups.fold<int>(0, (s, g) => s + g.dinModules);
    final rcdDin = devices.fold<int>(0, (s, d) => s + d.dinModules);
    final totalDin = groupsDin + rcdDin + inputGroup.dinModules;

    final totalPower = groups.fold<double>(0, (s, g) => s + g.totalPowerKw);
    final loadFactor = project.allowedPowerKw > 0
        ? totalPower / project.allowedPowerKw
        : 0.0;
    final isInputSufficient = totalPower <= project.allowedPowerKw;

    if (!isInputSufficient) {
      warnings.add(
        'Суммарная расчётная нагрузка (${totalPower.toStringAsFixed(1)} кВт) '
        'превышает разрешённую мощность по ТУ (${project.allowedPowerKw} кВт)',
      );
    }

    final recommendedDin = (totalDin * 1.25).ceil();

    final panel = PanelResult(
      totalDinModules: totalDin,
      recommendedPanelModules: recommendedDin,
      recommendedPanelSize: _panelSizeLabel(recommendedDin),
      groups: groups,
      totalCalculatedPowerKw: totalPower,
      loadFactor: loadFactor,
      isInputSufficient: isInputSufficient,
      materials: _buildMaterials(groups, inputGroup, devices),
      protectionDevices: devices,
    );

    return CalculationResult(
      groups: groups,
      panel: panel,
      warnings: warnings,
      inputGroup: inputGroup,
    );
  }

  List<List<Consumer>> _splitConsumers(List<Consumer> items, int lines) {
    if (items.isEmpty) return [];
    final n = lines < 1 ? 1 : lines;
    if (n == 1) return [items];

    // Разворачиваем quantity в «единицы» грубо: один Consumer = одна порция
    final buckets = List.generate(n, (_) => <Consumer>[]);
    for (var i = 0; i < items.length; i++) {
      buckets[i % n].add(items[i]);
    }
    return buckets.where((b) => b.isNotEmpty).toList();
  }

  /// In УЗО для освещения (линии по ~10 А)
  int _rcdAmpsForLighting(int lines) {
    if (lines <= 1) return 25;
    if (lines == 2) return 25;
    if (lines <= 4) return 40;
    return 63;
  }

  /// In УЗО для розеток (линии по ~16 А)
  int _rcdAmpsForSockets(int lines) {
    if (lines <= 1) return 25;
    if (lines == 2) return 32;
    if (lines == 3) return 40;
    return 63; // 4 и более
  }

  CircuitGroup _buildInputGroup(Project project, {int? fixedBreakerAmps}) {
    final power = project.allowedPowerKw;
    final currentA = _currentFromPower(power, project.phaseSystem);

    final BreakerNorm breaker;
    if (fixedBreakerAmps != null) {
      breaker = norms.breakers.firstWhere(
        (b) => b.amps == fixedBreakerAmps,
        orElse: () =>
            norms.breakerForCurrent(fixedBreakerAmps.toDouble()) ??
            norms.breakers.last,
      );
    } else {
      final targetAmps = math.max(currentA, 40.0);
      breaker = norms.breakerForCurrent(targetAmps) ?? norms.breakers.last;
    }

    final section =
        norms.sectionForCurrent(breaker.amps.toDouble()) ??
        norms.cableSections.last;

    const fireRcdMa = 100;
    final din = breaker.dinModules + 2;
    final cores = project.phaseSystem == PhaseSystem.three ? 5 : 3;
    final cableType =
        '${norms.cableTypeDefault} ${cores}×${_formatSection(section.sectionMm2)}';

    return CircuitGroup(
      id: 'input',
      name: 'Ввод',
      consumerIds: const [],
      totalPowerKw: power,
      calculatedCurrentA: currentA,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breaker.amps,
      breakerCurve: breaker.curve,
      hasRcd: true,
      rcdMa: fireRcdMa,
      isDifferentialBreaker: false,
      dinModules: din,
      cableType: cableType,
      phase: project.phaseSystem == PhaseSystem.three ? 'L1-L2-L3' : 'L',
      warnings: const ['На вводе рекомендуется противопожарное УЗО 100 мА'],
    );
  }

  CircuitGroup _buildGroup({
    required int index,
    required String name,
    required List<Consumer> consumers,
    required Room room,
    required _GroupKind kind,
    required PhaseSystem phaseSystem,
    String? parentRcdId,
    bool forceNoOwnRcd = false,
    int? forceRcdMa,
  }) {
    final totalPower = consumers.fold<double>(0, (s, c) {
      final p = c.powerKw ?? _defaultPower(c);
      return s + p * c.quantity;
    });

    final currentA = _currentFromPower(totalPower, phaseSystem);

    late int breakerAmps;
    late double minSection;
    var hasRcd = false;
    int? rcdMa;
    final groupWarnings = <String>[];

    switch (kind) {
      case _GroupKind.lighting:
        breakerAmps = norms.lightingDefaultAmps;
        minSection = 1.5;
        break;
      case _GroupKind.sockets:
        breakerAmps = math.max(norms.socketsDefaultAmps, _ampsCeil(currentA));
        minSection = 2.5;
        hasRcd = true;
        rcdMa = norms.defaultRcdMa;
        break;
      case _GroupKind.powerful:
      case _GroupKind.other:
        final minA = currentA > 0 ? currentA : 16.0;
        var raw = norms.breakerForCurrent(minA)?.amps ?? 16;
        // Силовые линии — не ниже 16 А (не 6 и не 10)
        breakerAmps = math.max(16, raw);
        minSection = totalPower >= 3.5 ? 4.0 : 2.5;
        // Варочная / очень мощные — сечение не меньше 6 мм² при ≥25 А
        if (breakerAmps >= 25) {
          minSection = math.max(minSection, 6.0);
        }
        hasRcd =
            norms.wetRoomTypes.contains(room.type.name) ||
            consumers.any((c) => c.requiresRcd);
        if (hasRcd) rcdMa = norms.defaultRcdMa;
        break;
    }

    if (kind == _GroupKind.sockets &&
        norms.wetRoomTypes.contains(room.type.name)) {
      hasRcd = true;
      rcdMa = norms.defaultRcdMa;
    }

    final isBath =
        room.type == RoomType.bathroom ||
        room.type == RoomType.combinedBathroom ||
        room.type == RoomType.toilet;

    if (isBath && hasRcd) {
      rcdMa = 10;
    }

    if (forceNoOwnRcd) {
      hasRcd = false;
      rcdMa = null;
    }
    if (forceRcdMa != null && !forceNoOwnRcd) {
      hasRcd = true;
      rcdMa = forceRcdMa;
    }

    final byBreaker = norms.sectionForCurrent(breakerAmps.toDouble());
    final needed = math.max(minSection, byBreaker?.sectionMm2 ?? minSection);

    final candidates = norms.cableSections.where(
      (s) => s.sectionMm2 >= needed - 0.001,
    );
    final section = candidates.isEmpty
        ? norms.cableSections.last
        : candidates.reduce((a, b) => a.sectionMm2 <= b.sectionMm2 ? a : b);

    final breakerNorm = norms.breakers.firstWhere(
      (b) => b.amps == breakerAmps,
      orElse: () => norms.breakers.first,
    );
    final dinModules = forceNoOwnRcd
        ? breakerNorm.dinModules
        : breakerNorm.dinModules + (hasRcd ? 2 : 0);

    if (section.maxCurrentA < breakerAmps) {
      groupWarnings.add(
        'Проверьте соответствие сечения ${section.sectionMm2} мм² и автомата ${breakerAmps}А',
      );
    }

    return CircuitGroup(
      id: 'grp_$index',
      name: 'Гр. $index — $name',
      consumerIds: consumers.map((c) => c.id).toList(),
      totalPowerKw: totalPower,
      calculatedCurrentA: currentA,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breakerAmps,
      breakerCurve: 'C',
      hasRcd: hasRcd,
      rcdMa: rcdMa,
      isDifferentialBreaker: false,
      dinModules: dinModules,
      cableType: section.description,
      warnings: groupWarnings,
      parentRcdId: parentRcdId,
    );
  }

  double _currentFromPower(double powerKw, PhaseSystem phase) {
    if (powerKw <= 0) return 0;
    if (phase == PhaseSystem.three) {
      return (powerKw * 1000) / (230 * math.sqrt(3));
    }
    return (powerKw * 1000) / 230;
  }

  int _ampsCeil(double currentA) {
    if (currentA <= 0) return norms.socketsDefaultAmps;
    final sorted = norms.breakers.map((b) => b.amps).toList()..sort();
    for (final a in sorted) {
      if (a >= currentA) return a;
    }
    return sorted.last;
  }

  void _assignPhases(List<CircuitGroup> groups) {
    final loads = {'L1': 0.0, 'L2': 0.0, 'L3': 0.0};
    final sorted = [...groups]
      ..sort((a, b) => b.totalPowerKw.compareTo(a.totalPowerKw));

    for (final g in sorted) {
      final phase = loads.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      loads[phase] = loads[phase]! + g.totalPowerKw;
      final idx = groups.indexWhere((x) => x.id == g.id);
      if (idx >= 0) {
        groups[idx] = groups[idx].copyWith(phase: phase);
      }
    }
  }

  double _defaultPower(Consumer c) {
    switch (c.type) {
      case ConsumerType.socket:
        return 0.1;
      case ConsumerType.lightPoint:
      case ConsumerType.chandelier:
      case ConsumerType.ledStrip:
        return 0.05;
      case ConsumerType.refrigerator:
        return 0.3;
      case ConsumerType.hood:
        return 0.2;
      case ConsumerType.switchSingle:
      case ConsumerType.switchDouble:
      case ConsumerType.switchPassThrough:
        return 0.0;
      default:
        return c.powerKw ?? 1.0;
    }
  }

  String _formatSection(double s) {
    return s == s.roundToDouble() ? s.toInt().toString() : s.toString();
  }

  String _panelSizeLabel(int modules) {
    if (modules <= 12) return '12 модулей';
    if (modules <= 18) return '18 модулей';
    if (modules <= 24) return '24 модуля';
    if (modules <= 36) return '36 модулей';
    if (modules <= 48) return '48 модулей';
    if (modules <= 54) return '54 модуля';
    return '$modules модулей (несколько корпусов)';
  }

  List<MaterialItem> _buildMaterials(
    List<CircuitGroup> groups,
    CircuitGroup input,
    List<ProtectionDevice> devices,
  ) {
    final map = <String, MaterialItem>{};

    void add(String name, String unit, double qty) {
      final existing = map[name];
      if (existing == null) {
        map[name] = MaterialItem(name: name, unit: unit, quantity: qty);
      } else {
        map[name] = MaterialItem(
          name: name,
          unit: unit,
          quantity: existing.quantity + qty,
        );
      }
    }

    add(
      'Вводной автомат ${input.breakerAmps}А (${input.breakerCurve})',
      'шт',
      1,
    );
    if (input.hasRcd && input.rcdMa != null) {
      add('УЗО ${input.rcdMa} мА (ввод, противопожарное)', 'шт', 1);
    }
    add('Кабель ввода ${input.cableType}', 'м', 15);

    for (final d in devices) {
      add('${d.name} ${d.amps}А', 'шт', 1);
    }

    for (final g in groups) {
      if (g.isDifferentialBreaker) {
        add('Дифавтомат ${g.breakerAmps}А / ${g.rcdMa ?? 30} мА', 'шт', 1);
      } else {
        add('Автомат ${g.breakerAmps}А (${g.breakerCurve})', 'шт', 1);
        if (g.hasRcd && g.rcdMa != null && g.parentRcdId == null) {
          add('УЗО ${g.rcdMa} мА', 'шт', 1);
        }
      }
      add('Кабель ${g.cableType}', 'м', 10);
    }

    return map.values.toList();
  }
}

enum _GroupKind { lighting, sockets, powerful, other }
