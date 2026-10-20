import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

import '../../fixtures/doodad_deletion_fixture.dart';

DoodadPlacementRecipe _small({int group = 201}) =>
    deletionRecipe(doodadType: 9, startTileGroup: group);

void main() {
  test(
    'a nonmatching alternative footprint still participates in overlap checks',
    () {
      final doc = differentTypeNeighborDocument();
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborCandidates: {
            9: [_small(), wideNeighborRecipe()],
          },
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('footprints overlap'),
          ),
        ),
      );
    },
  );

  test(
    'one malformed alternative geometry rejects even with a matching candidate',
    () {
      final doc = candidateNeighborDocument();
      final unaligned = DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.badlands,
        startTileGroup: 201,
        doodadType: 9,
        width: 2,
        height: 1,
        centerOffsetX: 32,
        centerOffsetY: 16,
        footprint: [
          for (var x = 0; x < 2; x++)
            DoodadFootprintCell(
              x: x,
              y: 0,
              rawTileValue: 3216 + x,
              requiredTileGroup: 0,
            ),
        ],
      );
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborCandidates: {
            9: [_small(), unaligned],
          },
        ),
        throwsStateError,
      );
    },
  );
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    for (final batch in [false, true]) {
      test(
        'all compatible candidates $overlay batch=$batch preserve the neighbor',
        () {
          final doc = candidateNeighborDocument(batch: batch, overlay: overlay);
          final before = const RawChkEncoder().encode(doc);
          final candidates = {
            9: [_small(group: 202), _small(), wideNeighborRecipe()],
          };
          final plan = batch
              ? DoodadDeletionPlan.createBatch(
                  document: doc,
                  requests: batchDeletionRequests(overlay: overlay),
                  retainedNeighborCandidates: candidates,
                )
              : DoodadDeletionPlan.create(
                  document: doc,
                  recipe: deletionRecipe(overlay: overlay),
                  recordIndex: 0,
                  confirmedOverlayRecordIndex: overlay == null ? null : 1,
                  retainedNeighborCandidates: candidates,
                );
          var after = doc;
          for (final entry in plan.replacements.entries) {
            after = after.replaceSection(entry.key, entry.value);
          }
          expect(plan.preservedNeighborRecordIndices, {batch ? 3 : 2});
          expect(plan.doodadCount, batch ? 2 : 1);
          final dd = doc.sections.singleWhere((s) => s.name == 'DD2 ').payload;
          expect(after.sections.singleWhere((s) => s.name == 'DD2 ').payload, [
            ...dd.sublist(8, 16),
            ...dd.sublist(dd.length - 8),
          ]);
          final thg = doc.sections.singleWhere((s) => s.name == 'THG2').payload;
          expect(after.sections.singleWhere((s) => s.name == 'THG2').payload, [
            for (var i = 0; i < thg.length ~/ 10; i++)
              if (!(overlay != null && (i == 1 || (batch && i == 3))))
                ...thg.sublist(i * 10, (i + 1) * 10),
          ]);
          final tiles = doc.sections
              .singleWhere((s) => s.name == 'MTXM')
              .payload;
          final expected = ByteData.sublistView(tiles)
            ..setUint16(66, 1, Endian.little);
          if (batch) expected.setUint16(68, 1, Endian.little);
          expect(
            after.sections.singleWhere((s) => s.name == 'MTXM').payload,
            tiles,
          );
          for (var i = 0; i < doc.sections.length; i++) {
            if (!plan.replacements.containsKey(i)) {
              expect(after.sections[i], same(doc.sections[i]));
            }
          }
          expect(const RawChkEncoder().encode(doc), before);
        },
      );
    }
  }

  test('one possible overlapping footprint rejects both candidate orders', () {
    final doc = candidateNeighborDocument(disjoint: false);
    for (final values in [
      [_small(), wideNeighborRecipe()],
      [wideNeighborRecipe(), _small()],
    ]) {
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborCandidates: {9: values},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('footprints overlap'),
          ),
        ),
      );
    }
  });

  test(
    'empty, mismatching and wrong-tileset candidates cannot prove safety',
    () {
      final doc = candidateNeighborDocument();
      final wrong = DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.jungle,
        startTileGroup: 201,
        doodadType: 9,
        width: 1,
        height: 1,
        centerOffsetX: 16,
        centerOffsetY: 16,
        footprint: _small().footprint,
      );
      for (final values in [
        <DoodadPlacementRecipe>[],
        [_small(group: 202)],
        [_small(), wrong],
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(),
            recordIndex: 0,
            retainedNeighborCandidates: {9: values},
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
    },
  );

  test(
    '256 candidates succeed; infinite input stops at 257 across all types',
    () {
      final doc = candidateNeighborDocument();
      expect(
        DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborCandidates: {9: List.filled(256, _small())},
        ).preservedNeighborRecordIndices,
        {2},
      );
      var reads = 0;
      Iterable<DoodadPlacementRecipe> endless() sync* {
        while (true) {
          reads++;
          yield _small();
        }
      }

      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborRecipes: {7: deletionRecipe()},
          retainedNeighborCandidates: {9: endless()},
        ),
        throwsStateError,
      );
      expect(
        reads,
        256,
      ); // One legacy candidate and 256 iterable reads exceed 256.
      reads = 0;
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborCandidates: {9: endless()},
        ),
        throwsStateError,
      );
      expect(reads, 257);
    },
  );

  test(
    'duplicate sources, key/type mismatch and more than 32 types reject',
    () {
      final doc = candidateNeighborDocument();
      for (final values in [
        {
          8: [_small()],
        },
        {for (var i = 0; i < 33; i++) i: <DoodadPlacementRecipe>[]},
      ]) {
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(),
            recordIndex: 0,
            retainedNeighborCandidates: values,
          ),
          throwsStateError,
        );
      }
      expect(
        () => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborRecipes: {9: _small()},
          retainedNeighborCandidates: {
            9: [_small()],
          },
        ),
        throwsStateError,
      );
    },
  );

  test(
    'cell budget allows its exact boundary and caches across batch targets',
    () {
      final tall = DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.badlands,
        startTileGroup: 201,
        doodadType: 9,
        width: 1,
        height: 16,
        centerOffsetX: 16,
        centerOffsetY: 256,
        footprint: [
          for (var y = 0; y < 16; y++)
            DoodadFootprintCell(
              x: 0,
              y: y,
              rawTileValue: (201 + y) * 16,
              requiredTileGroup: 0,
            ),
        ],
      );
      for (final count in [64, 65]) {
        var doc = batchDeletionDocument();
        final ddAt = doc.sections.indexWhere((s) => s.name == 'DD2 ');
        final records = doc.sections[ddAt].payload.toList();
        final record = ByteData(8)
          ..setUint16(0, 9, Endian.little)
          ..setUint16(2, 112, Endian.little)
          ..setUint16(4, 288, Endian.little);
        for (var i = 0; i < count; i++) {
          records.addAll(record.buffer.asUint8List());
        }
        doc = doc.replaceSection(ddAt, doc.sections[ddAt].withPayload(records));
        final at = doc.sections.indexWhere((s) => s.name == 'MTXM');
        final bytes = doc.sections[at].payload;
        final data = ByteData.sublistView(bytes);
        for (var y = 0; y < 16; y++) {
          data.setUint16(((y + 1) * 32 + 3) * 2, (201 + y) * 16, Endian.little);
        }
        doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
        final before = const RawChkEncoder().encode(doc);
        DoodadDeletionPlan plan() => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
          retainedNeighborCandidates: {9: List.filled(256, tall)},
        );
        if (count == 64) {
          expect(plan().preservedNeighborRecordIndices, hasLength(64));
        } else {
          expect(
            plan,
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'reason',
                contains('candidate cell budget'),
              ),
            ),
          );
        }
        expect(const RawChkEncoder().encode(doc), before);
      }
    },
  );
}
