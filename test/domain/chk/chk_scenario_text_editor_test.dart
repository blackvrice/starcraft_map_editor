import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_scenario_text_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);

RawChkDocument fixture({bool extended = false, List<int>? text}) {
  final raw = text ?? utf8.encode('Shared');
  final width = extended ? 4 : 2;
  final bytes = Uint8List(width * 2 + raw.length + 3);
  final data = ByteData.sublistView(bytes);
  if (extended) {
    data
      ..setUint32(0, 1, Endian.little)
      ..setUint32(4, 8, Endian.little);
  } else {
    data
      ..setUint16(0, 1, Endian.little)
      ..setUint16(2, 4, Endian.little);
  }
  bytes.setAll(width * 2, raw);
  bytes.setAll(bytes.length - 2, [0xde, 0xad]);
  return RawChkDocument(
    sourceLength: 0,
    sections: [
      section('SPRP', [1, 0, 1, 0]),
      section(extended ? 'STRx' : 'STR ', bytes),
      section('XTRA', [1, 0xff, 2]),
    ],
  );
}

void main() {
  const editor = ChkScenarioTextEditor();
  for (final extended in [false, true]) {
    test('preserves shared bytes and changes only references ($extended)', () {
      final original = fixture(extended: extended);
      final changes = editor.edit(
        original,
        title: '새 제목',
        description: 'New description',
      );
      var edited = original;
      for (final entry in changes.entries) {
        edited = edited.replaceSection(entry.key, entry.value);
      }
      expect(editor.read(edited).title, '새 제목');
      expect(editor.read(edited).description, 'New description');
      expect(edited.sections[0].payload, [2, 0, 3, 0]);
      expect(identical(edited.sections.last, original.sections.last), isTrue);
      final views = const ChkStringViewDecoder().decode(edited);
      final table = [...views.legacyTables, ...views.extendedTables].single;
      expect(table.entries.first.rawBytes, utf8.encode('Shared'));
      expect(table.declaredStringCount, 3);
      final originalData = original.sections[1].payload.sublist(
        extended ? 8 : 4,
      );
      expect(
        table.rawSection.payload.sublist(
          table.stringDataOffset,
          table.stringDataOffset + originalData.length,
        ),
        originalData,
      );
      expect(original.isDirty, isFalse);
      expect(
        editor.edit(edited, title: '새 제목', description: 'New description'),
        isEmpty,
      );
    });
  }
  test('clears references without deleting shared strings', () {
    final original = fixture();
    final changes = editor.edit(original, title: '', description: 'Shared');
    expect(changes.keys, [0]);
    expect(changes[0]!.payload, [0, 0, 1, 0]);
  });
  test('SPRP refuses new IDs above u16 even with an extended table', () {
    const count = 65535;
    const header = 4 + count * 4;
    final bytes = Uint8List(header + 2);
    final data = ByteData.sublistView(bytes)
      ..setUint32(0, count, Endian.little);
    for (var i = 0; i < count; i++) {
      data.setUint32(4 + i * 4, header, Endian.little);
    }
    bytes[header] = 65;
    final document = RawChkDocument(
      sourceLength: 0,
      sections: [
        section('SPRP', [1, 0, 1, 0]),
        section('STRx', bytes),
      ],
    );
    expect(
      () => editor.edit(document, title: 'New', description: 'A'),
      throwsStateError,
    );
    expect(editor.edit(document, title: 'A', description: 'A'), isEmpty);
    expect(document.isDirty, isFalse);
  });
  test('rejects ambiguous, malformed, missing and undecodable inputs', () {
    final original = fixture();
    for (final sections in [
      [original.sections[1]],
      [...original.sections, original.sections[0]],
      [...original.sections, original.sections[1]],
      [
        section('SPRP', [1, 0]),
        original.sections[1],
      ],
      [
        section('SPRP', [2, 0, 1, 0]),
        original.sections[1],
      ],
    ]) {
      expect(
        () => editor.read(RawChkDocument(sections: sections, sourceLength: 0)),
        throwsStateError,
      );
    }
    expect(() => editor.read(fixture(text: [0xff])), throwsFormatException);
    expect(
      () => editor.edit(original, title: 'new', description: 'a\u0000b'),
      throwsArgumentError,
    );
    expect(original.isDirty, isFalse);
  });
}
