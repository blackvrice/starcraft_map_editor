import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/objects/object_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  final unitRequest = StarCraftPlacementCatalogRequest(
    operationId: 'object-page',
    installationPath: r'C:\Games\StarCraft',
    kind: StarCraftPlacementKind.unit,
    tileset: StarCraftTilesetAssetSet.jungle,
    limit: 3,
  );

  test(
    'supplies variable-size thumbnails only for previewable Units',
    () async {
      final page = _page(
        unitRequest,
        entries: [
          _entry(StarCraftPlacementCatalogKey.unit(0)),
          _entry(StarCraftPlacementCatalogKey.unit(1)),
          _entry(
            StarCraftPlacementCatalogKey.unit(2),
            previewIssueCode: 'SC_CASC_OBJECT_GRP_MISSING',
          ),
        ],
      );
      final atlas = _AtlasGateway(
        (request) => _atlas(
          request,
          entries: [
            _atlasEntry(request.objects[0], width: 2, height: 3, color: 11),
            _atlasEntry(request.objects[1], width: 4, height: 1, color: 22),
          ],
        ),
      );
      final loader = ObjectPlacementCatalogLoader(
        catalogGateway: _CatalogGateway(page),
        objectAtlasGateway: atlas,
      );

      final result = await loader.load(unitRequest);

      expect(result.isSuccess, isTrue);
      expect(atlas.requests.single.operationId, 'object-page.preview');
      expect(atlas.requests.single.objects.map((key) => key.id), [0, 1]);
      expect(result.thumbnails.keys, [
        StarCraftPlacementCatalogKey.unit(0),
        StarCraftPlacementCatalogKey.unit(1),
      ]);
      expect(result.thumbnails[StarCraftPlacementCatalogKey.unit(0)]?.width, 2);
      expect(
        result.thumbnails[StarCraftPlacementCatalogKey.unit(0)]?.height,
        3,
      );
      expect(
        result.thumbnails[StarCraftPlacementCatalogKey.unit(0)]?.rgbaBytes,
        everyElement(11),
      );
      expect(result.page.entries.last.hasPreview, isFalse);
      expect(result.page.entries.every((entry) => !entry.isPlaceable), isTrue);
    },
  );

  test('maps a pure Sprite catalog to sprite atlas keys', () async {
    final request = StarCraftPlacementCatalogRequest(
      operationId: 'sprites',
      installationPath: unitRequest.installationPath,
      kind: StarCraftPlacementKind.pureSprite,
      tileset: unitRequest.tileset,
      offset: 10,
      limit: 1,
    );
    final page = _page(
      request,
      totalEntries: 517,
      entries: [_entry(StarCraftPlacementCatalogKey.pureSprite(10))],
    );
    final atlas = _AtlasGateway(
      (atlasRequest) => _atlas(
        atlasRequest,
        entries: [_atlasEntry(atlasRequest.objects.single)],
      ),
    );
    final result = await ObjectPlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      objectAtlasGateway: atlas,
    ).load(request);

    expect(result.isSuccess, isTrue);
    expect(
      atlas.requests.single.objects.single.kind,
      StarCraftObjectGraphicKind.sprite,
    );
    expect(
      result.thumbnails.keys.single,
      StarCraftPlacementCatalogKey.pureSprite(10),
    );
  });

  test(
    'skips atlas when a page is empty or every preview is unavailable',
    () async {
      final unavailablePage = _page(
        unitRequest,
        entries: [
          _entry(
            StarCraftPlacementCatalogKey.unit(0),
            previewIssueCode: 'SC_CASC_OBJECT_GRP_MISSING',
          ),
        ],
        totalEntries: 1,
      );
      final emptyRequest = StarCraftPlacementCatalogRequest(
        operationId: 'empty',
        installationPath: unitRequest.installationPath,
        kind: StarCraftPlacementKind.unit,
        tileset: unitRequest.tileset,
        offset: 228,
        limit: 3,
      );
      final atlas = _AtlasGateway((_) => throw StateError('must not render'));

      final unavailable = await ObjectPlacementCatalogLoader(
        catalogGateway: _CatalogGateway(unavailablePage),
        objectAtlasGateway: atlas,
      ).load(unitRequest);
      final empty = await ObjectPlacementCatalogLoader(
        catalogGateway: _CatalogGateway(
          _page(emptyRequest, entries: const [], totalEntries: 228),
        ),
        objectAtlasGateway: atlas,
      ).load(emptyRequest);

      expect(unavailable.isSuccess, isTrue);
      expect(unavailable.thumbnails, isEmpty);
      expect(empty.isSuccess, isTrue);
      expect(atlas.requests, isEmpty);
    },
  );

  test('rejects atlas fallback and storage identity mismatches', () async {
    final page = _page(
      unitRequest,
      entries: [_entry(StarCraftPlacementCatalogKey.unit(0))],
      totalEntries: 1,
    );
    final unsupportedLoader = ObjectPlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      objectAtlasGateway: _AtlasGateway(
        (request) => StarCraftObjectAtlasResult(
          request: request,
          entries: const [],
          unsupportedObjects: [
            StarCraftUnsupportedObjectGraphic(
              key: request.objects.single,
              code: 'SC_CASC_OBJECT_GRP_MISSING',
            ),
          ],
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.7.0',
          cascLibRevision: 'revision',
        ),
      ),
    );
    final identityLoader = ObjectPlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      objectAtlasGateway: _AtlasGateway(
        (request) => _atlas(
          request,
          entries: [_atlasEntry(request.objects.single)],
          storageBuildNumber: 999,
        ),
      ),
    );

    for (final result in [
      await unsupportedLoader.load(unitRequest),
      await identityLoader.load(unitRequest),
    ]) {
      expect(result.thumbnails, isEmpty);
      expect(
        result.diagnostics.single.code,
        ObjectPlacementCatalogDiagnosticCodes.resultMismatch,
      );
    }
  });

  test(
    'preserves failures and cancels catalog plus derived atlas operation',
    () async {
      const diagnostic = EditorDiagnostic(
        code: 'SC_CATALOG_METADATA_INVALID',
        message: 'invalid',
        severity: DiagnosticSeverity.warning,
        stage: DiagnosticStage.validate,
      );
      final failedCatalog = _CatalogGateway(
        StarCraftPlacementCatalogPage.failed(
          request: unitRequest,
          diagnostic: diagnostic,
        ),
      );
      final atlas = _AtlasGateway((_) => throw StateError('unused'));
      final loader = ObjectPlacementCatalogLoader(
        catalogGateway: failedCatalog,
        objectAtlasGateway: atlas,
      );

      final failed = await loader.load(unitRequest);
      await loader.cancel(unitRequest.operationId);

      expect(failed.diagnostics.single, same(diagnostic));
      expect(failedCatalog.cancelled, ['object-page']);
      expect(atlas.cancelled, ['object-page.preview']);
    },
  );

  test('catches catalog and atlas gateway exceptions', () async {
    final catalogFailure = await ObjectPlacementCatalogLoader(
      catalogGateway: _ThrowingCatalogGateway(),
      objectAtlasGateway: _AtlasGateway((_) => throw StateError('unused')),
    ).load(unitRequest);
    final page = _page(
      unitRequest,
      entries: [_entry(StarCraftPlacementCatalogKey.unit(0))],
      totalEntries: 1,
    );
    final atlasFailure = await ObjectPlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      objectAtlasGateway: _AtlasGateway((_) => throw StateError('boom')),
    ).load(unitRequest);

    expect(
      catalogFailure.diagnostics.single.code,
      ObjectPlacementCatalogDiagnosticCodes.catalogGatewayFailed,
    );
    expect(
      atlasFailure.diagnostics.single.code,
      ObjectPlacementCatalogDiagnosticCodes.atlasGatewayFailed,
    );
  });
}

