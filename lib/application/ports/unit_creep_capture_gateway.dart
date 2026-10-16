import 'dart:typed_data';

import '../../domain/placement/unit_creep_coverage.dart';
import '../../domain/placement/unit_creep_observation.dart';
import '../documents/pending_map_resources.dart';
import 'unit_creep_state_gateway.dart';

/// Implementations must verify/export the exact input before observing an engine.
/// No implementation, supported game build or automatic execution is bundled.
abstract interface class UnitCreepCaptureGateway {
  Future<UnitCreepCaptureReadResult> capture(UnitCreepCaptureRequest request);
  Future<void> cancel(UnitCreepCaptureRequest request);
}

final class UnitCreepCaptureRequest {
  UnitCreepCaptureRequest({
    required this.stateRequest,
    required this.inputRevision,
    required this.scenarioChkSha256,
    required this.baseArchiveSha256,
    required this.setupRevision,
    required List<int> scenarioChkBytes,
    required List<int> setupBytes,
    required this.setupSchema,
    required Map<String, List<int>?> resourceEdits,
  }) : scenarioChkBytes = _captureBytes(scenarioChkBytes),
       setupBytes = _captureBytes(setupBytes),
       resourceEdits = PendingMapResources(resourceEdits);

  final UnitCreepStateRequest stateRequest;
  final String inputRevision, scenarioChkSha256, setupRevision, setupSchema;
  final String? baseArchiveSha256;
  final List<int> scenarioChkBytes, setupBytes;
  final Map<String, List<int>?> resourceEdits;
}

final class UnitCreepCapture {
  const UnitCreepCapture({
    required this.request,
    required this.capturedInputRevision,
    required this.providerId,
    required this.revision,
    required this.observation,
    required this.coverage,
  });
  final UnitCreepCaptureRequest request;
  final String capturedInputRevision, providerId, revision;
  final UnitCreepObservation observation;
  final UnitCreepCoverage coverage;
}

final class UnitCreepCaptureReadResult {
  const UnitCreepCaptureReadResult({
    this.capture,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
  final UnitCreepCapture? capture;
  final String? errorCode;
  final int? exitCode;
  final String stdout, stderr;
}

Uint8List _captureBytes(List<int> values) {
  if (values is! Uint8List && values.any((v) => v < 0 || v > 255)) {
    throw ArgumentError('Capture payload must contain byte values.');
  }
  return Uint8List.fromList(values).asUnmodifiableView();
}
