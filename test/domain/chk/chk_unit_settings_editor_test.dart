import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_settings_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument fixture({bool expanded = true, bool extendedStrings = false}) {
  final bytes = Uint8List.fromList(
    List.generate(expanded ? 4168 : 4048, (i) => i % 251),
  );
  bytes[0] = 0;
  bytes[1] = 1;
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < 228; i++) {
    data.setUint16(3192 + i * 2, 1, Endian.little);
  }
  return RawChkDocument(
    sourceLength: 0,
    sections: [
      section('VER ', [expanded ? 206 : 63, 0]),
      section(expanded ? 'UNIx' : 'UNIS', bytes),
      section(expanded ? 'UNIS' : 'UNIx', [0xde, 0xad]),
      section(extendedStrings ? 'STRx' : 'STR ', [
        if (extendedStrings) ...[1, 0, 0, 0, 8, 0, 0, 0] else ...[1, 0, 4, 0],
        ...utf8.encode('Shared'),
        0,
        0xde,
        0xad,
      ]),
      section('SPRP', [1, 0, 1, 0]),
      section('XTRA', [255, 0, 22]),
    ],
  );
}

RawChkDocument apply(RawChkDocument doc, Map<int, RawChkSection> edits) {
  for (final e in edits.entries) {
    doc = doc.replaceSection(e.key, e.value);
  }
  return doc;
}

