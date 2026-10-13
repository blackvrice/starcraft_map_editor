import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';

void main() {
  for (final size in [(32, 32), (64, 96), (96, 128), (128, 96), (8192, 32)]) {
    test(
      'box $size aligns centers by tile parity and keeps origin tile aligned',
      () {
        final box = BuildingPlacementBox(width: size.$1, height: size.$2);
        for (var x = 0; x < 256; x++) {
          final point = box.align(x, 255 - x);
          expect((point.x - box.width ~/ 2) % 32, 0);
          expect((point.y - box.height ~/ 2) % 32, 0);
          expect((point.x - x).abs(), lessThanOrEqualTo(16));
          expect((point.y - (255 - x)).abs(), lessThanOrEqualTo(16));
          expect(box.align(point.x, point.y), point);
        }
        expect(box.align(-1, -1), (x: -1, y: -1));
      },
    );
  }
  test(
    'nearest ties choose increasing coordinates on odd and even lattices',
    () {
      final box = BuildingPlacementBox(width: 96, height: 64);
      expect(box.align(32, 16), (x: 48, y: 32));
      expect(box.align(31, 15), (x: 16, y: 0));
      expect(box.align(0, 0), (x: 16, y: 0));
    },
  );
  for (final axis in [-1, 0, 31, 33, 8193, 65535]) {
    test('rejects unsupported box axis $axis', () {
      expect(
        () => BuildingPlacementBox(width: axis, height: 32),
        throwsArgumentError,
      );
      expect(
        () => BuildingPlacementBox(width: 32, height: axis),
        throwsArgumentError,
      );
    });
  }
  test('entire box must fit, exact map edges are allowed', () {
    final box = BuildingPlacementBox(width: 128, height: 96);
    expect(box.fits(x: 64, y: 48, mapWidth: 8, mapHeight: 8), isTrue);
    expect(box.fits(x: 192, y: 208, mapWidth: 8, mapHeight: 8), isTrue);
    for (final point in [(63, 48), (64, 47), (193, 208), (192, 209)]) {
      expect(
        box.fits(x: point.$1, y: point.$2, mapWidth: 8, mapHeight: 8),
        isFalse,
      );
    }
  });
}
