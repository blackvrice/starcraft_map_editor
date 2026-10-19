import '../ports/eud_build_file_gateway.dart';
import '../ports/eud_build_gateway.dart';
import '../settings/eud_tool_settings_controller.dart';
import 'eud_build_configuration.dart';
import 'eud_build_controller.dart';
import 'eud_project_workspace.dart';
import '../../domain/eud/eud_generated_settings.dart';
import '../../domain/eud/eud_conflict_analysis.dart';
import '../../domain/eud/eud_rule_references.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

final class EudBuildPreparationController {
  EudBuildPreparationController({
    required this.tools,
    required this.builds,
    required this.files,
    required this.blockReason,
    this.projects,
    this.validateSources,
    this.sourceRevision,
    this.sourceRevisions,
  });
  final EudToolSettingsController tools;
  final EudBuildController builds;
  final EudBuildFileGateway files;
  final String? Function() blockReason;
  final EudProjectWorkspace? projects;
  final Future<void> Function(String root, String entry)? validateSources;
  final int Function()? sourceRevision;
  final Map<String, String> Function()? sourceRevisions;
  bool get hasProjectSettings => projects?.hasUnbuiltOverrides ?? false;
  bool busy = false;
  List<EditorDiagnostic> _diagnostics = const [];
  List<EditorDiagnostic> get diagnostics => _diagnostics;
  int _revision = 0;
  int _sequence = 0;
  void cancel() {
    _revision++;
  }

  Future<String?> prepare({
    required String baseMap,
    required String sourceRoot,
    required String entrySource,
    required String outputMap,
    String? projectToolPath,
    required bool trustSource,
    bool allowUnverifiedSettings = false,
  }) async {
    if (busy || builds.state.isActive) {
      return 'A build or preparation is already running.';
    }
    busy = true;
    _diagnostics = const [];
    final revision = ++_revision;
    try {
      builds.clearPreparation();
      if (!trustSource) {
        return 'Confirm that you trust the EUD source and its imports.';
      }
      final blocked = blockReason();
      if (blocked != null) return blocked;
      if (entrySource.isNotEmpty) {
        await validateSources?.call(sourceRoot, entrySource);
      }
      final expectedSourceRevision = sourceRevision?.call();
      final project = projects?.projects.project;
      final mapSession = projects?.maps.state.session;
      bool contextIsCurrent() =>
          sourceRevision?.call() == expectedSourceRevision &&
          identical(projects?.projects.project, project) &&
          identical(projects?.maps.state.session, mapSession) &&
          !(projects?.isBusy ?? false) &&
          blockReason() == null;
      EudGeneratedSettings? generated;
      if (project != null && project.hasGeneratedContent) {
        if (!allowUnverifiedSettings) {
          return 'Enable the unverified settings test build to compile project settings.';
        }
        await projects!.verify();
        if (projects!.binding != EudMapBinding.matched || !contextIsCurrent()) {
          return 'Verify the saved map and EUD project binding before building.';
        }
        if (!await files.refersToSameLocation(project.mapPath, baseMap)) {
          return 'The build base must be the map bound to this EUD project.';
        }
        final references = EudRuleReferences.validate(
          project,
          mapSession!.rawDocument,
        );
        if (references.isNotEmpty) return references.join(', ');
        generated = EudGeneratedSettings(
          project,
          conflicts: EudConflictAnalysis.analyze(
            project,
            document: mapSession.rawDocument,
          ),
        );
      }
      final configuration = EudBuildConfiguration(
        sourceRevisions: entrySource.isEmpty
            ? const {}
            : sourceRevisions?.call() ?? const {},
        compilerProfile: entrySource.toLowerCase().endsWith('.py')
            ? EudCompilerProfile.starcraftRemasteredPython
            : EudCompilerProfile.starcraftRemastered,
        baseMapPath: baseMap,
        sourceRootPath: sourceRoot,
        entrySourcePath: entrySource,
        outputMapPath: outputMap,
        generatedSettings: generated,
        settingsOnly: generated != null && entrySource.trim().isEmpty,
        compilerPathOverride:
            projectToolPath == null || projectToolPath.trim().isEmpty
            ? null
            : projectToolPath,
      );
      await tools.load();
      if (tools.state.busy || tools.state.error != null) {
        return 'Finish or retry EUD Tools settings first.';
      }
      final request = tools.inspectionRequest(
        projectProfilePath: configuration.compilerPathOverride,
      );
      final inspected = await tools.inspector.inspect(request);
      if (!inspected.isReady) {
        _diagnostics = List.unmodifiable(inspected.diagnostics);
        return inspected.diagnostics
            .map(
              (d) =>
                  '${d.code}: ${d.message}\n${d.remediation ?? ''}\n${d.rawDetails ?? ''}',
            )
            .join('\n');
      }
      await files.validateInputs(configuration);
      if (await files.refersToSameLocation(baseMap, outputMap)) {
        return 'Choose an output separate from the base map.';
      }
      if (await files.destinationExists(outputMap)) {
        return 'Output already exists. Choose a new .scx path.';
      }
      if (revision != _revision) return 'Preparation cancelled.';
      final current = tools
          .inspectionRequest(
            projectProfilePath: configuration.compilerPathOverride,
          )
          .selectedCandidate;
      if (current?.path != request.selectedCandidate?.path ||
          current?.source != request.selectedCandidate?.source ||
          tools.state.busy) {
        return 'Tool selection changed. Prepare again.';
      }
      final currentBlock = blockReason();
      if (currentBlock != null) return currentBlock;
      if (!contextIsCurrent()) return 'Project or map changed. Prepare again.';
      builds.prepare(
        EudBuildPlan(
          buildId:
              'editor-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}',
          configuration: configuration,
          tool: inspected.tool!,
          timeout: const Duration(minutes: 5),
          contextIsCurrent: contextIsCurrent,
        ),
      );
      return null;
    } catch (error) {
      return 'Build preparation failed: $error';
    } finally {
      busy = false;
    }
  }
}
