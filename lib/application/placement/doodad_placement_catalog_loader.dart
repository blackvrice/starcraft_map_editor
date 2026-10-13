import 'dart:typed_data';

import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/starcraft_object_atlas_gateway.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';
import '../ports/starcraft_tile_atlas_gateway.dart';
import 'catalog_thumbnail_pixels.dart';
import 'doodad_thumbnail_composer.dart';

abstract final class DoodadCatalogPreviewCodes {
  static const unavailable = 'SC_CATALOG_DOODAD_PREVIEW_UNAVAILABLE';
  static const limitExceeded = 'SC_CATALOG_DOODAD_PREVIEW_LIMIT_EXCEEDED';
  static const resultMismatch = 'SC_CATALOG_DOODAD_PREVIEW_RESULT_MISMATCH';
  static const gatewayFailed = 'SC_CATALOG_DOODAD_PREVIEW_GATEWAY_FAILED';
  static const cancelled = 'SC_CATALOG_DOODAD_PREVIEW_CANCELLED';
}

final class DoodadPlacementCatalogBatch {
  DoodadPlacementCatalogBatch({
    required this.page,
    Map<StarCraftPlacementCatalogKey, CatalogThumbnailPixels> thumbnails =
        const {},
    Map<StarCraftPlacementCatalogKey, String> previewIssues = const {},
    List<EditorDiagnostic> diagnostics = const [],
    List<EditorDiagnostic> previewDiagnostics = const [],
  }) : thumbnails = Map.unmodifiable(thumbnails),
       previewIssues = Map.unmodifiable(previewIssues),
       diagnostics = List.unmodifiable(diagnostics),
       previewDiagnostics = List.unmodifiable(previewDiagnostics);

  final StarCraftPlacementCatalogPage page;
  final Map<StarCraftPlacementCatalogKey, CatalogThumbnailPixels> thumbnails;
  final Map<StarCraftPlacementCatalogKey, String> previewIssues;
  final List<EditorDiagnostic> diagnostics;
  final List<EditorDiagnostic> previewDiagnostics;
}

/// A read-only catalog projection. Preview failures never rewrite placement
/// availability, recipe bytes, or the current map.
final class DoodadPlacementCatalogLoader {
  const DoodadPlacementCatalogLoader({
    required this.catalogGateway,
    this.tileAtlasGateway,
    this.objectAtlasGateway,
  });

  static const maximumPreviewTiles = StarCraftTileAtlasRequest.maximumRawValues;
  final StarCraftPlacementCatalogGateway catalogGateway;
  final StarCraftTileAtlasGateway? tileAtlasGateway;
  final StarCraftObjectAtlasGateway? objectAtlasGateway;

