import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'room_consumers_screen.dart';
import 'create_project_screen.dart';
import '../result/result_screen.dart';

class RoomsScreen extends StatefulWidget {
  final NewProjectData projectData;
  final core.NormsCatalog norms;

  const RoomsScreen({
    super.key,
    required this.projectData,
    required this.norms,
  });

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final List<core.Room> _rooms = [];
  int _idCounter = 1;

  void _addRoom() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddRoomDialog(
        onAdd: (name, type, area, consumers) {
          setState(() {
            _rooms.add(
              core.Room(
                id: 'r_${_idCounter++}',
                name: name,
                type: type,
                area: area,
                consumers: consumers,
              ),
            );
          });
        },
      ),
    );
  }

  void _removeRoom(int index) {
    setState(() => _rooms.removeAt(index));
  }

  void _calculate() {
    final now = DateTime.now();
    final project = core.Project(
      id: 'p_${now.millisecondsSinceEpoch}',
      name: widget.projectData.name,
      objectType: widget.projectData.objectType,
      phaseSystem: widget.projectData.phaseSystem,
      allowedPowerKw: widget.projectData.allowedPowerKw,
      groundingSystem: widget.projectData.groundingSystem,
      totalArea: widget.projectData.totalArea,
      ceilingHeight: widget.projectData.ceilingHeight,
      createdAt: now,
      updatedAt: now,
      rooms: List.unmodifiable(_rooms),
    );

    final result = core.CircuitCalculator(widget.norms).calculate(project);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result, projectName: project.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.projectData.name)),
      body: _rooms.isEmpty
          ? const Center(
              child: Text(
                'Добавьте хотя бы одну комнату',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final room = _rooms[index];
                final consumerCount = room.consumers.fold<int>(
                  0,
                  (s, c) => s + c.quantity,
                );
                return Card(
                  child: ListTile(
                    title: Text(room.name),
                    subtitle: Text(
                      '${_roomTypeLabel(room.type)} · ${room.area} м² · '
                      'точек: $consumerCount',
                    ),
                    onTap: () async {
                      final updated = await Navigator.of(context)
                          .push<core.Room>(
                            MaterialPageRoute(
                              builder: (_) => RoomConsumersScreen(room: room),
                            ),
                          );
                      if (updated != null) {
                        setState(() => _rooms[index] = updated);
                      }
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeRoom(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoom,
        icon: const Icon(Icons.add),
        label: const Text('Комната'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _rooms.isEmpty ? null : _calculate,
            child: const Text('Рассчитать щиток'),
          ),
        ),
      ),
    );
  }

  String _roomTypeLabel(core.RoomType t) {
    switch (t) {
      case core.RoomType.kitchen:
        return 'Кухня';
      case core.RoomType.livingRoom:
        return 'Гостиная';
      case core.RoomType.bedroom:
        return 'Спальня';
      case core.RoomType.bathroom:
        return 'Ванная';
      case core.RoomType.toilet:
        return 'Туалет';
      case core.RoomType.combinedBathroom:
        return 'С/у совмещённый';
      case core.RoomType.hallway:
        return 'Коридор';
      case core.RoomType.childrenRoom:
        return 'Детская';
      case core.RoomType.pantry:
        return 'Кладовая';
      case core.RoomType.balcony:
        return 'Балкон';
      case core.RoomType.technical:
        return 'Техническое';
      case core.RoomType.entrance:
        return 'Прихожая';
      case core.RoomType.other:
        return 'Другое';
    }
  }
}

class _AddRoomDialog extends StatefulWidget {
  final void Function(
    String name,
    core.RoomType type,
    double area,
    List<core.Consumer> consumers,
  )
  onAdd;

  const _AddRoomDialog({required this.onAdd});

  @override
  State<_AddRoomDialog> createState() => _AddRoomDialogState();
}

class _AddRoomDialogState extends State<_AddRoomDialog> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController(text: '12');
  core.RoomType _type = core.RoomType.livingRoom;
  int _cid = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  List<core.Consumer> _defaultConsumers(core.RoomType type) {
    switch (type) {
      case core.RoomType.kitchen:
        return [
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетки',
            quantity: 6,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: 2,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.refrigerator,
            name: 'Холодильник',
            quantity: 1,
          ),
        ];
      case core.RoomType.bathroom:
      case core.RoomType.combinedBathroom:
        return [
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетка',
            quantity: 1,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: 1,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.washingMachine,
            name: 'Стиралка',
            powerKw: 2.0,
            isPowerful: true,
            requiresRcd: true,
          ),
        ];
      case core.RoomType.hallway:
        return [
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: 1,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетка',
            quantity: 1,
          ),
        ];
      default:
        return [
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетки',
            quantity: 4,
          ),
          core.Consumer(
            id: 'c_${_cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: 2,
          ),
        ];
    }
  }

  void _submit() {
    final name = _nameController.text.trim().isEmpty
        ? _defaultName(_type)
        : _nameController.text.trim();
    final area = double.tryParse(_areaController.text.replaceAll(',', '.'));
    if (area == null || area <= 0) return;

    widget.onAdd(name, _type, area, _defaultConsumers(_type));
    Navigator.of(context).pop();
  }

  String _defaultName(core.RoomType t) {
    switch (t) {
      case core.RoomType.kitchen:
        return 'Кухня';
      case core.RoomType.livingRoom:
        return 'Гостиная';
      case core.RoomType.bedroom:
        return 'Спальня';
      case core.RoomType.bathroom:
        return 'Ванная';
      case core.RoomType.toilet:
        return 'Туалет';
      case core.RoomType.combinedBathroom:
        return 'С/у';
      case core.RoomType.hallway:
        return 'Коридор';
      case core.RoomType.childrenRoom:
        return 'Детская';
      case core.RoomType.pantry:
        return 'Кладовая';
      case core.RoomType.balcony:
        return 'Балкон';
      case core.RoomType.technical:
        return 'Котельная';
      case core.RoomType.entrance:
        return 'Прихожая';
      case core.RoomType.other:
        return 'Комната';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая комната'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<core.RoomType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Тип',
                border: OutlineInputBorder(),
              ),
              items: core.RoomType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_defaultName(t)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Название (необязательно)',
                hintText: _defaultName(_type),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Площадь, м²',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'К комнате сразу добавятся типовые точки\n(розетки, свет и т.д.).',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Добавить')),
      ],
    );
  }
}
