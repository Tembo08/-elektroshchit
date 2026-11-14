import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'rooms_flow_screen.dart';
import 'overview_screen.dart';

class LinesConfigScreen extends StatefulWidget {
  final core.NormsCatalog norms;
  final core.ObjectType objectType;
  final core.PhaseSystem phaseSystem;
  final List<RoomDraft> rooms;
  final double allowedPowerKw;
  final int inputBreakerAmps;

  const LinesConfigScreen({
    super.key,
    required this.norms,
    required this.objectType,
    required this.phaseSystem,
    required this.rooms,
    required this.allowedPowerKw,
    required this.inputBreakerAmps,
  });

  @override
  State<LinesConfigScreen> createState() => _LinesConfigScreenState();
}

class _LinesConfigScreenState extends State<LinesConfigScreen> {
  int _lightingLines = 2;
  int _socketLines = 2;

  int get _dedicatedCount {
    var n = 0;
    for (final r in widget.rooms) {
      for (final q in r.dedicatedSockets.values) {
        n += q;
      }
    }
    return n;
  }

  int get _normalSockets {
    return widget.rooms.fold(0, (s, r) => s + r.socketsNormal);
  }

  int get _lights {
    return widget.rooms.fold(0, (s, r) => s + r.lights);
  }

  Widget _stepper({
    required String title,
    required String subtitle,
    required int value,
    required ValueChanged<int> onChanged,
    int min = 1,
    int max = 10,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Линии')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Обычных розеток: $_normalSockets · Ламп: $_lights\n'
            'Отдельных силовых (стиралка, варочная и т.д.): $_dedicatedCount',
            style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          _stepper(
            title: 'Линии освещения',
            subtitle: 'На всю квартиру / дом (не по комнатам)',
            value: _lightingLines,
            onChanged: (v) => setState(() => _lightingLines = v),
          ),
          const SizedBox(height: 12),
          _stepper(
            title: 'Линии розеток',
            subtitle: 'Только обычные розетки. Силовые — всегда отдельно.',
            value: _socketLines,
            onChanged: (v) => setState(() => _socketLines = v),
          ),
          const SizedBox(height: 16),
          const Text(
            'Варочная, бойлер, котёл, стиралка, посудомойка, кондиционер, '
            'тёплый пол — отдельные линии, их число задавать не нужно.',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.35),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
builder: (_) => OverviewScreen(
                    norms: widget.norms,
                    objectType: widget.objectType,
                    phaseSystem: widget.phaseSystem,
                    rooms: widget.rooms,
                    lightingLines: _lightingLines,
                    socketLines: _socketLines,
                    allowedPowerKw: widget.allowedPowerKw,
                    inputBreakerAmps: widget.inputBreakerAmps,
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
