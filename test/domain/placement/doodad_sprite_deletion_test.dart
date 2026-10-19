import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import '../../fixtures/doodad_deletion_fixture.dart';

void main() {
  for (final batch in [false, true]) {
    for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
      test(
        'mixed sprites batch=$batch overlay=$overlay use original indices once',
        () {
          final doc = batch
              ? batchDeletionDocument(overlay: overlay)
              : deletionDocument(overlay: overlay);
          final before = const RawChkEncoder().encode(doc);
          final requests = batch
              ? batchDeletionRequests(overlay: overlay)
              : [
                  DoodadDeletionRequest(
                    recipe: deletionRecipe(overlay: overlay),
                    recordIndex: 0,
                    confirmedOverlayRecordIndex: overlay == null ? null : 1,
                  ),
                ];
          final selected = [0, 1, if (batch && overlay != null) 3];
          final deleted = {...selected, if (batch && overlay != null) 3};
          final plan = DoodadDeletionPlan.createBatch(
            document: doc,
            requests: requests.reversed,
            selectedSpriteRecordIndices: selected.reversed,
          );
          expect(plan.spriteCount, deleted.length);
          expect(
            plan.overlayCount,
            overlay == null
                ? 0
                : batch
                ? 2
                : 1,
          );
          var after = doc;
          for (final entry in plan.replacements.entries) {
            after = after.replaceSection(entry.key, entry.value);
          }
          final original = doc.sections
              .singleWhere((s) => s.name == 'THG2')
              .payload;
          expect(after.sections.singleWhere((s) => s.name == 'THG2').payload, [
            for (var i = 0; i < original.length ~/ 10; i++)
              if (!deleted.contains(i))
                ...original.sublist(i * 10, (i + 1) * 10),
          ]);
          expect(
            const ChkTerrainViewDecoder()
                .decode(after)
                .tileMaps
                .single
                .rawTileValues,
            everyElement(1),
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

  test(
    'selected sprite never substitutes for explicit overlay confirmation',
    () {
      final doc = deletionDocument(overlay: DoodadOverlaySemantic.spriteUnit);
      expect(
        () => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: [
            DoodadDeletionRequest(
              recipe: deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit),
              recordIndex: 0,
            ),
          ],
          selectedSpriteRecordIndices: [1],
        ),
        throwsStateError,
      );
    },
  );

  test('invalid sprite requests reject all terrain and object changes', () {
    final doc = batchDeletionDocument();
    final before = const RawChkEncoder().encode(doc);
    for (final indices in [
      [-1],
      [3],
      [0, 0],
      List.filled(257, 0),
    ]) {
      expect(
        () => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
          selectedSpriteRecordIndices: indices,
        ),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), before);
    }
    final badRequests = [
      ...batchDeletionRequests().take(1),
      DoodadDeletionRequest(recipe: deletionRecipe(), recordIndex: 999),
    ];
    expect(
      () => DoodadDeletionPlan.createBatch(
        document: doc,
        requests: badRequests,
        selectedSpriteRecordIndices: [0],
      ),
      throwsStateError,
    );
    expect(const RawChkEncoder().encode(doc), before);
  });

  test(
    'missing duplicate and truncated THG2 are never normalized by mixed deletion',
    () {
      final base = batchDeletionDocument();
      final at = base.sections.indexWhere((s) => s.name == 'THG2');
      final sprites = base.sections[at];
      for (final doc in [
        RawChkDocument(
          sections: base.sections.where((s) => s.name != 'THG2').toList(),
          sourceLength: base.sourceLength,
        ),
        base.appendSection(sprites),
        base.replaceSection(at, sprites.withPayload([...sprites.payload, 255])),
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.createBatch(
            document: doc,
            requests: batchDeletionRequests(),
            selectedSpriteRecordIndices: [0],
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
    },
  );

  test('256 selected sprites work and unbounded input stops at 257', () {
    var doc = batchDeletionDocument();
    final at = doc.sections.indexWhere((s) => s.name == 'THG2');
    final bytes = Uint8List(256 * 10);
    doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
    final plan = DoodadDeletionPlan.createBatch(
      document: doc,
      requests: batchDeletionRequests(),
      selectedSpriteRecordIndices: List.generate(256, (i) => i),
    );
    expect(plan.spriteCount, 256);
    expect(plan.replacements[at]!.payload, isEmpty);
    var reads = 0;
    Iterable<int> endless() sync* {
      while (true) {
        reads++;
        yield 0;
      }
    }

    expect(
      () => DoodadDeletionPlan.createBatch(
        document: doc,
        requests: batchDeletionRequests(),
        selectedSpriteRecordIndices: endless(),
      ),
      throwsStateError,
    );
    expect(reads, 257);
  });
}
