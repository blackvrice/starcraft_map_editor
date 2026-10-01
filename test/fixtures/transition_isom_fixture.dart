import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'solid_isom_fixture.dart';

// Synthetic CV5 numeric rows; no StarCraft assets or extracted imagery.
TerrainConnectionSnapshot transitionSnapshot() {
  const rows = <List<int>>[
    [1, 1, 51, 51],
    [1, 1, 51, 53],
    [1, 1, 52, 52],
    [1, 1, 55, 55],
    [1, 49, 49, 1],
    [1, 50, 50, 1],
    [1, 53, 50, 1],
    [1, 55, 55, 1],
    [49, 1, 1, 49],
    [49, 1, 1, 54],
    [50, 1, 1, 50],
    [51, 51, 1, 1],
    [52, 52, 1, 1],
    [52, 54, 1, 1],
    [56, 1, 1, 56],
    [56, 56, 1, 1],
  ];
  final groups = [
    solidGroup(2),
    solidGroup(3),
    solidGroup(4, type: 3, link: 2),
    solidGroup(5, type: 3, link: 2),
  ];
  for (var i = 0; i < rows.length; i++) {
    for (var half = 0; half < 2; half++) {
      groups.add(
        TerrainSnapshotGroup(
          group: 6 + i * 2 + half,
          terrainTypeWord: 34,
          flagsWord: 1,
          linkWords: rows[i],
          stackWords: [0, 0, 0, 0],
          megaTileReferences: [1, 2, ...List.filled(14, 0)],
          renderableMembers: [0, 1],
        ),
      );
    }
  }
  return solidSnapshot(groups: groups);
}
