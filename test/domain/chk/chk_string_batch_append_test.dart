import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import '../../fixtures/basic_editing_fixture.dart';

void main() {
  for (final extended in [false, true]) {
    test(
      '${extended ? 'STRx' : 'STR'} batch append preserves aliases, raw bytes and unused trailing data',
      () {
        final width = extended ? 4 : 2,
            bytes = Uint8List((extended ? 12 : 6) + 5);
        final data = ByteData.sublistView(bytes);
        if (extended) {
          data
            ..setUint32(0, 2, Endian.little)
            ..setUint32(4, 12, Endian.little)
            ..setUint32(8, 12, Endian.little);
        } else {
          data
            ..setUint16(0, 2, Endian.little)
            ..setUint16(2, 6, Endian.little)
            ..setUint16(4, 6, Endian.little);
        }
        bytes.setAll(3 * width, [0x81, 0xff, 0, 123, 45]);
        final doc = RawChkDocument(
          sections: [basicSection(extended ? 'STRx' : 'STR ', bytes)],
          sourceLength: 0,
        );
        final table = ChkResourceEditor.table(doc);
        final added = table.withAddedRawStrings(
          rawStrings: [
            [],
            [4, 254],
            [65],
          ],
        );
        final result = doc.replaceSection(0, added.section),
            view = ChkResourceEditor.table(result);
        expect(added.stringIds, [3, 4, 5]);
        expect(view.entries.map((e) => e.rawBytes).toList(), [
          [0x81, 0xff],
          [0x81, 0xff],
          [],
          [4, 254],
          [65],
        ]);
        expect(view.entries[0].rawOffset, view.entries[1].rawOffset);
        expect(added.section.payload.sublist(6 * width, 6 * width + 5), [
          0x81,
          0xff,
          0,
          123,
          45,
        ]);
        expect(
          table.withAddedRawStrings(rawStrings: []).section,
          same(table.rawSection),
        );
        expect(table.rawSection.payload, bytes);
        expect(
          () => table.withAddedRawStrings(
            rawStrings: [
              [0],
            ],
          ),
          throwsArgumentError,
        );
      },
    );
  }
  test(
    'legacy batch checks every new offset without changing the existing single-string contract',
    () {
      final bytes = Uint8List(65530);
      ByteData.sublistView(bytes)
        ..setUint16(0, 1, Endian.little)
        ..setUint16(2, 4, Endian.little);
      final table = ChkResourceEditor.table(
        RawChkDocument(
          sections: [basicSection('STR ', bytes)],
          sourceLength: 0,
        ),
      );
      expect(
        () => table.withAddedRawStrings(
          rawStrings: [
            [65],
            [66],
          ],
        ),
        throwsRangeError,
      );
      expect(table.withAddedRawString(rawBytes: [65, 66, 67, 68]).stringId, 2);
    },
  );
}
