import '../documents/document_path_lease.dart';
import '../ports/eud_build_gateway.dart';
import '../ports/eud_compiler_models.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

/// The reservation outlives every compiler event, including cancellation.
final class ReservedEudBuildGateway implements EudBuildGateway {
  ReservedEudBuildGateway({required this.delegate, required this.reserve});
  final EudBuildGateway delegate;
  final DocumentPathReserver reserve;
  final _queued = <String>{}, _executing = <String>{}, _cancelled = <String>{};
  @override
  Stream<EudBuildEvent> build(EudBuildPlan plan) {
    if (!_queued.add(plan.buildId)) {
      throw StateError('WORKSPACE_BUILD_ALREADY_ACTIVE');
    }
    return _build(plan);
  }

  EudBuildEvent _cancelledEvent(String id) => EudBuildEvent.cancelled(
    buildId: id,
    diagnostic: const EditorDiagnostic(
      code: 'WORKSPACE_BUILD_CANCELLED',
      message: 'Build cancelled before the compiler started.',
      severity: DiagnosticSeverity.error,
      stage: DiagnosticStage.compile,
    ),
  );
  Stream<EudBuildEvent> _build(EudBuildPlan plan) async* {
    DocumentPathLease? lease;
    try {
      if (_cancelled.contains(plan.buildId)) {
        yield _cancelledEvent(plan.buildId);
        return;
      }
      lease = await reserve(plan.configuration.outputMapPath);
      if (_cancelled.contains(plan.buildId)) {
        yield _cancelledEvent(plan.buildId);
        return;
      }
      _executing.add(plan.buildId);
      yield* delegate.build(plan);
    } on Object {
      if (!_executing.contains(plan.buildId) &&
          _cancelled.contains(plan.buildId)) {
        yield _cancelledEvent(plan.buildId);
      } else {
        rethrow;
      }
    } finally {
      _queued.remove(plan.buildId);
      _executing.remove(plan.buildId);
      _cancelled.remove(plan.buildId);
      lease?.release();
    }
  }

  @override
  Future<bool> cancel(String buildId) {
    // Queue ownership starts before listen, so immediate cancellation cannot
    // accidentally launch a compiler after a slow path check finishes.
    if (_queued.contains(buildId) && !_executing.contains(buildId)) {
      _cancelled.add(buildId);
      return Future.value(true);
    }
    return delegate.cancel(buildId);
  }
}