  Future<DoodadPlacementCatalogBatch> load(
    StarCraftPlacementCatalogRequest request, {
    bool Function()? isCancelled,
  }) async {
    if (request.kind != StarCraftPlacementKind.doodad) {
      throw ArgumentError.value(
        request.kind,
        'request.kind',
        'Must be doodad.',
      );
    }
    if (isCancelled?.call() ?? false) return _cancelled(request);
    final StarCraftPlacementCatalogPage page;
    try {
      page = await catalogGateway.list(request);
    } catch (error) {
      return _failure(
        StarCraftPlacementCatalogPage(request: request, totalEntries: 0),
        DoodadCatalogPreviewCodes.gatewayFailed,
        rawDetails: error.toString(),
        blocksCatalog: true,
      );
    }
    if (isCancelled?.call() ?? false) return _cancelled(request);
    if (page.request.operationId != request.operationId ||
        !_samePath(page.request.installationPath, request.installationPath) ||
        page.request.kind != request.kind ||
        page.request.tileset != request.tileset ||
        page.request.offset != request.offset ||
        page.request.limit != request.limit) {
      return _failure(
        StarCraftPlacementCatalogPage(request: request, totalEntries: 0),
        DoodadCatalogPreviewCodes.resultMismatch,
        blocksCatalog: true,
      );
    }
    if (!page.isSuccess || page.entries.isEmpty) {
      return DoodadPlacementCatalogBatch(
        page: page,
        diagnostics: page.diagnostics,
      );
    }
    final issues = <StarCraftPlacementCatalogKey, String>{};
    final recipes = page.entries.where((e) => e.doodadRecipe != null).toList();
    for (final entry in page.entries.where((e) => e.doodadRecipe == null)) {
      issues[entry.key] =
          entry.doodadRecipeIssueCode ?? DoodadCatalogPreviewCodes.unavailable;
    }
    final values = <int>{
      for (final entry in recipes)
        for (final cell in entry.doodadRecipe!.footprint)
          if (cell.rawTileValue != null) cell.rawTileValue!,
    }.toList()..sort();
    if (values.isEmpty) {
      return DoodadPlacementCatalogBatch(page: page, previewIssues: issues);
    }
    if (values.length > maximumPreviewTiles || tileAtlasGateway == null) {
      for (final entry in recipes) {
        issues[entry.key] = values.length > maximumPreviewTiles
            ? DoodadCatalogPreviewCodes.limitExceeded
            : DoodadCatalogPreviewCodes.unavailable;
      }
      return DoodadPlacementCatalogBatch(page: page, previewIssues: issues);
    }
    final tileRequest = StarCraftTileAtlasRequest(
      installationPath: request.installationPath,
      tileset: request.tileset,
      rawValues: values,
    );
    final tiles = <int, Uint8List>{};
    try {
      final atlas = await tileAtlasGateway!.render(tileRequest);
      if (isCancelled?.call() ?? false) return _cancelled(request);
      if (!_samePath(
            atlas.request.installationPath,
            request.installationPath,
          ) ||
          atlas.request.tileset != request.tileset ||
          !_sameList(atlas.request.rawValues, values)) {
        return _failure(page, DoodadCatalogPreviewCodes.resultMismatch);
      }
      if (!atlas.isSuccess) {
        return _failure(
          page,
          DoodadCatalogPreviewCodes.unavailable,
          diagnostics: atlas.diagnostics,
        );
      }
      if (!_sameIdentity(
        page,
        atlas.storageProduct,
        atlas.storageBuildNumber,
        atlas.helperVersion,
        atlas.cascLibRevision,
      )) {
        return _failure(page, DoodadCatalogPreviewCodes.resultMismatch);
      }
      for (var i = 0; i < atlas.rawValues.length; i++) {
        // Borrow only while composing: final thumbnails own their small buffer.
        tiles[atlas.rawValues[i]] = Uint8List.sublistView(
          atlas.rgbaBytes,
          i * 4096,
          (i + 1) * 4096,
        );
      }
    } catch (error) {
      return _failure(
        page,
        DoodadCatalogPreviewCodes.gatewayFailed,
        rawDetails: error.toString(),
      );
    }
    final overlayKeys = <StarCraftObjectGraphicKey>{
      for (final entry in recipes)
        if (entry.doodadRecipe!.overlay case final overlay?)
          DoodadThumbnailComposer.overlayKey(overlay),
    }.toList()..sort();
    final overlays = <StarCraftObjectGraphicKey, StarCraftObjectAtlasEntry>{};
    final overlayIssues = <StarCraftObjectGraphicKey, String>{};
    final diagnostics = <EditorDiagnostic>[];
    if (overlayKeys.isNotEmpty) {
      if (objectAtlasGateway == null) {
        for (final key in overlayKeys) {
          overlayIssues[key] = DoodadCatalogPreviewCodes.unavailable;
        }
      } else {
        final prefix = request.operationId.length > 120
            ? request.operationId.substring(0, 120)
            : request.operationId;
        final overlayRequest = StarCraftObjectAtlasRequest(
          operationId: '$prefix.overlay',
          installationPath: request.installationPath,
          tileset: request.tileset,
          objects: overlayKeys,
        );
        try {
          final atlas = await objectAtlasGateway!.render(overlayRequest);
          if (isCancelled?.call() ?? false) return _cancelled(request);
          final matches =
              atlas.request.operationId == overlayRequest.operationId &&
              _samePath(
                atlas.request.installationPath,
                request.installationPath,
              ) &&
              atlas.request.tileset == request.tileset &&
              _sameList(atlas.request.objects, overlayKeys) &&
              _sameIdentity(
                page,
                atlas.storageProduct,
                atlas.storageBuildNumber,
                atlas.helperVersion,
                atlas.cascLibRevision,
              );
          if (!matches || !atlas.isSuccess) {
            final code = matches
                ? DoodadCatalogPreviewCodes.unavailable
                : DoodadCatalogPreviewCodes.resultMismatch;
            for (final key in overlayKeys) {
              overlayIssues[key] = code;
            }
            diagnostics.addAll(
              atlas.diagnostics.isEmpty
                  ? [_diagnostic(request, code)]
                  : atlas.diagnostics,
            );
          } else {
            for (final entry in atlas.entries) {
              overlays[entry.key] = entry;
            }
            for (final unsupported in atlas.unsupportedObjects) {
              overlayIssues[unsupported.key] = unsupported.code;
            }
          }
        } catch (error) {
          for (final key in overlayKeys) {
            overlayIssues[key] = DoodadCatalogPreviewCodes.gatewayFailed;
          }
          diagnostics.add(
            _diagnostic(
              request,
              DoodadCatalogPreviewCodes.gatewayFailed,
              rawDetails: error.toString(),
            ),
          );
        }
      }
    }
    if (isCancelled?.call() ?? false) return _cancelled(request);
    final thumbnails = <StarCraftPlacementCatalogKey, CatalogThumbnailPixels>{};
    for (final entry in recipes) {
      final recipe = entry.doodadRecipe!;
      if (recipe.footprint.any(
        (c) => c.writesTerrain && !tiles.containsKey(c.rawTileValue),
      )) {
        issues[entry.key] = DoodadCatalogPreviewCodes.unavailable;
        continue;
      }
      final overlayKey = recipe.overlay == null
          ? null
          : DoodadThumbnailComposer.overlayKey(recipe.overlay!);
      if (overlayKey != null && !overlays.containsKey(overlayKey)) {
        issues[entry.key] =
            overlayIssues[overlayKey] ?? DoodadCatalogPreviewCodes.unavailable;
        continue;
      }
      thumbnails[entry.key] = DoodadThumbnailComposer.compose(
        recipe: recipe,
        tiles: tiles,
        overlay: overlays[overlayKey],
      );
    }
    return DoodadPlacementCatalogBatch(
      page: page,
      thumbnails: thumbnails,
      previewIssues: issues,
      previewDiagnostics: diagnostics,
    );
  }

