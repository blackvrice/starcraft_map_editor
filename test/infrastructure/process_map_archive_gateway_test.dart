import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';

void main() {
  group('ProcessMapArchiveGateway', () {
    late Directory temporaryRoot;
    late String fakeHelperScript;
    late String powershellExecutable;

    setUp(() async {
      temporaryRoot = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_gateway_test_',
      );
      fakeHelperScript = File(
        'test/fixtures/helpers/fake_map_archive_helper.ps1',
      ).absolute.path;
      powershellExecutable = await _findPowerShellExecutable();
    });

    tearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });

    ProcessMapArchiveGateway createGateway({
      int maximumProcessOutputBytes = 1024 * 1024,
      int maximumScenarioBytes = 64 * 1024 * 1024,
    }) {
      return ProcessMapArchiveGateway(
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
        temporaryRoot: temporaryRoot,
        maximumProcessOutputBytes: maximumProcessOutputBytes,
        maximumScenarioBytes: maximumScenarioBytes,
      );
    }

    Future<String> createSource(String name) async {
      final file = File(
        '${temporaryRoot.path}${Platform.pathSeparator}$name.scx',
      );
      await file.writeAsBytes(const [1, 2, 3], flush: true);
      return file.path;
    }

    test(
      'extracts scenario bytes and metadata through a real process',
      () async {
        final sourcePath = await createSource('success');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-success',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.extractedMap?.scenarioChkBytes, [
          86,
          69,
          82,
          32,
          2,
          0,
          0,
          0,
          59,
          0,
        ]);
        expect(result.extractedMap?.metadata.archiveSizeBytes, 128);
        expect(result.extractedMap?.metadata.formatVersion, 1);
        expect(result.extractedMap?.metadata.totalEntryCount, 2);
        expect(result.extractedMap?.metadata.listingComplete, isTrue);
        expect(result.extractedMap?.metadata.listingNativeError, isNull);
        expect(
          result.extractedMap?.metadata.entries.map((entry) => entry.path),
          [r'staredit\scenario.chk', '(listfile)'],
        );
        expect(result.extractedMap?.metadata.entries.first.flags, 0x80000200);
        expect(result.extractedMap?.metadata.entries.first.locale, 0);
        expect(result.diagnostics, isEmpty);
        expect(temporaryRoot.listSync().whereType<Directory>(), isEmpty);
      },
      skip: !Platform.isWindows,
    );

    test(
      'returns warnings for incomplete and synthetic archive listings',
      () async {
        final sourcePath = await createSource('listing-warning');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-listing-warning',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.extractedMap?.metadata.listingComplete, isFalse);
        expect(result.extractedMap?.metadata.listingNativeError, 299);
        expect(result.diagnostics.map((diagnostic) => diagnostic.code), [
          MapArchiveDiagnosticCodes.listingIncomplete,
          MapArchiveDiagnosticCodes.syntheticEntryNames,
        ]);
        expect(
          result.diagnostics.every(
            (diagnostic) => diagnostic.severity == DiagnosticSeverity.warning,
          ),
          isTrue,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'warns when the archive format version is unexpected',
      () async {
        final sourcePath = await createSource('format-warning');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-format-warning',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.extractedMap?.metadata.formatVersion, 2);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.unexpectedFormatVersion,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'reports encrypted entries as nonblocking information',
      () async {
        final sourcePath = await createSource('encrypted');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-encrypted',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(result.extractedMap?.metadata.entries.first.isEncrypted, isTrue);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.encryptedEntries,
        );
        expect(result.diagnostics.single.severity, DiagnosticSeverity.info);
      },
      skip: !Platform.isWindows,
    );

    test(
      'warns about duplicate archive paths case-insensitively',
      () async {
        final sourcePath = await createSource('duplicate-path');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-duplicate-path',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.duplicateEntryPaths,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'rejects an inconsistent complete archive listing',
      () async {
        final sourcePath = await createSource('invalid-listing');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-invalid-listing',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.invalidResponse,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'maps a structured helper error to an archive diagnostic',
      () async {
        final sourcePath = await createSource('error');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-error',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(result.diagnostics.single.code, 'ARCHIVE_SCENARIO_NOT_FOUND');
        expect(result.diagnostics.single.stage, DiagnosticStage.archive);
        expect(result.diagnostics.single.rawDetails, contains('exitCode=3'));
        expect(result.diagnostics.single.rawDetails, contains('nativeError=2'));
      },
      skip: !Platform.isWindows,
    );

    test('rejects malformed helper output', () async {
      final sourcePath = await createSource('malformed');
      final gateway = createGateway();

      final result = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'open-malformed',
          sourcePath: sourcePath,
          timeout: const Duration(seconds: 10),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.diagnostics.single.code,
        MapArchiveDiagnosticCodes.invalidResponse,
      );
    }, skip: !Platform.isWindows);

    test(
      'drains large stderr without blocking a successful response',
      () async {
        final sourcePath = await createSource('large-stderr');
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-large-stderr',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue);
      },
      skip: !Platform.isWindows,
    );

    test(
      'fails safely after draining output beyond the capture limit',
      () async {
        final sourcePath = await createSource('large-stderr');
        final gateway = createGateway(maximumProcessOutputBytes: 1024);

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-output-limit',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.outputLimitExceeded,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'blocks extracted CHK data above the configured size limit',
      () async {
        final sourcePath = await createSource('success');
        final gateway = createGateway(maximumScenarioBytes: 9);

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-scenario-limit',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.scenarioTooLarge,
        );
      },
      skip: !Platform.isWindows,
    );

    test('terminates a helper that exceeds its timeout', () async {
      final sourcePath = await createSource('hang');
      final gateway = createGateway();

      final result = await gateway.open(
        MapArchiveOpenRequest(
          operationId: 'open-timeout',
          sourcePath: sourcePath,
          timeout: const Duration(milliseconds: 200),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.diagnostics.single.code,
        MapArchiveDiagnosticCodes.timedOut,
      );
    }, skip: !Platform.isWindows);

    test(
      'cancels the process for the matching operation ID',
      () async {
        final sourcePath = await createSource('hang');
        final gateway = createGateway();

        final openFuture = gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-cancel',
            sourcePath: sourcePath,
            timeout: const Duration(seconds: 10),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(await gateway.cancel('open-cancel'), isTrue);
        final result = await openFuture;

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.cancelled,
        );
        expect(await gateway.cancel('open-cancel'), isFalse);
      },
      skip: !Platform.isWindows,
    );

    test(
      'rejects nonabsolute source paths before starting the helper',
      () async {
        final gateway = createGateway();

        final result = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'open-relative',
            sourcePath: 'relative.scx',
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.invalidSourcePath,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'writes a temporary archive through a real process',
      () async {
        final sourcePath = await createSource('success');
        final sourceBytesBefore = await File(sourcePath).readAsBytes();
        final workspace = await Directory(
          '${temporaryRoot.path}${Platform.pathSeparator}write-workspace',
        ).create();
        final outputPath =
            '${workspace.path}${Platform.pathSeparator}output.scx';
        final gateway = createGateway();

        final result = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'write-success',
            sourcePath: sourcePath,
            temporaryOutputPath: outputPath,
            scenarioChkBytes: const [1, 2, 3, 4],
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isTrue, reason: '${result.diagnostics}');
        expect(result.temporaryOutputPath, outputPath);
        expect(await File(outputPath).readAsBytes(), sourceBytesBefore);
        expect(await File(sourcePath).readAsBytes(), sourceBytesBefore);
        expect(
          File(
            '${workspace.path}${Platform.pathSeparator}scenario-input.chk',
          ).existsSync(),
          isFalse,
        );
      },
      skip: !Platform.isWindows,
    );

    test('refuses an existing temporary archive output', () async {
      final sourcePath = await createSource('success');
      final output = File(
        '${temporaryRoot.path}${Platform.pathSeparator}existing-output.scx',
      );
      await output.writeAsBytes(const [9, 8, 7]);
      final gateway = createGateway();

      final result = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'write-existing',
          sourcePath: sourcePath,
          temporaryOutputPath: output.path,
          scenarioChkBytes: const [1, 2, 3, 4],
          timeout: const Duration(seconds: 10),
        ),
      );

      expect(result.isSuccess, isFalse);
      expect(
        result.diagnostics.single.code,
        MapArchiveDiagnosticCodes.temporaryOutputExists,
      );
      expect(await output.readAsBytes(), [9, 8, 7]);
    }, skip: !Platform.isWindows);

    test(
      'rejects write metadata that does not match the output',
      () async {
        final sourcePath = await createSource('write-size-mismatch');
        final workspace = await Directory(
          '${temporaryRoot.path}${Platform.pathSeparator}mismatch-workspace',
        ).create();
        final gateway = createGateway();

        final result = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'write-size-mismatch',
            sourcePath: sourcePath,
            temporaryOutputPath:
                '${workspace.path}${Platform.pathSeparator}output.scx',
            scenarioChkBytes: const [1, 2, 3, 4],
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.temporaryOutputSizeMismatch,
        );
      },
      skip: !Platform.isWindows,
    );
  });
}

Future<String> _findPowerShellExecutable() async {
  final programFiles = Platform.environment['ProgramFiles'];
  final systemRoot = Platform.environment['SystemRoot'];
  final candidates = [
    if (programFiles != null)
      '$programFiles${Platform.pathSeparator}'
          r'PowerShell\7\pwsh.exe',
    if (systemRoot != null)
      '$systemRoot${Platform.pathSeparator}'
          r'System32\WindowsPowerShell\v1.0\powershell.exe',
  ];
  for (final candidate in candidates) {
    if (await File(candidate).exists()) {
      return candidate;
    }
  }
  throw StateError('No supported PowerShell executable was found.');
}
