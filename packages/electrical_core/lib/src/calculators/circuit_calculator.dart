import 'dart:math' as math;

import '../models/circuit_group.dart';
import '../models/consumer.dart';
import '../models/enums.dart';
import '../models/panel_result.dart';
import '../models/project.dart';
import '../models/protection_device.dart';
import '../models/room.dart';
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

/// Единица расчёта: одна точка (розетка/светильник) или один прибор.
class _Unit {
  final Consumer source;
  final String label;
  final double powerKw;

  /// Порядок комнаты: линии собираем «по комнатам», чтобы монтажник не тянул
  /// провода из разных комнат на одну линию.
  final int roomOrder;

  const _Unit(this.source, this.label, this.powerKw, this.roomOrder);
}

/// Мощный прибор, которому нужна отдельная линия.
class _PowerLine {
  final Room room;
  final Consumer consumer;

  const _PowerLine(this.room, this.consumer);
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
    var deviceIndex = 1;

    // --- 1) Раскладываем потребителей по видам ---
    final powerLines = <_PowerLine>[];
    final otherLines = <_PowerLine>[];
    final lightingUnits = <_Unit>[];
    final socketUnits = <_Unit>[];
    final bathSockets = <_Unit>[];

    for (var roomIndex = 0; roomIndex < project.rooms.length; roomIndex++) {
      final room = project.rooms[roomIndex];
      final isBath = _isBathroom(room.type);
      for (final c in room.consumers) {
        final typeName = c.type.name;
        if (c.isPowerful || norms.powerfulTypes.contains(typeName)) {
          powerLines.add(_PowerLine(room, c));
        } else if (norms.lightingTypes.contains(typeName)) {
          lightingUnits.addAll(_expand(c, roomIndex));
        } else if (norms.socketTypes.contains(typeName)) {
          if (isBath) {
            bathSockets.addAll(_expand(c, roomIndex));
          } else {
            socketUnits.addAll(_expand(c, roomIndex));
          }
        } else if (typeName.startsWith('switch')) {
          // выключатель — не нагрузка щита
        } else {
          otherLines.add(_PowerLine(room, c));
        }
      }
    }

    // --- 2) Розеточные линии обычных помещений: лимиты и потолок 16 А ---
    final socketBuckets = _pack(
      socketUnits,
      maxUnits: norms.maxSocketsPerGroup,
      maxPowerKw: norms.maxPowerKwPerSocketGroup,
      minLines: socketLines,
    );
    if (socketBuckets.length > math.max(1, socketLines)) {
      warnings.add(
        'Розетки разбиты на ${socketBuckets.length} '
        '${_linesWord(socketBuckets.length)}: больше '
        '${norms.maxSocketsPerGroup} точек или '
        '${norms.maxPowerKwPerSocketGroup.toStringAsFixed(1)} кВт на линию нельзя',
      );
    }
    if (socketBuckets.isNotEmpty) {
      final rcdId = 'rcd_sock_${deviceIndex++}';
      final childIds = <String>[];
      final childAmps = <int>[];
      for (var i = 0; i < socketBuckets.length; i++) {
        final g = _socketGroup(
          index: groups.length + 1,
          name: socketBuckets.length == 1
              ? 'Розетки'
              : 'Розетки — линия ${i + 1}',
          units: socketBuckets[i],
          rcdId: rcdId,
        );
        groups.add(g);
        childIds.add(g.id);
        childAmps.add(g.breakerAmps);
      }
      devices.add(_parentRcd(
        id: rcdId,
        name: 'УЗО ${norms.defaultRcdMa} мА (розетки)',
        rcdMa: norms.defaultRcdMa,
        childAmps: childAmps,
        childIds: childIds,
        threePhase: project.phaseSystem == PhaseSystem.three,
      ));
    }