StarCraftPlacementCatalogEntry _entry(
  StarCraftPlacementCatalogKey key, {
  String? previewIssueCode,
}) => StarCraftPlacementCatalogEntry(
  key: key,
  source: StarCraftPlacementCatalogSource.localData,
  availability: StarCraftPlacementAvailability.unsupported,
  issue: StarCraftPlacementCatalogIssue(
    code: previewIssueCode == null
        ? 'SC_CATALOG_ITEM_PLACEMENT_FACTORY_PENDING'
        : 'SC_CATALOG_ITEM_OBJECT_GRAPHIC_UNAVAILABLE',
    message: previewIssueCode == null
        ? 'Placement defaults are not implemented yet.'
        : 'The local object preview is unavailable.',
  ),
  previewIssueCode: previewIssueCode,
);

StarCraftPlacementCatalogPage _page(
  StarCraftPlacementCatalogRequest request, {
  required List<StarCraftPlacementCatalogEntry> entries,
  int? totalEntries,
}) => StarCraftPlacementCatalogPage(
  request: request,
  totalEntries: totalEntries ?? entries.length,
  entries: entries,
  storageProduct: 's1',
  storageBuildNumber: 13515,
  helperVersion: '0.7.0',
  cascLibRevision: 'revision',
);

StarCraftObjectAtlasResult _atlas(
  StarCraftObjectAtlasRequest request, {
  required List<StarCraftObjectAtlasEntry> entries,
  int storageBuildNumber = 13515,
}) => StarCraftObjectAtlasResult(
  request: request,
  entries: entries,
  unsupportedObjects: const [],
  storageProduct: 's1',
  storageBuildNumber: storageBuildNumber,
  helperVersion: '0.7.0',
  cascLibRevision: 'revision',
);

StarCraftObjectAtlasEntry _atlasEntry(
  StarCraftObjectGraphicKey key, {
  int width = 2,
  int height = 2,
  int color = 1,
}) => StarCraftObjectAtlasEntry(
  key: key,
  spriteId: key.id,
  imageId: key.id,
  width: width,
  height: height,
  anchorX: -1,
  anchorY: 1,
  frameIndex: 0,
  rgbaBytes: Uint8List.fromList(List.filled(width * height * 4, color)),
);

final class _CatalogGateway implements StarCraftPlacementCatalogGateway {
  _CatalogGateway(this.page);

  final StarCraftPlacementCatalogPage page;
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String operationId) async => cancelled.add(operationId);

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async => page;
}

final class _ThrowingCatalogGateway
    implements StarCraftPlacementCatalogGateway {
  @override
  Future<void> cancel(String operationId) async {}

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) => throw StateError('boom');
}

final class _AtlasGateway implements StarCraftObjectAtlasGateway {
  _AtlasGateway(this.renderer);

  final StarCraftObjectAtlasResult Function(StarCraftObjectAtlasRequest)
  renderer;
  final List<StarCraftObjectAtlasRequest> requests = [];
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String operationId) async => cancelled.add(operationId);

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    requests.add(request);
    return renderer(request);
  }
}
