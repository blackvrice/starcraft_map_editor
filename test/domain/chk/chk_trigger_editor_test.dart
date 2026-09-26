import 'dart:typed_data';
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
