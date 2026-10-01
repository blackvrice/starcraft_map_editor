import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/chk/chk_editing_clipboard.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  const e = ChkBasicEditing();
  test(
    'linked copy remaps class IDs and peer references without changing source bytes',
    () {
      final original = basicDocument(
        units: [
          basicUnit(type: 134, id: 1, x: 64, y: 64),
          basicUnit(type: 134, id: 2, x: 128, y: 64),
        ],
      );
      final linked = e.linkUnits(original, 0, 1, addon: false);
      expect(
        () => ChkEditingClipboard.capture(linked, {
          'UNIT': {0},
        }),
        throwsStateError,
      );
      final clip = ChkEditingClipboard.capture(linked, {
        'UNIT': {0, 1},
      });
      final pasted = clip.paste(linked, x: 192, y: 128),
          d = basicData(pasted, 'UNIT');
      expect(d.getUint32(72, Endian.little), 3);
      expect(d.getUint32(108, Endian.little), 4);
      expect(d.getUint32(104, Endian.little), 4);
      expect(d.getUint32(140, Endian.little), 3);
      expect(d.getUint16(76, Endian.little), 192);
      expect(d.getUint16(112, Endian.little), 256);
      expect(pasted.sections.last, same(linked.sections.last));
      expect(basicData(linked, 'UNIT').lengthInBytes, 72);
      expect(() => clip.paste(linked, x: 1000, y: 1000), throwsRangeError);
      final cut = ChkEditingClipboard.cut(linked, {
        'UNIT': {0, 1},
      });
      expect(basicData(cut, 'UNIT').lengthInBytes, 0);
      final restored = clip.paste(cut, x: 64, y: 64);
      expect(basicData(restored, 'UNIT').getUint32(32, Endian.little), 2);
    },
  );
  test(
    'locations use blank slots, keep strings/elevations and reject Anywhere',
    () {
      final doc = basicDocument(),
          old = e.section(doc, 'MRGN')!,
          bytes = old.payload;
      ByteData.sublistView(bytes)
        ..setUint32(0, 32, Endian.little)
        ..setUint32(4, 64, Endian.little)
        ..setUint32(8, 128, Endian.little)
        ..setUint32(12, 96, Endian.little)
        ..setUint16(16, 7, Endian.little)
        ..setUint16(18, 0x8005, Endian.little);
      final source = doc.replaceSection(
        doc.sections.indexOf(old),
        old.withPayload(bytes),
      );
      final clip = ChkEditingClipboard.capture(source, {
        'MRGN': {0},
      });
      final d = basicData(clip.paste(source, x: 64, y: 96), 'MRGN');
      expect(d.getUint32(20, Endian.little), 64);
      expect(d.getUint32(28, Endian.little), 160);
      expect(d.getUint16(36, Endian.little), 7);
      expect(d.getUint16(38, Endian.little), 0x8005);
      expect(
        () => ChkEditingClipboard.capture(source, {
          'MRGN': {63},
        }),
        throwsStateError,
      );
      expect(
        () => ChkEditingClipboard.capture(source, {
          'MRGN': {2},
        }),
        throwsStateError,
      );
      final cut = ChkEditingClipboard.cut(source, {
        'MRGN': {0},
      });
      expect(basicData(cut, 'MRGN').getUint32(0, Endian.little), 0);
      expect(basicData(cut, 'MRGN').getUint16(18, Endian.little), 0);
    },
  );
  test(
    'start location duplication and ambiguous object sections are refused',
    () {
      final doc = basicDocument(units: [basicUnit(type: 214)]);
      expect(
        () => ChkEditingClipboard.capture(doc, {
          'UNIT': {0},
        }),
        throwsStateError,
      );
      expect(
        () => ChkEditingClipboard.capture(
          doc.appendSection(basicSection('UNIT', [])),
          {
            'UNIT': {0},
          },
        ),
        throwsStateError,
      );
      expect(
        () => ChkEditingClipboard.capture(doc, {
          'DD2 ': {0},
        }),
        throwsStateError,
      );
    },
  );
}
