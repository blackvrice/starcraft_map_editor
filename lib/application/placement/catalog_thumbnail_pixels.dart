import 'dart:typed_data';

/// Small catalog-only preview; full map graphics are managed separately.
final class CatalogThumbnailPixels {
  CatalogThumbnailPixels._(this.width, this.height, this.rgba);

  static const maximumExtent = 64;
  static const maximumBytes = maximumExtent * maximumExtent * 4;

  factory CatalogThumbnailPixels.fromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) {
    if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
      throw ArgumentError(
        'RGBA length must match positive thumbnail dimensions.',
      );
    }
    final longest = width > height ? width : height;
    if (longest <= maximumExtent) {
      return CatalogThumbnailPixels._(width, height, rgba.asUnmodifiableView());
    }
    final outputWidth = (width * maximumExtent ~/ longest).clamp(
      1,
      maximumExtent,
    );
    final outputHeight = (height * maximumExtent ~/ longest).clamp(
      1,
      maximumExtent,
    );
    final output = Uint8List(outputWidth * outputHeight * 4);
    for (var y = 0; y < outputHeight; y++) {
      final sourceY = ((2 * y + 1) * height ~/ (2 * outputHeight));
      for (var x = 0; x < outputWidth; x++) {
        final sourceX = ((2 * x + 1) * width ~/ (2 * outputWidth));
        final source = (sourceY * width + sourceX) * 4;
        final target = (y * outputWidth + x) * 4;
        output.setRange(target, target + 4, rgba, source);
      }
    }
    return CatalogThumbnailPixels._(
      outputWidth,
      outputHeight,
      output.asUnmodifiableView(),
    );
  }

  final int width;
  final int height;
  final Uint8List rgba;
}
