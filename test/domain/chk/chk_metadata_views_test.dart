import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const parser = RawChkParser();
  const encoder = RawChkEncoder();
  const decoder = ChkMetadataViewDecoder();

  test('decodes the five metadata section types as little-endian values', () {
    final source = _loadFixture('metadata.chk.hex');
    final document = parser.parse(source).document!;

    final views = decoder.decode(document);

    expect(views.hasBlockingDiagnostics, isFalse);
    expect(views.diagnostics, isEmpty);

    expect(views.types, hasLength(1));
    expect(views.types.single.sectionIndex, 0);
    expect(views.types.single.rawValue, 0x42574152);
    expect(views.types.single.fourCharacterCode, 'RAWB');
    expect(views.types.single.knownType, ChkScenarioType.broodWar);

    expect(views.versions, hasLength(1));
    expect(views.versions.single.sectionIndex, 1);
    expect(views.versions.single.rawValue, 205);
    expect(views.versions.single.knownVersion, ChkMapVersion.broodWar);

    expect(views.internalVersions, hasLength(1));
    expect(views.internalVersions.single.sectionIndex, 2);
    expect(views.internalVersions.single.rawValue, 10);
    expect(
      views.internalVersions.single.knownVersion,
      ChkInternalVersion.current,
    );

    expect(views.tilesets, hasLength(1));
    expect(views.tilesets.single.sectionIndex, 3);
    expect(views.tilesets.single.rawValue, 4);
    expect(views.tilesets.single.knownTileset, ChkTileset.jungle);

    expect(views.dimensions, hasLength(1));
    expect(views.dimensions.single.sectionIndex, 4);
    expect(views.dimensions.single.width, 128);
    expect(views.dimensions.single.height, 64);
  });

  test('updates exact raw sections while retaining all unrelated bytes', () {
    final source = _loadFixture('metadata.chk.hex');
    var document = parser.parse(source).document!;
    var views = decoder.decode(document);

    document = document.replaceSection(
      views.types.single.sectionIndex,
      views.types.single.withRawValue(ChkScenarioType.starCraftHybrid.rawValue),
    );
    document = document.replaceSection(
      views.versions.single.sectionIndex,
      views.versions.single.withRawValue(ChkMapVersion.remastered.rawValue),
    );
    document = document.replaceSection(
      views.internalVersions.single.sectionIndex,
      views.internalVersions.single.withRawValue(
        ChkInternalVersion.beta.rawValue,
      ),
    );
    document = document.replaceSection(
      views.tilesets.single.sectionIndex,
      views.tilesets.single.withRawValue(ChkTileset.twilight.rawValue),
    );
    document = document.replaceSection(
      views.dimensions.single.sectionIndex,
      views.dimensions.single.withDimensions(width: 256, height: 192),
    );

    final encoded = encoder.encode(document);
    views = decoder.decode(parser.parse(encoded).document!);

    expect(document.isDirty, isTrue);
    expect(views.types.single.knownType, ChkScenarioType.starCraftHybrid);
    expect(views.types.single.fourCharacterCode, 'RAWS');
    expect(views.versions.single.knownVersion, ChkMapVersion.remastered);
    expect(views.internalVersions.single.knownVersion, ChkInternalVersion.beta);
    expect(views.tilesets.single.knownTileset, ChkTileset.twilight);
    expect(views.dimensions.single.width, 256);
    expect(views.dimensions.single.height, 192);

    _expectOnlyPayloadsChanged(
      original: parser.parse(source).document!,
      updated: parser.parse(encoded).document!,
    );
  });

  test('preserves unknown scalar values without producing diagnostics', () {
    final document = _documentFromSections([
      _section('TYPE', [0x5a, 0x5a, 0x5a, 0x5a]),
      _section('VER ', [0xe7, 0x03]),
      _section('IVER', [0x63, 0x00]),
      _section('ERA ', [0x34, 0x12]),
      _section('DIM ', [0x00, 0x00, 0xff, 0xff]),
    ]);

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.types.single.rawValue, 0x5a5a5a5a);
    expect(views.types.single.fourCharacterCode, 'ZZZZ');
    expect(views.types.single.knownType, isNull);
    expect(views.versions.single.rawValue, 999);
    expect(views.versions.single.knownVersion, isNull);
    expect(views.internalVersions.single.rawValue, 99);
    expect(views.internalVersions.single.knownVersion, isNull);
    expect(views.tilesets.single.rawValue, 0x1234);
    expect(views.tilesets.single.knownTileset, isNull);
    expect(views.dimensions.single.width, 0);
    expect(views.dimensions.single.height, 0xffff);
  });

  test('keeps duplicate typed sections as separate ordered views', () {
    final document = _documentFromSections([
      _section('VER ', [0x3f, 0x00]),
      _section('TEST', [0xaa]),
      _section('VER ', [0xcd, 0x00]),
      _section('ERA ', [0x00, 0x00]),
      _section('ERA ', [0x07, 0x00]),
    ]);

    final views = decoder.decode(document);

    expect(views.versions.map((view) => view.sectionIndex), [0, 2]);
    expect(views.versions.map((view) => view.rawValue), [63, 205]);
    expect(views.tilesets.map((view) => view.sectionIndex), [3, 4]);
    expect(views.tilesets.map((view) => view.knownTileset), [
      ChkTileset.badlands,
      ChkTileset.twilight,
    ]);
  });

  test('reports each fixed-size mismatch and continues decoding', () {
    final document = parser
        .parse(_loadFixture('invalid_metadata_sizes.chk.hex'))
        .document!;

    final views = decoder.decode(document);

    expect(views.hasBlockingDiagnostics, isTrue);
    expect(views.versions, isEmpty);
    expect(views.dimensions, isEmpty);
    expect(views.tilesets.single.knownTileset, ChkTileset.jungle);
    expect(views.diagnostics, hasLength(2));

    final versionDiagnostic = views.diagnostics[0];
    expect(versionDiagnostic.code, ChkTypedDiagnosticCodes.sectionSizeMismatch);
    expect(versionDiagnostic.severity, DiagnosticSeverity.error);
    expect(versionDiagnostic.stage, DiagnosticStage.validate);
    expect(versionDiagnostic.sectionName, 'VER ');
    expect(versionDiagnostic.byteOffset, 8);
    expect(versionDiagnostic.rawDetails, contains('sectionIndex=0'));
    expect(versionDiagnostic.rawDetails, contains('expectedPayloadBytes=2'));
    expect(versionDiagnostic.rawDetails, contains('actualPayloadBytes=1'));

    final dimensionsDiagnostic = views.diagnostics[1];
    expect(dimensionsDiagnostic.sectionName, 'DIM ');
    expect(dimensionsDiagnostic.byteOffset, 27);
    expect(dimensionsDiagnostic.rawDetails, contains('sectionIndex=2'));
  });

  test('rejects updates outside each unsigned integer range', () {
    final views = decoder.decode(
      parser.parse(_loadFixture('metadata.chk.hex')).document!,
    );

    expect(() => views.types.single.withRawValue(-1), throwsRangeError);
    expect(
      () => views.types.single.withRawValue(0x100000000),
      throwsRangeError,
    );
    expect(() => views.versions.single.withRawValue(0x10000), throwsRangeError);
    expect(
      () => views.internalVersions.single.withRawValue(-1),
      throwsRangeError,
    );
    expect(() => views.tilesets.single.withRawValue(0x10000), throwsRangeError);
    expect(
      () => views.dimensions.single.withDimensions(width: -1, height: 64),
      throwsRangeError,
    );
    expect(
      () => views.dimensions.single.withDimensions(width: 64, height: 0x10000),
      throwsRangeError,
    );
  });

  test('ignores unsupported sections without changing their raw data', () {
    final document = _documentFromSections([
      _section('TEST', [0xde, 0xad, 0xbe, 0xef]),
    ]);

    final views = decoder.decode(document);

    expect(views.types, isEmpty);
    expect(views.versions, isEmpty);
    expect(views.internalVersions, isEmpty);
    expect(views.dimensions, isEmpty);
    expect(views.tilesets, isEmpty);
    expect(views.diagnostics, isEmpty);
    expect(encoder.encode(document), _encodeSections(document.sections));
  });

  test('matches section names by exact raw bytes', () {
    final section = _section('VER ', [0xcd, 0x00]);

    expect(section.hasNameBytes(ChkSectionNames.version), isTrue);
    expect(section.hasNameBytes(const [0x56, 0x45, 0x52]), isFalse);
    expect(section.hasNameBytes(ChkSectionNames.type), isFalse);
  });
}

