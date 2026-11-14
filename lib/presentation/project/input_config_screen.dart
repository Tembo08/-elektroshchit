import 'package:flutter/material.dart';
import 'package:electrical_core/electrical_core.dart' as core;

import 'rooms_flow_screen.dart';
import 'lines_config_screen.dart';

class InputConfigScreen extends StatefulWidget {
  final core.NormsCatalog norms;
  final core.ObjectType objectType;
  final core.PhaseSystem phaseSystem;
  final List<RoomDraft> rooms;

  const InputConfigScreen({
    super.key,
    required this.norms,
    required this.objectType,
    required this.phaseSystem,
    required this.rooms,
  });

  @override
  State<InputConfigScreen> createState() => _InputConfigScreenState();
}

class _InputConfigScreenState extends State<InputConfigScreen> {
  late TextEditingController _tuController;
  late int _recommendedAmps;
  late int _selectedAmps;
  late String _reason;

  static const _ampsRow = [25, 32, 40, 50, 63];

  static const _markerTypes = {
    core.ConsumerType.electricStove,
    core.ConsumerType.oven,
    core.ConsumerType.airConditioner,
    core.ConsumerType.waterHeater,
    core.ConsumerType.boiler,
    core.ConsumerType.underfloorHeating,
    core.ConsumerType.evCharger,
  };

  @override
  void initState() {
    super.initState();
    _tuController = TextEditingController(); // пусто — пользователь вводит сам
    // Черновая рекомендация до ввода ТУ (от состава комнат)
    final advice = _advise(0);
    _recommendedAmps = advice.$1;
    _reason = advice.$2;
    _selectedAmps = advice.$1;
  }

  void _recalc(double tuKw) {
    final advice = _advise(tuKw);
    setState(() {
      _recommendedAmps = advice.$1;
      _reason = advice.$2;
      _selectedAmps = advice.$1;
    });
  }

  /// (амперы, текст причины)
  (int, String) _advise(double tuKw) {
    final roomCount = widget.rooms.length;
    var markerCount = 0;
    for (final r in widget.rooms) {
      for (final e in r.dedicatedSockets.entries) {
        if (_markerTypes.contains(e.key)) {
          markerCount += e.value;
        }
      }
    }

    // Пока ТУ не введено — показываем только подсказку по составу
    if (tuKw <= 0) {
      final heavy = roomCount >= 5 && markerCount >= 2 || markerCount >= 3;
      if (heavy) {
        return (
          63,
          'ТУ не указано. По составу ($roomCount помещений, '
              '$markerCount силовых) ориентир — 63 А, уточните по ТУ.',
        );
      }
      return (
        40,
        'ТУ не указано. По умолчанию ориентир — 40 А. '
            'Введите мощность из договора, чтобы уточнить.',
      );
    }

    // Ток по ТУ
    final current = widget.phaseSystem == core.PhaseSystem.three
        ? (tuKw * 1000) / (230 * 1.732)
        : (tuKw * 1000) / 230;

    var fromTu = _ampsRow.firstWhere((a) => a >= current, orElse: () => 63);
    if (fromTu < 40) fromTu = 40;

    // Подсказка по составу объекта
    final heavy = roomCount >= 5 && markerCount >= 2 || markerCount >= 3;
    if (heavy && fromTu < 63) {
      return (
        63,
        'Много помещений ($roomCount) и силовых ($markerCount). '
            'Рекомендуем 63 А, уточните мощность по ТУ.',
      );
    }

    return (
      fromTu,
      'По мощности ТУ ${tuKw.toStringAsFixed(0)} кВт '
          '(ток ≈ ${current.toStringAsFixed(0)} А). Помещений: $roomCount, '
          'силовых маркеров: $markerCount.',
    );
  }

  @override
  void dispose() {
    _tuController.dispose();
    super.dispose();
  }

  void _next() {
    final tu = double.tryParse(_tuController.text.replaceAll(',', '.'));
    if (tu == null || tu <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите мощность по ТУ (кВт)')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinesConfigScreen(
          norms: widget.norms,
          objectType: widget.objectType,
          phaseSystem: widget.phaseSystem,
          rooms: widget.rooms,
          allowedPowerKw: tu,
          inputBreakerAmps: _selectedAmps,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ввод и ТУ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Разрешённая мощность по вашим ТУ, кВт',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Не норма ПУЭ. Укажите цифру из договора или технических условий '
            'на присоединение. Ниже — только пример для старта.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tuController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Например, 7',
              helperText:
                  'Пример: 1 фаза часто 5–11 кВт, 3 фазы — 15 кВт и выше',
            ),
            onChanged: (v) {
              final tu = double.tryParse(v.replaceAll(',', '.'));
              if (tu != null && tu > 0) {
                _recalc(tu);
              } else {
                _recalc(0);
              }
            },
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFF007AFF).withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Рекомендуемый вводной автомат: $_recommendedAmps А',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reason,
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Выбор номинала',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _ampsRow.map((a) {
              final selected = _selectedAmps == a;
              return ChoiceChip(
                label: Text('$a А'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedAmps = a),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Номинал вводного автомата — черновой ориентир. '
            'Итоговую схему проверяет квалифицированный электрик.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.35),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _next,
            child: const Text('Далее', style: TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
  }
}
