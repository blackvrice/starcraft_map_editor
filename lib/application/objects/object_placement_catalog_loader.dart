import 'dart:typed_data';

import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/starcraft_object_atlas_gateway.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';

abstract final class ObjectPlacementCatalogDiagnosticCodes {
  static const catalogGatewayFailed = 'SC_CATALOG_OBJECT_GATEWAY_FAILED';
  static const atlasGatewayFailed = 'SC_CATALOG_OBJECT_ATLAS_GATEWAY_FAILED';
  static const resultMismatch = 'SC_CATALOG_OBJECT_RESULT_MISMATCH';
}

final class ObjectPlacementCatalogThumbnail {
  ObjectPlacementCatalogThumbnail({
    required this.catalogKey,
    required this.spriteId,
    required this.imageId,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
    required this.frameIndex,
    required Uint8List rgbaBytes,
  }) : rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView();

  factory ObjectPlacementCatalogThumbnail.fromAtlasEntry({
    required StarCraftPlacementCatalogKey catalogKey,
    required StarCraftObjectAtlasEntry entry,
  }) => ObjectPlacementCatalogThumbnail(
    catalogKey: catalogKey,
    spriteId: entry.spriteId,
    imageId: entry.imageId,
    width: entry.width,
    height: entry.height,
    anchorX: entry.anchorX,
    anchorY: entry.anchorY,
    frameIndex: entry.frameIndex,
    rgbaBytes: entry.rgbaBytes,
  );

  final StarCraftPlacementCatalogKey catalogKey;
  final int spriteId;
  final int imageId;
  final int width;
  final int height;
  final int anchorX;
  final int anchorY;
  final int frameIndex;
  final Uint8List rgbaBytes;
}

final class ObjectPlacementCatalogBatch {
  ObjectPlacementCatalogBatch({
    required this.page,
    Map<StarCraftPlacementCatalogKey, ObjectPlacementCatalogThumbnail>
        thumbnails =
        const {},
    List<EditorDiagnostic> diagnostics = const [],
  }) : thumbnails = Map.unmodifiable(thumbnails),
       diagnostics = List.unmodifiable(diagnostics);

  final StarCraftPlacementCatalogPage page;
  final Map<StarCraftPlacementCatalogKey, ObjectPlacementCatalogThumbnail>
  thumbnails;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

final class ObjectPlacementCatalogLoader {
  const ObjectPlacementCatalogLoader({
    required this.catalogGateway,
    required this.objectAtlasGateway,
  });

  final StarCraftPlacementCatalogGateway catalogGateway;
  final StarCraftObjectAtlasGateway objectAtlasGateway;

  Future<ObjectPlacementCatalogBatch> load(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.kind != StarCraftPlacementKind.unit &&
        request.kind != StarCraftPlacementKind.pureSprite) {
      throw ArgumentError.value(
        request.kind,
        'request.kind',
        'Must be unit or pureSprite.',
      );
    }

