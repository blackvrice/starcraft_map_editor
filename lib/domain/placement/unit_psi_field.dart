/// Numeric classic psi geometry, not a placement or runtime-state permission.
abstract final class UnitPsiField {
  static const revision = 'classic-psi-point-v1';
  static const tilePixels = 32;
  static const horizontalExtent = 256;
  static const verticalExtent = 160;

  // Inclusive column spans of the published 10x16 compatibility mask.
  // Source and implementation boundary: docs/UNIT_POWER_VALIDATION.md.
  static const _rows = [
    (5, 10),
    (2, 13),
    (1, 14),
    (0, 15),
    (0, 15),
    (0, 15),
    (0, 15),
    (1, 14),
    (2, 13),
    (5, 10),
  ];

  /// Half-open integer pixel strips equivalent to containsPoint, including its
  /// strict negative extent. Rendering must not replace these with an ellipse.
  static Iterable<({int left, int top, int right, int bottom})>
  get strips sync* {
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final left = row.$1 * tilePixels - horizontalExtent;
      final top = i * tilePixels - verticalExtent;
      yield (
        left: left == -horizontalExtent ? left + 1 : left,
        top: top == -verticalExtent ? top + 1 : top,
        right: (row.$2 + 1) * tilePixels - horizontalExtent,
        bottom: (i + 1) * tilePixels - verticalExtent,
      );
    }
  }

  static bool containsPoint({
    required int x,
    required int y,
    required int providerX,
    required int providerY,
  }) {
    if (x < 0 ||
        x > 0xffff ||
        y < 0 ||
        y > 0xffff ||
        providerX < 0 ||
        providerX > 0xffff ||
        providerY < 0 ||
        providerY > 0xffff) {
      return false;
    }
    final dx = x - providerX, dy = y - providerY;
    if (dx <= -horizontalExtent ||
        dx >= horizontalExtent ||
        dy <= -verticalExtent ||
        dy >= verticalExtent) {
      return false;
    }
    // Offsets are nonnegative here, so integer division is unambiguous.
    final row = _rows[(dy + verticalExtent) ~/ tilePixels];
    final column = (dx + horizontalExtent) ~/ tilePixels;
    return column >= row.$1 && column <= row.$2;
  }
}
