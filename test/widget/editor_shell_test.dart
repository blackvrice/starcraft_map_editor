import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  testWidgets('renders the desktop editor shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_createTestApp());

    expect(find.byKey(const Key('editor-shell')), findsOneWidget);
    expect(find.byKey(const Key('map-workspace')), findsOneWidget);
    expect(find.text('StarCraft Map Editor'), findsOneWidget);
    expect(find.text('Project / Layers'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.text('Problems'), findsOneWidget);
    expect(find.text('Open a map to begin'), findsOneWidget);
    expect(find.text('Windows • SC:R'), findsOneWidget);
  });

  testWidgets('routes toolbar commands through the dispatcher', (tester) async {
    var openMapInvocations = 0;
    final dispatcher = EditorCommandDispatcher({
      EditorCommandId.openMap: () {
        openMapInvocations++;
      },
    });

    await tester.pumpWidget(_createTestApp(dispatcher));
    await tester.tap(find.byKey(const Key('toolbar-open-map')));
    await tester.pump();

    expect(openMapInvocations, 1);
  });
}

Widget _createTestApp([EditorCommandDispatcher? dispatcher]) {
  return StarCraftMapEditorApp(
    dependencies: EditorAppDependencies(
      commandDispatcher: dispatcher ?? EditorCommandDispatcher(),
      settingsStore: InMemorySettingsStore(),
    ),
  );
}
