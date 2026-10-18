import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'basic_editing_fixture.dart';

RawChkDocument scriptDocument({List<ChkTrigger>? records}) {
  final doc = basicDocument();
  return doc.replaceSection(
    doc.sections.indexWhere((s) => s.name == 'TRIG'),
    basicSection('TRIG', ChkTriggers.encode(records ?? [scriptRecord(doc)])),
  );
}

ChkTrigger scriptRecord(RawChkDocument doc) {
  TriggerOpcode op(bool action, int id) => TriggerOpcodes.find(action, id)!;
  var record = ChkTrigger.create().withSlot(
    false,
    0,
    ChkTrigger.makeSlot(false, op(false, 22), {}, doc),
  );
  record = record.withSlot(
    true,
    4,
    ChkTrigger.makeSlot(true, op(true, 4), {'Milliseconds': 1000}, doc),
  );
  record = record.withSlot(
    true,
    9,
    ChkTrigger.makeSlot(true, op(true, 3), {}, doc),
  );
  final bytes = [...record.bytes];
  bytes[2372] = 2;
  bytes[2399] = 73;
  bytes[2369] = 0xab;
  bytes[320 + 4 * 32] = 0x99;
  return ChkTrigger(bytes);
}
