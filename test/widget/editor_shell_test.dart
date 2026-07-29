import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/directory_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';

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
    expect(find.byKey(const Key('output-tab-problems')), findsOneWidget);
    expect(find.text('Open a map to begin'), findsOneWidget);
    expect(find.text('Windows • SC:R • Assets not configured'), findsOneWidget);
  });

  testWidgets('configures StarCraft assets and exposes missing diagnostics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final settings = InMemorySettingsStore();
    final assetController = StarCraftDataAssetSettingsController(
      settingsStore: settings,
      directoryPicker: const _FakeDirectoryPicker(
        r'C:\Program Files (x86)\StarCraft',
      ),
      inspector: const _FakeStarCraftDataAssetInspector(ready: false),
    );
    addTearDown(assetController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        settingsStore: settings,
        starCraftDataAssetSettingsController: assetController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('starcraft-asset-environment-status')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('starcraft-asset-settings-dialog')),
      findsOneWidget,
    );
    expect(find.text('Not configured'), findsOneWidget);

    await tester.tap(find.byKey(const Key('starcraft-assets-choose')));
    await tester.pumpAndSettle();

    expect(find.text(r'C:\Program Files (x86)\StarCraft'), findsOneWidget);
    expect(find.text('39/40 required assets found'), findsOneWidget);
    expect(
      find.byKey(const Key('starcraft-assets-casc-metadata')),
      findsOneWidget,
    );
    expect(find.text(r'tileset\badlands.cv5'), findsOneWidget);
    expect(
      await settings.readString(
        StarCraftDataAssetSettingsController.settingsKey,
      ),
      r'C:\Program Files (x86)\StarCraft',
    );

    await tester.tap(find.byKey(const Key('starcraft-assets-close')));
    await tester.pumpAndSettle();
    expect(find.text('SC:R • Missing'), findsOneWidget);
    await tester.tap(find.byKey(const Key('output-tab-problems')));
    await tester.pump();
    expect(
      find.text(StarCraftDataAssetDiagnosticCodes.filesMissing),
      findsOneWidget,
    );
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

  testWidgets('keeps EUD build disabled until a request is prepared', (
    tester,
  ) async {
    await tester.pumpWidget(_createTestApp());
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const Key('toolbar-build-eud')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('output-tab-build-log')));
    await tester.pump();
    expect(find.text('Build settings are not ready'), findsOneWidget);
  });

  testWidgets('runs an EUD build and displays raw build output', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final progressController = OperationProgressController();
    final buildController = EudBuildController(
      buildGateway: _ScriptedEudCompilerGateway(),
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    )..prepare(_eudBuildRequest('widget-build'));
    addTearDown(buildController.dispose);
    addTearDown(progressController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        eudBuildController: buildController,
        operationProgressController: progressController,
      ),
    );
    await tester.tap(find.byKey(const Key('toolbar-build-eud')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('eud-build-log')), findsOneWidget);
    expect(find.text('Tool: euddraft 0.10.2.5'), findsOneWidget);
    expect(find.text('Succeeded • exit code 0'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('eud-build-log')),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(find.text('[stdout] Compiling main.eps'), findsOneWidget);
    expect(find.text('[stderr] Test warning'), findsOneWidget);
  });

  testWidgets('replaces Build with Cancel while euddraft is running', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final progressController = OperationProgressController();
    final gateway = _CancellableEudCompilerGateway();
    final buildController = EudBuildController(
      buildGateway: gateway,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    )..prepare(_eudBuildRequest('widget-cancel'));
    addTearDown(buildController.dispose);
    addTearDown(progressController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        eudBuildController: buildController,
        operationProgressController: progressController,
      ),
    );
    await tester.tap(find.byKey(const Key('toolbar-build-eud')));
    await tester.pump();

    expect(find.byKey(const Key('toolbar-cancel-eud-build')), findsOneWidget);
    await tester.tap(find.byKey(const Key('toolbar-cancel-eud-build')));
    await tester.pumpAndSettle();

    expect(gateway.cancelledBuildId, 'widget-cancel');
    expect(find.byKey(const Key('toolbar-build-eud')), findsOneWidget);
    expect(find.text('Cancelled • exit code unavailable'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('eud-build-log')),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(
      find.text('[EUD_TEST_CANCELLED] Test build cancelled.'),
      findsOneWidget,
    );
  });

  testWidgets('shows parsed euddraft source locations in log and problems', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final progressController = OperationProgressController();
    final buildController = EudBuildController(
      buildGateway: _DiagnosticEudCompilerGateway(),
      diagnosticParser: const EuddraftDiagnosticParser(),
      operationProgressController: progressController,
    )..prepare(_eudBuildRequest('widget-diagnostic'));
    addTearDown(buildController.dispose);
    addTearDown(progressController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        eudBuildController: buildController,
        operationProgressController: progressController,
      ),
    );
    await tester.tap(find.byKey(const Key('toolbar-build-eud')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('eud-build-log')),
      const Offset(0, -160),
    );
    await tester.pump();
    expect(
      find.text(
        '[EUD_EPSCRIPT_ERROR_7041] '
        'main.eps:14: Undefined function SpawnBoss',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('output-tab-problems')));
    await tester.pump();
    expect(find.text('EUD_EPSCRIPT_ERROR_7041'), findsOneWidget);
    expect(find.text('Undefined function SpawnBoss'), findsOneWidget);
    expect(find.text('main.eps:14'), findsOneWidget);
    expect(find.text('helpers.py:8:5'), findsOneWidget);
  });

  testWidgets('edits epScript and displays its dirty state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final sourceController = EudSourceController();
    addTearDown(sourceController.dispose);

    await tester.pumpWidget(
      _createTestApp(eudSourceController: sourceController),
    );
    await tester.tap(find.byKey(const Key('toolbar-new-eud-source')));
    await tester.pump();

    expect(find.byKey(const Key('eud-source-workspace')), findsOneWidget);
    expect(find.byKey(const Key('eud-source-editor')), findsOneWidget);
    expect(find.text('main.eps'), findsWidgets);
    expect(find.text('Clean'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('eud-source-editor')),
      'function onPluginStart() {\n  // ready\n}\n',
    );
    await tester.pump();

    expect(sourceController.state.document!.isDirty, isTrue);
    expect(sourceController.state.document!.revision, 1);
    expect(find.text('Modified'), findsWidgets);
    expect(find.text('main.eps •'), findsWidgets);
    expect(find.text('main.eps • Modified'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
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

  testWidgets('opens a selected map and renders its map canvas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final settingsStore = InMemorySettingsStore();
    final recentProjectsService = RecentProjectsService(settingsStore);
    final progressController = OperationProgressController();
    final extractedMap = _createExtractedMap();
    final openMapController = OpenMapController(
      archiveGateway: _FakeMapArchiveGateway(
        MapArchiveOpenResult.success(map: extractedMap),
      ),
      filePicker: _FakeMapFilePicker(extractedMap.sourcePath),
      fingerprintGateway: _FakeMapFileFingerprintGateway(),
      recentProjectsService: recentProjectsService,
      operationProgressController: progressController,
    );
    addTearDown(openMapController.dispose);
    addTearDown(progressController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        openMapController: openMapController,
        operationProgressController: progressController,
        recentProjectsService: recentProjectsService,
        settingsStore: settingsStore,
      ),
    );
    await tester.tap(find.byKey(const Key('open-map-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('opened-map-name')), findsOneWidget);
    expect(find.byKey(const Key('map-canvas')), findsOneWidget);
    expect(find.byKey(const Key('map-canvas-visible-region')), findsOneWidget);
    expect(find.byKey(const Key('map-canvas-coordinate')), findsOneWidget);
    expect(find.byKey(const Key('map-canvas-zoom-level')), findsOneWidget);
    expect(find.text('Raw MTXM preview'), findsOneWidget);
    expect(find.text('Tile — · Pixel —'), findsOneWidget);
    expect(find.text('Wheel zoom · Space/middle drag'), findsOneWidget);
    expect(find.text('Arena.scx'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('map-canvas-size')),
        matching: find.text('64 × 96'),
      ),
      findsOneWidget,
    );
    expect(find.text('6'), findsWidgets);
    expect(find.byKey(const Key('archive-entry-list')), findsOneWidget);
    expect(find.byKey(const Key('map-inspector')), findsOneWidget);
    expect(find.text('Read-only preview'), findsWidgets);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('toolbar-save-as')))
          .onPressed,
      isNotNull,
    );
    expect(
      (await recentProjectsService.load()).single.path,
      r'C:\Maps\Arena.scx',
    );

    await tester.tap(find.byKey(const Key('toolbar-new-eud-source')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('eud-source-editor')),
      'const selectedMap = "Arena";\n',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('map-document-tab')));
    await tester.pump();
    expect(find.byKey(const Key('opened-map-name')), findsOneWidget);
    expect(find.byKey(const Key('eud-source-editor')), findsNothing);

    await tester.tap(find.byKey(const Key('eud-source-tab')));
    await tester.pump();
    final sourceEditor = tester.widget<TextField>(
      find.byKey(const Key('eud-source-editor')),
    );
    expect(sourceEditor.controller!.text, 'const selectedMap = "Arena";\n');
  });
}

