import 'dart:async';

import '../../domain/diagnostics/editor_diagnostic.dart';
import '../operations/operation_progress.dart';
import '../operations/operation_progress_controller.dart';
import '../ports/eud_compiler_gateway.dart';
import 'eud_build_record.dart';

abstract final class EudBuildControllerDiagnosticCodes {
  static const eventStreamFailed = 'EUD_BUILD_EVENT_STREAM_FAILED';
  static const eventStreamEnded = 'EUD_BUILD_EVENT_STREAM_ENDED';
  static const eventBuildIdMismatch = 'EUD_BUILD_EVENT_ID_MISMATCH';
}

enum EudBuildStatus {
  notConfigured,
  ready,
  running,
  cancelling,
  succeeded,
  failed,
  cancelled,
}

final class EudBuildState {
  EudBuildState._({
    required this.status,
    required this.request,
    required Iterable<EudBuildEvent> events,
    required Iterable<EudBuildRecord> records,
  }) : events = List.unmodifiable(events),
       records = List.unmodifiable(records);

  factory EudBuildState.notConfigured({
    Iterable<EudBuildRecord> records = const [],
  }) {
    return EudBuildState._(
      status: EudBuildStatus.notConfigured,
      request: null,
      events: const [],
      records: records,
    );
  }

  factory EudBuildState.ready(
    EudBuildRequest request, {
    Iterable<EudBuildRecord> records = const [],
  }) {
    return EudBuildState._(
      status: EudBuildStatus.ready,
      request: request,
      events: const [],
      records: records,
    );
  }

  final EudBuildStatus status;
  final EudBuildRequest? request;
  final List<EudBuildEvent> events;
  final List<EudBuildRecord> records;

  EudBuildRecord? get latestRecord => records.isEmpty ? null : records.last;

  bool get isConfigured => request != null;

  bool get isActive =>
      status == EudBuildStatus.running || status == EudBuildStatus.cancelling;

  bool get canCancel => status == EudBuildStatus.running;

  bool get isTerminal =>
      status == EudBuildStatus.succeeded ||
      status == EudBuildStatus.failed ||
      status == EudBuildStatus.cancelled;

  List<EditorDiagnostic> get diagnostics =>
      List.unmodifiable([for (final event in events) ?event.diagnostic]);

  EudBuildState transition(
    EudBuildStatus status, {
    EudBuildEvent? event,
    EudBuildRecord? record,
  }) {
    return EudBuildState._(
      status: status,
      request: request,
      events: [...events, ?event],
      records: _replaceLatestRecord(record),
    );
  }

  EudBuildState append(EudBuildEvent event, {EudBuildRecord? record}) {
    return EudBuildState._(
      status: status,
      request: request,
      events: [...events, event],
      records: _replaceLatestRecord(record),
    );
  }

  List<EudBuildRecord> _replaceLatestRecord(EudBuildRecord? record) {
    if (record == null) {
      return records;
    }
    if (records.isEmpty || records.last.buildId != record.buildId) {
      throw StateError('The latest EUD build record does not match.');
    }
    return [...records.take(records.length - 1), record];
  }
}

final class EudBuildController {
  EudBuildController({
    required this.compilerGateway,
    required this.operationProgressController,
    DateTime Function()? clock,
    this.maximumBuildRecords = 20,
  }) : _clock = clock ?? DateTime.now {
    if (maximumBuildRecords <= 0) {
      throw RangeError.value(
        maximumBuildRecords,
        'maximumBuildRecords',
        'The maximum build record count must be positive.',
      );
    }
  }

  final EudCompilerGateway compilerGateway;
  final OperationProgressController operationProgressController;
  final int maximumBuildRecords;
  final DateTime Function() _clock;
  final StreamController<EudBuildState> _changes =
      StreamController<EudBuildState>.broadcast(sync: true);

  EudBuildState _state = EudBuildState.notConfigured();
  StreamSubscription<EudBuildEvent>? _subscription;
  Completer<bool>? _completion;
  bool _disposed = false;

  EudBuildState get state => _state;
  Stream<EudBuildState> get changes => _changes.stream;

  bool get canStart {
    final progress = operationProgressController.current;
    final operationAvailable = progress == null || progress.isTerminal;
    return !_disposed &&
        _state.isConfigured &&
        !_state.isActive &&
        _subscription == null &&
        operationAvailable;
  }

  void prepare(EudBuildRequest request) {
    _requireNotDisposed();
    if (_state.isActive || _subscription != null) {
      throw StateError('Cannot replace an active EUD build request.');
    }
    _emit(EudBuildState.ready(request, records: _state.records));
  }

