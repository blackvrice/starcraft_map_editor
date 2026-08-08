import 'dart:async';

import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../operations/operation_progress.dart';
import '../operations/operation_progress_controller.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/map_file_picker.dart';
import '../ports/map_file_fingerprint_gateway.dart';
import '../ports/map_save_file_gateway.dart';
import 'open_map_controller.dart';
import 'opened_map_session.dart';

abstract final class SaveMapDiagnosticCodes {
  static const noMapOpen = 'SAVE_MAP_NO_OPEN_DOCUMENT';
  static const fileSelectionFailed = 'SAVE_MAP_FILE_SELECTION_FAILED';
  static const invalidDestinationPath = 'SAVE_MAP_DESTINATION_NOT_ABSOLUTE';
  static const unsupportedExtension = 'SAVE_MAP_UNSUPPORTED_EXTENSION';
  static const sourceDestinationSame = 'SAVE_MAP_SOURCE_DESTINATION_SAME';
  static const destinationExists = 'SAVE_MAP_DESTINATION_EXISTS';
  static const destinationFingerprintFailed =
      'SAVE_MAP_DESTINATION_FINGERPRINT_FAILED';
  static const destinationChangedDuringSave =
      'SAVE_MAP_DESTINATION_CHANGED_DURING_SAVE';
  static const operationBusy = 'SAVE_MAP_OPERATION_BUSY';
  static const sourceFingerprintFailed = 'SAVE_MAP_SOURCE_FINGERPRINT_FAILED';
  static const sourceChangedBeforeSave = 'SAVE_MAP_SOURCE_CHANGED_BEFORE_SAVE';
  static const sourceChangedDuringSave = 'SAVE_MAP_SOURCE_CHANGED_DURING_SAVE';
  static const workspaceFailed = 'SAVE_MAP_WORKSPACE_FAILED';
  static const verificationBytesMismatch =
      'SAVE_MAP_VERIFICATION_BYTES_MISMATCH';
  static const verificationParseFailed = 'SAVE_MAP_VERIFICATION_PARSE_FAILED';
  static const outputFingerprintFailed = 'SAVE_MAP_OUTPUT_FINGERPRINT_FAILED';
  static const promotionFailed = 'SAVE_MAP_PROMOTION_FAILED';
  static const promotionRecoveryRequired =
      'SAVE_MAP_PROMOTION_RECOVERY_REQUIRED';
  static const backupCreated = 'SAVE_MAP_BACKUP_CREATED';
  static const unexpectedFailure = 'SAVE_MAP_UNEXPECTED_FAILURE';
}

enum SaveMapStatus { idle, saved, failed }

class SaveMapState {
  const SaveMapState._({
    required this.status,
    required this.outputPath,
    required this.backupPath,
    required this.diagnostics,
  });

  const SaveMapState.idle()
    : this._(
        status: SaveMapStatus.idle,
        outputPath: null,
        backupPath: null,
        diagnostics: const [],
      );

  SaveMapState.saved({
    required String savedPath,
    String? backupPath,
    required Iterable<EditorDiagnostic> diagnostics,
  }) : this._(
         status: SaveMapStatus.saved,
         outputPath: savedPath,
         backupPath: backupPath,
         diagnostics: List.unmodifiable(diagnostics),
       );

  SaveMapState.failed({required Iterable<EditorDiagnostic> diagnostics})
    : this._(
        status: SaveMapStatus.failed,
        outputPath: null,
        backupPath: null,
        diagnostics: List.unmodifiable(diagnostics),
      );

  final SaveMapStatus status;
  final String? outputPath;
  final String? backupPath;
  final List<EditorDiagnostic> diagnostics;
}

