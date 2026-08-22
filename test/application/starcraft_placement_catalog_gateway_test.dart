import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';

void main() {
  group('StarCraftPlacementCatalogKey', () {
    test('uses stable kind-specific IDs including doodad variants', () {
      final tile = StarCraftPlacementCatalogKey.tile(
        tileset: StarCraftTilesetAssetSet.jungle,
        rawValue: 123,
      );
      final doodad = StarCraftPlacementCatalogKey.doodad(
        tileset: StarCraftTilesetAssetSet.jungle,
        doodadId: 7,
        startTileGroup: 240,
      );

      expect(tile.stableId, 'tile:4:123');
      expect(doodad.stableId, 'doodad:4:7:240');
      expect(StarCraftPlacementCatalogKey.unit(37).stableId, 'unit:37');
      expect(
        StarCraftPlacementCatalogKey.pureSprite(130).stableId,
        'pureSprite:130',
      );
      expect(
        StarCraftPlacementCatalogKey.spriteUnit(37).stableId,
        'spriteUnit:37',
      );
      expect(tile.compareTo(doodad), lessThan(0));
      expect(() => StarCraftPlacementCatalogKey.unit(-1), throwsRangeError);
      expect(
        () => StarCraftPlacementCatalogKey.pureSprite(0x10000),
        throwsRangeError,
      );
      expect(
        () => StarCraftPlacementCatalogKey.doodad(
          tileset: StarCraftTilesetAssetSet.jungle,
          doodadId: 7,
          startTileGroup: -1,
        ),
        throwsRangeError,
      );
    });
  });

  group('StarCraftPlacementCatalogEntry', () {
    test('uses verified names and safe numeric fallbacks', () {
      final named = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.unit(37),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.placeable,
        verifiedName: '  Terran SCV  ',
      );
      final blank = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.pureSprite(130),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.placeable,
        verifiedName: '   ',
      );
      final controlCharacter = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.tile(
          tileset: StarCraftTilesetAssetSet.badlands,
          rawValue: 12,
        ),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.placeable,
        verifiedName: 'Bad\nName',
      );
      final tooLong = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.doodad(
          tileset: StarCraftTilesetAssetSet.jungle,
          doodadId: 7,
          startTileGroup: 240,
        ),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.placeable,
        verifiedName: List.filled(129, 'x').join(),
      );

      expect(named.verifiedName, 'Terran SCV');
      expect(named.displayName, 'Terran SCV');
      expect(blank.displayName, 'Sprite #130');
      expect(controlCharacter.displayName, 'Tile #12');
      expect(tooLong.displayName, 'Doodad #7');
      expect(named.thumbnailKey, 'unit:37');
    });

    test('copies categories and requires unavailable item diagnostics', () {
      final categories = ['Terran', 'Workers'];
      final entry = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.unit(7),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.unsupported,
        categoryPath: categories,
        issue: StarCraftPlacementCatalogIssue(
          code: 'SC_CATALOG_ITEM_UNSUPPORTED_RELATION',
          message: 'Relation defaults are not verified.',
        ),
      );
      categories[0] = 'Changed';

      expect(entry.categoryPath, ['Terran', 'Workers']);
      expect(entry.isPlaceable, isFalse);
      expect(() => entry.categoryPath.add('Changed'), throwsUnsupportedError);
      expect(
        () => StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(8),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.invalid,
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(8),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
          categoryPath: List.filled(9, 'Category'),
        ),
        throwsRangeError,
      );
      expect(
        () => StarCraftPlacementCatalogIssue(
          code: 'UNSTABLE_CODE',
          message: 'Invalid.',
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(8),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_INVALID',
            message: 'Invalid.',
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(8),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
          categoryPath: const ['Bad\nCategory'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('StarCraftPlacementCatalogRequest', () {
    test('bounds operation IDs and page windows', () {
      final request = _request();
      expect(request.offset, 0);
      expect(request.limit, 128);

      for (final invalid in [
        _requestFactory(operationId: 'bad id'),
        _requestFactory(offset: -1),
        _requestFactory(offset: 0x10000),
        _requestFactory(limit: 0),
        _requestFactory(limit: 257),
      ]) {
        expect(invalid, throwsArgumentError);
      }
    });
  });

  group('StarCraftPlacementCatalogPage', () {
    test('requires a sorted request-matching immutable page', () {
      final request = _request(limit: 2);
      final sourceEntries = [_unitEntry(7), _unitEntry(8, name: 'Terran SCV')];
      final page = StarCraftPlacementCatalogPage(
        request: request,
        totalEntries: 3,
        entries: sourceEntries,
        storageProduct: 's1',
        storageBuildNumber: 13515,
        helperVersion: '0.5.0',
        cascLibRevision: 'pinned-casc',
        totalMetadataBytes: 64,
      );
      sourceEntries.clear();

      expect(page.entries, hasLength(2));
      expect(page.nextOffset, 2);
      expect(page.isSuccess, isTrue);
      expect(() => page.entries.clear(), throwsUnsupportedError);

      expect(
        () => StarCraftPlacementCatalogPage(
          request: request,
          totalEntries: 2,
          entries: [_unitEntry(8), _unitEntry(7)],
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftPlacementCatalogPage(
          request: request,
          totalEntries: 1,
          entries: [
            StarCraftPlacementCatalogEntry(
              key: StarCraftPlacementCatalogKey.pureSprite(7),
              source: StarCraftPlacementCatalogSource.localData,
              availability: StarCraftPlacementAvailability.placeable,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => StarCraftPlacementCatalogPage(
          request: request,
          totalEntries: 1,
          entries: [
            StarCraftPlacementCatalogEntry(
              key: StarCraftPlacementCatalogKey.unit(7),
              source: StarCraftPlacementCatalogSource.mapTemplate,
              availability: StarCraftPlacementAvailability.placeable,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'failed pages preserve structured diagnostics and work with a fake',
      () async {
        final request = _request();
        final diagnostic = const EditorDiagnostic(
          code: StarCraftPlacementCatalogDiagnosticCodes.listingFailed,
          message: 'Catalog listing failed.',
          severity: DiagnosticSeverity.warning,
          stage: DiagnosticStage.validate,
        );
        final gateway = _FakeCatalogGateway(
          StarCraftPlacementCatalogPage.failed(
            request: request,
            diagnostic: diagnostic,
          ),
        );

        final result = await gateway.list(request);
        await gateway.cancel(request.operationId);

        expect(result.isSuccess, isFalse);
        expect(result.entries, isEmpty);
        expect(result.diagnostics.single, same(diagnostic));
        expect(gateway.requests, [request]);
        expect(gateway.cancelledOperationIds, [request.operationId]);
      },
    );
  });
}

StarCraftPlacementCatalogRequest _request({int limit = 128}) {
  return StarCraftPlacementCatalogRequest(
    operationId: 'catalog-test',
    installationPath: r'C:\Games\StarCraft',
    kind: StarCraftPlacementKind.unit,
    tileset: StarCraftTilesetAssetSet.jungle,
    limit: limit,
  );
}

Object Function() _requestFactory({
  String operationId = 'catalog-test',
  int offset = 0,
  int limit = 128,
}) {
  return () => StarCraftPlacementCatalogRequest(
    operationId: operationId,
    installationPath: r'C:\Games\StarCraft',
    kind: StarCraftPlacementKind.unit,
    tileset: StarCraftTilesetAssetSet.jungle,
    offset: offset,
    limit: limit,
  );
}

StarCraftPlacementCatalogEntry _unitEntry(int id, {String? name}) {
  return StarCraftPlacementCatalogEntry(
    key: StarCraftPlacementCatalogKey.unit(id),
    source: StarCraftPlacementCatalogSource.localData,
    availability: StarCraftPlacementAvailability.placeable,
    verifiedName: name,
  );
}

final class _FakeCatalogGateway implements StarCraftPlacementCatalogGateway {
  _FakeCatalogGateway(this.page);

  final StarCraftPlacementCatalogPage page;
  final List<StarCraftPlacementCatalogRequest> requests = [];
  final List<String> cancelledOperationIds = [];

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    requests.add(request);
    return page;
  }

  @override
  Future<void> cancel(String operationId) async {
    cancelledOperationIds.add(operationId);
  }
}
