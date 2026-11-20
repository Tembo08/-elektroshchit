import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:xml/xml.dart';

import 'plan_models.dart';
import 'plan_walls.dart';

/// Импорт плана из CorelDRAW / Inkscape.
///
/// Договор простой: что нарисовано — то и план. Тип элемента берётся из
/// имени слоя (`<g inkscape:label="walls">` или `id="walls"`):
///
/// | слой       | что это                    | что получаем            |
/// |------------|----------------------------|-------------------------|
/// | walls      | линии стен                 | стены с толщиной        |
/// | doors      | проёмы дверей (отрезки)    | двери                   |
/// | windows    | окна (отрезки)             | окна                    |
/// | socket     | розетки (любая фигура)     | точки-розетки по центру |
/// | light      | светильники                | точки-свет              |
/// | switch     | выключатели                | точки-выключатели       |
/// | powerful   | мощные приборы             | отдельные линии         |
/// | panel      | щит                         | место щита              |
///
/// Масштаб: если у `<svg>` размер задан в миллиметрах (`width="8000mm"`),
/// то 1 единица = 1 мм, и метры считаются сами. Иначе размер считается
/// в пикселях и пользователь задаёт масштаб вручную (scaleMmPerUnit).
class SvgPlanImport {
  /// Толщина стен по умолчанию, если в SVG не задана.
  static const wallThickness = 0.16;

  /// Разбирает SVG и собирает план.
  static SvgImportResult parse(
    String svg, {
    /// Сколько миллиметров в одной единице SVG. 0 — взять из документа.
    double scaleMmPerUnit = 0,
  }) {
    final warnings = <String>[];
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(svg);
    } on XmlException catch (e) {
      return SvgImportResult(
        plan: const FloorPlan(widthM: 0, heightM: 0),
        warnings: ['Не удалось прочитать SVG: ${e.message}'],
        layers: const {},
      );
    }

    final root = doc.rootElement;
    var mmPerUnit = scaleMmPerUnit;
    if (mmPerUnit <= 0) {
      mmPerUnit = _readUnitScale(root, warnings);
    }
    // мм → м
    final meterPerUnit = mmPerUnit / 1000.0;

    final walls = <PlanWall>[];
    final doors = <PlanOpening>[];
    final windows = <PlanOpening>[];
    final devices = <PlanDevice>[];
    final layerCounts = <String, int>{};
    var panel = const PlanPanel(x: 0, y: 0);

    void consume(String layer, XmlElement element) {
      final segments = _segments(element, warnings);
      final boxes = _boxes(element);
      layerCounts[layer] = (layerCounts[layer] ?? 0) + 1;

      switch (layer) {
        case 'walls':
          for (final seg in segments) {
            walls.add(PlanWall(
              Offset(seg.$1.dx * meterPerUnit, seg.$1.dy * meterPerUnit),
              Offset(seg.$2.dx * meterPerUnit, seg.$2.dy * meterPerUnit),
              thickness: wallThickness,
            ));
          }
        case 'doors':
          for (final seg in segments) {
            doors.add(_openingFrom(
              seg,
              meterPerUnit,
              PlanOpeningType.door,
            ));
          }
        case 'windows':
          for (final seg in segments) {
            windows.add(_openingFrom(
              seg,
              meterPerUnit,
              PlanOpeningType.window,
            ));
          }
        case 'socket':
        case 'light':
        case 'switch':
        case 'powerful':
          final box = boxes;
          if (box == null) {
            warnings.add('На слое $layer элемент без координат — пропущен');
            return;
          }
          final center = box.center;
          devices.add(PlanDevice(
            id: '$layer${devices.length}',
            roomId: 'svg',
            type: _typeOf(layer),
            x: center.dx * meterPerUnit,
            y: center.dy * meterPerUnit,
          ));
        case 'panel':
          final box = boxes;
          if (box == null) return;
          panel = PlanPanel(
            x: box.center.dx * meterPerUnit,
            y: box.center.dy * meterPerUnit,
          );
      }
    }