void main() {
  const editor = ChkUnitSettingsEditor();
  for (final expanded in [false, true]) {
    test(
      'edits exact unit and weapon bytes, preserving alternate ($expanded)',
      () {
        final source = fixture(expanded: expanded);
        final before = source.sections[1].payload;
        final count = expanded ? 130 : 100;
        final edited = apply(
          source,
          editor.edit(
            source,
            values: {
              (227, ChkUnitSettingField.useDefault): 0,
              (227, ChkUnitSettingField.hitpoints): 0xffffffff,
              (227, ChkUnitSettingField.shields): 65535,
              (227, ChkUnitSettingField.armor): 255,
              (227, ChkUnitSettingField.buildTime): 65535,
              (227, ChkUnitSettingField.minerals): 321,
              (227, ChkUnitSettingField.gas): 654,
            },
            damage: {(count - 1, false): 1234, (count - 1, true): 4321},
          ),
        );
        final expected = Uint8List.fromList(before);
        final data = ByteData.sublistView(expected)
          ..setUint8(227, 0)
          ..setUint32(1136, 0xffffffff, Endian.little)
          ..setUint16(1594, 65535, Endian.little)
          ..setUint8(1823, 255)
          ..setUint16(2278, 65535, Endian.little)
          ..setUint16(2734, 321, Endian.little)
          ..setUint16(3190, 654, Endian.little);
        data.setUint16(3648 + (count - 1) * 2, 1234, Endian.little);
        data.setUint16(3648 + count * 2 + (count - 1) * 2, 4321, Endian.little);
        expect(edited.sections[1].payload, expected);
        expect(editor.read(edited).weaponCount, count);
        expect(editor.read(edited).hasAlternate, isTrue);
        expect(identical(edited.sections[2], source.sections[2]), isTrue);
        expect(identical(edited.sections.last, source.sections.last), isTrue);
        expect(source.isDirty, isFalse);
        expect(
          editor.edit(edited, values: {(227, ChkUnitSettingField.armor): 255}),
          isEmpty,
        );
      },
    );
  }
  for (final extended in [false, true]) {
    test(
      'unit names append independently and preserve shared bytes ($extended)',
      () {
        final source = fixture(extendedStrings: extended);
        final edited = apply(
          source,
          editor.edit(source, names: {0: 'Marine custom', 1: '새 이름'}),
        );
        final view = editor.read(edited);
        expect(view.name(0), 'Marine custom');
        expect(view.name(1), '새 이름');
        expect(view.name(2), 'Shared');
        expect(view.table!.declaredStringCount, 3);
        expect(view.table!.entries.first.rawBytes, utf8.encode('Shared'));
        expect(
          view.table!.rawSection.payload.sublist(
            view.table!.stringDataOffset,
            view.table!.stringDataOffset + 9,
          ),
          [...utf8.encode('Shared'), 0, 0xde, 0xad],
        );
        expect(edited.sections[4].payload, source.sections[4].payload);
        final clear = editor.edit(edited, names: {0: ''});
        expect(clear.keys, [1]);
        expect(clear[1]!.payload.sublist(3192, 3194), [0, 0]);
      },
    );
  }
  test(
    'default restore touches only flag and preserves stored custom values',
    () {
      final source = fixture();
      final expected = source.sections[1].payload..[0] = 1;
      final restored = apply(
        source,
        editor.edit(source, values: {(0, ChkUnitSettingField.useDefault): 1}),
      );
      expect(restored.sections[1].payload, expected);
      expect(
        editor.edit(source, values: {(2, ChkUnitSettingField.useDefault): 2}),
        isEmpty,
      );
      expect(
        () => editor.edit(
          source,
          values: {(0, ChkUnitSettingField.useDefault): 2},
        ),
        throwsRangeError,
      );
    },
  );
  test('HP conversion is exact and rejects precision loss and overflow', () {
    const hp = ChkUnitSettingField.hitpoints;
    for (final raw in [0, 1, 255, 256, 257, 0xffffffff]) {
      expect(hp.parse(hp.display(raw)), raw);
    }
    expect(hp.parse('100.5'), 25728);
    expect(() => hp.parse('0.1'), throwsFormatException);
    expect(() => hp.parse('16777216'), throwsRangeError);
    expect(() => hp.parse('-1'), throwsFormatException);
    expect(() => ChkUnitSettingField.armor.parse('256'), throwsRangeError);
  });
  test('ambiguous sections and invalid edits are rejected atomically', () {
    final source = fixture();
    expect(
      () => editor.read(source.replaceSection(0, section('VER ', [255, 0]))),
      throwsStateError,
    );
    expect(
      () => editor.read(source.replaceSection(1, section('UNIx', [0]))),
      throwsStateError,
    );
    expect(
      () => editor.read(source.replaceSection(1, section('NONE', []))),
      throwsStateError,
    );
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
      () => editor.edit(source, values: {(228, ChkUnitSettingField.armor): 1}),
      throwsRangeError,
    );
    expect(
      () => editor.edit(source, damage: {(130, false): 1}),
      throwsRangeError,
    );
    expect(
      () => editor.edit(source, damage: {(0, false): -1}),
      throwsRangeError,
    );
    expect(
      () => editor.edit(
        source,
        values: {(0, ChkUnitSettingField.armor): 4},
        names: {0: 'valid', 1: 'bad\u0000'},
      ),
      throwsArgumentError,
    );
    expect(source.isDirty, isFalse);
  });
  test('unsafe names do not block numeric settings', () {
    final source = fixture().replaceSection(
      3,
      section('STR ', [1, 0, 4, 0, 255, 0]),
    );
    expect(() => editor.read(source).name(0), throwsFormatException);
    expect(
      editor.edit(source, values: {(0, ChkUnitSettingField.shields): 42}).keys,
      [1],
    );
    final missing = source.replaceSection(3, section('NONE', []));
    expect(() => editor.edit(missing, names: {0: 'new'}), throwsStateError);
  });
  test('unit names cannot exceed u16 IDs in STRx', () {
    const count = 65535;
    const header = 4 + count * 4;
    final bytes = Uint8List(header + 2);
    final data = ByteData.sublistView(bytes)
      ..setUint32(0, count, Endian.little);
    for (var i = 0; i < count; i++) {
      data.setUint32(4 + i * 4, header, Endian.little);
    }
    bytes[header] = 65;
    expect(
      () => editor.edit(
        fixture().replaceSection(3, section('STRx', bytes)),
        names: {0: 'new'},
      ),
      throwsStateError,
    );
  });
}
