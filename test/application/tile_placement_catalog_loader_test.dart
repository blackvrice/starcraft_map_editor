import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/terrain/tile_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  final request = StarCraftPlacementCatalogRequest(
    operationId: 'tile-page',
    installationPath: r'C:\Games\StarCraft',
    kind: StarCraftPlacementKind.tile,
    tileset: StarCraftTilesetAssetSet.jungle,
    limit: 2,
  );

  test('supplies one immutable 32x32 RGBA thumbnail per Tile entry', () async {
    final catalog = _CatalogGateway(_page(request, [0, 1]));
    final atlas = _AtlasGateway(
      (atlasRequest) => _atlas(
        atlasRequest,
        values: const [0, 1],
        pixels: [...List.filled(4096, 11), ...List.filled(4096, 22)],
      ),
    );
    final loader = TilePlacementCatalogLoader(
      catalogGateway: catalog,
      tileAtlasGateway: atlas,
    );

    final result = await loader.load(request);

    expect(result.isSuccess, isTrue);
    expect(result.thumbnails.keys, [0, 1]);
    expect(result.thumbnails[0], everyElement(11));
    expect(result.thumbnails[1], everyElement(22));
    expect(result.thumbnails[0], hasLength(32 * 32 * 4));
    expect(atlas.calls, 1);
  });

  test('does not request an atlas for an exhausted catalog page', () async {
    final exhaustedRequest = StarCraftPlacementCatalogRequest(
      operationId: 'empty',
      installationPath: request.installationPath,
      kind: request.kind,
      tileset: request.tileset,
      offset: 10,
      limit: 2,
    );
    final atlas = _AtlasGateway((_) => throw StateError('must not render'));
    final loader = TilePlacementCatalogLoader(
      catalogGateway: _CatalogGateway(
        StarCraftPlacementCatalogPage(
          request: exhaustedRequest,
          totalEntries: 2,
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.5.0',
          cascLibRevision: 'revision',
        ),
      ),
      tileAtlasGateway: atlas,
    );

    final result = await loader.load(exhaustedRequest);

    expect(result.isSuccess, isTrue);
    expect(result.thumbnails, isEmpty);
    expect(atlas.calls, 0);
  });

  test('rejects unsupported or identity-mismatched atlas output', () async {
    final page = _page(request, [0, 1]);
    final unsupportedLoader = TilePlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      tileAtlasGateway: _AtlasGateway(
        (atlasRequest) => StarCraftTileAtlasResult(
          request: atlasRequest,
          tileSize: 32,
          columns: 1,
          rows: 1,
          rawValues: const [0],
          rgbaBytes: Uint8List(4096),
          unsupportedRawValues: const [1],
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.5.0',
          cascLibRevision: 'revision',
        ),
      ),
    );
    final identityLoader = TilePlacementCatalogLoader(
      catalogGateway: _CatalogGateway(page),
      tileAtlasGateway: _AtlasGateway(
        (atlasRequest) => _atlas(
          atlasRequest,
          values: const [0, 1],
          pixels: List.filled(8192, 1),
          storageBuildNumber: 999,
        ),
      ),
    );

    for (final result in [
      await unsupportedLoader.load(request),
      await identityLoader.load(request),
    ]) {
      expect(result.thumbnails, isEmpty);
      expect(
        result.diagnostics.single.code,
        TilePlacementCatalogDiagnosticCodes.resultMismatch,
      );
    }
  });

  test(
    'preserves gateway diagnostics and catches gateway exceptions',
    () async {
      const diagnostic = EditorDiagnostic(
        code: 'SC_CATALOG_METADATA_INVALID',
        message: 'invalid',
        severity: DiagnosticSeverity.warning,
        stage: DiagnosticStage.validate,
      );
      final failed = TilePlacementCatalogLoader(
        catalogGateway: _CatalogGateway(
          StarCraftPlacementCatalogPage.failed(
            request: request,
            diagnostic: diagnostic,
          ),
        ),
        tileAtlasGateway: _AtlasGateway((_) => throw StateError('unused')),
      );
      final throwing = TilePlacementCatalogLoader(
        catalogGateway: _ThrowingCatalogGateway(),
        tileAtlasGateway: _AtlasGateway((_) => throw StateError('unused')),
      );

      expect((await failed.load(request)).diagnostics.single, same(diagnostic));
      expect(
        (await throwing.load(request)).diagnostics.single.code,
        TilePlacementCatalogDiagnosticCodes.catalogGatewayFailed,
      );
    },
  );
}

StarCraftPlacementCatalogPage _page(
  StarCraftPlacementCatalogRequest request,
  List<int> ids,
) => StarCraftPlacementCatalogPage(
  request: request,
  totalEntries: ids.length,
  entries: [
    for (final id in ids)
      StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.tile(
          tileset: request.tileset,
          rawValue: id,
        ),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.placeable,
      ),
  ],
  storageProduct: 's1',
  storageBuildNumber: 13515,
  helperVersion: '0.5.0',
  cascLibRevision: 'revision',
);

StarCraftTileAtlasResult _atlas(
  StarCraftTileAtlasRequest request, {
  required List<int> values,
  required List<int> pixels,
  int storageBuildNumber = 13515,
}) => StarCraftTileAtlasResult(
  request: request,
  tileSize: 32,
  columns: values.length,
  rows: 1,
  rawValues: values,
  rgbaBytes: Uint8List.fromList(pixels),
  unsupportedRawValues: const [],
  storageProduct: 's1',
  storageBuildNumber: storageBuildNumber,
  helperVersion: '0.5.0',
  cascLibRevision: 'revision',
);

final class _CatalogGateway implements StarCraftPlacementCatalogGateway {
  _CatalogGateway(this.page);

  final StarCraftPlacementCatalogPage page;

  @override
  Future<void> cancel(String operationId) async {}

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

final class _AtlasGateway implements StarCraftTileAtlasGateway {
  _AtlasGateway(this.renderResult);

  final StarCraftTileAtlasResult Function(StarCraftTileAtlasRequest request)
  renderResult;
  int calls = 0;

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    calls++;
    return renderResult(request);
  }
}
