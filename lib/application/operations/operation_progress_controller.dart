import 'dart:async';

import 'operation_progress.dart';

class OperationProgressController {
  final StreamController<OperationProgress?> _changes =
      StreamController<OperationProgress?>.broadcast(sync: true);

  OperationProgress? _current;

  OperationProgress? get current => _current;
  Stream<OperationProgress?> get changes => _changes.stream;

  void start({
    required String operationId,
    required String label,
    String? message,
    bool canCancel = false,
    DateTime? startedAt,
  }) {
    if (_current case final current? when !current.isTerminal) {
      throw StateError('Operation ${current.operationId} is still active.');
    }

    _emit(
      OperationProgress(
        operationId: operationId,
        label: label,
        phase: OperationPhase.queued,
        startedAt: startedAt ?? DateTime.now(),
        message: message,
        canCancel: canCancel,
      ),
    );
  }

  void update({
    required String operationId,
    required OperationPhase phase,
    String? message,
    double? fraction,
    bool? canCancel,
  }) {
    final current = _requireCurrent(operationId);
    if (current.isTerminal) {
      throw StateError('Operation $operationId has already completed.');
    }
    if (_isTerminalPhase(phase)) {
      throw ArgumentError.value(
        phase,
        'phase',
        'Use succeed, fail, or cancel for a terminal phase.',
      );
    }

    _emit(
      current.copyWith(
        phase: phase,
        message: message,
        fraction: fraction,
        canCancel: canCancel,
      ),
    );
  }

  void succeed({
    required String operationId,
    String? message,
    DateTime? completedAt,
  }) {
    _finish(
      operationId: operationId,
      phase: OperationPhase.succeeded,
      message: message,
      fraction: 1,
      completedAt: completedAt,
    );
  }

  void fail({
    required String operationId,
    required String message,
    DateTime? completedAt,
  }) {
    _finish(
      operationId: operationId,
      phase: OperationPhase.failed,
      message: message,
      completedAt: completedAt,
    );
  }

  void cancel({
    required String operationId,
    String? message,
    DateTime? completedAt,
  }) {
    _finish(
      operationId: operationId,
      phase: OperationPhase.cancelled,
      message: message,
      completedAt: completedAt,
    );
  }

  void clear() {
    final current = _current;
    if (current != null && !current.isTerminal) {
      throw StateError('Cannot clear an active operation.');
    }
    _emit(null);
  }

  Future<void> dispose() => _changes.close();

  OperationProgress _requireCurrent(String operationId) {
    final current = _current;
    if (current == null || current.operationId != operationId) {
      throw StateError('Operation $operationId is not active.');
    }
    return current;
  }

  void _finish({
    required String operationId,
    required OperationPhase phase,
    required String? message,
    double? fraction,
    DateTime? completedAt,
  }) {
    final current = _requireCurrent(operationId);
    if (current.isTerminal) {
      throw StateError('Operation $operationId has already completed.');
    }

    _emit(
      current.copyWith(
        phase: phase,
        message: message,
        fraction: fraction,
        canCancel: false,
        completedAt: completedAt ?? DateTime.now(),
      ),
    );
  }

  bool _isTerminalPhase(OperationPhase phase) =>
      phase == OperationPhase.succeeded ||
      phase == OperationPhase.failed ||
      phase == OperationPhase.cancelled;

  void _emit(OperationProgress? progress) {
    _current = progress;
    _changes.add(progress);
  }
}
