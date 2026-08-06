import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const decoder = ChkObjectViewDecoder();

  test('decodes UNIT, DD2, THG2, and original MRGN records', () {
    final locationPayload = Uint8List(
      ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
    );
    final locationData = ByteData.sublistView(locationPayload);
    locationData
      ..setUint32(0, 10, Endian.little)
      ..setUint32(4, 20, Endian.little)
      ..setUint32(8, 30, Endian.little)
      ..setUint32(12, 40, Endian.little)
      ..setUint16(16, 0x1234, Endian.little)
      ..setUint16(18, 0x003f, Endian.little);
    final document = _documentFromSections([
      _section('UNIT', _unitRecord()),
      _section('DD2 ', _doodadRecord()),
      _section('THG2', _spriteRecord()),
      _section('MRGN', locationPayload),
    ]);

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.hasBlockingDiagnostics, isFalse);

    final unit = views.unitSections.single.units.single;
    expect(unit.recordIndex, 0);
    expect(unit.classId, 0x04030201);
    expect(unit.x, 0x0605);
    expect(unit.y, 0x0807);
    expect(unit.unitType, 0x0a09);
    expect(unit.relationFlags, 0x0c0b);
    expect(unit.validStateFlags, 0x0e0d);
    expect(unit.validFieldFlags, 0x100f);
    expect(unit.owner, 0x11);
    expect(unit.hitpointPercent, 0x12);
    expect(unit.shieldPercent, 0x13);
    expect(unit.energyPercent, 0x14);
    expect(unit.resourceAmount, 0x18171615);
    expect(unit.hangarAmount, 0x1a19);
    expect(unit.stateFlags, 0x1c1b);
    expect(unit.unused, 0x201f1e1d);
    expect(unit.relationClassId, 0x24232221);

    final doodad = views.doodadSections.single.doodads.single;
    expect(doodad.recordIndex, 0);
    expect(doodad.doodadType, 0x0201);
    expect(doodad.x, 0x0403);
    expect(doodad.y, 0x0605);
    expect(doodad.owner, 7);
    expect(doodad.enabledValue, 1);
    expect(doodad.isEnabled, isFalse);
    expect(doodad.hasKnownEnabledValue, isTrue);

    final sprite = views.spriteSections.single.sprites.single;
    expect(sprite.recordIndex, 0);
    expect(sprite.spriteType, 0x0201);
    expect(sprite.x, 0x0403);
    expect(sprite.y, 0x0605);
    expect(sprite.owner, 7);
    expect(sprite.unused, 0xa5);
    expect(sprite.flags, 0xb000);
    expect(sprite.drawsAsSprite, isTrue);
    expect(sprite.hasUnitFlag, isTrue);
    expect(sprite.isSpriteUnitDisabled, isTrue);

    final locationSection = views.locationSections.single;
    expect(locationSection.locations, hasLength(64));
    expect(locationSection.usesExtendedLocationTable, isFalse);
    final location = locationSection.locations.first;
    expect(location.recordIndex, 0);
    expect(location.locationId, 1);
    expect(location.left, 10);
    expect(location.top, 20);
    expect(location.right, 30);
    expect(location.bottom, 40);
    expect(location.stringId, 0x1234);
    expect(location.elevationFlags, 0x003f);
    expect(location.isBlank, isFalse);
    expect(locationSection.locations[1].isBlank, isTrue);
  });

  test('accepts the 255-record extended location table', () {
    final views = decoder.decode(
      _documentFromSections([
        _section(
          'MRGN',
          Uint8List(
            ChkLocationSectionView.extendedLocationCount *
                ChkLocation.recordLength,
          ),
        ),
      ]),
    );

    expect(views.diagnostics, isEmpty);
    expect(views.locationSections.single.locations, hasLength(255));
    expect(views.locationSections.single.usesExtendedLocationTable, isTrue);
    expect(views.locationSections.single.locations.last.locationId, 255);
  });

  test('keeps duplicate sections separate and in source order', () {
    final document = _documentFromSections([
      _section('UNIT', const []),
      _section('TEST', const [0xaa]),
      _section('UNIT', _unitRecord()),
      _section('DD2 ', const []),
      _section('THG2', const []),
      _section('THG2', _spriteRecord()),
    ]);

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.unitSections.map((view) => view.sectionIndex), [0, 2]);
    expect(views.unitSections.map((view) => view.units.length), [0, 1]);
    expect(views.doodadSections.single.sectionIndex, 3);
    expect(views.spriteSections.map((view) => view.sectionIndex), [4, 5]);
    expect(views.spriteSections.map((view) => view.sprites.length), [0, 1]);
    expect(
      identical(views.unitSections[1].rawSection, document.sections[2]),
      isTrue,
    );
  });

  test('reports malformed records and continues decoding later sections', () {
    final document = _documentFromSections([
      _section('UNIT', Uint8List(35)),
      _section('DD2 ', Uint8List(7)),
      _section('THG2', Uint8List(9)),
      _section('MRGN', Uint8List(40)),
      _section('UNIT', _unitRecord()),
      _section('DD2 ', _doodadRecord()),
      _section('THG2', _spriteRecord()),
    ]);

    final views = decoder.decode(document);

    expect(views.hasBlockingDiagnostics, isTrue);
    expect(views.unitSections.single.sectionIndex, 4);
    expect(views.doodadSections.single.sectionIndex, 5);
    expect(views.spriteSections.single.sectionIndex, 6);
    expect(views.locationSections, isEmpty);
    expect(views.diagnostics.map((diagnostic) => diagnostic.code), [
      ChkTypedDiagnosticCodes.unitRecordTruncated,
      ChkTypedDiagnosticCodes.doodadRecordTruncated,
      ChkTypedDiagnosticCodes.spriteRecordTruncated,
      ChkTypedDiagnosticCodes.locationSectionSizeMismatch,
    ]);
    for (final diagnostic in views.diagnostics) {
      expect(diagnostic.severity, DiagnosticSeverity.error);
      expect(diagnostic.stage, DiagnosticStage.validate);
      expect(diagnostic.remediation, contains('read-only'));
    }
    expect(views.diagnostics[0].sectionName, 'UNIT');
    expect(views.diagnostics[0].byteOffset, 8);
    expect(views.diagnostics[0].rawDetails, contains('trailingBytes=35'));
    expect(views.diagnostics[3].rawDetails, contains('1280 or 5100'));
  });

  test('typed views are immutable and decoding preserves raw bytes', () {
    const parser = RawChkParser();
    const encoder = RawChkEncoder();
    final source = encoder.encode(
      _documentFromSections([
        _section('UNIT', _unitRecord()),
        _section('DD2 ', _doodadRecord()),
        _section('THG2', _spriteRecord()),
        _section(
          'MRGN',
          Uint8List(
            ChkLocationSectionView.originalLocationCount *
                ChkLocation.recordLength,
          ),
        ),
      ]),
    );
    final document = parser.parse(source).document!;
    final views = decoder.decode(document);

    expect(
      () => views.unitSections.add(views.unitSections.single),
      throwsUnsupportedError,
    );
    expect(
      () => views.unitSections.single.units.add(
        views.unitSections.single.units.single,
      ),
      throwsUnsupportedError,
    );
    expect(() => views.diagnostics.add(_diagnostic()), throwsUnsupportedError);
    expect(encoder.encode(document), source);
  });
}

Uint8List _unitRecord() => Uint8List.fromList(
  List<int>.generate(ChkUnitPlacement.recordLength, (index) => index + 1),
);

Uint8List _doodadRecord() => Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 1]);

Uint8List _spriteRecord() =>
    Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 0xa5, 0, 0xb0]);

RawChkDocument _documentFromSections(List<RawChkSection> sections) {
  var sourceOffset = 0;
  final positionedSections = <RawChkSection>[];
  for (final section in sections) {
    positionedSections.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: sourceOffset,
      ),
    );
    sourceOffset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(
    sections: positionedSections,
    sourceLength: sourceOffset,
  );
}

RawChkSection _section(String name, List<int> payload) {
  return RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: payload.length,
    payload: payload,
    sourceOffset: 0,
  );
}

EditorDiagnostic _diagnostic() => const EditorDiagnostic(
  code: 'TEST',
  message: 'test',
  severity: DiagnosticSeverity.info,
  stage: DiagnosticStage.validate,
);
