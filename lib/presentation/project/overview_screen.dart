import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'rooms_flow_screen.dart';
import 'room_wizard_screen.dart';
import '../result/result_screen.dart';

class OverviewScreen extends StatefulWidget {
  final core.NormsCatalog norms;
  final core.ObjectType objectType;
  final core.PhaseSystem phaseSystem;
  final List<RoomDraft> rooms;
  final int lightingLines;
  final int socketLines;
  final double allowedPowerKw;
  final int inputBreakerAmps;

  const OverviewScreen({
    super.key,
    required this.norms,
    required this.objectType,
    required this.phaseSystem,
    required this.rooms,
    required this.lightingLines,
    required this.socketLines,
    required this.allowedPowerKw,
    required this.inputBreakerAmps,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late List<RoomDraft> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = List.of(widget.rooms);
  }

  Future<void> _editRoom(int index) async {
    final updated = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(
        builder: (_) => RoomWizardScreen(existing: _rooms[index]),
      ),
    );
    if (updated != null) {
      setState(() => _rooms[index] = updated);
    }
  }

  void _calculate() {
    final now = DateTime.now();
    var cid = 1;

    final rooms = _rooms.map((d) {
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

      d.dedicatedSockets.forEach((type, qty) {
        for (var i = 0; i < qty; i++) {
          consumers.add(
            core.Consumer(
              id: 'c_${cid++}',
              type: type,
              name: _dedicatedName(type),
              quantity: 1,
              powerKw: _defaultPower(type),
              isPowerful: true,
              requiresRcd: true,
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

    final project = core.Project(
      id: 'p_${now.millisecondsSinceEpoch}',
      name: widget.objectType == core.ObjectType.apartment ? 'Квартира' : 'Дом',
      objectType: widget.objectType,
      phaseSystem: widget.phaseSystem,
      allowedPowerKw: widget.allowedPowerKw,
      groundingSystem: core.GroundingSystem.tnCs,
      totalArea: 50,
      ceilingHeight: 2.7,
      lightingGrouping: widget.lightingLines <= 1
          ? core.LightingGrouping.singleLine
          : (widget.lightingLines == 2
                ? core.LightingGrouping.twoZones
                : core.LightingGrouping.perRoom),
      createdAt: now,
      updatedAt: now,
      rooms: rooms,
    );

    final result = core.CircuitCalculator(widget.norms).calculate(
      project,
      inputBreakerAmps: widget.inputBreakerAmps,
      lightingLines: widget.lightingLines,
      socketLines: widget.socketLines,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: result, projectName: project.name),
      ),
    );
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

  double _defaultPower(core.ConsumerType t) {
    switch (t) {
      case core.ConsumerType.electricStove:
        return 7.0;
      case core.ConsumerType.oven:
        return 3.5;
      case core.ConsumerType.washingMachine:
      case core.ConsumerType.dishwasher:
      case core.ConsumerType.waterHeater:
      case core.ConsumerType.boiler:
        return 2.0;
      case core.ConsumerType.airConditioner:
        return 2.5;
      case core.ConsumerType.underfloorHeating:
        return 1.5;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обзор')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        itemCount: _rooms.length,
        itemBuilder: (context, i) {
          final r = _rooms[i];
          return InkWell(
            onTap: () => _editRoom(i),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
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
                    const Spacer(),
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
                    if (r.mirrorSockets > 0)
                      Text(
                        'Зеркало: ${r.mirrorSockets}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (r.dedicatedSockets.isNotEmpty)
                      Text(
                        'Силовые: ${r.dedicatedSockets.values.fold(0, (a, b) => a + b)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
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
            onPressed: _calculate,
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
