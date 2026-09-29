import 'dart:math' as math;
import 'dart:typed_data';

import 'raw_chk_document.dart';
import 'raw_chk_section.dart';

enum MapResizeAnchor {
  topLeft(0, 0, 'Top left'),
  top(1, 0, 'Top'),
  topRight(2, 0, 'Top right'),
  left(0, 1, 'Left'),
  center(1, 1, 'Center'),
  right(2, 1, 'Right'),
  bottomLeft(0, 2, 'Bottom left'),
  bottom(1, 2, 'Bottom'),
  bottomRight(2, 2, 'Bottom right');

  const MapResizeAnchor(this.x, this.y, this.label);
  final int x, y;
  final String label;
}

final class MapResizeOptions {
  MapResizeOptions({
    required this.width,
    required this.height,
    this.anchor = MapResizeAnchor.topLeft,
    this.fillX = 0,
    this.fillY = 0,
  }) {
    for (final size in [width, height]) {
      if (size < 32 || size > 256 || size % 32 != 0) {
        throw ArgumentError('Choose dimensions from 32 to 256 in steps of 32.');
      }
    }
  }
  final int width, height, fillX, fillY;
  final MapResizeAnchor anchor;
}

/// Immutable preview; no section is changed before explicit application.
final class MapResizePreview {
  MapResizePreview._({
    required this.source,
    required this.options,
    required this.oldWidth,
    required this.oldHeight,
    required this.dx,
    required this.dy,
    required this.croppedTiles,
    required this.addedTiles,
    required this.outsideUnits,
    required this.outsideSprites,
    required this.clippedLocations,
    required this.movedUnits,
    required this.movedSprites,
    required this.fillTile,
    required List<String> blockers,
    required this.result,
  }) : blockers = List.unmodifiable(blockers);
  final RawChkDocument source;
  final MapResizeOptions options;
  final int oldWidth, oldHeight, dx, dy, croppedTiles, addedTiles;
  final int outsideUnits,
      outsideSprites,
      clippedLocations,
      movedUnits,
      movedSprites;
  final int fillTile;
  final List<String> blockers;
  final RawChkDocument? result;
  bool get canApply => blockers.isEmpty && result != null;
  bool get needsCropConfirmation => croppedTiles > 0 || clippedLocations > 0;

  RawChkDocument apply({required bool acceptCropping}) {
    if (!canApply) throw StateError(blockers.join(' '));
    if (needsCropConfirmation && !acceptCropping) {
      throw StateError('Confirm terrain, fog and location cropping first.');
    }
    return result!;
  }
}

class MapResizeEditor {
  const MapResizeEditor();

