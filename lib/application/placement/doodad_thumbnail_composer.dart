import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/placement/doodad_placement_recipe.dart';
import '../ports/starcraft_object_atlas_gateway.dart';
import 'catalog_thumbnail_pixels.dart';

/// Samples verified footprint tiles and a center-anchored overlay without
/// allocating a full-size composite. All input pixels are premultiplied RGBA.
abstract final class DoodadThumbnailComposer {
  static CatalogThumbnailPixels compose({
    required DoodadPlacementRecipe recipe,
    required Map<int, Uint8List> tiles,
    StarCraftObjectAtlasEntry? overlay,
  }) {
    if ((recipe.overlay != null) != (overlay != null)) {
      throw ArgumentError('An overlay recipe requires its complete graphic.');
    }
    if (overlay != null && overlay.key != overlayKey(recipe.overlay!)) {
      throw ArgumentError('The overlay graphic does not match the recipe.');
    }
    for (final cell in recipe.footprint) {
      if (cell.rawTileValue != null &&
          tiles[cell.rawTileValue]?.length != 32 * 32 * 4) {
        throw ArgumentError('Every written footprint tile needs valid pixels.');
      }
    }
    final overlayLeft = recipe.centerOffsetX - (overlay?.anchorX ?? 0);
    final overlayTop = recipe.centerOffsetY - (overlay?.anchorY ?? 0);
    final left = overlay == null ? 0 : math.min(0, overlayLeft);
    final top = overlay == null ? 0 : math.min(0, overlayTop);
    final right = math.max(
      recipe.width * 32,
      overlay == null ? 0 : overlayLeft + overlay.width,
    );
    final bottom = math.max(
      recipe.height * 32,
      overlay == null ? 0 : overlayTop + overlay.height,
    );
    final width = right - left;
    final height = bottom - top;
    final longest = math.max(width, height);
    final extent = math.min(longest, CatalogThumbnailPixels.maximumExtent);
    final outputWidth = math.max(1, width * extent ~/ longest);
    final outputHeight = math.max(1, height * extent ~/ longest);
    final output = Uint8List(outputWidth * outputHeight * 4);
    for (var y = 0; y < outputHeight; y++) {
      final sourceY = top + (2 * y + 1) * height ~/ (2 * outputHeight);
      for (var x = 0; x < outputWidth; x++) {
        final sourceX = left + (2 * x + 1) * width ~/ (2 * outputWidth);
        final target = (y * outputWidth + x) * 4;
        if (sourceX >= 0 &&
            sourceX < recipe.width * 32 &&
            sourceY >= 0 &&
            sourceY < recipe.height * 32) {
          final cell =
              recipe.footprint[(sourceY ~/ 32) * recipe.width + sourceX ~/ 32];
          final tile = tiles[cell.rawTileValue];
          if (cell.writesTerrain && tile != null) {
            final source = ((sourceY % 32) * 32 + sourceX % 32) * 4;
            output.setRange(target, target + 4, tile, source);
          }
        }
        if (overlay != null) {
          final ox = sourceX - overlayLeft;
          final oy = sourceY - overlayTop;
          if (ox >= 0 && oy >= 0 && ox < overlay.width && oy < overlay.height) {
            final source = (oy * overlay.width + ox) * 4;
            final inverseAlpha = 255 - overlay.rgbaBytes[source + 3];
            for (var channel = 0; channel < 4; channel++) {
              output[target + channel] =
                  (overlay.rgbaBytes[source + channel] +
                          (output[target + channel] * inverseAlpha + 127) ~/
                              255)
                      .clamp(0, 255);
            }
          }
        }
      }
    }
    return CatalogThumbnailPixels.fromRgba(output, outputWidth, outputHeight);
  }

  static StarCraftObjectGraphicKey overlayKey(DoodadOverlayRecipe overlay) =>
      StarCraftObjectGraphicKey(
        kind: overlay.semantic == DoodadOverlaySemantic.pureSprite
            ? StarCraftObjectGraphicKind.sprite
            : StarCraftObjectGraphicKind.unit,
        id: overlay.id,
      );
}
