import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  testWidgets('renders the desktop editor shell', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_createTestApp());
    await tester.pump();

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
      EditorCommandId.openMap: (_) {
        openMapInvocations++;
      },
    });

    await tester.pumpWidget(_createTestApp(dispatcher: dispatcher));
    await tester.tap(find.byKey(const Key('toolbar-open-map')));
    await tester.pump();

    expect(openMapInvocations, 1);
  });

  testWidgets('reopens and removes a recent map', (tester) async {
    final settingsStore = InMemorySettingsStore();
    final recentProjectsService = RecentProjectsService(settingsStore);
    await recentProjectsService.recordOpened(
      r'C:\Maps\Arena.scx',
      openedAt: DateTime(2026, 7, 26, 12, 30),
    );
    Object? openedPath;
    final dispatcher = EditorCommandDispatcher({
      EditorCommandId.openMap: (argument) {
        openedPath = argument;
      },
    });

    await tester.pumpWidget(
      _createTestApp(
        dispatcher: dispatcher,
        recentProjectsService: recentProjectsService,
        settingsStore: settingsStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arena.scx'), findsOneWidget);
    final recentProject = find.byKey(
      const ValueKey(r'recent-project-C:\Maps\Arena.scx'),
    );
    await tester.ensureVisible(recentProject);
    await tester.pumpAndSettle();
    await tester.tap(recentProject);
    await tester.pump();
    expect(openedPath, r'C:\Maps\Arena.scx');

    final removeRecentProject = find.byKey(
      const ValueKey(r'remove-recent-project-C:\Maps\Arena.scx'),
    );
    await tester.ensureVisible(removeRecentProject);
    await tester.tap(removeRecentProject);
    await tester.pumpAndSettle();
    expect(find.text('Arena.scx'), findsNothing);
  });

  testWidgets('shows active operation progress', (tester) async {
    final progressController = OperationProgressController()
      ..start(operationId: 'open-map', label: 'Opening map', canCancel: true)
      ..update(
        operationId: 'open-map',
        phase: OperationPhase.reading,
        message: 'Reading map archive',
        fraction: 0.25,
      );
    addTearDown(progressController.dispose);

    await tester.pumpWidget(
      _createTestApp(operationProgressController: progressController),
    );
    await tester.pump();

    expect(find.text('Opening map'), findsOneWidget);
    expect(find.text('Reading map archive'), findsWidgets);
    expect(find.text('25%'), findsWidgets);
  });
}

Widget _createTestApp({
  EditorCommandDispatcher? dispatcher,
  OperationProgressController? operationProgressController,
  RecentProjectsService? recentProjectsService,
  InMemorySettingsStore? settingsStore,
}) {
  final resolvedSettingsStore = settingsStore ?? InMemorySettingsStore();
  return StarCraftMapEditorApp(
    dependencies: EditorAppDependencies(
      commandDispatcher: dispatcher ?? EditorCommandDispatcher(),
      operationProgressController:
          operationProgressController ?? OperationProgressController(),
      recentProjectsService:
          recentProjectsService ?? RecentProjectsService(resolvedSettingsStore),
      settingsStore: resolvedSettingsStore,
    ),
  );
}
