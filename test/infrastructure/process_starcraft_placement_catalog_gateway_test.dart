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
      StarCraftPlacementKind kind = StarCraftPlacementKind.tile,
    }) => StarCraftPlacementCatalogRequest(
      operationId: operationId,
      installationPath: 'C:\\Games\\$scenario',
      kind: kind,
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
      expect(page.helperVersion, '0.7.0');
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

    test(
      'lists the complete Unit range as previewable factory-pending items',
      () async {
        final gateway = createGateway();
        final first = await gateway.list(
          requestFor(
            'StarCraft',
            operationId: 'units-first',
            kind: StarCraftPlacementKind.unit,
          ),
        );
        final last = await gateway.list(
          requestFor(
            'StarCraft',
            operationId: 'units-last',
            kind: StarCraftPlacementKind.unit,
            offset: 226,
            limit: 4,
          ),
        );

        expect(first.totalEntries, 228);
        expect(first.entries.map((entry) => entry.key.id), [0, 1, 2]);
        expect(first.entries.every((entry) => entry.hasPreview), isTrue);
        expect(first.entries.every((entry) => !entry.isPlaceable), isTrue);
        expect(first.entries.map((entry) => entry.issue?.code).toSet(), {
          'SC_CATALOG_ITEM_PLACEMENT_FACTORY_PENDING',
        });
        expect(last.entries.map((entry) => entry.key.id), [226, 227]);
        expect(last.entries.first.hasPreview, isTrue);
        expect(
          last.entries.last.previewIssueCode,
          'SC_CASC_OBJECT_GRP_UNAVAILABLE',
        );
        expect(last.nextOffset, isNull);
      },
      skip: !Platform.isWindows,
    );

    test('lists all pure Sprites and isolates unavailable previews', () async {
      final page = await createGateway().list(
        requestFor(
          'StarCraft',
          operationId: 'sprites',
          kind: StarCraftPlacementKind.pureSprite,
          offset: 498,
          limit: 4,
        ),
      );

      expect(page.totalEntries, 517);
      expect(page.entries.map((entry) => entry.key.id), [498, 499, 500, 501]);
      expect(page.entries.take(2).every((entry) => entry.hasPreview), isTrue);
      expect(page.entries.skip(2).every((entry) => !entry.hasPreview), isTrue);
      expect(
        page.entries.last.issue?.code,
        'SC_CATALOG_ITEM_OBJECT_GRAPHIC_UNAVAILABLE',
      );
      expect(page.entries.last.displayName, 'Sprite #501');
    }, skip: !Platform.isWindows);

    test(
      'lists validated Doodad recipes and isolates an invalid entry',
      () async {
        final page = await createGateway().list(
          requestFor(
            'StarCraft',
            operationId: 'doodads',
            kind: StarCraftPlacementKind.doodad,
            limit: 4,
          ),
        );

        expect(page.isSuccess, isTrue, reason: page.diagnostics.toString());
        expect(page.totalEntries, 3);
        expect(page.entries.map((entry) => entry.key.id), [1, 2, 3]);
        final first = page.entries.first;
        expect(first.key.doodadStartTileGroup, 200);
        expect(first.isPlaceable, isFalse);
        expect(first.issue?.code, 'SC_CATALOG_ITEM_DOODAD_COMMAND_PENDING');
        expect(first.doodadRecipe!.width, 2);
        expect(first.doodadRecipe!.height, 2);
        expect(first.doodadRecipe!.centerOffsetX, 32);
        expect(first.doodadRecipe!.centerOffsetY, 32);
        expect(first.doodadRecipe!.footprint.map((cell) => cell.rawTileValue), [
          3200,
          3201,
          3216,
          null,
        ]);
        expect(
          first.doodadRecipe!.footprint.map((cell) => cell.requiredTileGroup),
          [4, 0, 5, 6],
        );
        expect(first.doodadRecipe!.overlay!.id, 130);
        expect(first.doodadRecipe!.overlay!.thg2Flags, 0x1000);

        final invalid = page.entries[1];
        expect(invalid.doodadRecipe, isNull);
        expect(invalid.doodadRecipeIssueCode, 'SC_CASC_DOODAD_OVERLAY_INVALID');
        expect(invalid.issue?.code, 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID');
        final unitOverlay = page.entries[2].doodadRecipe!.overlay!;
        expect(unitOverlay.id, 100);
        expect(unitOverlay.thg2Flags, 0);
      },
      skip: !Platform.isWindows,
    );

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
      final object = await gateway.list(
        requestFor(
          'object-metadata-error',
          operationId: 'object-metadata',
          kind: StarCraftPlacementKind.unit,
        ),
      );
      final doodad = await gateway.list(
        requestFor(
          'doodad-asset-error',
          operationId: 'doodad-assets',
          kind: StarCraftPlacementKind.doodad,
        ),
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
      expect(
        object.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
      );
      expect(
        doodad.diagnostics.single.code,
        StarCraftPlacementCatalogDiagnosticCodes.metadataInvalid,
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

    test('rejects malformed object preview availability', () async {
      for (final scenario in const [
        'catalog-preview-code-mismatch',
        'catalog-preview-field-missing',
        'catalog-total-mismatch',
        'catalog-read-count-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(
            scenario,
            operationId: 'bad-$scenario',
            kind: StarCraftPlacementKind.pureSprite,
          ),
        );
        expect(
          page.diagnostics.single.code,
          StarCraftPlacementCatalogDiagnosticCodes.helperInvalidResponse,
          reason: scenario,
        );
      }
    }, skip: !Platform.isWindows);

    test('rejects malformed Doodad recipe metadata', () async {
      for (final scenario in const [
        'catalog-recipe-code-mismatch',
        'catalog-recipe-field-missing',
        'catalog-recipe-center-mismatch',
        'catalog-recipe-value-mismatch',
        'catalog-read-count-mismatch',
      ]) {
        final page = await createGateway().list(
          requestFor(
            scenario,
            operationId: 'bad-doodad-$scenario',
            kind: StarCraftPlacementKind.doodad,
          ),
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
