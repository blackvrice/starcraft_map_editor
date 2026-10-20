import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

import '../../fixtures/doodad_deletion_fixture.dart';

void main() {
  test(
    'full-size 32-member preparation preserves source and unrelated bytes',
    () {
      final doc = largeBatchDeletionDocument();
      final before = const RawChkEncoder().encode(doc);
      final requests = batchDeletionRequests(count: 32);
      final plan = DoodadDeletionPlan.createBatch(
        document: doc,
        requests: requests.reversed,
      );
      expect(plan.document, same(doc));
      expect(plan.doodadCount, 32);
      var after = doc;
      for (final entry in plan.replacements.entries) {
        after = after.replaceSection(entry.key, entry.value);
      }
      expect(
        const ChkTerrainViewDecoder()
            .decode(after)
            .tileMaps
            .single
            .rawTileValues,
        everyElement(1),
      );
      expect(
        after.sections.singleWhere((s) => s.name == 'DD2 ').payload,
        doc.sections
            .singleWhere((s) => s.name == 'DD2 ')
            .payload
            .sublist(8, 16),
      );
      for (var i = 0; i < doc.sections.length; i++) {
        if (!plan.replacements.containsKey(i)) {
          expect(after.sections[i], same(doc.sections[i]));
        }
      }
      expect(const RawChkEncoder().encode(doc), before);
    },
  );

  test('later recipe still validates tileset against shared source', () {
    final doc = batchDeletionDocument();
    final requests = batchDeletionRequests();
    final wrong = deletionRecipe();
    final badRecipe = DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.jungle,
      startTileGroup: wrong.startTileGroup,
      doodadType: wrong.doodadType,
      width: wrong.width,
      height: wrong.height,
      centerOffsetX: wrong.centerOffsetX,
      centerOffsetY: wrong.centerOffsetY,
      footprint: wrong.footprint,
    );
    final before = const RawChkEncoder().encode(doc);
    expect(
      () => DoodadDeletionPlan.createBatch(
        document: doc,
        requests: [
          requests.first,
          DoodadDeletionRequest(recipe: badRecipe, recordIndex: 2),
        ],
      ),
      throwsStateError,
    );
    expect(const RawChkEncoder().encode(doc), before);
  });

  test(
    'source context never leaks TILE values across separate preparations',
    () {
      final original = batchDeletionDocument();
      final at = original.sections.indexWhere((s) => s.name == 'TILE');
      final bytes = original.sections[at].payload;
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i < bytes.length; i += 2) {
        data.setUint16(i, 2, Endian.little);
      }
      final changed = original.replaceSection(
        at,
        original.sections[at].withPayload(bytes),
      );
      for (final (doc, expected) in [
        (original, 1),
        (changed, 2),
        (original, 1),
      ]) {
        final plan = DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
        );
        final terrainAt = doc.sections.indexWhere((s) => s.name == 'MTXM');
        final result = ByteData.sublistView(
          plan.replacements[terrainAt]!.payload,
        );
        expect(result.getUint16(33 * 2, Endian.little), expected);
        expect(result.getUint16(34 * 2, Endian.little), expected);
      }
      expect(original.sections[at].payload, everyElement(isIn([0, 1])));
    },
  );

  for (final name in ['DIM ', 'ERA ', 'MTXM', 'DD2 ', 'TILE']) {
    test('shared source rejects duplicate $name without modifying input', () {
      final original = batchDeletionDocument();
      final doc = original.appendSection(
        original.sections.singleWhere((s) => s.name == name),
      );
      final before = const RawChkEncoder().encode(doc);
      expect(
        () => DoodadDeletionPlan.createBatch(
          document: doc,
          requests: batchDeletionRequests(),
        ),
        throwsStateError,
      );
      expect(const RawChkEncoder().encode(doc), before);
    });
  }

  test('no-overlay source does not require an unused THG2 section', () {
    final original = batchDeletionDocument();
    final doc = RawChkDocument(
      sections: original.sections.where((s) => s.name != 'THG2').toList(),
      sourceLength: original.sourceLength,
    );
    expect(
      DoodadDeletionPlan.createBatch(
        document: doc,
        requests: batchDeletionRequests(),
      ).spriteCount,
      0,
    );
  });
}
