import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  group('SaveMapController', () {
    late _FakeMapArchiveGateway archiveGateway;
    late _FakeMapFilePicker filePicker;
    late _FakeMapFileFingerprintGateway fingerprintGateway;
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
      fingerprintGateway = _FakeMapFileFingerprintGateway(
        defaultResponses: {
          sourceMap.sourcePath: _originalFingerprint(),
          saveFileGateway.workspace.temporaryOutputPath: _outputFingerprint(),
        },
      );
      progressController = OperationProgressController();
      recentProjectsService = RecentProjectsService(InMemorySettingsStore());
      openMapController = OpenMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        fingerprintGateway: fingerprintGateway,
        recentProjectsService: recentProjectsService,
        operationProgressController: progressController,
      );
      saveMapController = SaveMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        fingerprintGateway: fingerprintGateway,
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
        expect(
          openMapController.state.session!.sourceFingerprint,
          _outputFingerprint(),
        );
        expect(fingerprintGateway.paths, [
          sourceMap.sourcePath,
          sourceMap.sourcePath,
          sourceMap.sourcePath,
          saveFileGateway.workspace.temporaryOutputPath,
          sourceMap.sourcePath,
        ]);
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
        replaceExisting: true,
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

    test(
      'backs up and replaces a destination confirmed by the Save As dialog',
      () async {
        const destinationPath = r'C:\Maps\Arena Copy.scx';
        const backupPath = r'C:\Maps\Arena Copy.scx.backup-test.bak';
        saveFileGateway.destinationAlreadyExists = true;
        saveFileGateway.promotionResult = MapSavePromotionResult(
          backupPath: backupPath,
        );
        fingerprintGateway.defaultResponses[destinationPath] =
            _existingDestinationFingerprint();

        final state = await saveMapController.saveAs();

        expect(state.status, SaveMapStatus.saved);
        expect(state.outputPath, destinationPath);
        expect(state.backupPath, backupPath);
        expect(saveFileGateway.promotedDestination, destinationPath);
        expect(saveFileGateway.promotedReplaceExisting, isTrue);
        expect(
          state.diagnostics.last.code,
          SaveMapDiagnosticCodes.backupCreated,
        );
        expect(state.diagnostics.last.filePath, backupPath);
        expect(
          openMapController.state.session!.diagnostics
              .where(
                (diagnostic) =>
                    diagnostic.code == SaveMapDiagnosticCodes.backupCreated,
              )
              .toList(),
          isEmpty,
        );
      },
    );

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

    test('does not replace a destination changed during Save As', () async {
      const destinationPath = r'C:\Maps\Externally Changed.scx';
      saveFileGateway.destinationAlreadyExists = true;
      fingerprintGateway.defaultResponses[destinationPath] =
          _existingDestinationFingerprint();
      fingerprintGateway.script(destinationPath, [
        _existingDestinationFingerprint(),
        _changedDestinationFingerprint(),
      ]);

      final state = await saveMapController.saveAs(
        destinationPath: destinationPath,
        replaceExisting: true,
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.destinationChangedDuringSave,
      );
      expect(saveFileGateway.promotedDestination, isNull);
      expect(saveFileGateway.cleanupCount, 1);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
    });

    test('does not replace a destination created during Save As', () async {
      saveFileGateway.destinationExistenceResponses.addAll([false, true]);

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Created During Save.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.destinationChangedDuringSave,
      );
      expect(saveFileGateway.promotedDestination, isNull);
      expect(saveFileGateway.cleanupCount, 1);
    });

    test('reports the backup path when automatic restoration fails', () async {
      const destinationPath = r'C:\Maps\Recovery Required.scx';
      const backupPath = r'C:\Maps\Recovery Required.scx.backup-recovery.bak';
      saveFileGateway.destinationAlreadyExists = true;
      fingerprintGateway.defaultResponses[destinationPath] =
          _existingDestinationFingerprint();
      saveFileGateway.promotionError = MapSavePromotionRecoveryException(
        destinationPath: destinationPath,
        backupPath: backupPath,
        promotionError: StateError('promotion failed'),
        restorationError: StateError('restoration failed'),
      );

      final state = await saveMapController.saveAs(
        destinationPath: destinationPath,
        replaceExisting: true,
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.promotionRecoveryRequired,
      );
      expect(state.diagnostics.single.filePath, backupPath);
      expect(saveFileGateway.cleanupCount, 1);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
    });

    test('stops before writing when the opened source changed', () async {
      fingerprintGateway.defaultResponses[sourceMap.sourcePath] =
          _changedFingerprint();

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Changed Before Save.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.sourceChangedBeforeSave,
      );
      expect(saveFileGateway.createWorkspaceCount, 0);
      expect(archiveGateway.writeRequests, isEmpty);
      expect(saveFileGateway.promotedDestination, isNull);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
    });

    test('does not promote when the source changes during Save As', () async {
      fingerprintGateway.script(sourceMap.sourcePath, [
        _originalFingerprint(),
        _changedFingerprint(),
      ]);

      final state = await saveMapController.saveAs(
        destinationPath: r'C:\Maps\Changed During Save.scx',
      );

      expect(state.status, SaveMapStatus.failed);
      expect(
        state.diagnostics.single.code,
        SaveMapDiagnosticCodes.sourceChangedDuringSave,
      );
      expect(archiveGateway.writeRequests, hasLength(1));
      expect(saveFileGateway.promotedDestination, isNull);
      expect(saveFileGateway.cleanupCount, 1);
      expect(openMapController.state.session!.sourcePath, sourceMap.sourcePath);
      expect(progressController.current!.phase, OperationPhase.failed);
    });

    test(
      'does not promote when the source disappears during Save As',
      () async {
        fingerprintGateway.script(sourceMap.sourcePath, [
          _originalFingerprint(),
          StateError('source file disappeared'),
        ]);

        final state = await saveMapController.saveAs(
          destinationPath: r'C:\Maps\Deleted During Save.scx',
        );

        expect(state.status, SaveMapStatus.failed);
        expect(
          state.diagnostics.single.code,
          SaveMapDiagnosticCodes.sourceFingerprintFailed,
        );
        expect(archiveGateway.writeRequests, hasLength(1));
        expect(saveFileGateway.promotedDestination, isNull);
        expect(saveFileGateway.cleanupCount, 1);
        expect(
          openMapController.state.session!.sourcePath,
          sourceMap.sourcePath,
        );
      },
    );
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

