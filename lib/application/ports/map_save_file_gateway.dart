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

class MapSavePromotionResult {
  MapSavePromotionResult({this.backupPath}) {
    if (backupPath != null && backupPath!.trim().isEmpty) {
      throw ArgumentError.value(
        backupPath,
        'backupPath',
        'The backup path must not be blank.',
      );
    }
  }

  final String? backupPath;

  bool get replacedExistingDestination => backupPath != null;
}

class MapSavePromotionRecoveryException implements Exception {
  const MapSavePromotionRecoveryException({
    required this.destinationPath,
    required this.backupPath,
    required this.promotionError,
    required this.restorationError,
  });

  final String destinationPath;
  final String backupPath;
  final Object promotionError;
  final Object restorationError;

  @override
  String toString() {
    return 'The existing destination could not be restored automatically '
        'after promotion failed. destination=$destinationPath; '
        'backup=$backupPath; promotionError=$promotionError; '
        'restorationError=$restorationError';
  }
}

abstract interface class MapSaveFileGateway {
  Future<bool> destinationExists(String path);

  Future<bool> refersToSameLocation(String leftPath, String rightPath);

  Future<MapSaveWorkspace> createWorkspace(String destinationPath);

  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  });

  Future<void> cleanup(MapSaveWorkspace workspace);
}
