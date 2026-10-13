import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/catalog_thumbnail_pixels.dart';
import 'package:starcraft_map_editor/application/placement/doodad_placement_catalog_loader.dart';
import 'package:starcraft_map_editor/application/placement/doodad_thumbnail_composer.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';

void main() {
  group('Doodad thumbnail composition', () {
    test(
      'row-major rectangular tiles and holes have exact immutable pixels',
      () {
        final recipe = _recipe(width: 2, height: 2, holes: {3});
        final thumbnail = DoodadThumbnailComposer.compose(
          recipe: recipe,
          tiles: {
            3200: _solid(32, 32, [255, 0, 0, 255]),
            3201: _solid(32, 32, [0, 255, 0, 255]),
            3216: _solid(32, 32, [0, 0, 255, 255]),
          },
        );
        expect([thumbnail.width, thumbnail.height], [64, 64]);
        expect(_pixel(thumbnail, 0, 0), [255, 0, 0, 255]);
        expect(_pixel(thumbnail, 63, 0), [0, 255, 0, 255]);
        expect(_pixel(thumbnail, 0, 63), [0, 0, 255, 255]);
        expect(_pixel(thumbnail, 63, 63), [0, 0, 0, 0]);
        expect(() => thumbnail.rgba[0] = 1, throwsUnsupportedError);
        expect(thumbnail.rgba.buffer.lengthInBytes, 64 * 64 * 4);
      },
    );

    test(
      'overlay uses its anchor at the recipe center and premultiplied alpha',
      () {
        final recipe = _recipe(overlay: DoodadOverlaySemantic.pureSprite);
        final thumbnail = DoodadThumbnailComposer.compose(
          recipe: recipe,
          tiles: {
            3200: _solid(32, 32, [100, 0, 0, 255]),
          },
          overlay: _overlay(
            recipe.overlay!,
            width: 4,
            height: 4,
            anchorX: 1,
            anchorY: 3,
            color: [0, 128, 0, 128],
          ),
        );
        expect(_pixel(thumbnail, 14, 13), [100, 0, 0, 255]);
        expect(_pixel(thumbnail, 15, 13), [50, 128, 0, 255]);
        expect(_pixel(thumbnail, 18, 16), [50, 128, 0, 255]);
        expect(_pixel(thumbnail, 19, 16), [100, 0, 0, 255]);
      },
    );

    test('overlay overhang expands bounds instead of being clipped', () {
      final recipe = _recipe(overlay: DoodadOverlaySemantic.spriteUnit);
      final thumbnail = DoodadThumbnailComposer.compose(
        recipe: recipe,
        tiles: {
          3200: _solid(32, 32, [255, 0, 0, 255]),
        },
        overlay: _overlay(
          recipe.overlay!,
          width: 64,
          height: 16,
          anchorX: 48,
          anchorY: 8,
          color: [0, 255, 0, 255],
        ),
      );
      expect([thumbnail.width, thumbnail.height], [64, 32]);
      expect(_pixel(thumbnail, 0, 0), [0, 0, 0, 0]);
      expect(_pixel(thumbnail, 0, 8), [0, 255, 0, 255]);
      expect(_pixel(thumbnail, 63, 31), [255, 0, 0, 255]);
    });

    test(
      'maximum footprint samples to 64 pixels with correct aspect ratio',
      () {
        final recipe = _recipe(width: 16, height: 8);
        final tiles = {
          for (final c in recipe.footprint)
            c.rawTileValue!: _solid(32, 32, [c.x * 10, c.y * 10, 0, 255]),
        };
        final thumbnail = DoodadThumbnailComposer.compose(
          recipe: recipe,
          tiles: tiles,
        );
        expect([thumbnail.width, thumbnail.height], [64, 32]);
        expect(_pixel(thumbnail, 0, 0), [0, 0, 0, 255]);
        expect(_pixel(thumbnail, 63, 31), [150, 70, 0, 255]);
        expect(
          thumbnail.rgba.length,
          lessThanOrEqualTo(CatalogThumbnailPixels.maximumBytes),
        );
      },
    );

    test('never substitutes a tile or the wrong overlay semantic', () {
      final recipe = _recipe(overlay: DoodadOverlaySemantic.pureSprite);
      final tiles = {
        3200: _solid(32, 32, [0, 0, 0, 255]),
      };
      expect(
        () => DoodadThumbnailComposer.compose(recipe: recipe, tiles: tiles),
        throwsArgumentError,
      );
      expect(
        () => DoodadThumbnailComposer.compose(
          recipe: recipe,
          tiles: {},
          overlay: _overlay(recipe.overlay!),
        ),
        throwsArgumentError,
      );
      expect(
        () => DoodadThumbnailComposer.compose(
          recipe: recipe,
          tiles: tiles,
          overlay: _overlay(
            DoodadOverlayRecipe(
              semantic: DoodadOverlaySemantic.spriteUnit,
              id: 7,
            ),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Doodad catalog loading', () {
    test(
      'deduplicates sorted tiles/overlays and distinguishes Unit from Sprite IDs',
      () async {
        final entries = [
          _entry(_recipe(type: 1, overlay: DoodadOverlaySemantic.pureSprite)),
          _entry(_recipe(type: 2, overlay: DoodadOverlaySemantic.spriteUnit)),
          _entry(_recipe(type: 3, overlay: DoodadOverlaySemantic.pureSprite)),
        ];
        final tiles = _Tiles();
        final objects = _Objects();
        final result = await _loader(entries, tiles, objects).load(_request());
        expect(result.thumbnails.length, 3);
        expect(result.previewIssues, isEmpty);
        expect(result.diagnostics, isEmpty);
        expect(tiles.calls.single.rawValues, [3200]);
        expect(objects.calls.single.objects.map((k) => k.kind), [
          StarCraftObjectGraphicKind.unit,
          StarCraftObjectGraphicKind.sprite,
        ]);
        expect(objects.calls.single.operationId, 'doodad.overlay');
        for (final t in result.thumbnails.values) {
          expect(t.rgba.buffer.lengthInBytes, t.rgba.length);
          expect(() => t.rgba[0] = 1, throwsUnsupportedError);
        }
        expect(() => result.thumbnails.clear(), throwsUnsupportedError);
        expect(result.page.entries.first, same(entries.first));
      },
    );

    test(
      'no overlay means no object helper call and metadata-only remains usable',
      () async {
        final entry = _entry(_recipe());
        final tiles = _Tiles();
        final objects = _Objects();
        final result = await _loader([entry], tiles, objects).load(_request());
        expect(result.thumbnails.length, 1);
        expect(objects.calls, isEmpty);
        final missing = await DoodadPlacementCatalogLoader(
          catalogGateway: _Catalog([entry]),
        ).load(_request());
        expect(missing.thumbnails, isEmpty);
        expect(
          missing.previewIssues[entry.key],
          DoodadCatalogPreviewCodes.unavailable,
        );
        expect(missing.page.entries.single.isPlaceable, isTrue);
      },
    );

    test(
      'unsupported tile removes only affected complete thumbnails',
      () async {
        final entries = [
          _entry(_recipe(type: 1)),
          _entry(_recipe(group: 201, type: 2)),
        ];
        final tiles = _Tiles()..unsupported = {3200};
        final result = await _loader(
          entries,
          tiles,
          _Objects(),
        ).load(_request());
        expect(result.thumbnails.keys, [entries[1].key]);
        expect(result.previewIssues.keys, [entries[0].key]);
        expect(result.page.entries.every((e) => e.isPlaceable), isTrue);
      },
    );

    test(
      'unsupported overlay never leaves a misleading terrain-only image',
      () async {
        final entries = [
          _entry(_recipe(type: 1, overlay: DoodadOverlaySemantic.pureSprite)),
          _entry(_recipe(type: 2)),
        ];
        final objects = _Objects()..unsupported = true;
        final result = await _loader(
          entries,
          _Tiles(),
          objects,
        ).load(_request());
        expect(result.thumbnails.keys, [entries[1].key]);
        expect(
          result.previewIssues[entries[0].key],
          'SC_CASC_OBJECT_GRP_MISSING',
        );
      },
    );

    for (final stage in ['tile', 'overlay']) {
      test('$stage identity mismatch refuses mixed-build pixels', () async {
        final entry = _entry(
          _recipe(overlay: DoodadOverlaySemantic.pureSprite),
        );
        final tiles = _Tiles()..build = stage == 'tile' ? 2 : 1;
        final objects = _Objects()..build = stage == 'overlay' ? 2 : 1;
        final result = await _loader([entry], tiles, objects).load(_request());
        expect(result.thumbnails, isEmpty);
        expect(
          result.previewIssues[entry.key],
          DoodadCatalogPreviewCodes.resultMismatch,
        );
        expect(result.page.entries.single.isPlaceable, isTrue);
      });
      test(
        '$stage thrown failure records raw details and keeps placement recipe',
        () async {
          final entry = _entry(
            _recipe(overlay: DoodadOverlaySemantic.pureSprite),
          );
          final tiles = _Tiles()..throwsError = stage == 'tile';
          final objects = _Objects()..throwsError = stage == 'overlay';
          final result = await _loader(
            [entry],
            tiles,
            objects,
          ).load(_request());
          expect(result.thumbnails, isEmpty);
          expect(
            result.previewDiagnostics.single.rawDetails,
            contains('synthetic failure'),
          );
          expect(
            result.page.entries.single.doodadRecipe,
            same(entry.doodadRecipe),
          );
        },
      );
    }

    test(
      'catalog request mismatch cannot publish unrelated metadata',
      () async {
        final entry = _entry(_recipe());
        final tiles = _Tiles();
        final result = await DoodadPlacementCatalogLoader(
          catalogGateway: _Catalog([entry])..mismatch = true,
          tileAtlasGateway: tiles,
        ).load(_request());
        expect(result.page.entries, isEmpty);
        expect(
          result.diagnostics.single.code,
          DoodadCatalogPreviewCodes.resultMismatch,
        );
        expect(tiles.calls, isEmpty);
      },
    );

    test('missing recipe stays visible without invented preview', () async {
      final entry = StarCraftPlacementCatalogEntry(
        key: StarCraftPlacementCatalogKey.doodad(
          tileset: StarCraftTilesetAssetSet.jungle,
          doodadId: 7,
          startTileGroup: 200,
        ),
        source: StarCraftPlacementCatalogSource.localData,
        availability: StarCraftPlacementAvailability.unsupported,
        issue: StarCraftPlacementCatalogIssue(
          code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
          message: 'Invalid recipe',
        ),
        doodadRecipeIssueCode: 'SC_CASC_DOODAD_TRUNCATED',
      );
      final tiles = _Tiles();
      final result = await _loader([entry], tiles, _Objects()).load(_request());
      expect(result.page.entries.single, same(entry));
      expect(result.previewIssues[entry.key], 'SC_CASC_DOODAD_TRUNCATED');
      expect(tiles.calls, isEmpty);
    });

    for (final stage in ['before', 'catalog', 'tile', 'overlay']) {
      test('$stage cancellation never publishes stale previews', () async {
        var cancelled = stage == 'before';
        final catalog = _Catalog([
          _entry(_recipe(overlay: DoodadOverlaySemantic.pureSprite)),
        ])..after = stage == 'catalog' ? () => cancelled = true : null;
        final tiles = _Tiles()
          ..after = stage == 'tile' ? () => cancelled = true : null;
        final objects = _Objects()
          ..after = stage == 'overlay' ? () => cancelled = true : null;
        final result = await DoodadPlacementCatalogLoader(
          catalogGateway: catalog,
          tileAtlasGateway: tiles,
          objectAtlasGateway: objects,
        ).load(_request(), isCancelled: () => cancelled);
        expect(result.thumbnails, isEmpty);
        expect(result.page.entries, isEmpty);
        expect(
          result.diagnostics.single.code,
          DoodadCatalogPreviewCodes.cancelled,
        );
        if (stage == 'before' || stage == 'catalog') {
          expect(tiles.calls, isEmpty);
        }
        if (stage != 'overlay') expect(objects.calls, isEmpty);
      });
    }

    test(
      'aggregate tile bound rejects before allocating an oversized atlas',
      () async {
        final entries = [
          for (var i = 0; i < 17; i++)
            _entry(
              _recipe(group: 200 + i * 16, type: i, width: 16, height: 16),
            ),
        ];
        final tiles = _Tiles();
        final result = await _loader(
          entries,
          tiles,
          _Objects(),
        ).load(_request());
        expect(tiles.calls, isEmpty);
        expect(result.thumbnails, isEmpty);
        expect(
          result.previewIssues.values,
          everyElement(DoodadCatalogPreviewCodes.limitExceeded),
        );
      },
    );
    test(
      'failed tile response keeps its diagnostic instead of treating missing identity as corruption',
      () async {
        final entry = _entry(_recipe());
        final tiles = _Tiles()..failed = true;
        final result = await _loader(
          [entry],
          tiles,
          _Objects(),
        ).load(_request());
        expect(result.thumbnails, isEmpty);
        expect(
          result.previewDiagnostics.single.code,
          'SC_CASC_TILE_ASSET_MISSING',
        );
        expect(
          result.previewDiagnostics.single.rawDetails,
          'synthetic missing tile',
        );
        expect(result.page.entries.single, same(entry));
      },
    );
  });

  final installation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  test(
    'local CASC renders complete Doodad thumbnails for all eight tilesets',
    () async {
      final loader = DoodadPlacementCatalogLoader(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: helper!,
        ),
        tileAtlasGateway: ProcessStarCraftTileAtlasGateway(
          helperExecutablePath: helper,
        ),
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: helper,
        ),
      );
      for (final tileset in StarCraftTilesetAssetSet.values) {
        final watch = Stopwatch()..start();
        final result = await loader.load(
          StarCraftPlacementCatalogRequest(
            operationId: 'real-doodad-${tileset.index}',
            installationPath: installation!,
            kind: StarCraftPlacementKind.doodad,
            tileset: tileset,
            limit: 16,
          ),
        );
        expect(
          result.diagnostics,
          isEmpty,
          reason: result.diagnostics
              .map((d) => '${d.code} ${d.rawDetails}')
              .join('; '),
        );
        expect(result.thumbnails, isNotEmpty);
        for (final entry in result.page.entries) {
          expect(
            result.thumbnails.containsKey(entry.key) !=
                result.previewIssues.containsKey(entry.key),
            isTrue,
          );
        }
        for (final pixels in result.thumbnails.values) {
          expect(
            pixels.rgba.length,
            lessThanOrEqualTo(CatalogThumbnailPixels.maximumBytes),
          );
          expect(pixels.rgba.any((v) => v != 0), isTrue);
        }
        watch.stop();
        if (result.previewIssues.isNotEmpty) {
          debugPrint(
            'Doodad ${tileset.name} missing: ${result.previewIssues.entries.map((e) => '${e.key.stableId}=${e.value}').join(', ')}',
          );
        }
        debugPrint(
          'Doodad ${tileset.name}: entries=${result.page.entries.length} thumbnails=${result.thumbnails.length} issues=${result.previewIssues.length} bytes=${result.thumbnails.values.fold<int>(0, (n, t) => n + t.rgba.length)} ms=${watch.elapsedMilliseconds}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !Platform.isWindows || installation == null || helper == null
        ? 'Set local CASC helper and installation.'
        : false,
  );
}

StarCraftPlacementCatalogRequest _request() => StarCraftPlacementCatalogRequest(
  operationId: 'doodad',
  installationPath: r'C:\StarCraft',
  kind: StarCraftPlacementKind.doodad,
  tileset: StarCraftTilesetAssetSet.jungle,
);
DoodadPlacementRecipe _recipe({
  int group = 200,
  int type = 7,
  int width = 1,
  int height = 1,
  Set<int> holes = const {},
  DoodadOverlaySemantic? overlay,
}) => DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.jungle,
  startTileGroup: group,
  doodadType: type,
  width: width,
  height: height,
  centerOffsetX: width * 16,
  centerOffsetY: height * 16,
  overlay: overlay == null
      ? null
      : DoodadOverlayRecipe(semantic: overlay, id: 7),
  footprint: [
    for (var i = 0; i < width * height; i++)
      DoodadFootprintCell(
        x: i % width,
        y: i ~/ width,
        rawTileValue: holes.contains(i)
            ? null
            : (group + i ~/ width) * 16 + i % width,
        requiredTileGroup: 0,
      ),
  ],
);
StarCraftPlacementCatalogEntry _entry(DoodadPlacementRecipe recipe) =>
    StarCraftPlacementCatalogEntry(
      key: StarCraftPlacementCatalogKey.doodad(
        tileset: recipe.tileset,
        doodadId: recipe.doodadType,
        startTileGroup: recipe.startTileGroup,
      ),
      source: StarCraftPlacementCatalogSource.localData,
      availability: StarCraftPlacementAvailability.placeable,
      doodadRecipe: recipe,
    );
Uint8List _solid(int width, int height, List<int> color) =>
    Uint8List.fromList([for (var i = 0; i < width * height; i++) ...color]);
List<int> _pixel(CatalogThumbnailPixels t, int x, int y) =>
    t.rgba.sublist((y * t.width + x) * 4, (y * t.width + x) * 4 + 4);
StarCraftObjectAtlasEntry _overlay(
  DoodadOverlayRecipe recipe, {
  int width = 32,
  int height = 32,
  int anchorX = 16,
  int anchorY = 16,
  List<int> color = const [0, 255, 0, 255],
}) => StarCraftObjectAtlasEntry(
  key: DoodadThumbnailComposer.overlayKey(recipe),
  spriteId: 7,
  imageId: 9,
  width: width,
  height: height,
  anchorX: anchorX,
  anchorY: anchorY,
  frameIndex: 0,
  rgbaBytes: _solid(width, height, color),
);
DoodadPlacementCatalogLoader _loader(
  List<StarCraftPlacementCatalogEntry> entries,
  _Tiles tiles,
  _Objects objects,
) => DoodadPlacementCatalogLoader(
  catalogGateway: _Catalog(entries),
  tileAtlasGateway: tiles,
  objectAtlasGateway: objects,
);

final class _Catalog implements StarCraftPlacementCatalogGateway {
  _Catalog(this.entries);
  final List<StarCraftPlacementCatalogEntry> entries;
  bool mismatch = false;
  void Function()? after;
  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    after?.call();
    return StarCraftPlacementCatalogPage(
      request: mismatch
          ? StarCraftPlacementCatalogRequest(
              operationId: 'wrong',
              installationPath: request.installationPath,
              kind: request.kind,
              tileset: request.tileset,
            )
          : request,
      totalEntries: entries.length,
      entries: entries,
      storageProduct: 's1',
      storageBuildNumber: 1,
      helperVersion: '0.13.0',
      cascLibRevision: 'rev',
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
}

final class _Tiles implements StarCraftTileAtlasGateway {
  final calls = <StarCraftTileAtlasRequest>[];
  Set<int> unsupported = {};
  int build = 1;
  bool throwsError = false;
  bool failed = false;
  void Function()? after;
  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    calls.add(request);
    after?.call();
    if (throwsError) throw StateError('synthetic failure');
    if (failed) {
      return StarCraftTileAtlasResult.failed(
        request: request,
        diagnostic: const EditorDiagnostic(
          code: 'SC_CASC_TILE_ASSET_MISSING',
          message: 'Missing tile',
          severity: DiagnosticSeverity.warning,
          stage: DiagnosticStage.validate,
          rawDetails: 'synthetic missing tile',
        ),
      );
    }
    final values = request.rawValues
        .where((v) => !unsupported.contains(v))
        .toList();
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: 32,
      columns: values.length,
      rows: values.isEmpty ? 0 : 1,
      rawValues: values,
      rgbaBytes: Uint8List.fromList([
        for (final _ in values) ..._solid(32, 32, [100, 0, 0, 255]),
      ]),
      unsupportedRawValues: request.rawValues
          .where(unsupported.contains)
          .toList(),
      storageProduct: 's1',
      storageBuildNumber: build,
      helperVersion: '0.13.0',
      cascLibRevision: 'rev',
    );
  }
}

final class _Objects implements StarCraftObjectAtlasGateway {
  final calls = <StarCraftObjectAtlasRequest>[];
  bool unsupported = false;
  int build = 1;
  bool throwsError = false;
  void Function()? after;
  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    calls.add(request);
    after?.call();
    if (throwsError) throw StateError('synthetic failure');
    return StarCraftObjectAtlasResult(
      request: request,
      entries: unsupported
          ? []
          : [
              for (final k in request.objects)
                _overlay(
                  DoodadOverlayRecipe(
                    semantic: k.kind == StarCraftObjectGraphicKind.unit
                        ? DoodadOverlaySemantic.spriteUnit
                        : DoodadOverlaySemantic.pureSprite,
                    id: k.id,
                  ),
                ),
            ],
      unsupportedObjects: unsupported
          ? [
              for (final k in request.objects)
                StarCraftUnsupportedObjectGraphic(
                  key: k,
                  code: 'SC_CASC_OBJECT_GRP_MISSING',
                ),
            ]
          : [],
      storageProduct: 's1',
      storageBuildNumber: build,
      helperVersion: '0.13.0',
      cascLibRevision: 'rev',
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
}
