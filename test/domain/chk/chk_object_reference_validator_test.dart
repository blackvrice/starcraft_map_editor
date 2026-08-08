import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const validator = ChkObjectReferenceValidator();
  const metadataDecoder = ChkMetadataViewDecoder();
  const stringDecoder = ChkStringViewDecoder();
  const objectDecoder = ChkObjectViewDecoder();

  List<EditorDiagnostic> validate(RawChkDocument document) =>
      validator.validate(
        metadataViews: metadataDecoder.decode(document),
        stringViews: stringDecoder.decode(document),
        objectViews: objectDecoder.decode(document),
      );

  test('accepts valid object, player, location, and string references', () {
    final document = _documentFromSections([
      _section('DIM ', const [8, 0, 8, 0]),
      _section('SPRP', const [1, 0, 2, 0]),
      _section('STR ', _legacyStringTable(['Arena', 'Description'])),
      _section('UNIT', _unitRecord(x: 64, y: 64, owner: 0)),
      _section('DD2 ', _doodadRecord(x: 128, y: 128, owner: 11)),
      _section('THG2', _spriteRecord(x: 256, y: 256, owner: 5)),
      _section(
        'MRGN',
        _locations(left: 0, top: 0, right: 256, bottom: 256, stringId: 1),
      ),
    ]);

    expect(validate(document), isEmpty);
    expect(document.isDirty, isFalse);
  });

  test('reports every invalid semantic reference at its raw field', () {
    final document = _documentFromSections([
      _section('DIM ', const [8, 0, 8, 0]),
      _section('SPRP', const [3, 0, 1, 0]),
      _section('STR ', _legacyStringTable(['Only', 'Second'])),
      _section('UNIT', _unitRecord(x: 257, y: 64, owner: 12)),
      _section('DD2 ', _doodadRecord(x: 64, y: 300, owner: 255)),
      _section('THG2', _spriteRecord(x: 32, y: 32, owner: 1)),
      _section(
        'MRGN',
        _locations(left: 200, top: 50, right: 100, bottom: 300, stringId: 99),
      ),
    ]);

    final diagnostics = validate(document);

    expect(diagnostics.map((diagnostic) => diagnostic.code), [
      ChkObjectReferenceDiagnosticCodes.coordinateOutOfBounds,
      ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
      ChkObjectReferenceDiagnosticCodes.coordinateOutOfBounds,
      ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
      ChkObjectReferenceDiagnosticCodes.locationBoundsInvalid,
      ChkObjectReferenceDiagnosticCodes.stringReferenceOutOfRange,
      ChkObjectReferenceDiagnosticCodes.stringReferenceOutOfRange,
    ]);
    expect(
      diagnostics.every(
        (diagnostic) =>
            diagnostic.severity == DiagnosticSeverity.warning &&
            diagnostic.stage == DiagnosticStage.validate &&
            !diagnostic.blocksOperation,
      ),
      isTrue,
    );
    final unitSection = document.sections[3];
    expect(
      diagnostics[0].byteOffset,
      unitSection.sourceOffset + RawChkParser.headerLength + 4,
    );
    expect(
      diagnostics[1].byteOffset,
      unitSection.sourceOffset + RawChkParser.headerLength + 16,
    );
    expect(diagnostics[0].rawDetails, contains('maximumX=256'));
    expect(diagnostics[5].rawDetails, contains('stringId=99'));
    expect(diagnostics.last.sectionName, 'SPRP');
  });

  test('does not guess between duplicate string tables', () {
    final document = _documentFromSections([
      _section('SPRP', const [1, 0, 0, 0]),
      _section('STR ', _legacyStringTable(['Legacy'])),
      _section('STRx', _extendedStringTable(['Extended'])),
      _section(
        'MRGN',
        _locations(left: 0, top: 0, right: 32, bottom: 32, stringId: 1),
      ),
    ]);

    final diagnostics = validate(document);

    expect(diagnostics, hasLength(2));
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      everyElement(ChkObjectReferenceDiagnosticCodes.stringTableAmbiguous),
    );
    expect(diagnostics.first.rawDetails, contains('tableCount=2'));
    expect(diagnostics.first.rawDetails, contains('tableSectionIndexes=1,2'));
  });

  test('reports nonzero string references when no table is readable', () {
    final document = _documentFromSections([
      _section('SPRP', const [2, 0, 0, 0]),
      _section(
        'MRGN',
        _locations(left: 0, top: 0, right: 32, bottom: 32, stringId: 1),
      ),
    ]);

    final diagnostics = validate(document);

    expect(diagnostics, hasLength(2));
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      everyElement(ChkObjectReferenceDiagnosticCodes.stringReferenceUnresolved),
    );
  });
}

Uint8List _unitRecord({required int x, required int y, required int owner}) {
  final payload = Uint8List(ChkUnitPlacement.recordLength);
  ByteData.sublistView(payload)
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little)
    ..setUint8(16, owner);
  return payload;
}

Uint8List _doodadRecord({required int x, required int y, required int owner}) {
  final payload = Uint8List(ChkDoodadPlacement.recordLength);
  ByteData.sublistView(payload)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little)
    ..setUint8(6, owner);
  return payload;
}

Uint8List _spriteRecord({required int x, required int y, required int owner}) {
  final payload = Uint8List(ChkSpritePlacement.recordLength);
  ByteData.sublistView(payload)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little)
    ..setUint8(6, owner);
  return payload;
}

Uint8List _locations({
  required int left,
  required int top,
  required int right,
  required int bottom,
  required int stringId,
}) {
  final payload = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  ByteData.sublistView(payload)
    ..setUint32(0, left, Endian.little)
    ..setUint32(4, top, Endian.little)
    ..setUint32(8, right, Endian.little)
    ..setUint32(12, bottom, Endian.little)
    ..setUint16(16, stringId, Endian.little)
    ..setUint16(18, ChkLocation.allElevations, Endian.little);
  return payload;
}

Uint8List _legacyStringTable(List<String> strings) =>
    _stringTable(strings, countWidth: 2, offsetWidth: 2);

Uint8List _extendedStringTable(List<String> strings) =>
    _stringTable(strings, countWidth: 4, offsetWidth: 4);

Uint8List _stringTable(
  List<String> strings, {
  required int countWidth,
  required int offsetWidth,
}) {
  final encoded = strings.map(utf8.encode).toList(growable: false);
  final headerLength = countWidth + strings.length * offsetWidth;
  final payload = Uint8List(
    headerLength +
        encoded.fold<int>(0, (total, bytes) => total + bytes.length + 1),
  );
  final data = ByteData.sublistView(payload);
  if (countWidth == 2) {
    data.setUint16(0, strings.length, Endian.little);
  } else {
    data.setUint32(0, strings.length, Endian.little);
  }
  var offset = headerLength;
  for (var index = 0; index < encoded.length; index++) {
    final fieldOffset = countWidth + index * offsetWidth;
    if (offsetWidth == 2) {
      data.setUint16(fieldOffset, offset, Endian.little);
    } else {
      data.setUint32(fieldOffset, offset, Endian.little);
    }
    payload.setAll(offset, encoded[index]);
    offset += encoded[index].length + 1;
  }
  return payload;
}

RawChkDocument _documentFromSections(List<RawChkSection> sections) {
  var sourceOffset = 0;
  final positioned = <RawChkSection>[];
  for (final section in sections) {
    positioned.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: sourceOffset,
      ),
    );
    sourceOffset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(sections: positioned, sourceLength: sourceOffset);
}

RawChkSection _section(String name, List<int> payload) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: payload.length,
  payload: payload,
  sourceOffset: 0,
);
