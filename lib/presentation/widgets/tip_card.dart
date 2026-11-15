import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tip_state.dart';
import '../../core/tips.dart';

/// Небольшая подсказка внизу экрана. Не модалка: не мешает работе,
/// можно пролистать («Другая») или закрыть («Понятно»).
class TipCard extends ConsumerWidget {
  final TipScreen screen;

  const TipCard({super.key, required this.screen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = tipsFor(screen);
    if (all.isEmpty) return const SizedBox.shrink();

    final state = ref.watch(tipStateProvider);
    final visible = all.where((t) => !state.dismissed.contains(t.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final index = (state.offset[screen] ?? 0) % visible.length;
    final tip = visible[index];
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip.text,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (visible.length > 1)
                  TextButton(
                    onPressed: () =>
                        ref.read(tipStateProvider.notifier).next(screen, visible.length),
                    child: const Text('Другая'),
                  ),
                TextButton(
                  onPressed: () =>
                      ref.read(tipStateProvider.notifier).dismiss(tip.id),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
