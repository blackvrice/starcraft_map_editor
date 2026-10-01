import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_paint.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_doodad_overlay.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final install = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'local diamond brushes connect all terrain pairs in eight tilesets',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      for (var t = 0; t < 8; t++) {
        final read = await gateway.read(
          operationId: 'brush-$t',
          installationPath: install!,
          tileset: t,
        );
        expect(read.isSuccess, isTrue);
        final c = const TransitionIsomCatalogBuilder().build(read.snapshot!);
        for (final from in c.shapes.keys) {
          final base = const IsomTerrainFill()
              .preview(
                const NewMapFactory().create(
                  NewMapOptions(
                    width: 32,
                    height: 32,
                    rawTileValue: 0,
                    tileset: ChkTileset.values[t],
                  ),
                ),
                c.catalog,
                solidValue: c.shapes[from]! << 4,
                seed: 0,
              )
              .result;
          for (final to in c.shapes.keys) {
            for (final selection in <Set<IsomDiamond>>[
              {(8, 16)},
              {(0, 0)},
              {(16, 32)},
              {
                for (var y = 8; y <= 20; y++)
                  for (var x = y & 1; x <= 10; x += 2) (x, y),
              },
              {(4, 12), (5, 13), (6, 14), (7, 13), (8, 12)},
            ]) {
              final painted = const IsomTerrainPaint().preview(
                base,
                c.catalog,
                c.brush!,
                solidShape: c.shapes[to]!,
                diamonds: selection,
                seed: 7,
              );
              expect(
                const IsomTerrainConverter()
                    .preview(
                      painted.result,
                      c.catalog,
                      seed: 1,
                      requireKnownSourcePairs: true,
                    )
                    .changedTileCount,
                0,
                reason: '$t $from -> $to',
              );
            }
          }
        }
      }
    },
    skip: helper == null || install == null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
  test(
    'local VF4 ramps place on matching generated cliffs in all eight tilesets',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      final placements = ProcessStarCraftPlacementCatalogGateway(
        helperExecutablePath: helper,
      );
      final renderer = ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: helper,
      );
      for (var t = 0; t < 8; t++) {
        final c = const TransitionIsomCatalogBuilder().build(
          (await gateway.read(
            operationId: 'ramp-catalog-$t',
            installationPath: install!,
            tileset: t,
          )).snapshot!,
        );
        final recipes = <DoodadPlacementRecipe>[];
        var offset = 0;
        do {
          final page = await placements.list(
            StarCraftPlacementCatalogRequest(
              operationId: 'ramp-$t-$offset',
              installationPath: install,
              kind: StarCraftPlacementKind.doodad,
              tileset: StarCraftTilesetAssetSet.values[t],
              offset: offset,
              limit: 256,
            ),
          );
          expect(page.isSuccess, isTrue);
          recipes.addAll(
            page.entries
                .map((e) => e.doodadRecipe)
                .whereType<DoodadPlacementRecipe>(),
          );
          if (page.nextOffset == null) break;
          offset = page.nextOffset!;
        } while (true);
        var placed = false;
        for (final from in c.shapes.keys) {
          final base = const IsomTerrainFill()
              .preview(
                const NewMapFactory().create(
                  NewMapOptions(
                    width: 32,
                    height: 32,
                    rawTileValue: 0,
                    tileset: ChkTileset.values[t],
                  ),
                ),
                c.catalog,
                solidValue: c.shapes[from]! << 4,
                seed: 0,
              )
              .result;
          for (final to in c.shapes.keys.where((v) => v != from)) {
            for (final selection in <Set<IsomDiamond>>[
              {
                for (var y = 8; y <= 20; y++)
                  for (var x = 4 + (y & 1); x <= 12; x += 2) (x, y),
              },
              {
                for (var a = 0; a < 6; a++)
                  for (var b = 0; b < 6; b++) (8 + a - b, 10 + a + b),
              },
              {(8, 16)},
            ]) {
              final painted = const IsomTerrainPaint()
                  .preview(
                    base,
                    c.catalog,
                    c.brush!,
                    solidShape: c.shapes[to]!,
                    diamonds: selection,
                  )
                  .result;
              final tiles = const ChkTerrainViewDecoder()
                  .decode(painted)
                  .tileMaps
                  .single
                  .rawTileValues;
              for (final r in recipes.where((r) => r.hasRamp)) {
                for (var y = 0; y <= 32 - r.height && !placed; y++) {
                  for (var x = 0; x <= 32 - r.width && !placed; x++) {
                    if (!r.footprint.every(
                      (cell) =>
                          cell.requiredTileGroup == 0 ||
                          tiles[(y + cell.y) * 32 + x + cell.x] >> 4 ==
                              cell.requiredTileGroup,
                    )) {
                      continue;
                    }
                    final result = IsomDoodadOverlay.placeRamp(
                      painted,
                      r,
                      x: x,
                      y: y,
                      recipes: recipes,
                    );
                    expect(
                      result.sections.singleWhere((s) => s.name == 'ISOM'),
                      same(
                        painted.sections.singleWhere((s) => s.name == 'ISOM'),
                      ),
                    );
                    expect(
                      result.sections.singleWhere((s) => s.name == 'TILE'),
                      same(
                        painted.sections.singleWhere((s) => s.name == 'TILE'),
                      ),
                    );
                    final overlay = IsomDoodadOverlay.read(result, recipes);
                    expect(
                      const RawChkEncoder().encode(
                        overlay.restore(overlay.base),
                      ),
                      const RawChkEncoder().encode(result),
                    );
                    final bytes = const RawChkEncoder().encode(result);
                    expect(
                      const RawChkEncoder().encode(
                        const RawChkParser().parse(bytes).document!,
                      ),
                      bytes,
                    );
                    final values =
                        const ChkTerrainViewDecoder()
                            .decode(result)
                            .tileMaps
                            .single
                            .rawTileValues
                            .toSet()
                            .toList()
                          ..sort();
                    final rendered = await renderer.render(
                      StarCraftTileAtlasRequest(
                        installationPath: install,
                        tileset: StarCraftTilesetAssetSet.values[t],
                        rawValues: values,
                      ),
                    );
                    expect(rendered.isSuccess, isTrue);
                    expect(rendered.unsupportedRawValues, isEmpty);
                    placed = true;
                  }
                }
                if (placed) break;
              }
              if (placed) break;
            }
            if (placed) break;
          }
          if (placed) break;
        }
        expect(placed, isTrue, reason: 'No matching ramp in tileset $t');
      }
    },
    skip: helper == null || install == null,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