  MapResizePreview preview(RawChkDocument source, MapResizeOptions options) {
    final blockers = <String>[];
    RawChkSection? section(String name, {bool required = false}) {
      final matches = source.sections.where((s) => s.name == name).toList();
      if (matches.length > 1 || (required && matches.isEmpty)) {
        throw StateError(
          'Resize requires ${required ? "exactly one" : "at most one"} $name section.',
        );
      }
      return matches.isEmpty ? null : matches.single;
    }

    final dim = section('DIM ', required: true)!;
    if (dim.payload.length != 4) throw StateError('Invalid DIM section.');
    final dims = ByteData.sublistView(dim.payload);
    final w = dims.getUint16(0, Endian.little),
        h = dims.getUint16(2, Endian.little);
    if (w < 1 || w > 256 || h < 1 || h > 256) {
      throw StateError('Unsupported source dimensions.');
    }
    final nw = options.width, nh = options.height;
    final dx = ((nw - w) * options.anchor.x / 2).floor();
    final dy = ((nh - h) * options.anchor.y / 2).floor();
    final overlapW = math.max<int>(
      0,
      math.min<int>(w + dx, nw) - math.max<int>(0, dx),
    );
    final overlapH = math.max<int>(
      0,
      math.min<int>(h + dy, nh) - math.max<int>(0, dy),
    );
    if (w == nw && h == nh) blockers.add('Choose a different map size.');
    if (section('ISOM') != null ||
        source.sections.any((s) => s.isEuddraftProtectionMarker)) {
      blockers.add(
        'ISOM/protected maps require a verified isometric terrain conversion.',
      );
    }
    final dd = section('DD2 ');
    if (dd != null && dd.payload.isNotEmpty) {
      blockers.add(
        'Doodad terrain and overlay ownership cannot yet be resized safely.',
      );
    }
    final replacements = <RawChkSection, RawChkSection>{};
    final updatedDim = ByteData(4)
      ..setUint16(0, nw, Endian.little)
      ..setUint16(2, nh, Endian.little);
    replacements[dim] = dim.withPayload(updatedDim.buffer.asUint8List());
    final terrain = section('MTXM', required: true)!;
    if (terrain.payload.length != w * h * 2) {
      throw StateError('Invalid MTXM grid.');
    }
    RangeError.checkValueInInterval(options.fillX, 0, w - 1, 'fillX');
    RangeError.checkValueInInterval(options.fillY, 0, h - 1, 'fillY');
    final sample = (options.fillY * w + options.fillX) * 2;
    final fill = ByteData.sublistView(
      terrain.payload,
    ).getUint16(sample, Endian.little);
    for (final name in ['MTXM', 'TILE', 'MASK']) {
      final s = section(name);
      if (s == null) continue;
      final stride = name == 'MASK' ? 1 : 2;
      if (s.payload.length != w * h * stride) {
        throw StateError('Invalid $name grid.');
      }
      final old = s.payload;
      final bytes = Uint8List(nw * nh * stride);
      for (var y = 0; y < nh; y++) {
        for (var x = 0; x < nw; x++) {
          final sx = x - dx, sy = y - dy;
          final at = (y * nw + x) * stride;
          if (sx >= 0 && sx < w && sy >= 0 && sy < h) {
            final from = (sy * w + sx) * stride;
            bytes.setRange(at, at + stride, old, from);
          } else if (stride == 1) {
            bytes[at] = 255; // New cells start hidden for every player.
          } else {
            bytes[at] = fill & 255;
            bytes[at + 1] = fill >> 8;
          }
        }
      }
      replacements[s] = s.withPayload(bytes);
    }
    var outsideUnits = 0, outsideSprites = 0, movedUnits = 0, movedSprites = 0;
    for (final name in ['UNIT', 'THG2']) {
      final s = section(name);
      if (s == null) continue;
      final stride = name == 'UNIT' ? 36 : 10;
      final coord = name == 'UNIT' ? 4 : 2;
      if (s.payload.length % stride != 0) {
        throw StateError('Truncated $name record.');
      }
      final bytes = s.payload;
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length; i += stride) {
        final oldX = data.getUint16(i + coord, Endian.little);
        final oldY = data.getUint16(i + coord + 2, Endian.little);
        if (oldX >= w * 32 || oldY >= h * 32) {
          throw StateError('$name has a coordinate outside the source map.');
        }
        final x = oldX + dx * 32;
        final y = oldY + dy * 32;
        if (x < 0 || x >= nw * 32 || y < 0 || y >= nh * 32) {
          if (name == 'UNIT') {
            outsideUnits++;
          } else {
            outsideSprites++;
          }
          continue;
        }
        if (dx != 0 || dy != 0) {
          if (name == 'UNIT') {
            movedUnits++;
          } else {
            movedSprites++;
          }
        }
        data.setUint16(i + coord, x, Endian.little);
        data.setUint16(i + coord + 2, y, Endian.little);
      }
      replacements[s] = s.withPayload(bytes);
    }
    if (outsideUnits + outsideSprites > 0) {
      blockers.add(
        '$outsideUnits units and $outsideSprites sprites would leave the map. Move them or change the anchor/size; no records are deleted.',
      );
    }
    var clippedLocations = 0;
    final locations = section('MRGN');
    if (locations != null) {
      final bytes = locations.payload;
      if (bytes.length != 64 * 20 && bytes.length != 255 * 20) {
        throw StateError('Invalid MRGN section.');
      }
      final data = ByteData.sublistView(bytes);
      for (var at = 0; at < bytes.length; at += 20) {
        if (bytes.sublist(at, at + 20).every((b) => b == 0)) continue;
        final values = [
          for (var j = 0; j < 4; j++) data.getUint32(at + j * 4, Endian.little),
        ];
        if (at == 63 * 20 &&
            values[0] == 0 &&
            values[1] == 0 &&
            values[2] == w * 32 &&
            values[3] == h * 32) {
          data.setUint32(at + 8, nw * 32, Endian.little);
          data.setUint32(at + 12, nh * 32, Endian.little);
          continue;
        }
        var clipped = false;
        for (var j = 0; j < 4; j++) {
          final shifted = values[j] + (j.isEven ? dx : dy) * 32;
          final bounded = shifted.clamp(0, (j.isEven ? nw : nh) * 32);
          clipped |= bounded != shifted;
          data.setUint32(at + j * 4, bounded, Endian.little);
        }
        if (clipped) clippedLocations++;
      }
      replacements[locations] = locations.withPayload(bytes);
    }
    return MapResizePreview._(
      source: source,
      options: options,
      oldWidth: w,
      oldHeight: h,
      dx: dx,
      dy: dy,
      croppedTiles: w * h - overlapW * overlapH,
      addedTiles: nw * nh - overlapW * overlapH,
      outsideUnits: outsideUnits,
      outsideSprites: outsideSprites,
      clippedLocations: clippedLocations,
      movedUnits: movedUnits,
      movedSprites: movedSprites,
      fillTile: fill,
      blockers: blockers,
      result: blockers.isEmpty
          ? RawChkDocument(
              sections: [for (final s in source.sections) replacements[s] ?? s],
              sourceLength: source.sourceLength,
            )
          : null,
    );
  }
}
