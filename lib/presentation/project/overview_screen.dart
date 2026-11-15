import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../result/result_screen.dart';
import 'room_wizard_screen.dart';

class OverviewScreen extends ConsumerWidget {
  final core.NormsCatalog norms;

  const OverviewScreen({super.key, required this.norms});

  Future<void> _editRoom(
    BuildContext context,
    WidgetRef ref,
    RoomDraft room,
  ) async {
    final updated = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(
        builder: (_) => RoomWizardScreen(norms: norms, existing: room),
      ),
    );
    if (updated == null) return;
    ref.read(projectDraftProvider.notifier).updateRoom(updated);
  }

  String _dedicatedName(core.ConsumerType t) {
    const m = {
      core.ConsumerType.washingMachine: 'Стиралка',
      core.ConsumerType.dishwasher: 'Посудомойка',
      core.ConsumerType.oven: 'Духовка',
      core.ConsumerType.electricStove: 'Варочная',
      core.ConsumerType.waterHeater: 'Бойлер',
      core.ConsumerType.boiler: 'Котёл',
      core.ConsumerType.airConditioner: 'Кондиционер',
      core.ConsumerType.underfloorHeating: 'Тёплый пол',
      core.ConsumerType.refrigerator: 'Холодильник',
    };
    return m[t] ?? t.name;
  }

  core.Project _buildProject(ProjectDraft draft) {
    final now = DateTime.now();
    var cid = 1;

    final rooms = draft.rooms.map((d) {
      final consumers = <core.Consumer>[];

      if (d.socketsNormal > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетки',
            quantity: d.socketsNormal,
          ),
        );
      }

      if (d.mirrorSockets > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетка у зеркала',
            quantity: d.mirrorSockets,
            requiresRcd: true,
          ),
        );
      }

      d.dedicated.forEach((type, spec) {
        for (var i = 0; i < spec.quantity; i++) {
          consumers.add(
            core.Consumer(
              id: 'c_${cid++}',
              type: type,
              name: _dedicatedName(type),
              quantity: 1,
              // null — калькулятор возьмёт типовую мощность из норм.
              powerKw: spec.powerKw,
              isPowerful: true,
              requiresRcd: true,
              phases: spec.phases,
            ),
          );
        }
      });

      if (d.lights > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: d.lights,
          ),
        );
      }

      if (d.switches > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.switchSingle,
            name: 'Выключатели',
            quantity: d.switches,
          ),
        );
      }

      return core.Room(
        id: d.id,
        name: d.name,
        type: d.type,
        area: 10,
        consumers: consumers,
      );
    }).toList();

    final objectType = draft.objectType ?? core.ObjectType.apartment;
    return core.Project(
      id: 'p_${now.microsecondsSinceEpoch}',
      name: objectType == core.ObjectType.apartment ? 'Квартира' : 'Дом',
      objectType: objectType,
      phaseSystem: draft.phaseSystem,
      allowedPowerKw: draft.allowedPowerKw > 0 ? draft.allowedPowerKw : 10,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 50,
      ceilingHeight: 2.7,
      lightingGrouping: draft.lightingLines <= 1
          ? core.LightingGrouping.singleLine
          : (draft.lightingLines == 2
              ? core.LightingGrouping.twoZones
              : core.LightingGrouping.perRoom),
      createdAt: now,
      updatedAt: now,
      rooms: rooms,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(projectDraftProvider);
    final rooms = draft.rooms;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Обзор')),
      body: rooms.isEmpty
          ? Center(
              child: Text(
                'Добавьте хотя бы одну комнату',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Фиксированная высота: карточки компактные, без пустоты снизу.
                mainAxisExtent: 152,
              ),
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final r = rooms[i];
                return InkWell(
                  onTap: () => _editRoom(context, ref, r),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Розетки: ${r.totalSockets}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            'Лампы: ${r.lights}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            'Выключатели: ${r.switches}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          if (r.dedicatedCount > 0)
                            Text(
                              'Силовые: ${r.dedicatedCount}',
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            'ТУ: ${draft.allowedPowerKw > 0 ? "${draft.allowedPowerKw.toStringAsFixed(0)} кВт" : "не задано"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: rooms.isEmpty
                ? null
                : () {
                    final project = _buildProject(draft);
                    final result = core.CircuitCalculator(norms).calculate(
                      project,
                      inputBreakerAmps: draft.inputBreakerAmps,
                      lightingLines: draft.lightingLines,
                      socketLines: draft.socketLines,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          result: result,
                          projectName: project.name,
                        ),
                      ),
                    );
                  },
            child: const Text(
              'Рассчитать щиток',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ),
      ),
    );
  }
}
