import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
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

  testWidgets('opens a selected map and renders its CHK summary', (
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
    expect(find.text('Arena.scx'), findsWidgets);
    expect(find.text('64 × 96'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
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
  });
}

Widget _createTestApp({
  EditorCommandDispatcher? dispatcher,
  OpenMapController? openMapController,
  SaveMapController? saveMapController,
  OperationProgressController? operationProgressController,
  RecentProjectsService? recentProjectsService,
  InMemorySettingsStore? settingsStore,
}) {
  final resolvedSettingsStore = settingsStore ?? InMemorySettingsStore();
  final resolvedProgressController =
      operationProgressController ?? OperationProgressController();
  final resolvedRecentProjectsService =
      recentProjectsService ?? RecentProjectsService(resolvedSettingsStore);
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
      });
  return StarCraftMapEditorApp(
    dependencies: EditorAppDependencies(
      commandDispatcher: resolvedDispatcher,
      openMapController: resolvedOpenMapController,
      saveMapController: resolvedSaveMapController,
      operationProgressController: resolvedProgressController,
      recentProjectsService: resolvedRecentProjectsService,
      settingsStore: resolvedSettingsStore,
    ),
  );
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
  Future<void> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
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
  final chkBytes = _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [64, 0, 96, 0]),
    _section('ERA ', [4, 0]),
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