    void walk(XmlElement element, String layer) {
      final name = _layerName(element);
      final current = name ?? layer;
      if (name != null && _isLayer(name)) {
        // новый слой — сама группа ничего не рисует
      } else if (layer.isNotEmpty) {
        consume(layer, element);
      }
      for (final child in element.childElements) {
        final childName = _layerName(child);
        if (childName != null && _isLayer(childName)) {
          walk(child, _normalizeLayer(childName));
        } else if (current.isNotEmpty) {
          walk(child, current);
        }
      }
    }

    // Обходим только группы-слои и то, что внутри них.
    for (final child in root.childElements) {
      final name = _layerName(child);
      final layer = name == null ? '' : _normalizeLayer(name);
      if (layer.isNotEmpty && _isLayer(layer)) {
        walk(child, layer);
      }
    }

    if (walls.isEmpty) {
      warnings.add('Слой walls пуст: стены не найдены. Проверьте имя слоя.');
    }

    final maxX = [
      ...walls.map((w) => math.max(w.a.dx, w.b.dx)),
      ...devices.map((d) => d.x),
    ].fold<double>(0, math.max);
    final maxY = [
      ...walls.map((w) => math.max(w.a.dy, w.b.dy)),
      ...devices.map((d) => d.y),
    ].fold<double>(0, math.max);

    final plan = FloorPlan(
      widthM: maxX,
      heightM: maxY,
      rooms: const [],
      devices: devices,
      walls: walls,
      openings: [...doors, ...windows],
      panel: panel,
    );

