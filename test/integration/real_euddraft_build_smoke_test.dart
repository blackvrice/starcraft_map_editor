import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_record.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/local_eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';

void main() {
  final installationPath = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  final archiveHelperPath = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final skipReason = !Platform.isWindows
      ? 'The official euddraft smoke test requires Windows.'
      : installationPath == null || installationPath.isEmpty
      ? 'Set EUDDRAFT_TEST_INSTALLATION to euddraft 0.10.2.5.'
      : archiveHelperPath == null || archiveHelperPath.isEmpty
      ? 'Set MAP_ARCHIVE_HELPER_PATH to the built native helper.'
      : false;

  test(
    'official euddraft builds and promotes the self-authored map',
    () async {
      final toolInspector = LocalEudToolInspector();
      final inspection = await toolInspector.inspect(
        EudToolInspectionRequest(projectProfilePath: installationPath),
      );
      expect(inspection.isReady, isTrue, reason: '${inspection.diagnostics}');
      expect(inspection.tool?.version.toString(), '0.10.2.5');
      final tool = inspection.tool!;

      final systemRoot = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_real_euddraft_',
      );
      final temporaryRoot = await Directory(
        '${systemRoot.path}${Platform.pathSeparator}공백 포함 실제 빌드',
      ).create();
      addTearDown(() async {
        if (await systemRoot.exists()) {
          await systemRoot.delete(recursive: true);
        }
      });

      final baseDirectory = await Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}기준 맵',
      ).create();
      final sourceDirectory = await Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}epScript 소스',
      ).create();
      final outputDirectory = await Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}빌드 결과',
      ).create();
      final archiveTemporaryRoot = await Directory(
        '${temporaryRoot.path}${Platform.pathSeparator}아카이브 임시',
      ).create();
      final baseMap =
          await File(
            'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
          ).absolute.copy(
            '${baseDirectory.path}${Platform.pathSeparator}자체 제작 기준.scx',
          );
      final entrySource = await File('test/fixtures/eud/minimal-smoke.eps')
          .absolute
          .copy('${sourceDirectory.path}${Platform.pathSeparator}최소 스모크.eps');
      final outputMap = File(
        '${outputDirectory.path}${Platform.pathSeparator}실제 EUD 출력.scx',
      );
      final baseBytesBefore = await baseMap.readAsBytes();
      final sourceBytesBefore = await entrySource.readAsBytes();

      final archiveGateway = ProcessMapArchiveGateway(
        helperExecutablePath: File(archiveHelperPath!).absolute.path,
        temporaryRoot: archiveTemporaryRoot,
      );
      final progressController = OperationProgressController();
      final controller = EudBuildController(
        buildGateway: SafeEudBuildPipeline(
          toolInspector: toolInspector,
          compilerGateway: ProcessEudCompilerGateway(),
          archiveGateway: archiveGateway,
          fingerprintGateway: LocalMapFileFingerprintGateway(),
          buildFileGateway: LocalEudBuildFileGateway(),
          archiveTimeout: const Duration(seconds: 30),
        ),
        diagnosticParser: const EuddraftDiagnosticParser(),
        operationProgressController: progressController,
      );
      addTearDown(controller.dispose);
      addTearDown(progressController.dispose);
      controller.prepare(
        EudBuildPlan(
          buildId: 'official-euddraft-smoke',
          configuration: EudBuildConfiguration(
            baseMapPath: baseMap.path,
            sourceRootPath: sourceDirectory.path,
            entrySourcePath: entrySource.path,
            outputMapPath: outputMap.path,
            compilerPathOverride: tool.installationPath,
          ),
          tool: tool,
          timeout: const Duration(minutes: 2),
        ),
      );

      final succeeded = await controller.start();
      expect(
        succeeded,
        isTrue,
        reason:
            'status=${controller.state.status}; '
            'diagnostics=${controller.state.diagnostics.map((diagnostic) => '${diagnostic.code}:${diagnostic.message}:${diagnostic.rawDetails}')}; '
            'stdout=${controller.state.latestRecord?.stdoutLines}; '
            'stderr=${controller.state.latestRecord?.stderrLines}',
      );
      expect(controller.state.status, EudBuildStatus.succeeded);
      expect(
        controller.state.latestRecord?.status,
        EudBuildRecordStatus.succeeded,
      );
      expect(controller.state.latestRecord?.toolVersion, tool.version);
      expect(controller.state.latestRecord?.exitCode, 0);
      expect(
        controller.state.events.map((event) => event.kind),
        containsAllInOrder([
          EudBuildEventKind.started,
          EudBuildEventKind.finalizing,
          EudBuildEventKind.succeeded,
        ]),
      );
      expect(progressController.current?.phase, OperationPhase.succeeded);
      expect(await baseMap.readAsBytes(), baseBytesBefore);
      expect(await entrySource.readAsBytes(), sourceBytesBefore);
      expect(await outputMap.exists(), isTrue);
      expect(await outputMap.length(), greaterThan(baseBytesBefore.length));

      final reopened = await archiveGateway.open(
        MapArchiveOpenRequest(
          operationId: 'official-euddraft-output-open',
          sourcePath: outputMap.path,
          timeout: const Duration(seconds: 30),
        ),
      );
      expect(reopened.isSuccess, isTrue, reason: '${reopened.diagnostics}');
      expect(reopened.extractedMap?.scenarioChkBytes, isNotEmpty);
      expect(
        outputDirectory.listSync().whereType<Directory>().where(
          (directory) => directory.path
              .split(RegExp(r'[\\/]'))
              .last
              .startsWith('.starcraft_map_editor_eud_'),
        ),
        isEmpty,
      );
    },
    skip: skipReason,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
