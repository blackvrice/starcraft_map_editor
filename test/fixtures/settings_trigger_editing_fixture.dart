import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';

RawChkSection editingSection(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument editingDocument() => const NewMapFactory().create(
  NewMapOptions(width: 32, height: 32, rawTileValue: 0, title: 'Mission Alpha'),
);
RawChkDocument withRecords(
  RawChkDocument doc,
  List<ChkTrigger> records, {
  bool briefing = false,
}) {
  final name = briefing ? 'MBRF' : 'TRIG';
  final index = doc.sections.indexWhere((s) => s.name == name);
  final section = editingSection(name, ChkTriggers.encode(records));
  return index < 0
      ? doc.appendSection(section)
      : doc.replaceSection(index, section);
}

ChkTrigger triggerAction(
  RawChkDocument doc,
  int id, {
  bool briefing = false,
  Map<String, int> values = const {},
}) {
  final op = TriggerOpcodes.find(true, id, briefing: briefing)!;
  return ChkTrigger.create(briefing: briefing).withSlot(
    true,
    0,
    ChkTrigger.makeSlot(
      true,
      op,
      {
        for (final arg in op.arguments)
          arg.name:
              values[arg.name] ??
              (arg.choices.isNotEmpty
                  ? arg.choices.keys.first
                  : switch (arg.reference) {
                      'location' => 64,
                      'string' || 'property' => 1,
                      _ => 0,
                    }),
      },
      doc,
      briefing: briefing,
    ),
  );
}
