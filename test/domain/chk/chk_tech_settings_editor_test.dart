import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_tech_settings_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument fixture(bool expanded) => RawChkDocument(
  sourceLength: 0,
  sections: [
    section('VER ', [expanded ? 206 : 63, 0]),
    section(
      expanded ? 'TECx' : 'TECS',
      List.generate(expanded ? 396 : 216, (i) => i % 251),
    ),
    section(
      expanded ? 'PTEx' : 'PTEC',
      List.generate(expanded ? 1672 : 912, (i) => i % 251),
    ),
    section(expanded ? 'TECS' : 'TECx', [255, 1, 2]),
    section(expanded ? 'PTEC' : 'PTEx', [9]),
    section('XTRA', [255, 0]),
  ],
);
RawChkDocument apply(RawChkDocument doc, Map<int, RawChkSection> patches) {
  for (final e in patches.entries) {
    doc = doc.replaceSection(e.key, e.value);
  }
  return doc;
}

void main() {
  const editor = ChkTechSettingsEditor();
  const available = ChkTechField.available;
  const researched = ChkTechField.researched;
  const inherit = ChkTechField.inherit;
  for (final expanded in [false, true]) {
    test('golden cost and player offsets expanded=$expanded', () {
      final doc = fixture(expanded);
      final last = expanded ? 43 : 23;
      final expectedCosts = doc.sections[1].payload;
      final changes = <TechSettingKey, int>{};
      final starts = expanded ? [44, 132, 220, 308] : [24, 72, 120, 168];
      for (var i = 0; i < 4; i++) {
        changes[(last, null, ChkTechField.values[i + 1])] = 0x1234 + i;
        expectedCosts[starts[i] + last * 2] = 0x34 + i;
        expectedCosts[starts[i] + last * 2 + 1] = 0x12;
      }
      changes.addAll({
        (last, null, available): 0,
        (last, null, researched): 1,
        (last, 7, available): 1,
        (last, 7, researched): 0,
        (last, 7, inherit): 1,
      });
      final expectedStates = doc.sections[2].payload;
      final offsets = expanded
          ? [351, 879, 1099, 1143, 1495]
          : [191, 479, 599, 623, 815];
      for (var i = 0; i < 5; i++) {
        expectedStates[offsets[i]] = [1, 0, 0, 1, 1][i];
      }
      final changed = apply(doc, editor.edit(doc, changes));
      expect(changed.sections[1].payload, expectedCosts);
      expect(changed.sections[2].payload, expectedStates);
      for (var i = 3; i < doc.sections.length; i++) {
        expect(identical(changed.sections[i], doc.sections[i]), isTrue);
      }
      expect(editor.read(changed).hasAlternate, isTrue);
      expect(doc.isDirty, isFalse);
      expect(editor.edit(changed, changes), isEmpty);
    });
  }
  test(
    'defaults retain costs and player flags without coupling research to availability',
    () {
      final doc = fixture(true);
      final changed = apply(
        doc,
        editor.edit(doc, {
          (0, null, ChkTechField.useDefault): 1,
          (0, null, available): 0,
          (0, null, researched): 1,
          (0, 0, available): 0,
          (0, 0, researched): 1,
          (0, 0, inherit): 1,
        }),
      );
      expect(
        changed.sections[1].payload.sublist(1),
        doc.sections[1].payload.sublist(1),
      );
      final restored = apply(
        changed,
        editor.edit(changed, {(0, 0, inherit): 0}),
      );
      expect(editor.read(restored).value((0, 0, researched)), 1);
      expect(editor.read(restored).value((0, 0, available)), 0);
      expect(
        editor.edit(doc, {(2, null, ChkTechField.useDefault): 2}),
        isEmpty,
      );
    },
  );
  test('invalid IDs flags and costs reject the whole edit', () {
    final doc = fixture(false);
    for (final key in <TechSettingKey>[
      (24, null, available),
      (-1, null, researched),
      (0, 8, available),
      (0, 0, ChkTechField.minerals),
      (0, null, inherit),
    ]) {
      expect(
        () => editor.edit(doc, {(0, null, ChkTechField.gas): 100, key: 1}),
        throwsArgumentError,
      );
    }
    for (final entry in <TechSettingKey, int>{
      (0, null, available): 255,
      (0, null, researched): -1,
      (0, null, ChkTechField.energy): 65536,
      (0, 0, inherit): 255,
    }.entries) {
      expect(
        () => editor.edit(doc, {entry.key: entry.value}),
        throwsRangeError,
      );
    }
    expect(doc.isDirty, isFalse);
  });
  test('groups reject missing duplicate and malformed input independently', () {
    final source = fixture(true);
    for (final bad in [
      section('NONE', []),
      section('TECx', List.filled(395, 0)),
      section('TECx', List.filled(397, 0)),
    ]) {
      final doc = source.replaceSection(1, bad);
      expect(editor.read(doc).issues, contains('TECx'));
      expect(editor.edit(doc, {(0, null, available): 1}).keys, [2]);
      expect(
        () => editor.edit(doc, {(0, null, ChkTechField.minerals): 1}),
        throwsStateError,
      );
    }
    final duplicate = RawChkDocument(
      sourceLength: 0,
      sections: [...source.sections, source.sections[2]],
    );
    expect(editor.read(duplicate).issues, contains('PTEx'));
    expect(editor.edit(duplicate, {(0, null, ChkTechField.minerals): 1}).keys, [
      1,
    ]);
    expect(
      () => editor.edit(duplicate, {(0, null, available): 1}),
      throwsStateError,
    );
    for (final version in [59, 63, 205, 206]) {
      expect(
        editor
            .read(source.replaceSection(0, section('VER ', [version, 0])))
            .count,
        version < 205 ? 24 : 44,
      );
    }
    for (final bytes in [
      <int>[],
      [255, 0],
      [206],
    ]) {
      expect(
        () => editor.read(source.replaceSection(0, section('VER ', bytes))),
        throwsStateError,
      );
    }
  });
  test('numeric input preserves integer limits without rounding', () {
    for (final input in ['-1', '1.5', 'abc', '65536', '']) {
      expect(
        () => ChkTechField.energy.parse(input),
        throwsA(anyOf(isA<FormatException>(), isA<RangeError>())),
      );
    }
    expect(ChkTechField.energy.parse(' 65535 '), 65535);
    expect(ChkTechField.time.parse('0'), 0);
  });
}
