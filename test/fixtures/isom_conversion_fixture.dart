import 'dart:typed_data';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import 'editor_terrain_fixture.dart';

RawChkDocument isomFixture({int width = 32, int height = 32}) {
  final bytes = ByteData((width ~/ 2 + 1) * (height + 1) * 8);
  for (var i = 0; i < bytes.lengthInBytes; i += 2) {
    bytes.setUint16(i, 0x8011, Endian.little);
  }
  return const NewMapFactory()
      .create(NewMapOptions(width: width, height: height, rawTileValue: 0))
      .appendSection(part('ISOM', bytes.buffer.asUint8List()));
}

IsomTerrainCatalog isomCatalog({List<IsomTilePair>? pairs, int tileset = 0}) =>
    IsomTerrainCatalog(
      tileset: tileset,
      revision: 'synthetic-fixture-v1',
      edges: [IsomEdgeConnection(value: 0x10, link: 2, terrainType: 1)],
      pairs: pairs ?? [isomPair(2)],
    );
IsomTilePair isomPair(
  int group, {
  List<int> members = const [0],
  List<int> stacks = const [0, 0, 0, 0],
}) => IsomTilePair(
  leftGroup: group,
  terrainType: 1,
  links: [2, 2, 2, 2],
  stackConnections: stacks,
  members: members,
);
