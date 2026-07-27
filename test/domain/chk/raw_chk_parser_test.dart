import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  const parser = RawChkParser();
  const encoder = RawChkEncoder();

  group('RawChkParser', () {
    test('parses section headers, payloads, and source offsets', () {
      final source = _loadFixture('minimal.chk.hex');

      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.diagnostics, isEmpty);

      final document = result.document!;
      expect(document.sourceLength, source.length);
      expect(document.isDirty, isFalse);
      expect(document.sections, hasLength(2));

      final version = document.sections[0];
      expect(version.name, 'VER ');
      expect(version.nameBytes, [0x56, 0x45, 0x52, 0x20]);
      expect(version.declaredLength, 2);
      expect(version.payload, [0xcd, 0x00]);
      expect(version.sourceOffset, 0);
      expect(version.isDirty, isFalse);

      final dimensions = document.sections[1];
      expect(dimensions.name, 'DIM ');
      expect(dimensions.declaredLength, 4);
      expect(dimensions.payload, [0x40, 0x00, 0x40, 0x00]);
      expect(dimensions.sourceOffset, 10);
    });

    test('preserves unknown sections, duplicates, and order', () {
      final source = _loadFixture('duplicate_unknown.chk.hex');

      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.document!.sections.map((section) => section.name), [
        'TEST',
        'UNKN',
        'TEST',
      ]);
      expect(result.document!.sections.map((section) => section.payload), [
        [0xaa],
        <int>[],
        [0xbb, 0xcc],
      ]);
      expect(result.document!.sections.map((section) => section.sourceOffset), [
        0,
        9,
        17,
      ]);
    });

    test('returns a positioned diagnostic for a truncated header', () {
      final result = parser.parse(_loadFixture('truncated_header.chk.hex'));

      expect(result.isSuccess, isFalse);
      expect(result.document, isNull);
      expect(result.diagnostics, hasLength(1));

      final diagnostic = result.diagnostics.single;
      expect(diagnostic.code, RawChkDiagnosticCodes.truncatedHeader);
      expect(diagnostic.severity, DiagnosticSeverity.fatal);
      expect(diagnostic.stage, DiagnosticStage.parse);
      expect(diagnostic.byteOffset, 0);
      expect(diagnostic.rawDetails, contains('sectionIndex=0'));
      expect(diagnostic.rawDetails, contains('availableHeaderBytes=6'));
    });

    test('handles every 1-to-7-byte truncated header without throwing', () {
      for (var length = 1; length < RawChkParser.headerLength; length++) {
        final result = parser.parse(Uint8List(length));

        expect(result.isSuccess, isFalse, reason: 'input length: $length');
        expect(
          result.diagnostics.single.code,
          RawChkDiagnosticCodes.truncatedHeader,
          reason: 'input length: $length',
        );
        expect(
          result.diagnostics.single.byteOffset,
          0,
          reason: 'input length: $length',
        );
      }
    });

    test('reports a length field whose payload exceeds the input boundary', () {
      final result = parser.parse(_loadFixture('out_of_bounds.chk.hex'));

      expect(result.isSuccess, isFalse);
      expect(result.document, isNull);

      final diagnostic = result.diagnostics.single;
      expect(diagnostic.code, RawChkDiagnosticCodes.sectionOutOfBounds);
      expect(diagnostic.sectionName, 'UNIT');
      expect(diagnostic.byteOffset, 4);
      expect(diagnostic.rawDetails, contains('sectionIndex=0'));
      expect(diagnostic.rawDetails, contains('declaredLength=5'));
      expect(diagnostic.rawDetails, contains('availablePayloadBytes=2'));
    });

    test('preserves euddraft ISOM protection markers between sections', () {
      final markerLength = ByteData(4)..setUint32(0, 0x87654321, Endian.little);
      final source = Uint8List.fromList([
        ..._encodeSection('VER ', [0xce, 0x00]),
        ...'ISOM'.codeUnits,
        ...markerLength.buffer.asUint8List(),
        ..._encodeSection('CRGB', List<int>.filled(20, 0)),
      ]);

      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.document!.sections.map((section) => section.name), [
        'VER ',
        'ISOM',
        'CRGB',
      ]);
      final marker = result.document!.sections[1];
      expect(marker.isEuddraftProtectionMarker, isTrue);
      expect(marker.declaredLength, 0x87654321);
      expect(marker.payload, isEmpty);
      expect(marker.sourceOffset, 10);
      expect(encoder.encode(result.document!), source);
    });

    test('does not accept a negative-length marker with another name', () {
      final markerLength = ByteData(4)..setUint32(0, 0x80000000, Endian.little);
      final source = Uint8List.fromList([
        ...'UNIT'.codeUnits,
        ...markerLength.buffer.asUint8List(),
      ]);

      final result = parser.parse(source);

      expect(result.isSuccess, isFalse);
      expect(
        result.diagnostics.single.code,
        RawChkDiagnosticCodes.sectionOutOfBounds,
      );
    });

    test('reports trailing bytes as a truncated next header', () {
      final completeSection = _encodeSection('TEST', [0xaa]);
      final source = Uint8List.fromList([...completeSection, 0xff]);

      final result = parser.parse(source);

      expect(result.isSuccess, isFalse);
      expect(result.document, isNull);
      expect(result.diagnostics.single.code, 'CHK_TRUNCATED_HEADER');
      expect(result.diagnostics.single.byteOffset, completeSection.length);
      expect(result.diagnostics.single.rawDetails, contains('sectionIndex=1'));
    });

    test('copies parsed bytes instead of retaining mutable input', () {
      final source = _loadFixture('minimal.chk.hex');
      final result = parser.parse(source);

      source.fillRange(0, source.length, 0xff);

      expect(result.document!.sections.first.name, 'VER ');
      expect(result.document!.sections.first.payload, [0xcd, 0x00]);
    });
  });

  group('RawChkEncoder', () {
    for (final fixtureName in [
      'minimal.chk.hex',
      'duplicate_unknown.chk.hex',
    ]) {
      test('round-trips $fixtureName byte-for-byte', () {
        final source = _loadFixture(fixtureName);
        final document = parser.parse(source).document!;

        expect(encoder.encode(document), source);
      });
    }

    test('round-trips an empty raw document', () {
      final source = Uint8List(0);
      final result = parser.parse(source);

      expect(result.isSuccess, isTrue);
      expect(result.document!.sections, isEmpty);
      expect(encoder.encode(result.document!), source);
    });

    test('encodes only the explicitly replaced section payload', () {
      final source = _loadFixture('minimal.chk.hex');
      final original = parser.parse(source).document!;
      final updatedSection = original.sections[1].withPayload([
        0x80,
        0x00,
        0x40,
        0x00,
      ]);
      final updated = original.replaceSection(1, updatedSection);

      final encoded = encoder.encode(updated);
      final reparsed = parser.parse(encoded).document!;

      expect(updated.isDirty, isTrue);
      expect(encoded.sublist(0, 10), source.sublist(0, 10));
      expect(reparsed.sections[1].payload, [0x80, 0x00, 0x40, 0x00]);
      expect(reparsed.sections[1].declaredLength, 4);
    });

    test('round-trips generated section lists deterministically', () {
      final random = Random(0x43484b);

      for (var caseIndex = 0; caseIndex < 200; caseIndex++) {
        final sections = <RawChkSection>[];
        var sourceOffset = 0;
        final sectionCount = random.nextInt(12);

        for (
          var sectionIndex = 0;
          sectionIndex < sectionCount;
          sectionIndex++
        ) {
          final nameBytes = List<int>.generate(4, (_) => random.nextInt(0x100));
          final payload = List<int>.generate(
            random.nextInt(65),
            (_) => random.nextInt(0x100),
          );
          sections.add(
            RawChkSection(
              nameBytes: nameBytes,
              declaredLength: payload.length,
              payload: payload,
              sourceOffset: sourceOffset,
            ),
          );
          sourceOffset += RawChkParser.headerLength + payload.length;
        }

        final generated = RawChkDocument(
          sections: sections,
          sourceLength: sourceOffset,
        );
        final bytes = encoder.encode(generated);
        final parsed = parser.parse(bytes);

        expect(parsed.isSuccess, isTrue, reason: 'case: $caseIndex');
        expect(
          encoder.encode(parsed.document!),
          bytes,
          reason: 'case: $caseIndex',
        );
        expect(
          parsed.document!.sections.map((section) => section.sourceOffset),
          sections.map((section) => section.sourceOffset),
          reason: 'case: $caseIndex',
        );
      }
    });
  });

  group('RawChkSection', () {
    test('requires an exact four-byte name', () {
      expect(
        () => RawChkSection(
          nameBytes: const [0x56, 0x45, 0x52],
          declaredLength: 0,
          payload: const [],
          sourceOffset: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects values outside the byte range', () {
      expect(
        () => RawChkSection(
          nameBytes: const [0x56, 0x45, 0x52, 0x20],
          declaredLength: 1,
          payload: const [0x100],
          sourceOffset: 0,
        ),
        throwsRangeError,
      );
    });

    test('renders non-printable name bytes without losing raw bytes', () {
      final section = RawChkSection(
        nameBytes: const [0x00, 0x41, 0x7f, 0xff],
        declaredLength: 0,
        payload: const [],
        sourceOffset: 0,
      );

      expect(section.name, r'\x00A\x7F\xFF');
      expect(section.nameBytes, [0x00, 0x41, 0x7f, 0xff]);
    });
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
    tokens.map((token) {
      if (!RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(token)) {
        throw FormatException('Invalid hex byte "$token" in fixture $name.');
      }
      return int.parse(token, radix: 16);
    }).toList(),
  );
}

Uint8List _encodeSection(String name, List<int> payload) {
  if (name.codeUnits.length != 4) {
    throw ArgumentError.value(name, 'name', 'A section name must be 4 bytes.');
  }

  final length = ByteData(4)..setUint32(0, payload.length, Endian.little);
  return Uint8List.fromList([
    ...name.codeUnits,
    ...length.buffer.asUint8List(),
    ...payload,
  ]);
}