  void clearPreparation() {
    _requireNotDisposed();
    if (_state.isActive || _subscription != null) {
      throw StateError('Cannot clear an active EUD build request.');
    }
    _emit(EudBuildState.notConfigured(records: _state.records));
  }

  Future<bool> start() {
    _requireNotDisposed();
    if (!canStart) {
      return Future.value(false);
    }

    final request = _state.request!;
    operationProgressController.start(
      operationId: request.buildId,
      label: 'Building EUD map',
      message: 'Waiting for euddraft to start',
      canCancel: true,
    );
    _emit(
      EudBuildState._(
        status: EudBuildStatus.running,
        request: request,
        events: const [],
        records: _appendBuildRecord(
          EudBuildRecord.running(
            buildId: request.buildId,
            toolVersion: request.tool.version,
            startedAt: _clock(),
          ),
        ),
      ),
    );

    final completion = Completer<bool>();
    _completion = completion;
    try {
      var completedDuringListen = false;
      final subscription = compilerGateway
          .build(request)
          .listen(
            _handleEvent,
            onError: (Object error, StackTrace stackTrace) {
              unawaited(compilerGateway.cancel(request.buildId));
              _finishUnexpectedly(
                code: EudBuildControllerDiagnosticCodes.eventStreamFailed,
                message: 'The euddraft event stream failed unexpectedly.',
                rawDetails: '$error\n$stackTrace',
              );
            },
            onDone: () {
              completedDuringListen = true;
              _handleDone();
            },
          );
      if (!completedDuringListen) {
        _subscription = subscription;
      }
    } on Object catch (error, stackTrace) {
      _finishUnexpectedly(
        code: EudBuildControllerDiagnosticCodes.eventStreamFailed,
        message: 'The euddraft build could not be started.',
        rawDetails: '$error\n$stackTrace',
      );
      _subscription = null;
      _complete(false);
    }
    return completion.future;
  }

  Future<bool> cancel() async {
    _requireNotDisposed();
    if (!_state.canCancel) {
      return false;
    }

    final request = _state.request!;
    _emit(_state.transition(EudBuildStatus.cancelling));
    operationProgressController.update(
      operationId: request.buildId,
      phase: OperationPhase.compiling,
      message: 'Stopping euddraft',
      canCancel: false,
    );

    final bool accepted;
    try {
      accepted = await compilerGateway.cancel(request.buildId);
    } on Object catch (error, stackTrace) {
      _finishUnexpectedly(
        code: EudBuildControllerDiagnosticCodes.eventStreamFailed,
        message: 'The EUD build cancellation request failed.',
        rawDetails: '$error\n$stackTrace',
      );
      final subscription = _subscription;
      _subscription = null;
      try {
        await subscription?.cancel();
      } on Object {
        // The cancellation failure is already captured in the build record.
      }
      _complete(false);
      return false;
    }
    if (!accepted &&
        _state.status == EudBuildStatus.cancelling &&
        _state.request?.buildId == request.buildId) {
      _emit(_state.transition(EudBuildStatus.running));
      operationProgressController.update(
        operationId: request.buildId,
        phase: OperationPhase.compiling,
        message: 'euddraft is still running',
        canCancel: true,
      );
    }
    return accepted;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final completion = _completion;
    if (completion != null && !completion.isCompleted) {
      completion.complete(false);
    }
    _completion = null;
    await _changes.close();
  }

