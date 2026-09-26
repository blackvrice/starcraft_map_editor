import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/eud/eud_generated_settings.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/safe_eud_build_pipeline.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/bundled_eud_tool.dart';
import 'package:starcraft_map_editor/infrastructure/compiler/process_eud_compiler_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'generate_eud_smoke_fixture.dart' show generateMapFixture;
import 'generate_settings_smoke_fixture.dart' show buildSettingsSmokeScenario;

/// Produces observation maps, not assertions of game compatibility.
Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError(
      'Usage: <bundled-tool-dir> <archive-helper.exe> <new-output-directory>',
    );
  }
  final root = Directory(args[2]).absolute;
  if (await root.exists()) throw StateError('Choose a new output directory.');
  final inspector = BundledEudTool.inspector();
  final inspection = await inspector.inspect(
    EudToolInspectionRequest(bundledPath: Directory(args[0]).absolute.path),
  );
  if (!inspection.isReady) throw StateError('${inspection.diagnostics}');
  await root.create(recursive: true);
  final base = File('${root.path}/baseline.scx');
  await generateMapFixture(
    ['--helper', File(args[1]).absolute.path, '--output', base.path],
    scenarioBuilder: () {
      var document = const RawChkParser()
          .parse(buildSettingsSmokeScenario(modified: false))
          .document!;
      final locationIndex = document.sections.indexWhere(
        (s) => s.name == 'MRGN',
      );
      final locations = Uint8List.fromList(
        document.sections[locationIndex].payload,
      );
      // Location 1 is a spawn point below the preplaced observation units.
      final data = ByteData.sublistView(locations);
      data.setUint32(0, 224, Endian.little);
      data.setUint32(4, 416, Endian.little);
      data.setUint32(8, 352, Endian.little);
      data.setUint32(12, 544, Endian.little);
      document = document.replaceSection(
        locationIndex,
        document.sections[locationIndex].withPayload(locations),
      );
      return const RawChkEncoder().encode(document);
    },
  );
  final before = await base.readAsBytes();
  final hash = sha256.convert(before).toString();
  final sourceRoot = await Directory('${root.path}/source').create();
  final entry = File('${sourceRoot.path}/observe.eps');
  const source =
      'function onPluginStart() {\n'
      '    py_print("EDITOR_USER_INITIALIZED");\n'
      '    CreateUnit(1, 70, 1, P1);\n'
      '}\n';
  await entry.writeAsString(source);
  final cases = <String, List<EudOverride>>{
    'control': [],
    'shield': [
      EudOverride(field: 'unit.hasShield', targetId: 70, value: true),
      EudOverride(
        field: 'unit.maxShield',
        targetId: 70,
        value: 300,
        overrideChk: true,
      ),
    ],
    'weapon': [
      EudOverride(field: 'weapon.maxRange', targetId: 15, value: 224),
      EudOverride(field: 'weapon.cooldown', targetId: 15, value: 11),
      EudOverride(field: 'weapon.damageType', targetId: 15, value: 'Normal'),
    ],
    'player': [
      EudOverride(field: 'player.terranSupplyMax', targetId: 0, value: 600),
    ],
    'settings-only': [
      EudOverride(
        field: 'unit.maxShield',
        targetId: 70,
        value: 300,
        overrideChk: true,
      ),
    ],
  };
  final pipeline = SafeEudBuildPipeline(
    toolInspector: inspector,
    compilerGateway: ProcessEudCompilerGateway(),
    archiveGateway: ProcessMapArchiveGateway(
      helperExecutablePath: File(args[1]).absolute.path,
    ),
    fingerprintGateway: LocalMapFileFingerprintGateway(),
    buildFileGateway: LocalEudBuildFileGateway(),
  );
  final results = <Map<String, Object?>>[];
  for (final item in cases.entries) {
    final project = EudProject(
      mapPath: base.path,
      mapSha256: hash,
      overrides: item.value,
    );
    final generated = EudGeneratedSettings(project);
    await File(
      '${root.path}/${item.key}.eud.json',
    ).writeAsString(project.encode());
    await File(
      '${root.path}/${item.key}.generated.py',
    ).writeAsString(generated.source);
    await File(
      '${root.path}/${item.key}.manifest.json',
    ).writeAsString(generated.manifest);
    final output = File('${root.path}/${item.key}.scx');
    final plan = EudBuildPlan(
      buildId: 'validation-${item.key}',
      configuration: EudBuildConfiguration(
        baseMapPath: base.path,
        sourceRootPath: sourceRoot.path,
        entrySourcePath: entry.path,
        outputMapPath: output.path,
        generatedSettings: generated,
        settingsOnly: item.key == 'settings-only',
      ),
      tool: inspection.tool!,
      timeout: const Duration(minutes: 2),
    );
    final events = await pipeline.build(plan).toList();
    final log = events
        .map(
          (event) =>
              event.text ?? event.diagnostic?.toString() ?? event.kind.name,
        )
        .join('\n');
    await File('${root.path}/${item.key}.log').writeAsString(log);
    if (events.last.kind != EudBuildEventKind.succeeded) {
      throw StateError('Build failed: ${item.key}\n$log');
    }
    if (item.key != 'settings-only' &&
        !(log.contains('EDITOR_SETTINGS_V1_INITIALIZED') &&
            log.indexOf('EDITOR_SETTINGS_V1_INITIALIZED') <
                log.indexOf('EDITOR_USER_INITIALIZED'))) {
      throw StateError('Unexpected initialization compilation order.');
    }
    if (sha256.convert(await base.readAsBytes()).toString() != hash ||
        await entry.readAsString() != source) {
      throw StateError('Input changed.');
    }
    results.add({
      'case': item.key,
      'output': output.path,
      'sha256': sha256.convert(await output.readAsBytes()).toString(),
      'compileAndArchiveValidation': 'passed',
      'gameObservation': 'pending',
    });
    stdout.writeln('Built ${output.path}');
  }
  await File(
    '${root.path}/results.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
}
