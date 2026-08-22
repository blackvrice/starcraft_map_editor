import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_data_asset_inspector.dart';

void main() {
  group('ProcessStarCraftDataAssetInspector', () {
    late String powershellExecutable;
    late String fakeHelperScript;

    setUpAll(() async {
      powershellExecutable = await _findPowerShellExecutable();
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_starcraft_data_helper.ps1',
      ).absolute.path;
    });

    ProcessStarCraftDataAssetInspector createInspector({
      Duration timeout = const Duration(seconds: 10),
      int maximumProcessOutputBytes = 256 * 1024,
    }) {
      return ProcessStarCraftDataAssetInspector(
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
        // Windows PowerShell performs profile and cryptographic initialization
        // before the script starts. The production native helper does not
        // require these inherited variables and keeps the default allowlist.
        additionalInheritedEnvironmentKeys: Platform.environment.keys.toList(
          growable: false,
        ),
      );
    }

    test(
      'reads complete CASC metadata through a real process',
      () async {
        final result = await createInspector().inspect(
          r'C:\Program Files (x86)\StarCraft',
        );

        expect(
          result.isReady,
          isTrue,
          reason: result.diagnostics
              .map(
                (diagnostic) =>
                    '${diagnostic.code}: ${diagnostic.rawDetails ?? ''}',
              )
              .join('\n'),
        );
        expect(result.foundAssetCount, 40);
        expect(result.missingRelativePaths, isEmpty);
        expect(result.invalidRelativePaths, isEmpty);
        expect(result.storageProduct, 's1');
        expect(result.storageBuildNumber, 13515);
      expect(result.helperVersion, '0.7.0');
        expect(
          result.cascLibRevision,
          ProcessStarCraftDataAssetInspector.cascLibRevision,
        );
        expect(result.totalAssetBytes, 1048576);
      },
      skip: !Platform.isWindows,
    );

    test('reports missing and unreadable CASC assets', () async {
      final missing = await createInspector().inspect(r'C:\Games\incomplete');
      expect(missing.foundAssetCount, 39);
      expect(missing.missingRelativePaths, [r'tileset\badlands.cv5']);
      expect(
        missing.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.filesMissing,
      );

      final unreadable = await createInspector().inspect(
        r'C:\Games\unreadable',
      );
      expect(unreadable.foundAssetCount, 39);
      expect(unreadable.invalidRelativePaths, [r'tileset\platform.vf4']);
      expect(
        unreadable.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.filesInvalid,
      );
      expect(unreadable.diagnostics.single.rawDetails, contains('13'));
    }, skip: !Platform.isWindows);

    test('maps a structured CASC storage error', () async {
      final result = await createInspector().inspect(r'C:\Games\storage-error');

      expect(result.isReady, isFalse);
      expect(result.missingRelativePaths, hasLength(40));
      expect(
        result.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.storageOpenFailed,
      );
      expect(result.diagnostics.single.rawDetails, contains('nativeError=2'));
    }, skip: !Platform.isWindows);

    test('rejects malformed and excessive helper output', () async {
      final malformed = await createInspector().inspect(
        r'C:\Games\invalid-response',
      );
      expect(
        malformed.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.helperInvalidResponse,
      );

      final excessive = await createInspector(
        maximumProcessOutputBytes: 256,
      ).inspect(r'C:\Games\large-output');
      expect(
        excessive.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.helperOutputLimitExceeded,
      );
    }, skip: !Platform.isWindows);

    test(
      'rejects mismatched helper metadata and asset manifests',
      () async {
        for (final scenario in const [
          'protocol-mismatch',
          'request-mismatch',
          'revision-mismatch',
          'path-mismatch',
          'manifest-mismatch',
          'size-mismatch',
        ]) {
          final result = await createInspector().inspect(
            'C:\\Games\\$scenario',
          );

          expect(
            result.diagnostics.single.code,
            StarCraftDataAssetDiagnosticCodes.helperInvalidResponse,
            reason: scenario,
          );
        }
      },
      skip: !Platform.isWindows,
    );

    test('terminates a helper that exceeds its timeout', () async {
      final result = await createInspector(
        timeout: const Duration(milliseconds: 200),
      ).inspect(r'C:\Games\hang');

      expect(
        result.diagnostics.single.code,
        StarCraftDataAssetDiagnosticCodes.helperTimedOut,
      );
    }, skip: !Platform.isWindows);

    test(
      'rejects a relative installation before starting a helper',
      () async {
        final result = await createInspector().inspect('relative/StarCraft');

        expect(
          result.diagnostics.single.code,
          StarCraftDataAssetDiagnosticCodes.installationPathInvalid,
        );
      },
      skip: !Platform.isWindows,
    );
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
