import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class StarCraftDataAssetDiagnosticCodes {
  static const installationNotConfigured =
      'SC_CASC_INSTALLATION_NOT_CONFIGURED';
  static const installationPathInvalid = 'SC_CASC_INSTALLATION_PATH_INVALID';
  static const installationNotFound = 'SC_CASC_INSTALLATION_NOT_FOUND';
  static const installationNotDirectory = 'SC_CASC_INSTALLATION_NOT_DIRECTORY';
  static const storageOpenFailed = 'SC_CASC_STORAGE_OPEN_FAILED';
  static const storageInfoFailed = 'SC_CASC_STORAGE_INFO_FAILED';
  static const filesMissing = 'SC_CASC_ASSET_FILES_MISSING';
  static const filesInvalid = 'SC_CASC_ASSET_FILES_INVALID';
  static const helperNotFound = 'SC_CASC_HELPER_NOT_FOUND';
  static const helperStartFailed = 'SC_CASC_HELPER_START_FAILED';
  static const helperTimedOut = 'SC_CASC_HELPER_TIMED_OUT';
  static const helperOutputLimitExceeded =
      'SC_CASC_HELPER_OUTPUT_LIMIT_EXCEEDED';
  static const helperInvalidResponse = 'SC_CASC_HELPER_INVALID_RESPONSE';
  static const inspectionFailed = 'SC_CASC_INSPECTION_FAILED';
  static const settingsReadFailed = 'SC_CASC_SETTINGS_READ_FAILED';
  static const settingsWriteFailed = 'SC_CASC_SETTINGS_WRITE_FAILED';
  static const directoryPickerFailed = 'SC_CASC_DIRECTORY_PICKER_FAILED';
}

abstract interface class StarCraftDataAssetInspector {
  Future<StarCraftDataAssetInspection> inspect(String installationPath);
}

final class StarCraftDataAssetInspection {
  StarCraftDataAssetInspection({
    required this.installationPath,
    required this.requiredAssetCount,
    required this.foundAssetCount,
    this.storageProduct,
    this.storageBuildNumber,
    this.helperVersion,
    this.cascLibRevision,
    this.totalAssetBytes = 0,
    List<String> missingRelativePaths = const [],
    List<String> invalidRelativePaths = const [],
    List<EditorDiagnostic> diagnostics = const [],
  }) : missingRelativePaths = List.unmodifiable(missingRelativePaths),
       invalidRelativePaths = List.unmodifiable(invalidRelativePaths),
       diagnostics = List.unmodifiable(diagnostics) {
    if (totalAssetBytes < 0 ||
        requiredAssetCount < 0 ||
        foundAssetCount < 0 ||
        foundAssetCount > requiredAssetCount) {
      throw ArgumentError('Asset counts must be nonnegative and consistent.');
    }
    if (foundAssetCount +
            this.missingRelativePaths.length +
            this.invalidRelativePaths.length !=
        requiredAssetCount) {
      throw ArgumentError(
        'Found, missing, and invalid assets must cover every requirement.',
      );
    }
  }

  final String installationPath;
  final String? storageProduct;
  final int? storageBuildNumber;
  final String? helperVersion;
  final String? cascLibRevision;
  final int totalAssetBytes;
  final int requiredAssetCount;
  final int foundAssetCount;
  final List<String> missingRelativePaths;
  final List<String> invalidRelativePaths;
  final List<EditorDiagnostic> diagnostics;

  bool get isReady =>
      foundAssetCount == requiredAssetCount &&
      missingRelativePaths.isEmpty &&
      invalidRelativePaths.isEmpty &&
      diagnostics.isEmpty;
}
