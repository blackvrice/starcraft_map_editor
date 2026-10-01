import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/chk/chk_raw_terrain_clipboard.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  test(
    'raw terrain copy/cut/paste preserves editor terrain and rejects partial failure',
    () {
      const e = ChkBasicEditing();
      var doc = basicDocument();
      final m = e.section(doc, 'MTXM')!, bytes = m.payload;
      ByteData.sublistView(bytes)
        ..setUint16(0, 2, Endian.little)
        ..setUint16(2, 3, Endian.little)
        ..setUint16(64, 4, Endian.little)
        ..setUint16(66, 5, Endian.little);
      doc = doc.replaceSection(doc.sections.indexOf(m), m.withPayload(bytes));
      final clip = ChkRawTerrainClipboard.capture(
        doc,
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
      );
      final pasted = clip.paste(doc, x: 2, y: 3), d = basicData(pasted, 'MTXM');
      expect(d.getUint16((3 * 32 + 2) * 2, Endian.little), 2);
      expect(d.getUint16((4 * 32 + 3) * 2, Endian.little), 5);
      expect(e.section(pasted, 'TILE'), same(e.section(doc, 'TILE')));
      expect(clip.paste(doc, x: 0, y: 0), same(doc));
      expect(() => clip.paste(doc, x: 31, y: 31), throwsRangeError);
      expect(
        () => ChkRawTerrainClipboard.cut(
          doc,
          left: 0,
          top: 0,
          right: 1,
          bottom: 1,
          replacement: 99,
        ),
        throwsStateError,
      );
      final cut = ChkRawTerrainClipboard.cut(
        doc,
        left: 0,
        top: 0,
        right: 1,
        bottom: 1,
        replacement: 1,
      );
      expect(basicData(cut, 'MTXM').getUint16(0, Endian.little), 1);
      final dd = e.section(doc, 'DD2 ')!;
      final composite = doc.replaceSection(
        doc.sections.indexOf(dd),
        dd.withPayload(List.filled(8, 0)),
      );
      expect(() => clip.paste(composite, x: 2, y: 3), throwsStateError);
    },
  );
}
