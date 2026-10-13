/// Classic units.dat collision offsets, separate from the StarEdit tile box.
/// Missing profiles mean unknown geometry, never a zero-sized ground unit.
final class UnitCollisionProfile {
  UnitCollisionProfile({
    required this.left,
    required this.up,
    required this.right,
    required this.down,
    required this.isFlyer,
  }) {
    for (final offset in [left, up, right, down]) {
      if (offset < 0 || offset > maximumOffset) {
        throw RangeError.range(offset, 0, maximumOffset, 'collisionOffset');
      }
    }
  }

  static const version = 1;
  static const maximumOffset = 0xffff;
  final int left;
  final int up;
  final int right;
  final int down;
  final bool isFlyer;

  UnitCollisionBounds boundsAt(int x, int y) => UnitCollisionBounds._(
    left: x - left,
    top: y - up,
    right: x + right,
    bottom: y + down,
  );
}

/// Closed pixel bounds: sharing an edge or even one pixel counts as overlap.
/// Geometry alone does not decide collision layers or game placement validity.
final class UnitCollisionBounds {
  const UnitCollisionBounds._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;

  bool overlaps(UnitCollisionBounds other) =>
      right >= other.left &&
      left <= other.right &&
      bottom >= other.top &&
      top <= other.bottom;
}
