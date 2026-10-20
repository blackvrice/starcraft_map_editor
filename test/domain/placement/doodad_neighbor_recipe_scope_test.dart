import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

import '../../fixtures/doodad_deletion_fixture.dart';

RawChkDocument _neighbors(
  int count, {
  bool distinctTypes = false,
  bool distant = false,
}) {
  final doc = deletionDocument();
  final at = doc.sections.indexWhere((s) => s.name == 'DD2 ');
  final bytes = doc.sections[at].payload.toList();
  for (var i = 0; i < count; i++) {
    final record = ByteData(8)
      ..setUint16(0, distinctTypes ? 9 + i : 9, Endian.little)
      ..setUint16(2, distant ? 900 : 80, Endian.little)
      ..setUint16(4, distant ? 900 : 48, Endian.little);
    bytes.addAll(record.buffer.asUint8List());
  }
  return doc.replaceSection(at, doc.sections[at].withPayload(bytes));
}

Set<int> _scope(RawChkDocument doc, Iterable<int> indices) =>
    DoodadDeletionPlan.recipeLookupTypes(
      section: const ChkObjectViewDecoder().decode(doc).doodadSections.single,
      recordIndices: indices,
    );

void main() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    for (final batch in [false, true]) {
      test(
        'different neighbor $overlay batch=$batch is preserved byte-exactly',
        () {
          final doc = differentTypeNeighborDocument(
            batch: batch,
            overlay: overlay,
          );
          final before = const RawChkEncoder().encode(doc);
          final recipes = {
            9: deletionRecipe(
              overlay: overlay,
              doodadType: 9,
              startTileGroup: 201,
              overlayId: 101,
            ),
          };
          final plan = batch
              ? DoodadDeletionPlan.createBatch(
                  document: doc,
                  requests: batchDeletionRequests(overlay: overlay),
                  retainedNeighborRecipes: recipes,
                )
              : DoodadDeletionPlan.create(
                  document: doc,
                  recipe: deletionRecipe(overlay: overlay),
                  recordIndex: 0,
                  confirmedOverlayRecordIndex: overlay == null ? null : 1,
                  retainedNeighborRecipes: recipes,
                );
          var after = doc;
          for (final entry in plan.replacements.entries) {
            after = after.replaceSection(entry.key, entry.value);
          }
          expect(plan.doodadCount, batch ? 2 : 1);
          expect(plan.preservedNeighborRecordIndices, {batch ? 3 : 2});
          final removedDD = {0, if (batch) 2};
          final removedTHG = {
            if (overlay != null) 1,
            if (overlay != null && batch) 3,
          };
          for (final (name, width, removed) in [
            ('DD2 ', 8, removedDD),
            ('THG2', 10, removedTHG),
          ]) {
            final original = doc.sections
                .singleWhere((s) => s.name == name)
                .payload;
            expect(after.sections.singleWhere((s) => s.name == name).payload, [
              for (var i = 0; i < original.length ~/ width; i++)
                if (!removed.contains(i))
                  ...original.sublist(i * width, (i + 1) * width),
            ]);
          }
          final values = const ChkTerrainViewDecoder()
              .decode(after)
              .tileMaps
              .single
              .rawTileValues;
          expect(values[33], 1);
          if (batch) {
            expect(values[34], 1);
          }
          expect(values[batch ? 35 : 34], 3216);
          for (var i = 0; i < doc.sections.length; i++) {
            if (!plan.replacements.containsKey(i)) {
              expect(after.sections[i], same(doc.sections[i]));
            }
          }
          expect(const RawChkEncoder().encode(doc), before);
          expect(_scope(doc, [0, if (batch) 2]), {7, 9});
        },
      );
    }
  }

  test(
    'maximum envelopes include possible edge intersections, not touching edges',
    () {
      final base = differentTypeNeighborDocument();
      final at = base.sections.indexWhere((s) => s.name == 'DD2 ');
      for (final (x, y, included) in [
        (559, 48, true),
        (560, 48, false),
        (48, 559, true),
        (48, 560, false),
        (559, 559, true),
      ]) {
        final bytes = base.sections[at].payload;
        ByteData.sublistView(bytes)
          ..setUint16(18, x, Endian.little)
          ..setUint16(20, y, Endian.little);
        final doc = base.replaceSection(
          at,
          base.sections[at].withPayload(bytes),
        );
        expect(_scope(doc, [0]), {7, if (included) 9});
      }
    },
  );

  test(
    '32 total types succeed, 33 fall back without dropping selected types',
    () {
      expect(_scope(_neighbors(31, distinctTypes: true), [0]), hasLength(32));
      final fallback = _scope(_neighbors(32, distinctTypes: true), [0]);
      expect(fallback, {7});
      expect(() => fallback.clear(), throwsUnsupportedError);
      expect(
        () => DoodadDeletionPlan.create(
          document: _neighbors(32, distinctTypes: true),
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborRecipes: {7: deletionRecipe()},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            contains('ownership is ambiguous'),
          ),
        ),
      );
      final doc = _neighbors(32, distinctTypes: true);
      final selected = List.generate(32, (i) => i + 2);
      // The original type 7 would add a 33rd type, so all selected types remain.
      expect(_scope(doc, selected), {for (var i = 0; i < 32; i++) 9 + i});
    },
  );

  test(
    '256 neighbors succeed, 257 fall back; distant raw records spend no budget',
    () {
      expect(_scope(_neighbors(256), [0]), {7, 9});
      expect(_scope(_neighbors(257), [0]), {7});
      expect(_scope(_neighbors(300, distant: true), [0]), {7});
    },
  );

  test('lookup selection is bounded and never changes the source', () {
    final doc = differentTypeNeighborDocument();
    final before = const RawChkEncoder().encode(doc);
    for (final indices in [
      <int>[],
      [0, 0],
      [-1],
      [3],
    ]) {
      expect(() => _scope(doc, indices), throwsStateError);
    }
    var reads = 0;
    Iterable<int> endless() sync* {
      while (true) {
        reads++;
        yield 0;
      }
    }

    expect(() => _scope(doc, endless()), throwsStateError);
    expect(reads, 33);
    expect(_scope(doc, [0]), {7, 9});
    expect(const RawChkEncoder().encode(doc), before);
  });

  test(
    'lookup never authorizes invalid retained state, terrain or overlap',
    () {
      final base = differentTypeNeighborDocument();
      for (final failure in ['state', 'terrain', 'overlap']) {
        final name = failure == 'terrain' ? 'MTXM' : 'DD2 ';
        final at = base.sections.indexWhere((s) => s.name == name);
        final bytes = base.sections[at].payload;
        final data = ByteData.sublistView(bytes);
        switch (failure) {
          case 'state':
            data.setUint8(23, 255);
          case 'terrain':
            data.setUint16(68, 1, Endian.little);
          case 'overlap':
            data.setUint16(18, 48, Endian.little);
        }
        final doc = base.replaceSection(
          at,
          base.sections[at].withPayload(bytes),
        );
        expect(_scope(doc, [0]), {7, 9});
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(),
            recordIndex: 0,
            retainedNeighborRecipes: {
              9: deletionRecipe(
                doodadType: 9,
                startTileGroup: failure == 'overlap' ? 200 : 201,
              ),
            },
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
    },
  );

  test('neighbor recipe map has the same 32-type budget', () {
    final doc = differentTypeNeighborDocument();
    expect(
      () => DoodadDeletionPlan.create(
        document: doc,
        recipe: deletionRecipe(),
        recordIndex: 0,
        retainedNeighborRecipes: {
          for (var type = 0; type < 33; type++)
            type: deletionRecipe(doodadType: type),
        },
      ),
      throwsStateError,
    );
  });
}
