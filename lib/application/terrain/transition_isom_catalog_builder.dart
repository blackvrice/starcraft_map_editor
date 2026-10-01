// Shape projection rules adapted from Chkdraft at
// 32d27861b16dda0b0f3d95e34bad894ea4efb2c3 (MIT).
// Copyright (c) 2015-2026 Justin Forsberg. See docs/licenses/Chkdraft.txt.
import '../../domain/terrain/isom_terrain_conversion.dart';
import '../ports/terrain_connection_snapshot_gateway.dart';
import 'isom_transition_shapes.dart';
import 'solid_isom_catalog_builder.dart';

/// Builds numeric connections from one local snapshot. Does not infer heights
/// or repair ISOM. Missing quadrants reject the entire catalog. CV5 group order
/// defines the canonical quadrant; later stack rows supersede earlier rows.
class TransitionIsomCatalogBuilder {
  const TransitionIsomCatalogBuilder();
  SolidIsomCatalog build(TerrainConnectionSnapshot snapshot) {
    final solid = const SolidIsomCatalogBuilder().build(snapshot);
    final edges = [...solid.catalog.edges];
    final pairs = [...solid.catalog.pairs];
    final groups = {for (final g in snapshot.groups) g.group: g};
    const sides = [
      [2, 3],
      [0, 3],
      [0, 1],
      [1, 2],
    ];
    for (final entry in isomTransitionStarts[snapshot.tileset].entries) {
      final type = entry.key, start = entry.value;
      final candidates =
          snapshot.groups
              .where(
                (g) =>
                    g.group < 1024 &&
                    g.group.isEven &&
                    g.terrainTypeWord == type,
              )
              .toList()
            ..sort((a, b) => a.group.compareTo(b.group));
      if (candidates.isEmpty) continue;
      final links = List.generate(14, (_) => List.generate(4, (_) => <int>[]));
      final matched = List.generate(
        14,
        (_) => List<TerrainSnapshotGroup?>.filled(4, null),
      );
      for (final g in candidates) {
        if (g.linkWords.length != 4 ||
            g.stackWords.length != 4 ||
            g.linkWords.any((v) => v < 0 || v > 63)) {
          throw StateError('Invalid transition words.');
        }
        if (g.linkWords.every((v) => v <= 48) ||
            g.linkWords.every((v) => v > 48)) {
          continue;
        }
        for (var shape = 0; shape < 14; shape++) {
          for (var q = 0; q < 4; q++) {
            final pattern = isomTransitionPatterns[shape][q];
            if (pattern[4] == 1 && g.stackWords[1] != 0) continue;
            if (!List.generate(4, (i) => i).every(
              (i) =>
                  g.linkWords[i] == pattern[i] ||
                  (g.linkWords[i] <= 48 && pattern[i] <= 48),
            )) {
              continue;
            }
            final value = [for (final side in sides[q]) g.linkWords[side]];
            links[shape][q] = value;
            matched[shape][q] = g;
          }
        }
      }
      List<int> require(int shape, int q) {
        final v = links[shape][q];
        if (v.length != 2 || v.any((v) => v == 0)) {
          throw StateError('Missing transition quadrant: $type/$shape/$q.');
        }
        return v;
      }

      // Concave east/west quadrants can be composed from their two diagonal
      // boundary groups when CV5 does not contain a dedicated quadrant.
      if (links[8][1].isEmpty) {
        final a = matched[1][3], b = matched[2][0];
        if (a == null || b == null) {
          throw StateError('Missing east transition.');
        }
        links[8][1] = [a.linkWords[0], a.linkWords[3]];
        links[8][2] = [b.linkWords[0], b.linkWords[1]];
      }
      if (links[9][0].isEmpty) {
        final a = matched[0][2], b = matched[3][1];
        if (a == null || b == null) {
          throw StateError('Missing west transition.');
        }
        links[9][0] = [a.linkWords[2], a.linkWords[3]];
        links[9][3] = [b.linkWords[1], b.linkWords[2]];
      }
      // Empty quadrants are the adjacent solid side of a diagonal boundary.
      links[0][0] = [require(0, 1)[0], require(0, 3)[0]];
      links[1][1] = [require(1, 0)[0], require(1, 2)[1]];
      links[2][2] = [require(2, 3)[1], require(2, 1)[1]];
      links[3][3] = [require(3, 0)[1], require(3, 2)[0]];
      for (final q in [0, 1]) {
        final v = require(4, q == 0 ? 3 : 2)[q == 0 ? 0 : 1];
        links[4][q] = [v, v];
      }
      for (final q in [1, 2]) {
        links[5][q] = List.filled(2, require(5, 0)[0]);
      }
      for (final q in [2, 3]) {
        final v = require(6, q == 2 ? 1 : 0)[1];
        links[6][q] = [v, v];
      }
      for (final q in [0, 3]) {
        links[7][q] = List.filled(2, require(7, 1)[0]);
      }
      for (var shape = 0; shape < 14; shape++) {
        for (var q = 0; q < 4; q++) {
          final v = require(shape, q);
          for (var side = 0; side < 2; side++) {
            edges.add(
              IsomEdgeConnection(
                value: ((start + shape) << 4) | (q * 4 + side * 2),
                link: v[side],
                terrainType: type,
              ),
            );
          }
        }
      }
      for (final left in candidates) {
        final right = groups[left.group + 1];
        if (right == null ||
            right.terrainTypeWord != type ||
            !List.generate(4, (i) => i).every(
              (i) =>
                  left.linkWords[i] == right.linkWords[i] &&
                  left.stackWords[i] == right.stackWords[i],
            ) ||
            left.stackWords[0] != 0 ||
            left.stackWords[2] != 0) {
          throw StateError('Invalid transition pair: ${left.group}.');
        }
        final members = [
          for (var m = 0; m < 16; m++)
            if (left.renderableMembers.contains(m) &&
                right.renderableMembers.contains(m) &&
                left.megaTileReferences[m] != 0 &&
                right.megaTileReferences[m] != 0)
              m,
        ];
        if (members.isEmpty) continue;
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
    }
    edges.sort((a, b) => a.value.compareTo(b.value));
    pairs.sort((a, b) => a.leftGroup.compareTo(b.leftGroup));
    return SolidIsomCatalog(
      IsomTerrainCatalog(
        tileset: snapshot.tileset,
        revision: 'transition-isom-v1:${snapshot.revision}',
        edges: edges,
        pairs: pairs,
      ),
      solid.shapes,
    );
  }
}
