import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';

import '../../core/project_draft.dart';

class RoomWizardScreen extends StatefulWidget {
  final core.NormsCatalog norms;
  final core.RoomType? initialType;
  final RoomDraft? existing;

  const RoomWizardScreen({
    super.key,
    required this.norms,
    this.initialType,
    this.existing,
  });

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

  final Map<core.ConsumerType, ApplianceSpec> _dedicated = {};
  final Map<core.ConsumerType, TextEditingController> _powerControllers = {};
  bool _dirty = false;

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
    core.ConsumerType.evCharger: 'Зарядка электромобиля (EV)',
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
      _dedicated.addAll(e.dedicated);
      _dedicated.forEach(_syncController);
    } else {
      _applyDefaults(_type);
    }
  }

  void _applyDefaults(core.RoomType t) {
    _mirrorSocket = 0;
    _socketsNormal = 1;
    _lights = 1;
    _switches = 1;
  }

  /// Типовая мощность прибора из норм — чтобы в поле было с чего начать.
  double _defaultPower(core.ConsumerType type) =>
      widget.norms.defaultPowerKw[type.name] ?? 2.0;

  void _syncController(core.ConsumerType type, ApplianceSpec spec) {
    final text = (spec.powerKw ?? _defaultPower(type)).toStringAsFixed(1);
    final ctrl = _powerControllers[type];
    if (ctrl == null) {
      _powerControllers[type] = TextEditingController(text: text);
    } else if (ctrl.text.isEmpty) {
      ctrl.text = text;
    }
  }

  void _setQuantity(core.ConsumerType type, int qty) {
    setState(() {
      _dirty = true;
      if (qty <= 0) {
        _dedicated.remove(type);
        _powerControllers.remove(type)?.dispose();
      } else {
        final old = _dedicated[type];
        final spec = (old ?? ApplianceSpec(quantity: qty)).copyWith(
          quantity: qty,
        );
        _dedicated[type] = spec;
        _syncController(type, spec);
      }
    });
  }

  void _setPower(core.ConsumerType type, String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    final old = _dedicated[type];
    if (old == null) return;
    _dedicated[type] = ApplianceSpec(
      quantity: old.quantity,
      powerKw: (value != null && value > 0) ? value : null,
      phases: old.phases,
    );
    _dirty = true;
  }

  void _setPhases(core.ConsumerType type, int phases) {
    final old = _dedicated[type];
    if (old == null) return;
    setState(() {
      _dirty = true;
      _dedicated[type] = old.copyWith(phases: phases);
    });
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

  RoomDraft _buildDraft() {
    return RoomDraft(
      id: widget.existing?.id ?? 'r_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? _typeLabel(_type)
          : _nameController.text.trim(),
      type: _type,
      socketsNormal: _socketsNormal,
      lights: _lights,
      switches: _switches,
      mirrorSockets: _mirrorSocket,
      dedicated: Map.of(_dedicated),
    );
  }

  void _done() {
    Navigator.of(context).pop(_buildDraft());
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти без сохранения?'),
        content: const Text('Изменения в этой комнате будут потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return leave ?? false;
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
          tooltip: 'Уменьшить',
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
          tooltip: 'Увеличить',
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _powerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (!context.mounted) return;
        if (leave) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'Новая комната' : 'Комната'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Тип',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<core.RoomType>(
              initialValue: _type,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: core.RoomType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
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
            const Text(
              'Обычные розетки',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            _stepper(
              label: 'Количество',
              value: _socketsNormal,
              onChanged: (v) => setState(() {
                _dirty = true;
                _socketsNormal = v;
              }),
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
                onChanged: (v) => setState(() {
                  _dirty = true;
                  _mirrorSocket = v;
                }),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Розетка под прибор (отдельная линия)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._dedicatedOptions.entries.map((e) {
              final spec = _dedicated[e.key];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepper(
                    label: e.value,
                    value: spec?.quantity ?? 0,
                    max: 5,
                    onChanged: (v) => _setQuantity(e.key, v),
                  ),
                  if (spec != null) _applianceSettings(e.key, e.value, spec),
                ],
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Освещение',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            _stepper(
              label: 'Лампочки / светильники',
              value: _lights,
              onChanged: (v) => setState(() {
                _dirty = true;
                _lights = v;
              }),
            ),
            const SizedBox(height: 12),
            const Text(
              'Выключатели',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            _stepper(
              label: 'Количество',
              value: _switches,
              onChanged: (v) => setState(() {
                _dirty = true;
                _switches = v;
              }),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _done,
              child: const Text('Готово', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }

  /// Мощность и число фаз для прибора: раньше брались только типовые значения.
  Widget _applianceSettings(
    core.ConsumerType type,
    String label,
    ApplianceSpec spec,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _powerControllers[type],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Мощность «$label», кВт',
              helperText: 'Пусто — типовая '
                  '${_defaultPower(type).toStringAsFixed(1)} кВт',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _setPower(type, v),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 фаза')),
              ButtonSegment(value: 3, label: Text('3 фазы')),
            ],
            selected: {spec.phases},
            onSelectionChanged: (s) => _setPhases(type, s.first),
          ),
        ],
      ),
    );
  }
}