    return SvgImportResult(
      plan: plan,
      warnings: warnings,
      layers: layerCounts,
    );
  }

  // ── вспомогательное ──────────────────────────────────────────────

  static const _knownLayers = {
    'walls',
    'doors',
    'windows',
    'socket',
    'light',
    'switch',
    'powerful',
    'panel',
  };

  static bool _isLayer(String name) => _knownLayers.contains(_normalizeLayer(name));

  static String _normalizeLayer(String name) {
    final lower = name.toLowerCase();
    for (final layer in _knownLayers) {
      if (lower.contains(layer)) return layer;
    }
    return lower;
  }

  static String? _layerName(XmlElement element) {
    for (final attr in element.attributes) {
      if (attr.name.local == 'label' || attr.name.local == 'id') {
        final value = attr.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static PlanPointType _typeOf(String layer) => switch (layer) {
        'socket' => PlanPointType.socket,
        'light' => PlanPointType.light,
        'switch' => PlanPointType.switchPoint,
        _ => PlanPointType.powerful,
      };

  /// Размер в мм на единицу SVG: из width/height или из viewBox.
  static double _readUnitScale(XmlElement root, List<String> warnings) {
    final width = root.getAttribute('width');
    final viewBox = root.getAttribute('viewBox');

    double? mmFrom(String? value) {
      if (value == null) return null;
      final match = RegExp(r'^\s*([\d.]+)\s*(mm|cm|m|in|px|pt)?\s*$')
          .firstMatch(value);
      if (match == null) return null;
      final number = double.tryParse(match.group(1)!);
      if (number == null || number <= 0) return null;
      return number;
    }

    if (width != null && width.contains(RegExp(r'(mm|cm|m|in)$'))) {
      final value = mmFrom(width);
      if (value != null) {
        final unit = width.replaceAll(RegExp(r'[\d.\s]'), '');
        return switch (unit) {
          'mm' => 1.0,
          'cm' => 10.0,
          'm' => 1000.0,
          'in' => 25.4,
          _ => 1.0,
        };
      }
    }

    // Нет единиц: считаем, что единица = 1 мм (типично для Corel в мм).
    if (viewBox != null) {
      final parts = viewBox
          .split(RegExp(r'[\s,]+'))
          .where((p) => p.isNotEmpty)
          .map(double.tryParse)
          .toList();
      if (parts.length == 4 && parts[2]! > 0) {
        warnings.add(
          'У документа нет размера в мм — считаю 1 единицу SVG = 1 мм '
          '(проверьте масштаб на превью).',
        );
        return 1.0;
      }
    }

    final w = mmFrom(width);
    if (w != null && viewBox != null) {
      final parts = viewBox.split(RegExp(r'[\s,]+'));
      final vbWidth = double.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
      if (vbWidth > 0) return w / vbWidth;
    }

    warnings.add('Не удалось определить масштаб документа — 1 единица = 1 мм.');
    return 1.0;
  }

  static PlanOpening _openingFrom(
    (Offset, Offset) segment,
    double meterPerUnit,
    PlanOpeningType type,
  ) {
    return PlanOpening(
      a: Offset(segment.$1.dx * meterPerUnit, segment.$1.dy * meterPerUnit),
      b: Offset(segment.$2.dx * meterPerUnit, segment.$2.dy * meterPerUnit),
      type: type,
    );
  }

  /// Отрезки прямых линий из элемента.
  static List<(Offset, Offset)> _segments(
    XmlElement element,
    List<String> warnings,
  ) {
    final result = <(Offset, Offset)>[];
    switch (element.name.local) {
      case 'line':
        final x1 = _num(element, 'x1');
        final y1 = _num(element, 'y1');
        final x2 = _num(element, 'x2');
        final y2 = _num(element, 'y2');
        result.add((Offset(x1, y1), Offset(x2, y2)));
      case 'rect':
        final x = _num(element, 'x');
        final y = _num(element, 'y');
        final w = _num(element, 'width');
        final h = _num(element, 'height');
        result.addAll([
          (Offset(x, y), Offset(x + w, y)),
          (Offset(x + w, y), Offset(x + w, y + h)),
          (Offset(x + w, y + h), Offset(x, y + h)),
          (Offset(x, y + h), Offset(x, y)),
        ]);
      case 'polyline' || 'polygon':
        final points = _points(element.getAttribute('points'));
        for (var i = 0; i + 1 < points.length; i++) {
          result.add((points[i], points[i + 1]));
        }
        if (element.name.local == 'polygon' && points.length > 2) {
          result.add((points.last, points.first));
        }
      case 'path':
        final d = element.getAttribute('d');
        if (d == null) break;
        _pathSegments(d, result, warnings);
      case 'circle' || 'ellipse':
        // центры фигур нужны для символов, отрезков у них нет
        break;
    }
    return result;
  }

  /// Прямые участки пути: M/L/H/V/Z. Кривые игнорируем с предупреждением.
  static void _pathSegments(
    String d,
    List<(Offset, Offset)> out,
    List<String> warnings,
  ) {
    final hasCurve = RegExp('[CcSsQqTtAa]').hasMatch(d);
    if (hasCurve) {
      warnings.add('В путях есть кривые — они пропущены (оставлены прямые).');
    }

    final tokens = RegExp(
      r'([MLHVZmlhvz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)',
    ).allMatches(d).map((m) => m.group(0)!).toList();

    var current = Offset.zero;
    var start = Offset.zero;
    String? command;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (RegExp(r'^[A-Za-z]$').hasMatch(token)) {
        command = token;
        if (token.toUpperCase() == 'Z') {
          if (current != start) out.add((current, start));
          current = start;
        }
        continue;
      }

      double next() => double.parse(tokens[i++]);

      switch (command) {
        case 'M':
        case 'm':
          final x = next();
          final y = next();
          current = command == 'm' ? current + Offset(x, y) : Offset(x, y);
          start = current;
        case 'L':
        case 'l':
          final x = next();
          final y = next();
          final to = command == 'l' ? current + Offset(x, y) : Offset(x, y);
          out.add((current, to));
          current = to;
        case 'H':
        case 'h':
          final x = next();
          final to = command == 'h' ? current + Offset(x, 0) : Offset(x, current.dy);
          out.add((current, to));
          current = to;
        case 'V':
        case 'v':
          final y = next();
          final to = command == 'v' ? current + Offset(0, y) : Offset(current.dx, y);
          out.add((current, to));
          current = to;
      }
    }
  }

  static Rect? _boxes(XmlElement element) {
    final name = element.name.local;
    switch (name) {
      case 'rect':
        final x = _num(element, 'x');
        final y = _num(element, 'y');
        final w = _num(element, 'width');
        final h = _num(element, 'height');
        return Rect.fromLTWH(x, y, w, h);
      case 'circle':
        final cx = _num(element, 'cx');
        final cy = _num(element, 'cy');
        final r = _num(element, 'r');
        return Rect.fromCircle(center: Offset(cx, cy), radius: r);
      case 'ellipse':
        final cx = _num(element, 'cx');
        final cy = _num(element, 'cy');
        final rx = _num(element, 'rx');
        final ry = _num(element, 'ry');
        return Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 2,
          height: ry * 2,
        );
      case 'line':
        final x1 = _num(element, 'x1');
        final y1 = _num(element, 'y1');
        final x2 = _num(element, 'x2');
        final y2 = _num(element, 'y2');
        return Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
      case 'path':
        final d = element.getAttribute('d');
        if (d == null) return null;
        final segs = <(Offset, Offset)>[];
        _pathSegments(d, segs, []);
        if (segs.isEmpty) return null;
        var left = double.infinity, top = double.infinity;
        var right = -double.infinity, bottom = -double.infinity;
        for (final s in segs) {
          for (final p in [s.$1, s.$2]) {
            left = math.min(left, p.dx);
            top = math.min(top, p.dy);
            right = math.max(right, p.dx);
            bottom = math.max(bottom, p.dy);
          }
        }
        return Rect.fromLTRB(left, top, right, bottom);
      case 'polyline' || 'polygon' || 'g':
        Rect? box;
        for (final child in element.childElements) {
          final childBox = _boxes(child);
          if (childBox == null) continue;
          box = box == null ? childBox : box.expandToInclude(childBox);
        }
        return box;
    }
    return null;
  }

  static double _num(XmlElement element, String name) =>
      double.tryParse((element.getAttribute(name) ?? '0').trim()) ?? 0;

  static List<Offset> _points(String? raw) {
    if (raw == null) return const [];
    final numbers = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?')
        .allMatches(raw)
        .map((m) => double.parse(m.group(0)!))
        .toList();
    final result = <Offset>[];
    for (var i = 0; i + 1 < numbers.length; i += 2) {
      result.add(Offset(numbers[i], numbers[i + 1]));
    }
    return result;
  }
}

/// Что получилось при импорте.
class SvgImportResult {
  final FloorPlan plan;
  final List<String> warnings;

  /// Сколько элементов было на каждом слое.
  final Map<String, int> layers;

  const SvgImportResult({
    required this.plan,
    required this.warnings,
    required this.layers,
  });

  int get wallsCount => plan.walls.length;
  int get doorsCount =>
      plan.openings.where((o) => o.type == PlanOpeningType.door).length;
  int get windowsCount =>
      plan.openings.where((o) => o.type == PlanOpeningType.window).length;
  int get sockets =>
      plan.devices.where((d) => d.type == PlanPointType.socket).length;
  int get lights =>
      plan.devices.where((d) => d.type == PlanPointType.light).length;
  int get switches =>
      plan.devices.where((d) => d.type == PlanPointType.switchPoint).length;
  bool get isEmpty => plan.walls.isEmpty && plan.devices.isEmpty;
}

/// Совместимость имён со старым кодом (типы комнат не используются).
typedef SvgRoomType = core.RoomType;
