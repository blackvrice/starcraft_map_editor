import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/placement/location_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import '../../fixtures/doodad_deletion_fixture.dart';

RawChkDocument _replace(RawChkDocument doc, String name, List<int> bytes) {
  final at = doc.sections.indexWhere((s) => s.name == name);
  return doc.replaceSection(at, doc.sections[at].withPayload(bytes));
}

ChkTrigger _reference(
  RawChkDocument doc, {
  bool action = false,
  bool destination = false,
  bool disabled = false,
  int location = 1,
}) {
  final op = action
      ? TriggerOpcodes.actions.singleWhere(
          (o) => o.id == (destination ? 39 : 10),
        )
      : TriggerOpcodes.conditions.singleWhere((o) => o.id == 3);
  final values = {
    for (final a in op.arguments)
      a.name: a.reference == 'location'
          ? (destination && a.offset == 0 ? 2 : location)
          : a.choices.isNotEmpty
          ? a.choices.keys.first
          : 0,
  };
  var record = ChkTrigger.create().withSlot(
    action,
    0,
    ChkTrigger.makeSlot(action, op, values, doc),
  );
  if (disabled) {
    record = record.withSlotEnabled(action, 0, false).withEnabled(false);
  }
  return record;
}

void main() {
  for (final count in [64, 255]) {
    test(
      'Location clearing preserves $count IDs, shared strings and every other byte',
      () {
        var doc = doodadLocationDeletionDocument();
        final at = doc.sections.indexWhere((s) => s.name == 'MRGN');
        doc = _replace(
          doc,
          'MRGN',
          doc.sections[at].payload.take(count * 20).toList(),
        );
        final before = const RawChkEncoder().encode(doc);
        final selected = count == 64 ? [1, 0] : [254, 0];
        final plan = LocationDeletionPlan.create(
          document: doc,
          recordIndices: selected,
        );
        final expected = doc.sections[at].payload;
        for (final index in selected) {
          expected.fillRange(index * 20, (index + 1) * 20, 0);
        }
        expect(plan.document, same(doc));
        expect(plan.replacement.payload, expected);
        expect(plan.replacement.declaredLength, count * 20);
        expect(() => plan.recordIndices.clear(), throwsUnsupportedError);
        final after = doc.replaceSection(plan.sectionIndex, plan.replacement);
        for (var i = 0; i < doc.sections.length; i++) {
          if (i != at) {
            expect(after.sections[i], same(doc.sections[i]));
          }
        }
        expect(const RawChkEncoder().encode(doc), before);
      },
    );
  }
  for (final kind in ['condition', 'action', 'destination']) {
    for (final disabled in [false, true]) {
      test(
        'Location referenced by $kind disabled=$disabled cannot be cleared',
        () {
          final base = doodadLocationDeletionDocument();
          final record = _reference(
            base,
            action: kind != 'condition',
            destination: kind == 'destination',
            disabled: disabled,
          );
          final doc = _replace(base, 'TRIG', record.bytes);
          final before = const RawChkEncoder().encode(doc);
          expect(
            () =>
                LocationDeletionPlan.create(document: doc, recordIndices: [0]),
            throwsStateError,
          );
          expect(const RawChkEncoder().encode(doc), before);
        },
      );
    }
  }
  test(
    'Unrelated canonical references and ordinary briefings remain byte-exact',
    () {
      var doc = doodadLocationDeletionDocument();
      doc = _replace(doc, 'TRIG', _reference(doc, location: 2).bytes);
      final op = TriggerOpcodes.briefingActions.first;
      final briefing = ChkTrigger.create(briefing: true).withSlot(
        true,
        0,
        ChkTrigger.makeSlot(
          true,
          op,
          {'Duration (ms)': 50},
          doc,
          briefing: true,
        ),
      );
      doc = _replace(doc, 'MBRF', briefing.bytes);
      final plan = LocationDeletionPlan.create(
        document: doc,
        recordIndices: [0],
      );
      expect(plan.replacement.payload.take(20), everyElement(0));
      final after = doc.replaceSection(plan.sectionIndex, plan.replacement);
      for (final name in ['TRIG', 'MBRF', 'STR ']) {
        expect(
          after.sections.singleWhere((s) => s.name == name),
          same(doc.sections.singleWhere((s) => s.name == name)),
        );
      }
    },
  );
  for (final fault in [
    'opcode',
    'eudx',
    'eud-deaths',
    'reserved-slot',
    'record-flags',
    'owner',
    'briefing-marker',
  ]) {
    test('Opaque $fault prevents a false unreferenced claim', () {
      final base = doodadLocationDeletionDocument();
      final briefing = fault == 'briefing-marker';
      final bytes = Uint8List.fromList(
        ChkTrigger.create(briefing: briefing).bytes,
      );
      switch (fault) {
        case 'opcode':
          bytes[15] = 255;
        case 'eudx':
          bytes[18] = 0x53;
        case 'eud-deaths':
          bytes[15] = 15;
          ByteData.sublistView(bytes).setUint16(12, 228, Endian.little);
        case 'reserved-slot':
          bytes[0] = 1;
        case 'record-flags':
          bytes[2368] = 1;
        case 'owner':
          bytes[2372] = 2;
        case 'briefing-marker':
          bytes[0] = 1;
      }
      final doc = _replace(base, briefing ? 'MBRF' : 'TRIG', bytes);
      final before = const RawChkEncoder().encode(doc);
      expect(
        () => LocationDeletionPlan.create(document: doc, recordIndices: [0]),
        throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
      );
      expect(const RawChkEncoder().encode(doc), before);
    });
  }
  test(
    'Missing duplicate truncated sections and blank/Anywhere/invalid indices fail closed',
    () {
      final base = doodadLocationDeletionDocument();
      for (final name in ['MRGN', 'TRIG', 'MBRF']) {
        final section = base.sections.singleWhere((s) => s.name == name);
        for (final doc in [
          if (name != 'MBRF')
            RawChkDocument(
              sections: base.sections.where((s) => s.name != name).toList(),
              sourceLength: base.sourceLength,
            ),
          base.appendSection(section),
          _replace(base, name, [...section.payload, 255]),
        ]) {
          final before = const RawChkEncoder().encode(doc);
          expect(
            () =>
                LocationDeletionPlan.create(document: doc, recordIndices: [0]),
            throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
          );
          expect(const RawChkEncoder().encode(doc), before);
        }
      }
      for (final indices in [
        <int>[],
        [-1],
        [255],
        [0, 0],
        [2],
        [63],
      ]) {
        expect(
          () => LocationDeletionPlan.create(
            document: base,
            recordIndices: indices,
          ),
          throwsStateError,
        );
      }
    },
  );
  test('254 slots succeed, input stops at 255, trigger scan is bounded', () {
    var doc = doodadLocationDeletionDocument();
    final bytes = doc.sections.singleWhere((s) => s.name == 'MRGN').payload;
    for (var i = 0; i < 255; i++) {
      if (i != 63) {
        bytes[i * 20] = 1;
      }
    }
    doc = _replace(doc, 'MRGN', bytes);
    final plan = LocationDeletionPlan.create(
      document: doc,
      recordIndices: [
        for (var i = 0; i < 255; i++)
          if (i != 63) i,
      ],
    );
    expect(plan.recordIndices.length, 254);
    expect(
      plan.replacement.payload.sublist(63 * 20, 64 * 20),
      bytes.sublist(63 * 20, 64 * 20),
    );
    var reads = 0;
    Iterable<int> endless() sync* {
      while (true) {
        reads++;
        yield 0;
      }
    }

    expect(
      () =>
          LocationDeletionPlan.create(document: doc, recordIndices: endless()),
      throwsStateError,
    );
    expect(reads, 255);
    final large = _replace(doc, 'TRIG', Uint8List(4097 * 2400));
    expect(
      () => LocationDeletionPlan.create(document: large, recordIndices: [0]),
      throwsStateError,
    );
  });
  test('Composite location clearing requires the exact confirmed slot set', () {
    final doc = doodadLocationDeletionDocument(batch: true, units: true);
    final before = const RawChkEncoder().encode(doc);
    final plan = DoodadDeletionPlan.createBatch(
      document: doc,
      requests: batchDeletionRequests(),
      selectedLocationRecordIndices: [0],
      confirmedLocationRecordIndices: [0],
      selectedUnitRecordIndices: [0],
      confirmedUnitPeerRecordIndices: [1],
      selectedSpriteRecordIndices: [0],
    );
    expect(plan.replacements.values.map((s) => s.name).toSet(), {
      'MRGN',
      'UNIT',
      'MTXM',
      'DD2 ',
      'THG2',
    });
    for (final confirmed in [
      <int>[],
      [1],
      [0, 0],
      List.filled(255, 0),
    ]) {
      expect(
        () => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
          selectedLocationRecordIndices: [0],
          confirmedLocationRecordIndices: confirmed,
        ),
        throwsStateError,
      );
    }
    expect(const RawChkEncoder().encode(doc), before);
  });
}
