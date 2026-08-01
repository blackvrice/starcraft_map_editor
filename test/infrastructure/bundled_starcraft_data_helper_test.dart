import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_data_asset_inspector.dart';
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
        expect(result.rawValues, const [0, 1]);
        expect(result.columns, 2);
        expect(result.rows, 1);
        expect(result.rgbaBytes, hasLength(2 * 32 * 32 * 4));
        expect(result.rgbaBytes[3], 0xFF);
        expect(result.unsupportedRawValues, const [0x4000]);
      }
    },
    skip: canRun
        ? false
        : 'Set STARCRAFT_DATA_HELPER_PATH and '
              'STARCRAFT_TEST_INSTALLATION after building the Windows app.',
  );
}
