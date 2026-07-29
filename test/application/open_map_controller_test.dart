import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  group('OpenMapController', () {
    test('selects, extracts, parses, summarizes, and records a map', () async {
      final map = _createExtractedMap(_validChkBytes());
      final gateway = _FakeMapArchiveGateway(
        result: MapArchiveOpenResult.success(map: map),
      );
      final picker = _FakeMapFilePicker(map.sourcePath);
      final recentProjectsService = RecentProjectsService(
        InMemorySettingsStore(),
      );
      final progressController = OperationProgressController();
      final fingerprintGateway = _FakeMapFileFingerprintGateway();
      final openedAt = DateTime(2026, 7, 26, 14, 30);
      final controller = OpenMapController(
        archiveGateway: gateway,
        filePicker: picker,
        fingerprintGateway: fingerprintGateway,
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
        clock: () => openedAt,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(picker.invocationCount, 1);
      expect(gateway.openRequests, hasLength(1));
      expect(gateway.openRequests.single.sourcePath, map.sourcePath);
      expect(gateway.openRequests.single.operationId, startsWith('open-map-'));
      expect(state.status, OpenMapStatus.opened);
      expect(state.session, isNotNull);
      expect(state.session!.rawDocument.sections, hasLength(5));
      expect(state.session!.metadataViews.dimensions.single.width, 64);
      expect(state.session!.metadataViews.dimensions.single.height, 96);
      expect(state.session!.archiveMetadata.entries, hasLength(2));
      expect(state.session!.sourceFingerprint, _originalFingerprint());
      expect(fingerprintGateway.paths, [map.sourcePath, map.sourcePath]);
      expect(state.diagnostics, isEmpty);
      expect(progressController.current!.phase, OperationPhase.succeeded);
      expect((await recentProjectsService.load()).single.path, map.sourcePath);
      expect(
        (await recentProjectsService.load()).single.lastOpenedAt,
        openedAt,
      );
    });

    test(
      'reopens an explicit recent path without showing the picker',
      () async {
        final map = _createExtractedMap(_validChkBytes());
        final gateway = _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        );
        final picker = _FakeMapFilePicker(null);
        final progressController = OperationProgressController();
        final controller = OpenMapController(
          archiveGateway: gateway,
          filePicker: picker,
          fingerprintGateway: _FakeMapFileFingerprintGateway(),
          recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
          operationProgressController: progressController,
        );
        addTearDown(controller.dispose);
        addTearDown(progressController.dispose);

        final state = await controller.open(sourcePath: map.sourcePath);

        expect(state.status, OpenMapStatus.opened);
        expect(picker.invocationCount, 0);
        expect(gateway.openRequests.single.sourcePath, map.sourcePath);
      },
    );

    test('does not record a map when archive extraction fails', () async {
      final diagnostic = _errorDiagnostic(
        code: 'ARCHIVE_OPEN_FAILED',
        message: 'The archive could not be opened.',
      );
      final gateway = _FakeMapArchiveGateway(
        result: MapArchiveOpenResult.failure(diagnostics: [diagnostic]),
      );
      final recentProjectsService = RecentProjectsService(
        InMemorySettingsStore(),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: gateway,
        filePicker: _FakeMapFilePicker(r'C:\Maps\Broken.scx'),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.failed);
      expect(state.session, isNull);
      expect(state.diagnostics.single, same(diagnostic));
      expect(progressController.current!.phase, OperationPhase.failed);
      expect(await recentProjectsService.load(), isEmpty);
    });

    test('rejects a structurally invalid CHK after extraction', () async {
      final map = _createExtractedMap(Uint8List.fromList([1, 2, 3]));
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        ),
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.failed);
      expect(state.diagnostics.single.code, 'CHK_TRUNCATED_HEADER');
      expect(progressController.current!.phase, OperationPhase.failed);
    });

    test('opens typed metadata errors in restricted read-only mode', () async {
      final malformedVersion = _chkBytes([
        _section('VER ', [206]),
        _section('DIM ', [64, 0, 96, 0]),
      ]);
      final map = _createExtractedMap(malformedVersion);
      final recentProjectsService = RecentProjectsService(
        InMemorySettingsStore(),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        ),
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.opened);
      expect(state.session!.requiresRestrictedEditing, isTrue);
      expect(state.diagnostics.single.code, 'CHK_TYPED_SECTION_SIZE_MISMATCH');
      expect(progressController.current!.phase, OperationPhase.succeeded);
      expect(await recentProjectsService.load(), hasLength(1));
    });

    test('decodes valid terrain into the opened document session', () async {
      final map = _createExtractedMap(
        _chkBytes([
          _section('DIM ', [2, 0, 2, 0]),
          _section('ERA ', [4, 0]),
          _section('MTXM', [1, 0, 2, 0, 3, 0, 4, 0]),
        ]),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        ),
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.opened);
      expect(state.diagnostics, isEmpty);
      expect(state.session!.terrainViews.tileMaps, hasLength(1));
      expect(state.session!.terrainViews.tileMaps.single.rawTileValues, [
        1,
        2,
        3,
        4,
      ]);
    });

    test('opens malformed terrain in restricted read-only mode', () async {
      final map = _createExtractedMap(
        _chkBytes([
          _section('DIM ', [2, 0, 2, 0]),
          _section('MTXM', [1, 0, 2, 0, 3, 0]),
        ]),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        ),
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.opened);
      expect(state.session!.requiresRestrictedEditing, isTrue);
      expect(state.session!.terrainViews.tileMaps, isEmpty);
      expect(state.diagnostics.single.code, 'CHK_TERRAIN_TILE_COUNT_MISMATCH');
    });

    test('rejects unsupported extensions before archive access', () async {
      final gateway = _FakeMapArchiveGateway(
        result: MapArchiveOpenResult.success(
          map: _createExtractedMap(_validChkBytes()),
        ),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: gateway,
        filePicker: _FakeMapFilePicker(r'C:\Maps\Notes.txt'),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        OpenMapDiagnosticCodes.unsupportedExtension,
      );
      expect(gateway.openRequests, isEmpty);
      expect(progressController.current, isNull);
    });

    test('leaves state unchanged when file selection is cancelled', () async {
      final gateway = _FakeMapArchiveGateway(
        result: MapArchiveOpenResult.success(
          map: _createExtractedMap(_validChkBytes()),
        ),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: gateway,
        filePicker: _FakeMapFilePicker(null),
        fingerprintGateway: _FakeMapFileFingerprintGateway(),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.idle);
      expect(state.diagnostics, isEmpty);
      expect(gateway.openRequests, isEmpty);
      expect(progressController.current, isNull);
    });

    test('rejects a map that changes while it is being opened', () async {
      final map = _createExtractedMap(_validChkBytes());
      final recentProjectsService = RecentProjectsService(
        InMemorySettingsStore(),
      );
      final progressController = OperationProgressController();
      final controller = OpenMapController(
        archiveGateway: _FakeMapArchiveGateway(
          result: MapArchiveOpenResult.success(map: map),
        ),
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(
          responses: [_originalFingerprint(), _changedFingerprint()],
        ),
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.failed);
      expect(state.session, isNull);
      expect(
        state.diagnostics.single.code,
        OpenMapDiagnosticCodes.sourceChangedDuringOpen,
      );
      expect(progressController.current!.phase, OperationPhase.failed);
      expect(await recentProjectsService.load(), isEmpty);
    });

    test('reports a stable diagnostic when fingerprinting fails', () async {
      final map = _createExtractedMap(_validChkBytes());
      final progressController = OperationProgressController();
      final gateway = _FakeMapArchiveGateway(
        result: MapArchiveOpenResult.success(map: map),
      );
      final controller = OpenMapController(
        archiveGateway: gateway,
        filePicker: _FakeMapFilePicker(map.sourcePath),
        fingerprintGateway: _FakeMapFileFingerprintGateway(
          responses: [StateError('file disappeared')],
        ),
        recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);

      final state = await controller.open();

      expect(state.status, OpenMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        OpenMapDiagnosticCodes.sourceFingerprintFailed,
      );
      expect(gateway.openRequests, isEmpty);
      expect(progressController.current!.phase, OperationPhase.failed);
    });
  });
}

