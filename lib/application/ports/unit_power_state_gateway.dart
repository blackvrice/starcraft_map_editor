import '../../domain/chk/typed/chk_object_views.dart';
import '../../domain/placement/unit_power_unit_state.dart';
import '../documents/opened_map_session.dart';

typedef UnitPowerDataIdentity = (String, int, String, String);

/// Explicit state collection/projection only. Hover never calls this port.
/// Actual initial-map facts need a trusted collector; an editor projection
/// must be explicitly requested and must never be relabelled as actual state.
abstract interface class UnitPowerStateGateway {
  Future<UnitPowerStateReadResult> read(UnitPowerStateRequest request);
  Future<void> cancel(String operationId);
}

final class UnitPowerStateRequest {
  UnitPowerStateRequest({
    required this.operationId,
    required this.session,
    required this.documentRevision,
    required this.installationPath,
    required this.dataIdentity,
    this.model = UnitPowerStateModel.initialMap,
  }) : units = List.unmodifiable(
         session.objectViews.unitSections.expand((section) => section.units),
       );

  final String operationId;
  final OpenedMapSession session;
  final int documentRevision;
  final String installationPath;
  final UnitPowerDataIdentity dataIdentity;
  final UnitPowerStateModel model;
  final List<ChkUnitPlacement> units;
}

enum UnitPowerStateModel { initialMap, live, preplacedLayout }

final class UnitPowerStateSnapshot {
  UnitPowerStateSnapshot({
    required this.request,
    required this.providerId,
    required this.revision,
    required this.model,
    required this.powerModelRevision,
    required Iterable<UnitPowerUnitState> units,
  }) : units = List.unmodifiable(units);

  /// Echo the exact request, including each record's identity and order.
  final UnitPowerStateRequest request;
  final String providerId, revision, powerModelRevision;
  final UnitPowerStateModel model;
  final List<UnitPowerUnitState> units;
}

final class UnitPowerStateReadResult {
  const UnitPowerStateReadResult({
    this.snapshot,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final UnitPowerStateSnapshot? snapshot;
  final String? errorCode;
  final int? exitCode;
  final String stdout, stderr;
  bool get isSuccess =>
      snapshot != null &&
      errorCode == null &&
      (exitCode == null || exitCode == 0);
}
