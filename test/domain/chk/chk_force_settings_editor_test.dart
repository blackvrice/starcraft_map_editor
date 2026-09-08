import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_force_settings_editor.dart';

RawChkSection section(String name, List<int> payload) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: payload.length,
  payload: payload,
  sourceOffset: 0,
);
RawChkDocument fixture({bool extended = false}) => RawChkDocument(
  sourceLength: 0,
  sections: [
    section('VER ', [205, 0]),
    section('FORC', [
      0,
      1,
      2,
      3,
      0,
      1,
      2,
      99,
      1,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      0xf0,
      0xa5,
      0,
      15,
    ]),
    section(extended ? 'STRx' : 'STR ', [
      if (extended) ...[1, 0, 0, 0, 8, 0, 0, 0] else ...[1, 0, 4, 0],
      ...utf8.encode('Shared'),
      0,
      0xde,
      0xad,
    ]),
    section('SPRP', [1, 0, 1, 0]),
    section('XTRA', [0xff, 0, 42]),
  ],
);
RawChkDocument apply(RawChkDocument doc, Map<int, RawChkSection> edits) {
  for (final e in edits.entries) {
    doc = doc.replaceSection(e.key, e.value);
  }
  return doc;
}

void main() {
  const editor = ChkForceSettingsEditor();
  for (final extended in [false, true]) {
    test(
      'force edits preserve shared text, raw tail and reserved bits ($extended)',
      () {
        final source = fixture(extended: extended);
        final edited = apply(
          source,
          editor.edit(
            source,
            assignments: {0: 3},
            flags: {0: 15, 1: 2},
            names: {0: '새 세력', 2: 'Third'},
          ),
        );
        expect(edited.sections[1].payload, [
          3,
          1,
          2,
          3,
          0,
          1,
          2,
          99,
          2,
          0,
          1,
          0,
          3,
          0,
          0,
          0,
          0xff,
          0xa2,
          0,
          15,
        ]);
        expect(editor.read(edited).names, ['새 세력', 'Shared', 'Third', '']);
        final views = const ChkStringViewDecoder().decode(edited);
        final table = [...views.legacyTables, ...views.extendedTables].single;
        expect(table.entries.first.rawBytes, utf8.encode('Shared'));
        expect(
          table.rawSection.payload.sublist(
            table.stringDataOffset,
            table.stringDataOffset + 9,
          ),
          [...utf8.encode('Shared'), 0, 0xde, 0xad],
        );
        expect(identical(edited.sections[3], source.sections[3]), isTrue);
        expect(identical(edited.sections[4], source.sections[4]), isTrue);
        expect(source.isDirty, isFalse);
        expect(
          editor.edit(
            edited,
            assignments: {7: 99},
            flags: {0: 15},
            names: {0: '새 세력'},
          ),
          isEmpty,
        );
        final cleared = editor.edit(edited, names: {1: ''});
        expect(cleared.keys, [1]);
        expect(cleared[1]!.payload.sublist(10, 12), [0, 0]);
      },
    );
  }
  test('rejects ambiguous structure and invalid input atomically', () {
    final source = fixture();
    for (final length in [0, 19, 21]) {
      expect(
        () => editor.read(
          source.replaceSection(1, section('FORC', List.filled(length, 0))),
        ),
        throwsStateError,
      );
    }
    expect(
      () => editor.read(
        RawChkDocument(
          sourceLength: 0,
          sections: [...source.sections, source.sections[1]],
        ),
      ),
      throwsStateError,
    );
    expect(
      () => editor.read(source.replaceSection(0, section('VER ', [255, 0]))),
      throwsStateError,
    );
    expect(
      () => editor.edit(source, assignments: {0: 2, 8: 0}),
      throwsRangeError,
    );
    expect(() => editor.edit(source, assignments: {0: 4}), throwsRangeError);
    expect(() => editor.edit(source, flags: {0: 16}), throwsRangeError);
    expect(
      () => editor.edit(source, names: {0: 'valid', 1: 'bad\u0000name'}),
      throwsArgumentError,
    );
    expect(source.isDirty, isFalse);
  });
  test('unavailable name data does not prevent assignment or flag edits', () {
    final source = fixture();
    final missing = source.replaceSection(2, section('XSTR', []));
    expect(editor.read(missing).nameIssues.every((v) => v != null), isTrue);
    expect(editor.edit(missing, assignments: {0: 2}, flags: {0: 8}).keys, [1]);
    expect(() => editor.edit(missing, names: {0: 'new'}), throwsStateError);
    final invalid = source.replaceSection(
      2,
      section('STR ', [1, 0, 4, 0, 0xff, 0]),
    );
    expect(editor.read(invalid).names, [null, null, '', '']);
    expect(editor.edit(invalid, names: {2: 'valid'}).length, 2);
    final duplicate = RawChkDocument(
      sourceLength: 0,
      sections: [...source.sections, source.sections[2]],
    );
    expect(() => editor.edit(duplicate, names: {0: 'new'}), throwsStateError);
  });
  test('extended string table cannot allocate force references above u16', () {
    const count = 65535;
    const header = 4 + count * 4;
    final bytes = Uint8List(header + 2);
    final data = ByteData.sublistView(bytes)
      ..setUint32(0, count, Endian.little);
    for (var i = 0; i < count; i++) {
      data.setUint32(4 + i * 4, header, Endian.little);
    }
    bytes[header] = 65;
    final source = fixture().replaceSection(2, section('STRx', bytes));
    expect(() => editor.edit(source, names: {0: 'new'}), throwsStateError);
    expect(source.isDirty, isFalse);
  });
}
