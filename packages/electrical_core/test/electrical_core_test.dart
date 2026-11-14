import 'dart:io';

import 'package:electrical_core/electrical_core.dart';
import 'package:test/test.dart';

const _normsDir = 'lib/src/norms/ru_2026';
const _assetsDir = '../../assets/norms/ru_2026';

NormsCatalog loadNorms() {
  return NormsLoader.fromYamlTexts(
    version: 'ru_2026',
    cableSectionsYaml: File('$_normsDir/cable_sections.yaml').readAsStringSync(),
    breakersYaml: File('$_normsDir/breakers.yaml').readAsStringSync(),
    rcdYaml: File('$_normsDir/rcd.yaml').readAsStringSync(),
    groupingRulesYaml: File('$_normsDir/grouping_rules.yaml').readAsStringSync(),
    roomDefaultsYaml: File('$_normsDir/room_defaults.yaml').readAsStringSync(),
  );
}

Room room(String id, RoomType type, List<Consumer> consumers) => Room(
      id: id,
      name: id,
      type: type,
      area: 10,
      consumers: consumers,
    );

Consumer c(
  String id,
  ConsumerType type, {
  int qty = 1,
  double? power,
  bool powerful = false,
  bool rcd = false,
  int phases = 1,
}) =>
    Consumer(
      id: id,
      type: type,
      name: type.name,
      quantity: qty,
      powerKw: power,
      isPowerful: powerful,
      requiresRcd: rcd,
      phases: phases,
    );

Project project({
  required List<Room> rooms,
  double powerKw = 10,
  PhaseSystem phase = PhaseSystem.single,
}) =>
    Project(
      id: 'p1',
      name: 'Тест',
      objectType: ObjectType.apartment,
      phaseSystem: phase,
      allowedPowerKw: powerKw,
      groundingSystem: GroundingSystem.tnCs,
      totalArea: 50,
      ceilingHeight: 2.7,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      rooms: rooms,
    );

