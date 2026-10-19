import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/unit_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import '../../fixtures/basic_editing_fixture.dart';
import '../../fixtures/doodad_deletion_fixture.dart';

void main() {
  for (final nydus in [false, true]) {
    for (final both in [false, true]) {
      test(
        'unit deletion nydus=$nydus both=$both preserves all but verified peer links',
        () {
          final doc = doodadUnitDeletionDocument(nydus: nydus);
          final before = const RawChkEncoder().encode(doc);
          final original = doc.sections
              .singleWhere((s) => s.name == 'UNIT')
              .payload;
          final plan = UnitDeletionPlan.create(
            document: doc,
            recordIndices: both ? [1, 0] : [0],
          );
          final expected = Uint8List.fromList(original.sublist(both ? 72 : 36));
          if (!both) {
            ByteData.sublistView(expected)
              ..setUint16(10, 0, Endian.little)
              ..setUint32(32, 0, Endian.little);
          }
          expect(plan.document, same(doc));
          expect(plan.replacement.payload, expected);
          expect(plan.unitCount, both ? 2 : 1);
          expect(plan.unlinkedPeerRecordIndices, both ? isEmpty : {1});
          expect(
            () => plan.unlinkedPeerRecordIndices.clear(),
            throwsUnsupportedError,
          );
          expect(const RawChkEncoder().encode(doc), before);
        },
      );
    }
  }
  test('unrelated malformed relations are preserved rather than normalized', () {
    var doc = doodadUnitDeletionDocument();
    final at = doc.sections.indexWhere((s) => s.name == 'UNIT');
    final bytes = doc.sections[at].payload;
    ByteData.sublistView(bytes)
      ..setUint16(82, 0x1234, Endian.little)
      ..setUint32(104, 999, Endian.little);
    doc = doc.replaceSection(
      at,
      doc.sections[at].withPayload([...bytes, ...basicUnit(id: 14)]),
    );
    final plan = UnitDeletionPlan.create(document: doc, recordIndices: [3]);
    expect(plan.replacement.payload, bytes);
    expect(plan.unlinkedPeerRecordIndices, isEmpty);
    // Deleting an unrelated plain unit must not inspect or rewrite another pair.
    final clean = doodadUnitDeletionDocument();
    final unrelated = UnitDeletionPlan.create(
      document: clean,
      recordIndices: [2],
    );
    expect(
      unrelated.replacement.payload,
      clean.sections[at].payload.sublist(0, 72),
    );
  });
  for (final fault in [
    'flags',
    'missing-peer',
    'duplicate-own',
    'duplicate-peer',
    'third-incoming',
    'one-way',
    'incoming-flags',
  ]) {
    test('unit deletion rejects $fault without clearing any relationship', () {
      var doc = doodadUnitDeletionDocument();
      final at = doc.sections.indexWhere((s) => s.name == 'UNIT');
      final bytes = doc.sections[at].payload;
      final data = ByteData.sublistView(bytes);
      switch (fault) {
        case 'flags':
          data.setUint16(10, 0x1234, Endian.little);
        case 'missing-peer':
          data.setUint32(32, 999, Endian.little);
        case 'duplicate-own':
          data.setUint32(72, 11, Endian.little);
        case 'duplicate-peer':
          data.setUint32(72, 12, Endian.little);
        case 'third-incoming':
          data
            ..setUint16(82, 0x400, Endian.little)
            ..setUint32(104, 11, Endian.little);
        case 'one-way':
          data
            ..setUint16(10, 0, Endian.little)
            ..setUint32(32, 0, Endian.little);
        case 'incoming-flags':
          data
            ..setUint16(10, 0, Endian.little)
            ..setUint32(32, 0, Endian.little)
            ..setUint16(46, 0x1234, Endian.little);
      }
      doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
      final before = const RawChkEncoder().encode(doc);
      expect(
        () => UnitDeletionPlan.create(document: doc, recordIndices: [0]),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), before);
    });
  }
  test(
    'missing duplicate truncated UNIT and invalid selections are rejected',
    () {
      final base = doodadUnitDeletionDocument();
      final at = base.sections.indexWhere((s) => s.name == 'UNIT');
      for (final doc in [
        RawChkDocument(
          sections: base.sections.where((s) => s.name != 'UNIT').toList(),
          sourceLength: base.sourceLength,
        ),
        base.appendSection(base.sections[at]),
        base.replaceSection(
          at,
          base.sections[at].withPayload([...base.sections[at].payload, 255]),
        ),
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => UnitDeletionPlan.create(document: doc, recordIndices: [0]),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
      for (final indices in [
        <int>[],
        [-1],
        [3],
        [0, 0],
        List.filled(257, 0),
      ]) {
        expect(
          () => UnitDeletionPlan.create(document: base, recordIndices: indices),
          throwsStateError,
        );
      }
    },
  );
  test(
    '256 plain units are supported and infinite input is read only 257 times',
    () {
      final doc = basicDocument(
        units: List.generate(256, (i) => basicUnit(id: i + 1)),
      );
      final plan = UnitDeletionPlan.create(
        document: doc,
        recordIndices: List.generate(256, (i) => i),
      );
      expect(plan.unitCount, 256);
      expect(plan.replacement.payload, isEmpty);
      var reads = 0;
      Iterable<int> endless() sync* {
        while (true) {
          reads++;
          yield 0;
        }
      }

      expect(
        () => UnitDeletionPlan.create(document: doc, recordIndices: endless()),
        throwsStateError,
      );
      expect(reads, 257);
    },
  );
  test(
    'composite deletion combines original UNIT MTXM DD2 THG2 as one immutable plan',
    () {
      final doc = doodadUnitDeletionDocument(batch: true);
      final before = const RawChkEncoder().encode(doc);
      final plan = DoodadDeletionPlan.createBatch(
        document: doc,
        requests: batchDeletionRequests(),
        selectedUnitRecordIndices: [0],
        confirmedUnitPeerRecordIndices: [1],
        selectedSpriteRecordIndices: [0],
      );
      expect(plan.unitDeletion!.unlinkedPeerRecordIndices, {1});
      expect(plan.unitDeletion!.unitCount, 1);
      expect(plan.replacements.values.map((s) => s.name).toSet(), {
        'UNIT',
        'MTXM',
        'DD2 ',
        'THG2',
      });
      expect(const RawChkEncoder().encode(doc), before);
      for (final peers in [
        <int>[],
        [2],
        [1, 1],
        List.filled(257, 1),
      ]) {
        expect(
          () => DoodadDeletionPlan.createBatch(
            document: doc,
            requests: batchDeletionRequests(),
            selectedUnitRecordIndices: [0],
            confirmedUnitPeerRecordIndices: peers,
          ),
          throwsStateError,
        );
      }
      expect(const RawChkEncoder().encode(doc), before);
      expect(
        () => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
          selectedUnitRecordIndices: [999],
          selectedSpriteRecordIndices: [0],
        ),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), before);
    },
  );
}
