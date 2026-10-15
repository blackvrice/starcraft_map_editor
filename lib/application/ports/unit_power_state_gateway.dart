import '../../domain/chk/typed/chk_object_views.dart';
import '../../domain/placement/unit_power_unit_state.dart';
import '../documents/opened_map_session.dart';

typedef UnitPowerDataIdentity = (String, int, String, String);

/// Explicit, trusted state collection only. Hover must never call this port.
/// Initial-map facts must remain valid for the exact immutable request;
/// CHK presence/HP/DAT alone does not establish completion or activation.
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
  }) : units = List.unmodifiable(
         session.objectViews.unitSections.expand((section) => section.units),
       );

  final String operationId;
  final OpenedMapSession session;
  final int documentRevision;
  final String installationPath;
  final UnitPowerDataIdentity dataIdentity;
  final List<ChkUnitPlacement> units;
}

enum UnitPowerStateModel { initialMap, live }

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
