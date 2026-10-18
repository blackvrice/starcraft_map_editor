import 'dart:async';
import 'package:starcraft_map_editor/application/ports/terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/application/ports/terrain_placement_snapshot_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/terrain_placement_snapshot_decoder.dart';
import 'terrain_placement_fixture.dart';

TerrainPlacementSource analysisSource({bool elevation = true}) {
  final json = terrainPlacementJson();
  if (elevation) {
    json['elevationProfile'] = {
      'version': 1,
      'midMasks': [0xaaaa, 0],
      'highMasks': [0xcccc, 0],
    };
  }
  return const TerrainPlacementSnapshotDecoder().decode(
    json,
    operationId: 'fixture',
    installationPath: r'C:\StarCraft',
    tileset: 0,
  );
}

class AnalysisGateway
    implements
        TerrainPlacementSnapshotGateway,
        TerrainConnectionSnapshotGateway {
  final cancelled = <String>[];
  final requests = <String>[];
  final pending = <Completer<TerrainPlacementReadResult>>[];
  bool delay = false;
  bool fail = false;
  @override
  void cancel(String operationId) => cancelled.add(operationId);
  @override
  Future<TerrainPlacementReadResult> readPlacement({
    required String operationId,
    required String installationPath,
    required int tileset,
  }) async {
    requests.add(operationId);
    if (delay) {
      final value = Completer<TerrainPlacementReadResult>();
      pending.add(value);
      return value.future;
    }
    return fail
        ? const TerrainPlacementReadResult(errorCode: 'fixture-failed')
        : TerrainPlacementReadResult(source: analysisSource());
  }

  @override
  Future<TerrainSnapshotReadResult> read({
    required String operationId,
    required String installationPath,
    required int tileset,
  }) => throw StateError('No ISOM load');
}
