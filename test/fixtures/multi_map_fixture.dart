import 'dart:async';
import 'dart:typed_data';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/commands/editor_command_dispatcher.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/document_workspace_controller.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_palette_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_workspace.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/eud/reserved_eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/objects/object_sprite_atlas_loader.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/directory_picker.dart';
import 'package:starcraft_map_editor/application/ports/eud_build_gateway.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_diagnostic_parser.dart';
import 'package:starcraft_map_editor/application/ports/eud_compiler_models.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_picker.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_store.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_inspector.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_resource_gateway.dart';
import 'package:starcraft_map_editor/application/ports/recovery_store.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_tile_atlas_loader.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/object_sprite_texture_controller.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture_controller.dart';
import 'basic_editing_fixture.dart';
import 'new_map_harness.dart';

class MultiMapFixture {
  MultiMapFixture({
    MapArchiveGateway? archive,
    MapFileFingerprintGateway? fingerprints,
    MapSaveFileGateway? files,
    RecoveryStore? recovery,
    MapResourceGateway? resourceGateway,
  }) {
    archives = archive ?? fakeArchive;
    hashes = fingerprints ?? _Fingerprints();
    saveFiles = files ?? paths;
    store = recovery ?? memoryRecovery;
    resourceFiles = resourceGateway ?? resources;
    workspace = DocumentWorkspaceController(
      createDocument: _create,
      filePicker: picker,
      paths: saveFiles,
    );
  }
  final picker = NewMapPicker();
  final settings = InMemorySettingsStore();
  final paths = WorkspacePaths();
  final fakeArchive = WorkspaceArchive();
  final memoryRecovery = WorkspaceRecovery();
  final projectStore = WorkspaceProjects();
  final resources = WorkspaceResources();
  final builds = <String, WorkspaceBuilds>{};
  final disposed = <String>[];
  Future<void> Function()? beforeDispose;
  late final MapArchiveGateway archives;
  late final MapFileFingerprintGateway hashes;
  late final MapSaveFileGateway saveFiles;
  late final RecoveryStore store;
  late final MapResourceGateway resourceFiles;
  late final DocumentWorkspaceController<EditorAppDependencies> workspace;
  late final assets = StarCraftDataAssetSettingsController(
    settingsStore: settings,
    directoryPicker: _Directory(),
    inspector: _Inspector(),
  );
  WorkspaceDocument<EditorAppDependencies> _create(String id) {
    final progress = OperationProgressController(),
        recent = RecentProjectsService(settings);
    final maps = OpenMapController(
      archiveGateway: archives,
      filePicker: picker,
      fingerprintGateway: hashes,
      recentProjectsService: recent,
      operationProgressController: progress,
    );
    final saves = SaveMapController(
      archiveGateway: archives,
      filePicker: picker,
      fingerprintGateway: hashes,
      saveFileGateway: saveFiles,
      openMapController: maps,
      operationProgressController: progress,
      reserveDestination: (path) =>
          workspace.reserve(id, path, purpose: WorkspacePathPurpose.mapOutput),
    );
    final sources = EudSourceController(), gateway = WorkspaceBuilds();
    builds[id] = gateway;
    final eud = EudBuildController(
      buildGateway: ReservedEudBuildGateway(
        delegate: gateway,
        reserve: (path) => workspace.reserve(
          id,
          path,
          purpose: WorkspacePathPurpose.buildOutput,
        ),
      ),
      diagnosticParser: const IgnoreEudCompilerDiagnostics(),
      operationProgressController: progress,
    );
    final projects = EudProjectWorkspace(
      projects: EudProjectController(
        projectStore,
        reserveDestination: (path) => workspace.reserve(
          id,
          path,
          purpose: WorkspacePathPurpose.projectOutput,
        ),
      ),
      maps: maps,
      picker: _ProjectsPicker(),
    );
    final autosave = AutosaveController(
      maps: maps,
      sources: sources,
      projects: projects.projects,
      store: store,
      settings: settings,
      ownerId: id,
      reserveRestoreInput: (path) => workspace.reserve(
        id,
        path,
        purpose: WorkspacePathPurpose.restoreInput,
      ),
      canAccessCheckpoint: (checkpoint) =>
          workspace.canAccessCheckpoint(id, checkpoint),
    );
    final layers = MapLayerController(),
        terrain = TerrainEditingController(openMapController: maps);
    final editing = ObjectEditingController(
      resourceGateway: resourceFiles,
      openMapController: maps,
      mapLayerController: layers,
    );
    final palette = ObjectPaletteController(
      objectEditingController: editing,
      mapLayerController: layers,
    );
    final tileGateway = _Tiles();
    final catalog = PlacementCatalogController(
      openMapController: maps,
      objectEditingController: editing,
      terrainEditingController: terrain,
      catalogGateway: NewMapCatalog(),
      tileAtlasGateway: tileGateway,
    );
    final tiles = TerrainTileTextureController(
      loader: TerrainTileAtlasLoader(gateway: tileGateway),
    );
    final objects = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: _Objects()),
    );
    final dispatcher = EditorCommandDispatcher({
      EditorCommandId.openMap: (argument) async {
        await workspace.open(path: argument is String ? argument : null);
      },
      EditorCommandId.saveAs: (_) async {
        await saves.saveAs();
      },
      EditorCommandId.newEudSource: (_) {
        sources.createUntitled();
      },
    });
    final deps = EditorAppDependencies(
      commandDispatcher: dispatcher,
      openMapController: maps,
      saveMapController: saves,
      eudBuildController: eud,
      eudSourceController: sources,
      eudProjectWorkspace: projects,
      operationProgressController: progress,
      recentProjectsService: recent,
      settingsStore: settings,
      starCraftDataAssetSettingsController: assets,
      terrainEditingController: terrain,
      mapLayerController: layers,
      objectEditingController: editing,
      objectPaletteController: palette,
      placementCatalogController: catalog,
      terrainTileTextureController: tiles,
      objectSpriteTextureController: objects,
      autosaveController: autosave,
    );
    return WorkspaceDocument(
      id: id,
      value: deps,
      maps: maps,
      saves: saves,
      sources: sources,
      builds: eud,
      projects: projects,
      autosave: autosave,
      additionalBusy: () => editing.isBusy,
      additionalChanges: editing.changes,
      disposeOwned: () async {
        await beforeDispose?.call();
        disposed.add(id);
        await autosave.dispose();
        await catalog.dispose();
        await palette.dispose();
        await editing.dispose();
        await terrain.dispose();
        // Widget tests unmount the host before fixture teardown.
        tiles.dispose();
        objects.dispose();
        projects.dispose();
        projects.projects.dispose();
        sources.dispose();
        await eud.dispose();
        await saves.dispose();
        await maps.dispose();
        await layers.dispose();
        await progress.dispose();
      },
    );
  }

  WorkspaceDocument<EditorAppDependencies> addMap({int tile = 1}) {
    final d = workspace.prepareDocument();
    d.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: tile),
      expectedSession: null,
    );
    workspace.publish(d);
    return d;
  }

  Future<void> dispose() async {
    await workspace.dispose();
    assets.dispose();
  }
}

