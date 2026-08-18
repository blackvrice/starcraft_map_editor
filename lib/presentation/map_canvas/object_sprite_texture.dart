import 'dart:ui' as ui;

import '../../application/objects/object_sprite_atlas_loader.dart';

abstract interface class ObjectSpriteTexture {
  int get spriteId;

  int get imageId;

  int get width;

  int get height;

  int get anchorX;

  int get anchorY;

  int get frameIndex;

  ui.Image get image;

  void dispose();
}

abstract interface class ObjectSpriteTextureFactory {
  Future<ObjectSpriteTexture> create(ObjectSpriteRgbaFrame frame);
}

final class UiObjectSpriteTexture implements ObjectSpriteTexture {
  UiObjectSpriteTexture({
    required ObjectSpriteRgbaFrame frame,
    required this.image,
  }) : spriteId = frame.spriteId,
       imageId = frame.imageId,
       width = frame.width,
       height = frame.height,
       anchorX = frame.anchorX,
       anchorY = frame.anchorY,
       frameIndex = frame.frameIndex;

  @override
  final int spriteId;

  @override
  final int imageId;

  @override
  final int width;

  @override
  final int height;

  @override
  final int anchorX;

  @override
  final int anchorY;

  @override
  final int frameIndex;

  @override
  final ui.Image image;

  @override
  void dispose() => image.dispose();
}

final class UiObjectSpriteTextureFactory implements ObjectSpriteTextureFactory {
  const UiObjectSpriteTextureFactory();

  static const bytesPerPixel = 4;

  @override
  Future<ObjectSpriteTexture> create(ObjectSpriteRgbaFrame frame) async {
    final expectedBytes = frame.width * frame.height * bytesPerPixel;
    if (frame.width <= 0 ||
        frame.height <= 0 ||
        frame.rgbaBytes.length != expectedBytes) {
      throw ArgumentError.value(
        frame.rgbaBytes.length,
        'frame.rgbaBytes.length',
        'Object RGBA bytes must match the declared dimensions.',
      );
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(frame.rgbaBytes);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: frame.width,
        height: frame.height,
        rowBytes: frame.width * bytesPerPixel,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final decoded = await codec.getNextFrame();
      return UiObjectSpriteTexture(frame: frame, image: decoded.image);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