class _FakeMapFileFingerprintGateway implements MapFileFingerprintGateway {
  _FakeMapFileFingerprintGateway({
    required Map<String, MapFileFingerprint> defaultResponses,
  }) : defaultResponses = {...defaultResponses};

  final Map<String, MapFileFingerprint> defaultResponses;
  final Map<String, List<Object>> _scriptedResponses = {};
  final List<String> paths = [];

  void script(String path, List<Object> responses) {
    _scriptedResponses[path] = [...responses];
  }

  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    paths.add(path);
    final scripted = _scriptedResponses[path];
    final Object? response = scripted != null && scripted.isNotEmpty
        ? scripted.removeAt(0)
        : defaultResponses[path];
    if (response is MapFileFingerprint) {
      return response;
    }
    if (response != null) {
      throw response;
    }
    throw StateError('No fingerprint configured for $path.');
  }
}

class _FakeMapSaveFileGateway implements MapSaveFileGateway {
  final workspace = MapSaveWorkspace(
    directoryPath: r'C:\Maps\.starcraft_map_editor_save_test',
    temporaryOutputPath:
        r'C:\Maps\.starcraft_map_editor_save_test\temporary-map.scx',
  );

  bool destinationAlreadyExists = false;
  final List<bool> destinationExistenceResponses = [];
  Object? promotionError;
  MapSavePromotionResult promotionResult = MapSavePromotionResult();
  int createWorkspaceCount = 0;
  int cleanupCount = 0;
  String? promotedDestination;
  bool? promotedReplaceExisting;

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
  Future<bool> destinationExists(String path) async {
    if (destinationExistenceResponses.isNotEmpty) {
      return destinationExistenceResponses.removeAt(0);
    }
    return destinationAlreadyExists;
  }

  @override
  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async {
    final error = promotionError;
    if (error != null) {
      throw error;
    }
    promotedDestination = destinationPath;
    promotedReplaceExisting = replaceExisting;
    return promotionResult;
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async {
    String normalize(String path) => path.replaceAll('/', r'\').toLowerCase();
    return normalize(leftPath) == normalize(rightPath);
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

MapFileFingerprint _outputFingerprint() {
  return MapFileFingerprint(
    sizeBytes: 4352,
    modifiedAt: DateTime.utc(2026, 7, 26, 12, 1),
    sha256Digest:
        '3333333333333333333333333333333333333333333333333333333333333333',
  );
}

MapFileFingerprint _existingDestinationFingerprint() {
  return MapFileFingerprint(
    sizeBytes: 2048,
    modifiedAt: DateTime.utc(2026, 7, 26, 11),
    sha256Digest:
        '4444444444444444444444444444444444444444444444444444444444444444',
  );
}

MapFileFingerprint _changedDestinationFingerprint() {
  return MapFileFingerprint(
    sizeBytes: 2048,
    modifiedAt: DateTime.utc(2026, 7, 26, 11),
    sha256Digest:
        '5555555555555555555555555555555555555555555555555555555555555555',
  );
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
