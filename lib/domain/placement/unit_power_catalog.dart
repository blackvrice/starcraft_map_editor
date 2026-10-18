import '../chk/typed/chk_object_views.dart';
import 'unit_placement_capability.dart';
import 'unit_power_unit_state.dart';
import 'unit_psi_field.dart';

enum UnitPowerCheck {
  powered,
  unpowered,
  notApplicable,
  unavailable,
  stateUnsupported,
  outOfBounds,
}

/// Read-only classic Pylon model. No alliance, runtime/EUD override or implicit
/// completion model is supplied. A caller must bind this DAT snapshot's source.
final class UnitPowerCatalog {
  UnitPowerCatalog(Map<int, UnitPlacementCapability> units)
    : units = Map.unmodifiable(units) {
    for (final entry in units.entries) {
      if (entry.key != entry.value.unitId) {
        throw ArgumentError('Power catalog IDs must match capabilities.');
      }
    }
  }

  static const revision = 'classic-pylon-explicit-state-v1';
  static const pylonUnitId = 156;
  final Map<int, UnitPlacementCapability> units;

  UnitPowerCheck check({
    required UnitPlacementCapability candidate,
    required int owner,
    required int x,
    required int y,
    required int mapWidthTiles,
    required int mapHeightTiles,
    required Iterable<UnitPowerUnitState> existing,
  }) {
    final verified = units[candidate.unitId];
    final requirement = candidate.environmentProfile;
    final sourceRequirement = verified?.environmentProfile;
    if (requirement == null ||
        sourceRequirement == null ||
        requirement.requiresPsi != sourceRequirement.requiresPsi ||
        requirement.requiresCreep != sourceRequirement.requiresCreep ||
        candidate.isBuilding != verified!.isBuilding ||
        candidate.isSubunit != verified.isSubunit ||
        candidate.isFlyingBuilding != verified.isFlyingBuilding ||
        candidate.requiresRelationLink != verified.requiresRelationLink) {
      return UnitPowerCheck.unavailable;
    }
    if (!requirement.requiresPsi) return UnitPowerCheck.notApplicable;
    final box = candidate.placementBox, sourceBox = verified.placementBox;
    final geometry = candidate.collisionProfile;
    final sourceGeometry = verified.collisionProfile;
    if (box == null ||
        sourceBox == null ||
        box.width != sourceBox.width ||
        box.height != sourceBox.height ||
        geometry == null ||
        sourceGeometry == null ||
        geometry.isFlyer != sourceGeometry.isFlyer ||
        mapWidthTiles < 1 ||
        mapWidthTiles > 256 ||
        mapHeightTiles < 1 ||
        mapHeightTiles > 256) {
      return UnitPowerCheck.unavailable;
    }
    var unsupported =
        !candidate.isBuilding ||
        candidate.isSubunit ||
        candidate.isFlyingBuilding ||
        candidate.requiresRelationLink ||
        geometry.isFlyer ||
        owner < 0 ||
        owner > 7;
    var outside =
        x < 0 ||
        y < 0 ||
        x >= mapWidthTiles * 32 ||
        y >= mapHeightTiles * 32 ||
        !box.fits(
          x: x,
          y: y,
          mapWidth: mapWidthTiles,
          mapHeight: mapHeightTiles,
        );
    final field = project(
      owner: owner,
      mapWidthTiles: mapWidthTiles,
      mapHeightTiles: mapHeightTiles,
      existing: existing,
    );
    if (field.failure == UnitPowerCheck.unavailable) {
      return UnitPowerCheck.unavailable;
    }
    if (unsupported || field.failure == UnitPowerCheck.stateUnsupported) {
      return UnitPowerCheck.stateUnsupported;
    }
    if (outside || field.failure == UnitPowerCheck.outOfBounds) {
      return UnitPowerCheck.outOfBounds;
    }
    return field.containsPoint(x, y) == true
        ? UnitPowerCheck.powered
        : UnitPowerCheck.unpowered;
  }

  /// Validates suppliers once, independently of any proposed building. Both
  /// placement checks and the read-only field use this same fail-closed scan.
  UnitPowerField project({
    required int owner,
    required int mapWidthTiles,
    required int mapHeightTiles,
    required Iterable<UnitPowerUnitState> existing,
  }) {
    if (mapWidthTiles < 1 ||
        mapWidthTiles > 256 ||
        mapHeightTiles < 1 ||
        mapHeightTiles > 256) {
      return UnitPowerField._(UnitPowerCheck.unavailable, const []);
    }
    var unsupported = owner < 0 || owner > 7;
    var outside = false;
    var unavailable = false;
    final providers = <({int x, int y})>[];
    // A known supplier must not hide a later unknown or unsupported one.
    for (final state in existing) {
      final unit = state.unit;
      final cap = units[unit.unitType];
      if (cap == null || cap.environmentProfile == null || cap.isSubunit) {
        unavailable = true;
        continue;
      }
      if (unit.unitType != pylonUnitId) continue;
      final role = cap.environmentProfile!;
      final profile = cap.collisionProfile;
      final providerBox = cap.placementBox;
      if (profile == null || providerBox == null) {
        unavailable = true;
        continue;
      }
      if (!cap.isBuilding ||
          cap.isFlyingBuilding ||
          cap.requiresRelationLink ||
          profile.isFlyer ||
          role.requiresPsi ||
          role.requiresCreep ||
          providerBox.width != 64 ||
          providerBox.height != 64) {
        unsupported = true;
        continue;
      }
      // Known absent/incomplete providers cannot supply. Other facts need not
      // be invented for these inactive records.
      if (state.exists == false || state.isCompleted == false) continue;
      if ((unit.validFieldFlags & ChkUnitPlacement.validFieldOwnerFlag) == 0 ||
          unit.owner > 7) {
        unsupported = true;
        continue;
      }
      if (unit.owner != owner) continue;
      if (state.exists == null ||
          state.isCompleted == null ||
          state.isEnabled == null) {
        unavailable = true;
        continue;
      }
      // Only default/invincible ground state is supported; disabled and custom
      // flight/hallucination effects are not approximated as a power-off rule.
      final invincible = ChkUnitPlacement.stateInvincibleFlag;
      if (!state.isEnabled! ||
          (unit.stateFlags & ~invincible) != 0 ||
          (unit.validStateFlags & ~31) != 0 ||
          ((unit.stateFlags & invincible) != 0 &&
              (unit.validStateFlags & invincible) == 0 &&
              !cap.isInvincible) ||
          unit.relationFlags != 0 ||
          unit.relationClassId != 0) {
        unsupported = true;
        continue;
      }
      if (!providerBox.fits(
        x: unit.x,
        y: unit.y,
        mapWidth: mapWidthTiles,
        mapHeight: mapHeightTiles,
      )) {
        outside = true;
        continue;
      }
      providers.add((x: unit.x, y: unit.y));
    }
    return UnitPowerField._(
      unavailable
          ? UnitPowerCheck.unavailable
          : unsupported
          ? UnitPowerCheck.stateUnsupported
          : outside
          ? UnitPowerCheck.outOfBounds
          : null,
      providers,
    );
  }
}

final class UnitPowerField {
  UnitPowerField._(this.failure, List<({int x, int y})> providers)
    : providers = List.unmodifiable(providers);
  final UnitPowerCheck? failure;
  final List<({int x, int y})> providers;

  bool? containsPoint(int x, int y) => failure != null
      ? null
      : providers.any(
          (p) => UnitPsiField.containsPoint(
            x: x,
            y: y,
            providerX: p.x,
            providerY: p.y,
          ),
        );
}
