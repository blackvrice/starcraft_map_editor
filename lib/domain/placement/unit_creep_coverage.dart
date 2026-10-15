enum UnitCreepTile { present, absent, unknown }

/// Explicit 32px tile observations, never inferred from UNITs or tile graphics.
final class UnitCreepCoverage {
  factory UnitCreepCoverage({
    required int width,
    required int height,
    required List<UnitCreepTile> tiles,
  }) {
    if (width < 1 ||
        width > 256 ||
        height < 1 ||
        height > 256 ||
        tiles.length != width * height) {
      throw ArgumentError('Creep coverage must match a 1..256 tile map.');
    }
    return UnitCreepCoverage._(width, height, List.unmodifiable(tiles));
  }

  UnitCreepCoverage._(this.width, this.height, this.tiles);

  static const version = 1;
  final int width, height;

  /// Row-major. Hidden/unobserved tiles are unknown, not absent.
  final List<UnitCreepTile> tiles;

  UnitCreepTile tileAt({required int x, required int y}) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return UnitCreepTile.unknown;
    }
    return tiles[y * width + x];
  }
}
