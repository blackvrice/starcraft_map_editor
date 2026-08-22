import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/objects/object_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/terrain/tile_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';

void main() {
  final helperPath = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final installationPath = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final canRun =
      Platform.isWindows &&
      helperPath != null &&
      helperPath.isNotEmpty &&
      installationPath != null &&
      installationPath.isNotEmpty;

  test(
    'bundled CascLib helper inspects the installed StarCraft storage',
    () async {
      final inspector = ProcessStarCraftDataAssetInspector(
        helperExecutablePath: helperPath!,
        timeout: const Duration(seconds: 30),
      );

      final result = await inspector.inspect(installationPath!);

      expect(
        result.isReady,
        isTrue,
        reason: result.diagnostics
            .map(
              (diagnostic) =>
                  '${diagnostic.code}: ${diagnostic.message} '
                  '${diagnostic.rawDetails ?? ''}',
            )
            .join('\n'),
      );
      expect(result.storageProduct, isNotEmpty);
      expect(result.storageBuildNumber, greaterThanOrEqualTo(0));
      expect(
        result.cascLibRevision,
        ProcessStarCraftDataAssetInspector.cascLibRevision,
      );
      expect(result.totalAssetBytes, greaterThan(0));
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );

  test(
    'bundled CascLib helper renders fixed assets for every tileset',
    () async {
      final gateway = ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: helperPath!,
        timeout: const Duration(seconds: 30),
      );
      for (final tileset in StarCraftTilesetAssetSet.values) {
        final request = StarCraftTileAtlasRequest(
          installationPath: installationPath!,
          tileset: tileset,
          rawValues: const [0, 1, 0x4000],
        );

        final result = await gateway.render(request);

        expect(
          result.isSuccess,
          isTrue,
          reason: result.diagnostics
              .map(
                (diagnostic) =>
                    '${diagnostic.code}: ${diagnostic.message} '
                    '${diagnostic.rawDetails ?? ''}',
              )
              .join('\n'),
        );
        expect(result.storageProduct, isNotEmpty);
        expect(result.storageBuildNumber, greaterThanOrEqualTo(0));
        expect(result.totalAssetBytes, greaterThan(0));
        expect(result.rawValues, const [0, 1, 0x4000]);
        expect(result.columns, 3);
        expect(result.rows, 1);
        expect(result.rgbaBytes, hasLength(3 * 32 * 32 * 4));
        expect(result.rgbaBytes[3], 0xFF);
        expect(result.unsupportedRawValues, isEmpty);
      }
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );

  test(
    'bundled helper supplies Tile catalog thumbnails for every tileset',
    () async {
      final loader = TilePlacementCatalogLoader(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: helperPath!,
          timeout: const Duration(seconds: 30),
        ),
        tileAtlasGateway: ProcessStarCraftTileAtlasGateway(
          helperExecutablePath: helperPath,
          timeout: const Duration(seconds: 30),
        ),
      );
      for (final tileset in StarCraftTilesetAssetSet.values) {
        final result = await loader.load(
          StarCraftPlacementCatalogRequest(
            operationId: 'bundled-tile-catalog-${tileset.rawValue}',
            installationPath: installationPath!,
            kind: StarCraftPlacementKind.tile,
            tileset: tileset,
            limit: 4,
          ),
        );

        expect(
          result.isSuccess,
          isTrue,
          reason: result.diagnostics
              .map(
                (diagnostic) =>
                    '${diagnostic.code}: ${diagnostic.message} '
                    '${diagnostic.rawDetails ?? ''}',
              )
              .join('\n'),
        );
        expect(result.page.totalEntries, greaterThanOrEqualTo(4));
        expect(result.page.entries.map((entry) => entry.key.id), [0, 1, 2, 3]);
        expect(result.thumbnails.keys, [0, 1, 2, 3]);
        for (final thumbnail in result.thumbnails.values) {
          expect(thumbnail, hasLength(32 * 32 * 4));
          expect(thumbnail[3], 0xFF);
        }
      }
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );

  test(
    'bundled helper supplies Unit and pure Sprite catalog thumbnails',
    () async {
      final loader = ObjectPlacementCatalogLoader(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: helperPath!,
          timeout: const Duration(seconds: 30),
        ),
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: helperPath,
          timeout: const Duration(seconds: 30),
        ),
      );
      for (final catalogRequest in [
        StarCraftPlacementCatalogRequest(
          operationId: 'bundled-unit-catalog',
          installationPath: installationPath!,
          kind: StarCraftPlacementKind.unit,
          tileset: StarCraftTilesetAssetSet.jungle,
          limit: 8,
        ),
        StarCraftPlacementCatalogRequest(
          operationId: 'bundled-sprite-catalog',
          installationPath: installationPath,
          kind: StarCraftPlacementKind.pureSprite,
          tileset: StarCraftTilesetAssetSet.jungle,
          limit: 16,
        ),
      ]) {
        final result = await loader.load(catalogRequest);

        expect(
          result.isSuccess,
          isTrue,
          reason: result.diagnostics
              .map(
                (diagnostic) =>
                    '${diagnostic.code}: ${diagnostic.message} '
                    '${diagnostic.rawDetails ?? ''}',
              )
              .join('\n'),
        );
        expect(
          result.page.totalEntries,
          catalogRequest.kind == StarCraftPlacementKind.unit ? 228 : 517,
        );
        expect(result.page.entries, hasLength(catalogRequest.limit));
        expect(result.page.entries.every((entry) => entry.hasPreview), isTrue);
        expect(
          result.page.entries.every((entry) => !entry.isPlaceable),
          isTrue,
        );
        expect(result.thumbnails, hasLength(catalogRequest.limit));
        for (final thumbnail in result.thumbnails.values) {
          expect(thumbnail.width, greaterThan(0));
          expect(thumbnail.height, greaterThan(0));
          expect(thumbnail.rgbaBytes, isNotEmpty);
          expect(thumbnail.rgbaBytes.where((value) => value != 0), isNotEmpty);
        }
      }
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );

  test(
    'bundled CascLib helper renders unit colors and a pure sprite frame',
    () async {
      final gateway = ProcessStarCraftObjectAtlasGateway(
        helperExecutablePath: helperPath!,
        timeout: const Duration(seconds: 30),
      );
      final request = StarCraftObjectAtlasRequest(
        operationId: 'bundled-object-smoke',
        installationPath: installationPath!,
        tileset: StarCraftTilesetAssetSet.jungle,
        objects: [
          const StarCraftObjectGraphicKey(
            kind: StarCraftObjectGraphicKind.unit,
            id: 0,
            playerColor: 0,
          ),
          const StarCraftObjectGraphicKey(
            kind: StarCraftObjectGraphicKind.unit,
            id: 0,
          ),
          for (var spriteId = 0; spriteId < 16; spriteId++)
            StarCraftObjectGraphicKey(
              kind: StarCraftObjectGraphicKind.sprite,
              id: spriteId,
            ),
        ],
      );

      final result = await gateway.render(request);

      expect(
        result.isSuccess,
        isTrue,
        reason: result.diagnostics
            .map(
              (diagnostic) =>
                  '${diagnostic.code}: ${diagnostic.message} '
                  '${diagnostic.rawDetails ?? ''}',
            )
            .join('\n'),
      );
      final unitEntries = result.entries
          .where((entry) => entry.key.kind == StarCraftObjectGraphicKind.unit)
          .toList(growable: false);
      final spriteEntries = result.entries
          .where((entry) => entry.key.kind == StarCraftObjectGraphicKind.sprite)
          .toList(growable: false);
      expect(unitEntries, hasLength(2));
      expect(
        result.unsupportedObjects.where(
          (unsupported) =>
              unsupported.key.kind == StarCraftObjectGraphicKind.unit,
        ),
        isEmpty,
      );
      expect(unitEntries[0].key.playerColor, 0);
      expect(unitEntries[1].key.playerColor, isNull);
      expect(unitEntries[0].width, unitEntries[1].width);
      expect(unitEntries[0].height, unitEntries[1].height);
      expect(unitEntries[0].rgbaBytes, isNot(equals(unitEntries[1].rgbaBytes)));
      expect(spriteEntries, isNotEmpty);
      expect(spriteEntries.first.width, greaterThan(0));
      expect(spriteEntries.first.height, greaterThan(0));
      expect(spriteEntries.first.rgbaBytes, isNotEmpty);
      expect(
        result.entries
            .expand((entry) => entry.rgbaBytes)
            .where((value) => value != 0),
        isNotEmpty,
      );
      expect(result.totalAssetBytes, greaterThan(0));
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );
}
