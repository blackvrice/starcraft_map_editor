import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  group('SaveMapController', () {
    late _FakeMapArchiveGateway archiveGateway;
    late _FakeMapFilePicker filePicker;
    late _FakeMapSaveFileGateway saveFileGateway;
    late OperationProgressController progressController;
    late RecentProjectsService recentProjectsService;
    late OpenMapController openMapController;
    late SaveMapController saveMapController;
    late ExtractedMap sourceMap;

    setUp(() async {
      sourceMap = _createExtractedMap(
        sourcePath: r'C:\Maps\Arena.scx',
        chkBytes: _validChkBytes(),
      );
      archiveGateway = _FakeMapArchiveGateway(sourceMap);
      filePicker = _FakeMapFilePicker(
        openPath: sourceMap.sourcePath,
        savePath: r'C:\Maps\Arena Copy.scx',
      );
      saveFileGateway = _FakeMapSaveFileGateway();
      progressController = OperationProgressController();
      recentProjectsService = RecentProjectsService(InMemorySettingsStore());
      openMapController = OpenMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
      );
      saveMapController = SaveMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        saveFileGateway: saveFileGateway,
        openMapController: openMapController,
        operationProgressController: progressController,
      );
      await openMapController.open();
    });

    tearDown(() async {
      await saveMapController.dispose();
      await openMapController.dispose();
      await progressController.dispose();
    });

    test(
      'writes, reopens, verifies, promotes, and adopts the saved map',
      () async {
        final state = await saveMapController.saveAs();

        expect(state.status, SaveMapStatus.saved);
        expect(state.outputPath, r'C:\Maps\Arena Copy.scx');
        expect(filePicker.saveSuggestedNames, ['Arena Copy.scx']);
        expect(archiveGateway.writeRequests, hasLength(1));
        expect(
          archiveGateway.writeRequests.single.sourcePath,
          sourceMap.sourcePath,
        );
        expect(
          archiveGateway.writeRequests.single.temporaryOutputPath,
          saveFileGateway.workspace.temporaryOutputPath,
        );
        expect(
          archiveGateway.writeRequests.single.scenarioChkBytes,
          sourceMap.scenarioChkBytes,
        );
        expect(archiveGateway.openRequests, hasLength(2));
        expect(
          archiveGateway.openRequests.last.sourcePath,
          saveFileGateway.workspace.temporaryOutputPath,
        );
        expect(saveFileGateway.promotedDestination, state.outputPath);
        expect(saveFileGateway.cleanupCount, 1);
        expect(
          openMapController.state.session!.sourcePath,
          r'C:\Maps\Arena Copy.scx',
        );
        expect(progressController.current!.phase, OperationPhase.succeeded);
        expect(
          (await recentProjectsService.load()).first.path,
          r'C:\Maps\Arena Copy.scx',
        );
      },
    );

    test('refuses to overwrite the current source path', () async {
      final state = await saveMapController.saveAs(
        destinationPath: sourceMap.sourcePath.toLowerCase(),
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.sourceDestinationSame,
      );
      expect(archiveGateway.writeRequests, isEmpty);
      expect(saveFileGateway.createWorkspaceCount, 0);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
    });

    test('refuses an existing destination without changing it', () async {
      saveFileGateway.destinationAlreadyExists = true;

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Existing.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.destinationExists,
      );
      expect(archiveGateway.writeRequests, isEmpty);
      expect(saveFileGateway.createWorkspaceCount, 0);
      expect(saveFileGateway.promotedDestination, isNull);
    });

    test('rejects a relative destination before filesystem access', () async {
      final state = await saveMapController.saveAs(
        destinationPath: 'relative.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.invalidDestinationPath,
      );
      expect(saveFileGateway.createWorkspaceCount, 0);
      expect(archiveGateway.writeRequests, isEmpty);
    });

    test(
      'does not promote a temporary map with mismatched CHK bytes',
      () async {
        archiveGateway.verifiedChkBytes = _alternateValidChkBytes();

        final state = await saveMapController.saveAs(
          destinationPath: r'C:\Maps\Mismatch.scx',
        );

        expect(state.status, SaveMapStatus.failed);
        expect(
          state.diagnostics.single.code,
          SaveMapDiagnosticCodes.verificationBytesMismatch,
        );
        expect(saveFileGateway.promotedDestination, isNull);
        expect(saveFileGateway.cleanupCount, 1);
        expect(
          openMapController.state.session!.sourcePath,
          sourceMap.sourcePath,
        );
        expect(progressController.current!.phase, OperationPhase.failed);
      },
    );

    test('does not promote when temporary archive writing fails', () async {
      archiveGateway.writeFailure = EditorDiagnostic(
        code: 'ARCHIVE_SCENARIO_REPLACE_FAILED',
        message: 'scenario.chk replacement failed.',
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.save,
      );

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Write Failure.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(state.diagnostics.single.code, 'ARCHIVE_SCENARIO_REPLACE_FAILED');
      expect(saveFileGateway.promotedDestination, isNull);
      expect(saveFileGateway.cleanupCount, 1);
      expect(archiveGateway.openRequests, hasLength(1));
    });

    test('reports promotion failure and cleans the workspace', () async {
      saveFileGateway.promotionError = StateError('rename failed');

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Promotion Failure.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.promotionFailed,
      );
      expect(saveFileGateway.cleanupCount, 1);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
    });
  });
}

