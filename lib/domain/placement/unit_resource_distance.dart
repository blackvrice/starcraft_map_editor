import 'unit_collision_profile.dart';
import 'unit_resource_profile.dart';

enum UnitResourceDistanceCheck {
  clear,
  tooClose,
  notApplicable,
  unavailable,
  outOfBounds,
}

/// Read-only pair geometry. This does not authorize a UNIT or scan a document.
abstract final class UnitResourceDistance {
  static const bufferTiles = 3;
  static const tilePixels = 32;

  static UnitResourceDistanceCheck checkPair({
    required UnitResourceProfile? candidateRole,
    required UnitResourceProfile? existingRole,
    required UnitCollisionBounds? candidateBounds,
    required UnitCollisionBounds? existingBounds,
    required int mapWidthTiles,
    required int mapHeightTiles,
  }) {
    if (candidateRole == null) return UnitResourceDistanceCheck.unavailable;
    if (!candidateRole.isDepot && !candidateRole.isResource) {
      return UnitResourceDistanceCheck.notApplicable;
    }
    if (existingRole == null) return UnitResourceDistanceCheck.unavailable;
    // The reference editor checks depot first (else-if for resources). Both
    // flags are preserved; do not silently invent a mutually exclusive role.
    final relevant = candidateRole.isDepot
        ? existingRole.isResource
        : existingRole.isDepot;
    if (!relevant) return UnitResourceDistanceCheck.notApplicable;
    if (mapWidthTiles < 1 ||
        mapWidthTiles > 256 ||
        mapHeightTiles < 1 ||
        mapHeightTiles > 256 ||
        candidateBounds == null ||
        existingBounds == null) {
      return UnitResourceDistanceCheck.unavailable;
    }
    bool fits(UnitCollisionBounds bounds) =>
        bounds.left >= 0 &&
        bounds.top >= 0 &&
        bounds.right < mapWidthTiles * tilePixels &&
        bounds.bottom < mapHeightTiles * tilePixels;
    if (!fits(candidateBounds) || !fits(existingBounds)) {
      return UnitResourceDistanceCheck.outOfBounds;
    }
    // Legal closed bounds are nonnegative, so ~/ matches the reference's
    // integer division. The 3-tile rectangular buffer is not a pixel radius.
    final left = candidateBounds.left ~/ tilePixels;
    final right = candidateBounds.right ~/ tilePixels;
    final top = candidateBounds.top ~/ tilePixels;
    final bottom = candidateBounds.bottom ~/ tilePixels;
    final otherLeft = existingBounds.left ~/ tilePixels - bufferTiles;
    final otherRight = existingBounds.right ~/ tilePixels + bufferTiles;
    final otherTop = existingBounds.top ~/ tilePixels - bufferTiles;
    final otherBottom = existingBounds.bottom ~/ tilePixels + bufferTiles;
    return right >= otherLeft &&
            left <= otherRight &&
            bottom >= otherTop &&
            top <= otherBottom
        ? UnitResourceDistanceCheck.tooClose
        : UnitResourceDistanceCheck.clear;
  }
}