    // --- 3) Освещение: N линий под одно УЗО ---
    final lightingBuckets = _pack(
      lightingUnits,
      maxUnits: norms.maxLightingPointsPerGroup,
      maxPowerKw: norms.lightingMaxAmps * 230 / 1000,
      minLines: lightingLines,
    );
    if (lightingBuckets.length > math.max(1, lightingLines)) {
      warnings.add(
        'Освещение разбито на ${lightingBuckets.length} '
        '${_linesWord(lightingBuckets.length)}: больше '
        '${norms.maxLightingPointsPerGroup} точек или перегруз на линию',
      );
    }
    if (lightingBuckets.isNotEmpty) {
      final rcdId = 'rcd_light_${deviceIndex++}';
      final childIds = <String>[];
      final childAmps = <int>[];
      for (var i = 0; i < lightingBuckets.length; i++) {
        final g = _lightingGroup(
          index: groups.length + 1,
          name: lightingBuckets.length == 1
              ? 'Освещение'
              : 'Освещение — линия ${i + 1}',
          units: lightingBuckets[i],
          rcdId: rcdId,
        );
        groups.add(g);
        childIds.add(g.id);
        childAmps.add(g.breakerAmps);
      }
      devices.add(_parentRcd(
        id: rcdId,
        name: 'УЗО ${norms.defaultRcdMa} мА (освещение)',
        rcdMa: norms.defaultRcdMa,
        childAmps: childAmps,
        childIds: childIds,
        threePhase: project.phaseSystem == PhaseSystem.three,
      ));
    }

    // --- 4) Розетки санузла: отдельное УЗО (по практике — 10 мА) ---
    final bathBuckets = _pack(
      bathSockets,
      maxUnits: norms.maxSocketsPerGroup,
      maxPowerKw: norms.maxPowerKwPerSocketGroup,
      minLines: 1,
    );
    if (bathBuckets.isNotEmpty) {
      final rcdId = 'rcd_bath_${deviceIndex++}';
      final childIds = <String>[];
      final childAmps = <int>[];
      for (var i = 0; i < bathBuckets.length; i++) {
        final g = _socketGroup(
          index: groups.length + 1,
          name: bathBuckets.length == 1
              ? 'Розетки — санузел'
              : 'Розетки — санузел ${i + 1}',
          units: bathBuckets[i],
          rcdId: rcdId,
        );
        groups.add(g);
        childIds.add(g.id);
        childAmps.add(g.breakerAmps);
      }
      devices.add(_parentRcd(
        id: rcdId,
        name: 'УЗО ${norms.bathRcdMa} мА (санузел)',
        rcdMa: norms.bathRcdMa,
        childAmps: childAmps,
        childIds: childIds,
        threePhase: project.phaseSystem == PhaseSystem.three,
      ));
    }

    // Не вешаем больше N линий на одно УЗО 30 мА: иначе номинала не хватает,
    // а суммарная утечка даёт ложные отключения. Делим на несколько УЗО.
    _limitRcdChildren(
      groups,
      devices,
      idPrefix: 'rcd_sock_',
      baseName: 'УЗО ${norms.defaultRcdMa} мА (розетки)',
      rcdMa: norms.defaultRcdMa,
      maxLines: norms.maxLinesPerRcd,
      threePhase: project.phaseSystem == PhaseSystem.three,
    );
    _limitRcdChildren(
      groups,
      devices,
      idPrefix: 'rcd_light_',
      baseName: 'УЗО ${norms.defaultRcdMa} мА (освещение)',
      rcdMa: norms.defaultRcdMa,
      maxLines: norms.maxLinesPerRcd,
      threePhase: project.phaseSystem == PhaseSystem.three,
    );
    _limitRcdChildren(
      groups,
      devices,
      idPrefix: 'rcd_bath_',
      baseName: 'УЗО ${norms.bathRcdMa} мА (санузел)',
      rcdMa: norms.bathRcdMa,
      maxLines: norms.maxLinesPerRcd,
      threePhase: project.phaseSystem == PhaseSystem.three,
    );

