import 'enums.dart';
import 'room.dart';
import 'circuit_group.dart';
import 'panel_result.dart';

/// Проект электрощита
class Project {
  final String id;
  final String name;
  final ObjectType objectType;
  final PhaseSystem phaseSystem;
  final double allowedPowerKw;        // Разрешённая мощность по ТУ
  final GroundingSystem groundingSystem;
  final double totalArea;             // м²
  final double ceilingHeight;         // м
  final String normsVersion;          // "ru_2026"
  final LightingGrouping lightingGrouping;
  final List<Room> rooms;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Результаты расчёта (null до первого расчёта)
  final List<CircuitGroup>? circuitGroups;
  final PanelResult? panelResult;
  final List<String>? warnings;

  const Project({
    required this.id,
    required this.name,
    required this.objectType,
    required this.phaseSystem,
    required this.allowedPowerKw,
    required this.groundingSystem,
    required this.totalArea,
    required this.ceilingHeight,
    this.normsVersion = 'ru_2026',
    this.lightingGrouping = LightingGrouping.perRoom,
    this.rooms = const [],
    required this.createdAt,
    required this.updatedAt,
    this.circuitGroups,
    this.panelResult,
    this.warnings,
  });

  Project copyWith({
    String? id,
    String? name,
    ObjectType? objectType,
    PhaseSystem? phaseSystem,
    double? allowedPowerKw,
    GroundingSystem? groundingSystem,
    double? totalArea,
    double? ceilingHeight,
    String? normsVersion,
    LightingGrouping? lightingGrouping,
    List<Room>? rooms,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CircuitGroup>? circuitGroups,
    PanelResult? panelResult,
    List<String>? warnings,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      objectType: objectType ?? this.objectType,
      phaseSystem: phaseSystem ?? this.phaseSystem,
      allowedPowerKw: allowedPowerKw ?? this.allowedPowerKw,
      groundingSystem: groundingSystem ?? this.groundingSystem,
      totalArea: totalArea ?? this.totalArea,
      ceilingHeight: ceilingHeight ?? this.ceilingHeight,
      normsVersion: normsVersion ?? this.normsVersion,
      lightingGrouping: lightingGrouping ?? this.lightingGrouping,
      rooms: rooms ?? this.rooms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      circuitGroups: circuitGroups ?? this.circuitGroups,
      panelResult: panelResult ?? this.panelResult,
      warnings: warnings ?? this.warnings,
    );
  }
}
