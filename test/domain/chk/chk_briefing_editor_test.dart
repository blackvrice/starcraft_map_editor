import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument doc([List<RawChkSection> sections = const []]) => RawChkDocument(
  sections: [
    section('STR ', [2, 0, 6, 0, 8, 0, 65, 0, ...'own.wav'.codeUnits, 0]),
    ...sections,
  ],
  sourceLength: 0,
);

void main() {
  test(
    'all nine briefing actions match independently specified CHK fields and flags',
    () {
      // Chkdraft chk.cpp briefingTextArguments / briefingDefaultFlags.
      final cases = <int, (int, Map<String, int>, List<(int, int, int)>)>{
        1: (4, {'Duration (ms)': 1234}, [(12, 4, 1234)]),
        2: (
          4,
          {'Sound string ID': 2, 'Duration (ms)': 1234},
          [(8, 4, 2), (12, 4, 1234)],
        ),
        3: (
          0,
          {'String ID': 1, 'Duration (ms)': 1234},
          [(4, 4, 1), (12, 4, 1234)],
        ),
        4: (0, {'String ID': 1}, [(4, 4, 1)]),
        5: (20, {'Unit ID': 65, 'Portrait slot': 3}, [(24, 2, 65), (16, 4, 3)]),
        6: (4, {'Portrait slot': 3}, [(16, 4, 3)]),
        7: (
          4,
          {'Portrait slot': 3, 'Duration (ms)': 1234},
          [(16, 4, 3), (12, 4, 1234)],
        ),
        8: (
          0,
          {
            'String ID': 1,
            'Portrait slot': 3,
            'Modifier': 8,
            'Time adjustment (ms)': 300,
            'Sound string ID': 2,
            'Duration (ms)': 1234,
          },
          [
            (4, 4, 1),
            (8, 4, 2),
            (12, 4, 1234),
            (16, 4, 3),
            (20, 4, 300),
            (27, 1, 8),
          ],
        ),
        9: (0, {}, []),
      };
      expect(TriggerOpcodes.briefingActions.map((e) => e.id), cases.keys);
      for (final entry in cases.entries) {
        final expected = Uint8List(32)
          ..[26] = entry.key
          ..[28] = entry.value.$1;
        final data = ByteData.sublistView(expected);
        for (final field in entry.value.$3) {
          switch (field.$2) {
            case 1:
              data.setUint8(field.$1, field.$3);
            case 2:
              data.setUint16(field.$1, field.$3, Endian.little);
            case 4:
              data.setUint32(field.$1, field.$3, Endian.little);
          }
        }
        final opcode = TriggerOpcodes.find(true, entry.key, briefing: true)!;
        expect(
          ChkTrigger.makeSlot(
            true,
            opcode,
            entry.value.$2,
            doc(),
            briefing: true,
          ),
          expected,
          reason: opcode.name,
        );
        expect(
          () => ChkTrigger.makeSlot(true, opcode, entry.value.$2, doc()),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'MBRF append, read and edits preserve raw conditions, actions and reserved bytes',
    () {
      expect(ChkTriggers.read(doc(), briefing: true).sectionIndex, -1);
      final original = ChkTrigger.create(briefing: true).bytes.toList()
        ..[100] = 199
        ..[2399] = 203
        ..[2369] = 128
        ..[400] = 255;
      final record = ChkTrigger(original, briefing: true);
      expect(record.bytes[15], 13);
      final wait = ChkTrigger.makeSlot(
        true,
        TriggerOpcodes.briefingActions.first,
        {'Duration (ms)': 700},
        doc(),
        briefing: true,
      );
      final edited = record
          .withSlot(true, 0, wait)
          .withOwner(1, true)
          .withSlotEnabled(true, 0, false)
          .withEnabled(false);
      expect(edited.briefing, isTrue);
      expect(edited.bytes[100], 199);
      expect(edited.bytes[400], 255);
      expect(edited.bytes[2399], 203);
      expect(edited.bytes[2369], 128);
      expect(edited.moveSlot(true, 0, 1).slot(true, 1), edited.slot(true, 0));
      final map = doc([
        section('TRIG', ChkTrigger.create().bytes),
        section('MBRF', edited.bytes),
      ]);
      expect(ChkTriggers.read(map).records.single.briefing, isFalse);
      expect(
        ChkTriggers.read(map, briefing: true).records.single.bytes,
        edited.bytes,
      );
      expect(ChkTriggers.validationIssues(map, briefing: true), isEmpty);
      expect(
        () => ChkTriggers.read(
          doc([
            section('MBRF', [1]),
          ]),
          briefing: true,
        ),
        throwsFormatException,
      );
      expect(
        () => ChkTriggers.read(
          doc([section('MBRF', []), section('MBRF', [])]),
          briefing: true,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'invalid fields and string references fail while raw actions remain uninterpreted',
    () {
      final opcode = TriggerOpcodes.find(true, 8, briefing: true)!;
      final valid = {
        'String ID': 1,
        'Portrait slot': 0,
        'Modifier': 7,
        'Time adjustment (ms)': 0,
        'Sound string ID': 2,
        'Duration (ms)': 1000,
      };
      for (final invalid in [
        {'Portrait slot': 4},
        {'Modifier': 0},
        {'String ID': 99},
        {'Duration (ms)': -1},
        {'Sound string ID': 0},
      ]) {
        expect(
          () => ChkTrigger.makeSlot(
            true,
            opcode,
            {...valid, ...invalid},
            doc(),
            briefing: true,
          ),
          throwsFormatException,
        );
      }
      final slot = ChkTrigger.makeSlot(
        true,
        opcode,
        valid,
        doc(),
        briefing: true,
      );
      final record = ChkTrigger.create(briefing: true).withSlot(true, 0, slot);
      final map = doc([section('MBRF', record.bytes)]);
      expect(ChkResourceEditor.references(map).uses.map((u) => u.id), [1, 2]);
      expect(
        () => ChkResourceEditor.edit(map, 1, '', clear: true),
        throwsStateError,
      );
      final broken = record.bytes.toList()..[324] = 99;
      expect(
        ChkTriggers.validationIssues(
          doc([section('MBRF', broken)]),
          briefing: true,
        ),
        hasLength(1),
      );
      final raw = record.slot(true, 0)
        ..[30] = 83
        ..[31] = 67;
      expect(ChkTrigger.editable(true, raw, briefing: true), isFalse);
      expect(
        () => ChkTrigger.makeSlot(
          true,
          opcode,
          valid,
          doc(),
          briefing: true,
          original: raw,
        ),
        throwsFormatException,
      );
    },
  );
}
