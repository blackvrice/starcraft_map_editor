import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class StarCraftDataAssetDiagnosticCodes {
  static const rootNotConfigured = 'SC_ASSET_ROOT_NOT_CONFIGURED';
  static const rootPathInvalid = 'SC_ASSET_ROOT_PATH_INVALID';
  static const rootNotFound = 'SC_ASSET_ROOT_NOT_FOUND';
  static const rootNotDirectory = 'SC_ASSET_ROOT_NOT_DIRECTORY';
  static const tilesetDirectoryMissing = 'SC_ASSET_TILESET_DIRECTORY_MISSING';
  static const filesMissing = 'SC_ASSET_FILES_MISSING';
  static const filesInvalid = 'SC_ASSET_FILES_INVALID';
  static const inspectionFailed = 'SC_ASSET_INSPECTION_FAILED';
  static const settingsReadFailed = 'SC_ASSET_SETTINGS_READ_FAILED';
  static const settingsWriteFailed = 'SC_ASSET_SETTINGS_WRITE_FAILED';
  static const directoryPickerFailed = 'SC_ASSET_DIRECTORY_PICKER_FAILED';
}

abstract interface class StarCraftDataAssetInspector {
  Future<StarCraftDataAssetInspection> inspect(String rootPath);
}

final class StarCraftDataAssetInspection {
  StarCraftDataAssetInspection({
    required this.rootPath,
    required this.resolvedTilesetDirectoryPath,
    required this.requiredAssetCount,
    required this.foundAssetCount,
    List<String> missingRelativePaths = const [],
    List<String> invalidRelativePaths = const [],
    List<EditorDiagnostic> diagnostics = const [],
  }) : missingRelativePaths = List.unmodifiable(missingRelativePaths),
       invalidRelativePaths = List.unmodifiable(invalidRelativePaths),
       diagnostics = List.unmodifiable(diagnostics) {
    if (requiredAssetCount < 0 ||
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

  final String rootPath;
  final String? resolvedTilesetDirectoryPath;
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
