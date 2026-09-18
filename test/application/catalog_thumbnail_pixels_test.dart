import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/catalog_thumbnail_pixels.dart';

void main() {
  test('bounds landscape and portrait previews and preserves sampled RGBA', () {
    for (final size in [
      (128, 256),
      (256, 128),
      (256, 256),
      (1, 256),
      (256, 1),
    ]) {
      final (width, height) = size;
      final source = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          source.setRange((y * width + x) * 4, (y * width + x) * 4 + 4, [
            x,
            y,
            50,
            (x + y) % 256,
          ]);
        }
      }
      final result = CatalogThumbnailPixels.fromRgba(source, width, height);
      expect(result.width, inInclusiveRange(1, 64));
      expect(result.height, inInclusiveRange(1, 64));
      expect(result.rgba.length, result.width * result.height * 4);
      expect(
        result.rgba.length,
        lessThanOrEqualTo(CatalogThumbnailPixels.maximumBytes),
      );
      expect(
        (result.width, result.height),
        switch (size) {
          (128, 256) => (32, 64),
          (256, 128) => (64, 32),
          (256, 256) => (64, 64),
          (1, 256) => (1, 64),
          _ => (64, 1),
        },
      );
      for (final position in [(0, 0), (result.width - 1, result.height - 1)]) {
        final (x, y) = position;
        final sx = ((x + 0.5) * width / result.width).floor();
        final sy = ((y + 0.5) * height / result.height).floor();
        final at = (y * result.width + x) * 4;
        expect(result.rgba.sublist(at, at + 4), [sx, sy, 50, (sx + sy) % 256]);
      }
      expect(() => result.rgba[0] = 0, throwsUnsupportedError);
    }
  });
  test('keeps small previews exact and rejects malformed input', () {
    final source = Uint8List.fromList([1, 2, 3, 0, 4, 5, 6, 255]);
    final result = CatalogThumbnailPixels.fromRgba(source, 2, 1);
    expect((result.width, result.height), (2, 1));
    expect(result.rgba, source);
    expect(
      () => CatalogThumbnailPixels.fromRgba(source, 1, 1),
      throwsArgumentError,
    );
    expect(
      () => CatalogThumbnailPixels.fromRgba(Uint8List(0), 0, 1),
      throwsArgumentError,
    );
  });
}
