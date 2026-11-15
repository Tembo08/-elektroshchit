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

  @override
  void initState() {
    super.initState();
    // Возвращаемся с «назад» — показываем то, что уже выбрано.
    final draft = ref.read(projectDraftProvider);
    _objectType = draft.objectType;
    _phase = draft.phaseSystem;
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _objectType != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Объект')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const Spacer(),
            FilledButton(
              onPressed: canNext
                  ? () {
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
      ),
    );
  }

  Widget _choiceCard({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? const Color(0xFF007AFF).withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF007AFF) : Colors.black12,
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