Widget _createTestApp({
  EditorCommandDispatcher? dispatcher,
  OpenMapController? openMapController,
  SaveMapController? saveMapController,
  EudSourceController? eudSourceController,
  EudBuildController? eudBuildController,
  OperationProgressController? operationProgressController,
  RecentProjectsService? recentProjectsService,
  InMemorySettingsStore? settingsStore,
  StarCraftDataAssetSettingsController? starCraftDataAssetSettingsController,
}) {
  final resolvedSettingsStore = settingsStore ?? InMemorySettingsStore();
  final resolvedProgressController =
      operationProgressController ?? OperationProgressController();
  final resolvedRecentProjectsService =
      recentProjectsService ?? RecentProjectsService(resolvedSettingsStore);
  final resolvedEudSourceController =
      eudSourceController ?? EudSourceController();
  final resolvedEudBuildController =
      eudBuildController ??
      EudBuildController(
        buildGateway: _UnusedEudCompilerGateway(),
        diagnosticParser: const IgnoreEudCompilerDiagnostics(),
        operationProgressController: resolvedProgressController,
      );
  final resolvedFingerprintGateway = _FakeMapFileFingerprintGateway();
  final resolvedOpenMapController =
      openMapController ??
      OpenMapController(
        archiveGateway: _UnusedMapArchiveGateway(),
        filePicker: _FakeMapFilePicker(null),
        fingerprintGateway: resolvedFingerprintGateway,
        recentProjectsService: resolvedRecentProjectsService,
        operationProgressController: resolvedProgressController,
      );
  final resolvedSaveMapController =
      saveMapController ??
      SaveMapController(
        archiveGateway: _UnusedMapArchiveGateway(),
        filePicker: _FakeMapFilePicker(null),
        fingerprintGateway: resolvedFingerprintGateway,
        saveFileGateway: _UnusedMapSaveFileGateway(),
        openMapController: resolvedOpenMapController,
        operationProgressController: resolvedProgressController,
      );
  final resolvedDispatcher =
      dispatcher ??
      EditorCommandDispatcher({
        EditorCommandId.openMap: (argument) async {
          await resolvedOpenMapController.open(
            sourcePath: argument is String ? argument : null,
          );
        },
        EditorCommandId.saveAs: (_) async {
          await resolvedSaveMapController.saveAs();
        },
        EditorCommandId.newEudSource: (_) {
          resolvedEudSourceController.createUntitled();
        },
        EditorCommandId.buildEud: (_) async {
          await resolvedEudBuildController.start();
        },
        EditorCommandId.cancelEudBuild: (_) async {
          await resolvedEudBuildController.cancel();
        },
      });
  final resolvedStarCraftDataAssetSettingsController =
      starCraftDataAssetSettingsController ??
      StarCraftDataAssetSettingsController(
        settingsStore: resolvedSettingsStore,
        directoryPicker: const _FakeDirectoryPicker(),
        inspector: const _FakeStarCraftDataAssetInspector(),
      );
  return StarCraftMapEditorApp(
    dependencies: EditorAppDependencies(
      commandDispatcher: resolvedDispatcher,
      openMapController: resolvedOpenMapController,
      saveMapController: resolvedSaveMapController,
      eudBuildController: resolvedEudBuildController,
      eudSourceController: resolvedEudSourceController,
      operationProgressController: resolvedProgressController,
      recentProjectsService: resolvedRecentProjectsService,
      settingsStore: resolvedSettingsStore,
      starCraftDataAssetSettingsController:
          resolvedStarCraftDataAssetSettingsController,
    ),
  );
}

