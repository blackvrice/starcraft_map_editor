import 'unit_creep_coverage.dart';
import 'unit_placement_capability.dart';

enum UnitCreepCheck {
  covered,
  missing,
  notApplicable,
  unavailable,
  stateUnsupported,
  outOfBounds,
}

/// Positive creep requirement only, not permission to build/place. In
/// particular, requiresCreep=false does not decide creep prohibition/exemptions.
/// A caller must bind both DAT and coverage to the current document/source.
final class UnitCreepCatalog {
  UnitCreepCatalog(Map<int, UnitPlacementCapability> units)
    : units = Map.unmodifiable(units) {
    for (final entry in units.entries) {
      if (entry.key != entry.value.unitId) {
        throw ArgumentError('Creep catalog IDs must match capabilities.');
      }
    }
  }

  static const revision = 'positive-creep-tile-footprint-v1';
  static const maximumCheckedTiles = 4096;
  final Map<int, UnitPlacementCapability> units;

  UnitCreepCheck checkRequirement({
    required UnitPlacementCapability candidate,
    required int x,
    required int y,
    required int mapWidthTiles,
    required int mapHeightTiles,
    required UnitCreepCoverage? coverage,
  }) {
    final verified = units[candidate.unitId];
    final role = candidate.environmentProfile;
    final sourceRole = verified?.environmentProfile;
    if (role == null ||
        sourceRole == null ||
        role.requiresCreep != sourceRole.requiresCreep ||
        role.requiresPsi != sourceRole.requiresPsi ||
        candidate.isBuilding != verified!.isBuilding ||
        candidate.isSubunit != verified.isSubunit ||
        candidate.isFlyingBuilding != verified.isFlyingBuilding ||
        candidate.requiresRelationLink != verified.requiresRelationLink ||
        candidate.isGasResourceContainer != verified.isGasResourceContainer) {
      return UnitCreepCheck.unavailable;
    }
    if (!role.requiresCreep) return UnitCreepCheck.notApplicable;
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
      return UnitCreepCheck.unavailable;
    }
    // Refineries and relation/flight cases need separate verified exceptions.
    if (!candidate.isBuilding ||
        candidate.isSubunit ||
        candidate.isFlyingBuilding ||
        candidate.requiresRelationLink ||
        candidate.isGasResourceContainer ||
        geometry.isFlyer) {
      return UnitCreepCheck.stateUnsupported;
    }
    if (x < 0 ||
        y < 0 ||
        x >= mapWidthTiles * 32 ||
        y >= mapHeightTiles * 32 ||
        !box.fits(
          x: x,
          y: y,
          mapWidth: mapWidthTiles,
          mapHeight: mapHeightTiles,
        )) {
      return UnitCreepCheck.outOfBounds;
    }
    if (coverage == null ||
        coverage.width != mapWidthTiles ||
        coverage.height != mapHeightTiles) {
      return UnitCreepCheck.unavailable;
    }
    // Half-open StarEdit box, not closed collision extents. Unaligned final
    // points include every intersected tile; no implicit snapping is applied.
    final firstX = (x - box.width ~/ 2) ~/ 32;
    final lastX = (x + box.width ~/ 2 - 1) ~/ 32;
    final firstY = (y - box.height ~/ 2) ~/ 32;
    final lastY = (y + box.height ~/ 2 - 1) ~/ 32;
    if ((lastX - firstX + 1) * (lastY - firstY + 1) > maximumCheckedTiles) {
      return UnitCreepCheck.unavailable;
    }
    var missing = false;
    for (var row = firstY; row <= lastY; row++) {
      for (var column = firstX; column <= lastX; column++) {
        switch (coverage.tileAt(x: column, y: row)) {
          case UnitCreepTile.unknown:
            // Unknown outranks known absence, independent of traversal order.
            return UnitCreepCheck.unavailable;
          case UnitCreepTile.absent:
            missing = true;
          case UnitCreepTile.present:
            break;
        }
      }
    }
    return missing ? UnitCreepCheck.missing : UnitCreepCheck.covered;
  }
}
