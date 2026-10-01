import 'dart:typed_data';
import 'chk_basic_editing.dart';
import 'raw_chk_document.dart';

/// Raw MTXM editing deliberately retains TILE/ISOM, like the existing raw brush.
/// Doodad maps are excluded until a composite footprint is explicitly verified.
class ChkRawTerrainClipboard {
  ChkRawTerrainClipboard._(this.width, this.height, this.values);
  final int width, height;
  final List<int> values;
  static ByteData _grid(RawChkDocument doc) {
    const e = ChkBasicEditing();
    final (w, h) = e.dimensions(doc);
    final dd = e.section(doc, 'DD2 ', stride: 8);
    if (dd != null && dd.payload.isNotEmpty) {
      throw StateError('Raw terrain clipboard cannot edit Doodad composites.');
    }
    final m = e.section(doc, 'MTXM');
    if (m == null || m.payload.length != w * h * 2) {
      throw StateError('A complete MTXM grid is required.');
    }
    return ByteData.sublistView(m.payload);
  }

  static ChkRawTerrainClipboard capture(
    RawChkDocument doc, {
    required int left,
    required int top,
    required int right,
    required int bottom,
  }) {
    const e = ChkBasicEditing();
    final (w, h) = e.dimensions(doc);
    final d = _grid(doc);
    RangeError.checkValueInInterval(left, 0, w - 1, 'left');
    RangeError.checkValueInInterval(right, left, w - 1, 'right');
    RangeError.checkValueInInterval(top, 0, h - 1, 'top');
    RangeError.checkValueInInterval(bottom, top, h - 1, 'bottom');
    return ChkRawTerrainClipboard._(
      right - left + 1,
      bottom - top + 1,
      List.unmodifiable([
        for (var y = top; y <= bottom; y++)
          for (var x = left; x <= right; x++)
            d.getUint16((y * w + x) * 2, Endian.little),
      ]),
    );
  }

  RawChkDocument paste(RawChkDocument doc, {required int x, required int y}) {
    const e = ChkBasicEditing();
    final (w, h) = e.dimensions(doc);
    final d = _grid(doc);
    RangeError.checkValueInInterval(x, 0, w - width, 'x');
    RangeError.checkValueInInterval(y, 0, h - height, 'y');
    var changed = false;
    for (var cy = 0; cy < height; cy++) {
      for (var cx = 0; cx < width; cx++) {
        final at = ((y + cy) * w + x + cx) * 2, v = values[cy * width + cx];
        changed |= d.getUint16(at, Endian.little) != v;
        d.setUint16(at, v, Endian.little);
      }
    }
    if (!changed) return doc;
    final old = e.section(doc, 'MTXM')!;
    return doc.replaceSection(
      doc.sections.indexOf(old),
      old.withPayload(d.buffer.asUint8List()),
    );
  }

  static RawChkDocument cut(
    RawChkDocument doc, {
    required int left,
    required int top,
    required int right,
    required int bottom,
    required int replacement,
  }) {
    final clip = capture(
          doc,
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        ),
        d = _grid(doc);
    if (!Iterable.generate(
      d.lengthInBytes ~/ 2,
    ).any((i) => d.getUint16(i * 2, Endian.little) == replacement)) {
      throw StateError(
        'Cut replacement must be a tile already present in this map.',
      );
    }
    return ChkRawTerrainClipboard._(
      clip.width,
      clip.height,
      List.filled(clip.values.length, replacement),
    ).paste(doc, x: left, y: top);
  }
}
