import 'dart:async';

import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../operations/operation_progress.dart';
import '../operations/operation_progress_controller.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/map_file_picker.dart';
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
  static const operationBusy = 'SAVE_MAP_OPERATION_BUSY';
  static const workspaceFailed = 'SAVE_MAP_WORKSPACE_FAILED';
  static const verificationBytesMismatch =
      'SAVE_MAP_VERIFICATION_BYTES_MISMATCH';
  static const verificationParseFailed = 'SAVE_MAP_VERIFICATION_PARSE_FAILED';
  static const promotionFailed = 'SAVE_MAP_PROMOTION_FAILED';
  static const unexpectedFailure = 'SAVE_MAP_UNEXPECTED_FAILURE';
}

enum SaveMapStatus { idle, saved, failed }

class SaveMapState {
  const SaveMapState._({
    required this.status,
    required this.outputPath,
    required this.diagnostics,
  });

  const SaveMapState.idle()
    : this._(
        status: SaveMapStatus.idle,
        outputPath: null,
        diagnostics: const [],
      );

  SaveMapState.saved({
    required String savedPath,
    required Iterable<EditorDiagnostic> diagnostics,
  }) : this._(
         status: SaveMapStatus.saved,
         outputPath: savedPath,
         diagnostics: List.unmodifiable(diagnostics),
       );

  SaveMapState.failed({required Iterable<EditorDiagnostic> diagnostics})
    : this._(
        status: SaveMapStatus.failed,
        outputPath: null,
        diagnostics: List.unmodifiable(diagnostics),
      );

  final SaveMapStatus status;
  final String? outputPath;
  final List<EditorDiagnostic> diagnostics;
}

class SaveMapController {
  SaveMapController({
    required this.archiveGateway,
    required this.filePicker,
    required this.saveFileGateway,
    required this.openMapController,
    required this.operationProgressController,
    this.rawChkEncoder = const RawChkEncoder(),
    this.rawChkParser = const RawChkParser(),
    this.metadataViewDecoder = const ChkMetadataViewDecoder(),
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
  final MapSaveFileGateway saveFileGateway;
  final OpenMapController openMapController;
  final OperationProgressController operationProgressController;
  final RawChkEncoder rawChkEncoder;
  final RawChkParser rawChkParser;
  final ChkMetadataViewDecoder metadataViewDecoder;
  final Duration archiveTimeout;
  final DateTime Function() _clock;
  final StreamController<SaveMapState> _changes =
      StreamController<SaveMapState>.broadcast(sync: true);

  SaveMapState _state = const SaveMapState.idle();
  bool _isSaving = false;
  int _operationSequence = 0;

  SaveMapState get state => _state;

  Stream<SaveMapState> get changes => _changes.stream;

  Future<SaveMapState> saveAs({String? destinationPath}) async {
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
      if (await saveFileGateway.destinationExists(normalizedPath)) {
        return _emitFailure(
          _diagnostic(
            code: SaveMapDiagnosticCodes.destinationExists,
            message: 'The Save As destination already exists.',
            filePath: normalizedPath,
            remediation:
                'Choose a new file name. Existing files are never replaced '
                'in this safety milestone.',
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
        message: 'Creating temporary output',
        canCancel: false,
      );

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
      final verifiedDiagnostics = [
        ...writeResult.diagnostics,
        ...reopenResult.diagnostics,
        ...metadataViews.diagnostics,
      ];

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.writing,
        message: 'Promoting verified map to final destination',
        fraction: 0.9,
      );
      try {
        await saveFileGateway.promote(
          workspace: workspace,
          destinationPath: normalizedPath,
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
          diagnostics: verifiedDiagnostics,
        ),
      );
      operationProgressController.succeed(
        operationId: operationId,
        message: 'Map saved and verified',
      );
      return _emit(
        SaveMapState.saved(
          savedPath: normalizedPath,
          diagnostics: adoptedState.diagnostics,
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
