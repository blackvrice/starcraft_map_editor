import '../../domain/placement/unit_creep_catalog.dart';
import '../../domain/placement/unit_creep_coverage.dart';
import '../documents/opened_map_session.dart';

typedef UnitCreepDataIdentity = (String, int, String, String);

/// Explicit trusted observation only. No UNIT radius, terrain-image inference
/// or implicit initial-map/live fallback. No built-in collector exists yet.
abstract interface class UnitCreepStateGateway {
  Future<UnitCreepStateReadResult> read(UnitCreepStateRequest request);
  Future<void> cancel(String operationId);
}

enum UnitCreepStateModel { initialMap, live }

final class UnitCreepStateRequest {
  const UnitCreepStateRequest({
    required this.operationId,
    required this.session,
    required this.documentRevision,
    required this.installationPath,
    required this.dataIdentity,
    required this.model,
  });

  final String operationId;
  final OpenedMapSession session;
  final int documentRevision;
  final String installationPath;
  final UnitCreepDataIdentity dataIdentity;
  final UnitCreepStateModel model;

  /// Controllers must invalidate even when Undo restores the same bytes.
  bool isCurrentFor({
    required OpenedMapSession? session,
    required int documentRevision,
    required String? installationPath,
    required UnitCreepDataIdentity? dataIdentity,
  }) =>
      identical(this.session, session) &&
      this.documentRevision == documentRevision &&
      this.installationPath == installationPath &&
      this.dataIdentity == dataIdentity;
}

final class UnitCreepStateSnapshot {
  const UnitCreepStateSnapshot({
    required this.request,
    required this.providerId,
    required this.revision,
    required this.model,
    required this.creepModelRevision,
    required this.coverage,
  });

  final UnitCreepStateRequest request;
  final String providerId, revision, creepModelRevision;
  final UnitCreepStateModel model;
  final UnitCreepCoverage coverage;

  /// Use only after checking the request is still current. Echoing a request
  /// binds provenance but cannot prove that the collector is authoritative.
  UnitCreepCoverage? coverageFor(UnitCreepStateRequest currentRequest) {
    final dimensions = currentRequest.session.metadataViews.dimensions;
    final source = currentRequest.dataIdentity;
    if (!identical(request, currentRequest) ||
        model != currentRequest.model ||
        model != UnitCreepStateModel.initialMap ||
        providerId.trim().isEmpty ||
        revision.trim().isEmpty ||
        creepModelRevision != UnitCreepCatalog.revision ||
        currentRequest.operationId.trim().isEmpty ||
        currentRequest.documentRevision < 0 ||
        currentRequest.installationPath.trim().isEmpty ||
        source.$1.trim().isEmpty ||
        source.$2 < 0 ||
        source.$3.trim().isEmpty ||
        source.$4.trim().isEmpty ||
        currentRequest.session.requiresRestrictedEditing ||
        dimensions.length != 1 ||
        dimensions.single.width != coverage.width ||
        dimensions.single.height != coverage.height) {
      return null;
    }
    // Live collection needs a frame/observer freshness contract before use.
    return coverage;
  }
}

final class UnitCreepStateReadResult {
  const UnitCreepStateReadResult({
    this.snapshot,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final UnitCreepStateSnapshot? snapshot;
  final String? errorCode;
  final int? exitCode;
  final String stdout, stderr;
  bool get isSuccess =>
      snapshot != null &&
      errorCode == null &&
      (exitCode == null || exitCode == 0);
}
