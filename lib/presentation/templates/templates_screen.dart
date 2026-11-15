import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../core/template_mapper.dart';

/// Готовые шаблоны объектов: студия, 1к, 2к, дом и т.д.
/// Пользователь выбирает заготовку, дальше правит под свой объект.
class TemplatesScreen extends ConsumerWidget {
  final core.NormsCatalog norms;

  const TemplatesScreen({super.key, required this.norms});

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    core.ProjectTemplate template,
  ) async {
    final draft = ref.read(projectDraftProvider);
    if (draft.rooms.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Заменить комнаты?'),
          content: Text(
            'В проекте уже ${draft.rooms.length} комнат. '
            'Шаблон «${template.name}» заменит их.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Заменить'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    final rooms = roomsFromTemplate(template, norms);
    ref.read(projectDraftProvider.notifier).replaceRooms(rooms);
    if (template.suggestedPowerKw > 0) {
      ref.read(projectDraftProvider.notifier).setInput(
            allowedPowerKw: template.suggestedPowerKw,
            breakerAmps: ref.read(projectDraftProvider).inputBreakerAmps,
          );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Шаблон «${template.name}»: ${rooms.length} комнат. '
          'Проверьте и поправьте под объект.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final templates = norms.templates;

    return Scaffold(
      appBar: AppBar(title: const Text('Шаблоны объектов')),
      body: templates.isEmpty
          ? Center(
              child: Text(
                'Шаблоны не загружены',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Заготовка комнат и потребителей. После выбора всё можно '
                  'поправить: шаблон — это старт, а не проект.',
                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final t in templates) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (t.suggestedPowerKw > 0)
                                Text(
                                  '≈ ${t.suggestedPowerKw.toStringAsFixed(0)} кВт',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (t.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              t.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              _chip(context, '${t.rooms.length} комнат'),
                              _chip(context, '${t.totalSockets} розеток'),
                              _chip(context, '${t.totalLights} светильников'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonal(
                              onPressed: () => _apply(context, ref, t),
                              child: const Text('Применить'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
