import '../placement/terrain_placement_snapshot.dart';

enum TerrainAnalysisMode {
  off,
  elevation,
  buildable,
  walkable,
  power,
  creep,
  distance,
}

/// Local terrain facts, not UNIT occupancy/pathfinding or runtime observations.
final class TerrainTileAnalysis {
  const TerrainTileAnalysis(
    this.buildable,
    this.walkableMask,
    this.midMask,
    this.highMask,
  );
  final bool buildable;
  final int walkableMask;
  final int? midMask, highMask;
  int? elevation(int mini) {
    RangeError.checkValueInInterval(mini, 0, 15, 'mini');
    if (midMask == null || highMask == null) return null;
    final bit = 1 << mini;
    return (highMask! & bit) != 0
        ? 2
        : (midMask! & bit) != 0
        ? 1
        : 0;
  }
}

/// A bounded lazy cache keyed by raw tile, tied to one immutable document view
/// and one verified local snapshot. Offscreen tiles are not projected eagerly.
final class TerrainAnalysisView {
  TerrainAnalysisView({
    required this.width,
    required this.height,
    required List<int> rawValues,
    required this.source,
    required this.revision,
  }) : rawValues = List.unmodifiable(rawValues) {
    if (width < 1 ||
        width > 256 ||
        height < 1 ||
        height > 256 ||
        rawValues.length != width * height ||
        rawValues.any((v) => v < 0 || v > 65535)) {
      throw ArgumentError('ANALYSIS_GRID');
    }
  }
  static const maximumCachedValues = 4096;
  final int width, height;
  final List<int> rawValues;
  final TerrainPlacementSnapshot? source;
  final String? revision;
  final _cache = <int, TerrainTileAnalysis?>{};
  int get cachedValueCount => _cache.length;
  int _projections = 0;
  int get projectionCount => _projections;
  TerrainTileAnalysis? tileAt(int x, int y) {
    RangeError.checkValueInInterval(x, 0, width - 1, 'x');
    RangeError.checkValueInInterval(y, 0, height - 1, 'y');
    final raw = rawValues[y * width + x];
    if (_cache.containsKey(raw)) {
      final hit = _cache.remove(raw);
      _cache[raw] = hit;
      return hit;
    }
    _projections++;
    final facts = source?.tile(raw), elevation = source?.elevation(raw);
    final result = facts == null
        ? null
        : TerrainTileAnalysis(
            facts.buildable,
            facts.walkableMask,
            elevation?.mid,
            elevation?.high,
          );
    _cache[raw] = result;
    if (_cache.length > maximumCachedValues) _cache.remove(_cache.keys.first);
    return result;
  }
}

/// A user-entered geometric measurement, never a DAT/game weapon range.
final class MapDistanceMeasurement {
  MapDistanceMeasurement({
    required this.x,
    required this.y,
    required this.radius,
  }) {
    if (x < 0 || x > 8191 || y < 0 || y > 8191 || radius < 1 || radius > 8192) {
      throw ArgumentError('ANALYSIS_DISTANCE');
    }
  }
  final int x, y, radius;
}
