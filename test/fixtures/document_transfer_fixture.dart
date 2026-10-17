import 'dart:typed_data';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/editing/document_transfer_controller.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_resources.dart';
import 'basic_editing_fixture.dart';
import 'multi_map_fixture.dart';

DocumentTransferController<EditorAppDependencies> transferController(
  MultiMapFixture f,
) => DocumentTransferController(
  workspace: f.workspace,
  access: (d) => DocumentTransferAccess(
    d.value.mapLayerController,
    d.value.objectEditingController,
  ),
);
const transferSoundPath = r'staredit\wav\transfer.wav';

RawChkDocument transferPut(RawChkDocument doc, String name, List<int> bytes) {
  final i = doc.sections.indexWhere((s) => s.name == name);
  return i < 0
      ? doc.appendSection(basicSection(name, bytes))
      : doc.replaceSection(i, doc.sections[i].withPayload(bytes));
}

RawChkDocument transferSource() {
  final a = basicUnit(id: 9, x: 128, y: 160),
      b = basicUnit(id: 10, x: 160, y: 160);
  ByteData.sublistView(a)
    ..setUint16(10, 0x200, Endian.little)
    ..setUint32(32, 10, Endian.little);
  ByteData.sublistView(b)
    ..setUint16(10, 0x200, Endian.little)
    ..setUint32(32, 9, Endian.little);
  var doc = basicDocument(units: [a, b]);
  doc = ChkResourceEditor.addRaw(doc, [0x04, 0x81, 0xff]);
  final text = ChkResourceEditor.table(doc).declaredStringCount;
  final locations = doc.sections.singleWhere((s) => s.name == 'MRGN').payload;
  ByteData.sublistView(locations)
    ..setUint32(5 * 20, 64, Endian.little)
    ..setUint32(5 * 20 + 4, 96, Endian.little)
    ..setUint32(5 * 20 + 8, 256, Endian.little)
    ..setUint32(5 * 20 + 12, 288, Endian.little)
    ..setUint16(5 * 20 + 16, text, Endian.little)
    ..setUint16(5 * 20 + 18, 37, Endian.little);
  doc = transferPut(doc, 'MRGN', locations);
  doc = ChkTriggerResources.renameSwitch(doc, 3, 'Incoming switch');
  doc = ChkTriggerResources.editProperty(doc, 5, {
    'Hitpoints %': 70,
  }, List.filled(5, null));
  doc = ChkResourceEditor.registerSound(doc, r'staredit\wav\transfer.wav');
  final sound = ChkResourceEditor.table(doc).declaredStringCount;
  var trigger = ChkTrigger.create()
      .withOwner(0, false)
      .withOwner(1, true)
      .withOwner(18, true)
      .withEnabled(false);
  trigger = trigger.withSlot(
    false,
    0,
    ChkTrigger.makeSlot(false, TriggerOpcodes.find(false, 11)!, {
      'Switch ID (0–255)': 3,
      'State': 2,
    }, doc),
  );
  trigger = trigger.withSlot(
    true,
    0,
    ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 11)!, {
      'Player': 1,
      'Unit ID': 0,
      'Location ID': 6,
      'Count': 2,
      'Property slot ID': 5,
    }, doc),
  );
  trigger = trigger.withSlot(
    true,
    1,
    ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 9)!, {
      'String ID': text,
    }, doc),
  );
  trigger = trigger.withSlot(
    true,
    2,
    ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 8)!, {
      'Sound string ID': sound,
    }, doc),
  );
  var briefing = ChkTrigger.create(briefing: true);
  briefing = briefing.withSlot(
    true,
    0,
    ChkTrigger.makeSlot(
      true,
      TriggerOpcodes.find(true, 3, briefing: true)!,
      {'String ID': text, 'Duration (ms)': 1000},
      doc,
      briefing: true,
    ),
  );
  doc = transferPut(doc, 'TRIG', trigger.bytes);
  return transferPut(doc, 'MBRF', briefing.bytes);
}

void adoptTransferDocument(
  OpenMapController maps,
  RawChkDocument doc, {
  Map<String, List<int>?>? resources,
}) {
  final old = maps.state.session!;
  maps.adoptEditedSession(
    OpenedMapSession(
      extractedMap: old.extractedMap,
      rawDocument: doc,
      metadataViews: maps.metadataViewDecoder.decode(doc),
      stringViews: maps.stringViewDecoder.decode(doc),
      terrainViews: maps.terrainViewDecoder.decode(doc),
      objectViews: maps.objectViewDecoder.decode(doc),
      sourceFingerprint: old.sourceFingerprint,
      diagnostics: [],
      resourceEdits: resources ?? old.resourceEdits,
    ),
  );
}
