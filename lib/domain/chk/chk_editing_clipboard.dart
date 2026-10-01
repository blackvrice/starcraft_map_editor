import 'dart:typed_data';
import 'chk_basic_editing.dart';
import 'raw_chk_document.dart';
import 'raw_chk_section.dart';
import 'typed/chk_string_views.dart';

/// An immutable, document-local clipboard. String IDs remain local references.
class ChkEditingClipboard {
  ChkEditingClipboard._(this.records, this.anchorX, this.anchorY);
  final Map<String, List<List<int>>> records;
  final int anchorX, anchorY;
  static const _strides = {'UNIT': 36, 'THG2': 10, 'MRGN': 20};

  static void _checkLocationString(RawChkDocument doc, ByteData record) {
    final id = record.getUint16(16, Endian.little);
    if (id == 0) return;
    final views = const ChkStringViewDecoder().decode(doc),
        tables = [...views.legacyTables, ...views.extendedTables];
    if (views.hasBlockingDiagnostics ||
        tables.length != 1 ||
        tables.single.entryForId(id) == null) {
      throw StateError(
        'Location clipboard string reference is unavailable or ambiguous.',
      );
    }
  }

  static ChkEditingClipboard capture(
    RawChkDocument doc,
    Map<String, Set<int>> selected,
  ) {
    const e = ChkBasicEditing();
    e.dimensions(doc);
    final records = <String, List<List<int>>>{};
    int? anchorX, anchorY;
    for (final entry in selected.entries) {
      final stride = _strides[entry.key];
      if (stride == null) {
        throw StateError('Unsupported clipboard object kind.');
      }
      final s = e.section(doc, entry.key, stride: stride);
      if (s == null) throw StateError('Missing clipboard source section.');
      final bytes = s.payload, picked = <List<int>>[];
      for (final i in entry.value.toList()..sort()) {
        RangeError.checkValueInInterval(
          i,
          0,
          bytes.length ~/ stride - 1,
          'record',
        );
        final record = Uint8List.fromList(
              bytes.sublist(i * stride, (i + 1) * stride),
            ),
            d = ByteData.sublistView(record);
        if (entry.key == 'UNIT' && d.getUint16(8, Endian.little) == 214) {
          throw StateError(
            'Start locations cannot be cloned; use the owner-specific tool.',
          );
        }
        if (entry.key == 'MRGN' && (i == 63 || record.every((v) => v == 0))) {
          throw StateError('Anywhere and blank locations cannot be copied.');
        }
        if (entry.key == 'MRGN') _checkLocationString(doc, d);
        if (entry.key == 'THG2') {
          final dd = e.section(doc, 'DD2 ', stride: 8);
          if (dd != null) {
            final data = ByteData.sublistView(dd.payload);
            for (var k = 0; k < data.lengthInBytes; k += 8) {
              if (data.getUint16(k + 2, Endian.little) ==
                      d.getUint16(2, Endian.little) &&
                  data.getUint16(k + 4, Endian.little) ==
                      d.getUint16(4, Endian.little)) {
                throw StateError(
                  'Doodad overlays must be copied as verified composites.',
                );
              }
            }
          }
        }
        final x = entry.key == 'MRGN'
            ? d.getUint32(0, Endian.little)
            : d.getUint16(entry.key == 'UNIT' ? 4 : 2, Endian.little);
        final y = entry.key == 'MRGN'
            ? d.getUint32(4, Endian.little)
            : d.getUint16(entry.key == 'UNIT' ? 6 : 4, Endian.little);
        anchorX = anchorX == null || x < anchorX ? x : anchorX;
        anchorY = anchorY == null || y < anchorY ? y : anchorY;
        picked.add(List.unmodifiable(record));
      }
      records[entry.key] = List.unmodifiable(picked);
    }
    if (anchorX == null || anchorY == null) {
      throw StateError('Select objects to copy.');
    }
    final clip = ChkEditingClipboard._(
      Map.unmodifiable(records),
      anchorX,
      anchorY,
    );
    clip._validateLinks(doc);
    return clip;
  }

  void _validateLinks(RawChkDocument doc) {
    final units = records['UNIT'] ?? [];
    final all = const ChkBasicEditing()
        .section(doc, 'UNIT', stride: 36)
        ?.payload;
    final allData = all == null ? null : ByteData.sublistView(all);
    final ids = <int, ByteData>{};
    for (final u in units) {
      final d = ByteData.sublistView(Uint8List.fromList(u)),
          id = d.getUint32(0, Endian.little);
      if (id != 0 && ids.containsKey(id)) {
        throw StateError('Duplicate class IDs in clipboard.');
      }
      if (id != 0) ids[id] = d;
    }
    for (final u in units) {
      final d = ByteData.sublistView(Uint8List.fromList(u)),
          flags = d.getUint16(10, Endian.little),
          peer = d.getUint32(32, Endian.little);
      if (flags == 0 && peer == 0) continue;
      final id = d.getUint32(0, Endian.little), other = ids[peer];
      if (![0x200, 0x400].contains(flags) ||
          id == 0 ||
          peer == id ||
          other == null ||
          other.getUint32(32, Endian.little) != id ||
          other.getUint16(10, Endian.little) != flags ||
          allData == null ||
          Iterable.generate(allData.lengthInBytes ~/ 36)
                  .where((k) => allData.getUint32(k * 36, Endian.little) == id)
                  .length !=
              1) {
        throw StateError('Copy both uniquely linked units together.');
      }
    }
  }

