import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

/// Данные, которые пользователь вводит при создании проекта
class NewProjectData {
  final String name;
  final core.ObjectType objectType;
  final core.PhaseSystem phaseSystem;
  final double allowedPowerKw;
  final core.GroundingSystem groundingSystem;
  final double totalArea;
  final double ceilingHeight;

  const NewProjectData({
    required this.name,
    required this.objectType,
    required this.phaseSystem,
    required this.allowedPowerKw,
    required this.groundingSystem,
    required this.totalArea,
    required this.ceilingHeight,
  });
}

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Новый проект');
  final _powerController = TextEditingController(text: '7');
  final _areaController = TextEditingController(text: '50');
  final _heightController = TextEditingController(text: '2.7');

  core.ObjectType _objectType = core.ObjectType.apartment;
  core.PhaseSystem _phaseSystem = core.PhaseSystem.single;
  core.GroundingSystem _grounding = core.GroundingSystem.tnCs;

  @override
  void dispose() {
    _nameController.dispose();
    _powerController.dispose();
    _areaController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = NewProjectData(
      name: _nameController.text.trim(),
      objectType: _objectType,
      phaseSystem: _phaseSystem,
      allowedPowerKw: double.parse(_powerController.text.replaceAll(',', '.')),
      groundingSystem: _grounding,
      totalArea: double.parse(_areaController.text.replaceAll(',', '.')),
      ceilingHeight: double.parse(_heightController.text.replaceAll(',', '.')),
    );

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый проект')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Укажите название' : null,
            ),
            const SizedBox(height: 16),

            const Text('Тип объекта', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<core.ObjectType>(
              segments: const [
                ButtonSegment(
                  value: core.ObjectType.apartment,
                  label: Text('Квартира'),
                ),
                ButtonSegment(
                  value: core.ObjectType.privateHouse,
                  label: Text('Дом'),
                ),
              ],
              selected: {_objectType},
              onSelectionChanged: (s) => setState(() => _objectType = s.first),
            ),
            const SizedBox(height: 16),

            const Text('Фазы', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<core.PhaseSystem>(
              segments: const [
                ButtonSegment(
                  value: core.PhaseSystem.single,
                  label: Text('1 фаза'),
                ),
                ButtonSegment(
                  value: core.PhaseSystem.three,
                  label: Text('3 фазы'),
                ),
              ],
              selected: {_phaseSystem},
              onSelectionChanged: (s) => setState(() => _phaseSystem = s.first),
            ),
            const SizedBox(height: 16),

            const Text('Заземление', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<core.GroundingSystem>(
              initialValue: _grounding,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                  value: core.GroundingSystem.tnCs,
                  child: Text('TN-C-S'),
                ),
                DropdownMenuItem(
                  value: core.GroundingSystem.tnS,
                  child: Text('TN-S'),
                ),
                DropdownMenuItem(
                  value: core.GroundingSystem.tt,
                  child: Text('TT'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _grounding = v);
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _powerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Разрешённая мощность по ТУ, кВт',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Укажите мощность > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _areaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Общая площадь, м²',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Укажите площадь > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Высота потолков, м',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Укажите высоту > 0';
                return null;
              },
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _submit,
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );
  }
}
