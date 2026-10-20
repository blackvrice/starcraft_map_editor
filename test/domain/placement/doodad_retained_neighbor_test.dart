import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';

import '../../fixtures/doodad_deletion_fixture.dart';

RawChkDocument _patch(
  RawChkDocument doc,
  String name,
  List<int> Function(Uint8List) change,
) {
  final at = doc.sections.indexWhere((s) => s.name == name);
  return doc.replaceSection(
    at,
    doc.sections[at].withPayload(change(doc.sections[at].payload)),
  );
}

RawChkDocument _apply(DoodadDeletionPlan plan) {
  var result = plan.document;
  for (final entry in plan.replacements.entries) {
    result = result.replaceSection(entry.key, entry.value);
  }
  return result;
}

void main() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    for (final batch in [false, true]) {
      test('$overlay batch=$batch preserves a verified adjacent neighbor', () {
        final doc = batchDeletionDocument(
          count: batch ? 3 : 2,
          overlay: overlay,
        );
        final before = const RawChkEncoder().encode(doc);
        final recipe = deletionRecipe(overlay: overlay);
        final plan = batch
            ? DoodadDeletionPlan.createBatch(
                document: doc,
                requests: batchDeletionRequests(count: 2, overlay: overlay),
                retainedNeighborRecipes: {7: recipe},
              )
            : DoodadDeletionPlan.create(
                document: doc,
                recipe: recipe,
                recordIndex: 0,
                confirmedOverlayRecordIndex: overlay == null ? null : 1,
                retainedNeighborRecipes: {7: recipe},
              );
        final retained = batch ? 3 : 2;
        expect(plan.preservedNeighborRecordIndices, {retained});
        expect(
          () => plan.preservedNeighborRecordIndices.clear(),
          throwsUnsupportedError,
        );
        final result = _apply(plan);
        final dd = doc.sections.singleWhere((s) => s.name == 'DD2 ').payload;
        expect(result.sections.singleWhere((s) => s.name == 'DD2 ').payload, [
          ...dd.sublist(8, 16),
          ...dd.sublist(retained * 8, retained * 8 + 8),
        ]);
        if (overlay != null) {
          final originalIndex = batch ? 4 : 3;
          final original = doc.sections
              .singleWhere((s) => s.name == 'THG2')
              .payload;
          final after = result.sections
              .singleWhere((s) => s.name == 'THG2')
              .payload;
          expect(
            after.sublist(after.length - 10),
            original.sublist(originalIndex * 10, originalIndex * 10 + 10),
          );
        } else {
          expect(
            result.sections.singleWhere((s) => s.name == 'THG2').payload,
            doc.sections.singleWhere((s) => s.name == 'THG2').payload,
          );
        }
        final values = const ChkTerrainViewDecoder()
            .decode(result)
            .tileMaps
            .single
            .rawTileValues;
        expect(values[33], 1);
        if (batch) expect(values[34], 1);
        expect(values[batch ? 35 : 34], 3200);
        expect(const RawChkEncoder().encode(doc), before);
        for (var i = 0; i < doc.sections.length; i++) {
          if (!plan.replacements.containsKey(i)) {
            expect(result.sections[i], same(doc.sections[i]));
          }
        }
      });
    }
  }

  test(
    'unverified, overlapping and invalid neighbors reject without mutation',
    () {
      final base = batchDeletionDocument();
      RawChkDocument dd(void Function(ByteData) change) =>
          _patch(base, 'DD2 ', (bytes) {
            change(ByteData.sublistView(bytes));
            return bytes;
          });
      final badTerrain = _patch(base, 'MTXM', (bytes) {
        ByteData.sublistView(bytes).setUint16(68, 1, Endian.little);
        return bytes;
      });
      for (final doc in [
        dd((b) => b.setUint8(23, 255)),
        dd((b) => b.setUint16(16, 8, Endian.little)),
        dd((b) => b.setUint16(18, 81, Endian.little)),
        dd((b) => b.setUint16(18, 48, Endian.little)),
        dd((b) => b.setUint16(18, 0, Endian.little)),
        badTerrain,
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(),
            recordIndex: 0,
            retainedNeighborRecipes: {7: deletionRecipe()},
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
      expect(
        () => DoodadDeletionPlan.create(
          document: base,
          recipe: deletionRecipe(),
          recordIndex: 0,
        ),
        throwsStateError,
      );
    },
  );

  test('a nearby retained footprint outside the map is rejected', () {
    var doc = _patch(batchDeletionDocument(), 'DD2 ', (bytes) {
      ByteData.sublistView(bytes)
        ..setUint16(2, 1008, Endian.little)
        ..setUint16(18, 1040, Endian.little);
      return bytes;
    });
    doc = _patch(doc, 'MTXM', (bytes) {
      ByteData.sublistView(bytes).setUint16(126, 3200, Endian.little);
      return bytes;
    });
    expect(
      () => DoodadDeletionPlan.create(
        document: doc,
        recipe: deletionRecipe(),
        recordIndex: 0,
        retainedNeighborRecipes: {7: deletionRecipe()},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          contains('retained neighbor'),
        ),
      ),
    );
  });

  test('transparent cells do not permit overlapping whole footprints', () {
    final doc = _patch(batchDeletionDocument(), 'MTXM', (bytes) {
      ByteData.sublistView(bytes).setUint16(68, 3201, Endian.little);
      return bytes;
    });
    final wide = DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.badlands,
      startTileGroup: 200,
      doodadType: 7,
      width: 3,
      height: 1,
      centerOffsetX: 48,
      centerOffsetY: 16,
      footprint: [
        for (var x = 0; x < 3; x++)
          DoodadFootprintCell(
            x: x,
            y: 0,
            rawTileValue: x == 1 ? 3201 : null,
            requiredTileGroup: 0,
          ),
      ],
    );
    expect(
      () => DoodadDeletionPlan.create(
        document: doc,
        recipe: deletionRecipe(),
        recordIndex: 0,
        retainedNeighborRecipes: {7: wide},
      ),
      throwsStateError,
    );
  });

  test(
    'recipe types and tilesets cannot widen the retained-neighbor scope',
    () {
      final base = deletionRecipe();
      final wrongTileset = DoodadPlacementRecipe(
        tileset: StarCraftTilesetAssetSet.jungle,
        startTileGroup: base.startTileGroup,
        doodadType: base.doodadType,
        width: base.width,
        height: base.height,
        centerOffsetX: base.centerOffsetX,
        centerOffsetY: base.centerOffsetY,
        footprint: base.footprint,
      );
      for (final recipes in [
        {8: base},
        {7: wrongTileset},
      ]) {
        expect(
          () => DoodadDeletionPlan.create(
            document: batchDeletionDocument(),
            recipe: base,
            recordIndex: 0,
            retainedNeighborRecipes: recipes,
          ),
          throwsStateError,
        );
      }
    },
  );

  test(
    'truncated DD2 and MTXM are rejected instead of dropping tail bytes',
    () {
      for (final name in ['DD2 ', 'MTXM']) {
        final doc = _patch(
          batchDeletionDocument(),
          name,
          (bytes) => [...bytes, 7],
        );
        expect(
          () => DoodadDeletionPlan.create(
            document: doc,
            recipe: deletionRecipe(),
            recordIndex: 0,
            retainedNeighborRecipes: {7: deletionRecipe()},
          ),
          throwsStateError,
        );
      }
    },
  );

  test(
    '256 retained records succeed, 257 reject; distant raw records stay raw',
    () {
      final base = batchDeletionDocument();
      final dd = base.sections.singleWhere((s) => s.name == 'DD2 ').payload;
      for (final count in [256, 257]) {
        final doc = _patch(
          base,
          'DD2 ',
          (_) => [
            ...dd.take(16),
            for (var i = 0; i < count; i++) ...dd.skip(16),
          ],
        );
        DoodadDeletionPlan build() => DoodadDeletionPlan.create(
          document: doc,
          recipe: deletionRecipe(),
          recordIndex: 0,
          retainedNeighborRecipes: {7: deletionRecipe()},
        );
        if (count == 256) {
          final plan = build();
          expect(plan.preservedNeighborRecordIndices, hasLength(256));
          expect(
            const ChkObjectViewDecoder()
                .decode(_apply(plan))
                .doodadSections
                .single
                .doodads
                .first
                .enabledValue,
            255,
          );
        } else {
          expect(build, throwsStateError);
        }
      }
    },
  );
}
