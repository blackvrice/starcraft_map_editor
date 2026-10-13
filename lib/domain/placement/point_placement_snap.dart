/// Coordinate alignment only, not building footprint or game legality.
final class PointPlacementSnap {
  factory PointPlacementSnap({bool enabled = false, int step = 32}) {
    if (step < 1 || step > maximumStep) {
      throw RangeError.range(step, 1, maximumStep, 'step');
    }
    return PointPlacementSnap._(enabled, step);
  }

  const PointPlacementSnap._(this.enabled, this.step);

  static const disabled = PointPlacementSnap._(false, 32);
  static const maximumStep = 128;
  static const presets = [8, 16, 32, 64, 128];

  final bool enabled;
  final int step;

  ({int x, int y}) resolve(int x, int y) => (x: _align(x), y: _align(y));

  int _align(int value) {
    // Never turn an invalid negative input into an authorized map point.
    if (!enabled || value < 0) return value;
    return ((value + step ~/ 2) ~/ step) * step;
  }
}