    final StarCraftPlacementCatalogPage page;
    try {
      page = await catalogGateway.list(request);
    } catch (error) {
      final diagnostic = _diagnostic(
        code: ObjectPlacementCatalogDiagnosticCodes.catalogGatewayFailed,
        message: 'The object catalog request failed unexpectedly.',
        filePath: request.installationPath,
        remediation: 'Retry or repair the application installation.',
        rawDetails: error.toString(),
      );
      return ObjectPlacementCatalogBatch(
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
      return ObjectPlacementCatalogBatch(
        page: page,
        diagnostics: page.diagnostics,
      );
    }

    final previewable = page.entries
        .where((entry) => entry.hasPreview)
        .toList(growable: false);
    if (previewable.isEmpty) {
      return ObjectPlacementCatalogBatch(page: page);
    }
    final atlasOperationId = _previewOperationId(request.operationId);
    final atlasRequest = StarCraftObjectAtlasRequest(
      operationId: atlasOperationId,
      installationPath: request.installationPath,
      tileset: request.tileset,
      objects: [for (final entry in previewable) _graphicKey(entry.key)],
    );

    final StarCraftObjectAtlasResult atlas;
    try {
      atlas = await objectAtlasGateway.render(atlasRequest);
    } catch (error) {
      return ObjectPlacementCatalogBatch(
        page: page,
        diagnostics: [
          _diagnostic(
            code: ObjectPlacementCatalogDiagnosticCodes.atlasGatewayFailed,
            message: 'The object thumbnail request failed unexpectedly.',
            filePath: request.installationPath,
            remediation: 'Retry or repair the application installation.',
            rawDetails: error.toString(),
          ),
        ],
      );
    }
    if (!_sameAtlasRequest(atlas.request, atlasRequest) ||
        !atlas.isSuccess ||
        atlas.unsupportedObjects.isNotEmpty ||
        atlas.entries.length != previewable.length ||
        atlas.storageProduct != page.storageProduct ||
        atlas.storageBuildNumber != page.storageBuildNumber ||
        atlas.helperVersion != page.helperVersion ||
        atlas.cascLibRevision != page.cascLibRevision) {
      if (atlas.diagnostics.isNotEmpty) {
        return ObjectPlacementCatalogBatch(
          page: page,
          diagnostics: atlas.diagnostics,
        );
      }
      return _mismatch(page, request);
    }

    final thumbnails =
        <StarCraftPlacementCatalogKey, ObjectPlacementCatalogThumbnail>{};
    for (var index = 0; index < atlas.entries.length; index++) {
      final catalogEntry = previewable[index];
      final atlasEntry = atlas.entries[index];
      if (atlasEntry.key != _graphicKey(catalogEntry.key)) {
        return _mismatch(page, request);
      }
      thumbnails[catalogEntry.key] =
          ObjectPlacementCatalogThumbnail.fromAtlasEntry(
            catalogKey: catalogEntry.key,
            entry: atlasEntry,
          );
    }
    return ObjectPlacementCatalogBatch(page: page, thumbnails: thumbnails);
  }

  Future<void> cancel(String operationId) async {
    await catalogGateway.cancel(operationId);
    await objectAtlasGateway.cancel(_previewOperationId(operationId));
  }

  ObjectPlacementCatalogBatch _mismatch(
    StarCraftPlacementCatalogPage page,
    StarCraftPlacementCatalogRequest request,
  ) => ObjectPlacementCatalogBatch(
    page: page,
    diagnostics: [
      _diagnostic(
        code: ObjectPlacementCatalogDiagnosticCodes.resultMismatch,
        message: 'The object catalog and thumbnail results did not match.',
        filePath: request.installationPath,
        remediation: 'Repair the application or report the helper error.',
      ),
    ],
  );
}

StarCraftObjectGraphicKey _graphicKey(StarCraftPlacementCatalogKey key) =>
    StarCraftObjectGraphicKey(
      kind: key.kind == StarCraftPlacementKind.unit
          ? StarCraftObjectGraphicKind.unit
          : StarCraftObjectGraphicKind.sprite,
      id: key.id,
    );

String _previewOperationId(String catalogOperationId) {
  const suffix = '.preview';
  final prefixLength =
      StarCraftPlacementCatalogRequest.maximumOperationIdLength - suffix.length;
  final prefix = catalogOperationId.length <= prefixLength
      ? catalogOperationId
      : catalogOperationId.substring(0, prefixLength);
  return '$prefix$suffix';
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
  StarCraftObjectAtlasRequest left,
  StarCraftObjectAtlasRequest right,
) =>
    left.operationId == right.operationId &&
    _normalizeWindowsPath(left.installationPath) ==
        _normalizeWindowsPath(right.installationPath) &&
    left.tileset == right.tileset &&
    _sameGraphicKeys(left.objects, right.objects);

bool _sameGraphicKeys(
  List<StarCraftObjectGraphicKey> left,
  List<StarCraftObjectGraphicKey> right,
) {
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
