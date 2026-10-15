import '../../application/ports/unit_power_state_gateway.dart';
import '../../domain/chk/typed/chk_object_views.dart';
import '../../domain/placement/unit_power_catalog.dart';
import '../../domain/placement/unit_power_unit_state.dart';

/// An explicit design-time projection, not a simulation or game observation.
/// Only regular preplaced Pylons are treated as present/completed/enabled.
final class PreplacedUnitPowerStateGateway implements UnitPowerStateGateway {
  const PreplacedUnitPowerStateGateway();

  static const providerId = 'editor-preplaced-layout';
  static const revision = 'regular-pylon-layout-v1';
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
        units: [
          for (final unit in request.units)
            if (_isRegularPylon(unit))
              UnitPowerUnitState(
                unit,
                exists: true,
                isCompleted: true,
                isEnabled: true,
              )
            else
              UnitPowerUnitState(unit),
        ],
      ),
    );
  }

  bool _isRegularPylon(ChkUnitPlacement unit) {
    final invincible = ChkUnitPlacement.stateInvincibleFlag;
    // These guards limit the layout convention; they do not prove runtime
    // creation. Canonical DAT role/geometry is still checked by the catalog.
    return unit.unitType == UnitPowerCatalog.pylonUnitId &&
        unit.owner <= 7 &&
        (unit.validFieldFlags & ChkUnitPlacement.validFieldOwnerFlag) != 0 &&
        (unit.validFieldFlags & ~63) == 0 &&
        (unit.validStateFlags & ~31) == 0 &&
        (unit.stateFlags & ~invincible) == 0 &&
        ((unit.stateFlags & invincible) == 0 ||
            (unit.validStateFlags & invincible) != 0) &&
        unit.relationFlags == 0 &&
        unit.relationClassId == 0 &&
        unit.unused == 0;
  }

  // Projection has no external operation to stop; the caller's revision guard
  // still rejects the immutable result if the document changes before await.
  @override
  Future<void> cancel(String operationId) async {}
}
