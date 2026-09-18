import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// RGBA catalog preview. Callers supply a new buffer when pixels change.
class CatalogThumbnail extends StatefulWidget {
  const CatalogThumbnail({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    this.scale = 1,
    super.key,
  });

  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final double scale;

  @override
  State<CatalogThumbnail> createState() => _CatalogThumbnailState();
}

class _CatalogThumbnailState extends State<CatalogThumbnail> {
  ui.Image? _image;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(CatalogThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rgbaBytes, widget.rgbaBytes) ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _reload();
    }
  }

  void _reload() {
    _image?.dispose();
    _image = null;
    unawaited(
      _decode(++_revision, widget.rgbaBytes, widget.width, widget.height),
    );
  }

  @override
  void dispose() {
    _revision++;
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode(
    int revision,
    Uint8List bytes,
    int width,
    int height,
  ) async {
    if (width <= 0 || height <= 0 || bytes.length != width * height * 4) return;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      if (!mounted || revision != _revision) return;
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        rowBytes: width * 4,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      if (!mounted || revision != _revision) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => RawImage(
    image: _image,
    width: widget.width > 0 ? widget.width * widget.scale : 0,
    height: widget.height > 0 ? widget.height * widget.scale : 0,
    filterQuality: FilterQuality.none,
  );
}
