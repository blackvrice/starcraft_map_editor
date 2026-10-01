import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import '../fixtures/editor_terrain_fixture.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final install = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'all eight local transition catalogs and independent CV5 stack paths',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      final renderer = ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: helper,
      );
      const types = [8, 9, 6, 7, 12, 12, 12, 12];
      const pairs = [235, 302, 203, 188, 307, 307, 307, 307];
      for (var t = 0; t < 8; t++) {
        final read = await gateway.read(
          operationId: 'transition-$t',
          installationPath: install!,
          tileset: t,
        );
        expect(
          read.isSuccess,
          isTrue,
          reason: '${read.errorCode}: ${read.stderr}',
        );
        final c = const TransitionIsomCatalogBuilder().build(read.snapshot!);
        expect(c.catalog.edges.length, c.shapes.length * 8 + types[t] * 14 * 8);
        expect(c.catalog.pairs.length, pairs[t]);
        final flatType = c.shapes.keys.first;
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
              solidValue: c.shapes[flatType]! << 4,
              seed: 0,
            )
            .result;
        var stacks = 0;
        final renderedValues = <int>{};
        for (final target in c.catalog.pairs.where((p) => !p.isUnstacked)) {
          List<IsomTilePair>? path;
          for (final m in target.members) {
            List<IsomTilePair>? extend(
              IsomTilePair p,
              bool up,
              Set<int> visited,
            ) {
              if (!visited.add(p.leftGroup)) return null;
              final link = p.stackConnections[up ? 1 : 3];
              if (link == 0) return [p];
              for (final other in c.catalog.pairs.where(
                (o) =>
                    o.terrainType == p.terrainType &&
                    o.stackConnections[up ? 3 : 1] == link &&
                    o.members.contains(m),
              )) {
                final tail = extend(other, up, {...visited});
                if (tail != null) return [p, ...tail];
              }
              return null;
            }

            final up = extend(target, true, {}),
                down = extend(target, false, {});
            if (up != null && down != null) {
              path = [...up.reversed, ...down.skip(1)];
              break;
            }
          }
          expect(path, isNotNull, reason: '$t group ${target.leftGroup}');
          final data = ByteData.sublistView(
            base.sections.singleWhere((s) => s.name == 'ISOM').payload,
          );
          const flags = [
            [4, 8],
            [10, 12],
            [0, 14],
            [2, 6],
          ];
          for (var y = 0; y < path!.length; y++) {
            final p = path[y];
            for (var side = 0; side < 4; side++) {
              final choices = c.catalog.edges.where(
                (e) =>
                    (e.link <= 48 || e.terrainType == p.terrainType) &&
                    e.link == p.links[side] &&
                    flags[side].contains(e.value & 15),
              );
              expect(
                choices,
                isNotEmpty,
                reason: '$t group ${p.leftGroup} side $side',
              );
              data.setUint16(
                ((y + 1) * 17 + 4) * 8 + side * 2,
                choices.first.value,
                Endian.little,
              );
            }
          }
          final at = base.sections.indexWhere((s) => s.name == 'ISOM');
          final doc = base.replaceSection(
            at,
            part('ISOM', data.buffer.asUint8List()),
          );
          final result = const IsomTerrainConverter().preview(
            doc,
            c.catalog,
            seed: 17,
            requireKnownSourcePairs: true,
          );
          expect(result.changedTileCount, greaterThan(0));
          final tileBytes = result.result.sections
              .singleWhere((s) => s.name == 'TILE')
              .payload;
          for (var i = 0; i < tileBytes.length; i += 2) {
            renderedValues.add(tileBytes[i] | tileBytes[i + 1] << 8);
          }
          expect(result.result.sections[at].payload, doc.sections[at].payload);
          expect(
            const IsomTerrainConverter()
                .preview(
                  result.result,
                  c.catalog,
                  seed: 99,
                  requireKnownSourcePairs: true,
                )
                .changedTileCount,
            0,
          );
          final bytes = const RawChkEncoder().encode(result.result);
          expect(
            const RawChkEncoder().encode(
              const RawChkParser().parse(bytes).document!,
            ),
            bytes,
          );
          stacks++;
        }
        expect(stacks, greaterThan(0));
        final rendered = await renderer.render(
          StarCraftTileAtlasRequest(
            installationPath: install,
            tileset: StarCraftTilesetAssetSet.values[t],
            rawValues: renderedValues.toList()..sort(),
          ),
        );
        expect(rendered.unsupportedRawValues, isEmpty);
        expect(rendered.diagnostics, isEmpty);
      }
    },
    skip: !Platform.isWindows || helper == null || install == null
        ? 'Requires local CASC/helper.'
        : false,
  );
}
