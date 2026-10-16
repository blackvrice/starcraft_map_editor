import 'dart:async';
import '../../application/ports/unit_creep_capture_gateway.dart';
import '../../application/ports/unit_creep_state_gateway.dart';
import '../../domain/placement/unit_creep_catalog.dart';
import 'unit_creep_capture_input.dart';

/// Explicitly injected intake only. Does not launch or register a collector.
final class ValidatedUnitCreepStateGateway implements UnitCreepStateGateway {
  ValidatedUnitCreepStateGateway({
    required this.captureGateway,
    required this.configuration,
    this.timeout = const Duration(seconds: 30),
  }) {
    if (timeout <= Duration.zero) {
      throw ArgumentError('Invalid capture timeout.');
    }
  }
  final UnitCreepCaptureGateway captureGateway;
  final UnitCreepCaptureConfiguration configuration;
  final Duration timeout;
  static const maximumLogCodeUnits = 65536;
  final _active = <String, _CaptureOperation>{};

  @override
  Future<UnitCreepStateReadResult> read(UnitCreepStateRequest request) async {
    if (_active.containsKey(request.operationId)) {
      return const UnitCreepStateReadResult(
        errorCode: 'UNIT_CREEP_CAPTURE_ACTIVE',
      );
    }
    final UnitCreepCaptureRequest input;
    try {
      input = UnitCreepCaptureInput.prepare(request, configuration);
    } catch (error) {
      return UnitCreepStateReadResult(
        errorCode: 'UNIT_CREEP_CAPTURE_INPUT_INVALID',
        stderr: _bounded('$error'),
      );
    }
    final operation = _CaptureOperation(input);
    _active[request.operationId] = operation;
    final timer = Timer(
      timeout,
      () => _stop(operation, 'UNIT_CREEP_CAPTURE_TIMED_OUT'),
    );
    try {
      final result = await Future.any([
        Future.sync(() => captureGateway.capture(input)),
        operation.stopped.future.then(
          (code) => UnitCreepCaptureReadResult(errorCode: code),
        ),
      ]);
      final stdout = _bounded(result.stdout), stderr = _bounded(result.stderr);
      UnitCreepStateReadResult failure(String code) => UnitCreepStateReadResult(
        errorCode: code,
        exitCode: result.exitCode,
        stdout: stdout,
        stderr: stderr,
      );
      if (operation.stopped.isCompleted) {
        return failure(await operation.stopped.future);
      }
      if (result.stdout.length > maximumLogCodeUnits ||
          result.stderr.length > maximumLogCodeUnits) {
        return failure('UNIT_CREEP_CAPTURE_OUTPUT_LIMIT');
      }
      if (result.errorCode != null ||
          (result.exitCode != null && result.exitCode != 0)) {
        return failure('UNIT_CREEP_CAPTURE_FAILED');
      }
      final capture = result.capture;
      if (capture == null ||
          !identical(capture.request, input) ||
          capture.capturedInputRevision != input.inputRevision ||
          capture.providerId != configuration.providerId ||
          !validCaptureText(capture.revision) ||
          capture.observation.collectorVersion !=
              configuration.collectorVersion ||
          !configuration.supportedGameVersions.contains(
            capture.observation.gameVersion,
          ) ||
          capture.observation.gameSessionId != configuration.gameSessionId ||
          capture.observation.setupRevision != input.setupRevision) {
        return failure('UNIT_CREEP_CAPTURE_RESPONSE_INVALID');
      }
      final observation = capture.observation;
      final stateIdentity = [
        input.inputRevision,
        capture.revision,
        observation.contractRevision,
        observation.gameVersion,
        observation.collectorVersion,
        observation.gameSessionId,
        observation.phase.name,
        observation.gameFrame,
        observation.simulationFrame,
        observation.authority.name,
        observation.observerPlayer,
        observation.width,
        observation.height,
        observation.observedTiles,
        capture.coverage.tiles.map((v) => v.index).toList(),
      ];
      final snapshot = UnitCreepStateSnapshot(
        request: request,
        providerId: capture.providerId,
        revision: 'captured-creep-v1:${creepCaptureDigest(stateIdentity)}',
        model: request.model,
        creepModelRevision: UnitCreepCatalog.revision,
        observation: capture.observation,
        coverage: capture.coverage,
      );
      if (snapshot.coverageFor(request) == null) {
        return failure('UNIT_CREEP_CAPTURE_RESPONSE_INVALID');
      }
      return UnitCreepStateReadResult(
        snapshot: snapshot,
        exitCode: result.exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } catch (error) {
      if (operation.stopped.isCompleted) {
        return UnitCreepStateReadResult(
          errorCode: await operation.stopped.future,
        );
      }
      return UnitCreepStateReadResult(
        errorCode: 'UNIT_CREEP_CAPTURE_EXCEPTION',
        stderr: _bounded('$error'),
      );
    } finally {
      timer.cancel();
      if (identical(_active[request.operationId], operation)) {
        _active.remove(request.operationId);
      }
    }
  }

  String _bounded(String text) => text.length <= maximumLogCodeUnits
      ? text
      : text.substring(0, maximumLogCodeUnits);

  void _stop(_CaptureOperation operation, String code) {
    if (operation.stopped.isCompleted) return;
    operation.stopped.complete(code);
    final id = operation.request.stateRequest.operationId;
    if (identical(_active[id], operation)) _active.remove(id);
    // Request identity owns cancellation; reusing an ID must not cancel a retry.
    unawaited(
      Future.sync(
        () => captureGateway.cancel(operation.request),
      ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  @override
  Future<void> cancel(String operationId) async {
    final operation = _active[operationId];
    if (operation != null) _stop(operation, 'UNIT_CREEP_CAPTURE_CANCELLED');
  }
}

final class _CaptureOperation {
  _CaptureOperation(this.request);
  final UnitCreepCaptureRequest request;
  final stopped = Completer<String>();
}
