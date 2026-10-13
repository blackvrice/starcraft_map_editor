import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/point_placement_snap.dart';

void main() {
  test('disabled snap preserves exact coordinates', () {
    expect(PointPlacementSnap.disabled.resolve(31, 63), (x: 31, y: 63));
    expect(PointPlacementSnap.disabled.resolve(-1, 65536), (x: -1, y: 65536));
  });
  for (final step in [...PointPlacementSnap.presets, 1, 3, 17, 127]) {
    test('snap $step is nearest, ties up, idempotent and never clamps', () {
      final snap = PointPlacementSnap(enabled: true, step: step);
      for (var value = 0; value < 8192; value++) {
        final point = snap.resolve(value, value);
        expect(point.x % step, 0);
        expect((point.x - value).abs(), lessThanOrEqualTo(step ~/ 2));
        expect(snap.resolve(point.x, point.y), point);
      }
      expect(snap.resolve(step * 2, step * 3), (x: step * 2, y: step * 3));
      if (step.isEven) {
        expect(snap.resolve(step ~/ 2, -1), (x: step, y: -1));
      }
    });
  }
  for (final step in [-1, 0, 129, 65536]) {
    test('rejects invalid step $step', () {
      expect(() => PointPlacementSnap(step: step), throwsRangeError);
    });
  }
}
