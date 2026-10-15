import '../chk/typed/chk_object_views.dart';
import 'unit_power_catalog.dart';
import 'unit_power_unit_state.dart';

/// Explicit design convention only, never evidence of actual game state.
abstract final class PreplacedUnitPowerLayout {
  static const revision = 'regular-pylon-layout-v1';

  static Iterable<UnitPowerUnitState> project(
    Iterable<ChkUnitPlacement> units,
  ) sync* {
    for (final unit in units) {
      yield _isRegularPylon(unit)
          ? UnitPowerUnitState(
              unit,
              exists: true,
              isCompleted: true,
              isEnabled: true,
            )
          : UnitPowerUnitState(unit);
    }
  }

  static bool _isRegularPylon(ChkUnitPlacement unit) {
    final invincible = ChkUnitPlacement.stateInvincibleFlag;
    // Guards limit the layout convention, not runtime creation. The catalog
    // still validates canonical DAT role/geometry and the map boundary.
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
}
