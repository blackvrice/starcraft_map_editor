import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_unit_availability_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument fixture() => RawChkDocument(
  sourceLength: 0,
  sections: [
    section('VER ', [205, 0]),
    section('PUNI', List.generate(5700, (i) => i % 251)),
    section('XTRA', [0, 255, 1]),
  ],
);
RawChkDocument apply(RawChkDocument doc, Map<int, RawChkSection> changes) {
  for (final e in changes.entries) {
    doc = doc.replaceSection(e.key, e.value);
  }
  return doc;
}

void main() {
  const editor = ChkUnitAvailabilityEditor();
  const global = ChkUnitAvailabilityField.global;
  const player = ChkUnitAvailabilityField.player;
  const inherit = ChkUnitAvailabilityField.inherit;
  test(
    'golden edits preserve reserved players, unknown values and unrelated sections',
    () {
      final source = fixture();
      final expected = source.sections[1].payload
        ..[1823] = 1
        ..[2963] = 0
        ..[4787] = 1;
      final result = apply(
        source,
        editor.edit(source, {
          (7, 227, player): 1,
          (null, 227, global): 0,
          (7, 227, inherit): 1,
        }),
      );
      expect(result.sections[1].payload, expected);
      expect(identical(result.sections[2], source.sections[2]), isTrue);
      expect(source.isDirty, isFalse);
      expect(editor.edit(result, {(7, 227, player): 1}), isEmpty);
    },
  );
  test(
    'inheritance changes effective result without erasing player override',
    () {
      final source = fixture();
      final custom = apply(
        source,
        editor.edit(source, {
          (0, 0, player): 0,
          (null, 0, global): 1,
          (0, 0, inherit): 0,
        }),
      );
      expect(editor.read(custom).effective(0, 0), isFalse);
      final inherited = apply(
        custom,
        editor.edit(custom, {(0, 0, inherit): 1}),
      );
      expect(editor.read(inherited).effective(0, 0), isTrue);
      expect(editor.read(inherited).value((0, 0, player)), 0);
      expect(
        editor
            .read(
              apply(inherited, editor.edit(inherited, {(null, 0, global): 0})),
            )
            .effective(0, 0),
        isFalse,
      );
      expect(editor.read(source).effective(1, 5), isNull);
      expect(editor.edit(source, {(0, 2, player): 2}), isEmpty);
    },
  );
  test('rejects unsupported input atomically', () {
    final source = fixture();
    for (final key in <UnitAvailabilityKey>[
      (8, 0, player),
      (0, 228, player),
      (0, 0, global),
      (null, 0, inherit),
    ]) {
      expect(
        () => editor.edit(source, {(0, 0, player): 1, key: 0}),
        throwsArgumentError,
      );
    }
    expect(() => editor.edit(source, {(0, 0, player): 255}), throwsRangeError);
    expect(source.isDirty, isFalse);
  });
  test('requires one known version and one exact PUNI', () {
    final source = fixture();
    for (final bytes in [<int>[], List.filled(5699, 0), List.filled(5701, 0)]) {
      expect(
        () => editor.read(source.replaceSection(1, section('PUNI', bytes))),
        throwsStateError,
      );
    }
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
      () => editor.read(source.replaceSection(0, section('VER ', [255, 0]))),
      throwsStateError,
    );
    for (final version in [59, 63, 205, 206]) {
      expect(
        editor
            .read(source.replaceSection(0, section('VER ', [version, 0])))
            .bytes
            .length,
        5700,
      );
    }
  });
}
