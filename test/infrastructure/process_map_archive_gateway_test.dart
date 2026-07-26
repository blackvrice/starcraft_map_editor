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
      powershellExecutable =
          '${Platform.environment['SystemRoot']}'
          r'\System32\WindowsPowerShell\v1.0\powershell.exe';
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
        expect(result.extractedMap?.metadata.totalEntryCount, 2);
        expect(
          result.extractedMap?.metadata.entries.single.path,
          r'staredit\scenario.chk',
        );
        expect(temporaryRoot.listSync().whereType<Directory>(), isEmpty);
      },
      skip: !Platform.isWindows,
    );

    test('maps a structured helper error to an archive diagnostic', () async {
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
    }, skip: !Platform.isWindows);

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

    test('blocks extracted CHK data above the configured size limit', () async {
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
    }, skip: !Platform.isWindows);

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

    test('cancels the process for the matching operation ID', () async {
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
    }, skip: !Platform.isWindows);

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
      'keeps archive writing disabled until Save As is implemented',
      () async {
        final sourcePath = await createSource('success');
        final gateway = createGateway();

        final result = await gateway.writeTemporary(
          MapArchiveWriteRequest(
            operationId: 'write-not-ready',
            sourcePath: sourcePath,
            temporaryOutputPath:
                '${temporaryRoot.path}${Platform.pathSeparator}output.scx',
            scenarioChkBytes: const [],
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.diagnostics.single.code,
          MapArchiveDiagnosticCodes.writeNotImplemented,
        );
      },
      skip: !Platform.isWindows,
    );
  });
}
