import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_canvas.dart';
import '../../plan/plan_geometry.dart';
import '../../plan/plan_models.dart';
import '../../plan/plan_seed.dart';

/// Редактор плана помещения: комнаты, точки, щит.
///
/// Три режима вместо одной перегруженной панели — на телефоне иначе не
/// попасть пальцем. Комнаты тянутся и меняют размер, точки ставятся пачкой
/// и удаляются долгим нажатием.
class PlanEditorScreen extends StatefulWidget {
  final ProjectDraft draft;
  final ValueChanged<FloorPlan> onChanged;

  const PlanEditorScreen({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late FloorPlan _plan;
  PlanTool _tool = PlanTool.rooms;
  String? _selectedRoomId;
  String? _selectedDeviceId;

  /// Грань комнаты, которую сейчас тянет палец (null — движем целиком).
  PlanEdge? _grabbedEdge;

  /// Сколько розеток ставить за один тап.
  int _batch = 1;

  PlanPointType _pointType = PlanPointType.socket;

  @override
  void initState() {
    super.initState();
    // План собираем из комнат проекта: рисовать квартиру с нуля не нужно.
    _plan = widget.draft.plan ?? PlanSeed.fromDraft(widget.draft);
  }

  int _counter = 0;
  String _nextId(String prefix) => '${prefix}_${++_counter}_${DateTime.now().microsecondsSinceEpoch % 1000}';

  PlanRoom? get _selectedRoom =>
      _plan.rooms.where((r) => r.id == _selectedRoomId).firstOrNull;

  void _update(FloorPlan next) {
    setState(() => _plan = next);
    widget.onChanged(next);
  }

  void _addRoom(Offset meters) {
    final left = PlanGeometry.snap(meters.dx).clamp(0.0, _plan.widthM - 3);
    final top = PlanGeometry.snap(meters.dy).clamp(0.0, _plan.heightM - 3);
    final rect = PlanRect(left: left, top: top, width: 3, height: 3);
    if (!PlanGeometry.fits(_plan, rect) ||
        PlanGeometry.overlaps(_plan, rect)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Здесь не помещается — сдвиньте или уменьшите')),
      );
      return;
    }
    final index = _plan.rooms.length + 1;
    final room = PlanRoom(
      id: _nextId('room'),
      name: 'Комната $index',
      type: core.RoomType.other,
      rect: rect,
    );
    _update(_plan.copyWith(rooms: [..._plan.rooms, room]));
    setState(() => _selectedRoomId = room.id);
  }

  void _addPoints(Offset meters) {
    final room = PlanGeometry.roomAt(_plan, meters.dx, meters.dy);
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала поставьте комнату: режим «Комнаты»')),
      );
      return;
    }
    final batch = PlanGeometry.placeBatch(
      plan: _plan,
      roomId: room.id,
      type: _pointType,
      x: meters.dx,
      y: meters.dy,
      count: _batch,
      idPrefix: _pointType.name,
      startIndex: _counter,
    );
    _counter += _batch;
    _update(_plan.copyWith(devices: [..._plan.devices, ...batch]));
  }

  /// Тянем комнату целиком или за конкретную грань.
  void _dragRoom(String id, Offset meters, PlanEdge? edge) {
    final room = _plan.rooms.firstWhere((r) => r.id == id);
    final rect = room.rect;
    PlanRect next;

    switch (edge) {
      case PlanEdge.left:
        final left = PlanGeometry.snap(meters.dx).clamp(
          0.0,
          rect.right - PlanGeometry.minRoomSize,
        );
        next = PlanRect(
          left: left,
          top: rect.top,
          width: rect.right - left,
          height: rect.height,
        );
      case PlanEdge.right:
        final right = PlanGeometry.snap(meters.dx)
            .clamp(rect.left + PlanGeometry.minRoomSize, _plan.widthM);
        next = rect.resizedTo(right, rect.bottom);
      case PlanEdge.top:
        final top = PlanGeometry.snap(meters.dy).clamp(
          0.0,
          rect.bottom - PlanGeometry.minRoomSize,
        );
        next = PlanRect(
          left: rect.left,
          top: top,
          width: rect.width,
          height: rect.bottom - top,
        );
      case PlanEdge.bottom:
        final bottom = PlanGeometry.snap(meters.dy)
            .clamp(rect.top + PlanGeometry.minRoomSize, _plan.heightM);
        next = PlanRect(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: bottom - rect.top,
        );
      case PlanEdge.corner:
        next = rect.resizedTo(
          PlanGeometry.snap(meters.dx)
              .clamp(rect.left + PlanGeometry.minRoomSize, _plan.widthM),
          PlanGeometry.snap(meters.dy)
              .clamp(rect.top + PlanGeometry.minRoomSize, _plan.heightM),
        );
      case null:
        // Тянем за середину — двигаем комнату целиком.
        final moved = rect.movedTo(
          PlanGeometry.snap(meters.dx - rect.width / 2),
          PlanGeometry.snap(meters.dy - rect.height / 2),
        );
        next = PlanRect(
          left: moved.left.clamp(0.0, _plan.widthM - moved.width),
          top: moved.top.clamp(0.0, _plan.heightM - moved.height),
          width: moved.width,
          height: moved.height,
        );
    }

    _update(_plan.copyWith(
      rooms: [
        for (final r in _plan.rooms) r.id == id ? r.copyWith(rect: next) : r,
      ],
    ));
  }

  /// Отпустили комнату над другой — меняем их местами (размеры остаются).
  void _swapIfOverlaps(String id) {
    final room = _plan.rooms.firstWhere((r) => r.id == id);
    final center = room.rect.center;
    final target = _plan.rooms.where(
      (r) => r.id != id && r.rect.contains(center.dx, center.dy),
    ).firstOrNull;
    if (target == null) return;

    // Меняем позиции: каждая комната встаёт на место другой.
    final a = room.rect;
    final b = target.rect;
    _update(_plan.copyWith(
      rooms: [
        for (final r in _plan.rooms)
          if (r.id == id)
            r.copyWith(rect: a.copyWith(left: b.left, top: b.top))
          else if (r.id == target.id)
            r.copyWith(rect: b.copyWith(left: a.left, top: a.top))
          else
            r,
      ],
    ));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${room.name} ↔ ${target.name}: поменяли местами'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _deleteSelected() {
    if (_selectedDeviceId != null) {
      _update(_plan.copyWith(
        devices: _plan.devices.where((d) => d.id != _selectedDeviceId).toList(),
      ));
      setState(() => _selectedDeviceId = null);
      return;
    }
    if (_selectedRoomId != null) {
      _update(_plan.copyWith(
        rooms: _plan.rooms.where((r) => r.id != _selectedRoomId).toList(),
        devices:
            _plan.devices.where((d) => d.roomId != _selectedRoomId).toList(),
      ));
      setState(() => _selectedRoomId = null);
    }
  }

  Future<void> _renameRoom(PlanRoom room) async {
    final controller = TextEditingController(text: room.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название комнаты'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    _update(_plan.copyWith(
      rooms: [
        for (final r in _plan.rooms) r.id == room.id ? r.copyWith(name: name) : r,
      ],
    ));
  }

  Future<void> _pickType(PlanRoom room) async {
    final type = await showModalBottomSheet<core.RoomType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in core.RoomType.values)
              ListTile(
                title: Text(_roomTypeLabel(t)),
                trailing: t == room.type ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;
    _update(_plan.copyWith(
      rooms: [
        for (final r in _plan.rooms)
          r.id == room.id ? r.copyWith(type: type) : r,
      ],
    ));
  }

  String _roomTypeLabel(core.RoomType t) => switch (t) {
        core.RoomType.kitchen => 'Кухня',
        core.RoomType.livingRoom => 'Гостиная / зал',
        core.RoomType.bedroom => 'Спальня',
        core.RoomType.childrenRoom => 'Детская',
        core.RoomType.bathroom => 'Ванная',
        core.RoomType.combinedBathroom => 'Санузел',
        core.RoomType.toilet => 'Туалет',
        core.RoomType.hallway => 'Коридор',
        core.RoomType.technical => 'Техпомещение',
        core.RoomType.balcony => 'Балкон',
        core.RoomType.entrance => 'Прихожая',
        core.RoomType.pantry => 'Кладовая',
        core.RoomType.other => 'Другое',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rooms = _plan.rooms;
    final devices = _plan.devices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('План помещения'),
        actions: [
          IconButton(
            tooltip: 'Удалить выбранное',
            onPressed:
                (_selectedRoomId == null && _selectedDeviceId == null)
                    ? null
                    : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _ToolSwitch<PlanTool>(
              values: const [PlanTool.rooms, PlanTool.points, PlanTool.panel],
              labels: const {'Комнаты', 'Точки', 'Щит'},
              selected: _tool,
              onChanged: (v) => setState(() => _tool = v),
            ),
          ),
          if (_tool == PlanTool.points)
            _pointsBar(scheme)
          else if (_tool == PlanTool.rooms && _selectedRoom != null)
            _roomBar(scheme, _selectedRoom!),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: PlanCanvas(
                plan: _plan,
                tool: _tool,
                selectedRoomId: _selectedRoomId,
                selectedDeviceId: _selectedDeviceId,
                onTap: (m) {
                  if (_tool == PlanTool.rooms) {
                    _addRoom(m);
                  } else if (_tool == PlanTool.points) {
                    _addPoints(m);
                  } else {
                    _update(_plan.copyWith(
                      panel: PlanPanel(
                        x: PlanGeometry.snap(m.dx),
                        y: PlanGeometry.snap(m.dy),
                      ),
                    ));
                  }
                },
                onRoomGrab: (id, edge) => _grabbedEdge = edge,
                onRoomDragTo: (id, meters) {
                  _dragRoom(id, meters, _grabbedEdge);
                },
                onRoomDrop: (id) {
                  _swapIfOverlaps(id);
                  _grabbedEdge = null;
                },
                onDeviceGrab: (id) => setState(() => _selectedDeviceId = id),
                onDeviceDragTo: (id, meters) {
                  _update(_plan.copyWith(
                    devices: [
                      for (final d in _plan.devices)
                        d.id == id
                            ? d.movedTo(
                                PlanGeometry.snap(meters.dx),
                                PlanGeometry.snap(meters.dy),
                              )
                            : d,
                    ],
                  ));
                },
                onPanelDragTo: (meters) {
                  _update(_plan.copyWith(
                    panel: PlanPanel(
                      x: PlanGeometry.snap(meters.dx),
                      y: PlanGeometry.snap(meters.dy),
                    ),
                  ));
                },
                onSelectRoom: (id) => setState(() {
                  _selectedRoomId = id;
                  _selectedDeviceId = null;
                }),
                onSelectDevice: (id) => setState(() {
                  _selectedDeviceId = id;
                  _selectedRoomId = null;
                }),
              ),
            ),
          ),
          _statusBar(scheme, rooms.length, devices.length),
        ],
      ),
    );
  }

  Widget _pointsBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _ToolSwitch<PlanPointType>(
              values: const [
                PlanPointType.socket,
                PlanPointType.light,
                PlanPointType.powerful,
              ],
              labels: const {'Розетка', 'Свет', 'Мощный'},
              selected: _pointType,
              onChanged: (v) => setState(() => _pointType = v),
            ),
          ),
          const SizedBox(width: 8),
          // сколько ставить за один тап
          PopupMenuButton<int>(
            tooltip: 'Сколько ставить за раз',
            initialValue: _batch,
            onSelected: (v) => setState(() => _batch = v),
            itemBuilder: (context) => [
              for (final n in [1, 2, 3, 4, 6])
                PopupMenuItem(value: n, child: Text('По $n')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('×$_batch'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomBar(ColorScheme scheme, PlanRoom room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              room.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => _renameRoom(room),
            child: const Text('Имя'),
          ),
          TextButton(
            onPressed: () => _pickType(room),
            child: const Text('Тип'),
          ),
        ],
      ),
    );
  }

  Widget _statusBar(ColorScheme scheme, int rooms, int devices) {
    final lengths = <String>[];
    for (final room in _plan.rooms) {
      final len = PlanGeometry.roomLength(_plan, room.id);
      if (len > 0) lengths.add('${room.name}: ${len.toStringAsFixed(1)} м');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: scheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Комнат: $rooms · точек: $devices',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (lengths.isNotEmpty)
            Text(
              lengths.take(3).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}


/// Компактный переключатель из равных сегментов.
///
/// SegmentedButton на 360 dp переносил подпись «Комнаты» на две строки —
/// здесь текст всегда в одну строку с многоточием.
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
