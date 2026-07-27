import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_record.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';

void main() {
  group('fake euddraft safe-build integration', () {
    late Directory temporaryRoot;
    late String powershellExecutable;

    setUp(() async {
      final systemRoot = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_eud_integration_',
      );
      temporaryRoot = await Directory(
        '${systemRoot.path}${Platform.pathSeparator}공백 포함 통합 테스트',
      ).create();
      powershellExecutable = await _findPowerShellExecutable();
    });

    tearDown(() async {
      final systemRoot = temporaryRoot.parent;
      if (await systemRoot.exists()) {
        await systemRoot.delete(recursive: true);
      }
    });

    test('promotes verified output after a successful fake build', () async {
      final harness = await _IntegrationHarness.create(
        temporaryRoot: temporaryRoot,
        powershellExecutable: powershellExecutable,
      );
      addTearDown(harness.dispose);
      harness.prepare(buildId: 'fake-build-success', scenario: 'build-output');

      final succeeded = await harness.controller.start();
      expect(
        succeeded,
        isTrue,
        reason:
            'status=${harness.controller.state.status}; '
            'events=${harness.controller.state.events.map((event) => event.kind)}; '
            'diagnostics=${harness.controller.state.diagnostics.map((diagnostic) => '${diagnostic.code}:${diagnostic.rawDetails}')}; '
            'stdout=${harness.controller.state.latestRecord?.stdoutLines}; '
            'stderr=${harness.controller.state.latestRecord?.stderrLines}',
      );

      expect(harness.controller.state.status, EudBuildStatus.succeeded);
      expect(
        harness.controller.state.events.map((event) => event.kind),
        containsAllInOrder([
          EudBuildEventKind.started,
          EudBuildEventKind.finalizing,
          EudBuildEventKind.succeeded,
        ]),
      );
      expect(
        harness.controller.state.latestRecord?.status,
        EudBuildRecordStatus.succeeded,
      );
      expect(harness.controller.state.latestRecord?.exitCode, 0);
      expect(
        harness.controller.state.latestRecord?.stdoutLines,
        containsAll([
          'manifest-input=${harness.baseMap.path}',
          'manifest-entry=${harness.entrySource.path}',
          'stdout=fake 한글 로그',
        ]),
      );
      expect(
        harness.controller.state.latestRecord?.stdoutLines.any(
          (line) =>
              line.startsWith('manifest-output=') &&
              line.endsWith('${Platform.pathSeparator}temporary-output.scx'),
        ),
        isTrue,
      );
      expect(
        harness.controller.state.latestRecord?.stderrLines,
        contains('stderr=fake compiler warning'),
      );
      expect(await harness.outputMap.readAsBytes(), harness.baseMapBytes);
      expect(await harness.baseMap.readAsBytes(), harness.baseMapBytes);
      expect(
        harness.progressController.current?.phase,
        OperationPhase.succeeded,
      );
      await harness.expectWorkspaceClean();
    });

    test('preserves logs and output safety after compiler failure', () async {
      final harness = await _IntegrationHarness.create(
        temporaryRoot: temporaryRoot,
        powershellExecutable: powershellExecutable,
      );
      addTearDown(harness.dispose);
      harness.prepare(buildId: 'fake-build-failure', scenario: 'failure');

      expect(await harness.controller.start(), isFalse);

      expect(harness.controller.state.status, EudBuildStatus.failed);
      expect(
        harness.controller.state.latestRecord?.status,
        EudBuildRecordStatus.failed,
      );
      expect(harness.controller.state.latestRecord?.exitCode, 7);
      expect(
        harness.controller.state.latestRecord?.stderrLines,
        contains('stderr=compile failed'),
      );
      expect(
        harness.controller.state.diagnostics.map(
          (diagnostic) => diagnostic.code,
        ),
        contains(EudCompilerDiagnosticCodes.processFailed),
      );
      expect(await harness.outputMap.exists(), isFalse);
      expect(await harness.baseMap.readAsBytes(), harness.baseMapBytes);
      expect(harness.progressController.current?.phase, OperationPhase.failed);
      await harness.expectWorkspaceClean();
    });

    test(
      'kills the fake compiler and cleans output after cancellation',
      () async {
        final harness = await _IntegrationHarness.create(
          temporaryRoot: temporaryRoot,
          powershellExecutable: powershellExecutable,
        );
        addTearDown(harness.dispose);
        harness.prepare(buildId: 'fake-build-cancel', scenario: 'hang');
        final waitingForCompiler = harness.controller.changes.firstWhere(
          (state) => state.events.any(
            (event) =>
                event.kind == EudBuildEventKind.stdoutLine &&
                event.text == 'stdout=waiting',
          ),
        );

        final buildFuture = harness.controller.start();
        await waitingForCompiler.timeout(const Duration(seconds: 10));
        await Future<void>.delayed(Duration.zero);
        expect(await harness.controller.cancel(), isTrue);
        expect(await buildFuture, isFalse);

        expect(harness.controller.state.status, EudBuildStatus.cancelled);
        expect(
          harness.controller.state.latestRecord?.status,
          EudBuildRecordStatus.cancelled,
        );
        expect(
          harness.controller.state.diagnostics.map(
            (diagnostic) => diagnostic.code,
          ),
          contains(EudCompilerDiagnosticCodes.cancelled),
        );
        expect(await harness.outputMap.exists(), isFalse);
        expect(await harness.baseMap.readAsBytes(), harness.baseMapBytes);
        expect(
          harness.progressController.current?.phase,
          OperationPhase.cancelled,
        );
        await harness.expectWorkspaceClean();
      },
    );
  }, skip: !Platform.isWindows);
}

