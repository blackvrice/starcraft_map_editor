enum OperationPhase {
  queued,
  reading,
  parsing,
  validating,
  writing,
  compiling,
  verifying,
  succeeded,
  failed,
  cancelled,
}

class OperationProgress {
  const OperationProgress({
    required this.operationId,
    required this.label,
    required this.phase,
    required this.startedAt,
    this.message,
    this.fraction,
    this.canCancel = false,
    this.completedAt,
  }) : assert(fraction == null || (fraction >= 0 && fraction <= 1));

  final String operationId;
  final String label;
  final OperationPhase phase;
  final DateTime startedAt;
  final String? message;
  final double? fraction;
  final bool canCancel;
  final DateTime? completedAt;

  bool get isTerminal =>
      phase == OperationPhase.succeeded ||
      phase == OperationPhase.failed ||
      phase == OperationPhase.cancelled;

  OperationProgress copyWith({
    OperationPhase? phase,
    String? message,
    double? fraction,
    bool? canCancel,
    DateTime? completedAt,
  }) {
    return OperationProgress(
      operationId: operationId,
      label: label,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      message: message ?? this.message,
      fraction: fraction ?? this.fraction,
      canCancel: canCancel ?? this.canCancel,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
