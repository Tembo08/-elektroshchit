import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/project_draft.dart';
import '../../plan/plan_geometry.dart';
import '../../plan/plan_models.dart';
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
      core.ConsumerType.evCharger: 'Зарядка электромобиля',
    };
    return m[t] ?? t.name;
  }

  /// Данные из плана: длина трассы и число точек по комнате.
  ///
  /// План опционален: если его нет или комната не найдена, остаются
  /// значения, введённые руками в визарде.
  ({double lengthM, int? sockets, int? lights}) _fromPlan(
    FloorPlan? plan,
    RoomDraft room,
  ) {
    if (plan == null) return (lengthM: 0, sockets: null, lights: null);
    final planRoom =
        plan.rooms.where((r) => r.name.trim() == room.name.trim()).firstOrNull;
    if (planRoom == null) return (lengthM: 0, sockets: null, lights: null);
    return (
      lengthM: PlanGeometry.roomLength(plan, planRoom.id),
      sockets: plan.deviceCount(planRoom.id, PlanPointType.socket),
      lights: plan.deviceCount(planRoom.id, PlanPointType.light),
    );
  }

  core.Project _buildProject(ProjectDraft draft) {
    final now = DateTime.now();
    var cid = 1;

    final rooms = draft.rooms.map((d) {
      final consumers = <core.Consumer>[];
      final fromPlan = _fromPlan(draft.plan, d);
      // Число точек с плана важнее ручного ввода: если розетки расставлены,
      // считаем именно их.
      final socketCount = fromPlan.sockets ?? d.socketsNormal;
      final lightCount = fromPlan.lights ?? d.lights;

      if (socketCount > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.socket,
            name: 'Розетки',
            quantity: socketCount,
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

      if (lightCount > 0) {
        consumers.add(
          core.Consumer(
            id: 'c_${cid++}',
            type: core.ConsumerType.lightPoint,
            name: 'Свет',
            quantity: lightCount,
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
        area: d.area > 0
            ? d.area
            : (draft.plan?.rooms
                    .where((r) => r.name.trim() == d.name.trim())
                    .firstOrNull
                    ?.rect
                    .area ??
                0),
        consumers: consumers,
        // Длина из плана (если есть) перекрывает введённую руками.
        cableLengthM: fromPlan.lengthM > 0 ? fromPlan.lengthM : d.cableLengthM,
      );
    }).toList();

    final objectType = draft.objectType ?? core.ObjectType.apartment;
    final fallbackName =
        objectType == core.ObjectType.apartment ? 'Квартира' : 'Дом';
    return core.Project(
      id: 'p_${now.microsecondsSinceEpoch}',
      name: draft.name.trim().isEmpty ? fallbackName : draft.name.trim(),
      objectType: objectType,
      phaseSystem: draft.phaseSystem,
      allowedPowerKw: draft.allowedPowerKw > 0 ? draft.allowedPowerKw : 10,
      groundingSystem: draft.groundingSystem,
      totalArea: draft.totalArea > 0 ? draft.totalArea : 0,
      ceilingHeight: draft.ceilingHeight > 0 ? draft.ceilingHeight : 0,
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

  Widget _roomCard(
    BuildContext context,
    WidgetRef ref,
    RoomDraft r,
    ProjectDraft draft,
    ColorScheme scheme,
  ) {
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 8),
              Text('Розетки: ${r.totalSockets}',
                  style: const TextStyle(fontSize: 14)),
              Text('Лампы: ${r.lights}',
                  style: const TextStyle(fontSize: 14)),
              Text('Выключатели: ${r.switches}',
                  style: const TextStyle(fontSize: 14)),
              if (r.dedicatedCount > 0)
                Text(
                  'Силовые: ${r.dedicatedCount}',
                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
              const SizedBox(height: 10),
              Text(
                draft.allowedPowerKw > 0
                    ? 'ТУ (тех. условия): ${draft.allowedPowerKw.toStringAsFixed(0)} кВт'
                    : 'ТУ (тех. условия): не задано',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
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
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Карточки сами подбирают высоту под содержимое — так нет
                // переполнения при любом числе строк и масштабе шрифта.
                final columns = (constraints.maxWidth / 260).floor().clamp(1, 4);
                final width = (constraints.maxWidth -
                        32 -
                        12 * (columns - 1)) /
                    columns;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final r in rooms)
                        SizedBox(
                          width: width,
                          child: _roomCard(context, ref, r, draft, scheme),
                        ),
                    ],
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
                    final details = <String>[
                      if (project.totalArea > 0)
                        '${project.totalArea.toStringAsFixed(0)} м²',
                      if (project.ceilingHeight > 0)
                        'потолки ${project.ceilingHeight.toStringAsFixed(1)} м',
                      switch (project.groundingSystem) {
                        core.GroundingSystem.tnCs => 'TN-C-S',
                        core.GroundingSystem.tnS => 'TN-S',
                        core.GroundingSystem.tt => 'TT',
                      },
                      'ТУ ${project.allowedPowerKw.toStringAsFixed(0)} кВт',
                    ].join(' · ');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          result: result,
                          projectName: project.name,
                          projectDetails: details,
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