final class _IntegrationHarness {
  _IntegrationHarness._({
    required this.baseMap,
    required this.entrySource,
    required this.outputMap,
    required this.buildDirectory,
    required this.baseMapBytes,
    required this.tool,
    required this.controller,
    required this.progressController,
  });

  final File baseMap;
  final File entrySource;
  final File outputMap;
  final Directory buildDirectory;
  final List<int> baseMapBytes;
  final EudToolInfo tool;
  final EudBuildController controller;
  final OperationProgressController progressController;

  static Future<_IntegrationHarness> create({
    required Directory temporaryRoot,
    required String powershellExecutable,
  }) async {
    final baseDirectory = await Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}기준 맵',
    ).create();
    final sourceDirectory = await Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}epScript 소스',
    ).create();
    final buildDirectory = await Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}빌드 결과',
    ).create();
    final archiveTemporaryRoot = await Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}아카이브 임시',
    ).create();
    final baseMap = File(
      '${baseDirectory.path}${Platform.pathSeparator}기준 맵.scx',
    );
    const baseMapBytes = <int>[83, 67, 77, 69, 45, 70, 65, 75, 69];
    await baseMap.writeAsBytes(baseMapBytes, flush: true);
    final entrySource = File(
      '${sourceDirectory.path}${Platform.pathSeparator}메인.eps',
    );
    await entrySource.writeAsString(
      'function onPluginStart() {\r\n}\r\n',
      flush: true,
    );
    final outputMap = File(
      '${buildDirectory.path}${Platform.pathSeparator}완성 맵.scx',
    );
    final fakeCompilerScript = File(
      'test/fixtures/helpers/fake_eud_compiler.ps1',
    ).absolute.path;
    final fakeArchiveHelperScript = File(
      'test/fixtures/helpers/fake_map_archive_helper.ps1',
    ).absolute.path;
    final tool = EudToolInfo(
      pathSource: EudToolPathSource.projectProfile,
      installationPath: File(powershellExecutable).parent.path,
      executablePath: powershellExecutable,
      versionFilePath: fakeCompilerScript,
      version: EudToolVersion.parse('0.10.2.5'),
      companionPaths: [fakeCompilerScript],
    );
    final compilerGateway = ProcessEudCompilerGateway(
      executableArgumentPrefix: [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        fakeCompilerScript,
      ],
    );
    final archiveGateway = ProcessMapArchiveGateway(
      helperExecutablePath: powershellExecutable,
      helperArguments: [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        fakeArchiveHelperScript,
      ],
      temporaryRoot: archiveTemporaryRoot,
    );
    final pipeline = SafeEudBuildPipeline(
      toolInspector: _ReadyToolInspector(tool),
      compilerGateway: compilerGateway,
      archiveGateway: archiveGateway,
      fingerprintGateway: LocalMapFileFingerprintGateway(),
      buildFileGateway: LocalEudBuildFileGateway(),
      archiveTimeout: const Duration(seconds: 10),
    );
    final progressController = OperationProgressController();
    final controller = EudBuildController(
      buildGateway: pipeline,
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progressController,
    );
    return _IntegrationHarness._(
      baseMap: baseMap,
      entrySource: entrySource,
      outputMap: outputMap,
      buildDirectory: buildDirectory,
      baseMapBytes: baseMapBytes,
      tool: tool,
      controller: controller,
      progressController: progressController,
    );
  }

  void prepare({required String buildId, required String scenario}) {
    controller.prepare(
      EudBuildPlan(
        buildId: buildId,
        configuration: EudBuildConfiguration(
          baseMapPath: baseMap.path,
          sourceRootPath: entrySource.parent.path,
          entrySourcePath: entrySource.path,
          outputMapPath: outputMap.path,
          environmentOverrides: {'FAKE_EUD_SCENARIO': scenario},
        ),
        tool: tool,
        timeout: const Duration(seconds: 20),
      ),
    );
  }

  Future<void> expectWorkspaceClean() async {
    final workspaces = await buildDirectory
        .list()
        .where(
          (entity) =>
              entity is Directory &&
              entity.path
                  .split(RegExp(r'[\\/]'))
                  .last
                  .startsWith('.starcraft_map_editor_eud_'),
        )
        .toList();
    expect(workspaces, isEmpty);
  }

  Future<void> dispose() async {
    await controller.dispose();
    await progressController.dispose();
  }
}

final class _ReadyToolInspector implements EudToolInspector {
  const _ReadyToolInspector(this.tool);

  final EudToolInfo tool;

  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async {
    return EudToolInspectionResult.ready(readyTool: tool);
  }
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
