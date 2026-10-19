import 'dart:io';
import 'package:starcraft_map_editor/domain/eud/portable_eud_script.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script_syntax.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_source_translation_gateway.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_preparation_controller.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_record.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';

import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/euddraft_diagnostic_parser.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/local_eud_tool_inspector.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_source_workspace_gateway.dart';

void main() {
  final installationPath = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  final bundled = Platform.environment['EUDDRAFT_TEST_BUNDLED'] == '1';
  final archiveHelperPath = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final skipReason = !Platform.isWindows
      ? 'The official euddraft smoke test requires Windows.'
      : installationPath == null || installationPath.isEmpty
      ? 'Set EUDDRAFT_TEST_INSTALLATION to euddraft 0.10.2.5.'
      : archiveHelperPath == null || archiveHelperPath.isEmpty
      ? 'Set MAP_ARCHIVE_HELPER_PATH to the built native helper.'
      : false;

  for (final mode in [0, 1, 2]) {
    final python = mode != 0;
    test(
      'verified euddraft builds and promotes self-authored map (source mode=$mode)',
      () async {
        final toolInspector = bundled
            ? BundledEudTool.inspector()
            : LocalEudToolInspector();
        final inspection = await toolInspector.inspect(
          EudToolInspectionRequest(
            projectProfilePath: bundled ? null : installationPath,
            bundledPath: bundled ? installationPath : null,
          ),
        );
        expect(inspection.isReady, isTrue, reason: '${inspection.diagnostics}');
        expect(inspection.tool?.version.toString(), '0.10.2.5');
        final tool = inspection.tool!;
        final toolFilesBefore = await _installationHashes(
          tool.installationPath,
        );
        addTearDown(() async {
          expect(
            await _installationHashes(tool.installationPath),
            toolFilesBefore,
            reason:
                'The compiler installation must not change during the smoke test.',
          );
        });

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
        var entrySource = await File('test/fixtures/eud/minimal-smoke.eps')
            .absolute
            .copy('${sourceDirectory.path}${Platform.pathSeparator}최소 스모크.eps');
        if (python) {
          var translated = PortableEudScript.parse(
            await entrySource.readAsString(),
            TriggerScriptLanguage.epScript,
          ).convert(TriggerScriptLanguage.python);
          if (mode == 2) {
            final gateway = ProcessEudSourceTranslationGateway(
              helperPath:
                  '${File(archiveHelperPath!).parent.path}/eud_source_translate_helper.exe',
              bundlePath: tool.installationPath,
            );
            translated = (await gateway.toPython(
              await File('test/fixtures/eud/free-smoke.eps').readAsString(),
            )).source;
            await File(
              '${sourceDirectory.path}/editor_helper.py',
            ).writeAsString(
              'def identity(value):\n    return value\n',
              flush: true,
            );
            translated =
                'from editor_helper import identity\nassert identity(7) == 7\n$translated';
          }
          entrySource = await File(
            '${sourceDirectory.path}${Platform.pathSeparator}최소 스모크.py',
          ).writeAsString(translated, flush: true);
        }
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
            compilerGateway: ProcessEudCompilerGateway(
              parentEnvironment: bundled
                  ? {
                      'SYSTEMROOT': Platform.environment['SYSTEMROOT']!,
                      'WINDIR': Platform.environment['SYSTEMROOT']!,
                      'TEMP': systemRoot.path,
                      'TMP': systemRoot.path,
                      'PATH': '',
                    }
                  : null,
            ),
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
        final toolSettings = EudToolSettingsController(
          store: InMemorySettingsStore({
            if (!bundled)
              EudToolSettingsController.settingsKey: tool.installationPath,
          }),
          bundledPath: bundled ? tool.installationPath : null,
          inspector: toolInspector,
        );
        addTearDown(toolSettings.dispose);
        final scan = await const LocalSourceWorkspaceGateway().scan(
          sourceDirectory.path,
        );
        final revisions = {
          for (final file in scan.files) file.relativePath: file.revision,
        };
        final preparation = EudBuildPreparationController(
          tools: toolSettings,
          builds: controller,
          files: LocalEudBuildFileGateway(),
          blockReason: () => null,
          sourceRevisions: () => revisions,
        );
        final error = await preparation.prepare(
          baseMap: baseMap.path,
          sourceRoot: sourceDirectory.path,
          entrySource: entrySource.path,
          outputMap: outputMap.path,
          trustSource: true,
        );
        expect(error, isNull);
        expect(
          controller.state.plan!.configuration.compilerProfile.language,
          python ? 'Python' : 'epScript',
        );
        expect(
          controller.state.plan!.tool.pathSource,
          bundled ? EudToolPathSource.bundled : EudToolPathSource.userSettings,
        );
        final succeeded = await controller.start();
        final sourcesAfter = await const LocalSourceWorkspaceGateway().scan(
          sourceDirectory.path,
        );
        expect(
          succeeded,
          isTrue,
          reason:
              'status=${controller.state.status}; '
              'dependencies before=$revisions after=${{for (final f in sourcesAfter.files) f.relativePath: f.revision}}; '
              'diagnostics=${controller.state.diagnostics.map((diagnostic) => '${diagnostic.code}:${diagnostic.message}:${diagnostic.rawDetails}')}; '
              'stdout=${controller.state.latestRecord?.stdoutLines}; '
              'stderr=${controller.state.latestRecord?.stderrLines}',
        );
        expect(controller.state.status, EudBuildStatus.succeeded);
        if (bundled) {
          expect(
            controller.state.latestRecord!.stdoutLines.join('\n'),
            contains('Bundled tool updates are managed by the application'),
          );
        }
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
}

Future<Map<String, String>> _installationHashes(String path) async {
  final hashes = <String, String>{};
  await for (final entity in Directory(
    path,
  ).list(recursive: true, followLinks: false)) {
    if (entity is File) {
      hashes[entity.path.substring(path.length)] =
          (await sha256.bind(entity.openRead()).first).toString();
    } else if (entity is Link) {
      throw StateError(
        'Unexpected link in the compiler installation: ${entity.path}',
      );
    }
  }
  return hashes;
}
