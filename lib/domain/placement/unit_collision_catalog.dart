import '../chk/typed/chk_object_views.dart';
import 'unit_placement_capability.dart';

enum UnitCollisionCheck {
  clear,
  overlap,
  metadataUnavailable,
  stateUnsupported,
}

/// An immutable local-DAT snapshot. Missing entries remain unknown.
final class UnitCollisionCatalog {
  UnitCollisionCatalog(Map<int, UnitPlacementCapability> units)
    : units = Map.unmodifiable(units) {
    for (final entry in units.entries) {
      if (entry.key != entry.value.unitId) {
        throw ArgumentError('Collision catalog IDs must match capabilities.');
      }
    }
  }

  final Map<int, UnitPlacementCapability> units;

  UnitCollisionCheck check({
    required UnitPlacementCapability candidate,
    required int x,
    required int y,
    required Iterable<ChkUnitPlacement> existing,
  }) {
    final verified = units[candidate.unitId];
    final profile = candidate.collisionProfile;
    final source = verified?.collisionProfile;
    if (profile == null ||
        source == null ||
        profile.left != source.left ||
        profile.up != source.up ||
        profile.right != source.right ||
        profile.down != source.down ||
        profile.isFlyer != source.isFlyer ||
        candidate.isBuilding != verified!.isBuilding ||
        candidate.isFlyingBuilding != verified.isFlyingBuilding) {
      return UnitCollisionCheck.metadataUnavailable;
    }
    final bounds = profile.boundsAt(x, y);
    final airborne = candidate.isAirborne(inTransit: false)!;
    var overlaps = false;
    var unsupportedState = false;
    // Unknown geometry can overlap even from a distant center. Do not infer
    // clearance from distance or stop at the first known overlap.
    for (final unit in existing) {
      final capability = units[unit.unitType];
      final otherProfile = capability?.collisionProfile;
      if (capability == null || otherProfile == null || capability.isSubunit) {
        return UnitCollisionCheck.metadataUnavailable;
      }
      final inTransit =
          (unit.stateFlags & ChkUnitPlacement.stateInTransitFlag) != 0;
      if (inTransit &&
          (!capability.isBuilding ||
              !capability.isFlyingBuilding ||
              (unit.validStateFlags & ChkUnitPlacement.stateInTransitFlag) ==
                  0)) {
        unsupportedState = true;
        continue;
      }
      if (airborne == capability.isAirborne(inTransit: inTransit) &&
          bounds.overlaps(otherProfile.boundsAt(unit.x, unit.y))) {
        overlaps = true;
      }
    }
    if (unsupportedState) return UnitCollisionCheck.stateUnsupported;
    return overlaps ? UnitCollisionCheck.overlap : UnitCollisionCheck.clear;
  }
}