class WorkspacePaths implements MapSaveFileGateway {
  final aliases = <String, String>{};
  Future<void> Function()? beforeCompare;
  int writes = 0;
  String key(String path) {
    final normalized = Uri.file(
      path,
      windows: true,
    ).normalizePath().toFilePath(windows: true).toLowerCase();
    return aliases[normalized] ?? normalized;
  }

  @override
  Future<bool> refersToSameLocation(String a, String b) async {
    await beforeCompare?.call();
    return key(a) == key(b);
  }

  @override
  Future<bool> destinationExists(String path) async => false;
  @override
  Future<MapSaveWorkspace> createWorkspace(String path) async {
    writes++;
    throw StateError('No writes expected.');
  }

  @override
  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async => throw StateError('No writes expected.');
  @override
  Future<void> cleanup(MapSaveWorkspace workspace) async {}
}

class WorkspaceArchive implements MapArchiveGateway {
  Completer<void>? pending;
  bool fail = false;
  final opened = <String>[];
  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    opened.add(request.sourcePath);
    await pending?.future;
    if (fail) throw StateError('Archive unavailable');
    final bytes = const RawChkEncoder().encode(basicDocument());
    return MapArchiveOpenResult.success(
      map: ExtractedMap(
        sourcePath: request.sourcePath,
        scenarioChkBytes: bytes,
        metadata: MapArchiveMetadata(
          archiveSizeBytes: bytes.length,
          formatVersion: 1,
          totalEntryCount: 1,
          listingComplete: true,
          entries: [
            MapArchiveEntryMetadata(
              path: MapArchiveEntryPaths.scenarioChk,
              uncompressedSizeBytes: bytes.length,
              compressedSizeBytes: bytes.length,
              flags: 0x80000000,
              locale: 0,
              nameIsSynthetic: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) async => throw StateError('No writes expected');
  @override
  Future<bool> cancel(String operationId) async => false;
}

class _Fingerprints implements MapFileFingerprintGateway {
  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 1024,
        modifiedAt: DateTime.utc(2026),
        sha256Digest: 'a' * 64,
      );
}

class WorkspaceRecovery implements RecoveryStore {
  final values = <String, String>{};
  @override
  Future<List<RecoveryEntry>> list() async => [
    for (final e in values.entries) RecoveryEntry(id: e.key, content: e.value),
  ];
  @override
  Future<void> write(String id, String content) async {
    values[id] = content;
  }

  @override
  Future<void> remove(String id) async {
    values.remove(id);
  }
}

class WorkspaceProjects implements EudProjectStore {
  final values = <String, EudProject>{};
  @override
  Future<EudProjectFile> read(String path) async =>
      EudProjectFile(project: values[path]!, revision: values[path]!.encode());
  @override
  Future<EudProjectFile> saveAs(String path, EudProject project) async {
    if (values.containsKey(path)) throw StateError('Exists');
    values[path] = project;
    return EudProjectFile(project: project, revision: project.encode());
  }

  @override
  Future<EudProjectFile> save(
    String path,
    EudProject project, {
    required String expectedRevision,
  }) async {
    if (values[path]?.encode() != expectedRevision) {
      throw EudProjectConflict(path);
    }
    values[path] = project;
    return EudProjectFile(project: project, revision: project.encode());
  }
}

class WorkspaceBuilds implements EudBuildGateway {
  final completion = Completer<bool>();
  int started = 0;
  @override
  Stream<EudBuildEvent> build(EudBuildPlan plan) async* {
    started++;
    yield EudBuildEvent.started(
      buildId: plan.buildId,
      toolVersion: plan.tool.version,
    );
    final result = await completion.future;
    yield result
        ? EudBuildEvent.succeeded(buildId: plan.buildId, exitCode: 0)
        : EudBuildEvent.cancelled(
            buildId: plan.buildId,
            diagnostic: const EditorDiagnostic(
              code: 'TEST_CANCELLED',
              message: 'Cancelled',
              severity: DiagnosticSeverity.error,
              stage: DiagnosticStage.compile,
            ),
          );
  }

  @override
  Future<bool> cancel(String buildId) async {
    if (!completion.isCompleted) completion.complete(false);
    return true;
  }
}

class WorkspaceResources implements MapResourceGateway {
  Completer<({String name, List<int> bytes})?>? pending;
  @override
  Future<({String name, List<int> bytes})?> importSound() async =>
      pending == null ? null : await pending!.future;
  @override
  Future<List<int>?> readSound(String archive, String path) async => null;
  @override
  Future<void> exportSound(String name, List<int> bytes) async {}
  @override
  Future<void> preview(List<int> bytes) async {}
  @override
  Future<void> stopPreview() async {}
}

EudBuildPlan workspacePlan(
  String id, {
  String output = r'C:\Maps\output.scx',
}) => EudBuildPlan(
  buildId: id,
  configuration: EudBuildConfiguration(
    baseMapPath: r'C:\Maps\base.scx',
    sourceRootPath: r'C:\Source',
    entrySourcePath: r'C:\Source\main.eps',
    outputMapPath: output,
  ),
  tool: EudToolInfo(
    pathSource: EudToolPathSource.projectProfile,
    installationPath: r'C:\Tools\euddraft',
    executablePath: r'C:\Tools\euddraft\euddraft.exe',
    versionFilePath: r'C:\Tools\euddraft\VERSION',
    version: EudToolVersion.parse('0.10.2.5'),
    companionPaths: const [],
  ),
  timeout: const Duration(minutes: 1),
);

class _ProjectsPicker implements EudProjectPicker {
  @override
  Future<String?> openProject() async => null;
  @override
  Future<String?> saveProjectAs() async => null;
}

class _Directory implements DirectoryPicker {
  @override
  Future<String?> pickStarCraftInstallationDirectory() async => null;
}

class _Inspector implements StarCraftDataAssetInspector {
  @override
  Future<StarCraftDataAssetInspection> inspect(String path) async =>
      StarCraftDataAssetInspection(
        installationPath: path,
        requiredAssetCount: 0,
        foundAssetCount: 0,
      );
}

class _Tiles implements StarCraftTileAtlasGateway {
  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async => StarCraftTileAtlasResult(
    request: request,
    tileSize: 32,
    columns: request.rawValues.length,
    rows: 1,
    rawValues: request.rawValues,
    rgbaBytes: Uint8List(request.rawValues.length * 4096),
    unsupportedRawValues: [],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.13.0',
    cascLibRevision: 'test',
  );
}

class _Objects implements StarCraftObjectAtlasGateway {
  @override
  Future<void> cancel(String operationId) async {}
  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async => StarCraftObjectAtlasResult.failed(
    request: request,
    diagnostic: const EditorDiagnostic(
      code: 'TEST_NO_OBJECT_ATLAS',
      message: 'Synthetic map',
      severity: DiagnosticSeverity.warning,
      stage: DiagnosticStage.application,
    ),
  );
}
