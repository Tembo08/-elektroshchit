import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

class RoomConsumersScreen extends StatefulWidget {
  final core.Room room;

  const RoomConsumersScreen({super.key, required this.room});

  @override
  State<RoomConsumersScreen> createState() => _RoomConsumersScreenState();
}

class _RoomConsumersScreenState extends State<RoomConsumersScreen> {
  late List<core.Consumer> _consumers;
  int _idCounter = 100;

  @override
  void initState() {
    super.initState();
    _consumers = List.of(widget.room.consumers);
  }

  void _addConsumer() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddConsumerDialog(
        onAdd: (c) => setState(() => _consumers.add(c)),
        nextId: () => 'c_${_idCounter++}',
      ),
    );
  }

  void _removeAt(int index) {
    setState(() => _consumers.removeAt(index));
  }

  void _save() {
    final updated = widget.room.copyWith(consumers: List.unmodifiable(_consumers));
    Navigator.of(context).pop(updated);
  }

  String _typeLabel(core.ConsumerType t) {
    const map = {
      core.ConsumerType.socket: 'Розетка',
      core.ConsumerType.switchSingle: 'Выключатель',
      core.ConsumerType.switchDouble: 'Выключатель 2-кл',
      core.ConsumerType.switchPassThrough: 'Проходной',
      core.ConsumerType.lightPoint: 'Светильник',
      core.ConsumerType.chandelier: 'Люстра',
      core.ConsumerType.ledStrip: 'LED-лента',
      core.ConsumerType.electricStove: 'Плита',
      core.ConsumerType.oven: 'Духовка',
      core.ConsumerType.dishwasher: 'Посудомойка',
      core.ConsumerType.washingMachine: 'Стиралка',
      core.ConsumerType.waterHeater: 'Бойлер',
      core.ConsumerType.airConditioner: 'Кондиционер',
      core.ConsumerType.underfloorHeating: 'Тёплый пол',
      core.ConsumerType.evCharger: 'Зарядка ЭМ',
      core.ConsumerType.refrigerator: 'Холодильник',
      core.ConsumerType.hood: 'Вытяжка',
      core.ConsumerType.boiler: 'Котёл',
      core.ConsumerType.otherPowerful: 'Другое мощное',
    };
    return map[t] ?? t.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Готово'),
          ),
        ],
      ),
      body: _consumers.isEmpty
          ? const Center(child: Text('Нет потребителей'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _consumers.length,
              itemBuilder: (context, index) {
                final c = _consumers[index];
                final power = c.powerKw != null
                    ? '${c.powerKw} кВт'
                    : (c.isPowerful ? 'мощный' : '');
                return Card(
                  child: ListTile(
                    title: Text('${c.name} ×${c.quantity}'),
                    subtitle: Text(
                      [
                        _typeLabel(c.type),
                        if (power.isNotEmpty) power,
                        if (c.requiresRcd) 'УЗО',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAt(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addConsumer,
        icon: const Icon(Icons.add),
        label: const Text('Точка'),
      ),
    );
  }
}

class _AddConsumerDialog extends StatefulWidget {
  final void Function(core.Consumer consumer) onAdd;
  final String Function() nextId;

  const _AddConsumerDialog({
    required this.onAdd,
    required this.nextId,
  });

  @override
  State<_AddConsumerDialog> createState() => _AddConsumerDialogState();
}

class _AddConsumerDialogState extends State<_AddConsumerDialog> {
  core.ConsumerType _type = core.ConsumerType.socket;
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _powerController = TextEditingController();

  static const _powerful = {
    core.ConsumerType.electricStove,
    core.ConsumerType.oven,
    core.ConsumerType.dishwasher,
    core.ConsumerType.washingMachine,
    core.ConsumerType.waterHeater,
    core.ConsumerType.airConditioner,
    core.ConsumerType.underfloorHeating,
    core.ConsumerType.evCharger,
    core.ConsumerType.boiler,
    core.ConsumerType.otherPowerful,
  };

  static const _labels = {
    core.ConsumerType.socket: 'Розетка',
    core.ConsumerType.lightPoint: 'Светильник',
    core.ConsumerType.chandelier: 'Люстра',
    core.ConsumerType.electricStove: 'Плита',
    core.ConsumerType.oven: 'Духовка',
    core.ConsumerType.dishwasher: 'Посудомойка',
    core.ConsumerType.washingMachine: 'Стиралка',
    core.ConsumerType.waterHeater: 'Бойлер',
    core.ConsumerType.airConditioner: 'Кондиционер',
    core.ConsumerType.underfloorHeating: 'Тёплый пол',
    core.ConsumerType.evCharger: 'Зарядка ЭМ',
    core.ConsumerType.refrigerator: 'Холодильник',
    core.ConsumerType.hood: 'Вытяжка',
    core.ConsumerType.boiler: 'Котёл',
    core.ConsumerType.otherPowerful: 'Другое мощное',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _powerController.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_qtyController.text) ?? 1;
    if (qty < 1) return;

    final isPowerful = _powerful.contains(_type);
    double? power;
    if (_powerController.text.trim().isNotEmpty) {
      power = double.tryParse(_powerController.text.replaceAll(',', '.'));
    } else if (isPowerful) {
      power = _defaultPower(_type);
    }

    final name = _nameController.text.trim().isEmpty
        ? (_labels[_type] ?? _type.name)
        : _nameController.text.trim();

    widget.onAdd(core.Consumer(
      id: widget.nextId(),
      type: _type,
      name: name,
      quantity: qty,
      powerKw: power,
      isPowerful: isPowerful,
      requiresRcd: isPowerful || _type == core.ConsumerType.socket,
    ));
    Navigator.pop(context);
  }

  double _defaultPower(core.ConsumerType t) {
    switch (t) {
      case core.ConsumerType.electricStove:
        return 7.0;
      case core.ConsumerType.oven:
        return 3.5;
      case core.ConsumerType.dishwasher:
      case core.ConsumerType.washingMachine:
      case core.ConsumerType.waterHeater:
      case core.ConsumerType.boiler:
        return 2.0;
      case core.ConsumerType.airConditioner:
        return 2.5;
      case core.ConsumerType.underfloorHeating:
        return 1.5;
      case core.ConsumerType.evCharger:
        return 7.0;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPowerful = _powerful.contains(_type);
    return AlertDialog(
      title: const Text('Добавить точку'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<core.ConsumerType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Тип',
                border: OutlineInputBorder(),
              ),
              items: _labels.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
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
                labelText: 'Название',
                hintText: _labels[_type],
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество',
                border: OutlineInputBorder(),
              ),
            ),
            if (isPowerful) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _powerController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Мощность, кВт',
                  hintText: '${_defaultPower(_type)}',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
