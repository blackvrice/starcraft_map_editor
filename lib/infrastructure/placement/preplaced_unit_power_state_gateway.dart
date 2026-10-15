import '../../application/ports/unit_power_state_gateway.dart';
import '../../domain/placement/unit_power_catalog.dart';
import '../../domain/placement/preplaced_unit_power_layout.dart';

/// An explicit design-time projection, not a simulation or game observation.
/// Only regular preplaced Pylons are treated as present/completed/enabled.
final class PreplacedUnitPowerStateGateway implements UnitPowerStateGateway {
  const PreplacedUnitPowerStateGateway();

  static const providerId = 'editor-preplaced-layout';
  static const revision = PreplacedUnitPowerLayout.revision;
  static const modelUnavailable = 'UNIT_POWER_STATE_MODEL_UNAVAILABLE';

  @override
  Future<UnitPowerStateReadResult> read(UnitPowerStateRequest request) async {
    if (request.model != UnitPowerStateModel.preplacedLayout) {
      return const UnitPowerStateReadResult(errorCode: modelUnavailable);
    }
    return UnitPowerStateReadResult(
      snapshot: UnitPowerStateSnapshot(
        request: request,
        providerId: providerId,
        revision: revision,
        model: UnitPowerStateModel.preplacedLayout,
        powerModelRevision: UnitPowerCatalog.revision,
        units: PreplacedUnitPowerLayout.project(request.units),
      ),
    );
  }

  // Projection has no external operation to stop; the caller's revision guard
  // still rejects the immutable result if the document changes before await.
  @override
  Future<void> cancel(String operationId) async {}
}
