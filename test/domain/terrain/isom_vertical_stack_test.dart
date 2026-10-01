import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import '../../fixtures/isom_conversion_fixture.dart';

void main() {
  test('recalculation refuses unsupported source tile pairs without edits', () {
    final doc = isomFixture();
    final before = const RawChkEncoder().encode(doc);
    expect(
      () => const IsomTerrainConverter().preview(
        doc,
        isomCatalog(),
        seed: 0,
        requireKnownSourcePairs: true,
      ),
      throwsStateError,
    );
    expect(const RawChkEncoder().encode(doc), before);
  });
  RawChkDocument source() {
    final doc = isomFixture();
    final isom = doc.sections.last;
    final bytes = isom.payload;
    final data = ByteData.sublistView(bytes);
    for (var x = 0; x < 17; x++) {
      for (var side = 0; side < 4; side++) {
        data.setUint16((17 + x) * 8 + side * 2, 0x20, Endian.little);
      }
    }
    return doc.replaceSection(doc.sections.length - 1, isom.withPayload(bytes));
  }

  IsomTerrainCatalog catalog({bool incompatible = false}) => IsomTerrainCatalog(
    tileset: 0,
    revision: 'independent-stack-fixture',
    edges: [
      IsomEdgeConnection(value: 16, link: 1, terrainType: 2),
      IsomEdgeConnection(value: 32, link: 2, terrainType: 3),
    ],
    pairs: [
      IsomTilePair(
        leftGroup: 2,
        terrainType: 2,
        links: [1, 1, 1, 1],
        stackConnections: [0, 0, 0, 0],
        members: [0],
      ),
      // A locally attractive dead end; the solver must look below it.
      IsomTilePair(
        leftGroup: 4,
        terrainType: 2,
        links: [1, 1, 1, 1],
        stackConnections: [0, 0, 0, 7],
        members: [0],
      ),
      IsomTilePair(
        leftGroup: 6,
        terrainType: 2,
        links: [1, 1, 1, 1],
        stackConnections: [0, 0, 0, 9],
        members: [3],
      ),
      IsomTilePair(
        leftGroup: 8,
        terrainType: 3,
        links: [2, 2, 2, 2],
        stackConnections: [0, 9, 0, 0],
        members: [incompatible ? 4 : 3],
      ),
    ],
  );
  test(
    'whole-column solver avoids dead ends and keeps a common stack member',
    () {
      final doc = source();
      final bytes = const RawChkEncoder().encode(doc);
      final p = const IsomTerrainConverter().preview(doc, catalog(), seed: 7);
      final tile = p.result.sections
          .singleWhere((s) => s.name == 'TILE')
          .payload;
      expect(tile.take(4), [99, 0, 115, 0]); // group 6 / 7, member 3.
      expect(tile.skip(64).take(4), [131, 0, 147, 0]); // group 8 / 9.
      expect(tile.skip(128).take(4), [32, 0, 48, 0]); // Unstacked row.
      expect(
        p.result.sections.last,
        same(doc.sections.last),
      ); // ISOM flags unchanged.
      expect(const RawChkEncoder().encode(doc), bytes);
      expect(
        const IsomTerrainConverter()
            .preview(p.result, catalog(), seed: 99)
            .changedTileCount,
        0,
      );
    },
  );
  test('no common stack member is refused atomically', () {
    final doc = source();
    final before = const RawChkEncoder().encode(doc);
    expect(
      () => const IsomTerrainConverter().preview(
        doc,
        catalog(incompatible: true),
        seed: 0,
      ),
      throwsStateError,
    );
    expect(const RawChkEncoder().encode(doc), before);
  });
  test('connection 48 is soft and does not attach a terrain type', () {
    final p = const IsomTerrainConverter().preview(
      isomFixture(),
      IsomTerrainCatalog(
        tileset: 0,
        revision: 'soft-48',
        edges: [IsomEdgeConnection(value: 16, link: 48, terrainType: 2)],
        pairs: [
          IsomTilePair(
            leftGroup: 2,
            terrainType: 3,
            links: [48, 48, 48, 48],
            stackConnections: [0, 0, 0, 0],
            members: [0],
          ),
        ],
      ),
      seed: 0,
    );
    expect(p.changedTileCount, 1024);
  });
}