EudBuildPlan _eudBuildRequest(String buildId) {
  return EudBuildPlan(
    buildId: buildId,
    configuration: EudBuildConfiguration(
      baseMapPath: r'C:\Project\base\Base.scx',
      sourceRootPath: r'C:\Project\src',
      entrySourcePath: r'C:\Project\src\main.eps',
      outputMapPath: r'C:\Project\build\Output.scx',
    ),
    tool: EudToolInfo(
      pathSource: EudToolPathSource.projectProfile,
      installationPath: r'C:\Tools\euddraft',
      executablePath: r'C:\Tools\euddraft\euddraft.exe',
      versionFilePath: r'C:\Tools\euddraft\VERSION',
      version: EudToolVersion.parse('0.10.2.5'),
      companionPaths: const [r'C:\Tools\euddraft\python3.dll'],
    ),
    timeout: const Duration(minutes: 2),
  );
}

final class _FakeDirectoryPicker implements DirectoryPicker {
  const _FakeDirectoryPicker([this.path]);

  final String? path;

  @override
  Future<String?> pickStarCraftInstallationDirectory() async => path;
}

final class _FakeStarCraftDataAssetInspector
    implements StarCraftDataAssetInspector {
  const _FakeStarCraftDataAssetInspector({this.ready = true});

  final bool ready;

  @override
  Future<StarCraftDataAssetInspection> inspect(String installationPath) async {
    if (!ready) {
      return StarCraftDataAssetInspection(
        installationPath: installationPath,
        requiredAssetCount: 40,
        foundAssetCount: 39,
        storageProduct: 's1',
        storageBuildNumber: 13515,
        helperVersion: '0.1.0',
        cascLibRevision: '4971d363e665551ac4142f541e5f2d71f1cda653',
        totalAssetBytes: 1024,
        missingRelativePaths: const [r'tileset\badlands.cv5'],
        diagnostics: const [
          EditorDiagnostic(
            code: StarCraftDataAssetDiagnosticCodes.filesMissing,
            message: 'One required StarCraft tileset asset file is missing.',
            severity: DiagnosticSeverity.warning,
            stage: DiagnosticStage.validate,
          ),
        ],
      );
    }
    return StarCraftDataAssetInspection(
      installationPath: installationPath,
      requiredAssetCount: 0,
      foundAssetCount: 0,
    );
  }
}

