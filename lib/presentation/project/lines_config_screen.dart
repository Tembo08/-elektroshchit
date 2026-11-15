import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/tips.dart';
import '../widgets/tip_card.dart';
import 'overview_screen.dart';

class LinesConfigScreen extends ConsumerStatefulWidget {
  final core.NormsCatalog norms;

  const LinesConfigScreen({super.key, required this.norms});

  @override
  ConsumerState<LinesConfigScreen> createState() => _LinesConfigScreenState();
}

class _LinesConfigScreenState extends ConsumerState<LinesConfigScreen> {
  late int _lightingLines;
  late int _socketLines;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(projectDraftProvider);
    _lightingLines = draft.lightingLines;
    _socketLines = draft.socketLines;
  }

  int get _dedicatedCount {
    var n = 0;
    for (final r in ref.read(projectDraftProvider).rooms) {
      n += r.dedicatedCount;
    }
    return n;
  }

  int get _normalSockets {
    return ref
        .read(projectDraftProvider)
        .rooms
        .fold<int>(0, (s, r) => s + r.socketsNormal);
  }

  int get _lights {
    return ref
        .read(projectDraftProvider)
        .rooms
        .fold<int>(0, (s, r) => s + r.lights);
  }

  void _save() {
    ref.read(projectDraftProvider.notifier).setLines(
          lightingLines: _lightingLines,
          socketLines: _socketLines,
        );
  }

  Widget _stepper({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 1,
    int max = 10,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              tooltip: 'Уменьшить',
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              tooltip: 'Увеличить',
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Линии')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Розеток обычных: $_normalSockets · Силовых приборов: '
            '$_dedicatedCount · Светильников: $_lights',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _stepper(
            context: context,
            title: 'Линии освещения',
            subtitle: 'На всю квартиру / дом (не по комнатам)',
            value: _lightingLines,
            onChanged: (v) => setState(() {
              _lightingLines = v;
              _save();
            }),
          ),
          const SizedBox(height: 12),
          _stepper(
            context: context,
            title: 'Линии розеток',
            subtitle: 'Только обычные розетки. Силовые — всегда отдельно.',
            value: _socketLines,
            onChanged: (v) => setState(() {
              _socketLines = v;
              _save();
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Варочная, бойлер, котёл, стиралка, посудомойка, кондиционер, '
            'тёплый пол — отдельные линии, их число задавать не нужно.',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          const TipCard(screen: TipScreen.lines),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () {
              _save();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OverviewScreen(norms: widget.norms),
                ),
              );
            },
            child: const Text('Далее', style: TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
  }
}
