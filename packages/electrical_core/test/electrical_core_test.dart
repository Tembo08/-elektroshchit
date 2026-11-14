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

    test('25 кВт на трёх фазах — 5-жильный кабель и сечение под ток', () {
      final r = calc.calculate(
        project(powerKw: 25, phase: PhaseSystem.three, rooms: [
          room('Зал', RoomType.livingRoom, [c('s', ConsumerType.socket, qty: 6)]),
        ]),
      );
      final input = r.inputGroup!;
      expect(input.cableType, contains('5×'));
      expect(input.breakerAmps, greaterThanOrEqualTo(37));
      expect(input.cableSectionMm2, greaterThanOrEqualTo(10));
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
      expect(g.calculatedCurrentA, closeTo(17.6, 0.2));
      expect(g.breakerAmps, 20);
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
