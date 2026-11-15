import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/providers.dart';
import '../project/object_type_screen.dart';
import 'home_hero_variants.dart';
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
                      const HomeHero(
                        variant: HomeHeroVariant.panel,
                        subtitle: 'Посчитайте щит за пару минут',
                      ),
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
