import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/map_sound.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import '../../fixtures/pcm_sound_fixture.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument document([List<RawChkSection> others = const []]) =>
    RawChkDocument(
      sections: [
        section('STR ', [2, 0, 6, 0, 8, 0, 65, 0, 0xff, 0]),
        ...others,
      ],
      sourceLength: 0,
    );

void main() {
  test(
    'shared text edits and reference split preserve untouched raw bytes and IDs',
    () {
      final original = document([
        section('SPRP', [1, 0, 1, 0]),
      ]);
      final refs = ChkResourceEditor.references(original);
      expect(refs.uncertainties, isEmpty);
      expect(refs.uses, hasLength(2));
      final edited = ChkResourceEditor.edit(original, 1, 'Hello');
      expect(ChkResourceEditor.table(edited).entryForId(2)!.rawBytes, [255]);
      expect(edited.sections[1], same(original.sections[1]));
      final split = ChkResourceEditor.edit(
        original,
        1,
        'Only title',
        onlyUse: refs.uses.first,
      );
      expect(split.sections[1].payload, [3, 0, 1, 0]);
      expect(ChkResourceEditor.table(split).entryForId(1)!.rawBytes, [65]);
      expect(
        utf8.decode(ChkResourceEditor.table(split).entryForId(3)!.rawBytes!),
        'Only title',
      );
      expect(original.sections.first.payload, [
        2,
        0,
        6,
        0,
        8,
        0,
        65,
        0,
        255,
        0,
      ]);
      expect(
        () => ChkResourceEditor.edit(original, 1, '', clear: true),
        throwsStateError,
      );
      final cleared = ChkResourceEditor.edit(original, 2, '', clear: true);
      expect(ChkResourceEditor.table(cleared).declaredStringCount, 2);
      expect(ChkResourceEditor.table(cleared).entryForId(2)!.rawBytes, isEmpty);
    },
  );
  test('unknown, duplicate and raw trigger sections prevent unused claims', () {
    final raw = ChkTrigger.create().bytes.toList()..[346] = 255;
    for (final extra in [
      [
        section('????', [1]),
      ],
      [
        section('SPRP', [0, 0, 0, 0]),
        section('SPRP', [0, 0, 0, 0]),
      ],
      [section('TRIG', raw)],
      [
        section('WAV ', [1]),
      ],
    ]) {
      final doc = document(extra);
      expect(ChkResourceEditor.references(doc).uncertainties, isNotEmpty);
      expect(
        () => ChkResourceEditor.edit(doc, 2, '', clear: true),
        throwsStateError,
      );
    }
  });
  test(
    'TRIG and MBRF sound/text uses prevent deletion, and registration can be removed',
    () {
      final sound = ChkResourceEditor.registerSound(
        document(),
        r'staredit\wav\own.wav',
      );
      final trigger = ChkTrigger.create().bytes.toList()
        ..[346] = 8
        ..[328] = 3;
      final used = sound.appendSection(section('TRIG', trigger));
      expect(
        ChkResourceEditor.references(used).uses.where((u) => u.sound),
        hasLength(2),
      );
      expect(
        () => ChkResourceEditor.unregisterSound(used, r'staredit\wav\own.wav'),
        throwsStateError,
      );
      final briefing = Uint8List(2400)
        ..[346] = 8
        ..[324] = 1
        ..[328] = 3;
      final brief = sound.appendSection(section('MBRF', briefing));
      expect(
        ChkResourceEditor.references(brief).uses.where((u) => u.id == 1),
        hasLength(1),
      );
      expect(
        () => ChkResourceEditor.unregisterSound(brief, r'staredit\wav\own.wav'),
        throwsStateError,
      );
      expect(
        () => ChkResourceEditor.edit(sound, 3, 'renamed.wav'),
        throwsStateError,
      );
      final removed = ChkResourceEditor.unregisterSound(
        sound,
        r'staredit\wav\own.wav',
      );
      expect(ChkResourceEditor.references(removed).uses, isEmpty);
      expect(removed.sections.first, same(sound.sections.first));
    },
  );
  test(
    'STRx stays extended; malformed table is inspectable but cannot be edited',
    () {
      final extended = RawChkDocument(
        sections: [
          section('STRx', [1, 0, 0, 0, 8, 0, 0, 0, 65, 0]),
        ],
        sourceLength: 0,
      );
      final edit = ChkResourceEditor.edit(extended, 1, '한글');
      expect(edit.sections.single.name, 'STRx');
      expect(
        utf8.decode(ChkResourceEditor.table(edit).entryForId(1)!.rawBytes!),
        '한글',
      );
      final broken = RawChkDocument(
        sections: [
          section('STR ', [1, 0, 250, 0]),
        ],
        sourceLength: 0,
      );
      expect(
        ChkResourceEditor.table(broken, forEditing: false).diagnostics,
        isNotEmpty,
      );
      expect(
        () => ChkResourceEditor.edit(broken, 1, 'x'),
        throwsFormatException,
      );
      final full = RawChkDocument(
        sections: [
          section('STR ', [1, 0, 4, 0, 65, 0, ...List.filled(65530, 0)]),
        ],
        sourceLength: 0,
      );
      expect(() => ChkResourceEditor.edit(full, 1, 'x'), throwsRangeError);
    },
  );
  test(
    'PCM and archive path validation reject truncated, compressed and unsafe inputs',
    () {
      final pcm = pcmSoundFixture();
      expect(() => MapSound.validate(pcm), returnsNormally);
      expect(MapSound.path('staredit/wav/own.WAV'), r'staredit\wav\own.WAV');
      for (final path in [
        r'..\x.wav',
        r'C:\x.wav',
        r'\x.wav',
        'x.ogg',
        r'a\\b.wav',
        'a/../b.wav',
        '한글.wav',
      ]) {
        expect(() => MapSound.path(path), throwsFormatException, reason: path);
      }
      final compressed = Uint8List.fromList(pcm)..[20] = 3;
      final trailing = Uint8List.fromList([...pcm, 0]);
      ByteData.sublistView(
        trailing,
      ).setUint32(4, trailing.length - 8, Endian.little);
      for (final bytes in [
        pcm.sublist(0, pcm.length - 1),
        compressed,
        trailing,
      ]) {
        expect(() => MapSound.validate(bytes), throwsFormatException);
      }
    },
  );
}
