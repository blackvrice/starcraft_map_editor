class MapSaveWorkspace {
  MapSaveWorkspace({
    required this.directoryPath,
    required this.temporaryOutputPath,
  }) {
    if (directoryPath.trim().isEmpty) {
      throw ArgumentError.value(
        directoryPath,
        'directoryPath',
        'The workspace directory path must not be blank.',
      );
    }
    if (temporaryOutputPath.trim().isEmpty) {
      throw ArgumentError.value(
        temporaryOutputPath,
        'temporaryOutputPath',
        'The temporary output path must not be blank.',
      );
    }
  }

  final String directoryPath;
  final String temporaryOutputPath;
}

abstract interface class MapSaveFileGateway {
  Future<bool> destinationExists(String path);

  Future<bool> refersToSameLocation(String leftPath, String rightPath);

  Future<MapSaveWorkspace> createWorkspace(String destinationPath);

  Future<void> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
  });

  Future<void> cleanup(MapSaveWorkspace workspace);
}
