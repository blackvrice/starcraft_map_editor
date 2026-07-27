import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const parser = RawChkParser();
  const encoder = RawChkEncoder();
  const decoder = ChkTerrainViewDecoder();

  test('decodes an MTXM grid as little-endian raw tile values', () {
    final document = parser.parse(_loadFixture('terrain.chk.hex')).document!;

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.hasBlockingDiagnostics, isFalse);
    expect(views.tileMaps, hasLength(1));

    final terrain = views.tileMaps.single;
    expect(terrain.sectionIndex, 2);
    expect(terrain.width, 3);
    expect(terrain.height, 2);
    expect(terrain.hasGridDimensions, isTrue);
    expect(terrain.tileCount, 6);
    expect(terrain.rawTileValues, [1, 0x10, 0x1234, 0xffff, 0, 0xab]);
    expect(terrain.rawTileValueAt(x: 2, y: 0), 0x1234);
    expect(terrain.rawTileValueAt(x: 1, y: 1), 0);
    expect(terrain.rawTileValueAtIndex(5), 0xab);
  });

  test('updates one exact tile while preserving every unrelated byte', () {
    final source = _loadFixture('terrain.chk.hex');
    final original = parser.parse(source).document!;
    final terrain = decoder.decode(original).tileMaps.single;

    final updated = original.replaceSection(
      terrain.sectionIndex,
      terrain.withRawTileValueAt(x: 1, y: 1, rawValue: 0xbeef),
    );
    final encoded = encoder.encode(updated);
    final reparsed = parser.parse(encoded).document!;
    final updatedTerrain = decoder.decode(reparsed).tileMaps.single;

    expect(updated.isDirty, isTrue);
    expect(updatedTerrain.rawTileValues, [
      1,
      0x10,
      0x1234,
      0xffff,
      0xbeef,
      0xab,
    ]);
    expect(
      encoded.sublist(0, terrain.rawSection.sourceOffset + 8),
      source.sublist(0, terrain.rawSection.sourceOffset + 8),
    );
    expect(
      encoded.sublist(terrain.rawSection.sourceOffset + 8, encoded.length),
      isNot(source.sublist(terrain.rawSection.sourceOffset + 8, source.length)),
    );
    expect(reparsed.sections[0].payload, original.sections[0].payload);
    expect(reparsed.sections[1].payload, original.sections[1].payload);

    final originalPayload = original.sections[2].payload;
    final updatedPayload = reparsed.sections[2].payload;
    expect(updatedPayload.sublist(0, 8), originalPayload.sublist(0, 8));
    expect(updatedPayload.sublist(10), originalPayload.sublist(10));
    expect(updatedPayload.sublist(8, 10), [0xef, 0xbe]);
  });

  test('replaces the complete tile list without changing its length', () {
    final document = parser.parse(_loadFixture('terrain.chk.hex')).document!;
    final terrain = decoder.decode(document).tileMaps.single;

    final replacement = terrain.withRawTileValues([6, 5, 4, 3, 2, 1]);
    final updated = decoder
        .decode(document.replaceSection(terrain.sectionIndex, replacement))
        .tileMaps
        .single;

    expect(updated.rawTileValues, [6, 5, 4, 3, 2, 1]);
    expect(replacement.declaredLength, terrain.rawSection.declaredLength);
  });

  test('keeps duplicate MTXM sections as separate ordered views', () {
    final document = _documentFromSections([
      _section('DIM ', [1, 0, 1, 0]),
      _section('MTXM', [1, 0]),
      _section('TEST', [0xaa]),
      _section('MTXM', [2, 0]),
    ]);

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.tileMaps.map((view) => view.sectionIndex), [1, 3]);
    expect(views.tileMaps.map((view) => view.rawTileValues.single), [1, 2]);
  });

  test('reports malformed MTXM sections and continues decoding', () {
    final document = _documentFromSections([
      _section('DIM ', [2, 0, 2, 0]),
      _section('MTXM', [1, 0, 2]),
      _section('MTXM', [1, 0, 2, 0, 3, 0]),
      _section('MTXM', [1, 0, 2, 0, 3, 0, 4, 0]),
    ]);

    final views = decoder.decode(document);

    expect(views.hasBlockingDiagnostics, isTrue);
    expect(views.tileMaps, hasLength(1));
    expect(views.tileMaps.single.sectionIndex, 3);
    expect(views.diagnostics, hasLength(2));

    final truncated = views.diagnostics[0];
    expect(truncated.code, ChkTypedDiagnosticCodes.terrainTileRecordTruncated);
    expect(truncated.severity, DiagnosticSeverity.error);
    expect(truncated.stage, DiagnosticStage.validate);
    expect(truncated.sectionName, 'MTXM');
    expect(truncated.byteOffset, 22);
    expect(truncated.rawDetails, contains('sectionIndex=1'));

    final mismatched = views.diagnostics[1];
    expect(mismatched.code, ChkTypedDiagnosticCodes.terrainTileCountMismatch);
    expect(mismatched.sectionName, 'MTXM');
    expect(mismatched.rawDetails, contains('mapWidth=2'));
    expect(mismatched.rawDetails, contains('mapHeight=2'));
    expect(mismatched.rawDetails, contains('expectedTileCount=4'));
    expect(mismatched.rawDetails, contains('actualTileCount=3'));
  });

  test('decodes linear tiles when dimensions are absent or ambiguous', () {
    final withoutDimensions = decoder.decode(
      _documentFromSections([
        _section('MTXM', [1, 0, 2, 0]),
      ]),
    );
    final duplicateDimensions = decoder.decode(
      _documentFromSections([
        _section('DIM ', [1, 0, 2, 0]),
        _section('DIM ', [2, 0, 1, 0]),
        _section('MTXM', [1, 0, 2, 0]),
      ]),
    );
    final zeroDimensions = decoder.decode(
      _documentFromSections([
        _section('DIM ', [0, 0, 2, 0]),
        _section('MTXM', [1, 0, 2, 0]),
      ]),
    );

    for (final views in [
      withoutDimensions,
      duplicateDimensions,
      zeroDimensions,
    ]) {
      expect(views.diagnostics, isEmpty);
      expect(views.tileMaps.single.hasGridDimensions, isFalse);
      expect(views.tileMaps.single.rawTileValues, [1, 2]);
      expect(
        () => views.tileMaps.single.rawTileValueAt(x: 0, y: 0),
        throwsStateError,
      );
    }
  });

  test('rejects invalid indices, coordinates, values, and list sizes', () {
    final terrain = decoder
        .decode(parser.parse(_loadFixture('terrain.chk.hex')).document!)
        .tileMaps
        .single;

    expect(() => terrain.rawTileValueAtIndex(-1), throwsRangeError);
    expect(() => terrain.rawTileValueAtIndex(6), throwsRangeError);
    expect(() => terrain.rawTileValueAt(x: 3, y: 0), throwsRangeError);
    expect(() => terrain.rawTileValueAt(x: 0, y: 2), throwsRangeError);
    expect(
      () => terrain.withRawTileValueAtIndex(index: 0, rawValue: -1),
      throwsRangeError,
    );
    expect(
      () => terrain.withRawTileValueAt(x: 0, y: 0, rawValue: 0x10000),
      throwsRangeError,
    );
    expect(() => terrain.withRawTileValues([1, 2]), throwsArgumentError);
    expect(
      () => terrain.withRawTileValues([1, 2, 3, 4, 5, 0x10000]),
      throwsRangeError,
    );
    expect(() => terrain.rawTileValues.add(7), throwsUnsupportedError);
  });

  test('ignores non-MTXM and euddraft protection sections', () {
    final document = RawChkDocument(
      sections: [
        _section('TILE', [1, 0]),
        RawChkSection.euddraftProtectionMarker(
          declaredLength: 0x80000001,
          sourceOffset: 10,
        ),
      ],
      sourceLength: 18,
    );

    final views = decoder.decode(document);

    expect(views.tileMaps, isEmpty);
    expect(views.diagnostics, isEmpty);
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