class _FakeMapArchiveGateway implements MapArchiveGateway {
  _FakeMapArchiveGateway(this.sourceMap);

  final ExtractedMap sourceMap;
  final List<MapArchiveOpenRequest> openRequests = [];
  final List<MapArchiveWriteRequest> writeRequests = [];
  Uint8List? verifiedChkBytes;
  EditorDiagnostic? writeFailure;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    openRequests.add(request);
    if (request.sourcePath == sourceMap.sourcePath) {
      return MapArchiveOpenResult.success(map: sourceMap);
    }
    final chkBytes =
        verifiedChkBytes ??
        Uint8List.fromList(writeRequests.single.scenarioChkBytes);
    return MapArchiveOpenResult.success(
      map: _createExtractedMap(
        sourcePath: request.sourcePath,
        chkBytes: chkBytes,
      ),
    );
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) async {
    writeRequests.add(request);
    final failure = writeFailure;
    if (failure != null) {
      return MapArchiveWriteResult.failure(diagnostics: [failure]);
    }
    return MapArchiveWriteResult.success(
      temporaryOutputPath: request.temporaryOutputPath,
    );
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

class _FakeMapFilePicker implements MapFilePicker {
  _FakeMapFilePicker({required this.openPath, required this.savePath});

  final String? openPath;
  final String? savePath;
  final List<String> saveSuggestedNames = [];

  @override
  Future<String?> pickMapPath() async => openPath;

  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async {
    saveSuggestedNames.add(suggestedName);
    return savePath;
  }
}

class _FakeMapSaveFileGateway implements MapSaveFileGateway {
  final workspace = MapSaveWorkspace(
    directoryPath: r'C:\Maps\.starcraft_map_editor_save_test',
    temporaryOutputPath:
        r'C:\Maps\.starcraft_map_editor_save_test\temporary-map.scx',
  );

  bool destinationAlreadyExists = false;
  Object? promotionError;
  int createWorkspaceCount = 0;
  int cleanupCount = 0;
  String? promotedDestination;

  @override
  Future<void> cleanup(MapSaveWorkspace workspace) async {
    cleanupCount++;
  }

  @override
  Future<MapSaveWorkspace> createWorkspace(String destinationPath) async {
    createWorkspaceCount++;
    return workspace;
  }

  @override
  Future<bool> destinationExists(String path) async => destinationAlreadyExists;

  @override
  Future<void> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
  }) async {
    final error = promotionError;
    if (error != null) {
      throw error;
    }
    promotedDestination = destinationPath;
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async {
    String normalize(String path) => path.replaceAll('/', r'\').toLowerCase();
    return normalize(leftPath) == normalize(rightPath);
  }
}

ExtractedMap _createExtractedMap({
  required String sourcePath,
  required Uint8List chkBytes,
}) {
  return ExtractedMap(
    sourcePath: sourcePath,
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

Uint8List _validChkBytes() {
  return _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [64, 0, 96, 0]),
    _section('ERA ', [4, 0]),
  ]);
}

Uint8List _alternateValidChkBytes() {
  return _chkBytes([
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [205, 0]),
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