class _FakeMapFilePicker implements MapFilePicker {
  _FakeMapFilePicker(this.path);

  final String? path;
  int invocationCount = 0;

  @override
  Future<String?> pickMapPath() async {
    invocationCount++;
    return path;
  }

  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) {
    throw UnimplementedError();
  }
}

class _FakeMapArchiveGateway implements MapArchiveGateway {
  _FakeMapArchiveGateway({required this.result});

  final MapArchiveOpenResult result;
  final List<MapArchiveOpenRequest> openRequests = [];

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    openRequests.add(request);
    return result;
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(MapArchiveWriteRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

class _FakeMapFileFingerprintGateway implements MapFileFingerprintGateway {
  _FakeMapFileFingerprintGateway({List<Object>? responses})
    : _responses = [...?responses];

  final List<Object> _responses;
  final List<String> paths = [];

  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    paths.add(path);
    final response = _responses.isEmpty
        ? _originalFingerprint()
        : _responses.removeAt(0);
    if (response is MapFileFingerprint) {
      return response;
    }
    throw response;
  }
}

MapFileFingerprint _originalFingerprint() {
  return MapFileFingerprint(
    sizeBytes: 4096,
    modifiedAt: DateTime.utc(2026, 7, 26, 12),
    sha256Digest:
        '1111111111111111111111111111111111111111111111111111111111111111',
  );
}

MapFileFingerprint _changedFingerprint() {
  return MapFileFingerprint(
    sizeBytes: 4096,
    modifiedAt: DateTime.utc(2026, 7, 26, 12),
    sha256Digest:
        '2222222222222222222222222222222222222222222222222222222222222222',
  );
}

ExtractedMap _createExtractedMap(Uint8List chkBytes) {
  const sourcePath = r'C:\Maps\Arena.scx';
  return ExtractedMap(
    sourcePath: sourcePath,
    scenarioChkBytes: chkBytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: 4096,
      formatVersion: 1,
      totalEntryCount: 2,
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
        MapArchiveEntryMetadata(
          path: '(listfile)',
          uncompressedSizeBytes: 32,
          compressedSizeBytes: 24,
          flags: 0x80000000,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
    ),
  );
}

Uint8List _validChkBytes() {
  return _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [64, 0, 96, 0]),
    _section('ERA ', [4, 0]),
  ]);
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

EditorDiagnostic _errorDiagnostic({
  required String code,
  required String message,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.error,
    stage: DiagnosticStage.archive,
  );
}
