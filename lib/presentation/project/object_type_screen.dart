import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import 'rooms_flow_screen.dart';

class ObjectTypeScreen extends ConsumerStatefulWidget {
  final core.NormsCatalog norms;

  const ObjectTypeScreen({super.key, required this.norms});

  @override
  ConsumerState<ObjectTypeScreen> createState() => _ObjectTypeScreenState();
}

class _ObjectTypeScreenState extends ConsumerState<ObjectTypeScreen> {
  core.ObjectType? _objectType;
  core.PhaseSystem _phase = core.PhaseSystem.single;
  core.GroundingSystem _grounding = core.GroundingSystem.tnCs;
  late TextEditingController _nameController;
  late TextEditingController _areaController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    // Возвращаемся с «назад» — показываем то, что уже выбрано.
    final draft = ref.read(projectDraftProvider);
    _objectType = draft.objectType;
    _phase = draft.phaseSystem;
    _grounding = draft.groundingSystem;
    _nameController = TextEditingController(text: draft.name);
    _areaController = TextEditingController(
      text: draft.totalArea > 0 ? _num(draft.totalArea) : '',
    );
    _heightController = TextEditingController(
      text: draft.ceilingHeight > 0 ? _num(draft.ceilingHeight) : '',
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// Сохраняем метаданные в черновик, чтобы они пережили «назад».
  void _saveMeta() {
    ref.read(projectDraftProvider.notifier).setMeta(
          name: _nameController.text.trim(),
          totalArea: double.tryParse(
                _areaController.text.replaceAll(',', '.'),
              ) ??
              0,
          ceilingHeight: double.tryParse(
                _heightController.text.replaceAll(',', '.'),
              ) ??
              0,
          groundingSystem: _grounding,
        );
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _objectType != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Объект')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
            const Text(
              'Тип объекта',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _choiceCard(
              title: 'Квартира',
              selected: _objectType == core.ObjectType.apartment,
              onTap: () =>
                  setState(() => _objectType = core.ObjectType.apartment),
            ),
            const SizedBox(height: 10),
            _choiceCard(
              title: 'Дом',
              selected: _objectType == core.ObjectType.privateHouse,
              onTap: () =>
                  setState(() => _objectType = core.ObjectType.privateHouse),
            ),
            const SizedBox(height: 28),
            const Text(
              'Фазы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<core.PhaseSystem>(
              segments: const [
                ButtonSegment(
                  value: core.PhaseSystem.single,
                  label: Text('Одна фаза'),
                  icon: Icon(Icons.looks_one_outlined),
                ),
                ButtonSegment(
                  value: core.PhaseSystem.three,
                  label: Text('Три фазы'),
                  icon: Icon(Icons.looks_3_outlined),
                ),
              ],
              selected: {_phase},
              onSelectionChanged: (s) => setState(() => _phase = s.first),
            ),
            const SizedBox(height: 24),
            const Text(
              'Название объекта',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Квартира, Ленина 5',
                helperText: 'Попадёт в спецификацию и документы',
              ),
              onChanged: (_) => _saveMeta(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _areaController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Площадь, м²',
                    ),
                    onChanged: (_) => _saveMeta(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Потолки, м',
                    ),
                    onChanged: (_) => _saveMeta(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Система заземления',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Для TT все линии обязаны быть под УЗО — приложение проверит '
              'и подскажет.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<core.GroundingSystem>(
              segments: const [
                ButtonSegment(
                  value: core.GroundingSystem.tnCs,
                  label: Text('TN-C-S'),
                ),
                ButtonSegment(
                  value: core.GroundingSystem.tnS,
                  label: Text('TN-S'),
                ),
                ButtonSegment(
                  value: core.GroundingSystem.tt,
                  label: Text('TT'),
                ),
              ],
              selected: {_grounding},
              onSelectionChanged: (v) {
                setState(() => _grounding = v.first);
                _saveMeta();
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: canNext
                  ? () {
                      _saveMeta();
                      ref.read(projectDraftProvider.notifier).startProject(
                            _objectType!,
                            _phase,
                          );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomsFlowScreen(norms: widget.norms),
                        ),
                      );
                    }
                  : null,
              child: const Text('Далее', style: TextStyle(fontSize: 17)),
            ),
        ],
      ),
    );
  }

  Widget _choiceCard({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
