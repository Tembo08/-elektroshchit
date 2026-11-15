import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/tips.dart';
import '../widgets/tip_card.dart';
import 'input_config_screen.dart';
import 'room_wizard_screen.dart';

class RoomsFlowScreen extends ConsumerWidget {
  final core.NormsCatalog norms;

  const RoomsFlowScreen({super.key, required this.norms});

  Future<void> _addRoom(BuildContext context, WidgetRef ref) async {
    final draft = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(builder: (_) => RoomWizardScreen(norms: norms)),
    );
    if (draft == null) return;
    ref.read(projectDraftProvider.notifier).addRoom(draft);
  }

  Future<void> _editRoom(
    BuildContext context,
    WidgetRef ref,
    RoomDraft room,
  ) async {
    final updated = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(builder: (_) => RoomWizardScreen(norms: norms, existing: room)),
    );
    if (updated == null) return;
    ref.read(projectDraftProvider.notifier).updateRoom(updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(projectDraftProvider).rooms;

    return Scaffold(
      appBar: AppBar(title: const Text('Комнаты')),
      body: Column(
        children: [
          Expanded(
            child: rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Пока ни одной комнаты',
                    style: TextStyle(
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _addRoom(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить комнату'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              // Отступ снизу, чтобы FAB не перекрывал последнюю карточку.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final r = rooms[i];
                return Card(
                  child: ListTile(
                    title: Text(r.name, style: const TextStyle(fontSize: 17)),
                    subtitle: Text(
                      'Розетки: ${r.totalSockets} · Лампы: ${r.lights} · '
                      'Выключатели: ${r.switches}'
                      '${r.dedicatedCount > 0 ? " · Силовые: ${r.dedicatedCount}" : ""}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () => _editRoom(context, ref, r),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Удалить комнату',
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        ref
                            .read(projectDraftProvider.notifier)
                            .removeRoom(r.id);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Комната «${r.name}» удалена'),
                            action: SnackBarAction(
                              label: 'Вернуть',
                              onPressed: () => ref
                                  .read(projectDraftProvider.notifier)
                                  .addRoom(r),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            // отступ справа/снизу, чтобы FAB не перекрывал подсказку
            padding: EdgeInsets.fromLTRB(16, 0, 16, 84),
            child: TipCard(screen: TipScreen.rooms),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRoom(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Комната'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: rooms.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InputConfigScreen(norms: norms),
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
