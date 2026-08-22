import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';

void main() {
  group('ProcessStarCraftPlacementCatalogGateway', () {
    late String powershellExecutable;
    late String fakeHelperScript;

    setUpAll(() async {
      powershellExecutable = await _findPowerShellExecutable();
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_starcraft_data_helper.ps1',
      ).absolute.path;
    });

    ProcessStarCraftPlacementCatalogGateway createGateway({
      Duration timeout = const Duration(seconds: 10),
      int maximumProcessOutputBytes = 256 * 1024,
    }) => ProcessStarCraftPlacementCatalogGateway(
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

    StarCraftPlacementCatalogRequest requestFor(
      String scenario, {
      String operationId = 'catalog-test',
      int offset = 0,
      int limit = 3,
    }) => StarCraftPlacementCatalogRequest(
      operationId: operationId,
      installationPath: 'C:\\Games\\$scenario',
      kind: StarCraftPlacementKind.tile,
      tileset: StarCraftTilesetAssetSet.jungle,
      offset: offset,
      limit: limit,
    );

    test('lists a validated contiguous Tile page', () async {
      final page = await createGateway().list(requestFor('StarCraft'));

      expect(page.isSuccess, isTrue, reason: page.diagnostics.toString());
      expect(page.totalEntries, 260);
      expect(page.entries.map((entry) => entry.key.id), [0, 1, 2]);
      expect(page.entries.map((entry) => entry.displayName), [
        'Tile #0',
        'Tile #1',
        'Tile #2',
      ]);
      expect(page.nextOffset, 3);
      expect(page.storageProduct, 's1');
      expect(page.storageBuildNumber, 13515);
      expect(page.helperVersion, '0.5.0');
      expect(page.totalMetadataBytes, 1048576);
    }, skip: !Platform.isWindows);

    test('clamps the final page and accepts an exhausted page', () async {
      final gateway = createGateway();
      final finalPage = await gateway.list(
        requestFor('StarCraft', operationId: 'final', offset: 258, limit: 8),
      );
      final exhausted = await gateway.list(
        requestFor('StarCraft', operationId: 'empty', offset: 300, limit: 8),
      );

      expect(finalPage.entries.map((entry) => entry.key.id), [258, 259]);
      expect(finalPage.nextOffset, isNull);
      expect(exhausted.isSuccess, isTrue);
      expect(exhausted.entries, isEmpty);
    }, skip: !Platform.isWindows);

    test('maps native storage and asset errors', () async {
      final gateway = createGateway();
      final storage = await gateway.list(
        requestFor('storage-error', operationId: 'storage'),
      );
      final asset = await gateway.list(
        requestFor('asset-error', operationId: 'asset'),
      );
      final missing = await gateway.list(
        requestFor('asset-missing', operationId: 'missing'),
      );

      expect(
        storage.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.storageOpenFailed,
      );
      expect(
        asset.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      );
      expect(
        missing.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataMissing,
      );
    }, skip: !Platform.isWindows);

    test('rejects mismatched and malformed responses', () async {
      for (final scenario in const [
        'invalid-response',
        'protocol-mismatch',
        'request-mismatch',
        'revision-mismatch',
        'path-mismatch',
        'catalog-page-mismatch',
        'catalog-entry-mismatch',
        'catalog-size-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(scenario, operationId: 'bad-$scenario'),
        );
        expect(
          page.diagnostics.single.code,
          StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects excessive output and terminates timeout', () async {
      final excessive = await createGateway(
        maximumProcessOutputBytes: 256,
      ).list(requestFor('large-output', operationId: 'large'));
      final timedOut = await createGateway(
        timeout: const Duration(milliseconds: 200),
      ).list(requestFor('hang', operationId: 'timeout'));

      expect(
        excessive.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperOutputLimitExceeded,
      );
      expect(
        timedOut.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperTimedOut,
      );
    }, skip: !Platform.isWindows);

    test('cancels the exact active operation', () async {
      final gateway = createGateway();
      final future = gateway.list(
        requestFor('hang', operationId: 'cancel-this'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await gateway.cancel('cancel-this');

      final page = await future;
      expect(
        page.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.helperCancelled,
      );
    }, skip: !Platform.isWindows);

    test('rejects a relative installation without starting helper', () async {
      final request = StarCraftPlacementCatalogRequest(
        operationId: 'relative',
        installationPath: 'relative/StarCraft',
        kind: StarCraftPlacementKind.tile,
        tileset: StarCraftTilesetAssetSet.badlands,
      );

      final page = await createGateway().list(request);
      expect(
        page.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.installationPathInvalid,
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
  throw StateError('PowerShell is required for helper process tests.');
}
