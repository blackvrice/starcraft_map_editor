import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';

void main() {
  final toolPath = Platform.environment['EUDDRAFT_TEST_INSTALLATION'];
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'generated settings pass safe build, preserve entry, repeat from base and reject mismatched binding',
    () async {
      final inspector = BundledEudTool.inspector();
      final inspection = await inspector.inspect(
        EudToolInspectionRequest(bundledPath: toolPath),
      );
      expect(inspection.isReady, isTrue);
      final root = await Directory.systemTemp.createTemp(
        'generated-eud-build-',
      );
      addTearDown(() => root.delete(recursive: true));
      final base = await File(
        'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
      ).copy('${root.path}/base.scx');
      final original = await base.readAsBytes();
      final sourceRoot = await Directory('${root.path}/src').create();
      final entry = await File('${sourceRoot.path}/user.eps').writeAsString(
        'function onPluginStart() { py_print("USER_INIT_AFTER_SETTINGS"); }',
      );
      final source = await entry.readAsBytes();
      final pipeline = SafeEudBuildPipeline(
        toolInspector: inspector,
        compilerGateway: ProcessEudCompilerGateway(),
        archiveGateway: ProcessMapArchiveGateway(helperExecutablePath: helper!),
        fingerprintGateway: LocalMapFileFingerprintGateway(),
        buildFileGateway: LocalEudBuildFileGateway(),
      );
      for (var run = 0; run < 4; run++) {
        final generated = EudGeneratedSettings(
          EudProject(
            mapPath: base.path,
            mapSha256: run == 3
                ? '0' * 64
                : sha256.convert(original).toString(),
            overrides: [
              EudOverride(
                field: 'unit.maxShield',
                targetId: 70,
                value: 300,
                overrideChk: true,
              ),
            ],
          ),
        );
        final output = File('${root.path}/output-$run.scx');
        final events = await pipeline
            .build(
              EudBuildPlan(
                buildId: 'generated-$run',
                configuration: EudBuildConfiguration(
                  baseMapPath: base.path,
                  sourceRootPath: sourceRoot.path,
                  entrySourcePath: entry.path,
                  outputMapPath: output.path,
                  generatedSettings: generated,
                  settingsOnly: run == 2,
                ),
                tool: inspection.tool!,
                timeout: const Duration(minutes: 1),
              ),
            )
            .toList();
        final log = events
            .map((e) => e.text ?? e.diagnostic?.toString() ?? '')
            .join('\n');
        if (run == 3) {
          expect(
            events.last.diagnostic?.code,
            EudBuildPipelineDiagnosticCodes.projectChanged,
          );
          expect(await output.exists(), isFalse);
        } else {
          expect(events.last.kind, EudBuildEventKind.succeeded, reason: log);
          expect(await output.length(), greaterThan(original.length));
          expect(log, contains('EDITOR_SETTINGS_V1_INITIALIZED'));
          if (run != 2) {
            expect(log, contains('USER_INIT_AFTER_SETTINGS'));
            expect(
              log.indexOf('EDITOR_SETTINGS_V1_INITIALIZED'),
              lessThan(log.indexOf('USER_INIT_AFTER_SETTINGS')),
            );
          }
        }
        expect(await base.readAsBytes(), original);
        expect(await entry.readAsBytes(), source);
        expect(
          root.listSync().whereType<Directory>().where(
            (d) => d.path.contains('.starcraft_map_editor_eud_'),
          ),
          isEmpty,
        );
      }
    },
    skip:
        !Platform.isWindows ||
        toolPath == null ||
        helper == null ||
        Platform.environment['EUDDRAFT_TEST_BUNDLED'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
