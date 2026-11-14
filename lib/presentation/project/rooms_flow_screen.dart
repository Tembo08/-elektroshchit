import 'input_config_screen.dart';
import 'room_wizard_screen.dart';

import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

/// Черновик комнаты в новом потоке
class RoomDraft {
  final String id;
  final String name;
  final core.RoomType type;
  final int socketsNormal;
  final int lights;
  final int switches;
  final int mirrorSockets;
  final Map<core.ConsumerType, int> dedicatedSockets;

  const RoomDraft({
    required this.id,
    required this.name,
    required this.type,
    this.socketsNormal = 0,
    this.lights = 0,
    this.switches = 0,
    this.mirrorSockets = 0,
    this.dedicatedSockets = const {},
  });

  int get totalSockets {
    final dedicated = dedicatedSockets.values.fold(0, (a, b) => a + b);
    return socketsNormal + dedicated + mirrorSockets;
  }
}

class RoomsFlowScreen extends StatefulWidget {
  final core.NormsCatalog norms;
  final core.ObjectType objectType;
  final core.PhaseSystem phaseSystem;

  const RoomsFlowScreen({
    super.key,
    required this.norms,
    required this.objectType,
    required this.phaseSystem,
  });

  @override
  State<RoomsFlowScreen> createState() => _RoomsFlowScreenState();
}

class _RoomsFlowScreenState extends State<RoomsFlowScreen> {
  final List<RoomDraft> _rooms = [];

  Future<void> _addRoom() async {
    final draft = await Navigator.of(context).push<RoomDraft>(
      MaterialPageRoute(builder: (_) => const RoomWizardScreen()),
    );
    if (draft == null) return;
    setState(() => _rooms.add(draft));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Комнаты')),
      body: _rooms.isEmpty
          ? const Center(
              child: Text(
                'Добавьте комнаты',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rooms.length,
              itemBuilder: (context, i) {
                final r = _rooms[i];
                return Card(
                  child: ListTile(
                    title: Text(r.name, style: const TextStyle(fontSize: 17)),
                    subtitle: Text(
                      'Розетки: ${r.totalSockets} · Лампы: ${r.lights} · '
                      'Выключатели: ${r.switches}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    onTap: () async {
                      final updated = await Navigator.of(context)
                          .push<RoomDraft>(
                            MaterialPageRoute(
                              builder: (_) => RoomWizardScreen(existing: r),
                            ),
                          );
                      if (updated != null) {
                        setState(() => _rooms[i] = updated);
                      }
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _rooms.removeAt(i)),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRoom,
        icon: const Icon(Icons.add),
        label: const Text('Комната'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _rooms.isEmpty
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InputConfigScreen(
                          norms: widget.norms,
                          objectType: widget.objectType,
                          phaseSystem: widget.phaseSystem,
                          rooms: List.of(_rooms),
                        ),
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
