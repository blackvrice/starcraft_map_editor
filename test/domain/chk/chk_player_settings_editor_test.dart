import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_settings_editor.dart';

RawChkSection part(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument fixture() => RawChkDocument(
  sourceLength: 0,
  sections: [
    part('VER ', [206, 0]),
    part('OWNR', [0, 0, 0, 0, 0, 0, 0, 0, 0xa1, 0xa2, 0xa3, 7]),
    part('SIDE', [1, 0xfe, 1, 1, 1, 1, 1, 1, 7, 7, 7, 4]),
    part('COLR', [0, 1, 2, 3, 4, 5, 6, 7]),
    part('XTRA', [0xff, 0, 3]),
  ],
);

void main() {
  const editor = ChkPlayerSettingsEditor();
  test(
    'changes only requested bytes, preserving reserved players and raw IDs',
    () {
      final document = fixture();
      final replacements = editor.edit(document, [
        const ChkPlayerChange(0, ChkPlayerField.owner, 6),
        const ChkPlayerChange(2, ChkPlayerField.race, 2),
        const ChkPlayerChange(0, ChkPlayerField.color, 8),
      ]);
      expect(replacements.keys, [1, 2, 3]);
      expect(replacements[1]!.payload, [
        6,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0xa1,
        0xa2,
        0xa3,
        7,
      ]);
      expect(replacements[2]!.payload, [1, 0xfe, 2, 1, 1, 1, 1, 1, 7, 7, 7, 4]);
      expect(replacements[3]!.payload, [8, 1, 2, 3, 4, 5, 6, 7]);
      expect(document.isDirty, isFalse);
      expect(
        editor.edit(document, [
          const ChkPlayerChange(1, ChkPlayerField.race, 0xfe),
        ]),
        isEmpty,
      );
    },
  );
  test(
    'refuses invalid values, reserved players and duplicate updates atomically',
    () {
      final document = fixture();
      for (final changes in [
        [const ChkPlayerChange(8, ChkPlayerField.owner, 6)],
        [const ChkPlayerChange(0, ChkPlayerField.race, 8)],
        [const ChkPlayerChange(0, ChkPlayerField.color, 256)],
        [
          const ChkPlayerChange(0, ChkPlayerField.owner, 6),
          const ChkPlayerChange(0, ChkPlayerField.owner, 5),
        ],
      ]) {
        expect(() => editor.edit(document, changes), throwsArgumentError);
        expect(document.isDirty, isFalse);
      }
    },
  );
  test('isolates missing, duplicate, wrong-sized and CRGB color data', () {
    final original = fixture();
    for (final sections in [
      original.sections.where((s) => s.name != 'COLR').toList(),
      [...original.sections, original.sections[3]],
      [
        for (final s in original.sections)
          s.name == 'COLR' ? part('COLR', [0]) : s,
      ],
      [...original.sections, part('CRGB', List.filled(32, 0))],
    ]) {
      final doc = RawChkDocument(sections: sections, sourceLength: 0);
      expect(editor.read(doc)[2].canEdit, isFalse);
      expect(
        () => editor.edit(doc, [
          const ChkPlayerChange(0, ChkPlayerField.color, 1),
        ]),
        throwsStateError,
      );
      expect(
        editor.edit(doc, [
          const ChkPlayerChange(0, ChkPlayerField.owner, 6),
        ]).keys,
        [1],
      );
    }
    final badVersion = original.replaceSection(0, part('VER ', [255, 0]));
    expect(editor.read(badVersion).every((g) => !g.canEdit), isTrue);
  });
  test(
    'start diagnostics distinguish missing, duplicate, inactive and invalid owners',
    () {
      var doc = fixture();
      doc = doc.replaceSection(1, part('OWNR', [6, 5, ...List.filled(10, 0)]));
      List<int> start(int owner) {
        final bytes = Uint8List(36);
        ByteData.sublistView(bytes)
          ..setUint16(8, 214, Endian.little)
          ..setUint8(16, owner);
        return bytes;
      }

      doc = doc.appendSection(
        part('UNIT', [...start(1), ...start(1), ...start(2), ...start(9)]),
      );
      final codes = editor.diagnostics(doc).map((d) => d.code).toSet();
      expect(codes, {
        'CHK_PLAYER_SETTINGS_START_MISSING',
        'CHK_PLAYER_SETTINGS_START_DUPLICATE',
        'CHK_PLAYER_SETTINGS_START_INACTIVE',
        'CHK_PLAYER_SETTINGS_START_OWNER',
      });
      expect(editor.diagnostics(doc).every((d) => !d.blocksOperation), isTrue);
      final broken = doc.appendSection(part('UNIT', [0]));
      expect(
        editor.diagnostics(broken).single.code,
        'CHK_PLAYER_SETTINGS_START_UNAVAILABLE',
      );
    },
  );
}
