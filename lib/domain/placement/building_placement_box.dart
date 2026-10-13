/// Verified StarEdit placement dimensions, not the DAT collision extents.
final class BuildingPlacementBox {
  BuildingPlacementBox({required this.width, required this.height}) {
    for (final axis in [width, height]) {
      if (axis < 32 || axis > maximumAxis || axis % 32 != 0) {
        throw ArgumentError(
          'Placement dimensions must be 32px tile multiples.',
        );
      }
    }
  }

  static const version = 1;
  static const maximumAxis = 8192;
  final int width;
  final int height;

  ({int x, int y}) align(int x, int y) =>
      (x: _alignAxis(x, width), y: _alignAxis(y, height));

  int _alignAxis(int value, int extent) {
    if (value < 0) return value;
    // Odd tile counts have centers at 16 modulo 32, even counts at 0.
    // Nearest lattice point, with ties toward the larger coordinate.
    final odd = (extent ~/ 32).isOdd;
    return ((value + (odd ? 0 : 16)) ~/ 32) * 32 + (odd ? 16 : 0);
  }

  bool fits({
    required int x,
    required int y,
    required int mapWidth,
    required int mapHeight,
  }) =>
      x - width ~/ 2 >= 0 &&
      y - height ~/ 2 >= 0 &&
      x + width ~/ 2 <= mapWidth * 32 &&
      y + height ~/ 2 <= mapHeight * 32;
}
