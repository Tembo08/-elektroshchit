import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/data/project_store.dart';

ProjectDraft sampleDraft({String name = 'Квартира, Ленина 5'}) => ProjectDraft(
      name: name,
      objectType: core.ObjectType.privateHouse,
      phaseSystem: core.PhaseSystem.three,
      groundingSystem: core.GroundingSystem.tt,
      allowedPowerKw: 15,
      inputBreakerAmps: 40,
      totalArea: 150,
      ceilingHeight: 2.8,
      lightingLines: 3,
      socketLines: 2,
      rooms: const [
        RoomDraft(
          id: 'r1',
          name: 'Кухня',
          type: core.RoomType.kitchen,
          socketsNormal: 8,
          lights: 3,
          switches: 2,
          mirrorSockets: 1,
          cableLengthM: 18,
          area: 12,
          dedicated: {
            core.ConsumerType.electricStove: ApplianceSpec(
              quantity: 1,
              powerKw: 6.5,
              phases: 1,
            ),
            core.ConsumerType.evCharger: ApplianceSpec(
              quantity: 1,
              powerKw: 11,
              phases: 3,
            ),
          },
        ),
        RoomDraft(
          id: 'r2',
          name: 'Санузел',
          type: core.RoomType.combinedBathroom,
          socketsNormal: 2,
          lights: 1,
          cableLengthM: 12,
          area: 5,
        ),
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('черновик переживает сохранение и загрузку без потерь', () {
    final original = sampleDraft();
    final restored = draftFromJson(draftToJson(original));

    expect(restored.name, original.name);
    expect(restored.objectType, core.ObjectType.privateHouse);
    expect(restored.phaseSystem, core.PhaseSystem.three);
    expect(restored.groundingSystem, core.GroundingSystem.tt);
    expect(restored.allowedPowerKw, 15);
    expect(restored.inputBreakerAmps, 40);
    expect(restored.totalArea, 150);
    expect(restored.ceilingHeight, 2.8);
    expect(restored.lightingLines, 3);
    expect(restored.socketLines, 2);
    expect(restored.rooms.length, 2);

    final kitchen = restored.rooms.first;
    expect(kitchen.name, 'Кухня');
    expect(kitchen.socketsNormal, 8);
    expect(kitchen.mirrorSockets, 1);
    expect(kitchen.cableLengthM, 18);
    expect(kitchen.area, 12);
    expect(
      kitchen.dedicated[core.ConsumerType.electricStove]?.powerKw,
      6.5,
    );
    expect(
      kitchen.dedicated[core.ConsumerType.evCharger]?.phases,
      3,
    );
  });

  test('проект сохраняется, обновляется и читается обратно', () async {
    final store = ProjectStore();
    expect(await store.loadAll(), isEmpty);

    final saved = await store.upsert(
      draft: sampleDraft(),
      now: DateTime(2026, 11, 19, 10),
    );
    expect(saved.name, 'Квартира, Ленина 5');

    var all = await store.loadAll();
    expect(all.length, 1);
    expect(all.first.roomsCount, 2);
    expect(all.first.powerKw, 15);

    // Обновление того же проекта не создаёт второй.
    final updated = await store.upsert(
      draft: sampleDraft(name: 'Дом в Сосновке'),
      id: saved.id,
      now: DateTime(2026, 11, 19, 11),
    );
    all = await store.loadAll();
    expect(all.length, 1);
    expect(all.first.name, 'Дом в Сосновке');
    expect(updated.id, saved.id);
  });

  test('имя по умолчанию, если пользователь не ввёл', () async {
    final store = ProjectStore();
    final saved = await store.upsert(
      draft: sampleDraft(name: '   '),
      now: DateTime(2026, 11, 19),
    );
    expect(saved.name, contains('Проект от'));
  });

  test('копия и удаление', () async {
    final store = ProjectStore();
    final saved = await store.upsert(
      draft: sampleDraft(),
      now: DateTime(2026, 11, 19, 10),
    );

    final copy = await store.duplicate(saved, now: DateTime(2026, 11, 19, 12));
    expect(copy.id, isNot(saved.id));
    expect(copy.name, 'Квартира, Ленина 5 (копия)');
    expect((await store.loadAll()).length, 2);

    await store.delete(saved.id);
    final left = await store.loadAll();
    expect(left.length, 1);
    expect(left.first.id, copy.id);
  });

  test('новые проекты идут первыми в списке', () async {
    final store = ProjectStore();
    await store.upsert(
      draft: sampleDraft(name: 'Старый'),
      now: DateTime(2026, 11, 18),
    );
    await store.upsert(
      draft: sampleDraft(name: 'Новый'),
      now: DateTime(2026, 11, 19),
    );
    final all = await store.loadAll();
    expect(all.first.name, 'Новый');
    expect(all.last.name, 'Старый');
  });

  test('битые данные не роняют список', () async {
    SharedPreferences.setMockInitialValues({
      'saved_projects_v1': 'не json',
    });
    final store = ProjectStore();
    expect(await store.loadAll(), isEmpty);
  });
}