  DoodadPlacementCatalogBatch _cancelled(
    StarCraftPlacementCatalogRequest request,
  ) => _failure(
    StarCraftPlacementCatalogPage(request: request, totalEntries: 0),
    DoodadCatalogPreviewCodes.cancelled,
    blocksCatalog: true,
  );

  DoodadPlacementCatalogBatch _failure(
    StarCraftPlacementCatalogPage page,
    String code, {
    String? rawDetails,
    List<EditorDiagnostic> diagnostics = const [],
    bool blocksCatalog = false,
  }) => DoodadPlacementCatalogBatch(
    page: page,
    previewIssues: {for (final entry in page.entries) entry.key: code},
    diagnostics: blocksCatalog
        ? [_diagnostic(page.request, code, rawDetails: rawDetails)]
        : const [],
    previewDiagnostics: blocksCatalog
        ? const []
        : diagnostics.isEmpty
        ? [_diagnostic(page.request, code, rawDetails: rawDetails)]
        : diagnostics,
  );
}

bool _sameIdentity(
  StarCraftPlacementCatalogPage page,
  String? product,
  int? build,
  String? helper,
  String? revision,
) =>
    page.storageProduct == product &&
    page.storageBuildNumber == build &&
    page.helperVersion == helper &&
    page.cascLibRevision == revision;

bool _samePath(String a, String b) =>
    a.replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '').toLowerCase() ==
    b.replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '').toLowerCase();

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

EditorDiagnostic _diagnostic(
  StarCraftPlacementCatalogRequest request,
  String code, {
  String? rawDetails,
}) => EditorDiagnostic(
  code: code,
  severity: DiagnosticSeverity.warning,
  stage: DiagnosticStage.validate,
  message: 'The local object preview is unavailable.',
  messageId: 'editorTheLocalObjectPreviewIsUnavailable',
  remediation: 'Retry or repair the application installation.',
  remediationId: 'editorRetryOrRepairTheApplicationInstallation',
  filePath: request.installationPath,
  rawDetails: rawDetails,
);
