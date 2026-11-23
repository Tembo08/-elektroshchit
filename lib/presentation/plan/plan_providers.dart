import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_auto.dart';
import '../../plan/plan_canvas.dart';
import '../../plan/plan_layout.dart';
import '../../plan/plan_models.dart';

/// Чем генерировать план.
enum PlanGenerator {
  /// `PlanAuto`: сетка комнат и точки по расчёту — быстрый эскиз.
  auto,

  /// `PlanLayout`: архитектурная геометрия со стенами, коридором и проёмами,
  /// точки расставляются поверх.
  layout,
}

/// Состояние экрана плана: что выбрано, каким инструментом работаем,
/// какие слои показывать.
///
/// Сам план живёт в `ProjectDraft.plan` — так он сохраняется вместе с
/// проектом и не расходится с расчётом.
class PlanEditorState {
  final PlanTool tool;

  /// Какой прибор ставим тапом в режиме «Точки».
  final PlanPointType pointType;

  /// Каким генератором собирать план.
  final PlanGenerator generator;
  final String? selectedRoomId;
  final String? selectedDeviceId;
  final bool showGrid;
  final bool showTraces;
  final bool showElectrical;
  final bool dirty;

  const PlanEditorState({
    this.tool = PlanTool.rooms,
    this.pointType = PlanPointType.socket,
    this.generator = PlanGenerator.auto,
    this.selectedRoomId,
    this.selectedDeviceId,
    this.showGrid = true,
    this.showTraces = false,
    this.showElectrical = true,
    this.dirty = false,
  });

  PlanEditorState copyWith({
    PlanTool? tool,
    PlanPointType? pointType,
    PlanGenerator? generator,
    String? selectedRoomId,
    String? selectedDeviceId,
    bool? showGrid,
    bool? showTraces,
    bool? showElectrical,
    bool? dirty,
    bool clearRoom = false,
    bool clearDevice = false,
  }) {
    return PlanEditorState(
      tool: tool ?? this.tool,
      pointType: pointType ?? this.pointType,
      generator: generator ?? this.generator,
      selectedRoomId: clearRoom ? null : (selectedRoomId ?? this.selectedRoomId),
      selectedDeviceId:
          clearDevice ? null : (selectedDeviceId ?? this.selectedDeviceId),
      showGrid: showGrid ?? this.showGrid,
      showTraces: showTraces ?? this.showTraces,
      showElectrical: showElectrical ?? this.showElectrical,
      dirty: dirty ?? this.dirty,
    );
  }
}

final planEditorProvider =
    NotifierProvider<PlanEditorNotifier, PlanEditorState>(PlanEditorNotifier.new);

class PlanEditorNotifier extends Notifier<PlanEditorState> {
  @override
  PlanEditorState build() => const PlanEditorState();

  void setTool(PlanTool tool) => state = state.copyWith(tool: tool);

  void setPointType(PlanPointType type) =>
      state = state.copyWith(pointType: type);

  void setGenerator(PlanGenerator generator) =>
      state = state.copyWith(generator: generator);

  void selectRoom(String? id) => state = id == null
      ? state.copyWith(clearRoom: true, clearDevice: true)
      : state.copyWith(selectedRoomId: id, clearDevice: true);

  void selectDevice(String? id) => state = id == null
      ? state.copyWith(clearDevice: true, clearRoom: true)
      : state.copyWith(selectedDeviceId: id, clearRoom: true);

  void toggleGrid() => state = state.copyWith(showGrid: !state.showGrid);
  void toggleTraces() => state = state.copyWith(showTraces: !state.showTraces);
  void toggleElectrical() =>
      state = state.copyWith(showElectrical: !state.showElectrical);

  void markDirty([bool value = true]) => state = state.copyWith(dirty: value);

  void reset() => state = const PlanEditorState();
}

/// Номера групп по комнатам — нужны для подписей на плане.
///
/// Считаются из результата расчёта один раз: id потребителей имеют вид
/// «roomId#cN», поэтому группу легко привязать к комнате.
final planGroupLabelsProvider =
    Provider.family<Map<String, String>, core.CalculationResult>((ref, result) {
  final labels = <String, String>{};
  for (final group in result.groups) {
    for (final consumerId in group.consumerIds) {
      final cut = consumerId.indexOf('#');
      if (cut <= 0) continue;
      final roomId = consumerId.substring(0, cut);
      final number = group.name.replaceAll(RegExp(r'[^0-9]'), '');
      if (number.isEmpty) continue;
      final existing = labels[roomId];
      labels[roomId] =
          existing == null ? number : '$existing, $number';
    }
  }
  return labels;
});

/// Сгенерировать план из черновика и результата расчёта.
///
/// Используется при первом открытии экрана и по кнопке «Пересоздать».
/// `generator` выбирает движок: эскиз (`PlanAuto`) или архитектурную
/// геометрию (`PlanLayout` + расстановка точек поверх).
({FloorPlan plan, Map<String, String> groupLabels}) buildPlan({
  required ProjectDraft draft,
  required core.CalculationResult result,
  PlanGenerator generator = PlanGenerator.auto,
}) {
  if (generator == PlanGenerator.layout) {
    final layout = PlanLayout.build(draft);
    return PlanLayoutDevices.fill(
      draft: draft,
      result: result,
      layout: layout,
    );
  }
  return PlanAuto.build(draft: draft, result: result);
}