class SaveMapController {
  SaveMapController({
    required this.archiveGateway,
    required this.filePicker,
    required this.fingerprintGateway,
    required this.saveFileGateway,
    required this.openMapController,
    required this.operationProgressController,
    this.rawChkEncoder = const RawChkEncoder(),
    this.rawChkParser = const RawChkParser(),
    this.metadataViewDecoder = const ChkMetadataViewDecoder(),
    this.stringViewDecoder = const ChkStringViewDecoder(),
    this.terrainViewDecoder = const ChkTerrainViewDecoder(),
    this.objectViewDecoder = const ChkObjectViewDecoder(),
    this.objectReferenceValidator = const ChkObjectReferenceValidator(),
    this.archiveTimeout = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (archiveTimeout <= Duration.zero) {
      throw ArgumentError.value(
        archiveTimeout,
        'archiveTimeout',
        'The archive timeout must be greater than zero.',
      );
    }
  }

  final MapArchiveGateway archiveGateway;
  final MapFilePicker filePicker;
  final MapFileFingerprintGateway fingerprintGateway;
  final MapSaveFileGateway saveFileGateway;
  final OpenMapController openMapController;
  final OperationProgressController operationProgressController;
  final RawChkEncoder rawChkEncoder;
  final RawChkParser rawChkParser;
  final ChkMetadataViewDecoder metadataViewDecoder;
  final ChkStringViewDecoder stringViewDecoder;
  final ChkTerrainViewDecoder terrainViewDecoder;
  final ChkObjectViewDecoder objectViewDecoder;
  final ChkObjectReferenceValidator objectReferenceValidator;
  final Duration archiveTimeout;
  final DateTime Function() _clock;
  final StreamController<SaveMapState> _changes =
      StreamController<SaveMapState>.broadcast(sync: true);

  SaveMapState _state = const SaveMapState.idle();
  bool _isSaving = false;
  int _operationSequence = 0;

  SaveMapState get state => _state;

  Stream<SaveMapState> get changes => _changes.stream;

  Future<SaveMapState> saveAs({
    String? destinationPath,
    bool replaceExisting = false,
  }) async {
    if (_isSaving) {
      return _state;
    }
    final sourceSession = openMapController.state.session;
    if (sourceSession == null) {
      return _emitFailure(
        _diagnostic(
          code: SaveMapDiagnosticCodes.noMapOpen,
          message: 'Open a map before using Save As.',
          remediation: 'Open a .scm or .scx map and try again.',
        ),
      );
    }
    _isSaving = true;

    MapSaveWorkspace? workspace;
    String? operationId;
    try {
      final selectedFromPicker = destinationPath == null;
      final selectedPath =
          destinationPath ??
          await _selectDestinationPath(sourceSession.sourcePath);
      if (selectedPath == null) {
        return _state;
      }
      final normalizedPath = selectedPath.trim();
      if (!_isAbsoluteWindowsPath(normalizedPath)) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.invalidDestinationPath,
            message:
                'The Save As destination must be an absolute Windows path.',
            filePath: normalizedPath,
            remediation: 'Choose the destination using the Save As dialog.',
          ),
        );
      }
      if (!_hasSupportedExtension(normalizedPath)) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.unsupportedExtension,
            message: 'Save As supports only .scm and .scx map files.',
            filePath: normalizedPath,
            remediation: 'Choose a destination ending in .scm or .scx.',
          ),
        );
      }
      if (await saveFileGateway.refersToSameLocation(
        sourceSession.sourcePath,
        normalizedPath,
      )) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.sourceDestinationSame,
            message: 'Save As cannot overwrite the currently open source map.',
            filePath: normalizedPath,
            remediation: 'Choose a different output file name.',
          ),
        );
      }
      final destinationExistedAtSaveStart = await saveFileGateway
          .destinationExists(normalizedPath);
      final replacementConfirmed = selectedFromPicker || replaceExisting;
      if (destinationExistedAtSaveStart && !replacementConfirmed) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.destinationExists,
            message: 'The Save As destination already exists.',
            filePath: normalizedPath,
            remediation:
                'Choose a new file name or explicitly confirm replacement in '
                'the Save As dialog.',
          ),
        );
      }

      final activeProgress = operationProgressController.current;
      if (activeProgress != null && !activeProgress.isTerminal) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.operationBusy,
            message: 'Another editor operation is already running.',
            filePath: normalizedPath,
            remediation:
                'Wait for the current operation to finish and try again.',
            rawDetails: 'activeOperationId=${activeProgress.operationId}',
          ),
        );
      }

      operationId =
          'save-map-${_clock().microsecondsSinceEpoch}-${++_operationSequence}';
      operationProgressController.start(
        operationId: operationId,
        label: 'Saving map as',
        message: 'Checking source map',
        canCancel: false,
      );

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.validating,
        message: 'Checking source map fingerprint',
        fraction: 0.1,
      );
      late final MapFileFingerprint sourceFingerprintAtSaveStart;
      try {
        sourceFingerprintAtSaveStart = await fingerprintGateway.fingerprint(
          sourceSession.sourcePath,
        );
      } on Object catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _sourceFingerprintFailureDiagnostic(
            path: sourceSession.sourcePath,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
      if (sourceFingerprintAtSaveStart != sourceSession.sourceFingerprint) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.sourceChangedBeforeSave,
            message:
                'The source map changed after it was opened, so Save As was '
                'stopped.',
            filePath: sourceSession.sourcePath,
            remediation:
                'Reopen the source map to review the external changes before '
                'saving.',
            rawDetails:
                'opened=${sourceSession.sourceFingerprint}; '
                'current=$sourceFingerprintAtSaveStart',
          ),
        );
      }

      MapFileFingerprint? destinationFingerprintAtSaveStart;
      if (destinationExistedAtSaveStart) {
        operationProgressController.update(
          operationId: operationId,
          phase: OperationPhase.validating,
          message: 'Checking existing destination fingerprint',
          fraction: 0.13,
        );
        try {
          destinationFingerprintAtSaveStart = await fingerprintGateway
              .fingerprint(normalizedPath);
        } on Object catch (error, stackTrace) {
          return _failOperation(
            operationId,
            _destinationFingerprintFailureDiagnostic(
              path: normalizedPath,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
      }

      try {
        workspace = await saveFileGateway.createWorkspace(normalizedPath);
      } on Object catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.workspaceFailed,
            message: 'A temporary Save As workspace could not be created.',
            filePath: normalizedPath,
            remediation:
                'Check destination folder permissions and free disk space.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.writing,
        message: 'Writing temporary map archive',
        fraction: 0.25,
      );
      final encodedChk = rawChkEncoder.encode(sourceSession.rawDocument);
      final writeResult = await archiveGateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: '$operationId-write',
          sourcePath: sourceSession.sourcePath,
          temporaryOutputPath: workspace.temporaryOutputPath,
          scenarioChkBytes: encodedChk,
          timeout: archiveTimeout,
        ),
      );
      if (!writeResult.isSuccess) {
        return _failOperationDiagnostics(operationId, writeResult.diagnostics);
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.verifying,
        message: 'Reopening and verifying temporary map',
        fraction: 0.65,
      );
      final reopenResult = await archiveGateway.open(
        MapArchiveOpenRequest(
          operationId: '$operationId-verify',
          sourcePath: workspace.temporaryOutputPath,
          timeout: archiveTimeout,
        ),
      );
      if (!reopenResult.isSuccess) {
        return _failOperationDiagnostics(operationId, reopenResult.diagnostics);
      }

      final verifiedMap = reopenResult.extractedMap!;
      if (!_bytesEqual(encodedChk, verifiedMap.scenarioChkBytes)) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.verificationBytesMismatch,
            message:
                'The reopened temporary map does not contain the expected '
                'scenario.chk bytes.',
            filePath: workspace.temporaryOutputPath,
            remediation:
                'Keep the source map unchanged and report the archive writer '
                'failure.',
            rawDetails:
                'expectedBytes=${encodedChk.length}; '
                'actualBytes=${verifiedMap.scenarioChkBytes.length}',
          ),
        );
      }

      final parseResult = rawChkParser.parse(verifiedMap.scenarioChkBytes);
      if (!parseResult.isSuccess) {
        return _failOperationDiagnostics(operationId, [
          ...reopenResult.diagnostics,
          ...parseResult.diagnostics,
          _diagnostic(
            code: SaveMapDiagnosticCodes.verificationParseFailed,
            message: 'The reopened temporary map failed CHK validation.',
            filePath: workspace.temporaryOutputPath,
            remediation:
                'Keep the source map unchanged and inspect parser diagnostics.',
          ),
        ]);
      }

      final verifiedDocument = parseResult.document!;
      final metadataViews = metadataViewDecoder.decode(verifiedDocument);
      final stringViews = stringViewDecoder.decode(verifiedDocument);
      final terrainViews = terrainViewDecoder.decode(verifiedDocument);
      final objectViews = objectViewDecoder.decode(verifiedDocument);
      final objectReferenceDiagnostics = objectReferenceValidator.validate(
        metadataViews: metadataViews,
        stringViews: stringViews,
        objectViews: objectViews,
      );
      final verifiedDiagnostics = [
        ...writeResult.diagnostics,
        ...reopenResult.diagnostics,
        ...metadataViews.diagnostics,
        ...stringViews.diagnostics,
        ...terrainViews.diagnostics,
        ...objectViews.diagnostics,
        ...objectReferenceDiagnostics,
      ];

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.verifying,
        message: 'Fingerprinting verified output',
        fraction: 0.8,
      );
      late final MapFileFingerprint verifiedOutputFingerprint;
      try {
        verifiedOutputFingerprint = await fingerprintGateway.fingerprint(
          workspace.temporaryOutputPath,
        );
      } on Object catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.outputFingerprintFailed,
            message:
                'The verified temporary map fingerprint could not be '
                'calculated.',
            filePath: workspace.temporaryOutputPath,
            remediation:
                'Check destination folder permissions and free disk space.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.verifying,
        message: 'Rechecking source map fingerprint',
        fraction: 0.88,
      );
      late final MapFileFingerprint sourceFingerprintBeforePromotion;
      try {
        sourceFingerprintBeforePromotion = await fingerprintGateway.fingerprint(
          sourceSession.sourcePath,
        );
      } on Object catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _sourceFingerprintFailureDiagnostic(
            path: sourceSession.sourcePath,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
      if (sourceFingerprintBeforePromotion != sourceFingerprintAtSaveStart) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.sourceChangedDuringSave,
            message:
                'The source map changed during Save As, so the verified '
                'output was not promoted.',
            filePath: sourceSession.sourcePath,
            remediation:
                'Reopen the source map to review the external changes and '
                'retry with a new output name.',
            rawDetails:
                'start=$sourceFingerprintAtSaveStart; '
                'beforePromotion=$sourceFingerprintBeforePromotion',
          ),
        );
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.verifying,
        message: 'Rechecking Save As destination',
        fraction: 0.89,
      );
      final destinationExistsBeforePromotion = await saveFileGateway
          .destinationExists(normalizedPath);
      if (destinationExistedAtSaveStart) {
        if (!destinationExistsBeforePromotion) {
          return _failOperation(
            operationId,
            _destinationChangedDiagnostic(
              path: normalizedPath,
              rawDetails: 'The existing destination disappeared.',
            ),
          );
        }

        late final MapFileFingerprint destinationFingerprintBeforePromotion;
        try {
          destinationFingerprintBeforePromotion = await fingerprintGateway
              .fingerprint(normalizedPath);
        } on Object catch (error, stackTrace) {
          return _failOperation(
            operationId,
            _destinationFingerprintFailureDiagnostic(
              path: normalizedPath,
              error: error,
              stackTrace: stackTrace,
            ),
          );
        }
        if (destinationFingerprintBeforePromotion !=
            destinationFingerprintAtSaveStart) {
          return _failOperation(
            operationId,
            _destinationChangedDiagnostic(
              path: normalizedPath,
              rawDetails:
                  'start=$destinationFingerprintAtSaveStart; '
                  'beforePromotion=$destinationFingerprintBeforePromotion',
            ),
          );
        }
      } else if (destinationExistsBeforePromotion) {
        return _failOperation(
          operationId,
          _destinationChangedDiagnostic(
            path: normalizedPath,
            rawDetails:
                'A destination was created after the Save As operation '
                'started.',
          ),
        );
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.writing,
        message: 'Promoting verified map to final destination',
        fraction: 0.9,
      );
      late final MapSavePromotionResult promotionResult;
      try {
        promotionResult = await saveFileGateway.promote(
          workspace: workspace,
          destinationPath: normalizedPath,
          replaceExisting: destinationExistedAtSaveStart,
        );
      } on MapSavePromotionRecoveryException catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.promotionRecoveryRequired,
            message:
                'The existing destination is safe in a backup, but automatic '
                'restoration failed.',
            filePath: error.backupPath,
            remediation:
                'Restore the backup to ${error.destinationPath} before '
                'retrying Save As.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      } on Object catch (error, stackTrace) {
        return _failOperation(
          operationId,
          _diagnostic(
            code: SaveMapDiagnosticCodes.promotionFailed,
            message:
                'The verified map could not be promoted to its destination.',
            filePath: normalizedPath,
            remediation:
                'Check destination folder permissions and choose a new name.',
            rawDetails: '$error\n$stackTrace',
          ),
        );
      }

      final finalMap = ExtractedMap(
        sourcePath: normalizedPath,
        scenarioChkBytes: verifiedMap.scenarioChkBytes,
        metadata: verifiedMap.metadata,
      );
      final adoptedState = await openMapController.adoptSavedSession(
        OpenedMapSession(
          extractedMap: finalMap,
          rawDocument: verifiedDocument,
          metadataViews: metadataViews,
          stringViews: stringViews,
          terrainViews: terrainViews,
          objectViews: objectViews,
          sourceFingerprint: verifiedOutputFingerprint,
          diagnostics: verifiedDiagnostics,
        ),
      );
      final saveDiagnostics = [...adoptedState.diagnostics];
      final backupPath = promotionResult.backupPath;
      if (backupPath != null) {
        saveDiagnostics.add(
          EditorDiagnostic(
            code: SaveMapDiagnosticCodes.backupCreated,
            message:
                'The previous destination was preserved as a recovery backup.',
            severity: DiagnosticSeverity.info,
            stage: DiagnosticStage.save,
            filePath: backupPath,
            remediation:
                'Keep the backup until the replacement map has been verified.',
          ),
        );
      }
      operationProgressController.succeed(
        operationId: operationId,
        message: backupPath == null
            ? 'Map saved and verified'
            : 'Map saved, verified, and backed up',
      );
      return _emit(
        SaveMapState.saved(
          savedPath: normalizedPath,
          backupPath: backupPath,
          diagnostics: saveDiagnostics,
        ),
      );
    } on Object catch (error, stackTrace) {
      final diagnostic = _diagnostic(
        code: SaveMapDiagnosticCodes.unexpectedFailure,
        message: 'Save As failed because of an unexpected error.',
        filePath: destinationPath,
        remediation:
            'Retry with a new output name. The source map was not modified.',
        rawDetails: '$error\n$stackTrace',
      );
      if (operationId != null) {
        final current = operationProgressController.current;
        if (current?.operationId == operationId && !current!.isTerminal) {
          return _failOperation(operationId, diagnostic);
        }
      }
      return _emitFailure(diagnostic);
    } finally {
      if (workspace != null) {
        try {
          await saveFileGateway.cleanup(workspace);
        } on Object {
          // Never widen cleanup beyond the exact owned workspace.
        }
      }
      _isSaving = false;
    }
  }

  Future<String?> _selectDestinationPath(String sourcePath) async {
    try {
      return await filePicker.pickSaveMapPath(
        suggestedName: _suggestedName(sourcePath),
      );
    } on Object catch (error, stackTrace) {
      _emitFailure(
        _diagnostic(
          code: SaveMapDiagnosticCodes.fileSelectionFailed,
          message: 'The Save As dialog could not be opened.',
          remediation: 'Retry the operation or restart the application.',
          rawDetails: '$error\n$stackTrace',
        ),
      );
      return null;
    }
  }

  SaveMapState _failOperation(String operationId, EditorDiagnostic diagnostic) {
    return _failOperationDiagnostics(operationId, [diagnostic]);
  }

  SaveMapState _failOperationDiagnostics(
    String operationId,
    Iterable<EditorDiagnostic> diagnostics,
  ) {
    final diagnosticList = List<EditorDiagnostic>.unmodifiable(diagnostics);
    operationProgressController.fail(
      operationId: operationId,
      message: _failureMessage(diagnosticList),
    );
    return _emit(SaveMapState.failed(diagnostics: diagnosticList));
  }

  SaveMapState _emitFailure(EditorDiagnostic diagnostic) =>
      _emit(SaveMapState.failed(diagnostics: [diagnostic]));

  EditorDiagnostic _sourceFingerprintFailureDiagnostic({
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return _diagnostic(
      code: SaveMapDiagnosticCodes.sourceFingerprintFailed,
      message: 'The source map fingerprint could not be verified.',
      filePath: path,
      remediation:
          'Check that the source map still exists, is readable, and is not '
          'being changed by another program.',
      rawDetails: '$error\n$stackTrace',
    );
  }

  EditorDiagnostic _destinationFingerprintFailureDiagnostic({
    required String path,
    required Object error,
    required StackTrace stackTrace,
  }) {
    return _diagnostic(
      code: SaveMapDiagnosticCodes.destinationFingerprintFailed,
      message: 'The existing Save As destination could not be verified.',
      filePath: path,
      remediation:
          'Check that the destination is a readable regular file and retry.',
      rawDetails: '$error\n$stackTrace',
    );
  }

  EditorDiagnostic _destinationChangedDiagnostic({
    required String path,
    required String rawDetails,
  }) {
    return _diagnostic(
      code: SaveMapDiagnosticCodes.destinationChangedDuringSave,
      message:
          'The Save As destination changed while the map was being prepared.',
      filePath: path,
      remediation:
          'Review the destination in another program, then retry and confirm '
          'replacement again.',
      rawDetails: rawDetails,
    );
  }

  SaveMapState _emit(SaveMapState state) {
    _state = state;
    _changes.add(state);
    return state;
  }

  EditorDiagnostic _diagnostic({
    required String code,
    required String message,
    required String remediation,
    String? filePath,
    String? rawDetails,
  }) {
    return EditorDiagnostic(
      code: code,
      message: message,
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.save,
      filePath: filePath,
      remediation: remediation,
      rawDetails: rawDetails,
    );
  }

  String _failureMessage(List<EditorDiagnostic> diagnostics) {
    for (final diagnostic in diagnostics) {
      if (diagnostic.blocksOperation) {
        return diagnostic.message;
      }
    }
    return 'The map could not be saved.';
  }

  String _suggestedName(String sourcePath) {
    final fileName = sourcePath.replaceAll('/', r'\').split(r'\').last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex <= 0) {
      return '$fileName Copy.scx';
    }
    return '${fileName.substring(0, dotIndex)} Copy'
        '${fileName.substring(dotIndex)}';
  }

  bool _hasSupportedExtension(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.scm') || lowerPath.endsWith('.scx');
  }

  bool _isAbsoluteWindowsPath(String path) {
    return RegExp(
      r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
    ).hasMatch(path);
  }

  bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> dispose() => _changes.close();
}
