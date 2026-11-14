import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'rooms_flow_screen.dart';

class ObjectTypeScreen extends StatefulWidget {
  final core.NormsCatalog norms;

  const ObjectTypeScreen({super.key, required this.norms});

  @override
  State<ObjectTypeScreen> createState() => _ObjectTypeScreenState();
}

class _ObjectTypeScreenState extends State<ObjectTypeScreen> {
  core.ObjectType? _objectType;
  core.PhaseSystem _phase = core.PhaseSystem.single;

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
              onTap: () => setState(() => _objectType = core.ObjectType.apartment),
            ),
            const SizedBox(height: 10),
            _choiceCard(
              title: 'Дом',
              selected: _objectType == core.ObjectType.privateHouse,
              onTap: () => setState(() => _objectType = core.ObjectType.privateHouse),
            ),
            const SizedBox(height: 28),
            const Text(
              'Фазы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _phase == core.PhaseSystem.single,
              title: const Text('Одна фаза', style: TextStyle(fontSize: 16)),
              onChanged: (_) => setState(() => _phase = core.PhaseSystem.single),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _phase == core.PhaseSystem.three,
              title: const Text('Три фазы', style: TextStyle(fontSize: 16)),
              onChanged: (_) => setState(() => _phase = core.PhaseSystem.three),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            FilledButton(
              onPressed: canNext
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomsFlowScreen(
                            norms: widget.norms,
                            objectType: _objectType!,
                            phaseSystem: _phase,
                          ),
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
      color: selected ? const Color(0xFF007AFF).withValues(alpha: 0.12) : Colors.white,
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