Uint8List _loadFixture(String name) {
  final source = File('test/fixtures/chk/$name').readAsStringSync();
  final tokens = <String>[];

  for (final line in source.split(RegExp(r'\r?\n'))) {
    final content = line.split('#').first.trim();
    if (content.isNotEmpty) {
      tokens.addAll(content.split(RegExp(r'\s+')));
    }
  }

  return Uint8List.fromList(
    tokens.map((token) => int.parse(token, radix: 16)).toList(),
  );
}

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

Uint8List _encodeSections(List<RawChkSection> sections) {
  return const RawChkEncoder().encode(
    RawChkDocument(
      sections: sections,
      sourceLength: sections.fold(
        0,
        (length, section) =>
            length + RawChkParser.headerLength + section.declaredLength,
      ),
    ),
  );
}

void _expectOnlyPayloadsChanged({
  required RawChkDocument original,
  required RawChkDocument updated,
}) {
  expect(updated.sections, hasLength(original.sections.length));

  for (var index = 0; index < original.sections.length; index++) {
    final originalSection = original.sections[index];
    final updatedSection = updated.sections[index];

    expect(updatedSection.nameBytes, originalSection.nameBytes);
    expect(updatedSection.sourceOffset, originalSection.sourceOffset);
    expect(updatedSection.declaredLength, originalSection.declaredLength);
    expect(updatedSection.payload, isNot(originalSection.payload));
  }
}
