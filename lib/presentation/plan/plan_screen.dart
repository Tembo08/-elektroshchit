import 'dart:math' as math;

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_canvas.dart';
import '../../plan/plan_geometry.dart';
import '../../plan/plan_models.dart';
import 'plan_providers.dart';

/// Экран плана помещения: просмотр и базовое редактирование.
///
/// План генерируется автоматически из черновика и результата расчёта,
/// правится пальцем (комнаты, точки, щит) и сохраняется в проект.
class PlanScreen extends ConsumerStatefulWidget {
  final core.CalculationResult result;
  final String projectName;

  const PlanScreen({
    super.key,
    required this.result,
    required this.projectName,
  });

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  late final Map<String, String> _groupLabels;

  @override
  void initState() {
    super.initState();
    _groupLabels = ref.read(planGroupLabelsProvider(widget.result));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePlan());
  }

  /// Если плана ещё нет — строим автоматически (или по кнопке «Пересоздать»).
  void _ensurePlan({bool force = false}) {
    final draft = ref.read(projectDraftProvider);
    if (!force && draft.plan != null) return;

    final built = buildPlan(draft: draft, result: widget.result);
    ref.read(projectDraftProvider.notifier).setPlan(built.plan);
  }

  void _savePlan(FloorPlan plan) {
    ref.read(projectDraftProvider.notifier).setPlan(plan);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final draft = ref.watch(projectDraftProvider);
    final editor = ref.watch(planEditorProvider);
    final plan = draft.plan;

    return Scaffold(
      appBar: AppBar(
        title: const Text('План помещения'),
        actions: [
          IconButton(
            tooltip: 'Пересоздать план',
            icon: const Icon(Icons.refresh),
            onPressed: () => _confirmRegenerate(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'grid':
                  ref.read(planEditorProvider.notifier).toggleGrid();
                case 'traces':
                  ref.read(planEditorProvider.notifier).toggleTraces();
                case 'reset':
                  _confirmReset(context);
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'grid',
                checked: editor.showGrid,
                child: const Text('Сетка'),
              ),
              CheckedPopupMenuItem(
                value: 'traces',
                checked: editor.showTraces,
                child: const Text('Трассы'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset',
                child: Text('Сбросить план'),
              ),
            ],
          ),
        ],
      ),
      body: plan == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _canvas(context, plan, editor),
                ),
                _toolbar(scheme, editor, plan),
              ],
            ),
    );
  }

  // ── холст ────────────────────────────────────────────────────────

  Widget _canvas(BuildContext context, FloorPlan plan, PlanEditorState editor) {
    // Соотношение сторон листа, чтобы план не растягивался.
    final width = plan.widthM > 0 ? plan.widthM : 1.0;
    final height = plan.heightM > 0 ? plan.heightM : 1.0;

    return Container(
      color: const Color(0xFFF3F4F6),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: AspectRatio(
          aspectRatio: width / height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InteractiveViewer(
              maxScale: 5,
              minScale: 1,
              child: PlanCanvas(
                plan: plan,
                tool: editor.tool,
                selectedRoomId: editor.selectedRoomId,
                selectedDeviceId: editor.selectedDeviceId,
                groupLabels: _groupLabels,
                panelNote: widget.result.inputGroup == null
                    ? null
                    : 'ввод ${widget.result.inputGroup!.breakerAmps} А',
                showGrid: editor.showGrid,
                showElectrical: editor.showElectrical,
                onTap: (meters) => _onTap(meters, plan, editor),
                onRoomGrab: (roomId, edge) {
                  ref.read(planEditorProvider.notifier).selectRoom(roomId);
                },
                onRoomDragTo: (roomId, point) {
                  final room = plan.rooms.firstWhere((r) => r.id == roomId);
                  final dx = point.dx - (room.rect.left + room.rect.width / 2);
                  final dy = point.dy - (room.rect.top + room.rect.height / 2);
                  final moved = plan.copyWith(
                    rooms: [
                      for (final r in plan.rooms)
                        if (r.id == roomId)
                          r.copyWith(
                            rect: PlanRect(
                              left: PlanGeometry.snap(r.rect.left + dx),
                              top: PlanGeometry.snap(r.rect.top + dy),
                              width: r.rect.width,
                              height: r.rect.height,
                            ),
                          )
                        else
                          r,
                    ],
                  );
                  _savePlan(moved);
                },
                onRoomDrop: (_) {},
                onDeviceGrab: (deviceId) {
                  ref.read(planEditorProvider.notifier).selectDevice(deviceId);
                },
                onDeviceDragTo: (deviceId, point) {
                  final moved = plan.copyWith(
                    devices: [
                      for (final d in plan.devices)
                        if (d.id == deviceId)
                          d.movedTo(
                            PlanGeometry.snap(point.dx),
                            PlanGeometry.snap(point.dy),
                          )
                        else
                          d,
                    ],
                  );
                  _savePlan(moved);
                },
                onPanelDragTo: (point) {
                  _savePlan(plan.copyWith(
                    panel: PlanPanel(
                      x: PlanGeometry.snap(point.dx),
                      y: PlanGeometry.snap(point.dy),
                    ),
                  ));
                },
                onSelectRoom: (roomId) =>
                    ref.read(planEditorProvider.notifier).selectRoom(roomId),
                onSelectDevice: (deviceId) =>
                    ref.read(planEditorProvider.notifier).selectDevice(deviceId),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Тап по листу в режиме точек добавляет устройство в комнату под пальцем.
  void _onTap(Offset meters, FloorPlan plan, PlanEditorState editor) {
    if (editor.tool != PlanTool.points) return;

    final room = PlanGeometry.roomAt(plan, meters.dx, meters.dy);
    if (room == null) return;

    final device = PlanDevice(
      id: 'd${DateTime.now().microsecondsSinceEpoch}',
      roomId: room.id,
      type: PlanPointType.socket,
      x: PlanGeometry.snap(meters.dx),
      y: PlanGeometry.snap(meters.dy),
    );
    _savePlan(plan.copyWith(devices: [...plan.devices, device]));
    ref.read(planEditorProvider.notifier).selectDevice(device.id);
  }

  // ── панель инструментов ──────────────────────────────────────────

  Widget _toolbar(ColorScheme scheme, PlanEditorState editor, FloorPlan plan) {
    final selectedDevice = editor.selectedDeviceId == null
        ? null
        : plan.devices.where((d) => d.id == editor.selectedDeviceId).firstOrNull;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ToolSwitch<PlanTool>(
                      values: const [
                        PlanTool.rooms,
                        PlanTool.points,
                        PlanTool.panel,
                      ],
                      labels: const {'Комнаты', 'Точки', 'Щит'},
                      selected: editor.tool,
                      onChanged: (value) => ref
                          .read(planEditorProvider.notifier)
                          .setTool(value),
                    ),
                  ),
                ],
              ),
              if (selectedDevice != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Выбрано: ${_deviceLabel(selectedDevice.type)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteDevice(plan, selectedDevice.id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Удалить'),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _hint(editor),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _hint(PlanEditorState editor) => switch (editor.tool) {
        PlanTool.rooms => 'Тяните комнату пальцем, чтобы переместить',
        PlanTool.points => 'Тап по комнате добавит розетку',
        PlanTool.panel => 'Тяните щит, чтобы переставить',
      };

  String _deviceLabel(PlanPointType type) => switch (type) {
        PlanPointType.socket => 'розетка',
        PlanPointType.light => 'светильник',
        PlanPointType.switchPoint => 'выключатель',
        PlanPointType.powerful => 'мощный прибор',
      };

  void _deleteDevice(FloorPlan plan, String id) {
    _savePlan(plan.copyWith(
      devices: [
        for (final d in plan.devices)
          if (d.id != id) d,
      ],
    ));
    ref.read(planEditorProvider.notifier).selectDevice(null);
  }

  // ── действия меню ────────────────────────────────────────────────

  Future<void> _confirmRegenerate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Пересоздать план?'),
        content: const Text(
          'Текущее расположение комнат и точек будет потеряно — план '
          'соберётся заново из данных расчёта.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Пересоздать'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _ensurePlan(force: true);
      ref.read(planEditorProvider.notifier).reset();
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить план?'),
        content: const Text(
          'План будет удалён из проекта. При следующем открытии он '
          'соберётся заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(projectDraftProvider.notifier).setPlan(null);
      ref.read(planEditorProvider.notifier).reset();
      _ensurePlan(force: true);
    }
  }
}

/// Полезно для отладки раскладки: сколько метров занимает лист.
String describePlan(FloorPlan plan) =>
    '${plan.widthM.toStringAsFixed(1)}×${plan.heightM.toStringAsFixed(1)} м, '
    'комнат ${plan.rooms.length}, точек ${plan.devices.length}';

/// Не используется в UI, но помогает в тестах: проверка попадания в лист.
bool planFitsSheet(FloorPlan plan) =>
    plan.rooms.every((r) => r.rect.right <= plan.widthM + 0.01) &&
    plan.rooms.every((r) => r.rect.bottom <= plan.heightM + 0.01) &&
    math.max(plan.widthM, plan.heightM) > 0;

/// Компактный переключатель режимов.
///
/// `SegmentedButton` на узких экранах переносит «Комнаты» на две строки,
/// поэтому рисуем свой: одинаковая высота, текст в одну строку.
class _ToolSwitch<T> extends StatelessWidget {
  final List<T> values;
  final Set<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  const _ToolSwitch({
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = labels.toList();
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(values[i]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? scheme.primary.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    items[i],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: values[i] == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: values[i] == selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
