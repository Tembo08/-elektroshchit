import 'package:electrical_core/electrical_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elektroshchit/core/project_draft.dart';
import 'package:elektroshchit/presentation/projects/projects_screen.dart';

core.NormsCatalog fakeNorms() {
  return core.NormsCatalog(
    version: 'test',
    cableTypeDefault: 'ВВГнг-LS',
    cableSections: const [],
    breakers: const [],
    rcdOptions: const [],
    powerfulTypes: const [],
    lightingTypes: const [],
    socketTypes: const [],
    wetRoomTypes: const [],
    maxSocketsPerGroup: 10,
    maxPowerKwPerSocketGroup: 3.5,
    defaultRcdMa: 30,
    lightingDefaultAmps: 10,
    socketsDefaultAmps: 16,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('пустой список проектов показывает подсказку', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ProjectsScreen(norms: fakeNorms())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Сохранённых проектов пока нет'), findsOneWidget);
  });

  testWidgets('сохранённый проект виден в списке и открывается', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(projectStoreProvider).upsert(
      draft: const ProjectDraft(
        name: 'Дом в Сосновке',
        objectType: core.ObjectType.privateHouse,
        allowedPowerKw: 15,
        rooms: [
          RoomDraft(
            id: 'r1',
            name: 'Кухня',
            type: core.RoomType.kitchen,
            socketsNormal: 6,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ProjectsScreen(norms: fakeNorms())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Дом в Сосновке'), findsOneWidget);
    expect(find.textContaining('1 комн.'), findsOneWidget);
    expect(find.textContaining('15 кВт'), findsOneWidget);

    // Открытие: черновик заменяется проектом.
    await tester.tap(find.text('Дом в Сосновке'));
    await tester.pumpAndSettle();
    final draft = container.read(projectDraftProvider);
    expect(draft.name, 'Дом в Сосновке');
    expect(draft.rooms.length, 1);
  });
}
