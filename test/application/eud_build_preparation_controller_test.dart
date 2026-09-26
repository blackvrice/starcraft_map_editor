import 'dart:async';
import '../fixtures/eud_project_workspace_fixture.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_preparation_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_file_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'eud_tool_settings_controller_test.dart' show TestInspector;

void main() {
  test(
    'project test builds require opt-in, verified binding and a current snapshot',
    () async {
      final h = PreparationHarness();
      final f = EudWorkspaceFixture();
      addTearDown(h.dispose);
      addTearDown(f.dispose);
      await f.maps.open();
      await f.workspace.createFromMap();
      f.projects.replaceOverrides([
        EudOverride(
          field: 'unit.maxShield',
          targetId: 70,
          value: 300,
          overrideChk: true,
        ),
      ]);
      final controller = EudBuildPreparationController(
        tools: h.tools,
        builds: h.builds,
        files: ProjectPreparationFiles(),
        blockReason: () => null,
        projects: f.workspace,
      );
      Future<String?> prepare(bool allow) => controller.prepare(
        baseMap: f.projects.project!.mapPath,
        sourceRoot: '',
        entrySource: '',
        outputMap: r'C:\out\test.scx',
        trustSource: true,
        allowUnverifiedSettings: allow,
      );
      expect(await prepare(false), contains('unverified'));
      expect(await prepare(true), isNull);
      final plan = h.builds.state.plan!;
      expect(plan.configuration.settingsOnly, isTrue);
      expect(
        plan.configuration.generatedSettings!.source,
        contains('TrgUnit(70).maxShield = 300'),
      );
      expect(plan.contextIsCurrent!(), isTrue);
      f.projects.replaceOverrides([]);
      expect(plan.contextIsCurrent!(), isFalse);
      f.projects.undo();
      f.hash = 'b' * 64;
      expect(await prepare(true), isNotNull);
      expect(h.builds.canStart, isFalse);
    },
  );
  late PreparationHarness h;
  setUp(() {
    h = PreparationHarness();
  });
  tearDown(() => h.dispose());
  test(
    'prepares saved user choice without invoking compiler or replacing output',
    () async {
      expect(await h.prepare(), isNull);
      expect(h.builds.canStart, true);
      expect(
        h.builds.state.plan!.tool.pathSource,
        EudToolPathSource.userSettings,
      );
      expect(h.builds.state.plan!.replaceExistingOutput, false);
      expect(h.files.validations, 1);
    },
  );
  test('per-build override takes priority over saved user choice', () async {
    expect(await h.prepare(override: r'C:\project-tool'), isNull);
    expect(
      h.builds.state.plan!.tool.pathSource,
      EudToolPathSource.projectProfile,
    );
    expect(h.builds.state.plan!.tool.installationPath, r'C:\project-tool');
  });
  test(
    'trust, dirty context and invalid paths invalidate prior preparation',
    () async {
      await h.prepare();
      expect(await h.prepare(trust: false), contains('trust'));
      expect(h.builds.canStart, false);
      h.block = 'Unsaved map';
      expect(await h.prepare(), 'Unsaved map');
      h.block = null;
      expect(await h.prepare(output: r'C:\maps\base.scx'), contains('failed'));
      expect(h.builds.canStart, false);
    },
  );
  test('tool diagnostics do not fall back and cannot create a plan', () async {
    h.inspector.fail = true;
    expect(await h.prepare(), contains('EUD_TOOL_COMPANION_MISSING'));
    expect(h.files.validations, 0);
    expect(h.builds.canStart, false);
  });
  test(
    'existing output, canonical alias and invalid files are rejected',
    () async {
      h.files.exists = true;
      expect(await h.prepare(), contains('already exists'));
      h.files.exists = false;
      h.files.same = true;
      expect(await h.prepare(), contains('separate'));
      h.files.same = false;
      h.files.invalid = true;
      expect(await h.prepare(), contains('invalid files'));
      expect(h.builds.canStart, false);
    },
  );
  test(
    'cancelled and changed tool selections cannot publish stale preparation',
    () async {
      final wait = Completer<void>();
      h.files.wait = wait.future;
      final operation = h.prepare();
      await Future<void>.delayed(Duration.zero);
      expect(await h.prepare(), contains('already running'));
      h.controller.cancel();
      wait.complete();
      expect(await operation, contains('cancelled'));
      expect(h.builds.canStart, false);
      final secondWait = Completer<void>();
      h.files.wait = secondWait.future;
      final second = h.prepare();
      await Future<void>.delayed(Duration.zero);
      await h.tools.selectExternal(r'C:\other');
      secondWait.complete();
      expect(await second, contains('selection changed'));
      expect(h.builds.canStart, false);
    },
  );
  test('dirty state arising during inspection blocks publication', () async {
    final wait = Completer<void>();
    h.files.wait = wait.future;
    final operation = h.prepare();
    await Future<void>.delayed(Duration.zero);
    h.block = 'Changed source';
    wait.complete();
    expect(await operation, 'Changed source');
    expect(h.builds.canStart, false);
  });
}

class PreparationHarness {
  final inspector = ReadyInspector();
  final files = PreparationFiles();
  final progress = OperationProgressController();
  late final builds = EudBuildController(
    buildGateway: NoBuildGateway(),
    diagnosticParser: const IgnoreEudCompilerDiagnostics(),
    operationProgressController: progress,
  );
  late final tools = EudToolSettingsController(
    store: InMemorySettingsStore({
      EudToolSettingsController.settingsKey: r'C:\user-tool',
    }),
    inspector: inspector,
  );
  String? block;
  late final controller = EudBuildPreparationController(
    tools: tools,
    builds: builds,
    files: files,
    blockReason: () => block,
  );
  Future<String?> prepare({
    bool trust = true,
    String? override,
    String output = r'C:\out\new.scx',
  }) => controller.prepare(
    baseMap: r'C:\maps\base.scx',
    sourceRoot: r'C:\src',
    entrySource: r'C:\src\main.eps',
    outputMap: output,
    projectToolPath: override,
    trustSource: trust,
  );
  Future<void> dispose() async {
    await tools.dispose();
    await builds.dispose();
    await progress.dispose();
  }
}

class ReadyInspector implements EudToolInspector {
  bool fail = false;
  @override
  Future<EudToolInspectionResult> inspect(
    EudToolInspectionRequest request,
  ) async {
    if (fail) return TestInspector.failure();
    final candidate = request.selectedCandidate!;
    return EudToolInspectionResult.ready(
      readyTool: EudToolInfo(
        pathSource: candidate.source,
        installationPath: candidate.path,
        executablePath: '${candidate.path}\\euddraft.exe',
        versionFilePath: '${candidate.path}\\VERSION',
        version: EudToolVersion.parse('0.10.2.5'),
        companionPaths: const [],
      ),
    );
  }
}

class PreparationFiles implements EudBuildFileGateway {
  bool exists = false, same = false, invalid = false;
  int validations = 0;
  Future<void>? wait;
  @override
  Future<void> validateInputs(EudBuildConfiguration configuration) async {
    validations++;
    if (invalid) throw StateError('invalid files');
    if (wait != null) await wait;
  }

  @override
  Future<bool> destinationExists(String path) async => exists;
  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async =>
      same;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Preparation must not write files: $invocation');
}

class ProjectPreparationFiles extends PreparationFiles {
  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async =>
      leftPath == rightPath;
}

class NoBuildGateway implements EudBuildGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Preparation must not execute compiler: $invocation');
}
