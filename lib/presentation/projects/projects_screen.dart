import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../data/project_store.dart';
import '../project/overview_screen.dart';

/// Провайдер хранилища: один экземпляр на приложение.
final projectStoreProvider = Provider<ProjectStore>((ref) => ProjectStore());

/// Список сохранённых проектов (перечитывается после изменений).
final savedProjectsProvider =
    FutureProvider<List<SavedProject>>((ref) async {
  return ref.watch(projectStoreProvider).loadAll();
});

/// Список проектов: открыть, копировать, удалить.
class ProjectsScreen extends ConsumerWidget {
  final core.NormsCatalog norms;

  const ProjectsScreen({super.key, required this.norms});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    SavedProject project,
  ) async {
    final current = ref.read(projectDraftProvider);
    if (current.rooms.isNotEmpty &&
        current.name.trim() != project.name.trim()) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Открыть проект?'),
          content: Text(
            'Текущий черновик (${current.rooms.length} комнат) не сохранён '
            'и будет заменён проектом «${project.name}».',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Открыть'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    ref.read(projectDraftProvider.notifier).replaceDraft(project.draft);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OverviewScreen(norms: norms)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedProject project,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text('«${project.name}» будет удалён без возможности отмены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(projectStoreProvider).delete(project.id);
    ref.invalidate(savedProjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Проект «${project.name}» удалён')),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    SavedProject project,
  ) async {
    await ref.read(projectStoreProvider).duplicate(project);
    ref.invalidate(savedProjectsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Создана копия «${project.name} (копия)»')),
    );
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(savedProjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мои проекты')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Не удалось прочитать проекты:\n$e'),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_outlined,
                        size: 56, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'Сохранённых проектов пока нет',
                      style: TextStyle(
                        fontSize: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Посчитайте щит и нажмите «Сохранить» на экране '
                      'результата — проект появится здесь.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${p.roomsCount} комн. · '
                    'ТУ ${p.powerKw > 0 ? '${p.powerKw.toStringAsFixed(0)} кВт' : '—'} · '
                    '${_date(p.updatedAt)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () => _open(context, ref, p),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Действия',
                    onSelected: (value) {
                      switch (value) {
                        case 'open':
                          _open(context, ref, p);
                        case 'duplicate':
                          _duplicate(context, ref, p);
                        case 'delete':
                          _delete(context, ref, p);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'open', child: Text('Открыть')),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Дублировать'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