final class _UnusedEudCompilerGateway implements EudBuildGateway {
  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) {
    throw StateError('The EUD compiler gateway is not used by this test.');
  }

  @override
  Future<bool> cancel(String buildId) async => false;
}

final class _ScriptedEudCompilerGateway implements EudBuildGateway {
  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) {
    return Stream.fromIterable([
      EudBuildEvent.started(
        buildId: request.buildId,
        toolVersion: request.tool.version,
      ),
      EudBuildEvent.stdoutLine(
        buildId: request.buildId,
        text: 'Compiling main.eps',
      ),
      EudBuildEvent.stderrLine(buildId: request.buildId, text: 'Test warning'),
      EudBuildEvent.finalizing(buildId: request.buildId),
      EudBuildEvent.succeeded(buildId: request.buildId, exitCode: 0),
    ]);
  }

  @override
  Future<bool> cancel(String buildId) async => false;
}

final class _DiagnosticEudCompilerGateway implements EudBuildGateway {
  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) {
    return Stream.fromIterable([
      EudBuildEvent.started(
        buildId: request.buildId,
        toolVersion: request.tool.version,
      ),
      EudBuildEvent.stderrLine(
        buildId: request.buildId,
        text:
            r'[Error 7041] Module "C:\Project\EUD Source\main.eps" '
            'Line 14 : Undefined function SpawnBoss',
      ),
      EudBuildEvent.failed(
        buildId: request.buildId,
        diagnostic: const EditorDiagnostic(
          code: 'EUD_TEST_PYTHON_FAILURE',
          message: 'A Python helper failed.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.compile,
          filePath: r'C:\Project\EUD Source\helpers.py',
          sourceLine: 8,
          sourceColumn: 5,
        ),
        exitCode: 1,
      ),
    ]);
  }

  @override
  Future<bool> cancel(String buildId) async => false;
}