    // --- 5) Мощные приборы и «прочее» — отдельная линия на прибор ---
    for (final line in [...powerLines, ...otherLines]) {
      groups.add(_powerfulGroup(
        index: groups.length + 1,
        room: line.room,
        consumer: line.consumer,
        phaseSystem: project.phaseSystem,
      ));
    }

    // Фазы: трёхфазные Линии получают все три, однофазные распределяются
    // по наименьшей загрузке, фаза УЗО-родителя учитывается по полюсам.
    if (project.phaseSystem == PhaseSystem.three) {
      _assignPhases(groups);
    } else {
      for (var i = 0; i < groups.length; i++) {
        groups[i] = groups[i].copyWith(phase: 'L');
      }
    }

    // --- 6) Ввод ---
    final inputGroup = _buildInputGroup(
      project,
      fixedBreakerAmps: inputBreakerAmps,
      warnings: warnings,
    );

    // --- 7) Итоги ---
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

    // Предупреждения уровня линии поднимаем в общий список, чтобы их
    // нельзя было не показать в интерфейсе.
    for (final g in groups) {
      for (final w in g.warnings) {
        warnings.add('${g.name}: $w');
      }
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

  // ─────────────────────────── линии ───────────────────────────

  CircuitGroup _socketGroup({
    required int index,
    required String name,
    required List<_Unit> units,
    required String rcdId,
  }) {
    final power = units.fold<double>(0, (s, u) => s + u.powerKw);
    final current = _currentFromPower(power, 1);
    final warnings = <String>[];

    // Правило практики: розеточная группа — не более 16 А.
    final breaker = math.min(norms.socketsDefaultAmps, norms.socketsMaxAmps);
    if (current > breaker) {
      warnings.add(
        'Перегруз: расчётный ток ${current.toStringAsFixed(1)} А больше '
        'автомата $breaker А — уменьшите число/мощность потребителей',
      );
    }
    final section = _chooseSection(
      minSection: norms.minSectionSockets,
      breakerAmps: breaker,
      warnings: warnings,
      label: name,
    );

    return CircuitGroup(
      id: 'grp_$index',
      name: 'Гр. $index — $name',
      consumerIds: units.map((u) => u.source.id).toList(),
      totalPowerKw: power,
      calculatedCurrentA: current,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breaker,
      breakerCurve: 'C',
      dinModules: breakerDinModules(breaker, 1),
      cableType: '${norms.cableTypeDefault} 3×${_formatSection(section.sectionMm2)}',
      warnings: warnings,
      parentRcdId: rcdId,
      parentRcdPoles: null,
      hasRcd: false,
    );
  }

  CircuitGroup _lightingGroup({
    required int index,
    required String name,
    required List<_Unit> units,
    required String rcdId,
  }) {
    final power = units.fold<double>(0, (s, u) => s + u.powerKw);
    final current = _currentFromPower(power, 1);
    final warnings = <String>[];

    var breakerNorm = norms.breakerForCurrent(
      math.max(current, norms.lightingDefaultAmps.toDouble()),
    );
    if (breakerNorm == null) {
      warnings.add('Ряд автоматов не покрывает ток ${current.toStringAsFixed(1)} А');
      breakerNorm = norms.breakerByAmps(norms.lightingMaxAmps);
    }
    var breaker = breakerNorm?.amps ?? norms.lightingMaxAmps;
    if (breaker > norms.lightingMaxAmps) {
      warnings.add(
        'Ток ${current.toStringAsFixed(1)} А: линия освещения больше '
        '${norms.lightingMaxAmps} А не делается — делите на линии',
      );
      breaker = norms.lightingMaxAmps;
    }
    if (current > breaker) {
      warnings.add(
        'Перегруз: расчётный ток ${current.toStringAsFixed(1)} А больше '
        'автомата $breaker А',
      );
    }
    final section = _chooseSection(
      minSection: norms.minSectionLighting,
      breakerAmps: breaker,
      warnings: warnings,
      label: name,
    );

    return CircuitGroup(
      id: 'grp_$index',
      name: 'Гр. $index — $name',
      consumerIds: units.map((u) => u.source.id).toList(),
      totalPowerKw: power,
      calculatedCurrentA: current,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breaker,
      breakerCurve: 'C',
      dinModules: breakerDinModules(breaker, 1),
      cableType: '${norms.cableTypeDefault} 3×${_formatSection(section.sectionMm2)}',
      warnings: warnings,
      parentRcdId: rcdId,
      hasRcd: false,
    );
  }

  CircuitGroup _powerfulGroup({
    required int index,
    required Room room,
    required Consumer consumer,
    required PhaseSystem phaseSystem,
  }) {
    final phases = consumer.phases == 3 ? 3 : 1;
    final power = _consumerPower(consumer);
    final current = _currentFromPower(power, phases);
    final warnings = <String>[];

    var breakerNorm = norms.breakerForCurrent(
      math.max(current, norms.powerfulMinAmps.toDouble()),
    );
    if (breakerNorm == null) {
      warnings.add(
        'Ряд автоматов не покрывает ток ${current.toStringAsFixed(1)} А — '
        'нужен расчёт распределения/другой ряд',
      );
      breakerNorm = norms.breakerByAmps(norms.powerfulMinAmps);
    }
    final breaker = breakerNorm?.amps ?? norms.powerfulMinAmps;

    final heavy = power >= norms.heavyLoadKw;
    final section = _chooseSection(
      minSection: heavy ? norms.heavyMinSection : norms.minSectionPowerful,
      breakerAmps: breaker,
      warnings: warnings,
      label: consumer.name,
    );

    if (current > breaker) {
      warnings.add(
        'Перегруз: расчётный ток ${current.toStringAsFixed(1)} А больше '
        'автомата $breaker А',
      );
    }

    final inWetRoom = norms.wetRoomTypes.contains(room.type.name);
    final hasRcd = inWetRoom || consumer.requiresRcd;
    final rcdMa = hasRcd ? (_isBathroom(room.type) ? norms.bathRcdMa : norms.defaultRcdMa) : null;

    final rcdModules = phases == 3 ? 4 : 2;
    final din = breakerDinModules(breaker, phases) + (hasRcd ? rcdModules : 0);
    final cores = phases == 3 ? 5 : 3;

    return CircuitGroup(
      id: 'grp_$index',
      name: 'Гр. $index — ${consumer.name} (${room.name})',
      consumerIds: [consumer.id],
      totalPowerKw: power,
      calculatedCurrentA: current,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breaker,
      breakerCurve: 'C',
      hasRcd: hasRcd,
      rcdMa: rcdMa,
      rcdAmps: hasRcd ? norms.rcdRatingAtLeast(breaker.toDouble()) : null,
      dinModules: din,
      cableType:
          '${norms.cableTypeDefault} $cores×${_formatSection(section.sectionMm2)}',
      phase: phaseSystem == PhaseSystem.three && phases == 3
          ? 'L1-L2-L3'
          : null,
      warnings: warnings,
      poles: phases,
    );
  }

  // ─────────────────────────── ввод ───────────────────────────

  CircuitGroup _buildInputGroup(
    Project project, {
    int? fixedBreakerAmps,
    required List<String> warnings,
  }) {
    final threephase = project.phaseSystem == PhaseSystem.three;
    final power = project.allowedPowerKw;
    final currentA = _currentFromPower(power, threephase ? 3 : 1);

    final auto = norms.breakerForCurrent(math.max(currentA, 16));
    var breakerAmps = fixedBreakerAmps ?? auto?.amps ?? norms.breakers.last.amps;
    final breakerNorm = norms.breakerByAmps(breakerAmps);
    if (breakerNorm == null) {
      warnings.add('Вводной автомат $breakerAmps А отсутствует в ряду норм');
    }
    if (fixedBreakerAmps != null) {
      if (currentA > fixedBreakerAmps + 0.01) {
        warnings.add(
          'Вводной автомат $fixedBreakerAmps А меньше тока по ТУ '
          '(${currentA.toStringAsFixed(1)} А) — защита не обеспечит нагрузку',
        );
      } else if (auto != null && fixedBreakerAmps > auto.amps) {
        warnings.add(
          'Вводной автомат $fixedBreakerAmps А больше требуемого по ТУ '
          '(${auto.amps} А) — проверьте, что вводной кабель и счётчик это держат',
        );
      }
    } else if (auto == null) {
      warnings.add(
        'Мощность по ТУ (${power.toStringAsFixed(1)} кВт, '
        '${currentA.toStringAsFixed(1)} А) выходит за ряд автоматов — '
        'нужен расчёт по проекту',
      );
    }

    final poles = threephase ? 3 : 1;
    final warningsList = <String>[
      'На вводе рекомендуется противопожарное УЗО '
          '${norms.fireRcdMa} мА (тип ${norms.fireRcdType})',
    ];
    final section = _chooseSection(
      minSection: norms.minSectionPowerful,
      breakerAmps: breakerAmps,
      warnings: warnings,
      label: 'ввод',
    );
    final cores = threephase ? 5 : 3;
    final rcdAmps = norms.rcdRatingAtLeast(breakerAmps.toDouble());
    final rcdPoles = threephase ? 4 : 2;

    return CircuitGroup(
      id: 'input',
      name: 'Ввод',
      consumerIds: const [],
      totalPowerKw: power,
      calculatedCurrentA: currentA,
      cableSectionMm2: section.sectionMm2,
      breakerAmps: breakerAmps,
      breakerCurve: breakerNorm?.curve ?? 'C',
      hasRcd: true,
      rcdMa: norms.fireRcdMa,
      rcdAmps: rcdAmps,
      dinModules: breakerDinModules(breakerAmps, poles) + rcdPoles,
      cableType:
          '${norms.cableTypeDefault} $cores×${_formatSection(section.sectionMm2)}',
      phase: threephase ? 'L1-L2-L3' : 'L',
      warnings: warningsList,
      poles: poles,
      parentRcdId: null,
    );
  }

  // ─────────────────────────── утилиты ───────────────────────────

  /// Выбор сечения: не меньше минимального по нагрузке и не меньше,
  /// чем требует автомат. Если таблица кончилась — предупреждение, а не
  /// молчаливая подмена последним сечением.
  CableSectionNorm _chooseSection({
    required double minSection,
    required int breakerAmps,
    required List<String> warnings,
    required String label,
  }) {
    var section = norms.sectionAtLeast(minSection) ??
        norms.largestSection ??
        const CableSectionNorm(
          sectionMm2: 1.5,
          maxCurrentA: 10,
          typicalUse: '',
          cores: 3,
          description: '',
        );

    // Поднимаем сечение, пока оно не держит автомат.
    final sorted = [...norms.cableSections]
      ..sort((a, b) => a.sectionMm2.compareTo(b.sectionMm2));
    while (section.maxCurrentA < breakerAmps) {
      final next = sorted.firstWhere(
        (s) => s.sectionMm2 > section.sectionMm2 + 0.001,
        orElse: () => section,
      );
      if (identical(next, section)) break;
      section = next;
    }

    if (section.maxCurrentA < breakerAmps) {
      warnings.add(
        'Сечение ${section.sectionMm2} мм² (макс ${section.maxCurrentA} А) '
        'меньше автомата $breakerAmps А — таблица сечений кончилась, '
        'нужен инженерный расчёт ($label)',
      );
    }
    return section;
  }

  /// Раскладывает точки по линиям: не больше [maxUnits] точек и
  /// [maxPowerKw] на линию, но не меньше [minLines] линий, если точек хватает.
  List<List<_Unit>> _pack(
    List<_Unit> units, {
    required int maxUnits,
    required double maxPowerKw,
    required int minLines,
  }) {
    if (units.isEmpty) return [];
    // Сначала по комнатам (для монтажа), внутри комнаты — от мощных к слабым.
    final sorted = [...units]
      ..sort((a, b) {
        final byRoom = a.roomOrder.compareTo(b.roomOrder);
        if (byRoom != 0) return byRoom;
        return b.powerKw.compareTo(a.powerKw);
      });
    final buckets = <List<_Unit>>[];

    for (final u in sorted) {
      // Кладём в первую подходящую линию, но не смешиваем комнаты:
      // линия продолжается, только если она того же помещения.
      List<_Unit>? target;
      for (final b in buckets) {
        final sameRoom =
            b.isEmpty || b.last.roomOrder == u.roomOrder;
        if (!sameRoom) continue;
        final power = b.fold<double>(0, (s, x) => s + x.powerKw);
        if (b.length < maxUnits && power + u.powerKw <= maxPowerKw + 0.001) {
          target = b;
          break;
        }
      }
      if (target != null) {
        target.add(u);
      } else {
        buckets.add([u]);
      }
    }

    // Пользователь может попросить больше линий (например, свет по зонам).
    // Делим самую большую линию на равные части — 9 точек и 3 линии дают
    // 3+3+3, а не 7+1+1.
    final wanted = math.max(1, minLines);
    while (buckets.length < wanted && sorted.length >= wanted) {
      final donorIndex = buckets.indexWhere((b) => b.length > 1);
      if (donorIndex < 0) break;
      final donor = buckets[donorIndex];
      final remaining = wanted - buckets.length + 1; // сколько частей нарезать
      final parts = math.min(remaining, donor.length);
      if (parts <= 1) break;
      final size = (donor.length / parts).ceil();
      final chunks = <List<_Unit>>[];
      for (var i = 0; i < donor.length; i += size) {
        chunks.add(donor.sublist(i, math.min(i + size, donor.length)));
      }
      buckets.removeAt(donorIndex);
      buckets.addAll(chunks);
    }

    return buckets;
  }

  /// Если под одним УЗО больше [maxLines] линий — делим на несколько
  /// аппаратов и переносим id родителя у групп.
  void _limitRcdChildren(
    List<CircuitGroup> groups,
    List<ProtectionDevice> devices, {
    required String idPrefix,
    required String baseName,
    required int rcdMa,
    required int maxLines,
    required bool threePhase,
  }) {
    final index = devices.indexWhere((d) => d.id.startsWith(idPrefix));
    if (index < 0) return;
    final dev = devices[index];
    final childIds = dev.childBreakerIds;
    if (maxLines <= 0 || childIds.length <= maxLines) return;

    final chunks = <List<String>>[];
    for (var i = 0; i < childIds.length; i += maxLines) {
      chunks.add(childIds.sublist(i, math.min(i + maxLines, childIds.length)));
    }

    final replacements = <ProtectionDevice>[];
    for (var c = 0; c < chunks.length; c++) {
      final id = '${dev.id}_$c';
      final suffix = c == 0 ? '' : ' ${c + 1}';
      final name = '$baseName$suffix';
      final chunkIds = chunks[c];
      final amps = <int>[];
      for (var i = 0; i < groups.length; i++) {
        if (chunkIds.contains(groups[i].id)) {
          groups[i] = groups[i].copyWith(parentRcdId: id);
          amps.add(groups[i].breakerAmps);
        }
      }
      replacements.add(_parentRcd(
        id: id,
        name: name,
        rcdMa: rcdMa,
        childAmps: amps,
        childIds: chunkIds,
        threePhase: threePhase,
      ));
    }
    devices.replaceRange(index, index + 1, replacements);
  }

  ProtectionDevice _parentRcd({
    required String id,
    required String name,
    required int rcdMa,
    required List<int> childAmps,
    required List<String> childIds,
    required bool threePhase,
  }) {
    final sum = childAmps.fold<int>(0, (s, a) => s + a);
    final amps = norms.rcdRatingAtLeast(sum.toDouble());
    final poles = threePhase ? 4 : 2;
    return ProtectionDevice(
      id: id,
      kind: ProtectionKind.rcd,
      name: '$name $amps А',
      amps: amps,
      rcdMa: rcdMa,
      dinModules: poles,
      childBreakerIds: childIds,
      poles: poles,
      rcdType: norms.rcdType,
    );
  }

  int breakerDinModules(int amps, int poles) {
    final norm = norms.breakerByAmps(amps);
    return (norm?.dinModules ?? 1) * poles;
  }

  /// Ток по мощности: 1 фаза — P/(230), 3 фазы — P/(230·√3).
  double _currentFromPower(double powerKw, int phases) {
    if (powerKw <= 0) return 0;
    if (phases == 3) return (powerKw * 1000) / (230 * math.sqrt(3));
    return (powerKw * 1000) / 230;
  }

  double _consumerPower(Consumer c) {
    final p = c.powerKw ?? _defaultPower(c);
    final qty = c.quantity < 1 ? 1 : c.quantity;
    return p * qty;
  }

  List<_Unit> _expand(Consumer c, int roomOrder) {
    if (c.quantity < 1) return const [];
    final qty = c.quantity;
    final p = c.powerKw ?? _defaultPower(c);
    return List.generate(
      qty,
      (i) => _Unit(c.copyWith(id: '${c.id}#$i'), c.name, p, roomOrder),
    );
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

  bool _isBathroom(RoomType type) =>
      type == RoomType.bathroom ||
      type == RoomType.combinedBathroom ||
      type == RoomType.toilet;

  /// «1 линия / 2 линии / 5 линий» — чтобы предупреждения читались по-русски.
  String _linesWord(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'линий';
    if (mod10 == 1) return 'линия';
    if (mod10 >= 2 && mod10 <= 4) return 'линии';
    return 'линий';
  }

  String _formatSection(double s) {
    return s == s.roundToDouble() ? s.toInt().toString() : s.toString();
  }

  /// Фазы: трёхфазные линии остаются на всех трёх, однофазные раскидываем
  /// по наименьшей загрузке.
  void _assignPhases(List<CircuitGroup> groups) {
    final loads = {'L1': 0.0, 'L2': 0.0, 'L3': 0.0};
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      if (g.poles == 3) {
        groups[i] = g.copyWith(phase: 'L1-L2-L3');
        continue;
      }
      final phase = loads.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      loads[phase] = loads[phase]! + g.totalPowerKw;
      groups[i] = g.copyWith(phase: phase);
    }
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

    final inputPoles = input.poles == 3 ? '3P' : '1P';
    add(
      'Вводной автомат ${input.breakerAmps} А (${input.breakerCurve}), $inputPoles',
      'шт',
      1,
    );
    if (input.hasRcd && input.rcdMa != null) {
      add(
        'УЗО ${input.rcdAmps ?? input.breakerAmps} А / ${input.rcdMa} мА '
        '(ввод, тип ${norms.fireRcdType}, ${input.poles == 3 ? "4P" : "2P"})',
        'шт',
        1,
      );
    }
    add('Кабель ввода ${input.cableType}', 'м', 15);

    for (final d in devices) {
      add('${d.name}, ${d.poles}P', 'шт', 1);
    }

    for (final g in groups) {
      if (g.isDifferentialBreaker) {
        add('Дифавтомат ${g.breakerAmps} А / ${g.rcdMa ?? 30} мА', 'шт', 1);
      } else {
        add(
          'Автомат ${g.breakerAmps} А (${g.breakerCurve}), '
          '${g.poles == 3 ? "3P" : "1P"}',
          'шт',
          1,
        );
        if (g.hasRcd && g.rcdMa != null && g.parentRcdId == null) {
          add(
            'УЗО ${g.rcdAmps ?? g.breakerAmps} А / ${g.rcdMa} мА, '
            '${g.poles == 3 ? "4P" : "2P"}',
            'шт',
            1,
          );
        }
      }
      add('Кабель ${g.cableType}', 'м', 10);
    }

    return map.values.toList();
  }
}
