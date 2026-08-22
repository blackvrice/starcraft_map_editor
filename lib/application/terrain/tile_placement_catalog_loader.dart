import 'dart:typed_data';

import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';
import '../ports/starcraft_tile_atlas_gateway.dart';

abstract final class TilePlacementCatalogDiagnosticCodes {
  static const catalogGatewayFailed = 'SC_CATALOG_TILE_GATEWAY_FAILED';
  static const atlasGatewayFailed = 'SC_CATALOG_TILE_ATLAS_GATEWAY_FAILED';
  static const resultMismatch = 'SC_CATALOG_TILE_RESULT_MISMATCH';
}

final class TilePlacementCatalogBatch {
  TilePlacementCatalogBatch({
    required this.page,
    Map<int, Uint8List> thumbnails = const {},
    List<EditorDiagnostic> diagnostics = const [],
  }) : thumbnails = Map.unmodifiable({
         for (final entry in thumbnails.entries)
           entry.key: Uint8List.fromList(entry.value).asUnmodifiableView(),
       }),
       diagnostics = List.unmodifiable(diagnostics);

  final StarCraftPlacementCatalogPage page;
  final Map<int, Uint8List> thumbnails;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

final class TilePlacementCatalogLoader {
  const TilePlacementCatalogLoader({
    required this.catalogGateway,
    required this.tileAtlasGateway,
  });

  static const rgbaBytesPerThumbnail = 32 * 32 * 4;

  final StarCraftPlacementCatalogGateway catalogGateway;
  final StarCraftTileAtlasGateway tileAtlasGateway;

  Future<TilePlacementCatalogBatch> load(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.kind != StarCraftPlacementKind.tile) {
      throw ArgumentError.value(request.kind, 'request.kind', 'Must be tile.');
    }

    final StarCraftPlacementCatalogPage page;
    try {
      page = await catalogGateway.list(request);
    } catch (error) {
      final diagnostic = _diagnostic(
        code: TilePlacementCatalogDiagnosticCodes.catalogGatewayFailed,
        message: 'The Tile catalog request failed unexpectedly.',
        filePath: request.installationPath,
        remediation: 'Retry or repair the application installation.',
        rawDetails: error.toString(),
      );
      return TilePlacementCatalogBatch(
        page: StarCraftPlacementCatalogPage.failed(
          request: request,
          diagnostic: diagnostic,
        ),
        diagnostics: [diagnostic],
      );
    }
    if (!_sameCatalogRequest(page.request, request)) {
      return _mismatch(page, request);
    }
    if (!page.isSuccess || page.entries.isEmpty) {
      return TilePlacementCatalogBatch(
        page: page,
        diagnostics: page.diagnostics,
      );
    }

    final rawValues = [for (final entry in page.entries) entry.key.id];
    final atlasRequest = StarCraftTileAtlasRequest(
      installationPath: request.installationPath,
      tileset: request.tileset,
      rawValues: rawValues,
    );
    final StarCraftTileAtlasResult atlas;
    try {
      atlas = await tileAtlasGateway.render(atlasRequest);
    } catch (error) {
      return TilePlacementCatalogBatch(
        page: page,
        diagnostics: [
          _diagnostic(
            code: TilePlacementCatalogDiagnosticCodes.atlasGatewayFailed,
            message: 'The Tile thumbnail request failed unexpectedly.',
            filePath: request.installationPath,
            remediation: 'Retry or repair the application installation.',
            rawDetails: error.toString(),
          ),
        ],
      );
    }
    if (!_sameAtlasRequest(atlas.request, atlasRequest) ||
        !atlas.isSuccess ||
        atlas.unsupportedRawValues.isNotEmpty ||
        !_sameValues(atlas.rawValues, rawValues) ||
        atlas.storageProduct != page.storageProduct ||
        atlas.storageBuildNumber != page.storageBuildNumber ||
        atlas.helperVersion != page.helperVersion ||
        atlas.cascLibRevision != page.cascLibRevision) {
      if (atlas.diagnostics.isNotEmpty) {
        return TilePlacementCatalogBatch(
          page: page,
          diagnostics: atlas.diagnostics,
        );
      }
      return _mismatch(page, request);
    }

    final thumbnails = <int, Uint8List>{};
    for (var index = 0; index < atlas.rawValues.length; index++) {
      final start = index * rgbaBytesPerThumbnail;
      thumbnails[atlas.rawValues[index]] = Uint8List.fromList(
        atlas.rgbaBytes.sublist(start, start + rgbaBytesPerThumbnail),
      );
    }
    return TilePlacementCatalogBatch(page: page, thumbnails: thumbnails);
  }

  TilePlacementCatalogBatch _mismatch(
    StarCraftPlacementCatalogPage page,
    StarCraftPlacementCatalogRequest request,
  ) => TilePlacementCatalogBatch(
    page: page,
    diagnostics: [
      _diagnostic(
        code: TilePlacementCatalogDiagnosticCodes.resultMismatch,
        message: 'The Tile catalog and thumbnail results did not match.',
        filePath: request.installationPath,
        remediation: 'Repair the application or report the helper error.',
      ),
    ],
  );
}

bool _sameCatalogRequest(
  StarCraftPlacementCatalogRequest left,
  StarCraftPlacementCatalogRequest right,
) =>
    left.operationId == right.operationId &&
    _normalizeWindowsPath(left.installationPath) ==
        _normalizeWindowsPath(right.installationPath) &&
    left.kind == right.kind &&
    left.tileset == right.tileset &&
    left.offset == right.offset &&
    left.limit == right.limit;

bool _sameAtlasRequest(
  StarCraftTileAtlasRequest left,
  StarCraftTileAtlasRequest right,
) =>
    _normalizeWindowsPath(left.installationPath) ==
        _normalizeWindowsPath(right.installationPath) &&
    left.tileset == right.tileset &&
    _sameValues(left.rawValues, right.rawValues);

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

EditorDiagnostic _diagnostic({
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) => EditorDiagnostic(
  code: code,
  message: message,
  severity: DiagnosticSeverity.warning,
  stage: DiagnosticStage.validate,
  filePath: filePath,
  remediation: remediation,
  rawDetails: rawDetails,
);