  void _handleEvent(EudBuildEvent event) {
    final request = _state.request;
    if (request == null || event.buildId != request.buildId) {
      if (request != null) {
        unawaited(compilerGateway.cancel(request.buildId));
      }
      _finishUnexpectedly(
        code: EudBuildControllerDiagnosticCodes.eventBuildIdMismatch,
        message: 'euddraft returned an event for a different build.',
        rawDetails: 'expected=${request?.buildId}; actual=${event.buildId}',
      );
      return;
    }
    if (!_state.isActive) {
      return;
    }

    final record = _requireLatestRecord(request.buildId);
    switch (event.kind) {
      case EudBuildEventKind.started:
        _emit(
          _state.append(
            event,
            record: record.withToolVersion(
              event.toolVersion ?? record.toolVersion,
            ),
          ),
        );
        final cancelling = _state.status == EudBuildStatus.cancelling;
        operationProgressController.update(
          operationId: request.buildId,
          phase: OperationPhase.compiling,
          message: cancelling
              ? 'Stopping euddraft'
              : 'euddraft ${event.toolVersion} is running',
          canCancel: !cancelling,
        );
        return;
      case EudBuildEventKind.stdoutLine:
        _emit(
          _state.append(
            event,
            record: record.appendLog(
              channel: EudBuildLogChannel.stdout,
              text: event.text ?? '',
              capturedAt: _clock(),
            ),
          ),
        );
        return;
      case EudBuildEventKind.stderrLine:
        _emit(
          _state.append(
            event,
            record: record.appendLog(
              channel: EudBuildLogChannel.stderr,
              text: event.text ?? '',
              capturedAt: _clock(),
            ),
          ),
        );
        return;
      case EudBuildEventKind.diagnostic:
        _emit(
          _state.append(
            event,
            record: event.diagnostic == null
                ? record
                : record.appendDiagnostic(event.diagnostic!),
          ),
        );
        return;
      case EudBuildEventKind.cancelled:
        _emit(
          _state.transition(
            EudBuildStatus.cancelled,
            event: event,
            record: record.complete(
              status: EudBuildRecordStatus.cancelled,
              completedAt: _clock(),
              exitCode: event.exitCode,
              diagnostic: event.diagnostic,
            ),
          ),
        );
        operationProgressController.cancel(
          operationId: request.buildId,
          message: event.diagnostic?.message ?? 'EUD build was cancelled',
        );
        return;
      case EudBuildEventKind.failed:
        _emit(
          _state.transition(
            EudBuildStatus.failed,
            event: event,
            record: record.complete(
              status: EudBuildRecordStatus.failed,
              completedAt: _clock(),
              exitCode: event.exitCode,
              diagnostic: event.diagnostic,
            ),
          ),
        );
        operationProgressController.fail(
          operationId: request.buildId,
          message: event.diagnostic?.message ?? 'EUD build failed',
        );
        return;
      case EudBuildEventKind.succeeded:
        _emit(
          _state.transition(
            EudBuildStatus.succeeded,
            event: event,
            record: record.complete(
              status: EudBuildRecordStatus.succeeded,
              completedAt: _clock(),
              exitCode: event.exitCode,
            ),
          ),
        );
        operationProgressController.succeed(
          operationId: request.buildId,
          message: 'EUD build process completed',
        );
        return;
    }
  }

  void _handleDone() {
    _subscription = null;
    if (_state.isActive) {
      _finishUnexpectedly(
        code: EudBuildControllerDiagnosticCodes.eventStreamEnded,
        message: 'The euddraft event stream ended without a result.',
      );
    }
    _complete(_state.status == EudBuildStatus.succeeded);
    if (!_disposed) {
      _emit(_state);
    }
  }

  void _finishUnexpectedly({
    required String code,
    required String message,
    String? rawDetails,
  }) {
    if (!_state.isActive) {
      return;
    }
    final request = _state.request!;
    final event = EudBuildEvent.failed(
      buildId: request.buildId,
      diagnostic: EditorDiagnostic(
        code: code,
        message: message,
        severity: DiagnosticSeverity.error,
        stage: DiagnosticStage.compile,
        filePath: request.settingsFilePath,
        remediation: 'Inspect the build log and retry.',
        rawDetails: rawDetails,
      ),
    );
    final record = _requireLatestRecord(request.buildId).complete(
      status: EudBuildRecordStatus.failed,
      completedAt: _clock(),
      diagnostic: event.diagnostic,
    );
    _emit(
      _state.transition(EudBuildStatus.failed, event: event, record: record),
    );
    operationProgressController.fail(
      operationId: request.buildId,
      message: message,
    );
  }

  void _complete(bool succeeded) {
    final completion = _completion;
    if (completion != null && !completion.isCompleted) {
      completion.complete(succeeded);
    }
    _completion = null;
  }

  List<EudBuildRecord> _appendBuildRecord(EudBuildRecord record) {
    final records = [..._state.records, record];
    if (records.length <= maximumBuildRecords) {
      return records;
    }
    return records.sublist(records.length - maximumBuildRecords);
  }

  EudBuildRecord _requireLatestRecord(String buildId) {
    final record = _state.latestRecord;
    if (record == null || record.buildId != buildId) {
      throw StateError('Build $buildId does not have an active record.');
    }
    return record;
  }

  void _emit(EudBuildState state) {
    _state = state;
    if (!_disposed) {
      _changes.add(state);
    }
  }

  void _requireNotDisposed() {
    if (_disposed) {
      throw StateError('The EUD build controller has been disposed.');
    }
  }
}
