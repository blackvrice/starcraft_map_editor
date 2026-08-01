import 'dart:typed_data';
import 'dart:ui' as ui;

abstract interface class TerrainTileTexture {
  int get width;

  int get height;

  ui.Image get image;

  void dispose();
}

abstract interface class TerrainTileTextureFactory {
  Future<TerrainTileTexture> create(Uint8List rgbaBytes);
}

final class UiTerrainTileTexture implements TerrainTileTexture {
  UiTerrainTileTexture(this.image);

  @override
  final ui.Image image;

  @override
  int get width => image.width;

  @override
  int get height => image.height;

  @override
  void dispose() => image.dispose();
}

final class UiTerrainTileTextureFactory implements TerrainTileTextureFactory {
  const UiTerrainTileTextureFactory();

  static const tileSize = 32;
  static const bytesPerPixel = 4;
  static const rgbaBytesPerTile = tileSize * tileSize * bytesPerPixel;

  @override
  Future<TerrainTileTexture> create(Uint8List rgbaBytes) async {
    if (rgbaBytes.length != rgbaBytesPerTile) {
      throw ArgumentError.value(
        rgbaBytes.length,
        'rgbaBytes.length',
        'A terrain tile must contain exactly $rgbaBytesPerTile RGBA bytes.',
      );
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(rgbaBytes);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: tileSize,
        height: tileSize,
        rowBytes: tileSize * bytesPerPixel,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      return UiTerrainTileTexture(frame.image);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
