import 'dart:convert';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/project_draft.dart';

/// Сохранённый проект: черновик + метаданные для списка.
class SavedProject {
  final String id;
  final String name;
  final DateTime updatedAt;
  final ProjectDraft draft;

  const SavedProject({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.draft,
  });

  int get roomsCount => draft.rooms.length;
  double get powerKw => draft.allowedPowerKw;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'updatedAt': updatedAt.toIso8601String(),
        'draft': draftToJson(draft),
      };

  static SavedProject fromJson(Map<String, dynamic> json) => SavedProject(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Проект',
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        draft: draftFromJson(
          Map<String, dynamic>.from(json['draft'] as Map? ?? const {}),
        ),
      );
}

/// Сериализация черновика. Отдельной функцией, чтобы тесты проверяли
/// круговой обход без хранилища.
Map<String, dynamic> draftToJson(ProjectDraft d) => {
      'name': d.name,
      'objectType': d.objectType?.name,
      'phaseSystem': d.phaseSystem.name,
      'grounding': d.groundingSystem.name,
      'allowedPowerKw': d.allowedPowerKw,
      'inputBreakerAmps': d.inputBreakerAmps,
      'totalArea': d.totalArea,
      'ceilingHeight': d.ceilingHeight,
      'lightingLines': d.lightingLines,
      'socketLines': d.socketLines,
      'rooms': [
        for (final r in d.rooms)
          {
            'id': r.id,
            'name': r.name,
            'type': r.type.name,
            'socketsNormal': r.socketsNormal,
            'lights': r.lights,
            'switches': r.switches,
            'mirrorSockets': r.mirrorSockets,
            'cableLengthM': r.cableLengthM,
            'area': r.area,
            'dedicated': {
              for (final e in r.dedicated.entries)
                e.key.name: {
                  'quantity': e.value.quantity,
                  'powerKw': e.value.powerKw,
                  'phases': e.value.phases,
                },
            },
          },
      ],
    };

ProjectDraft draftFromJson(Map<String, dynamic> json) {
  core.ObjectType? objectType;
  final objectTypeName = json['objectType'] as String?;
  if (objectTypeName != null) {
    for (final t in core.ObjectType.values) {
      if (t.name == objectTypeName) objectType = t;
    }
  }

  core.PhaseSystem phase = core.PhaseSystem.single;
  for (final p in core.PhaseSystem.values) {
    if (p.name == json['phaseSystem']) phase = p;
  }

  var grounding = core.GroundingSystem.tnCs;
  for (final g in core.GroundingSystem.values) {
    if (g.name == json['grounding']) grounding = g;
  }

  final roomsJson = (json['rooms'] as List?) ?? const [];
  final rooms = <RoomDraft>[];
  for (final item in roomsJson) {
    final m = Map<String, dynamic>.from(item as Map);
    var type = core.RoomType.other;
    for (final t in core.RoomType.values) {
      if (t.name == m['type']) type = t;
    }

    final dedicated = <core.ConsumerType, ApplianceSpec>{};
    final dedicatedJson = (m['dedicated'] as Map?) ?? const {};
    for (final entry in dedicatedJson.entries) {
      core.ConsumerType? consumerType;
      for (final t in core.ConsumerType.values) {
        if (t.name == entry.key) consumerType = t;
      }
      if (consumerType == null) continue;
      final spec = Map<String, dynamic>.from(entry.value as Map);
      dedicated[consumerType] = ApplianceSpec(
        quantity: (spec['quantity'] as num?)?.toInt() ?? 1,
        powerKw: (spec['powerKw'] as num?)?.toDouble(),
        phases: (spec['phases'] as num?)?.toInt() ?? 1,
      );
    }

    rooms.add(
      RoomDraft(
        id: m['id'] as String? ?? 'r_${rooms.length}',
        name: m['name'] as String? ?? 'Комната',
        type: type,
        socketsNormal: (m['socketsNormal'] as num?)?.toInt() ?? 0,
        lights: (m['lights'] as num?)?.toInt() ?? 0,
        switches: (m['switches'] as num?)?.toInt() ?? 0,
        mirrorSockets: (m['mirrorSockets'] as num?)?.toInt() ?? 0,
        cableLengthM: (m['cableLengthM'] as num?)?.toDouble() ?? 0,
        area: (m['area'] as num?)?.toDouble() ?? 0,
        dedicated: dedicated,
      ),
    );
  }

  return ProjectDraft(
    name: json['name'] as String? ?? '',
    objectType: objectType,
    phaseSystem: phase,
    groundingSystem: grounding,
    allowedPowerKw: (json['allowedPowerKw'] as num?)?.toDouble() ?? 0,
    inputBreakerAmps: (json['inputBreakerAmps'] as num?)?.toInt(),
    totalArea: (json['totalArea'] as num?)?.toDouble() ?? 0,
    ceilingHeight: (json['ceilingHeight'] as num?)?.toDouble() ?? 0,
    lightingLines: (json['lightingLines'] as num?)?.toInt() ?? 2,
    socketLines: (json['socketLines'] as num?)?.toInt() ?? 2,
    rooms: rooms,
  );
}

/// Хранилище проектов: JSON-массив в SharedPreferences.
/// Для десятков проектов этого достаточно, а база данных тут лишняя.
class ProjectStore {
  static const _key = 'saved_projects_v1';

  Future<List<SavedProject>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final projects = list
          .map((e) => SavedProject.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (_) {
      // Битые данные не должны ронять приложение: считаем, что проектов нет.
      return [];
    }
  }

  Future<void> saveAll(List<SavedProject> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([for (final p in projects) p.toJson()]);
    await prefs.setString(_key, raw);
  }

  /// Сохраняет или обновляет проект по id.
  Future<SavedProject> upsert({
    required ProjectDraft draft,
    String? id,
    DateTime? now,
  }) async {
    final projects = await loadAll();
    final stamp = now ?? DateTime.now();
    final projectId = id ?? 'pr_${stamp.microsecondsSinceEpoch}';
    final name = draft.name.trim().isEmpty
        ? 'Проект от ${stamp.day}.${stamp.month}.${stamp.year}'
        : draft.name.trim();

    final saved = SavedProject(
      id: projectId,
      name: name,
      updatedAt: stamp,
      draft: draft,
    );

    final index = projects.indexWhere((p) => p.id == projectId);
    if (index >= 0) {
      projects[index] = saved;
    } else {
      projects.insert(0, saved);
    }
    await saveAll(projects);
    return saved;
  }

  Future<void> delete(String id) async {
    final projects = await loadAll();
    projects.removeWhere((p) => p.id == id);
    await saveAll(projects);
  }

  Future<SavedProject> duplicate(SavedProject source, {DateTime? now}) async {
    final projects = await loadAll();
    final stamp = now ?? DateTime.now();
    final copy = SavedProject(
      id: 'pr_${stamp.microsecondsSinceEpoch}',
      name: '${source.name} (копия)',
      updatedAt: stamp,
      draft: source.draft.copyWith(
        name: '${source.name} (копия)',
      ),
    );
    projects.insert(0, copy);
    await saveAll(projects);
    return copy;
  }

  Future<SavedProject?> find(String id) async {
    final projects = await loadAll();
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }
}
