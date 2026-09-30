import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/solid_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_metadata_views.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final install = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'all eight local tilesets build solid ISOM and render every generated tile',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      final renderer = ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: helper,
      );
      const expectedTypes = [9, 10, 7, 8, 13, 13, 13, 13];
      for (var t = 0; t < 8; t++) {
        final read = await gateway.read(
          operationId: 'solid-$t',
          installationPath: install!,
          tileset: t,
        );
        expect(
          read.isSuccess,
          isTrue,
          reason: '${read.errorCode}: ${read.stderr}',
        );
        final c = const SolidIsomCatalogBuilder().build(read.snapshot!);
        expect(c.shapes.length, expectedTypes[t], reason: 'tileset $t');
        final source = const NewMapFactory().create(
          NewMapOptions(
            width: 32,
            height: 32,
            rawTileValue: 0,
            tileset: ChkTileset.values[t],
          ),
        );
        final values = <int>{};
        for (final entry in c.shapes.entries) {
          final p = const IsomTerrainFill().preview(
            source,
            c.catalog,
            solidValue: entry.value << 4,
            seed: 17,
          );
          expect(p.changedTileCount, 1024);
          final bytes = p.result.sections
              .singleWhere((s) => s.name == 'MTXM')
              .payload;
          for (var i = 0; i < bytes.length; i += 2) {
            values.add(bytes[i] | bytes[i + 1] << 8);
          }
          final repeated = const IsomTerrainFill().preview(
            p.result,
            c.catalog,
            solidValue: entry.value << 4,
            seed: 99,
          );
          expect(repeated.hasChanges, isFalse);
        }
        final rendered = await renderer.render(
          StarCraftTileAtlasRequest(
            installationPath: install,
            tileset: StarCraftTilesetAssetSet.values[t],
            rawValues: values.toList()..sort(),
          ),
        );
        expect(rendered.unsupportedRawValues, isEmpty);
        expect(rendered.rawValues.length, values.length);
        expect(rendered.diagnostics, isEmpty);
      }
    },
    skip: !Platform.isWindows || helper == null || install == null
        ? 'Requires local Windows CASC data/helper.'
        : false,
  );
}