void main() {
  late NormsCatalog norms;
  late CircuitCalculator calc;

  setUpAll(() {
    norms = loadNorms();
    calc = CircuitCalculator(norms);
  });

  group('нормы', () {
    test('загружаются и содержат сечения для вводов', () {
      expect(norms.cableSections, isNotEmpty);
      expect(norms.defaultRcdMa, 30);
      expect(norms.bathRcdMa, 10);
      expect(norms.fireRcdMa, 100);
      expect(norms.fireRcdType, 'S');
      expect(norms.maxSocketsPerGroup, 10);
      expect(norms.socketsMaxAmps, 16);
      expect(norms.cableSections.map((s) => s.sectionMm2), contains(16.0));
      expect(norms.cableSections.map((s) => s.sectionMm2), contains(25.0));
      expect(norms.cableSections.map((s) => s.sectionMm2), contains(35.0));
    });

    test('таблица сечений не подменяет «не нашлось» последним сечением', () {
      expect(norms.sectionForCurrent(200), isNull);
      expect(norms.breakerForCurrent(500), isNull);
      expect(norms.sectionForCurrent(40)?.sectionMm2, 10);
    });

    test('копии норм в assets и packages совпадают', () {
      for (final f in [
        'cable_sections',
        'breakers',
        'rcd',
        'grouping_rules',
        'room_defaults',
        'stop_scenarios',
      ]) {
        final a = File('$_assetsDir/$f.yaml').readAsStringSync();
        final b = File('$_normsDir/$f.yaml').readAsStringSync();
        expect(a, b, reason: 'нормы $f.yaml разошлись между assets и пакетом');
      }
    });
  });

  group('розеточные группы', () {
    test('не больше 10 точек на линию и автомат не выше 16 А', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 30)]),
        ]),
        socketLines: 1,
        lightingLines: 1,
      );
      final sockets = r.groups.where((g) => g.name.contains('Розетки')).toList();
      expect(sockets.length, 3, reason: '30 точек → 3 линии по 10');
      for (final g in sockets) {
        expect(g.breakerAmps, lessThanOrEqualTo(16));
        expect(g.consumerIds.length, lessThanOrEqualTo(10));
        expect(g.cableSectionMm2, greaterThanOrEqualTo(2.5));
      }
      expect(r.warnings.any((w) => w.contains('Розетки разбиты')), isTrue);
    });

    test('60 розеток на 1 линию — режется на 6 линий, а не даёт 32 А', () {
      final r = calc.calculate(
        project(rooms: [
          room('Дом', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 60)]),
        ], powerKw: 15),
        socketLines: 1,
        lightingLines: 1,
      );
      final sockets = r.groups.where((g) => g.name.contains('Розетки')).toList();
      expect(sockets.length, 6);
      for (final g in sockets) {
        expect(g.breakerAmps, 16);
        expect(g.cableSectionMm2, 2.5);
        expect(g.calculatedCurrentA, lessThanOrEqualTo(16));
      }
    });

    test('запрос пользователя на 3 линии уважается', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 9)]),
        ]),
        socketLines: 3,
        lightingLines: 1,
      );
      expect(
        r.groups.where((g) => g.name.contains('Розетки')).length,
        3,
      );
    });

    test('линии собираются по комнатам, а не вперемешку', () {
      final r = calc.calculate(
        project(rooms: [
          room('Кухня', RoomType.kitchen, [c('k', ConsumerType.socket, qty: 8)]),
          room('Зал', RoomType.livingRoom, [c('z', ConsumerType.socket, qty: 8)]),
        ]),
        socketLines: 1,
        lightingLines: 1,
      );
      final sockets = r.groups.where((g) => g.name.contains('Розетки')).toList();
      expect(sockets.length, 2);
      // Каждая линия — из одной комнаты: id вида k#i или z#i, не смесь.
      for (final g in sockets) {
        final prefixes = g.consumerIds.map((id) => id.split('#').first).toSet();
        expect(prefixes.length, 1, reason: '${g.name} смешала комнаты: $prefixes');
        expect(g.consumerIds.length, 8);
      }
    });

    test('9 точек на 3 линии делятся равномерно (3+3+3, а не 7+1+1)', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 9)]),
        ]),
        socketLines: 3,
        lightingLines: 1,
      );
      final sizes = r.groups
          .where((g) => g.name.contains('Розетки'))
          .map((g) => g.consumerIds.length)
          .toList()
        ..sort();
      expect(sizes, [3, 3, 3]);
    });

    test('аномально мощная розетка даёт предупреждение о перегрузе', () {
      final r = calc.calculate(
        project(rooms: [
          room('Гараж', RoomType.technical, [
            c('s', ConsumerType.socket, qty: 1, power: 5.0),
          ]),
        ], powerKw: 15),
        socketLines: 1,
        lightingLines: 1,
      );
      final g = r.groups.firstWhere((g) => g.name.contains('Розетки'));
      expect(g.calculatedCurrentA, greaterThan(g.breakerAmps));
      expect(g.warnings.any((w) => w.contains('Перегруз')), isTrue);
      expect(r.warnings.any((w) => w.contains('Перегруз')), isTrue,
          reason: 'предупреждения линий обязаны попадать в общий список');
    });
  });

  group('освещение', () {
    test('больше 15 точек — делится на линии', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [
            c('l', ConsumerType.lightPoint, qty: 20),
          ]),
        ]),
        lightingLines: 1,
      );
      final lights = r.groups.where((g) => g.name.contains('Освещение')).toList();
      expect(lights.length, 2);
      for (final g in lights) {
        expect(g.consumerIds.length, lessThanOrEqualTo(15));
      }
    });

    test('перегруз освещения не остаётся молчаливым', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [
            c('l1', ConsumerType.chandelier, power: 3.0),
            c('l2', ConsumerType.ledStrip, power: 2.0),
          ]),
        ], powerKw: 15),
        lightingLines: 1,
      );
      final lights = r.groups.where((g) => g.name.contains('Освещение')).toList();
      expect(lights.length, 2, reason: '5 кВт не влезает в одну линию освещения');
      for (final g in lights) {
        expect(g.calculatedCurrentA, lessThanOrEqualTo(g.breakerAmps));
        expect(g.breakerAmps, lessThanOrEqualTo(norms.lightingMaxAmps));
      }
      expect(r.warnings.any((w) => w.contains('Освещение разбито')), isTrue);
    });
  });

  group('ввод', () {
    test('5 кВт по ТУ — автомат 25 А и кабель не толще 6 мм²', () {
      final r = calc.calculate(
        project(powerKw: 5, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
      );
      final input = r.inputGroup!;
      expect(input.breakerAmps, 25);
      expect(input.cableSectionMm2, lessThanOrEqualTo(6));
      expect(r.warnings.any((w) => w.contains('меньше тока по ТУ')), isFalse);
    });

    test('15 кВт на одной фазе — автомат 80 А и сечение 25 мм²', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
      );
      final input = r.inputGroup!;
      expect(input.calculatedCurrentA, closeTo(65.2, 0.5));
      expect(input.breakerAmps, 80);
      expect(input.cableSectionMm2, greaterThanOrEqualTo(25));
    });

    test('25 кВт на трёх фазах — 5-жильный кабель и сечение под ток', () {
      final r = calc.calculate(
        project(powerKw: 25, phase: PhaseSystem.three, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
      );
      final input = r.inputGroup!;
      expect(input.calculatedCurrentA, closeTo(36.2, 0.3),
          reason: 'ток 3 фаз = P/(3·230), а не P/(230·√3)');
      expect(input.breakerAmps, 40);
      expect(input.cableSectionMm2, 10);
      expect(input.cableType, contains('5×'));
      expect(input.poles, 3);
    });

    test('явно выбранный ввод 63 А получает 16 мм², а не 10', () {
      final r = calc.calculate(
        project(powerKw: 40, phase: PhaseSystem.three, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
        inputBreakerAmps: 63,
      );
      expect(r.inputGroup!.breakerAmps, 63);
      expect(r.inputGroup!.cableSectionMm2, 16);
      expect(
        r.warnings.any((w) => w.contains('таблица сечений кончилась')),
        isFalse,
      );
    });

    test('слишком маленький явный ввод предупреждает', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
        inputBreakerAmps: 25,
      );
      expect(
        r.warnings.any((w) => w.contains('меньше тока по ТУ')),
        isTrue,
      );
    });
  });

  group('мощные потребители и фазы', () {
    test('однофазная варочная 7 кВт в 3-фазной квартире — 32 А, 6 мм²', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('p', ConsumerType.electricStove, power: 7.0, powerful: true, rcd: true),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('electricStove'));
      expect(g.calculatedCurrentA, closeTo(30.4, 0.2));
      expect(g.breakerAmps, 32);
      expect(g.cableSectionMm2, 6);
      expect(g.poles, 1);
    });

    test('трёхфазный прибор получает 3 полюса и ток по √3', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Гараж', RoomType.technical, [
            c('ev', ConsumerType.evCharger,
                power: 7.0, powerful: true, rcd: true, phases: 3),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('evCharger'));
      expect(g.calculatedCurrentA, closeTo(10.1, 0.2));
      expect(g.breakerAmps, 16);
      expect(g.poles, 3);
      expect(g.dinModules, 3 + 4, reason: '3P автомат + 4P УЗО');
      expect(g.cableType, contains('5×'));
      expect(g.phase, 'L1-L2-L3');
    });

    test('бойлер 12 кВт — сечение не меньше 16 мм²', () {
      final r = calc.calculate(
        project(powerKw: 25, rooms: [
          room('Котельная', RoomType.technical, [
            c('b', ConsumerType.boiler, power: 12.0, powerful: true, rcd: true),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('boiler'));
      expect(g.breakerAmps, 63);
      expect(g.cableSectionMm2, greaterThanOrEqualTo(16));
      expect(
        g.warnings.any((w) => w.contains('таблица сечений кончилась')),
        isFalse,
      );
    });
  });

  group('защита от неверного ввода данных', () {
    test('прибор мощнее ряда автоматов не получает 16 А', () {
      final r = calc.calculate(
        project(powerKw: 40, rooms: [
          room('Гараж', RoomType.technical, [
            c('h', ConsumerType.otherPowerful, power: 25.0, powerful: true),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('otherPowerful'));
      expect(g.calculatedCurrentA, closeTo(108.7, 0.5));
      expect(g.breakerAmps, greaterThan(16));
      expect(g.breakerAmps, 100);
      expect(
        g.warnings.any((w) => w.contains('выходит за ряд автоматов')),
        isTrue,
      );
    });

    test('мощный прибор без powerKw получает мощность из room_defaults', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('p', ConsumerType.electricStove, powerful: true, rcd: true),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('electricStove'));
      expect(g.totalPowerKw, 7.0);
      expect(g.breakerAmps, 32);
    });

    test('прибор с quantity 0 не попадает в щит', () {
      final r = calc.calculate(
        project(rooms: [
          room('Кухня', RoomType.kitchen, [
            c('p', ConsumerType.oven, qty: 0, power: 3.5, powerful: true),
            c('s', ConsumerType.socket, qty: 0),
          ]),
        ]),
      );
      expect(r.groups, isEmpty);
    });

    test('трёхфазный прибор в однофазном проекте — предупреждение', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Гараж', RoomType.technical, [
            c('ev', ConsumerType.evCharger, power: 7.0, powerful: true, phases: 3),
          ]),
        ]),
      );
      expect(
        r.groups.first.warnings.any((w) => w.contains('проект однофазный')),
        isTrue,
      );
    });
  });

  group('УЗО', () {
    test('номинал родительского УЗО не меньше суммы автоматов', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 30)]),
        ]),
        socketLines: 1,
      );
      final socketRcd = r.panel.protectionDevices
          .firstWhere((d) => d.name.contains('розетки'));
      final childSum = r.groups
          .where((g) => g.parentRcdId == socketRcd.id)
          .fold<int>(0, (s, g) => s + g.breakerAmps);
      expect(socketRcd.amps, greaterThanOrEqualTo(childSum));
      expect(socketRcd.poles, 2);
      expect(socketRcd.dinModules, 2);
    });

    test('много линий — несколько УЗО, а не одно на 100 А', () {
      final r = calc.calculate(
        project(powerKw: 20, rooms: [
          room('Дом', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 60)]),
        ]),
        socketLines: 1,
      );
      final rcds = r.panel.protectionDevices
          .where((d) => d.name.contains('розетки'))
          .toList();
      expect(rcds.length, greaterThanOrEqualTo(2));
      for (final d in rcds) {
        expect(d.childBreakerIds.length, lessThanOrEqualTo(norms.maxLinesPerRcd));
        expect(d.amps, lessThanOrEqualTo(100));
        expect(d.amps, greaterThanOrEqualTo(16 * d.childBreakerIds.length));
      }
      // каждая розеточная линия привязана ровно к одному УЗО
      final socketGroups =
          r.groups.where((g) => g.name.contains('Розетки')).toList();
      final parents = socketGroups.map((g) => g.parentRcdId).toSet();
      expect(parents.length, rcds.length);
      expect(parents.contains(null), isFalse);
    });

    test('трёхфазная система — родительские УЗО четырёхполюсные', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Кухня', RoomType.kitchen, [c('s', ConsumerType.socket, qty: 8)]),
          room('Зал', RoomType.livingRoom, [c('l', ConsumerType.lightPoint, qty: 4)]),
        ]),
        socketLines: 2,
      );
      for (final d in r.panel.protectionDevices) {
        expect(d.poles, 4, reason: '${d.name} должно быть 4P');
        expect(d.rcdType, norms.rcdType);
      }
    });

    test('влажная комната даёт УЗО даже без флага requiresRcd', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('p', ConsumerType.electricStove, power: 7.0, powerful: true),
          ]),
        ]),
      );
      final g = r.groups.firstWhere((g) => g.name.contains('electricStove'));
      expect(g.hasRcd, isTrue);
      expect(g.rcdMa, 30);
      expect(g.dinModules, 1 + 2);
    });

    test('техника с импульсным БП получает УЗО тип A', () {
      final r = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('w', ConsumerType.washingMachine, power: 2.0, powerful: true),
          ]),
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 4)]),
        ]),
      );
      final washer = r.groups.firstWhere((g) => g.name.contains('washingMachine'));
      expect(washer.rcdType, 'A');
      final socketRcd =
          r.panel.protectionDevices.firstWhere((d) => d.name.contains('розетки'));
      expect(socketRcd.rcdType, 'AC');
      expect(
        r.panel.materials.any((m) => m.name.contains('тип A')),
        isTrue,
      );
    });

    test('санузел — 10 мА, номинал не ниже автомата', () {
      final r = calc.calculate(
        project(rooms: [
          room('Санузел', RoomType.combinedBathroom, [
            c('s', ConsumerType.socket, qty: 2),
          ]),
        ]),
      );
      final bathRcd = r.panel.protectionDevices
          .firstWhere((d) => d.name.contains('санузел'));
      expect(bathRcd.rcdMa, 10);
      final child = r.groups.firstWhere((g) => g.parentRcdId == bathRcd.id);
      expect(bathRcd.amps, greaterThanOrEqualTo(child.breakerAmps));
    });

    test('вводное УЗО — 100 мА тип S, номинал не ниже автомата ввода', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
      );
      final input = r.inputGroup!;
      expect(input.hasRcd, isTrue);
      expect(input.rcdMa, 100);
      expect(input.rcdAmps, greaterThanOrEqualTo(input.breakerAmps));
    });
  });

  group('фазы и мощность', () {
    test('3 фазы: однофазные линии раскиданы по L1/L2/L3', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Кухня', RoomType.kitchen, [c('k', ConsumerType.socket, qty: 6)]),
          room('Зал', RoomType.livingRoom, [c('z', ConsumerType.socket, qty: 6)]),
          room('Спальня', RoomType.bedroom, [c('s', ConsumerType.socket, qty: 6)]),
          room('Котельная', RoomType.technical, [
            c('ev', ConsumerType.evCharger, power: 7.0, powerful: true, phases: 3),
          ]),
        ]),
        socketLines: 3,
        lightingLines: 1,
      );
      final phases = r.groups
          .where((g) => g.poles == 1)
          .map((g) => g.phase)
          .toSet();
      expect(phases, {'L1', 'L2', 'L3'});
      final ev = r.groups.firstWhere((g) => g.name.contains('evCharger'));
      expect(ev.phase, 'L1-L2-L3');
    });

    test('10 розеток по 0,5 кВт = 5 кВт → две линии, а не одна', () {
      final r = calc.calculate(
        project(rooms: [
          room('Мастерская', RoomType.technical, [
            c('s', ConsumerType.socket, qty: 10, power: 0.5),
          ]),
        ]),
        socketLines: 1,
      );
      final sockets = r.groups.where((g) => g.name.contains('Розетки')).toList();
      expect(sockets.length, 2);
      for (final g in sockets) {
        expect(g.totalPowerKw, lessThanOrEqualTo(3.5 + 0.001));
        expect(g.calculatedCurrentA, lessThanOrEqualTo(16));
      }
    });

    test('порог «тяжёлой» нагрузки: 3,5 кВт даёт 4 мм², 3,4 кВт — 2,5', () {
      final heavy = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('o', ConsumerType.oven, power: 3.5, powerful: true),
          ]),
        ]),
      );
      final light = calc.calculate(
        project(powerKw: 15, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('o', ConsumerType.oven, power: 3.4, powerful: true),
          ]),
        ]),
      );
      expect(heavy.groups.first.cableSectionMm2, 4.0);
      expect(light.groups.first.cableSectionMm2, 2.5);
    });

    test('перегруз ТУ выставляет isInputSufficient=false и предупреждает', () {
      final r = calc.calculate(
        project(powerKw: 5, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('p', ConsumerType.electricStove, power: 7.0, powerful: true),
          ]),
        ]),
      );
      expect(r.panel.isInputSufficient, isFalse);
      expect(r.panel.loadFactor, greaterThan(1));
      expect(
        r.warnings.any((w) => w.contains('превышает разрешённую мощность')),
        isTrue,
      );
    });

    test('расчёт детерминирован: два прогона дают одинаковые линии', () {
      Project make() => project(rooms: [
            room('Кухня', RoomType.kitchen, [
              c('s1', ConsumerType.socket, qty: 12),
              c('l1', ConsumerType.lightPoint, qty: 8),
            ]),
            room('Зал', RoomType.livingRoom, [
              c('s2', ConsumerType.socket, qty: 9),
              c('l2', ConsumerType.chandelier, power: 0.3),
            ]),
          ]);
      String signature(CalculationResult r) => r.groups
          .map((g) => '${g.name}|${g.breakerAmps}|${g.cableSectionMm2}|'
              '${g.consumerIds.join(",")}')
          .join(';');
      expect(signature(calc.calculate(make())), signature(calc.calculate(make())));
    });
  });

  group('инварианты щита', () {
    test('ни одна линия не выходит за свой автомат и сечения', () {
      final r = calc.calculate(
        project(powerKw: 15, phase: PhaseSystem.three, rooms: [
          room('Кухня', RoomType.kitchen, [
            c('s1', ConsumerType.socket, qty: 12),
            c('p1', ConsumerType.electricStove, power: 7.0, powerful: true, rcd: true),
            c('p2', ConsumerType.oven, power: 3.5, powerful: true, rcd: true),
            c('l1', ConsumerType.lightPoint, qty: 6),
          ]),
          room('Санузел', RoomType.combinedBathroom, [
            c('s2', ConsumerType.socket, qty: 3),
          ]),
          room('Зал', RoomType.livingRoom, [
            c('s3', ConsumerType.socket, qty: 10),
            c('l2', ConsumerType.chandelier, power: 0.5),
          ]),
        ]),
        socketLines: 2,
        lightingLines: 2,
      );

      for (final g in r.groups) {
        expect(g.calculatedCurrentA, lessThanOrEqualTo(g.breakerAmps),
            reason: '${g.name}: ток больше автомата');
        expect(g.cableSectionMm2, greaterThan(0));
        expect(g.dinModules, greaterThan(0));
      }

      // Итоговый DIN = линии + УЗО + ввод.
      final groupsDin = r.groups.fold<int>(0, (s, g) => s + g.dinModules);
      final rcdDin = r.panel.protectionDevices
          .fold<int>(0, (s, d) => s + d.dinModules);
      expect(r.panel.totalDinModules,
          groupsDin + rcdDin + r.inputGroup!.dinModules);
    });

    test('спецификация и предупреждения не пустые', () {
      final r = calc.calculate(
        project(rooms: [
          room('Зал', RoomType.livingRoom, [
            c('s', ConsumerType.socket, qty: 6),
            c('l', ConsumerType.lightPoint, qty: 4),
          ]),
        ]),
      );
      expect(r.panel.materials, isNotEmpty);
      expect(
        r.panel.materials.any((m) => m.name.contains('Автомат')),
        isTrue,
      );
      expect(r.warnings.first, contains('черновик'));
      expect(
        r.warnings.any((w) => w.contains('противопожарное')),
        isFalse,
        reason: 'противопожарное УЗО рекомендует сама линия ввода, не общий список',
      );
      expect(r.inputGroup!.warnings.any((w) => w.contains('100 мА')), isTrue);
    });

    test('пустой проект не падает', () {
      final r = calc.calculate(project(rooms: const []));
      expect(r.groups, isEmpty);
      expect(r.panel.totalDinModules, greaterThan(0));
      expect(r.inputGroup, isNotNull);
    });
  });
}
