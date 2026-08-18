import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';

void main() {
  group('ProcessStarCraftTileAtlasGateway', () {
    late String powershellExecutable;
    late String fakeHelperScript;

    setUpAll(() async {
      powershellExecutable = await _findPowerShellExecutable();
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_starcraft_data_helper.ps1',
      ).absolute.path;
    });

    ProcessStarCraftTileAtlasGateway createGateway({
      Duration timeout = const Duration(seconds: 10),
      int maximumProcessOutputBytes = 256 * 1024,
    }) {
      return ProcessStarCraftTileAtlasGateway(
        helperExecutablePath: powershellExecutable,
        helperArguments: [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          fakeHelperScript,
        ],
        timeout: timeout,
        maximumProcessOutputBytes: maximumProcessOutputBytes,
        additionalInheritedEnvironmentKeys: Platform.environment.keys.toList(
          growable: false,
        ),
      );
    }

    StarCraftTileAtlasRequest requestFor(
      String scenario, {
      List<int> rawValues = const [0, 1, 0x4000, 0x5000],
    }) {
      return StarCraftTileAtlasRequest(
        installationPath: 'C:\\Games\\$scenario',
        tileset: StarCraftTilesetAssetSet.jungle,
        rawValues: rawValues,
      );
    }

    test('validates a binary atlas returned by a real process', () async {
      final result = await createGateway().render(requestFor('StarCraft'));

      expect(
        result.isSuccess,
        isTrue,
        reason: result.diagnostics
            .map((diagnostic) => '${diagnostic.code}: ${diagnostic.rawDetails}')
            .join('\n'),
      );
      expect(result.rawValues, [0, 1, 0x4000]);
      expect(result.unsupportedRawValues, [0x5000]);
      expect(result.tileSize, 32);
      expect(result.columns, 3);
      expect(result.rows, 1);
      expect(result.rgbaBytes, hasLength(3 * 32 * 32 * 4));
      expect(result.storageProduct, 's1');
      expect(result.storageBuildNumber, 13515);
      expect(result.helperVersion, '0.4.0');
      expect(
        result.cascLibRevision,
        ProcessStarCraftTileAtlasGateway.cascLibRevision,
      );
      expect(result.totalAssetBytes, 1048576);
    }, skip: !Platform.isWindows);

    test(
      'accepts an empty atlas when every raw value is unsupported',
      () async {
        final result = await createGateway().render(
          requestFor('all-unsupported', rawValues: const [0x5000, 0xFFFF]),
        );

        expect(result.isSuccess, isTrue);
        expect(result.rawValues, isEmpty);
        expect(result.rgbaBytes, isEmpty);
        expect(result.columns, 0);
        expect(result.rows, 0);
        expect(result.unsupportedRawValues, [0x5000, 0xFFFF]);
      },
      skip: !Platform.isWindows,
    );

    test('maps native storage and asset read failures', () async {
      final storage = await createGateway().render(requestFor('storage-error'));
      expect(
        storage.diagnostics.single.code,
        StarCraftTileAtlasDiagnosticCodes.storageOpenFailed,
      );
      expect(storage.diagnostics.single.rawDetails, contains('nativeError=2'));

      final asset = await createGateway().render(requestFor('asset-error'));
      expect(
        asset.diagnostics.single.code,
        StarCraftTileAtlasDiagnosticCodes.assetInvalid,
      );
      expect(asset.unsupportedRawValues, [0, 1, 0x4000, 0x5000]);
    }, skip: !Platform.isWindows);

    test('rejects malformed process output and atlas envelopes', () async {
      for (final scenario in const [
        'invalid-response',
        'protocol-mismatch',
        'request-mismatch',
        'revision-mismatch',
        'path-mismatch',
        'tileset-mismatch',
        'atlas-header-mismatch',
        'atlas-entry-mismatch',
        'atlas-size-mismatch',
        'atlas-output-name-mismatch',
        'atlas-output-missing',
        'unsupported-mismatch',
        'asset-size-mismatch',
      ]) {
        final result = await createGateway().render(requestFor(scenario));

        expect(
          result.diagnostics.single.code,
          StarCraftTileAtlasDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects excessive output and terminates a timeout', () async {
      final excessive = await createGateway(
        maximumProcessOutputBytes: 256,
      ).render(requestFor('large-output'));
      expect(
        excessive.diagnostics.single.code,
        StarCraftTileAtlasDiagnosticCodes.helperOutputLimitExceeded,
      );

      final timedOut = await createGateway(
        timeout: const Duration(milliseconds: 200),
      ).render(requestFor('hang'));
      expect(
        timedOut.diagnostics.single.code,
        StarCraftTileAtlasDiagnosticCodes.helperTimedOut,
      );
    }, skip: !Platform.isWindows);

    test('rejects a relative installation without starting a helper', () async {
      final request = StarCraftTileAtlasRequest(
        installationPath: 'relative/StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        rawValues: const [0],
      );

      final result = await createGateway().render(request);

      expect(
        result.diagnostics.single.code,
        StarCraftTileAtlasDiagnosticCodes.installationPathInvalid,
      );
    }, skip: !Platform.isWindows);
  });
}

Future<String> _findPowerShellExecutable() async {
  for (final candidate in const [
    r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
    r'C:\Program Files\PowerShell\7\pwsh.exe',
  ]) {
    if (await File(candidate).exists()) {
      return candidate;
    }
  }
  throw StateError('PowerShell is required for the helper process tests.');
}
