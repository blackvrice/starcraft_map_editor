import '../chk/typed/chk_object_views.dart';
import 'unit_placement_capability.dart';
import 'unit_resource_distance.dart';

enum UnitResourceDistanceCatalogCheck {
  clear,
  tooClose,
  notApplicable,
  metadataUnavailable,
  stateUnsupported,
  outOfBounds,
}

/// A read-only classic-DAT snapshot, not a runtime/EUD placement permission.
final class UnitResourceDistanceCatalog {
  UnitResourceDistanceCatalog(Map<int, UnitPlacementCapability> units)
    : units = Map.unmodifiable(units) {
    for (final entry in units.entries) {
      if (entry.key != entry.value.unitId) {
        throw ArgumentError('Resource catalog IDs must match capabilities.');
      }
    }
  }

  final Map<int, UnitPlacementCapability> units;

  UnitResourceDistanceCatalogCheck check({
    required UnitPlacementCapability candidate,
    required int x,
    required int y,
    required int mapWidthTiles,
    required int mapHeightTiles,
    required Iterable<ChkUnitPlacement> existing,
  }) {
    final verified = units[candidate.unitId];
    final role = candidate.resourceProfile;
    final sourceRole = verified?.resourceProfile;
    if (role == null ||
        sourceRole == null ||
        role.isDepot != sourceRole.isDepot ||
        role.isResource != sourceRole.isResource ||
        candidate.isSubunit ||
        candidate.isSubunit != verified!.isSubunit ||
        candidate.isBuilding != verified.isBuilding ||
        candidate.isFlyingBuilding != verified.isFlyingBuilding ||
        candidate.requiresRelationLink != verified.requiresRelationLink) {
      return UnitResourceDistanceCatalogCheck.metadataUnavailable;
    }
    if (!role.isDepot && !role.isResource) {
      return UnitResourceDistanceCatalogCheck.notApplicable;
    }
    final profile = candidate.collisionProfile;
    final source = verified.collisionProfile;
    if (profile == null ||
        source == null ||
        profile.left != source.left ||
        profile.up != source.up ||
        profile.right != source.right ||
        profile.down != source.down ||
        profile.isFlyer != source.isFlyer ||
        mapWidthTiles < 1 ||
        mapWidthTiles > 256 ||
        mapHeightTiles < 1 ||
        mapHeightTiles > 256) {
      return UnitResourceDistanceCatalogCheck.metadataUnavailable;
    }
    final bounds = profile.boundsAt(x, y);
    var outside =
        bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right >= mapWidthTiles * UnitResourceDistance.tilePixels ||
        bounds.bottom >= mapHeightTiles * UnitResourceDistance.tilePixels;
    var unsupported = profile.isFlyer;
    var tooClose = false;
    // Unknown metadata outranks all known violations, independent of UNIT
    // order. A distant center is not proof that unknown extents are harmless.
    for (final unit in existing) {
      final capability = units[unit.unitType];
      final otherRole = capability?.resourceProfile;
      final otherProfile = capability?.collisionProfile;
      if (capability == null ||
          otherRole == null ||
          otherProfile == null ||
          capability.isSubunit) {
        return UnitResourceDistanceCatalogCheck.metadataUnavailable;
      }
      final inTransit =
          (unit.stateFlags & ChkUnitPlacement.stateInTransitFlag) != 0;
      if (inTransit &&
          (!capability.isBuilding ||
              !capability.isFlyingBuilding ||
              (unit.validStateFlags & ChkUnitPlacement.stateInTransitFlag) ==
                  0)) {
        unsupported = true;
        continue;
      }
      final relevant = role.isDepot ? otherRole.isResource : otherRole.isDepot;
      if (!relevant) continue;
      // Only static ground participants are supported. Do not guess resource
      // distance semantics for lifted depots or custom airborne resources.
      if (inTransit || otherProfile.isFlyer) {
        unsupported = true;
        continue;
      }
      switch (UnitResourceDistance.checkPair(
        candidateRole: role,
        existingRole: otherRole,
        candidateBounds: bounds,
        existingBounds: otherProfile.boundsAt(unit.x, unit.y),
        mapWidthTiles: mapWidthTiles,
        mapHeightTiles: mapHeightTiles,
      )) {
        case UnitResourceDistanceCheck.tooClose:
          tooClose = true;
        case UnitResourceDistanceCheck.outOfBounds:
          outside = true;
        case UnitResourceDistanceCheck.unavailable:
          return UnitResourceDistanceCatalogCheck.metadataUnavailable;
        case UnitResourceDistanceCheck.clear:
        case UnitResourceDistanceCheck.notApplicable:
          break;
      }
    }
    if (unsupported) return UnitResourceDistanceCatalogCheck.stateUnsupported;
    if (outside) return UnitResourceDistanceCatalogCheck.outOfBounds;
    return tooClose
        ? UnitResourceDistanceCatalogCheck.tooClose
        : UnitResourceDistanceCatalogCheck.clear;
  }
}
