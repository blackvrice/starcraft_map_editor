import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_document_transfer.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_resources.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/document_transfer_fixture.dart';

void main() {
  test('a blank location referenced by a target trigger remains reserved', () {
    final source = transferSource();
    var target = basicDocument();
    final r = ChkTrigger.create().withSlot(
      true,
      0,
      ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 10)!, {
        'Location ID': 1,
      }, target),
    );
    target = transferPut(target, 'TRIG', r.bytes);
    final plan = ChkDocumentTransfer.capture(
      source,
      selected: {
        'MRGN': {5},
      },
    ).preview(target);
    expect(plan.locations[6], 2);
    expect(
      plan.result.sections
          .singleWhere((s) => s.name == 'MRGN')
          .payload
          .take(20),
      List.filled(20, 0),
    );
    expect(ChkTriggers.read(plan.result).records.single.bytes, r.bytes);
  });
  test(
    'Anywhere references require full-map bounds and matching elevation semantics',
    () {
      var source = basicDocument();
      final r = ChkTrigger.create().withSlot(
        true,
        0,
        ChkTrigger.makeSlot(true, TriggerOpcodes.find(true, 10)!, {
          'Location ID': 64,
        }, source),
      );
      source = transferPut(source, 'TRIG', r.bytes);
      final clip = ChkDocumentTransfer.capture(source, triggers: {0});
      expect(clip.preview(basicDocument()).locations, {64: 64});
      final bytes = basicDocument().sections
          .singleWhere((s) => s.name == 'MRGN')
          .payload;
      bytes[63 * 20] = 1;
      expect(
        () => clip.preview(transferPut(basicDocument(), 'MRGN', bytes)),
        throwsStateError,
      );
    },
  );
  test(
    'ordinary trigger closure remaps strings, locations, switches, properties, pairs and owners without changing inputs',
    () {
      final source = transferSource(),
          target = basicDocument(units: [basicUnit(id: 1)]);
      final sourceBytes = const RawChkEncoder().encode(source),
          targetBytes = const RawChkEncoder().encode(target);
      final clip = ChkDocumentTransfer.capture(
        source,
        selected: {
          'UNIT': {0, 1},
        },
        triggers: {0},
        briefings: {0},
      );
      final plan = clip.preview(
        target,
        offsetX: 32,
        offsetY: -32,
        owners: {0: 1, 1: 0},
      );
      final result = plan.result,
          trigger = ChkTriggers.read(result).records.single;
      expect(clip.locationIndices, {5});
      expect(plan.locations[6], 1);
      expect(plan.switches[3], 0);
      expect(plan.properties[5], 1);
      expect(plan.units, {9: 2, 10: 3});
      expect(trigger.enabled, isFalse);
      expect(trigger.bytes[2372], 1);
      expect(trigger.bytes[2373], 0);
      expect(
        trigger.bytes[2390],
        1,
      ); // Force remains a force, not a player slot.
      final action = ByteData.sublistView(
        Uint8List.fromList(trigger.slot(true, 0)),
      );
      expect(action.getUint32(0, Endian.little), 1);
      expect(action.getUint32(16, Endian.little), 0);
      expect(action.getUint32(20, Endian.little), 1);
      final oldName = basicData(
        source,
        'MRGN',
      ).getUint16(5 * 20 + 16, Endian.little);
      expect(
        ChkResourceEditor.table(
          result,
        ).entryForId(plan.strings[oldName]!)!.rawBytes,
        [4, 0x81, 0xff],
      );
      expect(
        basicData(result, 'MRGN').getUint16(16, Endian.little),
        plan.strings[oldName],
      );
      expect(basicData(result, 'MRGN').getUint32(0, Endian.little), 96);
      expect(basicData(result, 'MRGN').getUint32(4, Endian.little), 64);
      expect(basicData(result, 'MRGN').getUint16(18, Endian.little), 37);
      expect(ChkTriggerResources.propertyValues(result, 1)['Hitpoints %'], 70);
      expect(ChkTriggerResources.switchName(result, 0), 'Incoming switch');
      final units = basicData(result, 'UNIT');
      expect(units.getUint32(36 + 32, Endian.little), 3);
      expect(units.getUint32(72 + 32, Endian.little), 2);
      expect(units.getUint16(36 + 4, Endian.little), 160);
      expect(units.getUint8(36 + 16), 1);
      expect(ChkTriggers.validationIssues(result), isEmpty);
      expect(ChkTriggers.validationIssues(result, briefing: true), isEmpty);
      expect(
        result.sections.last.payload,
        source.sections.last.payload,
        reason: 'Unknown target section stays byte-exact',
      );
      expect(const RawChkEncoder().encode(source), sourceBytes);
      expect(const RawChkEncoder().encode(target), targetBytes);
    },
  );
  test(
    'target-used slots and location names with colliding numeric IDs stay untouched',
    () {
      final source = transferSource();
      var target = ChkTriggerResources.renameSwitch(
        basicDocument(),
        0,
        'Target switch',
      );
      target = ChkTriggerResources.editProperty(target, 1, {
        'Energy %': 80,
      }, List.filled(5, null));
      final bytes = target.sections
          .singleWhere((s) => s.name == 'MRGN')
          .payload;
      ByteData.sublistView(bytes)
        ..setUint32(8, 50, Endian.little)
        ..setUint16(16, 1, Endian.little);
      target = transferPut(target, 'MRGN', bytes);
      final plan = ChkDocumentTransfer.capture(
        source,
        triggers: {0},
      ).preview(target);
      expect(plan.locations[6], 2);
      expect(plan.switches[3], 1);
      expect(plan.properties[5], 2);
      expect(ChkTriggerResources.switchName(plan.result, 0), 'Target switch');
      expect(
        ChkTriggerResources.propertyValues(plan.result, 1)['Energy %'],
        80,
      );
      expect(basicData(plan.result, 'MRGN').getUint16(16, Endian.little), 1);
    },
  );
  test(
    'raw, EUDX, reserved trigger flags and reserved owners are refused atomically',
    () {
      final source = transferSource();
      for (final offset in [18, 31, 2369, 2386]) {
        final bytes = source.sections
            .singleWhere((s) => s.name == 'TRIG')
            .payload;
        bytes[offset] = 1;
        expect(
          () => ChkDocumentTransfer.capture(
            transferPut(source, 'TRIG', bytes),
            triggers: {0},
          ),
          throwsStateError,
        );
      }
    },
  );
  test(
    'unresolved links, incomplete pair, reserved locations and unsupported object kinds are refused',
    () {
      final source = transferSource();
      for (final selected in <Map<String, Set<int>>>[
        {
          'UNIT': {0},
        },
        {
          'MRGN': {63},
        },
        {
          'DD2 ': {0},
        },
      ]) {
        expect(
          () => ChkDocumentTransfer.capture(source, selected: selected),
          throwsStateError,
        );
      }
    },
  );
  test(
    'capacity, coordinate bounds, tile set, malformed tables and owner merges fail before apply',
    () {
      final clip = ChkDocumentTransfer.capture(transferSource(), triggers: {0});
      final target = basicDocument();
      expect(() => clip.preview(target, offsetX: 2048), throwsRangeError);
      expect(() => clip.preview(target, owners: {0: 1}), throwsStateError);
      expect(
        () => clip.preview(transferPut(target, 'ERA ', [1, 0])),
        throwsStateError,
      );
      expect(
        () => clip.preview(target.appendSection(basicSection('STR ', [0, 0]))),
        throwsFormatException,
      );
      expect(
        () => clip.preview(transferPut(target, 'UPUS', List.filled(64, 1))),
        throwsStateError,
      );
      final locations = target.sections
          .singleWhere((s) => s.name == 'MRGN')
          .payload;
      for (var i = 0; i < 255; i++) {
        locations[i * 20] = 1;
      }
      expect(
        () => clip.preview(transferPut(target, 'MRGN', locations)),
        throwsStateError,
      );
    },
  );
  test('opaque target triggers cannot hide switch or property usage', () {
    final target = basicDocument();
    final raw = Uint8List(2400)..[15] = 255;
    final clip = ChkDocumentTransfer.capture(transferSource(), triggers: {0});
    expect(
      () => clip.preview(transferPut(target, 'TRIG', raw)),
      throwsStateError,
    );
  });
  test(
    'simple objects need no strings or trigger closure and support independent sprites',
    () {
      final doc = transferPut(
        basicDocument(units: [basicUnit(id: 9)]),
        'THG2',
        (ByteData(10)
              ..setUint16(0, 130, Endian.little)
              ..setUint16(2, 128, Endian.little)
              ..setUint16(4, 128, Endian.little)
              ..setUint16(8, 4096, Endian.little))
            .buffer
            .asUint8List(),
      );
      final clip = ChkDocumentTransfer.capture(
        doc,
        selected: {
          'UNIT': {0},
          'THG2': {0},
        },
      );
      final plan = clip.preview(basicDocument());
      expect(plan.strings, isEmpty);
      expect(basicData(plan.result, 'THG2').getUint16(0, Endian.little), 130);
    },
  );
}
