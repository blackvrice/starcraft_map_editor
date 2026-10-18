import '../chk/typed/chk_terrain_views.dart';
import 'cv5_creep_candidate_profile.dart';
import 'unit_collision_profile.dart';

enum TerrainFootprintCheck {
  clear,
  unbuildable,
  unwalkable,
  unavailable,
  outOfBounds,
}

/// Derived local CV5/VF4 facts, not graphics, power or observed creep state.
/// Optional static CV5 candidate flags do not prove creep presence or absence,
/// even on an empty UNIT map. Footprint checks use buildability/walkability only.
final class TerrainPlacementSnapshot {
  TerrainPlacementSnapshot({
    required this.tileset,
    required List<bool> groupBuildable,
    required List<List<int>> megaTileReferences,
    required List<int> walkableMasks,
    List<int>? midElevationMasks,
    List<int>? highElevationMasks,
    this.creepCandidateProfile,
  }) : groupBuildable = List.unmodifiable(groupBuildable),
       megaTileReferences = List.unmodifiable(
         megaTileReferences.map((row) => List<int>.unmodifiable(row)),
       ),
       walkableMasks = List.unmodifiable(walkableMasks),
       midElevationMasks = midElevationMasks == null
           ? null
           : List.unmodifiable(midElevationMasks),
       highElevationMasks = highElevationMasks == null
           ? null
           : List.unmodifiable(highElevationMasks) {
    if (tileset < 0 ||
        tileset > 7 ||
        groupBuildable.isEmpty ||
        groupBuildable.length > 4096 ||
        megaTileReferences.length != groupBuildable.length ||
        (creepCandidateProfile != null &&
            creepCandidateProfile!.groupFlags.length !=
                groupBuildable.length) ||
        walkableMasks.isEmpty ||
        walkableMasks.length > 65536 ||
        walkableMasks.any((mask) => mask < 0 || mask > 65535) ||
        megaTileReferences.any(
          (row) => row.length != 16 || row.any((id) => id < 0 || id > 65535),
        )) {
      throw ArgumentError('Invalid terrain placement dimensions or values.');
    }
    if ((midElevationMasks == null) != (highElevationMasks == null) ||
        [midElevationMasks, highElevationMasks].any(
          (masks) =>
              masks != null &&
              (masks.length != walkableMasks.length ||
                  masks.any((v) => v < 0 || v > 65535)),
        )) {
      throw ArgumentError('Invalid terrain elevation coverage.');
    }
  }

  static const version = 1;

  /// A synchronous-check budget, not a game building-size rule.
  static const maximumCheckedTiles = 4096;
  final int tileset;
  final List<bool> groupBuildable;
  final List<List<int>> megaTileReferences;

  /// VF4 bit0 projected to bit (row*4+column), for sixteen 8px mini-tiles.
  final List<int> walkableMasks;

  /// Optional VF4 bit1/bit2 projections. Missing does not mean low ground.
  final List<int>? midElevationMasks, highElevationMasks;

  ({int mid, int high})? elevation(int rawValue) {
    if (tile(rawValue) == null || midElevationMasks == null) return null;
    final mega = megaTileReferences[rawValue ~/ 16][rawValue & 15];
    return (mid: midElevationMasks![mega], high: highElevationMasks![mega]);
  }

  /// Missing on legacy helpers. Shares this snapshot's CV5 source identity.
  final Cv5CreepCandidateProfile? creepCandidateProfile;

  /// Invalid references stay unknown; do not substitute mega-tile zero.
  ({bool buildable, int walkableMask})? tile(int rawValue) {
    if (rawValue < 0 || rawValue > 65535) return null;
    final group = rawValue ~/ 16;
    if (group >= groupBuildable.length) return null;
    final mega = megaTileReferences[group][rawValue & 15];
    if (mega >= walkableMasks.length) return null;
    return (
      buildable: groupBuildable[group],
      walkableMask: walkableMasks[mega],
    );
  }

  /// A closed collision footprint. This is a read-only terrain check, not a
  /// complete UNIT/game permission or a StarEdit building tile-box check.
  TerrainFootprintCheck check({
    required ChkTerrainTileMapView terrain,
    required int mapTileset,
    required UnitCollisionBounds bounds,
    required bool requireBuildable,
  }) {
    final width = terrain.width, height = terrain.height;
    if (mapTileset != tileset ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        terrain.tileCount != width * height) {
      return TerrainFootprintCheck.unavailable;
    }
    // The last legal pixel is width*32-1, unlike the half-open tile box edge.
    if (bounds.left < 0 ||
        bounds.top < 0 ||
        bounds.right >= width * 32 ||
        bounds.bottom >= height * 32) {
      return TerrainFootprintCheck.outOfBounds;
    }
    var unbuildable = false;
    var unwalkable = false;
    final firstX = bounds.left ~/ 32, lastX = bounds.right ~/ 32;
    final firstY = bounds.top ~/ 32, lastY = bounds.bottom ~/ 32;
    if ((lastX - firstX + 1) * (lastY - firstY + 1) > maximumCheckedTiles) {
      return TerrainFootprintCheck.unavailable;
    }
    for (var y = firstY; y <= lastY; y++) {
      for (var x = firstX; x <= lastX; x++) {
        final facts = tile(terrain.rawTileValueAt(x: x, y: y));
        if (facts == null) return TerrainFootprintCheck.unavailable;
        if (requireBuildable && !facts.buildable) unbuildable = true;
        final left = bounds.left > x * 32 ? (bounds.left - x * 32) ~/ 8 : 0;
        final right = bounds.right < x * 32 + 31
            ? (bounds.right - x * 32) ~/ 8
            : 3;
        final top = bounds.top > y * 32 ? (bounds.top - y * 32) ~/ 8 : 0;
        final bottom = bounds.bottom < y * 32 + 31
            ? (bounds.bottom - y * 32) ~/ 8
            : 3;
        for (var row = top; row <= bottom; row++) {
          for (var column = left; column <= right; column++) {
            if ((facts.walkableMask & (1 << (row * 4 + column))) == 0) {
              unwalkable = true;
            }
          }
        }
      }
    }
    if (unbuildable) return TerrainFootprintCheck.unbuildable;
    return unwalkable
        ? TerrainFootprintCheck.unwalkable
        : TerrainFootprintCheck.clear;
  }
}
