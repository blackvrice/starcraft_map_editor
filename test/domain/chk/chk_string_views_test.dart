import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const parser = RawChkParser();
  const encoder = RawChkEncoder();
  const decoder = ChkStringViewDecoder();

  test('decodes SPRP references and a legacy raw string table', () {
    final document = parser.parse(_loadFixture('strings.chk.hex')).document!;

    final views = decoder.decode(document);

    expect(views.hasBlockingDiagnostics, isFalse);
    expect(views.diagnostics, isEmpty);
    expect(views.scenarioProperties, hasLength(1));
    expect(views.legacyTables, hasLength(1));
    expect(views.extendedTables, isEmpty);

    final properties = views.scenarioProperties.single;
    final table = views.legacyTables.single;
    expect(properties.sectionIndex, 0);
    expect(properties.scenarioName.stringId, 1);
    expect(properties.scenarioDescription.stringId, 2);
    expect(table.sectionIndex, 1);
    expect(table.kind, ChkStringTableKind.legacy);
    expect(table.declaredStringCount, 3);
    expect(table.stringDataOffset, 8);
    expect(table.canAppendSafely, isTrue);

    expect(table.entries.map((entry) => entry.rawOffset), [8, 12, 8]);
    expect(table.entries[0].rawBytes, utf8.encode('Map'));
    expect(table.entries[1].rawBytes, utf8.encode('Line'));
    expect(table.entries[2].rawBytes, utf8.encode('Map'));
    expect(table.entries.every((entry) => entry.isStructurallyValid), isTrue);
    expect(
      properties.scenarioName
          .resolve(table)!
          .decodeForDisplay((bytes) => utf8.decode(bytes)),
      'Map',
    );
    expect(
      properties.scenarioDescription
          .resolve(table)!
          .decodeForDisplay((bytes) => utf8.decode(bytes)),
      'Line',
    );
  });

  test('decodes STRx offsets and preserves UTF-8 and control bytes', () {
    final document = parser
        .parse(_loadFixture('strings_extended.chk.hex'))
        .document!;

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.legacyTables, isEmpty);
    expect(views.extendedTables, hasLength(1));

    final table = views.extendedTables.single;
    expect(table.kind, ChkStringTableKind.extended);
    expect(table.declaredStringCount, 2);
    expect(table.stringDataOffset, 12);
    expect(table.entries[0].rawOffset, 12);
    expect(table.entries[0].rawBytes, utf8.encode('EUD'));
    expect(table.entries[1].rawOffset, 16);
    expect(table.entries[1].rawBytes, [0xc3, 0xa9, 0x01]);
    expect(
      table.entries[1].decodeForDisplay((bytes) => utf8.decode(bytes)),
      'é\u0001',
    );

    final exposedBytes = table.entries[1].rawBytes!;
    exposedBytes.fillRange(0, exposedBytes.length, 0xff);
    expect(table.entries[1].rawBytes, [0xc3, 0xa9, 0x01]);
  });

  test('updates SPRP references without touching the string table', () {
    final source = _loadFixture('strings.chk.hex');
    var document = parser.parse(source).document!;
    final views = decoder.decode(document);

    document = document.replaceSection(
      views.scenarioProperties.single.sectionIndex,
      views.scenarioProperties.single.withReferences(
        scenarioNameStringId: 3,
        scenarioDescriptionStringId: 0,
      ),
    );
    final reparsed = parser.parse(encoder.encode(document)).document!;
    final updatedViews = decoder.decode(reparsed);

    expect(updatedViews.scenarioProperties.single.scenarioName.stringId, 3);
    expect(
      updatedViews.scenarioProperties.single.scenarioDescription.isNone,
      isTrue,
    );
    expect(
      reparsed.sections[1].payload,
      parser.parse(source).document!.sections[1].payload,
    );
    expect(
      updatedViews.scenarioProperties.single.scenarioName
          .resolve(updatedViews.legacyTables.single)!
          .rawBytes,
      utf8.encode('Map'),
    );
  });

  test('appends legacy raw bytes and repoints only the requested offset', () {
    final source = _loadFixture('strings.chk.hex');
    var document = parser.parse(source).document!;
    final originalTable = decoder.decode(document).legacyTables.single;
    final originalPayload = originalTable.rawSection.payload;
    final replacement = utf8.encode('새 맵');

    final updatedSection = originalTable.withAppendedRawString(
      stringId: 2,
      rawBytes: replacement,
    );
    document = document.replaceSection(
      originalTable.sectionIndex,
      updatedSection,
    );
    final reparsed = parser.parse(encoder.encode(document)).document!;
    final updatedTable = decoder.decode(reparsed).legacyTables.single;
    final updatedPayload = updatedTable.rawSection.payload;

    expect(updatedSection.isDirty, isTrue);
    expect(updatedTable.entries[0].rawBytes, utf8.encode('Map'));
    expect(updatedTable.entries[1].rawOffset, originalPayload.length);
    expect(updatedTable.entries[1].rawBytes, replacement);
    expect(updatedTable.entries[2].rawOffset, 8);
    expect(updatedTable.entries[2].rawBytes, utf8.encode('Map'));
    expect(updatedPayload.sublist(17, 19), [0xde, 0xad]);
    expect(
      updatedPayload.sublist(
        originalPayload.length,
        originalPayload.length + replacement.length,
      ),
      replacement,
    );
    expect(updatedPayload.last, 0);

    for (var index = 0; index < originalPayload.length; index++) {
      if (index == 4 || index == 5) {
        continue;
      }
      expect(
        updatedPayload[index],
        originalPayload[index],
        reason: 'legacy payload index $index',
      );
    }
  });

  test('appends extended raw bytes with a 32-bit offset', () {
    final document = parser
        .parse(_loadFixture('strings_extended.chk.hex'))
        .document!;
    final table = decoder.decode(document).extendedTables.single;
    final originalPayload = table.rawSection.payload;

    final updatedSection = table.withAppendedRawString(
      stringId: 2,
      rawBytes: const [0x01, 0x02, 0x03],
    );
    final updatedDocument = document.replaceSection(
      table.sectionIndex,
      updatedSection,
    );
    final updatedTable = decoder
        .decode(parser.parse(encoder.encode(updatedDocument)).document!)
        .extendedTables
        .single;

    expect(updatedTable.entries[1].rawOffset, originalPayload.length);
    expect(updatedTable.entries[1].rawBytes, [0x01, 0x02, 0x03]);

    final updatedPayload = updatedSection.payload;
    for (var index = 0; index < originalPayload.length; index++) {
      if (index >= 8 && index < 12) {
        continue;
      }
      expect(
        updatedPayload[index],
        originalPayload[index],
        reason: 'extended payload index $index',
      );
    }
  });

  test(
    'reports truncated and unsafe string structures with exact locations',
    () {
      final document = parser
          .parse(_loadFixture('invalid_strings.chk.hex'))
          .document!;

      final views = decoder.decode(document);

      expect(views.hasBlockingDiagnostics, isTrue);
      expect(views.extendedTables, isEmpty);
      expect(views.legacyTables, hasLength(1));
      expect(views.legacyTables.single.canAppendSafely, isFalse);
      expect(views.diagnostics.map((diagnostic) => diagnostic.code), [
        ChkTypedDiagnosticCodes.stringTableHeaderTruncated,
        ChkTypedDiagnosticCodes.stringTableOffsetsTruncated,
        ChkTypedDiagnosticCodes.stringUnterminated,
        ChkTypedDiagnosticCodes.stringOffsetIntoHeader,
        ChkTypedDiagnosticCodes.stringOffsetOutOfBounds,
      ]);

      final headerDiagnostic = views.diagnostics[0];
      expect(headerDiagnostic.severity, DiagnosticSeverity.error);
      expect(headerDiagnostic.stage, DiagnosticStage.validate);
      expect(headerDiagnostic.sectionName, 'STR ');
      expect(headerDiagnostic.byteOffset, 8);
      expect(headerDiagnostic.rawDetails, contains('sectionIndex=0'));

      final table = views.legacyTables.single;
      expect(table.sectionIndex, 2);
      expect(table.entries[0].offsetInBounds, isTrue);
      expect(table.entries[0].isNullTerminated, isFalse);
      expect(table.entries[0].rawBytes, [0x4f, 0x4b]);
      expect(table.entries[1].pointsIntoHeader, isTrue);
      expect(table.entries[2].offsetInBounds, isFalse);
      expect(table.entries[2].rawBytes, isNull);
      expect(
        () => table.withAppendedRawString(stringId: 1, rawBytes: const [0x41]),
        throwsStateError,
      );
    },
  );

  test('reports an invalid SPRP fixed size and continues with other views', () {
    final document = _documentFromSections([
      _section('SPRP', [0x01, 0x00]),
      _section('STR ', [0x00, 0x00]),
    ]);

    final views = decoder.decode(document);

    expect(views.scenarioProperties, isEmpty);
    expect(views.legacyTables, hasLength(1));
    expect(views.diagnostics, hasLength(1));
    expect(
      views.diagnostics.single.code,
      ChkTypedDiagnosticCodes.sectionSizeMismatch,
    );
    expect(views.diagnostics.single.sectionName, 'SPRP');
    expect(views.diagnostics.single.byteOffset, 8);
  });

  test('keeps duplicate legacy and extended tables as ordered views', () {
    final document = _documentFromSections([
      _section('STR ', [0x00, 0x00]),
      _section('STRx', [0x00, 0x00, 0x00, 0x00]),
      _section('STR ', [0x00, 0x00]),
      _section('STRx', [0x00, 0x00, 0x00, 0x00]),
    ]);

    final views = decoder.decode(document);

    expect(views.diagnostics, isEmpty);
    expect(views.legacyTables.map((table) => table.sectionIndex), [0, 2]);
    expect(views.extendedTables.map((table) => table.sectionIndex), [1, 3]);
  });

  test('rejects ambiguous or out-of-range raw string updates', () {
    final table = decoder
        .decode(parser.parse(_loadFixture('strings.chk.hex')).document!)
        .legacyTables
        .single;

    expect(
      () => table.withAppendedRawString(stringId: 0, rawBytes: const [0x41]),
      throwsRangeError,
    );
    expect(
      () => table.withAppendedRawString(stringId: 4, rawBytes: const [0x41]),
      throwsRangeError,
    );
    expect(
      () => table.withAppendedRawString(
        stringId: 1,
        rawBytes: const [0x41, 0x00, 0x42],
      ),
      throwsArgumentError,
    );
    expect(
      () => table.withAppendedRawString(stringId: 1, rawBytes: const [0x100]),
      throwsRangeError,
    );
  });

  test('blocks a legacy append when its new offset exceeds uint16', () {
    final payload = Uint8List(0x10000);
    final data = ByteData.sublistView(payload)
      ..setUint16(0, 1, Endian.little)
      ..setUint16(2, 4, Endian.little);
    final document = _documentFromSections([
      _section('STR ', data.buffer.asUint8List()),
    ]);
    final table = decoder.decode(document).legacyTables.single;

    expect(table.canAppendSafely, isTrue);
    expect(
      () => table.withAppendedRawString(stringId: 1, rawBytes: const [0x41]),
      throwsRangeError,
    );
  });

  test('validates SPRP reference updates as uint16 values', () {
    final properties = decoder
        .decode(parser.parse(_loadFixture('strings.chk.hex')).document!)
        .scenarioProperties
        .single;

    expect(
      () => properties.withReferences(scenarioNameStringId: -1),
      throwsRangeError,
    );
    expect(
      () => properties.withReferences(scenarioDescriptionStringId: 0x10000),
      throwsRangeError,
    );
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
