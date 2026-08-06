import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';

void main() {
  const decoder = ChkObjectViewDecoder();
  const editor = ChkObjectSectionEditor();

  test('moves only coordinate bytes in fixed object records', () {
    final first = Uint8List.fromList(
      List<int>.generate(ChkUnitPlacement.recordLength, (index) => index + 1),
    );
    ByteData.sublistView(first)
      ..setUint16(4, 100, Endian.little)
      ..setUint16(6, 200, Endian.little);
    final second = Uint8List.fromList(
      List<int>.generate(ChkUnitPlacement.recordLength, (index) => 200 - index),
    );
    final document = _document([
      _section('UNIT', [...first, ...second]),
    ]);
    final view = decoder.decode(document).unitSections.single;

    final moved = editor.moveUnits(view, const {
      0: ChkObjectCoordinateDelta(dx: 7, dy: -9),
    });
    final expected = Uint8List.fromList([...first, ...second]);
    ByteData.sublistView(expected)
      ..setUint16(4, 107, Endian.little)
      ..setUint16(6, 191, Endian.little);

    expect(moved.payload, expected);
    expect(moved.isDirty, isTrue);
    expect(view.rawSection.payload, [...first, ...second]);
  });

  test('deletes fixed records without changing remaining record bytes', () {
    final records = List.generate(
      3,
      (record) => Uint8List.fromList(
        List<int>.generate(
          ChkSpritePlacement.recordLength,
          (index) => record * 40 + index,
        ),
      ),
    );
    final document = _document([
      _section('THG2', [for (final record in records) ...record]),
    ]);
    final view = decoder.decode(document).spriteSections.single;

    final deleted = editor.deleteSprites(view, const [0, 2]);

    expect(deleted.payload, records[1]);
    expect(deleted.declaredLength, ChkSpritePlacement.recordLength);
  });

  test('moves and blanks locations while preserving the table length', () {
    final payload = Uint8List(
      ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
    );
    final data = ByteData.sublistView(payload);
    data
      ..setUint32(0, 10, Endian.little)
      ..setUint32(4, 20, Endian.little)
      ..setUint32(8, 30, Endian.little)
      ..setUint32(12, 40, Endian.little)
      ..setUint16(16, 9, Endian.little)
      ..setUint16(18, 0x3f, Endian.little);
    final view = decoder
        .decode(_document([_section('MRGN', payload)]))
        .locationSections
        .single;

    final moved = editor.moveLocations(view, const {
      0: ChkObjectCoordinateDelta(dx: 5, dy: 7),
    });
    final movedData = ByteData.sublistView(moved.payload);
    expect(
      [
        movedData.getUint32(0, Endian.little),
        movedData.getUint32(4, Endian.little),
        movedData.getUint32(8, Endian.little),
        movedData.getUint32(12, Endian.little),
        movedData.getUint16(16, Endian.little),
        movedData.getUint16(18, Endian.little),
      ],
      [15, 27, 35, 47, 9, 0x3f],
    );

    final movedView = decoder
        .decode(_document([moved]))
        .locationSections
        .single;
    final deleted = editor.deleteLocations(movedView, const [0]);
    expect(deleted.declaredLength, payload.length);
    expect(deleted.payload.take(ChkLocation.recordLength), everyElement(0));
  });

  test('rejects record and unsigned-coordinate overflow', () {
    final bytes = Uint8List(ChkDoodadPlacement.recordLength);
    ByteData.sublistView(bytes)
      ..setUint16(2, 1, Endian.little)
      ..setUint16(4, 1, Endian.little);
    final view = decoder
        .decode(_document([_section('DD2 ', bytes)]))
        .doodadSections
        .single;

    expect(
      () => editor.moveDoodads(view, const {
        0: ChkObjectCoordinateDelta(dx: -2, dy: 0),
      }),
      throwsRangeError,
    );
    expect(() => editor.deleteDoodads(view, const [1]), throwsRangeError);
  });
}

RawChkDocument _document(List<RawChkSection> sections) {
  var offset = 0;
  final positioned = <RawChkSection>[];
  for (final section in sections) {
    positioned.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: offset,
      ),
    );
    offset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(sections: positioned, sourceLength: offset);
}

RawChkSection _section(String name, List<int> payload) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: payload.length,
  payload: payload,
  sourceOffset: 0,
);
