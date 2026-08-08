import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_palette_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
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
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_tile_atlas_loader.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture_controller.dart';

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

  testWidgets(
    'renders prepared StarCraft tiles and returns to fallback when assets clear',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const installationPath = r'C:\Program Files (x86)\StarCraft';
      final settingsStore = InMemorySettingsStore({
        StarCraftDataAssetSettingsController.settingsKey: installationPath,
      });
      final assetController = StarCraftDataAssetSettingsController(
        settingsStore: settingsStore,
        directoryPicker: const _FakeDirectoryPicker(),
        inspector: const _RenderableStarCraftDataAssetInspector(),
      );
      final redPixels = Uint8List(32 * 32 * 4);
      for (var offset = 0; offset < redPixels.length; offset += 4) {
        redPixels[offset] = 255;
        redPixels[offset + 3] = 255;
      }
      final ownedTexture = await tester.runAsync(
        () => const UiTerrainTileTextureFactory().create(redPixels),
      );
      expect(ownedTexture, isNotNull);
      final resolvedOwnedTexture = ownedTexture!;
      final textureFactory = _BorrowedTerrainTextureFactory(
        resolvedOwnedTexture.image,
      );
      final atlasGateway = _RenderingStarCraftTileAtlasGateway();
      final textureController = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: atlasGateway),
        textureFactory: textureFactory,
      );

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
      addTearDown(() {
        textureController.dispose();
        resolvedOwnedTexture.dispose();
      });
      addTearDown(assetController.dispose);
      addTearDown(openMapController.dispose);
      addTearDown(progressController.dispose);

      await tester.pumpWidget(
        _createTestApp(
          openMapController: openMapController,
          operationProgressController: progressController,
          recentProjectsService: recentProjectsService,
          settingsStore: settingsStore,
          starCraftDataAssetSettingsController: assetController,
          terrainTileTextureController: textureController,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-map-button')));
      await tester.pumpAndSettle();

      expect(atlasGateway.requests, hasLength(1));
      expect(atlasGateway.requests.single.installationPath, installationPath);
      expect(atlasGateway.requests.single.rawValues, [
        ...List.generate(32, (i) => i),
        0x4000,
      ]);
      expect(textureController.state.status, TerrainTileTextureStatus.ready);
      expect(textureController.state.textures, hasLength(33));
      expect(textureController.state.fallbackRawValues, isEmpty);
      expect(find.text('StarCraft tiles'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('map-canvas-paint')),
                  )
                  .painter!
              as MapCanvasPainter;
      expect(painter.terrainTextures, hasLength(33));

      await assetController.clear();
      await tester.pumpAndSettle();

      expect(textureController.state.status, TerrainTileTextureStatus.idle);
      expect(textureController.state.textures, isEmpty);
      expect(textureFactory.disposedTextures, 33);
      expect(find.text('Raw fallback'), findsOneWidget);
    },
  );

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
    expect(find.text('Raw fallback'), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(const Key('map-inspector')),
        matching: find.text('11'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('map-layer-list')), findsOneWidget);
    expect(find.byKey(const Key('map-inspector')), findsOneWidget);
    expect(find.text('Editable'), findsOneWidget);
    expect(find.byKey(const Key('terrain-editing-toolbar')), findsOneWidget);
    expect(find.text('Select a source tile'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-tool-brush')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-undo')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-redo')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
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

    var canvasPainter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    var canvasTopLeft = tester.getTopLeft(find.byKey(const Key('map-canvas')));
    await tester.tapAt(
      canvasTopLeft +
          canvasPainter.layout.mapRect.topLeft +
          Offset(
            canvasPainter.layout.tileExtent * 1.5,
            canvasPainter.layout.tileExtent * 0.5,
          ),
    );
    await tester.pump();

    expect(
      find.text('Raw tile 16384 · group 1024 · member 0 from 1,0'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-tool-brush')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('terrain-tool-brush')));
    await tester.pump();
    canvasTopLeft = tester.getTopLeft(find.byKey(const Key('map-canvas')));
    canvasPainter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    await tester.tapAt(
      canvasTopLeft +
          canvasPainter.layout.mapRect.topLeft +
          Offset(
            canvasPainter.layout.tileExtent * 2.5,
            canvasPainter.layout.tileExtent * 0.5,
          ),
    );
    await tester.pump();

    expect(
      openMapController.state.session!.terrainViews.tileMaps.single
          .rawTileValueAt(x: 2, y: 0),
      0x4000,
    );
    expect(find.text('Raw fallback'), findsOneWidget);
    expect(openMapController.state.session!.isDirty, isTrue);
    expect(find.text('Modified'), findsWidgets);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-undo')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      openMapController.state.session!.terrainViews.tileMaps.single
          .rawTileValueAt(x: 2, y: 0),
      2,
    );
    expect(find.text('Raw fallback'), findsOneWidget);
    expect(openMapController.state.session!.isDirty, isFalse);
    expect(find.text('Editable'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const Key('terrain-redo')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      openMapController.state.session!.terrainViews.tileMaps.single
          .rawTileValueAt(x: 2, y: 0),
      0x4000,
    );
    expect(find.text('Raw fallback'), findsOneWidget);
    expect(openMapController.state.session!.isDirty, isTrue);
    expect(find.text('Modified'), findsWidgets);

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

  testWidgets('layer controls change selection priority and canvas objects', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final settingsStore = InMemorySettingsStore();
    final recentProjectsService = RecentProjectsService(settingsStore);
    final progressController = OperationProgressController();
    final mapLayerController = MapLayerController();
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
    final objectEditingController = ObjectEditingController(
      openMapController: openMapController,
      mapLayerController: mapLayerController,
    );
    final objectPaletteController = ObjectPaletteController(
      objectEditingController: objectEditingController,
      mapLayerController: mapLayerController,
    );
    addTearDown(openMapController.dispose);
    addTearDown(progressController.dispose);
    addTearDown(mapLayerController.dispose);
    addTearDown(objectEditingController.dispose);
    addTearDown(objectPaletteController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        openMapController: openMapController,
        operationProgressController: progressController,
        recentProjectsService: recentProjectsService,
        settingsStore: settingsStore,
        mapLayerController: mapLayerController,
        objectEditingController: objectEditingController,
        objectPaletteController: objectPaletteController,
      ),
    );
    await tester.tap(find.byKey(const Key('open-map-button')));
    await tester.pumpAndSettle();

    final session = openMapController.state.session!;
    var scene = mapLayerController.sceneFor(session);
    expect(scene.objectCounts[MapLayerType.units], 1);
    expect(scene.objectCounts[MapLayerType.sprites], 1);
    expect(scene.objectCounts[MapLayerType.doodads], 1);
    expect(scene.objectCounts[MapLayerType.locations], 1);

    await tester.tap(find.byKey(const Key('map-layer-units')));
    await tester.pump();
    expect(mapLayerController.state.activeLayer, MapLayerType.units);
    expect(
      find.text('Pick Units → Sprites → Doodads → Locations → Terrain'),
      findsOneWidget,
    );

    await _tapMapPixel(tester, pixelX: 64, pixelY: 64);
    expect(
      mapLayerController.state.selection?.object.layer,
      MapLayerType.units,
    );
    expect(find.text('Units 1 · 64,64px'), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-layer-units-locked')));
    await tester.pump();
    expect(mapLayerController.state.selection, isNull);
    expect(
      mapLayerController.state.selectionPriority,
      isNot(contains(MapLayerType.units)),
    );
    await _tapMapPixel(tester, pixelX: 64, pixelY: 64);
    expect(
      mapLayerController.state.selection?.object.layer,
      MapLayerType.sprites,
    );

    await tester.tap(find.byKey(const Key('map-layer-units-locked')));
    await tester.pump();
    await _tapMapPixel(tester, pixelX: 64, pixelY: 64);
    expect(
      mapLayerController.state.selection?.object.layer,
      MapLayerType.units,
    );

    await tester.tap(find.byKey(const Key('map-layer-units-visible')));
    await tester.pump();
    expect(mapLayerController.state.selection, isNull);
    scene = mapLayerController.sceneFor(session);
    expect(
      scene.points.where((point) => point.object.layer == MapLayerType.units),
      isEmpty,
    );
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.layerScene, same(scene));

    await tester.tap(find.byKey(const Key('map-layer-units-visible')));
    await tester.pump();
    await _tapMapPixel(tester, pixelX: 64, pixelY: 64);
    expect(find.byKey(const Key('object-editing-toolbar')), findsOneWidget);
    expect(find.text('1 selected · drag selection to move'), findsOneWidget);
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).onSelectedObjectsMoved,
      isNotNull,
    );

    final drag = await tester.startGesture(
      _mapPixelOffset(tester, pixelX: 64, pixelY: 64),
    );
    await drag.moveTo(_mapPixelOffset(tester, pixelX: 96, pixelY: 96));
    await drag.up();
    await tester.pump();
    expect(
      openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units
          .single
          .x,
      96,
    );
    expect(openMapController.state.session!.isDirty, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(
      openMapController.state.session!.objectViews.unitSections.single.units,
      isEmpty,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units
          .single
          .x,
      96,
    );

    expect(find.text('Unit type 1'), findsOneWidget);
    expect(find.text('Doodad type 1'), findsOneWidget);
    expect(find.text('Sprite type 1'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('object-palette-search')),
      'unit #1',
    );
    await tester.pump();
    expect(find.text('Unit type 1'), findsOneWidget);
    expect(find.text('Doodad type 1'), findsNothing);

    await tester.tap(
      find.byKey(const Key('object-palette-units-1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(objectPaletteController.state.isPlacementActive, isTrue);
    expect(find.byKey(const Key('object-placement-active')), findsOneWidget);
    expect(
      tester.widget<MapCanvas>(find.byType(MapCanvas)).isObjectPlacementActive,
      isTrue,
    );

    await _tapMapPixel(tester, pixelX: 128, pixelY: 128);
    final placedUnits =
        openMapController.state.session!.objectViews.unitSections.single.units;
    expect(placedUnits, hasLength(2));
    expect((placedUnits.last.x, placedUnits.last.y), (128, 128));
    expect(objectPaletteController.state.isPlacementActive, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(objectPaletteController.state.isPlacementActive, isFalse);
    expect(find.byKey(const Key('object-placement-active')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('object inspector validates and applies unit properties', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final settingsStore = InMemorySettingsStore();
    final recentProjectsService = RecentProjectsService(settingsStore);
    final progressController = OperationProgressController();
    final mapLayerController = MapLayerController();
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
    final objectEditingController = ObjectEditingController(
      openMapController: openMapController,
      mapLayerController: mapLayerController,
    );
    addTearDown(openMapController.dispose);
    addTearDown(progressController.dispose);
    addTearDown(mapLayerController.dispose);
    addTearDown(objectEditingController.dispose);

    await tester.pumpWidget(
      _createTestApp(
        openMapController: openMapController,
        operationProgressController: progressController,
        recentProjectsService: recentProjectsService,
        settingsStore: settingsStore,
        mapLayerController: mapLayerController,
        objectEditingController: objectEditingController,
      ),
    );
    await tester.tap(find.byKey(const Key('open-map-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-layer-units')));
    await tester.pump();
    await _tapMapPixel(tester, pixelX: 64, pixelY: 64);

    expect(find.text('Unit #0'), findsOneWidget);
    expect(
      find.byKey(const Key('object-properties-inspector')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('object-inspector-x')), '9999');
    await tester.tap(find.byKey(const Key('object-inspector-apply')));
    await tester.pump();
    expect(find.text('X must stay inside the map.'), findsOneWidget);
    expect(openMapController.state.session!.isDirty, isFalse);

    await tester.enterText(
      find.byKey(const Key('object-inspector-typeId')),
      '42',
    );
    await tester.enterText(find.byKey(const Key('object-inspector-x')), '80');
    await tester.enterText(
      find.byKey(const Key('object-inspector-owner')),
      '6',
    );
    await tester.tap(find.byKey(const Key('object-inspector-apply')));
    await tester.pump();

    final unit = openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units
        .single;
    expect((unit.unitType, unit.x, unit.owner), (42, 80, 6));
    expect(openMapController.state.session!.isDirty, isTrue);
    expect(objectEditingController.undoLabel, 'Edit Unit properties');
    expect(mapLayerController.state.selection?.object.recordIndex, 0);

    await tester.tap(find.byKey(const Key('map-layer-locations')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('object-create-location')));
    await tester.pump();
    expect(objectEditingController.state.isCreatingLocation, isTrue);
    expect(find.byKey(const Key('location-creation-active')), findsOneWidget);
    final locationDrag = await tester.startGesture(
      _mapPixelOffset(tester, pixelX: 160, pixelY: 160),
    );
    await locationDrag.moveTo(
      _mapPixelOffset(tester, pixelX: 224, pixelY: 224),
    );
    await locationDrag.up();
    await tester.pump();

    var location = openMapController
        .state
        .session!
        .objectViews
        .locationSections
        .single
        .locations[1];
    expect(
      (location.left, location.top, location.right, location.bottom),
      (160, 160, 224, 224),
    );
    expect(find.text('Location 2'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('location-inspector-name')))
          .enabled,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('location-inspector-name')),
      'Spawn Area',
    );
    await tester.enterText(
      find.byKey(const Key('location-inspector-right')),
      '240',
    );
    await tester.tap(find.byKey(const Key('location-inspector-apply')));
    await tester.pump();

    location = openMapController
        .state
        .session!
        .objectViews
        .locationSections
        .single
        .locations[1];
    expect((location.right, location.stringId), (240, 2));
    expect(
      const ChkStringViewDecoder()
          .decode(openMapController.state.session!.rawDocument)
          .legacyTables
          .single
          .entries[1]
          .rawBytes,
      utf8.encode('Spawn Area'),
    );

    await tester.tap(find.byKey(const Key('object-create-location')));
    await tester.pump();
    expect(objectEditingController.state.isCreatingLocation, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(objectEditingController.state.isCreatingLocation, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapMapPixel(
  WidgetTester tester, {
  required int pixelX,
  required int pixelY,
}) async {
  await tester.tapAt(_mapPixelOffset(tester, pixelX: pixelX, pixelY: pixelY));
  await tester.pump();
}

Offset _mapPixelOffset(
  WidgetTester tester, {
  required int pixelX,
  required int pixelY,
}) {
  final painter =
      tester
              .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
              .painter!
          as MapCanvasPainter;
  final canvasTopLeft = tester.getTopLeft(find.byKey(const Key('map-canvas')));
  return canvasTopLeft +
      painter.layout.mapRect.topLeft +
      Offset(
        (pixelX + 0.5) / 32 * painter.layout.tileExtent,
        (pixelY + 0.5) / 32 * painter.layout.tileExtent,
      );
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
  TerrainEditingController? terrainEditingController,
  MapLayerController? mapLayerController,
  ObjectEditingController? objectEditingController,
  ObjectPaletteController? objectPaletteController,
  TerrainTileTextureController? terrainTileTextureController,
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
  final resolvedTerrainEditingController =
      terrainEditingController ??
      TerrainEditingController(openMapController: resolvedOpenMapController);
  final resolvedMapLayerController = mapLayerController ?? MapLayerController();
  final resolvedObjectEditingController =
      objectEditingController ??
      ObjectEditingController(
        openMapController: resolvedOpenMapController,
        mapLayerController: resolvedMapLayerController,
      );
  final resolvedObjectPaletteController =
      objectPaletteController ??
      ObjectPaletteController(
        objectEditingController: resolvedObjectEditingController,
        mapLayerController: resolvedMapLayerController,
      );
  final resolvedTerrainTileTextureController =
      terrainTileTextureController ??
      TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(
          gateway: _UnusedStarCraftTileAtlasGateway(),
        ),
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
      terrainEditingController: resolvedTerrainEditingController,
      mapLayerController: resolvedMapLayerController,
      objectEditingController: resolvedObjectEditingController,
      objectPaletteController: resolvedObjectPaletteController,
      terrainTileTextureController: resolvedTerrainTileTextureController,
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

final class _RenderableStarCraftDataAssetInspector
    implements StarCraftDataAssetInspector {
  const _RenderableStarCraftDataAssetInspector();

  @override
  Future<StarCraftDataAssetInspection> inspect(String installationPath) async {
    return StarCraftDataAssetInspection(
      installationPath: installationPath,
      requiredAssetCount: 40,
      foundAssetCount: 40,
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.3.0',
      cascLibRevision: 'pinned-casc',
      totalAssetBytes: 1024,
    );
  }
}

final class _RenderingStarCraftTileAtlasGateway
    implements StarCraftTileAtlasGateway {
  final List<StarCraftTileAtlasRequest> requests = [];

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    requests.add(request);
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: 32,
      columns: request.rawValues.length,
      rows: 1,
      rawValues: request.rawValues,
      rgbaBytes: Uint8List(request.rawValues.length * 32 * 32 * 4),
      unsupportedRawValues: const [],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.3.0',
      cascLibRevision: 'pinned-casc',
      totalAssetBytes: 1024,
    );
  }
}

final class _BorrowedTerrainTextureFactory
    implements TerrainTileTextureFactory {
  _BorrowedTerrainTextureFactory(this.image);

  final ui.Image image;
  int disposedTextures = 0;

  @override
  Future<TerrainTileTexture> create(Uint8List rgbaBytes) async {
    return _BorrowedTerrainTexture(image, () => disposedTextures++);
  }
}

final class _BorrowedTerrainTexture implements TerrainTileTexture {
  _BorrowedTerrainTexture(this.image, this.onDispose);

  @override
  final ui.Image image;
  final VoidCallback onDispose;
  bool _disposed = false;

  @override
  int get width => image.width;

  @override
  int get height => image.height;

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    onDispose();
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

final class _UnusedStarCraftTileAtlasGateway
    implements StarCraftTileAtlasGateway {
  @override
  Future<StarCraftTileAtlasResult> render(StarCraftTileAtlasRequest request) {
    throw StateError('The StarCraft tile gateway is not used by this test.');
  }
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
    terrainData.setUint16(
      index * 2,
      index == 1 ? 0x4000 : index % 32,
      Endian.little,
    );
  }
  final locationPayload = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  ByteData.sublistView(locationPayload)
    ..setUint32(0, 32, Endian.little)
    ..setUint32(4, 32, Endian.little)
    ..setUint32(8, 96, Endian.little)
    ..setUint32(12, 96, Endian.little)
    ..setUint16(16, 1, Endian.little)
    ..setUint16(18, 0x3f, Endian.little);
  final chkBytes = _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [mapWidth, 0, mapHeight, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', terrainPayload),
    _section('UNIT', _unitRecord(64, 64)),
    _section('DD2 ', _doodadRecord(64, 64)),
    _section('THG2', _spriteRecord(64, 64)),
    _section('MRGN', locationPayload),
    _section('STR ', _legacyStringTable(['Existing'])),
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

Uint8List _legacyStringTable(List<String> strings) {
  final encoded = strings.map(utf8.encode).toList(growable: false);
  final headerLength = 2 + strings.length * 2;
  final payloadLength =
      headerLength +
      encoded.fold<int>(0, (sum, bytes) => sum + bytes.length + 1);
  final payload = Uint8List(payloadLength);
  final data = ByteData.sublistView(payload)
    ..setUint16(0, strings.length, Endian.little);
  var offset = headerLength;
  for (var index = 0; index < encoded.length; index++) {
    data.setUint16(2 + index * 2, offset, Endian.little);
    payload.setAll(offset, encoded[index]);
    offset += encoded[index].length + 1;
  }
  return payload;
}

Uint8List _unitRecord(int x, int y) {
  final bytes = Uint8List(ChkUnitPlacement.recordLength);
  ByteData.sublistView(bytes)
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little)
    ..setUint16(8, 1, Endian.little);
  return bytes;
}

Uint8List _doodadRecord(int x, int y) {
  final bytes = Uint8List(ChkDoodadPlacement.recordLength);
  ByteData.sublistView(bytes)
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
}

Uint8List _spriteRecord(int x, int y) {
  final bytes = Uint8List(ChkSpritePlacement.recordLength);
  ByteData.sublistView(bytes)
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
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
