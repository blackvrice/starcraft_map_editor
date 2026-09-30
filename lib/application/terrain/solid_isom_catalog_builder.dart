import '../../domain/terrain/isom_terrain_conversion.dart';
import '../ports/terrain_connection_snapshot_gateway.dart';

/// Flat shape IDs are format facts verified against Chkdraft sc.cpp at
/// 32d27861b16dda0b0f3d95e34bad894ea4efb2c3. This is not a transition solver.
final class SolidIsomCatalog {
  SolidIsomCatalog(this.catalog, Map<int, int> shapes)
    : shapes = Map.unmodifiable(shapes);
  final IsomTerrainCatalog catalog;
  final Map<int, int> shapes; // Terrain type -> solid shape index.
}

class SolidIsomCatalogBuilder {
  const SolidIsomCatalogBuilder();
  static const _natural = {
    2: 1,
    3: 2,
    4: 13,
    5: 3,
    8: 4,
    9: 5,
    10: 9,
    11: 7,
    12: 10,
    13: 11,
    15: 6,
    16: 8,
    17: 12,
  };
  static const _shapes = [
    {2: 1, 3: 2, 4: 9, 5: 3, 6: 4, 7: 7, 14: 5, 15: 6, 18: 8},
    {2: 1, 3: 2, 4: 11, 5: 4, 6: 12, 7: 8, 8: 9, 9: 10, 10: 13, 11: 14},
    {2: 1, 3: 2, 4: 4, 5: 5, 6: 3, 7: 7, 8: 6},
    {2: 2, 3: 3, 4: 5, 5: 6, 6: 4, 7: 7, 8: 1, 9: 8},
    _natural,
    _natural,
    _natural,
    _natural,
  ];

  SolidIsomCatalog build(TerrainConnectionSnapshot snapshot) {
    RangeError.checkValueInInterval(snapshot.tileset, 0, 7, 'tileset');
    final groups = {for (final g in snapshot.groups) g.group: g};
    if (groups.length != snapshot.groups.length) {
      throw StateError('Duplicate terrain groups.');
    }
    final shapes = <int, int>{};
    final edges = <IsomEdgeConnection>[];
    final pairs = <IsomTilePair>[];
    final linksByType = <int, int>{};
    for (final left in snapshot.groups) {
      // The first 1024 CV5 groups are terrain. Later records are doodads.
      if (left.group.isOdd || left.group >= 1024) continue;
      final shape = _shapes[snapshot.tileset][left.terrainTypeWord];
      final right = groups[left.group + 1];
      if (shape == null ||
          right == null ||
          right.terrainTypeWord != left.terrainTypeWord) {
        continue;
      }
      bool flat(TerrainSnapshotGroup g) =>
          g.linkWords.length == 4 &&
          g.stackWords.length == 4 &&
          g.megaTileReferences.length == 16 &&
          g.stackWords.every((v) => v == 0) &&
          g.linkWords.first > 0 &&
          g.linkWords.first < 48 &&
          g.linkWords.every((v) => v == g.linkWords.first);
      if (!flat(left) ||
          !flat(right) ||
          left.linkWords.first != right.linkWords.first) {
        continue;
      }
      // Platform Space is intentionally the zero mega-tile, not an empty
      // member of an ordinary terrain group. Use only its canonical member 0.
      final space =
          snapshot.tileset == 1 &&
          left.terrainTypeWord == 2 &&
          left.megaTileReferences.every((v) => v == 0) &&
          right.megaTileReferences.every((v) => v == 0);
      final members = [
        for (var m = 0; m < 16; m++)
          if (left.renderableMembers.contains(m) &&
              right.renderableMembers.contains(m) &&
              ((left.megaTileReferences[m] != 0 &&
                      right.megaTileReferences[m] != 0) ||
                  (space && m == 0)))
            m,
      ];
      if (members.isEmpty) continue;
      final type = left.terrainTypeWord, link = left.linkWords.first;
      final previous = linksByType[type];
      if (previous != null && previous != link) {
        throw StateError('Ambiguous solid terrain connection.');
      }
      if (linksByType.entries.any((e) => e.key != type && e.value == link)) {
        throw StateError('Solid terrain types share an ambiguous connection.');
      }
      if (previous == null) {
        shapes[type] = shape;
        linksByType[type] = link;
        for (var side = 0; side < 16; side += 2) {
          edges.add(
            IsomEdgeConnection(
              value: (shape << 4) | side,
              link: link,
              terrainType: type,
            ),
          );
        }
      }
      pairs.add(
        IsomTilePair(
          leftGroup: left.group,
          terrainType: type,
          links: left.linkWords,
          stackConnections: left.stackWords,
          members: members,
        ),
      );
    }
    if (shapes.isEmpty) {
      throw StateError('No verified solid terrain available.');
    }
    return SolidIsomCatalog(
      IsomTerrainCatalog(
        tileset: snapshot.tileset,
        revision: 'solid-isom-v1:${snapshot.revision}',
        edges: edges,
        pairs: pairs,
      ),
      shapes,
    );
  }
}
