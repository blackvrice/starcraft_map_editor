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

  test('duplicates a template record and changes only its coordinates', () {
    final template = Uint8List.fromList(
      List<int>.generate(ChkUnitPlacement.recordLength, (index) => 180 - index),
    );
    ByteData.sublistView(template)
      ..setUint16(4, 10, Endian.little)
      ..setUint16(6, 20, Endian.little);
    final view = decoder
        .decode(_document([_section('UNIT', template)]))
        .unitSections
        .single;

    final duplicated = editor.duplicateUnit(
      view,
      templateRecordIndex: 0,
      x: 300,
      y: 400,
    );

    expect(duplicated.declaredLength, ChkUnitPlacement.recordLength * 2);
    expect(duplicated.payload.take(ChkUnitPlacement.recordLength), template);
    final copy = Uint8List.fromList(
      duplicated.payload.skip(ChkUnitPlacement.recordLength).toList(),
    );
    final expected = Uint8List.fromList(template);
    ByteData.sublistView(expected)
      ..setUint16(4, 300, Endian.little)
      ..setUint16(6, 400, Endian.little);
    expect(copy, expected);
  });

  test('updates supported unit properties and preserves every other byte', () {
    final record = Uint8List.fromList(
      List<int>.generate(ChkUnitPlacement.recordLength, (index) => 220 - index),
    );
    final view = decoder
        .decode(_document([_section('UNIT', record)]))
        .unitSections
        .single;

    final updated = editor.updateUnitProperties(
      view,
      recordIndex: 0,
      unitType: 321,
      x: 123,
      y: 234,
      owner: 7,
      hitpointPercent: 80,
      shieldPercent: 70,
      energyPercent: 60,
      resourceAmount: 0x12345678,
      hangarAmount: 19,
    );
    final expected = Uint8List.fromList(record);
    ByteData.sublistView(expected)
      ..setUint16(4, 123, Endian.little)
      ..setUint16(6, 234, Endian.little)
      ..setUint16(8, 321, Endian.little)
      ..setUint8(16, 7)
      ..setUint8(17, 80)
      ..setUint8(18, 70)
      ..setUint8(19, 60)
      ..setUint32(20, 0x12345678, Endian.little)
      ..setUint16(24, 19, Endian.little);

    expect(updated.payload, expected);
    expect(view.rawSection.payload, record);
    expect(
      () => editor.updateUnitProperties(
        view,
        recordIndex: 0,
        unitType: 1,
        x: 1,
        y: 1,
        owner: 1,
        hitpointPercent: 101,
        shieldPercent: 100,
        energyPercent: 100,
        resourceAmount: 0,
        hangarAmount: 0,
      ),
      throwsRangeError,
    );
  });

  test(
    'updates doodad and sprite properties without rewriting opaque bytes',
    () {
      final doodadRecord = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 1]);
      final spriteRecord = Uint8List.fromList([
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        0xa5,
        0x34,
        0xb2,
      ]);
      final views = decoder.decode(
        _document([
          _section('DD2 ', doodadRecord),
          _section('THG2', spriteRecord),
        ]),
      );

      final doodad = editor.updateDoodadProperties(
        views.doodadSections.single,
        recordIndex: 0,
        doodadType: 20,
        x: 30,
        y: 40,
        owner: 5,
        enabledValue: 0,
      );
      expect(doodad.payload, [20, 0, 30, 0, 40, 0, 5, 0]);

      final sprite = editor.updateSpriteProperties(
        views.spriteSections.single,
        recordIndex: 0,
        spriteType: 50,
        x: 60,
        y: 70,
        owner: 8,
      );
      expect(sprite.payload, [50, 0, 60, 0, 70, 0, 8, 0xa5, 0x34, 0xb2]);
      expect(
        () => editor.updateDoodadProperties(
          views.doodadSections.single,
          recordIndex: 0,
          doodadType: 1,
          x: 1,
          y: 1,
          owner: 1,
          enabledValue: 2,
        ),
        throwsRangeError,
      );
    },
  );

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
