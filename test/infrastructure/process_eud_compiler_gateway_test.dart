import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';

void main() {
  group('ProcessEudCompilerGateway', () {
    late Directory temporaryRoot;
    late String fakeCompilerScript;
    late String powershellExecutable;

    setUp(() async {
      temporaryRoot = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_eud_gateway_',
      );
      fakeCompilerScript = File(
        'test/fixtures/helpers/fake_eud_compiler.ps1',
      ).absolute.path;
      powershellExecutable = await _findPowerShellExecutable();
    });

    tearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });

    ProcessEudCompilerGateway createGateway({
      int maximumProcessOutputBytes = 1024 * 1024,
      bool Function()? isWindows,
      Map<String, String>? parentEnvironment,
    }) {
      return ProcessEudCompilerGateway(
        executableArgumentPrefix: [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          fakeCompilerScript,
        ],
        maximumProcessOutputBytes: maximumProcessOutputBytes,
        isWindows: isWindows ?? () => true,
        parentEnvironment: parentEnvironment,
      );
    }

    EudToolInfo tool({String? executablePath}) {
      final path = executablePath ?? powershellExecutable;
      return EudToolInfo(
        pathSource: EudToolPathSource.userSettings,
        installationPath: File(path).parent.path,
        executablePath: path,
        versionFilePath:
            '${File(path).parent.path}${Platform.pathSeparator}VERSION',
        version: EudToolVersion.parse('0.10.2.5'),
        companionPaths: const [],
      );
    }

    Future<File> createSettings(String caseName, {Directory? parent}) async {
      final directory = parent ?? temporaryRoot;
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}$caseName.eds',
      );
      await file.writeAsString('[main]\ninput=test.scx\n', flush: true);
      return file;
    }

    EudBuildRequest request({
      required String buildId,
      required String settingsFilePath,
      EudToolInfo? selectedTool,
      Duration timeout = const Duration(seconds: 10),
      Map<String, String> environmentOverrides = const {},
    }) {
      return EudBuildRequest(
        buildId: buildId,
        tool: selectedTool ?? tool(),
        settingsFilePath: settingsFilePath,
        timeout: timeout,
        environmentOverrides: environmentOverrides,
      );
    }

    test('streams UTF-8 stdout and stderr then succeeds', () async {
      final pathDirectory = Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}공백 경로',
      );
      final settings = await createSettings('success', parent: pathDirectory);
      final gateway = createGateway();

      final events = await gateway
          .build(
            request(buildId: 'success-build', settingsFilePath: settings.path),
          )
          .toList();

      expect(events.first.kind, EudBuildEventKind.started);
      expect(events.last.kind, EudBuildEventKind.succeeded);
      expect(events.last.exitCode, 0);
      expect(
        events
            .where((event) => event.kind == EudBuildEventKind.stdoutLine)
            .map((event) => event.text),
        contains('settings=${settings.absolute.path}'),
      );
      expect(
        events
            .where((event) => event.kind == EudBuildEventKind.stdoutLine)
            .map((event) => event.text),
        contains('stdout=한글 로그'),
      );
      expect(
        events
            .where((event) => event.kind == EudBuildEventKind.stderrLine)
            .map((event) => event.text),
        contains('stderr=compiler warning'),
      );
      expect(events.where((event) => event.isTerminal), hasLength(1));
    }, skip: !Platform.isWindows);

    test(
      'returns streamed logs and a nonzero exit failure',
      () async {
        final settings = await createSettings('failure');
        final events = await createGateway()
            .build(
              request(buildId: 'failed-build', settingsFilePath: settings.path),
            )
            .toList();

        expect(events.first.kind, EudBuildEventKind.started);
        expect(events.last.kind, EudBuildEventKind.failed);
        expect(events.last.exitCode, 7);
        expect(
          events.last.diagnostic?.code,
          EudCompilerDiagnosticCodes.processFailed,
        );
        expect(
          events
              .where((event) => event.kind == EudBuildEventKind.stderrLine)
              .single
              .text,
          'stderr=compile failed',
        );
      },
      skip: !Platform.isWindows,
    );

    test('terminates a build that exceeds its timeout', () async {
      final settings = await createSettings('hang');
      final events = await createGateway()
          .build(
            request(
              buildId: 'timeout-build',
              settingsFilePath: settings.path,
              timeout: const Duration(milliseconds: 300),
            ),
          )
          .toList();

      expect(events.last.kind, EudBuildEventKind.failed);
      expect(events.last.diagnostic?.code, EudCompilerDiagnosticCodes.timedOut);
      expect(
        events.last.diagnostic?.rawDetails,
        contains('processTerminated='),
      );
    }, skip: !Platform.isWindows);

    test('cancels only the matching active build', () async {
      final settings = await createSettings('hang');
      final gateway = createGateway();
      final eventsFuture = gateway
          .build(
            request(buildId: 'cancel-build', settingsFilePath: settings.path),
          )
          .toList();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await gateway.cancel('other-build'), isFalse);
      expect(await gateway.cancel('cancel-build'), isTrue);
      final events = await eventsFuture;

      expect(events.last.kind, EudBuildEventKind.cancelled);
      expect(
        events.last.diagnostic?.code,
        EudCompilerDiagnosticCodes.cancelled,
      );
      expect(await gateway.cancel('cancel-build'), isFalse);
    }, skip: !Platform.isWindows);

    test('rejects a duplicate active build ID', () async {
      final hangingSettings = await createSettings('hang');
      final successSettings = await createSettings('success');
      final gateway = createGateway();
      final firstBuild = gateway
          .build(
            request(
              buildId: 'duplicate-build',
              settingsFilePath: hangingSettings.path,
            ),
          )
          .toList();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final duplicateEvents = await gateway
          .build(
            request(
              buildId: 'duplicate-build',
              settingsFilePath: successSettings.path,
            ),
          )
          .toList();

      expect(duplicateEvents, hasLength(1));
      expect(
        duplicateEvents.single.diagnostic?.code,
        EudCompilerDiagnosticCodes.duplicateBuild,
      );
      expect(await gateway.cancel('duplicate-build'), isTrue);
      await firstBuild;
    }, skip: !Platform.isWindows);

    test(
      'drains both streams and fails after the output limit',
      () async {
        final settings = await createSettings('large-output');
        final events = await createGateway(maximumProcessOutputBytes: 1024)
            .build(
              request(
                buildId: 'large-output-build',
                settingsFilePath: settings.path,
              ),
            )
            .toList();

        expect(events.last.kind, EudBuildEventKind.failed);
        expect(
          events.last.diagnostic?.code,
          EudCompilerDiagnosticCodes.outputLimitExceeded,
        );
        expect(
          events.last.diagnostic?.rawDetails,
          contains('maximumBytesPerStream=1024'),
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'inherits only safe environment names plus explicit overrides',
      () async {
        final settings = await createSettings('environment');
        final parentEnvironment = {
          ...Platform.environment,
          'SECRET_TOKEN': 'must-not-leak',
        };
        final events = await createGateway(parentEnvironment: parentEnvironment)
            .build(
              request(
                buildId: 'environment-build',
                settingsFilePath: settings.path,
                environmentOverrides: const {'VISIBLE_TOKEN': 'visible'},
              ),
            )
            .toList();
        final stdoutLines = events
            .where((event) => event.kind == EudBuildEventKind.stdoutLine)
            .map((event) => event.text)
            .toList();

        expect(events.last.kind, EudBuildEventKind.succeeded);
        expect(stdoutLines, contains('visible=visible'));
        expect(stdoutLines, contains('secret='));
        expect(stdoutLines, isNot(contains('secret=must-not-leak')));
      },
      skip: !Platform.isWindows,
    );

    test(
      'rejects invalid and missing settings before process start',
      () async {
        final missingPath =
            '${temporaryRoot.path}${Platform.pathSeparator}missing.eds';
        final textFile = File(
          '${temporaryRoot.path}${Platform.pathSeparator}settings.txt',
        );
        await textFile.writeAsString('not eds', flush: true);
        final gateway = createGateway();

        final relativeEvents = await gateway
            .build(
              request(
                buildId: 'relative-settings',
                settingsFilePath: 'relative.eds',
              ),
            )
            .toList();
        final wrongExtensionEvents = await gateway
            .build(
              request(
                buildId: 'wrong-extension',
                settingsFilePath: textFile.path,
              ),
            )
            .toList();
        final missingEvents = await gateway
            .build(
              request(
                buildId: 'missing-settings',
                settingsFilePath: missingPath,
              ),
            )
            .toList();

        expect(
          relativeEvents.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.settingsPathInvalid,
        );
        expect(
          wrongExtensionEvents.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.settingsPathInvalid,
        );
        expect(
          missingEvents.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.settingsMissing,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'rechecks the executable before starting the process',
      () async {
        final settings = await createSettings('success');
        final missingExecutable =
            '${temporaryRoot.path}${Platform.pathSeparator}missing.exe';
        final relativeTool = tool(executablePath: 'euddraft.exe');
        final missingTool = tool(executablePath: missingExecutable);
        final gateway = createGateway();

        final relativeEvents = await gateway
            .build(
              request(
                buildId: 'relative-tool',
                settingsFilePath: settings.path,
                selectedTool: relativeTool,
              ),
            )
            .toList();
        final missingEvents = await gateway
            .build(
              request(
                buildId: 'missing-tool',
                settingsFilePath: settings.path,
                selectedTool: missingTool,
              ),
            )
            .toList();

        expect(
          relativeEvents.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.executablePathInvalid,
        );
        expect(
          missingEvents.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.executableMissing,
        );
      },
      skip: !Platform.isWindows,
    );

    test(
      'reports process start failure for a nonexecutable file',
      () async {
        final settings = await createSettings('success');
        final invalidExecutable = File(
          '${temporaryRoot.path}${Platform.pathSeparator}invalid.exe',
        );
        await invalidExecutable.writeAsBytes([1, 2, 3], flush: true);
        final gateway = ProcessEudCompilerGateway(isWindows: () => true);

        final events = await gateway
            .build(
              request(
                buildId: 'start-failure',
                settingsFilePath: settings.path,
                selectedTool: tool(executablePath: invalidExecutable.path),
              ),
            )
            .toList();

        expect(events.single.kind, EudBuildEventKind.failed);
        expect(
          events.single.diagnostic?.code,
          EudCompilerDiagnosticCodes.startFailed,
        );
      },
      skip: !Platform.isWindows,
    );

    test('reports unsupported platforms without touching files', () async {
      final gateway = createGateway(isWindows: () => false);

      final events = await gateway
          .build(
            request(
              buildId: 'unsupported-platform',
              settingsFilePath: r'C:\missing\build.eds',
            ),
          )
          .toList();

      expect(events.single.kind, EudBuildEventKind.failed);
      expect(
        events.single.diagnostic?.code,
        EudCompilerDiagnosticCodes.platformUnsupported,
      );
    });
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
