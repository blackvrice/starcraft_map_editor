import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_upgrade_settings_editor.dart';

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
      expanded ? 'UPGx' : 'UPGS',
      List.generate(expanded ? 794 : 598, (i) => i % 251),
    ),
    section(expanded ? 'PUPx' : 'UPGR', List.filled(expanded ? 2318 : 1748, 0)),
    section(expanded ? 'UPGS' : 'UPGx', [255, 1, 2]),
    section(expanded ? 'UPGR' : 'PUPx', [9]),
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
  const editor = ChkUpgradeSettingsEditor();
  const start = ChkUpgradeField.start;
  const max = ChkUpgradeField.maximum;
  const inherit = ChkUpgradeField.inherit;
  for (final expanded in [false, true]) {
    test('golden offsets and alternate preservation expanded=$expanded', () {
      final doc = fixture(expanded);
      final count = expanded ? 61 : 46;
      final last = count - 1;
      final expectedCosts = doc.sections[1].payload;
      final changes = <UpgradeSettingKey, int>{};
      final starts = expanded
          ? [62, 184, 306, 428, 550, 672]
          : [46, 138, 230, 322, 414, 506];
      for (var i = 0; i < 6; i++) {
        changes[(last, null, ChkUpgradeField.values[i + 1])] = 0x1234 + i;
        expectedCosts[starts[i] + last * 2] = 0x34 + i;
        expectedCosts[starts[i] + last * 2 + 1] = 0x12;
      }
      changes.addAll({
        (last, null, max): 255,
        (last, null, start): 200,
        (last, 7, max): 5,
        (last, 7, start): 3,
        (last, 7, inherit): 1,
      });
      final expectedLevels = doc.sections[2].payload
        ..[8 * count - 1] = 5
        ..[20 * count - 1] = 3
        ..[25 * count - 1] = 255
        ..[26 * count - 1] = 200
        ..[34 * count - 1] = 1;
      final changed = apply(doc, editor.edit(doc, changes));
      expect(changed.sections[1].payload, expectedCosts);
      expect(changed.sections[2].payload, expectedLevels);
      for (var i = 3; i < doc.sections.length; i++) {
        expect(identical(changed.sections[i], doc.sections[i]), isTrue);
      }
      expect(editor.read(changed).hasAlternate, isTrue);
      expect(doc.isDirty, isFalse);
      expect(editor.edit(changed, changes), isEmpty);
      if (expanded) expect(changed.sections[1].payload[61], 61);
    });
  }
  test('defaults retain custom costs and dormant player levels', () {
    final doc = fixture(true);
    final levels = doc.sections[2].payload
      ..[0] = 2
      ..[732] = 7
      ..[1464] = 4;
    final source = doc.replaceSection(2, section('PUPx', levels));
    final changed = apply(
      source,
      editor.edit(source, {
        (0, null, ChkUpgradeField.useDefault): 1,
        (0, 0, inherit): 1,
      }),
    );
    expect(
      changed.sections[1].payload.sublist(1),
      source.sections[1].payload.sublist(1),
    );
    expect(editor.read(changed).value((0, 0, start)), 7);
    expect(() => editor.edit(changed, {(0, 0, inherit): 0}), throwsStateError);
    expect(
      editor.edit(doc, {(2, null, ChkUpgradeField.useDefault): 2}),
      isEmpty,
    );
  });
  test(
    'validates final pairs atomically without normalizing unrelated values',
    () {
      final doc = fixture(false);
      expect(
        () => editor.edit(doc, {
          (0, null, ChkUpgradeField.minerals): 100,
          (0, null, start): 3,
        }),
        throwsStateError,
      );
      final changed = apply(
        doc,
        editor.edit(doc, {(0, null, start): 3, (0, null, max): 4}),
      );
      expect(editor.read(changed).value((0, null, start)), 3);
      for (final key in <UpgradeSettingKey>[
        (46, null, max),
        (0, 8, max),
        (0, 0, ChkUpgradeField.minerals),
        (0, null, inherit),
      ]) {
        expect(() => editor.edit(doc, {key: 1}), throwsArgumentError);
      }
      for (final entry in <UpgradeSettingKey, int>{
        (0, null, max): 256,
        (0, null, start): -1,
        (0, null, ChkUpgradeField.gas): 65536,
        (0, 0, inherit): 2,
      }.entries) {
        expect(
          () => editor.edit(doc, {entry.key: entry.value}),
          throwsRangeError,
        );
      }
      expect(doc.isDirty, isFalse);
    },
  );
  test(
    'missing malformed and duplicate groups are independently unavailable',
    () {
      final source = fixture(true);
      for (final bad in [
        section('NONE', []),
        section('UPGx', List.filled(793, 0)),
        section('UPGx', List.filled(795, 0)),
      ]) {
        final doc = source.replaceSection(1, bad);
        expect(editor.read(doc).issues, contains('UPGx'));
        expect(editor.edit(doc, {(0, null, max): 1}).keys, [2]);
        expect(
          () => editor.edit(doc, {(0, null, ChkUpgradeField.minerals): 1}),
          throwsStateError,
        );
      }
      final duplicate = RawChkDocument(
        sourceLength: 0,
        sections: [...source.sections, source.sections[2]],
      );
      expect(editor.read(duplicate).issues, contains('PUPx'));
      expect(
        editor.edit(duplicate, {(0, null, ChkUpgradeField.minerals): 1}).keys,
        [1],
      );
      expect(
        () => editor.edit(duplicate, {(0, null, max): 1}),
        throwsStateError,
      );
      for (final version in [59, 63, 205, 206]) {
        expect(
          editor
              .read(source.replaceSection(0, section('VER ', [version, 0])))
              .count,
          version < 205 ? 46 : 61,
        );
      }
      expect(
        () => editor.read(source.replaceSection(0, section('VER ', [255, 0]))),
        throwsStateError,
      );
      expect(
        () => editor.read(source.replaceSection(0, section('NONE', []))),
        throwsStateError,
      );
    },
  );
  test('numeric input rejects fractions text and overflow', () {
    for (final input in ['-1', '1.5', 'abc', '65536', '']) {
      expect(
        () => ChkUpgradeField.time.parse(input),
        throwsA(anyOf(isA<FormatException>(), isA<RangeError>())),
      );
    }
    expect(ChkUpgradeField.time.parse(' 65535 '), 65535);
  });
}
