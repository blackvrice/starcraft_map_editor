import 'dart:io';

import '../../application/ports/starcraft_data_asset_inspector.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

final class LocalStarCraftDataAssetInspector
    implements StarCraftDataAssetInspector {
  @override
  Future<StarCraftDataAssetInspection> inspect(String rootPath) async {
    final requirements = StarCraftDataAssetManifest.requiredTilesetAssets;
    final trimmedPath = rootPath.trim();
    if (trimmedPath.isEmpty ||
        trimmedPath != rootPath ||
        !_isAbsoluteWindowsPath(rootPath)) {
      return _failedInspection(
        rootPath: rootPath,
        requiredAssetCount: requirements.length,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.rootPathInvalid,
          message:
              'The StarCraft data asset path must be an absolute Windows '
              'drive or UNC directory.',
          filePath: rootPath,
          remediation: 'Choose the directory using the Settings folder picker.',
        ),
      );
    }

    try {
      final rootType = await FileSystemEntity.type(rootPath, followLinks: true);
      if (rootType == FileSystemEntityType.notFound) {
        return _failedInspection(
          rootPath: rootPath,
          requiredAssetCount: requirements.length,
          diagnostic: _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.rootNotFound,
            message: 'The configured StarCraft data asset path does not exist.',
            filePath: rootPath,
            remediation: 'Choose an existing asset root or tileset directory.',
          ),
        );
      }
      if (rootType != FileSystemEntityType.directory) {
        return _failedInspection(
          rootPath: rootPath,
          requiredAssetCount: requirements.length,
          diagnostic: _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.rootNotDirectory,
            message:
                'The configured StarCraft data asset path is not a directory.',
            filePath: rootPath,
            remediation: 'Choose an asset root or tileset directory.',
          ),
        );
      }

      final tilesetDirectoryPath = _isTilesetDirectory(rootPath)
          ? _withoutTrailingSeparators(rootPath)
          : _join(rootPath, 'tileset');
      final tilesetType = await FileSystemEntity.type(
        tilesetDirectoryPath,
        followLinks: true,
      );
      if (tilesetType != FileSystemEntityType.directory) {
        return _failedInspection(
          rootPath: rootPath,
          resolvedTilesetDirectoryPath: tilesetDirectoryPath,
          requiredAssetCount: requirements.length,
          diagnostic: _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.tilesetDirectoryMissing,
            message: 'The required tileset data directory is missing.',
            filePath: tilesetDirectoryPath,
            remediation:
                'Choose a directory named "tileset" or its parent asset root.',
          ),
        );
      }

      final missing = <String>[];
      final invalid = <String>[];
      var foundCount = 0;
      for (final requirement in requirements) {
        final assetPath = _join(tilesetDirectoryPath, requirement.fileName);
        final assetType = await FileSystemEntity.type(
          assetPath,
          followLinks: true,
        );
        if (assetType != FileSystemEntityType.file) {
          missing.add(requirement.relativePath);
          continue;
        }
        if (await File(assetPath).length() <= 0) {
          invalid.add(requirement.relativePath);
          continue;
        }
        foundCount++;
      }

      final diagnostics = <EditorDiagnostic>[
        if (missing.isNotEmpty)
          _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.filesMissing,
            message:
                '${missing.length} required StarCraft tileset asset '
                '${missing.length == 1 ? 'file is' : 'files are'} missing.',
            filePath: tilesetDirectoryPath,
            remediation:
                'Provide the complete loose CV5/VF4/VX4/VR4/WPE asset set.',
            rawDetails: missing.join('\n'),
          ),
        if (invalid.isNotEmpty)
          _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.filesInvalid,
            message:
                '${invalid.length} required StarCraft tileset asset '
                '${invalid.length == 1 ? 'file is' : 'files are'} empty.',
            filePath: tilesetDirectoryPath,
            remediation: 'Replace empty assets with valid extracted data.',
            rawDetails: invalid.join('\n'),
          ),
      ];

      return StarCraftDataAssetInspection(
        rootPath: rootPath,
        resolvedTilesetDirectoryPath: tilesetDirectoryPath,
        requiredAssetCount: requirements.length,
        foundAssetCount: foundCount,
        missingRelativePaths: missing,
        invalidRelativePaths: invalid,
        diagnostics: diagnostics,
      );
    } on FileSystemException catch (error) {
      return _failedInspection(
        rootPath: rootPath,
        requiredAssetCount: requirements.length,
        diagnostic: _diagnostic(
          code: StarCraftDataAssetDiagnosticCodes.inspectionFailed,
          message: 'The StarCraft data asset directory could not be inspected.',
          filePath: error.path ?? rootPath,
          remediation: 'Check directory permissions and retry.',
          rawDetails: error.toString(),
        ),
      );
    }
  }
}

StarCraftDataAssetInspection _failedInspection({
  required String rootPath,
  required int requiredAssetCount,
  required EditorDiagnostic diagnostic,
  String? resolvedTilesetDirectoryPath,
}) {
  return StarCraftDataAssetInspection(
    rootPath: rootPath,
    resolvedTilesetDirectoryPath: resolvedTilesetDirectoryPath,
    requiredAssetCount: requiredAssetCount,
    foundAssetCount: 0,
    missingRelativePaths: [
      for (final requirement
          in StarCraftDataAssetManifest.requiredTilesetAssets)
        requirement.relativePath,
    ],
    diagnostics: [diagnostic],
  );
}

EditorDiagnostic _diagnostic({
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
    filePath: filePath,
    remediation: remediation,
    rawDetails: rawDetails,
  );
}

bool _isAbsoluteWindowsPath(String path) {
  if (path.startsWith(r'\\?\') || path.startsWith(r'\\.\')) {
    return false;
  }
  return RegExp(
    r'^(?:[a-zA-Z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+(?:[\\/]|$))',
  ).hasMatch(path);
}

bool _isTilesetDirectory(String path) {
  final normalized = _withoutTrailingSeparators(path).replaceAll('/', r'\');
  return normalized.split(r'\').last.toLowerCase() == 'tileset';
}

String _withoutTrailingSeparators(String path) {
  var result = path;
  while (result.length > 3 && (result.endsWith(r'\') || result.endsWith('/'))) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String _join(String parent, String child) {
  final normalizedParent = _withoutTrailingSeparators(parent);
  return '$normalizedParent${Platform.pathSeparator}$child';
}
