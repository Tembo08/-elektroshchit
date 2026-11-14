import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'rooms_flow_screen.dart';

class RoomWizardScreen extends StatefulWidget {
  final core.RoomType? initialType;
  final RoomDraft? existing;

  const RoomWizardScreen({super.key, this.initialType, this.existing});

  @override
  State<RoomWizardScreen> createState() => _RoomWizardScreenState();
}

class _RoomWizardScreenState extends State<RoomWizardScreen> {
  late core.RoomType _type;
  late TextEditingController _nameController;
  int _socketsNormal = 1;
  int _lights = 1;
  int _switches = 1;
  int _mirrorSocket = 0; // розетка у зеркала (ванная)
  final Map<core.ConsumerType, int> _dedicated = {};

  static const _dedicatedOptions = <core.ConsumerType, String>{
    core.ConsumerType.washingMachine: 'Стиралка',
    core.ConsumerType.dishwasher: 'Посудомойка',
    core.ConsumerType.oven: 'Духовка / СВЧ',
    core.ConsumerType.electricStove: 'Варочная панель',
    core.ConsumerType.waterHeater: 'Бойлер',
    core.ConsumerType.boiler: 'Котёл',
    core.ConsumerType.airConditioner: 'Кондиционер',
    core.ConsumerType.underfloorHeating: 'Тёплый пол',
    core.ConsumerType.refrigerator: 'Холодильник',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? core.RoomType.livingRoom;
    _nameController = TextEditingController(text: e?.name ?? _typeLabel(_type));
    if (e != null) {
      _mirrorSocket = e.mirrorSockets;
      _socketsNormal = e.socketsNormal;
      _lights = e.lights;
      _switches = e.switches;
      _dedicated.addAll(e.dedicatedSockets);
    } else {
      _applyDefaults(_type);
    }
  }

  void _applyDefaults(core.RoomType t) {
    _mirrorSocket = 0;
    switch (t) {
      case core.RoomType.kitchen:
        _socketsNormal = 1;
        _lights = 1;
        _switches = 1;
        break;
      case core.RoomType.bathroom:
      case core.RoomType.combinedBathroom:
        _socketsNormal = 0;
        _mirrorSocket = 1;
        _lights = 1;
        _switches = 1;
        break;
      case core.RoomType.entrance:
      case core.RoomType.hallway:
      case core.RoomType.toilet:
        _socketsNormal = 1;
        _lights = 1;
        _switches = 1;
        break;
      default:
        _socketsNormal = 1;
        _lights = 1;
        _switches = 1;
    }
  }

  String _typeLabel(core.RoomType t) {
    switch (t) {
      case core.RoomType.kitchen:
        return 'Кухня';
      case core.RoomType.livingRoom:
        return 'Гостиная';
      case core.RoomType.bedroom:
        return 'Спальня';
      case core.RoomType.childrenRoom:
        return 'Детская';
      case core.RoomType.bathroom:
        return 'Ванная';
      case core.RoomType.toilet:
        return 'Туалет';
      case core.RoomType.combinedBathroom:
        return 'С/у совмещённый';
      case core.RoomType.hallway:
        return 'Коридор';
      case core.RoomType.entrance:
        return 'Прихожая';
      case core.RoomType.pantry:
        return 'Кладовая';
      case core.RoomType.balcony:
        return 'Балкон';
      case core.RoomType.technical:
        return 'Котельная';
      case core.RoomType.other:
        return 'Другое';
    }
  }

  void _done() {
    final draft = RoomDraft(
      id: widget.existing?.id ?? 'r_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? _typeLabel(_type)
          : _nameController.text.trim(),
      type: _type,
      socketsNormal: _socketsNormal,
      lights: _lights,
      switches: _switches,
      dedicatedSockets: Map.of(_dedicated),
      mirrorSockets: _mirrorSocket,
    );
    Navigator.of(context).pop(draft);
  }

  Widget _stepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 0,
    int max = 30,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Новая комната' : 'Комната'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Тип', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<core.RoomType>(
            value: _type,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: core.RoomType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _type = v;
                if (widget.existing == null) {
                  _nameController.text = _typeLabel(v);
                  _applyDefaults(v);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Обычные розетки', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          _stepper(
            label: 'Количество',
            value: _socketsNormal,
            onChanged: (v) => setState(() => _socketsNormal = v),
          ),
          if (_type == core.RoomType.bathroom ||
              _type == core.RoomType.combinedBathroom) ...[
            const SizedBox(height: 8),
            const Text(
              'Розетка у зеркала',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            _stepper(
              label: 'Количество',
              value: _mirrorSocket,
              max: 3,
              onChanged: (v) => setState(() => _mirrorSocket = v),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Розетка под прибор (отдельная линия)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._dedicatedOptions.entries.map((e) {
            final count = _dedicated[e.key] ?? 0;
            return _stepper(
              label: e.value,
              value: count,
              max: 5,
              onChanged: (v) => setState(() {
                if (v == 0) {
                  _dedicated.remove(e.key);
                } else {
                  _dedicated[e.key] = v;
                }
              }),
            );
          }),
          const SizedBox(height: 16),
          const Text('Освещение', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          _stepper(
            label: 'Лампочки / светильники',
            value: _lights,
            onChanged: (v) => setState(() => _lights = v),
          ),
          const SizedBox(height: 12),
          const Text('Выключатели', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          _stepper(
            label: 'Количество',
            value: _switches,
            onChanged: (v) => setState(() => _switches = v),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _done,
            child: const Text('Готово', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
