import '../../domain/diagnostics/editor_diagnostic.dart';
import 'map_file_fingerprint_gateway.dart';
import 'unit_creep_capture_gateway.dart';

final class CreepCaptureWorkspace {
  const CreepCaptureWorkspace({
    required this.directoryPath,
    required this.mapPath,
  });
  final String directoryPath, mapPath;
}

abstract interface class CreepCaptureWorkspaceGateway {
  Future<CreepCaptureWorkspace> create();
  Future<bool> sameLocation(String left, String right);
  Future<void> cleanup(CreepCaptureWorkspace workspace);
}

final class PreparedUnitCreepMap {
  const PreparedUnitCreepMap({
    required this.request,
    required this.path,
    required this.fingerprint,
  });
  final UnitCreepCaptureRequest request;
  final String path;
  final MapFileFingerprint fingerprint;
}

final class UnitCreepMapPreparationResult {
  UnitCreepMapPreparationResult({
    this.prepared,
    this.errorCode,
    this.errorDetails = '',
    this.cleanupPending = false,
    Iterable<EditorDiagnostic> diagnostics = const [],
  }) : diagnostics = List.unmodifiable(diagnostics);
  final PreparedUnitCreepMap? prepared;
  final String? errorCode;
  final String errorDetails;
  final bool cleanupPending;
  final List<EditorDiagnostic> diagnostics;
  bool get isSuccess => prepared != null && errorCode == null;
}

/// Temporary input only; no promotion, engine launch or implicit observation.
abstract interface class UnitCreepMapPreparationGateway {
  /// Returns an owned receipt only after reopening and verifying the output.
  Future<UnitCreepMapPreparationResult> prepare(
    UnitCreepCaptureRequest request,
  );
  Future<bool> revalidate(PreparedUnitCreepMap prepared);

  /// Advisory cancellation; cleanup waits for in-flight I/O to finish.
  Future<void> cancel(UnitCreepCaptureRequest request);

  /// Revokes the receipt; false retains ownership for a later cleanup retry.
  Future<bool> release(UnitCreepCaptureRequest request);
}
