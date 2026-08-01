import 'dart:collection';
import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../../domain/chk/typed/chk_terrain_views.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/starcraft_tile_atlas_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';

abstract final class TerrainTileAtlasDiagnosticCodes {
  static const gatewayFailed = 'SC_CASC_TILE_ATLAS_GATEWAY_FAILED';
  static const resultMismatch = 'SC_CASC_TILE_ATLAS_RESULT_MISMATCH';
}

final class TerrainTileAtlasIdentity {
  TerrainTileAtlasIdentity({
    required this.installationPath,
    required this.storageProduct,
    required this.storageBuildNumber,
    required this.helperVersion,
    required this.cascLibRevision,
    required this.tileset,
    required this.inspectionSnapshot,
  }) : _normalizedInstallationPath = _normalizeWindowsPath(installationPath);

  final String installationPath;
  final String storageProduct;
  final int storageBuildNumber;
  final String helperVersion;
  final String cascLibRevision;
  final StarCraftTilesetAssetSet tileset;
  final Object inspectionSnapshot;
  final String _normalizedInstallationPath;

  @override
  bool operator ==(Object other) {
    return other is TerrainTileAtlasIdentity &&
        other._normalizedInstallationPath == _normalizedInstallationPath &&
        other.storageProduct == storageProduct &&
        other.storageBuildNumber == storageBuildNumber &&
        other.helperVersion == helperVersion &&
        other.cascLibRevision == cascLibRevision &&
        other.tileset == tileset &&
        identical(other.inspectionSnapshot, inspectionSnapshot);
  }

  @override
  int get hashCode => Object.hash(
    _normalizedInstallationPath,
    storageProduct,
    storageBuildNumber,
    helperVersion,
    cascLibRevision,
    tileset,
    identityHashCode(inspectionSnapshot),
  );
}

final class TerrainTileAtlasContext {
  TerrainTileAtlasContext({
    required this.identity,
    required List<int> renderableRawValues,
    required List<int> unsupportedRawValues,
  }) : renderableRawValues = List.unmodifiable(renderableRawValues),
       unsupportedRawValues = List.unmodifiable(unsupportedRawValues);

  final TerrainTileAtlasIdentity identity;
  final List<int> renderableRawValues;
  final List<int> unsupportedRawValues;
}

final class TerrainTileAtlasBatchResult {
  TerrainTileAtlasBatchResult({
    required Map<int, Uint8List> rgbaTiles,
    required List<int> unsupportedRawValues,
    required List<EditorDiagnostic> diagnostics,
  }) : rgbaTiles = Map.unmodifiable({
         for (final entry in rgbaTiles.entries)
           entry.key: Uint8List.fromList(entry.value).asUnmodifiableView(),
       }),
       unsupportedRawValues = List.unmodifiable(unsupportedRawValues),
       diagnostics = List.unmodifiable(diagnostics);

  final Map<int, Uint8List> rgbaTiles;
  final List<int> unsupportedRawValues;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

final class TerrainTileAtlasLoader {
  const TerrainTileAtlasLoader({required this.gateway});

  static const tileSize = 32;
  static const bytesPerPixel = 4;
  static const rgbaBytesPerTile = tileSize * tileSize * bytesPerPixel;

  final StarCraftTileAtlasGateway gateway;

  TerrainTileAtlasContext? createContext({
    required ChkMetadataViews metadataViews,
    required ChkTerrainViews terrainViews,
    required StarCraftDataAssetSettingsState assetState,
  }) {
    if (!assetState.isReady ||
        metadataViews.tilesets.length != 1 ||
        terrainViews.tileMaps.length != 1) {
      return null;
    }
    final inspection = assetState.inspection;
    final terrain = terrainViews.tileMaps.single;
    final knownTileset = metadataViews.tilesets.single.knownTileset;
    if (inspection == null ||
        !inspection.isReady ||
        !terrain.hasGridDimensions ||
        knownTileset == null) {
      return null;
    }
    final storageProduct = inspection.storageProduct;
    final storageBuildNumber = inspection.storageBuildNumber;
    final helperVersion = inspection.helperVersion;
    final cascLibRevision = inspection.cascLibRevision;
    if (storageProduct == null ||
        storageProduct.isEmpty ||
        storageBuildNumber == null ||
        helperVersion == null ||
        helperVersion.isEmpty ||
        cascLibRevision == null ||
        cascLibRevision.isEmpty) {
      return null;
    }

    final tileset = StarCraftTilesetAssetSet.values.singleWhere(
      (candidate) => candidate.rawValue == knownTileset.rawValue,
    );
    final uniqueValues = SplayTreeSet<int>.of(terrain.rawTileValues);

    return TerrainTileAtlasContext(
      identity: TerrainTileAtlasIdentity(
        installationPath: inspection.installationPath,
        storageProduct: storageProduct,
        storageBuildNumber: storageBuildNumber,
        helperVersion: helperVersion,
        cascLibRevision: cascLibRevision,
        tileset: tileset,
        inspectionSnapshot: inspection,
      ),
      renderableRawValues: uniqueValues.toList(growable: false),
      unsupportedRawValues: const [],
    );
  }

