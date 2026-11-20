import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plan/plan_models.dart';

/// Прибор, который ставится на отдельную линию.
class ApplianceSpec {
  final int quantity;

  /// Мощность в кВт. null — берём типовую из норм (`room_defaults.yaml`).
  final double? powerKw;

  /// 1 — однофазный, 3 — трёхфазный.
  final int phases;

  const ApplianceSpec({
    this.quantity = 1,
    this.powerKw,
    this.phases = 1,
  });

  ApplianceSpec copyWith({int? quantity, double? powerKw, int? phases}) {
    return ApplianceSpec(
      quantity: quantity ?? this.quantity,
      powerKw: powerKw ?? this.powerKw,
      phases: phases ?? this.phases,
    );
  }
}

/// Черновик комнаты: то, что пользователь ввёл в визарде.
class RoomDraft {
  final String id;
  final String name;
  final core.RoomType type;
  final int socketsNormal;
  final int lights;
  final int switches;
  final int mirrorSockets;
  final Map<core.ConsumerType, ApplianceSpec> dedicated;

  /// Длина трассы от щита до комнаты, м. 0 — неизвестна.
  final double cableLengthM;

  /// Площадь комнаты, м². 0 — неизвестна.
  final double area;

  const RoomDraft({
    required this.id,
    required this.name,
    required this.type,
    this.socketsNormal = 0,
    this.lights = 0,
    this.switches = 0,
    this.mirrorSockets = 0,
    this.dedicated = const {},
    this.cableLengthM = 0,
    this.area = 0,
  });

  int get totalSockets {
    final dedicatedCount =
        dedicated.values.fold<int>(0, (s, a) => s + a.quantity);
    return socketsNormal + dedicatedCount + mirrorSockets;
  }

  int get dedicatedCount =>
      dedicated.values.fold<int>(0, (s, a) => s + a.quantity);

  RoomDraft copyWith({
    String? name,
    core.RoomType? type,
    int? socketsNormal,
    int? lights,
    int? switches,
    int? mirrorSockets,
    Map<core.ConsumerType, ApplianceSpec>? dedicated,
    double? cableLengthM,
    double? area,
  }) {
    return RoomDraft(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      socketsNormal: socketsNormal ?? this.socketsNormal,
      lights: lights ?? this.lights,
      switches: switches ?? this.switches,
      mirrorSockets: mirrorSockets ?? this.mirrorSockets,
      dedicated: dedicated ?? this.dedicated,
      cableLengthM: cableLengthM ?? this.cableLengthM,
      area: area ?? this.area,
    );
  }
}

/// Черновик всего проекта: живёт в Riverpod, поэтому «назад» ничего не стирает.
class ProjectDraft {
  /// Название объекта — как в договоре («Квартира, Ленина 5»).
  final String name;

  final core.ObjectType? objectType;
  final double totalArea;
  final double ceilingHeight;
  final core.GroundingSystem groundingSystem;

  /// План помещения. null — считаем без плана (длины вводятся руками).
  final FloorPlan? plan;
  final core.PhaseSystem phaseSystem;

  /// Разрешённая мощность по ТУ. 0 — пользователь ещё не ввёл.
  final double allowedPowerKw;

  final int? inputBreakerAmps;
  final int lightingLines;
  final int socketLines;
  final List<RoomDraft> rooms;

  const ProjectDraft({
    this.name = '',
    this.totalArea = 0,
    this.ceilingHeight = 0,
    this.groundingSystem = core.GroundingSystem.tnCs,
    this.plan,
    this.objectType,
    this.phaseSystem = core.PhaseSystem.single,
    this.allowedPowerKw = 0,
    this.inputBreakerAmps,
    this.lightingLines = 2,
    this.socketLines = 2,
    this.rooms = const [],
  });

  bool get hasProject => objectType != null;

  ProjectDraft copyWith({
    String? name,
    core.ObjectType? objectType,
    double? totalArea,
    double? ceilingHeight,
    core.GroundingSystem? groundingSystem,
    FloorPlan? plan,
    core.PhaseSystem? phaseSystem,
    double? allowedPowerKw,
    int? inputBreakerAmps,
    int? lightingLines,
    int? socketLines,
    List<RoomDraft>? rooms,
  }) {
    return ProjectDraft(
      name: name ?? this.name,
      totalArea: totalArea ?? this.totalArea,
      ceilingHeight: ceilingHeight ?? this.ceilingHeight,
      groundingSystem: groundingSystem ?? this.groundingSystem,
      plan: plan ?? this.plan,
      objectType: objectType ?? this.objectType,
      phaseSystem: phaseSystem ?? this.phaseSystem,
      allowedPowerKw: allowedPowerKw ?? this.allowedPowerKw,
      inputBreakerAmps: inputBreakerAmps ?? this.inputBreakerAmps,
      lightingLines: lightingLines ?? this.lightingLines,
      socketLines: socketLines ?? this.socketLines,
      rooms: rooms ?? this.rooms,
    );
  }
}

class ProjectDraftNotifier extends Notifier<ProjectDraft> {
  @override
  ProjectDraft build() => const ProjectDraft();

  void startProject(core.ObjectType type, core.PhaseSystem phases) {
    state = state.copyWith(objectType: type, phaseSystem: phases);
  }

  void addRoom(RoomDraft room) {
    state = state.copyWith(rooms: [...state.rooms, room]);
  }

  void updateRoom(RoomDraft room) {
    state = state.copyWith(
      rooms: [
        for (final r in state.rooms) r.id == room.id ? room : r,
      ],
    );
  }

  void replaceRooms(List<RoomDraft> rooms) {
    state = state.copyWith(rooms: [...rooms]);
  }

  void removeRoom(String id) {
    state = state.copyWith(
      rooms: state.rooms.where((r) => r.id != id).toList(),
    );
  }

  /// Название, площадь, высота потолков и система заземления.
  void setMeta({
    String? name,
    double? totalArea,
    double? ceilingHeight,
    core.GroundingSystem? groundingSystem,
  }) {
    state = state.copyWith(
      name: name,
      totalArea: totalArea,
      ceilingHeight: ceilingHeight,
      groundingSystem: groundingSystem,
    );
  }

  /// План помещения (или null, чтобы вернуться к ручным длинам).
  void setPlan(FloorPlan? plan) => state = state.copyWith(plan: plan);

  void setInput({required double allowedPowerKw, int? breakerAmps}) {
    state = state.copyWith(
      allowedPowerKw: allowedPowerKw,
      inputBreakerAmps: breakerAmps,
    );
  }

  void setLines({int? lightingLines, int? socketLines}) {
    state = state.copyWith(
      lightingLines: lightingLines,
      socketLines: socketLines,
    );
  }

  /// Полностью заменяет черновик (открытие сохранённого проекта).
  void replaceDraft(ProjectDraft draft) => state = draft;

  void reset() => state = const ProjectDraft();
}

final projectDraftProvider =
    NotifierProvider<ProjectDraftNotifier, ProjectDraft>(ProjectDraftNotifier.new);
