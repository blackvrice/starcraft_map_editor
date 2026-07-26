import 'dart:async';

import '../../domain/chk/chk.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../operations/operation_progress.dart';
import '../operations/operation_progress_controller.dart';
import '../ports/map_archive_gateway.dart';
import '../ports/map_file_picker.dart';
import '../recent_projects/recent_projects_service.dart';
import 'opened_map_session.dart';

abstract final class OpenMapDiagnosticCodes {
  static const fileSelectionFailed = 'OPEN_MAP_FILE_SELECTION_FAILED';
  static const unsupportedExtension = 'OPEN_MAP_UNSUPPORTED_EXTENSION';
  static const operationBusy = 'OPEN_MAP_OPERATION_BUSY';
  static const recentProjectUpdateFailed =
      'OPEN_MAP_RECENT_PROJECT_UPDATE_FAILED';
  static const unexpectedFailure = 'OPEN_MAP_UNEXPECTED_FAILURE';
}

enum OpenMapStatus { idle, opened, failed }

class OpenMapState {
  const OpenMapState._({
    required this.status,
    required this.session,
    required this.diagnostics,
  });

  const OpenMapState.idle()
    : this._(status: OpenMapStatus.idle, session: null, diagnostics: const []);

  OpenMapState.opened({
    required OpenedMapSession openedSession,
    required Iterable<EditorDiagnostic> diagnostics,
  }) : this._(
         status: OpenMapStatus.opened,
         session: openedSession,
         diagnostics: List.unmodifiable(diagnostics),
       );

  OpenMapState.failed({
    required Iterable<EditorDiagnostic> diagnostics,
    OpenedMapSession? previousSession,
  }) : this._(
         status: OpenMapStatus.failed,
         session: previousSession,
         diagnostics: List.unmodifiable(diagnostics),
       );

  final OpenMapStatus status;
  final OpenedMapSession? session;
  final List<EditorDiagnostic> diagnostics;
}