  Future<TerrainTileAtlasBatchResult> loadBatch({
    required TerrainTileAtlasContext context,
    required List<int> rawValues,
  }) async {
    _validateBatch(context, rawValues);
    final request = StarCraftTileAtlasRequest(
      installationPath: context.identity.installationPath,
      tileset: context.identity.tileset,
      rawValues: rawValues,
    );

    final StarCraftTileAtlasResult result;
    try {
      result = await gateway.render(request);
    } catch (error) {
      return TerrainTileAtlasBatchResult(
        rgbaTiles: const {},
        unsupportedRawValues: rawValues,
        diagnostics: [
          _diagnostic(
            code: TerrainTileAtlasDiagnosticCodes.gatewayFailed,
            message: 'The StarCraft tile atlas request failed unexpectedly.',
            filePath: context.identity.installationPath,
            remediation: 'Retry or repair the application installation.',
            rawDetails: error.toString(),
          ),
        ],
      );
    }

    if (!_sameRequest(result.request, request) ||
        (result.isSuccess &&
            !_sameIdentityMetadata(result, context.identity))) {
      return TerrainTileAtlasBatchResult(
        rgbaTiles: const {},
        unsupportedRawValues: rawValues,
        diagnostics: [
          _diagnostic(
            code: TerrainTileAtlasDiagnosticCodes.resultMismatch,
            message: 'The StarCraft tile atlas result did not match its batch.',
            filePath: context.identity.installationPath,
            remediation: 'Repair the application or report the helper error.',
          ),
        ],
      );
    }

    final tiles = <int, Uint8List>{};
    for (var index = 0; index < result.rawValues.length; index++) {
      tiles[result.rawValues[index]] = _extractTile(result, index);
    }
    return TerrainTileAtlasBatchResult(
      rgbaTiles: tiles,
      unsupportedRawValues: result.unsupportedRawValues,
      diagnostics: result.diagnostics,
    );
  }

  void _validateBatch(TerrainTileAtlasContext context, List<int> rawValues) {
    if (rawValues.isEmpty ||
        rawValues.length > StarCraftTileAtlasRequest.maximumRawValues) {
      throw RangeError.range(
        rawValues.length,
        1,
        StarCraftTileAtlasRequest.maximumRawValues,
        'rawValues.length',
      );
    }
    final allowed = context.renderableRawValues.toSet();
    var previous = -1;
    for (final value in rawValues) {
      if (value <= previous || !allowed.contains(value)) {
        throw ArgumentError.value(
          rawValues,
          'rawValues',
          'Must be a sorted unique subset of the renderable context values.',
        );
      }
      previous = value;
    }
  }
}

bool _sameIdentityMetadata(
  StarCraftTileAtlasResult result,
  TerrainTileAtlasIdentity identity,
) {
  return result.storageProduct == identity.storageProduct &&
      result.storageBuildNumber == identity.storageBuildNumber &&
      result.helperVersion == identity.helperVersion &&
      result.cascLibRevision == identity.cascLibRevision;
}

Uint8List _extractTile(StarCraftTileAtlasResult atlas, int tileIndex) {
  final start = tileIndex * TerrainTileAtlasLoader.rgbaBytesPerTile;
  return Uint8List.fromList(
    atlas.rgbaBytes.sublist(
      start,
      start + TerrainTileAtlasLoader.rgbaBytesPerTile,
    ),
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

bool _sameRequest(
  StarCraftTileAtlasRequest left,
  StarCraftTileAtlasRequest right,
) {
  return _normalizeWindowsPath(left.installationPath) ==
          _normalizeWindowsPath(right.installationPath) &&
      left.tileset == right.tileset &&
      _sameValues(left.rawValues, right.rawValues);
}

bool _sameValues(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _normalizeWindowsPath(String path) {
  var normalized = path.replaceAll('/', r'\');
  while (normalized.length > 3 && normalized.endsWith(r'\')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.toLowerCase();
}