  RawChkDocument paste(RawChkDocument doc, {required int x, required int y}) {
    const e = ChkBasicEditing();
    final (w, h) = e.dimensions(doc);
    final dx = x - anchorX, dy = y - anchorY;
    var result = doc;
    final existing = e.section(doc, 'UNIT', stride: 36)?.payload;
    final used = <int>{};
    if (existing != null) {
      final d = ByteData.sublistView(existing);
      for (var at = 0; at < existing.length; at += 36) {
        used.add(d.getUint32(at, Endian.little));
      }
    }
    final ids = <int, int>{}, fresh = <int>[];
    var next = 1;
    for (final u in records['UNIT'] ?? <List<int>>[]) {
      while (used.contains(next)) {
        next++;
      }
      fresh.add(next);
      used.add(next);
      final old = ByteData.sublistView(
        Uint8List.fromList(u),
      ).getUint32(0, Endian.little);
      if (old != 0) ids[old] = next;
    }
    for (final entry in records.entries) {
      final stride = _strides[entry.key]!,
          old = e.section(result, entry.key, stride: stride);
      final bytes = old?.payload.toList() ?? <int>[];
      final pending = <List<int>>[];
      for (var i = 0; i < entry.value.length; i++) {
        final record = Uint8List.fromList(entry.value[i]),
            d = ByteData.sublistView(record);
        if (entry.key == 'MRGN') {
          _checkLocationString(doc, d);
          for (final at in [0, 8]) {
            final value = d.getUint32(at, Endian.little) + dx;
            RangeError.checkValueInInterval(value, 0, w * 32, 'location x');
            d.setUint32(at, value, Endian.little);
          }
          for (final at in [4, 12]) {
            final value = d.getUint32(at, Endian.little) + dy;
            RangeError.checkValueInInterval(value, 0, h * 32, 'location y');
            d.setUint32(at, value, Endian.little);
          }
        } else {
          final at = entry.key == 'UNIT' ? 4 : 2;
          final nx = d.getUint16(at, Endian.little) + dx,
              ny = d.getUint16(at + 2, Endian.little) + dy;
          RangeError.checkValueInInterval(nx, 0, w * 32 - 1, 'x');
          RangeError.checkValueInInterval(ny, 0, h * 32 - 1, 'y');
          d.setUint16(at, nx, Endian.little);
          d.setUint16(at + 2, ny, Endian.little);
          if (entry.key == 'UNIT') {
            final peer = d.getUint32(32, Endian.little);
            d.setUint32(0, fresh[i], Endian.little);
            d.setUint32(32, peer == 0 ? 0 : ids[peer]!, Endian.little);
          }
        }
        pending.add(record);
      }
      if (entry.key == 'MRGN') {
        if (old == null || ![1280, 5100].contains(bytes.length)) {
          throw StateError('Invalid location destination table.');
        }
        final slots = [
          for (var k = 0; k < bytes.length ~/ 20; k++)
            if (k != 63 &&
                bytes.sublist(k * 20, k * 20 + 20).every((v) => v == 0))
              k,
        ];
        if (slots.length < pending.length) {
          throw StateError('Not enough unused location slots.');
        }
        for (var i = 0; i < pending.length; i++) {
          bytes.setRange(slots[i] * 20, slots[i] * 20 + 20, pending[i]);
        }
      } else {
        bytes.addAll([for (final record in pending) ...record]);
      }
      if (old != null) {
        result = result.replaceSection(
          result.sections.indexOf(old),
          old.withPayload(bytes),
        );
      } else {
        result = result.appendSection(
          RawChkSection(
            nameBytes: entry.key.codeUnits,
            declaredLength: bytes.length,
            payload: bytes,
            sourceOffset: result.sourceLength,
            isDirty: true,
          ),
        );
      }
    }
    return result;
  }

  static RawChkDocument cut(
    RawChkDocument doc,
    Map<String, Set<int>> selected,
  ) {
    capture(doc, selected); // Includes whole-pair and composite safety checks.
    const e = ChkBasicEditing();
    var result = doc;
    for (final entry in selected.entries) {
      final stride = _strides[entry.key]!,
          old = e.section(result, entry.key, stride: stride)!;
      final bytes = old.payload.toList();
      final output = entry.key == 'MRGN' ? bytes : <int>[];
      for (var i = 0; i < bytes.length ~/ stride; i++) {
        if (entry.value.contains(i)) {
          if (entry.key == 'MRGN') {
            output.fillRange(i * stride, (i + 1) * stride, 0);
          }
        } else if (entry.key != 'MRGN') {
          output.addAll(bytes.sublist(i * stride, (i + 1) * stride));
        }
      }
      result = result.replaceSection(
        result.sections.indexOf(old),
        old.withPayload(output),
      );
    }
    return result;
  }
}
