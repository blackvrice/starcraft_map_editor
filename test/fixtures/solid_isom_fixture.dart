import 'dart:async';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';

TerrainConnectionSnapshot solidSnapshot({
  int tileset = 0,
  List<TerrainSnapshotGroup>? groups,
  String storageProduct = 'fixture',
  int storageBuildNumber = 1,
}) => TerrainConnectionSnapshot(
  tileset: tileset,
  revision: 'synthetic-solid',
  helperVersion: '0.13.0',
  storageProduct: storageProduct,
  storageBuildNumber: storageBuildNumber,
  assets: [],
  groups:
      groups ??
      [
        solidGroup(2),
        solidGroup(3),
        solidGroup(4, type: 3, link: 2),
        solidGroup(5, type: 3, link: 2),
      ],
);

TerrainSnapshotGroup solidGroup(
  int group, {
  int type = 2,
  int link = 1,
  List<int>? stacks,
  List<int>? references,
  List<int>? members,
}) => TerrainSnapshotGroup(
  group: group,
  terrainTypeWord: type,
  flagsWord: 1,
  linkWords: List.filled(4, link),
  stackWords: stacks ?? List.filled(4, 0),
  megaTileReferences: references ?? [1, 2, ...List.filled(14, 0)],
  renderableMembers: members ?? List.generate(16, (i) => i),
);

class SolidSnapshotGateway implements TerrainConnectionSnapshotGateway {
  Completer<TerrainSnapshotReadResult>? pending;
  final cancelled = <String>[];
  String? operation;
  @override
  void cancel(String operationId) => cancelled.add(operationId);
  @override
  Future<TerrainSnapshotReadResult> read({
    required String operationId,
    required String installationPath,
    required int tileset,
  }) async {
    operation = operationId;
    return pending == null
        ? TerrainSnapshotReadResult(snapshot: solidSnapshot(tileset: tileset))
        : await pending!.future;
  }
}
