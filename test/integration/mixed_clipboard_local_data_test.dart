import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_mixed_clipboard.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_paint.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'],
      install = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  test(
    'local ISOM region copy preserves pinned transition shapes and valid pairs in eight tilesets',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      for (var t = 0; t < 8; t++) {
        final read = await gateway.read(
          operationId: 'mixed-$t',
          installationPath: install!,
          tileset: t,
        );
        expect(read.isSuccess, isTrue);
        final c = const TransitionIsomCatalogBuilder().build(read.snapshot!);
        final types = c.shapes.keys.take(2).toList();
        final base = const IsomTerrainFill()
            .preview(
              const NewMapFactory().create(
                NewMapOptions(
                  width: 64,
                  height: 64,
                  tileset: ChkTileset.values[t],
                  rawTileValue: 0,
                ),
              ),
              c.catalog,
              solidValue: c.shapes[types.first]! << 4,
              seed: 5,
            )
            .result;
        final painted = const IsomTerrainPaint()
            .preview(
              base,
              c.catalog,
              c.brush!,
              solidShape: c.shapes[types.last]!,
              diamonds: {(5, 13), (6, 14)},
              seed: 7,
            )
            .result;
        final clip = ChkMixedClipboard.capture(
          painted,
          region: ClipboardRegion(4, 8, 19, 23),
          profile: MixedClipboardProfile.isom,
          kinds: {},
          overlays: {},
          data: MixedClipboardData(
            recipes: [],
            catalog: c.catalog,
            brush: c.brush,
          ),
        );
        final bytes = const RawChkEncoder().encode(painted);
        final result = clip.paste(painted, x: 36, y: 40);
        final shapes = IsomTerrainPaint.readDiamonds(result, c.brush!);
        for (final e in clip.shapes.entries) {
          expect(
            shapes[(e.key.$1 + 16, e.key.$2 + 32)],
            e.value,
            reason: 'tileset $t / ${e.key}',
          );
        }
        expect(
          const IsomTerrainConverter()
              .preview(
                result,
                c.catalog,
                seed: 9,
                requireKnownSourcePairs: true,
              )
              .changedTileCount,
          0,
        );
        expect(const RawChkEncoder().encode(result), isNot(bytes));
        expect(const RawChkEncoder().encode(painted), bytes);
        final cut = clip.cut(fillShape: c.shapes[types.first]);
        expect(
          IsomTerrainPaint.readDiamonds(cut, c.brush!)[(5, 13)],
          c.shapes[types.first],
        );
      }
    },
    skip: helper == null || install == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
