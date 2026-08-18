import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';

void main() {
  group('ProcessStarCraftObjectAtlasGateway', () {
    late String powershellExecutable;
    late String fakeHelperScript;

    setUpAll(() async {
      powershellExecutable = await _findPowerShellExecutable();
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_starcraft_data_helper.ps1',
      ).absolute.path;
    });

    ProcessStarCraftObjectAtlasGateway createGateway({
      Duration timeout = const Duration(seconds: 10),
      int maximumProcessOutputBytes = 256 * 1024,
    }) {
      return ProcessStarCraftObjectAtlasGateway(
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

    StarCraftObjectAtlasRequest requestFor(
      String scenario, {
      String operationId = 'object-test',
      List<StarCraftObjectGraphicKey> objects = const [
        StarCraftObjectGraphicKey(
          kind: StarCraftObjectGraphicKind.unit,
          id: 0,
          playerColor: 1,
        ),
        StarCraftObjectGraphicKey(
          kind: StarCraftObjectGraphicKind.sprite,
          id: 500,
        ),
      ],
    }) {
      return StarCraftObjectAtlasRequest(
        operationId: operationId,
        installationPath: 'C:\\Games\\$scenario',
        tileset: StarCraftTilesetAssetSet.jungle,
        objects: objects,
      );
    }

    test('validates object entries returned by a real process', () async {
      final result = await createGateway().render(requestFor('StarCraft'));

      expect(
        result.isSuccess,
        isTrue,
        reason: result.diagnostics
            .map((diagnostic) => '${diagnostic.code}: ${diagnostic.rawDetails}')
            .join('\n'),
      );
      expect(result.entries, hasLength(1));
      final entry = result.entries.single;
      expect(entry.key, requestFor('StarCraft').objects.first);
      expect(entry.spriteId, 1);
      expect(entry.imageId, 2);
      expect(entry.width, 2);
      expect(entry.height, 3);
      expect(entry.anchorX, -1);
      expect(entry.anchorY, 2);
      expect(entry.rgbaBytes, hasLength(24));
      expect(entry.rgbaBytes[3], 255);
      expect(result.unsupportedObjects.single.key.id, 500);
      expect(result.helperVersion, '0.4.0');
      expect(result.storageProduct, 's1');
      expect(result.totalAssetBytes, 1048576);
    }, skip: !Platform.isWindows);

    test('accepts an empty atlas when every object is unsupported', () async {
      final result = await createGateway().render(
        requestFor(
          'all-unsupported',
          objects: const [
            StarCraftObjectGraphicKey(
              kind: StarCraftObjectGraphicKind.sprite,
              id: 500,
            ),
          ],
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries, isEmpty);
      expect(result.unsupportedObjects.single.key.id, 500);
    }, skip: !Platform.isWindows);

    test('maps native storage and object asset failures', () async {
      final storage = await createGateway().render(requestFor('storage-error'));
      expect(
        storage.diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.storageOpenFailed,
      );
      expect(storage.diagnostics.single.rawDetails, contains('nativeError=2'));

      final palette = await createGateway().render(requestFor('object-error'));
      expect(palette.diagnostics.single.code, 'SC_CASC_OBJECT_PALETTE_INVALID');
      expect(palette.unsupportedObjects, hasLength(2));
    }, skip: !Platform.isWindows);

    test('rejects malformed process output and object envelopes', () async {
      for (final scenario in const [
        'invalid-response',
        'protocol-mismatch',
        'request-mismatch',
        'revision-mismatch',
        'path-mismatch',
        'object-tileset-mismatch',
        'object-atlas-header-mismatch',
        'object-atlas-entry-mismatch',
        'object-atlas-size-mismatch',
        'object-atlas-output-name-mismatch',
        'object-atlas-output-missing',
        'object-unsupported-mismatch',
        'object-asset-size-mismatch',
      ]) {
        final result = await createGateway().render(requestFor(scenario));
        expect(
          result.diagnostics.single.code,
          StarCraftObjectAtlasDiagnosticCodes.helperInvalidResponse,
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
        StarCraftObjectAtlasDiagnosticCodes.helperOutputLimitExceeded,
      );

      final timedOut = await createGateway(
        timeout: const Duration(milliseconds: 200),
      ).render(requestFor('hang'));
      expect(
        timedOut.diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.helperTimedOut,
      );
    }, skip: !Platform.isWindows);

    test('cancels the exact active object rendering operation', () async {
      final gateway = createGateway();
      final request = requestFor('hang', operationId: 'cancel-me');
      final rendering = gateway.render(request);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final duplicate = await gateway.render(request);
      expect(
        duplicate.diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.renderFailed,
      );

      await gateway.cancel(request.operationId);
      final result = await rendering.timeout(const Duration(seconds: 3));

      expect(
        result.diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.helperCancelled,
      );

      final pendingRequest = requestFor('hang', operationId: 'cancel-pending');
      final pending = gateway.render(pendingRequest);
      await gateway.cancel(pendingRequest.operationId);
      expect(
        (await pending).diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.helperCancelled,
      );
    }, skip: !Platform.isWindows);

    test('rejects a relative installation before starting helper', () async {
      final request = StarCraftObjectAtlasRequest(
        operationId: 'relative',
        installationPath: 'relative/StarCraft',
        tileset: StarCraftTilesetAssetSet.badlands,
        objects: const [
          StarCraftObjectGraphicKey(
            kind: StarCraftObjectGraphicKind.unit,
            id: 0,
          ),
        ],
      );

      final result = await createGateway().render(request);
      expect(
        result.diagnostics.single.code,
        StarCraftObjectAtlasDiagnosticCodes.installationPathInvalid,
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
