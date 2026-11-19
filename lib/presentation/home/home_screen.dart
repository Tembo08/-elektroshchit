import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/providers.dart';
import '../project/object_type_screen.dart';
import '../projects/projects_screen.dart';
import 'panel_styles.dart';
import '../tips/tips_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Новый проект всегда начинается с чистого черновика: иначе после
  /// возврата домой «Начать проект» открывал старые комнаты.
  Future<void> _startProject(
    BuildContext context,
    WidgetRef ref,
    core.NormsCatalog norms,
  ) async {
    final draft = ref.read(projectDraftProvider);
    if (draft.rooms.isNotEmpty) {
      final restart = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Начать новый проект?'),
          content: Text(
            'Текущий проект (${draft.rooms.length} комнат) не сохранён — '
            'его данные будут очищены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Начать новый'),
            ),
          ],
        ),
      );
      if (restart != true) return;
    }
    ref.read(projectDraftProvider.notifier).reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ObjectTypeScreen(norms: norms)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normsAsync = ref.watch(normsProvider);

    return Scaffold(
      body: SafeArea(
        child: normsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка норм:\n$e')),
          data: (norms) => LayoutBuilder(
            builder: (context, constraints) {
              final minHeight =
                  (constraints.maxHeight - 56).clamp(0.0, double.infinity);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _NeonHero(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: () => _startProject(context, ref, norms),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Начать проект',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProjectsScreen(norms: norms),
                                ),
                              );
                            },
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Мои проекты'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TipsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.menu_book_outlined),
                            label: const Text('Шпаргалка электрика'),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Тёмная «витрина» с неоновым щитом. Тёмный фон задаётся намеренно:
/// неон рассчитан на контраст, на белом он выцветает.
class _NeonHero extends StatelessWidget {
  const _NeonHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 246,
          height: 246 * 1.1,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF07090C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF27E0C8).withValues(alpha: 0.22),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF27E0C8).withValues(alpha: 0.16),
                blurRadius: 34,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const PanelVariant(
            style: PanelStyle.neon,
            width: 246,
            animate: true,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'Электрощит',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            'Посчитайте щит за пару минут',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
