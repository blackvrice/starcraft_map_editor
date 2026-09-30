/// Raw local CV5 metadata, not an ISOM catalog or permission to edit terrain.
abstract interface class TerrainConnectionSnapshotGateway {
  Future<TerrainSnapshotReadResult> read({
    required String operationId,
    required String installationPath,
    required int tileset,
  });
  void cancel(String operationId);
}

final class TerrainConnectionSnapshot {
  TerrainConnectionSnapshot({
    required this.tileset,
    required this.revision,
    required this.helperVersion,
    required this.storageProduct,
    required this.storageBuildNumber,
    required List<TerrainSnapshotAsset> assets,
    required List<TerrainSnapshotGroup> groups,
  }) : assets = List.unmodifiable(assets),
       groups = List.unmodifiable(groups);
  final int tileset, storageBuildNumber;
  final String revision, helperVersion, storageProduct;
  final List<TerrainSnapshotAsset> assets;
  final List<TerrainSnapshotGroup> groups;
}

final class TerrainSnapshotAsset {
  const TerrainSnapshotAsset(this.path, this.byteLength, this.sha256);
  final String path, sha256;
  final int byteLength;
}

final class TerrainSnapshotGroup {
  TerrainSnapshotGroup({
    required this.group,
    required this.terrainTypeWord,
    required this.flagsWord,
    required List<int> linkWords,
    required List<int> stackWords,
    required List<int> renderableMembers,
  }) : linkWords = List.unmodifiable(linkWords),
       stackWords = List.unmodifiable(stackWords),
       renderableMembers = List.unmodifiable(renderableMembers);
  final int group, terrainTypeWord, flagsWord;
  final List<int> linkWords, stackWords, renderableMembers;
}

final class TerrainSnapshotReadResult {
  const TerrainSnapshotReadResult({
    this.snapshot,
    this.errorCode,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });
  final TerrainConnectionSnapshot? snapshot;
  final String? errorCode;
  final int? exitCode;

  /// Bounded raw process logs, including successful responses and versions.
  final String stdout, stderr;
  bool get isSuccess => snapshot != null && errorCode == null;
}
