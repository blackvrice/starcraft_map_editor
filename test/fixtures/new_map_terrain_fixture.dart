import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'solid_isom_fixture.dart';

class NewMapTerrainGateway extends SolidSnapshotGateway {
  @override
  Future<TerrainSnapshotReadResult> read({
    required String operationId,
    required String installationPath,
    required int tileset,
  }) async {
    operation = operationId;
    return pending == null
        ? TerrainSnapshotReadResult(
            snapshot: solidSnapshot(
              tileset: tileset,
              storageProduct: 's1',
              storageBuildNumber: 13515,
            ),
          )
        : await pending!.future;
  }
}
