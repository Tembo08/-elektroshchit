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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
            const Text(
              'Тип объекта',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _choiceCard(
                    title: 'Квартира',
                    icon: Icons.apartment,
                    selected: _objectType == core.ObjectType.apartment,
                    onTap: () => setState(
                      () => _objectType = core.ObjectType.apartment,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choiceCard(
                    title: 'Дом',
                    icon: Icons.cottage,
                    selected: _objectType == core.ObjectType.privateHouse,
                    onTap: () => setState(
                      () => _objectType = core.ObjectType.privateHouse,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            const Text(
              'Система заземления',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showGroundingHelp(context),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Что значат TN-C-S, TN-S и TT?'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 88),
          ],
        ),
        // SafeArea отводит место под системную панель навигации,
        // Padding добавляет «дыхание», чтобы кнопка не прилипала к ней.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canNext
                    ? () {
                        _saveMeta();
                        ref.read(projectDraftProvider.notifier).startProject(
                              _objectType!,
                              _phase,
                            );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RoomsFlowScreen(norms: widget.norms),
                          ),
                        );
                      }
                    : null,
                child: const Text('Далее', style: TextStyle(fontSize: 17)),
              ),
            ),
          ),
        ),
    );
  }

  /// Расшифровка систем заземления: постоянная карточка не влезала на
  /// экран телефона и вытесняла сам переключатель под кнопку.
  void _showGroundingHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Системы заземления',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Выбирайте ту, что указана в проекте дома или в ТУ. '
                'Если не знаете — уточните у электрика, обслуживающего дом.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in _groundingNotes.entries)
                _GroundingCard(
                  data: entry.value,
                  active: entry.key == _grounding,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceCard({
    required String title,
    required IconData icon,
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
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Расшифровки систем заземления: что это и чем важно на практике.
class _GroundingCard extends StatelessWidget {
  final (String, String, String) data;
  final bool active;

  const _GroundingCard({required this.data, required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (title, what, important) = data;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: active
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? scheme.primary.withValues(alpha: 0.55) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: active ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              if (active)
                Icon(Icons.check_circle, size: 16, color: scheme.primary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            what,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            important,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Пояснения по системам заземления. Общие для карточки и нижнего листа.
const _groundingNotes = {
  core.GroundingSystem.tnCs: (
    'TN-C-S — самая частая схема в домах',
    'К щиту идут четыре провода (фазы и совмещённый PEN), на вводе PEN '
        'делится на нулевой N и защитный PE. Дальше по квартире они идут '
        'раздельно.',
    'Если PEN оборвётся до деления, корпуса приборов окажутся под '
        'напряжением — поэтому УЗО обязательно.',
  ),
  core.GroundingSystem.tnS: (
    'TN-S — пять проводов от подстанции',
    'Нулевой и защитный проводники разделены по всей линии, начиная от '
        'трансформатора. Так делают в новых домах и по проекту.',
    'Самый предсказуемый вариант. Требует пятижильного ввода: три фазы, N и PE.',
  ),
  core.GroundingSystem.tt: (
    'TT — заземление своё, от сети не зависит',
    'Защитный проводник идёт от собственного заземлителя: штырей, полосы или '
        'контура. Так делают в частных домах и на дачах.',
    'Автомат от поражения током не защищает, поэтому УЗО нужно на каждой '
        'линии — приложение это проверит.',
  ),
};
