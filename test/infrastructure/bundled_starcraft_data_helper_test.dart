import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_data_asset_inspector.dart';

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
}
