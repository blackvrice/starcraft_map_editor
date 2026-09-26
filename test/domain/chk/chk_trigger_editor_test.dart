import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_resources.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';

RawChkSection section(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument document(List<RawChkSection> sections) =>
    RawChkDocument(sections: sections, sourceLength: 0);

void main() {
  test(
    'all ordinary opcodes match independent eudplib constructor layouts',
    () {
      final golden =
          jsonDecode(
                File(
                  'test/fixtures/trigger_opcode_layouts.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final refs = document([
        section('TRIG', []),
        section('MRGN', List.filled(40, 0)),
        section('STR ', [1, 0, 4, 0, 65, 0]),
        section('UPRP', List.filled(1280, 0)),
      ]);
      for (final action in [false, true]) {
        final ops = action ? TriggerOpcodes.actions : TriggerOpcodes.conditions;
        final layouts =
            golden[action ? 'actions' : 'conditions'] as Map<String, dynamic>;
        expect(
          ops.map((o) => o.id).toSet(),
          layouts.keys.map(int.parse).toSet(),
        );
        for (final op in ops) {
          final fields = (layouts['${op.id}'] as List).cast<int>();
          final expected = Uint8List(action ? 32 : 20),
              data = ByteData(action ? 32 : 20);
          final offsets = action
              ? [0, 4, 8, 12, 16, 20, 24, 26, 27, 28]
              : [0, 4, 8, 12, 14, 15, 16, 17];
          final widths = action
              ? [4, 4, 4, 4, 4, 4, 2, 1, 1, 1]
              : [4, 4, 4, 2, 1, 1, 1, 1];
          for (var i = 0; i < fields.length; i++) {
            switch (widths[i]) {
              case 1:
                data.setUint8(offsets[i], fields[i]);
              case 2:
                data.setUint16(offsets[i], fields[i], Endian.little);
              case 4:
                data.setUint32(offsets[i], fields[i], Endian.little);
            }
          }
          expected.setAll(0, data.buffer.asUint8List());
          final values = {
            for (final arg in op.arguments)
              arg.name: ChkTrigger.argument(expected, arg),
          };
          expect(
            ChkTrigger.makeSlot(action, op, values, refs),
            expected,
            reason: op.name,
          );
          expect(
            op.arguments.map((a) => a.name).toSet().length,
            op.arguments.length,
            reason: 'unique names ${op.name}',
          );
        }
      }
    },
  );
  test('enable owner and slot ordering preserve unknown bytes', () {
    final original = ChkTrigger(List.generate(2400, (i) => i % 256));
    final toggled = original.withEnabled(false).withOwner(18, true);
    for (var i = 0; i < 2400; i++) {
      if (i != 2368 && i != 2390) expect(toggled.bytes[i], original.bytes[i]);
    }
    expect(toggled.enabled, isFalse);
    expect(
      original.moveSlot(true, 0, 63).moveSlot(true, 63, 0).bytes,
      original.bytes,
    );
    final normal = ChkTrigger.create();
    expect(normal.withSlotEnabled(false, 0, false).slot(false, 0)[17], 2);
    final eud = List.filled(20, 0)
      ..[15] = 15
      ..[4] = 255;
    expect(ChkTrigger.editable(false, eud), isFalse);
  });
  test('property masks shared usage and copy-on-write switch names', () {
    final base = document([
      section('TRIG', []),
      section('STR ', [1, 0, 4, 0, 65, 0]),
    ]);
    var updated = ChkTriggerResources.editProperty(
      base,
      64,
      {'Hitpoints %': 50, 'Energy %': 100},
      [null, true, false, null, true],
    );
    expect(ChkTriggerResources.propertyValues(updated, 64)['Hitpoints %'], 50);
    expect(ChkTriggerResources.specialValues(updated, 64), [
      null,
      true,
      false,
      null,
      true,
    ]);
    expect(updated.sections.last.payload[63], 1);
    updated = ChkTriggerResources.renameSwitch(updated, 255, 'Test switch');
    expect(ChkTriggerResources.switchName(updated, 255), 'Test switch');
    expect(ChkTriggerResources.stringLabel(updated, 1), 'A');
    expect(base.sections.length, 2);
    expect(
      () => ChkTriggerResources.editProperty(updated, 64, {
        'Hitpoints %': 101,
      }, List.filled(5, null)),
      throwsFormatException,
    );
    expect(
      () => ChkTriggerResources.renameSwitch(
        document([
          ...base.sections,
          section('SWNM', [0]),
        ]),
        0,
        'bad',
      ),
      throwsFormatException,
    );
  });
  final refs = document([
    section('MRGN', List.filled(20, 0)),
    section('STR ', [1, 0, 4, 0, 65, 0]),
  ]);
  test(
    'CreateUnit matches binary layout and preserves all unrelated bytes',
    () {
      final action = ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 44)!, {
        'Player': 7,
        'Unit ID': 65,
        'Location ID': 1,
        'Count': 3,
      }, refs);
      final expected = List.filled(32, 0)
        ..[0] = 1
        ..[16] = 7
        ..[24] = 65
        ..[26] = 44
        ..[27] = 3
        ..[28] = 20;
      expect(action, expected);
      final original = List.generate(2400, (i) => i % 256);
      final changed = ChkTrigger(
        original,
      ).withSlot(true, 5, action).withOwner(0, true);
      for (var i = 0; i < 2400; i++) {
        if ((i >= 480 && i < 512) || i == 2372) continue;
        expect(changed.bytes[i], original[i], reason: 'byte $i');
      }
      final raw = document([
        section('TRIG', [...original, ...changed.bytes]),
      ]);
      expect(
        ChkTriggers.encode(ChkTriggers.read(raw).records),
        raw.sections.single.payload,
      );
    },
  );
  test(
    'known slot edits preserve flags and unused fields; EUDX remains raw',
    () {
      final original = List.filled(20, 0)
        ..[0] = 123
        ..[15] = 12
        ..[17] = 2;
      final result = ChkTrigger.makeSlot(
        false,
        TriggerOpcodes.find(false, 12)!,
        {'Comparison': 10, 'Amount': 0xffffffff},
        refs,
        original: original,
      );
      expect(result[0], 123);
      expect(result[17], 2);
      expect(
        ByteData.sublistView(
          Uint8List.fromList(result),
        ).getUint32(8, Endian.little),
        0xffffffff,
      );
      original[18] = 0x53;
      expect(ChkTrigger.editable(false, original), isFalse);
      expect(
        () => ChkTrigger.makeSlot(
          false,
          TriggerOpcodes.find(false, 12)!,
          {'Comparison': 10, 'Amount': 1},
          refs,
          original: original,
        ),
        throwsFormatException,
      );
    },
  );
  test('missing duplicate and truncated TRIG are not repaired', () {
    for (final sections in <List<RawChkSection>>[
      [],
      [section('TRIG', []), section('TRIG', [])],
      [
        section('TRIG', [0]),
      ],
    ]) {
      expect(() => ChkTriggers.read(document(sections)), throwsFormatException);
    }
  });
  test('references and numeric choices are checked before serialization', () {
    List<int> text(RawChkDocument doc, int id) => ChkTrigger.makeSlot(
      true,
      TriggerOpcodes.find(true, 9)!,
      {'String ID': id},
      doc,
    );
    expect(text(refs, 1)[4], 1);
    expect(() => text(refs, 2), throwsFormatException);
    expect(
      () => text(
        document([
          ...refs.sections,
          section('STRx', [0]),
        ]),
        1,
      ),
      throwsFormatException,
    );
    expect(
      () => text(document([...refs.sections, refs.sections.last]), 1),
      throwsFormatException,
    );
    expect(
      () => ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 10)!, {
        'Location ID': 2,
      }, refs),
      throwsFormatException,
    );
    expect(
      () => ChkTrigger.makeSlot(false, TriggerOpcodes.find(false, 12)!, {
        'Comparison': 3,
        'Amount': 1,
      }, refs),
      throwsFormatException,
    );
    expect(
      () => ChkTrigger.create().withSlot(false, 0, List.filled(20, 256)),
      throwsFormatException,
    );
  });
}
