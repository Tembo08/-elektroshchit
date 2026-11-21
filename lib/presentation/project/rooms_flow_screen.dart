import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/tips.dart';
import '../templates/templates_screen.dart';
import '../widgets/tip_card.dart';
import 'input_config_screen.dart';
import 'room_wizard_screen.dart';

class RoomsFlowScreen extends ConsumerStatefulWidget {
  final core.NormsCatalog norms;

  const RoomsFlowScreen({super.key, required this.norms});

  @override
  ConsumerState<RoomsFlowScreen> createState() => _RoomsFlowScreenState();
}

class _RoomsFlowScreenState extends ConsumerState<RoomsFlowScreen> {
  /// Последняя удалённая комната: показываем свою плашку «Вернуть».
  /// SnackBar не используем: он живёт на уровне приложения, не гаснет
  /// при некоторых настройках доступности и переезжает между экранами.
  RoomDraft? _lastDeleted;

  Future<void> _addRoom() async {
    _lastDeleted = null;
    final draft = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(builder: (_) => RoomWizardScreen(norms: widget.norms)),
    );
    if (draft == null) return;
    ref.read(projectDraftProvider.notifier).addRoom(draft);
  }

  Future<void> _editRoom(RoomDraft room) async {
    _lastDeleted = null;
    final updated = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(
        builder: (_) => RoomWizardScreen(norms: widget.norms, existing: room),
      ),
    );
    if (updated == null) return;
    ref.read(projectDraftProvider.notifier).updateRoom(updated);
  }

  void _deleteRoom(RoomDraft room) {
    ref.read(projectDraftProvider.notifier).removeRoom(room.id);
    setState(() => _lastDeleted = room);
  }

  void _undoDelete() {
    final room = _lastDeleted;
    if (room == null) return;
    ref.read(projectDraftProvider.notifier).addRoom(room);
    setState(() => _lastDeleted = null);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(projectDraftProvider).rooms;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Комнаты'),
        actions: [
          IconButton(
            tooltip: 'Готовые шаблоны',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TemplatesScreen(norms: widget.norms),
                ),
              );
            },
          ),
        ],
      ),
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
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _addRoom,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить комнату'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TemplatesScreen(
                                  norms: widget.norms,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dashboard_customize_outlined),
                          label: const Text('Начать с шаблона'),
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
                          title:
                              Text(r.name, style: const TextStyle(fontSize: 17)),
                          subtitle: Text(
                            'Розетки: ${r.totalSockets} · Лампы: ${r.lights} · '
                            'Выключатели: ${r.switches}'
                            '${r.dedicatedCount > 0 ? " · Силовые: ${r.dedicatedCount}" : ""}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          onTap: () => _editRoom(r),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Удалить комнату',
                            onPressed: () => _deleteRoom(r),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_lastDeleted != null)
            _UndoBar(
              text: 'Комната «${_lastDeleted!.name}» удалена',
              onUndo: _undoDelete,
              onClose: () => setState(() => _lastDeleted = null),
            ),
          // FAB «Комната» висит над нижней панелью и перекрывал подсказку:
          // когда кнопка видна, оставляем под ней место.
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, rooms.isEmpty ? 8 : 76),
            child: const TipCard(screen: TipScreen.rooms),
          ),
        ],
      ),
      floatingActionButton: rooms.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addRoom,
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
                        builder: (_) => InputConfigScreen(norms: widget.norms),
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

/// Своя плашка «удалено» вместо SnackBar: живёт, пока пользователь не решил,
/// и не всплывает на других экранах.
class _UndoBar extends StatelessWidget {
  final String text;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  const _UndoBar({
    required this.text,
    required this.onUndo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            TextButton(onPressed: onUndo, child: const Text('Вернуть')),
            IconButton(
              tooltip: 'Закрыть',
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