class OpenMapController {
  OpenMapController({
    required this.archiveGateway,
    required this.filePicker,
    required this.recentProjectsService,
    required this.operationProgressController,
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
  final RecentProjectsService recentProjectsService;
  final OperationProgressController operationProgressController;
  final RawChkParser rawChkParser;
  final ChkMetadataViewDecoder metadataViewDecoder;
  final Duration archiveTimeout;
  final DateTime Function() _clock;
  final StreamController<OpenMapState> _changes =
      StreamController<OpenMapState>.broadcast(sync: true);

  OpenMapState _state = const OpenMapState.idle();
  bool _isOpening = false;
  int _operationSequence = 0;

  OpenMapState get state => _state;

  Stream<OpenMapState> get changes => _changes.stream;

  Future<OpenMapState> open({String? sourcePath}) async {
    if (_isOpening) {
      return _state;
    }
    _isOpening = true;

    final selectedPath = sourcePath ?? await _selectMapPath();
    if (selectedPath == null) {
      _isOpening = false;
      return _state;
    }

    final normalizedPath = selectedPath.trim();
    if (!_hasSupportedExtension(normalizedPath)) {
      _isOpening = false;
      return _emitFailure(
        EditorDiagnostic(
          code: OpenMapDiagnosticCodes.unsupportedExtension,
          message: 'Only .scm and .scx map files can be opened.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.application,
          filePath: normalizedPath,
          remediation: 'Choose a StarCraft map with a .scm or .scx extension.',
        ),
      );
    }

    final activeProgress = operationProgressController.current;
    if (activeProgress != null && !activeProgress.isTerminal) {
      _isOpening = false;
      return _emitFailure(
        EditorDiagnostic(
          code: OpenMapDiagnosticCodes.operationBusy,
          message: 'Another editor operation is already running.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.application,
          filePath: normalizedPath,
          remediation:
              'Wait for the current operation to finish and try again.',
          rawDetails: 'activeOperationId=${activeProgress.operationId}',
        ),
      );
    }

    final operationId =
        'open-map-${_clock().microsecondsSinceEpoch}-${++_operationSequence}';
    operationProgressController.start(
      operationId: operationId,
      label: 'Opening map',
      message: 'Reading map archive',
      canCancel: false,
    );

    try {
      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.reading,
        message: 'Reading map archive',
        fraction: 0.15,
      );
      final archiveResult = await archiveGateway.open(
        MapArchiveOpenRequest(
          operationId: operationId,
          sourcePath: normalizedPath,
          timeout: archiveTimeout,
        ),
      );
      if (!archiveResult.isSuccess) {
        operationProgressController.fail(
          operationId: operationId,
          message: _failureMessage(archiveResult.diagnostics),
        );
        return _emit(
          OpenMapState.failed(
            diagnostics: archiveResult.diagnostics,
            previousSession: _state.session,
          ),
        );
      }

      final extractedMap = archiveResult.extractedMap!;
      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.parsing,
        message: 'Parsing scenario.chk',
        fraction: 0.55,
      );
      final parseResult = rawChkParser.parse(extractedMap.scenarioChkBytes);
      if (!parseResult.isSuccess) {
        final diagnostics = [
          ...archiveResult.diagnostics,
          ...parseResult.diagnostics,
        ];
        operationProgressController.fail(
          operationId: operationId,
          message: _failureMessage(diagnostics),
        );
        return _emit(
          OpenMapState.failed(
            diagnostics: diagnostics,
            previousSession: _state.session,
          ),
        );
      }

      operationProgressController.update(
        operationId: operationId,
        phase: OperationPhase.validating,
        message: 'Validating map metadata',
        fraction: 0.8,
      );
      final rawDocument = parseResult.document!;
      final metadataViews = metadataViewDecoder.decode(rawDocument);
      final documentDiagnostics = [
        ...archiveResult.diagnostics,
        ...metadataViews.diagnostics,
      ];
      final session = OpenedMapSession(
        extractedMap: extractedMap,
        rawDocument: rawDocument,
        metadataViews: metadataViews,
        diagnostics: documentDiagnostics,
      );
      final operationDiagnostics = [...documentDiagnostics];

      try {
        await recentProjectsService.recordOpened(
          normalizedPath,
          openedAt: _clock(),
        );
      } on Object catch (error) {
        operationDiagnostics.add(
          EditorDiagnostic(
            code: OpenMapDiagnosticCodes.recentProjectUpdateFailed,
            message:
                'The map opened, but the recent maps list was not updated.',
            severity: DiagnosticSeverity.warning,
            stage: DiagnosticStage.application,
            filePath: normalizedPath,
            remediation:
                'Check access to the application settings folder and reopen '
                'the map.',
            rawDetails: '$error',
          ),
        );
      }

      operationProgressController.succeed(
        operationId: operationId,
        message: session.requiresRestrictedEditing
            ? 'Map opened in restricted read-only mode'
            : 'Map opened',
      );
      return _emit(
        OpenMapState.opened(
          openedSession: session,
          diagnostics: operationDiagnostics,
        ),
      );
    } on Object catch (error, stackTrace) {
      final diagnostic = EditorDiagnostic(
        code: OpenMapDiagnosticCodes.unexpectedFailure,
        message: 'The map could not be opened because of an unexpected error.',
        severity: DiagnosticSeverity.fatal,
        stage: DiagnosticStage.application,
        filePath: normalizedPath,
        remediation:
            'Retry the operation. If it fails again, inspect the application '
            'log.',
        rawDetails: '$error\n$stackTrace',
      );
      final currentProgress = operationProgressController.current;
      if (currentProgress?.operationId == operationId &&
          !currentProgress!.isTerminal) {
        operationProgressController.fail(
          operationId: operationId,
          message: diagnostic.message,
        );
      }
      return _emitFailure(diagnostic);
    } finally {
      _isOpening = false;
    }
  }

  Future<String?> _selectMapPath() async {
    try {
      return await filePicker.pickMapPath();
    } on Object catch (error, stackTrace) {
      _emitFailure(
        EditorDiagnostic(
          code: OpenMapDiagnosticCodes.fileSelectionFailed,
          message: 'The map file dialog could not be opened.',
          severity: DiagnosticSeverity.error,
          stage: DiagnosticStage.application,
          remediation: 'Retry the operation or restart the application.',
          rawDetails: '$error\n$stackTrace',
        ),
      );
      return null;
    }
  }

  OpenMapState _emitFailure(EditorDiagnostic diagnostic) {
    return _emit(
      OpenMapState.failed(
        diagnostics: [diagnostic],
        previousSession: _state.session,
      ),
    );
  }

  OpenMapState _emit(OpenMapState state) {
    _state = state;
    _changes.add(state);
    return state;
  }

  String _failureMessage(List<EditorDiagnostic> diagnostics) {
    for (final diagnostic in diagnostics) {
      if (diagnostic.blocksOperation) {
        return diagnostic.message;
      }
    }
    return 'The map could not be opened.';
  }

  bool _hasSupportedExtension(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.scm') || lowerPath.endsWith('.scx');
  }

  Future<void> dispose() => _changes.close();
}
