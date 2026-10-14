import '../../domain/placement/terrain_placement_snapshot.dart';
import 'terrain_connection_snapshot_gateway.dart';

abstract interface class TerrainPlacementSnapshotGateway {
  Future<TerrainPlacementReadResult> readPlacement({
    required String operationId,
    required String installationPath,
    required int tileset,
  });
  void cancel(String operationId);
}

final class TerrainPlacementSource {
  TerrainPlacementSource({
    required this.snapshot,
    required this.revision,
    required this.helperVersion,
    required this.cascLibRevision,
    required this.storageProduct,
    required this.storageBuildNumber,
    required List<TerrainSnapshotAsset> assets,
  }) : assets = List.unmodifiable(assets);
  final TerrainPlacementSnapshot snapshot;
  final String revision, helperVersion, cascLibRevision, storageProduct;
  final int storageBuildNumber;
  final List<TerrainSnapshotAsset> assets;
}

final class TerrainPlacementReadResult {
  const TerrainPlacementReadResult({
    this.source,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
  final TerrainPlacementSource? source;
  final String? errorCode;
  final int? exitCode;
  final String stdout, stderr;
  bool get isSuccess => source != null && errorCode == null;
}
