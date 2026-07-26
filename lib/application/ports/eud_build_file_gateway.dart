import '../eud/eud_build_configuration.dart';

final class EudBuildWorkspace {
  EudBuildWorkspace({
    required this.directoryPath,
    required this.settingsFilePath,
    required this.temporaryOutputMapPath,
  });

  final String directoryPath;
  final String settingsFilePath;
  final String temporaryOutputMapPath;
}

final class EudBuildPromotionResult {
  EudBuildPromotionResult({this.backupPath});

  final String? backupPath;
}

final class EudBuildPromotionRecoveryException implements Exception {
  const EudBuildPromotionRecoveryException({
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
    return 'Failed to promote the verified EUD map and restore the previous '
        'destination. Recover "$destinationPath" from "$backupPath". '
        'Promotion error: $promotionError. '
        'Restoration error: $restorationError.';
  }
}

abstract interface class EudBuildFileGateway {
  Future<void> validateInputs(EudBuildConfiguration configuration);

  Future<bool> destinationExists(String path);

  Future<bool> refersToSameLocation(String leftPath, String rightPath);

  Future<EudBuildWorkspace> createWorkspace(
    EudBuildConfiguration configuration,
  );

  Future<EudBuildPromotionResult> promote({
    required EudBuildWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  });

  Future<void> cleanup(EudBuildWorkspace workspace);
}
