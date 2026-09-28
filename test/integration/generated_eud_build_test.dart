import 'dart:io';
import '../fixtures/pcm_sound_fixture.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/eud/eud_rule_expression.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/domain/eud/eud_execution_rule.dart';
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
      final sourceMap = await File(
        'test/fixtures/maps/eud_smoke/eud-smoke-self-authored.scx',
      ).copy('${root.path}/base.scx');
      final archive = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      final extracted = await archive.open(
        MapArchiveOpenRequest(
          operationId: 'rules-base-read',
          sourcePath: sourceMap.path,
          timeout: const Duration(seconds: 30),
        ),
      );
      final document = const RawChkParser()
          .parse(extracted.extractedMap!.scenarioChkBytes)
          .document!;
      final resources = ChkResourceEditor.registerSound(
        document,
        r'sound\rule-silence.wav',
      );
      final soundId = ChkResourceEditor.table(resources).entries.last.stringId;
      final base = File('${root.path}/rules-base.scx');
      await archive.writeTemporary(
        MapArchiveWriteRequest(
          operationId: 'rules-base-write',
          sourcePath: sourceMap.path,
          temporaryOutputPath: base.path,
          scenarioChkBytes: const RawChkEncoder().encode(resources),
          resourceEdits: {r'sound\rule-silence.wav': pcmSoundFixture()},
          timeout: const Duration(seconds: 30),
        ),
      );
      final original = await base.readAsBytes();
      final sourceRoot = await Directory('${root.path}/src').create();
      final entry = await File('${sourceRoot.path}/user.eps').writeAsString(
        'function onPluginStart() { py_print("USER_INIT_AFTER_SETTINGS"); }',
      );
      final source = await entry.readAsBytes();
      final pipeline = SafeEudBuildPipeline(
        toolInspector: inspector,
        compilerGateway: ProcessEudCompilerGateway(),
        archiveGateway: ProcessMapArchiveGateway(helperExecutablePath: helper),
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
            rules: [
              for (final action in EudRuleAction.values)
                EudExecutionRule(
                  id: 'extended_${action.name}',
                  name: action.name,
                  player: 7,
                  resource: EudResource.ore,
                  comparison: EudComparison.atLeast,
                  threshold: 0,
                  operation: EudResourceOperation.setTo,
                  amount: 1,
                  schedule: EudRuleSchedule.periodic,
                  extension: EudRuleExtension(
                    action: action,
                    target: action == EudRuleAction.sound
                        ? soundId
                        : action == EudRuleAction.location
                        ? 1
                        : action == EudRuleAction.followUnit
                        ? 2
                        : 0,
                    unitType: 70,
                    text: 'Value {} 한글',
                    timing: action == EudRuleAction.text
                        ? EudRuleTiming.afterTriggers
                        : EudRuleTiming.beforeTriggers,
                    left: EudRuleValue(source: EudValueSource.upgrade),
                    right: EudRuleValue(),
                    value: action == EudRuleAction.variable
                        ? EudRuleValue(
                            source: EudValueSource.gas,
                            factor: 2,
                            offset: -10,
                          )
                        : EudRuleValue(source: EudValueSource.variable),
                    coordinates: action == EudRuleAction.location
                        ? [for (var i = 0; i < 4; i++) EudRuleValue(index: 32)]
                        : [],
                  ),
                ),
              for (final schedule in EudRuleSchedule.values)
                EudExecutionRule(
                  id: schedule.name,
                  name: schedule.name,
                  player: schedule.index,
                  resource: EudResource.values[schedule.index],
                  comparison: EudComparison.values[schedule.index],
                  threshold: 100,
                  operation: schedule == EudRuleSchedule.once
                      ? EudResourceOperation.add
                      : EudResourceOperation.subtract,
                  amount: 50,
                  schedule: schedule,
                ),
              EudExecutionRule(
                id: 'exact',
                name: 'exact',
                player: 2,
                resource: EudResource.ore,
                comparison: EudComparison.exactly,
                threshold: 0,
                operation: EudResourceOperation.setTo,
                amount: 10,
              ),
            ],
            overrides: [
              if (run != 2)
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