final class _CancellableEudCompilerGateway implements EudBuildGateway {
  final StreamController<EudBuildEvent> _events =
      StreamController<EudBuildEvent>();

  String? cancelledBuildId;

  @override
  Stream<EudBuildEvent> build(EudBuildPlan request) {
    scheduleMicrotask(() {
      _events.add(
        EudBuildEvent.started(
          buildId: request.buildId,
          toolVersion: request.tool.version,
        ),
      );
    });
    return _events.stream;
  }

  @override
  Future<bool> cancel(String buildId) async {
    cancelledBuildId = buildId;
    _events.add(
      EudBuildEvent.cancelled(
        buildId: buildId,
        diagnostic: const EditorDiagnostic(
          code: 'EUD_TEST_CANCELLED',
          message: 'Test build cancelled.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.compile,
        ),
      ),
    );
    await _events.close();
    return true;
  }
}

class _FakeMapFilePicker implements MapFilePicker {
  _FakeMapFilePicker(this.path);

  final String? path;

  @override
  Future<String?> pickMapPath() async => path;

  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      null;
}

class _FakeMapArchiveGateway implements MapArchiveGateway {
  _FakeMapArchiveGateway(this.result);

  final MapArchiveOpenResult result;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    return result;
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

class _UnusedMapArchiveGateway implements MapArchiveGateway {
  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) {
    throw StateError('The archive gateway is not used by this test.');
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request) {
    throw StateError('The archive gateway is not used by this test.');
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

class _UnusedMapSaveFileGateway implements MapSaveFileGateway {
  @override
  Future<void> cleanup(MapSaveWorkspace workspace) async {}

  @override
  Future<MapSaveWorkspace> createWorkspace(String destinationPath) {
    throw StateError('The save file gateway is not used by this test.');
  }

  @override
  Future<bool> destinationExists(String path) async => false;

  @override
  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) {
    throw StateError('The save file gateway is not used by this test.');
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async =>
      false;
}

class _FakeMapFileFingerprintGateway implements MapFileFingerprintGateway {
  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    return MapFileFingerprint(
      sizeBytes: 4096,
      modifiedAt: DateTime.utc(2026, 7, 26, 12),
      sha256Digest:
          '1111111111111111111111111111111111111111111111111111111111111111',
    );
  }
}

ExtractedMap _createExtractedMap() {
  const mapWidth = 64;
  const mapHeight = 96;
  final terrainPayload = Uint8List(mapWidth * mapHeight * 2);
  final terrainData = ByteData.sublistView(terrainPayload);
  for (var index = 0; index < mapWidth * mapHeight; index++) {
    terrainData.setUint16(index * 2, index % 32, Endian.little);
  }
  final chkBytes = _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [mapWidth, 0, mapHeight, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', terrainPayload),
  ]);
  return ExtractedMap(
    sourcePath: r'C:\Maps\Arena.scx',
    scenarioChkBytes: chkBytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: 4096,
      formatVersion: 1,
      totalEntryCount: 1,
      listingComplete: true,
      entries: [
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: chkBytes.length,
          compressedSizeBytes: chkBytes.length,
          flags: 0x80000000,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
    ),
  );
}

Uint8List _section(String name, List<int> payload) {
  final bytes = Uint8List(8 + payload.length);
  bytes.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.little);
  bytes.setRange(8, bytes.length, payload);
  return bytes;
}

Uint8List _chkBytes(List<Uint8List> sections) {
  final builder = BytesBuilder(copy: false);
  for (final section in sections) {
    builder.add(section);
  }
  return builder.takeBytes();
}
