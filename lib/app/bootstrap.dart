import '../infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import '../application/documents/isom_fill_controller.dart';
import '../application/documents/autosave_controller.dart';
import '../infrastructure/filesystem/local_recovery_store.dart';
import 'dart:async';

import '../infrastructure/filesystem/local_map_resource_gateway.dart';
import 'package:flutter/widgets.dart';
import '../infrastructure/assets/process_eud_dat_gateway.dart';
import '../application/eud/eud_build_preparation_controller.dart';
import '../application/settings/eud_tool_settings_controller.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/editing/object_editing_controller.dart';
import '../application/editing/object_palette_controller.dart';
import '../application/placement/placement_catalog_controller.dart';
import '../infrastructure/placement/preplaced_unit_power_state_gateway.dart';
import '../application/eud/eud_build_controller.dart';
import '../application/eud/safe_eud_build_pipeline.dart';
import '../application/eud/eud_source_controller.dart';
import '../application/eud/eud_project_controller.dart';
import '../application/eud/eud_project_workspace.dart';
import '../infrastructure/filesystem/local_eud_project_store.dart';
import '../infrastructure/filesystem/method_channel_eud_project_picker.dart';
import '../application/layers/map_layer_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/objects/object_sprite_atlas_loader.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../application/settings/app_language_controller.dart';
import '../application/settings/starcraft_data_asset_settings_controller.dart';
import '../application/terrain/terrain_editing_controller.dart';
import '../application/terrain/terrain_tile_atlas_loader.dart';
import '../infrastructure/archive/process_map_archive_gateway.dart';
import '../infrastructure/assets/process_starcraft_data_asset_inspector.dart';
import '../infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import '../infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import '../infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import '../infrastructure/compiler/euddraft_diagnostic_parser.dart';
import '../infrastructure/compiler/bundled_eud_tool.dart';
import '../infrastructure/compiler/process_eud_compiler_gateway.dart';
import '../infrastructure/filesystem/local_eud_build_file_gateway.dart';
import '../infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import '../infrastructure/filesystem/local_map_save_file_gateway.dart';
import '../infrastructure/filesystem/method_channel_directory_picker.dart';
import '../infrastructure/filesystem/method_channel_map_file_picker.dart';
import '../infrastructure/settings/json_file_settings_store.dart';
import '../application/terrain/terrain_brush_library.dart';
import '../infrastructure/filesystem/local_terrain_brush_store.dart';
import '../presentation/map_canvas/terrain_tile_texture_controller.dart';
import '../presentation/map_canvas/object_sprite_texture_controller.dart';
import 'app.dart';
import '../application/documents/document_workspace_controller.dart';
import '../application/eud/reserved_eud_build_gateway.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = JsonFileSettingsStore.forCurrentUser();
  final brushLibrary = TerrainBrushLibrary(
    LocalTerrainBrushStore.forCurrentUser(),
  );
  final languageController = AppLanguageController(store: settingsStore);
  final eudToolInspector = BundledEudTool.inspector();
  final eudToolSettingsController = EudToolSettingsController(
    store: settingsStore,
    inspector: eudToolInspector,
    bundledPath: BundledEudTool.installationPath,
    directoryPicker: const MethodChannelDirectoryPicker(),
  );
  final recentProjectsService = RecentProjectsService(settingsStore);
  final starCraftDataAssetSettingsController =
      StarCraftDataAssetSettingsController(
        settingsStore: settingsStore,
        directoryPicker: const MethodChannelDirectoryPicker(),
        inspector: ProcessStarCraftDataAssetInspector.bundled(),
      );
  const filePicker = MethodChannelMapFilePicker();
  final saveFiles = LocalMapSaveFileGateway();
  final recoveryStore = LocalRecoveryStore.forCurrentUser();
  late final DocumentWorkspaceController<EditorAppDependencies> workspace;

  WorkspaceDocument<EditorAppDependencies> createDocument(String id) {
    final commandDispatcher = EditorCommandDispatcher();
    final operationProgressController = OperationProgressController();
    final archiveGateway = ProcessMapArchiveGateway.bundled();
    final fingerprintGateway = LocalMapFileFingerprintGateway();
    final eudBuildController = EudBuildController(
      buildGateway: ReservedEudBuildGateway(
        reserve: (path) => workspace.reserve(
          id,
          path,
          purpose: WorkspacePathPurpose.buildOutput,
        ),
        delegate: SafeEudBuildPipeline(
          validateOutput: (path) => workspace.validatePath(
            id,
            path,
            purpose: WorkspacePathPurpose.buildOutput,
          ),
          toolInspector: eudToolInspector,
          compilerGateway: ProcessEudCompilerGateway(),
          archiveGateway: archiveGateway,
          fingerprintGateway: fingerprintGateway,
          buildFileGateway: LocalEudBuildFileGateway(),
        ),
      ),
      diagnosticParser: const EuddraftDiagnosticParser(),
      operationProgressController: operationProgressController,
    );
    final eudSourceController = EudSourceController();
    final openMapController = OpenMapController(
      archiveGateway: archiveGateway,
      filePicker: filePicker,
      fingerprintGateway: fingerprintGateway,
      recentProjectsService: recentProjectsService,
      operationProgressController: operationProgressController,
    );
    final terrainEditingController = TerrainEditingController(
      openMapController: openMapController,
    );
    final eudProjectWorkspace = EudProjectWorkspace(
      projects: EudProjectController(
        LocalEudProjectStore(),
        reserveDestination: (path) => workspace.reserve(
          id,
          path,
          purpose: WorkspacePathPurpose.projectOutput,
        ),
      ),
      maps: openMapController,
      picker: const MethodChannelEudProjectPicker(),
    );
    final mapLayerController = MapLayerController();
    String? buildBlockReason() {
      if (openMapController.state.session?.isDirty ?? false) {
        return 'Save the edited map before building.';
      }
      if (eudSourceController.state.document?.isDirty ?? false) {
        return 'Save or discard source edits before building.';
      }
      if (eudSourceController.state.document?.isUntitled ?? false) {
        return 'Use a saved epScript file before building.';
      }
      return null;
    }

    final eudBuildPreparationController = EudBuildPreparationController(
      tools: eudToolSettingsController,
      builds: eudBuildController,
      files: LocalEudBuildFileGateway(),
      blockReason: buildBlockReason,
      projects: eudProjectWorkspace,
    );
    final objectEditingController = ObjectEditingController(
      resourceGateway: LocalMapResourceGateway(archiveGateway),
      openMapController: openMapController,
      mapLayerController: mapLayerController,
    );
    final objectPaletteController = ObjectPaletteController(
      objectEditingController: objectEditingController,
      mapLayerController: mapLayerController,
    );
    final tileAtlasGateway = ProcessStarCraftTileAtlasGateway.bundled();
    final objectAtlasGateway = ProcessStarCraftObjectAtlasGateway.bundled();
    final placementCatalogController = PlacementCatalogController(
      unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
      terrainPlacementGateway:
          ProcessTerrainConnectionSnapshotGateway.bundled(),
      openMapController: openMapController,
      objectEditingController: objectEditingController,
      terrainEditingController: terrainEditingController,
      catalogGateway: ProcessStarCraftPlacementCatalogGateway.bundled(),
      eudDatGateway: ProcessEudDatGateway.bundled(),
      tileAtlasGateway: tileAtlasGateway,
      objectAtlasGateway: objectAtlasGateway,
    );
    placementCatalogController.setInstallationPath(
      starCraftDataAssetSettingsController.state.configuredPath,
    );
    final assetSubscription = starCraftDataAssetSettingsController.changes
        .listen((state) {
          placementCatalogController.setInstallationPath(state.configuredPath);
        });
    final terrainTileTextureController = TerrainTileTextureController(
      loader: TerrainTileAtlasLoader(gateway: tileAtlasGateway),
    );
    final objectSpriteTextureController = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: objectAtlasGateway),
    );
    final saveMapController = SaveMapController(
      archiveGateway: archiveGateway,
      filePicker: filePicker,
      fingerprintGateway: fingerprintGateway,
      saveFileGateway: saveFiles,
      reserveDestination: (path) =>
          workspace.reserve(id, path, purpose: WorkspacePathPurpose.mapOutput),
      openMapController: openMapController,
      operationProgressController: operationProgressController,
    );
    commandDispatcher.register(EditorCommandId.openMap, (argument) async {
      await workspace.open(path: argument is String ? argument : null);
    });
    commandDispatcher.register(EditorCommandId.saveAs, (_) async {
      await saveMapController.saveAs();
    });
    commandDispatcher.register(EditorCommandId.newEudSource, (_) {
      eudSourceController.createUntitled();
    });
    commandDispatcher.register(EditorCommandId.buildEud, (_) async {
      if (eudBuildPreparationController.busy || buildBlockReason() != null) {
        return;
      }
      await eudBuildController.start();
    });
    commandDispatcher.register(EditorCommandId.cancelEudBuild, (_) async {
      await eudBuildController.cancel();
    });

    final dependencies = EditorAppDependencies(
      autosaveController: AutosaveController(
        maps: openMapController,
        sources: eudSourceController,
        projects: eudProjectWorkspace.projects,
        store: recoveryStore,
        settings: settingsStore,
        reserveRestoreInput: (path) => workspace.reserve(
          id,
          path,
          purpose: WorkspacePathPurpose.restoreInput,
        ),
        canAccessCheckpoint: (checkpoint) =>
            workspace.canAccessCheckpoint(id, checkpoint),
      ),
      eudBuildPreparationController: eudBuildPreparationController,
      eudToolSettingsController: eudToolSettingsController,
      commandDispatcher: commandDispatcher,
      openMapController: openMapController,
      saveMapController: saveMapController,
      eudBuildController: eudBuildController,
      eudSourceController: eudSourceController,
      eudProjectWorkspace: eudProjectWorkspace,
      operationProgressController: operationProgressController,
      recentProjectsService: recentProjectsService,
      settingsStore: settingsStore,
      brushLibrary: brushLibrary,
      starCraftDataAssetSettingsController:
          starCraftDataAssetSettingsController,
      isomFillController: IsomFillController(
        maps: openMapController,
        assets: () => starCraftDataAssetSettingsController.state,
        gateway: ProcessTerrainConnectionSnapshotGateway.bundled(),
        placementGateway: ProcessStarCraftPlacementCatalogGateway.bundled(),
        atlasLoader: TerrainTileAtlasLoader(gateway: tileAtlasGateway),
      ),
      terrainEditingController: terrainEditingController,
      mapLayerController: mapLayerController,
      objectEditingController: objectEditingController,
      objectPaletteController: objectPaletteController,
      placementCatalogController: placementCatalogController,
      terrainTileTextureController: terrainTileTextureController,
      objectSpriteTextureController: objectSpriteTextureController,
      languageController: languageController,
    );

    return WorkspaceDocument(
      id: id,
      value: dependencies,
      maps: openMapController,
      saves: saveMapController,
      sources: eudSourceController,
      builds: eudBuildController,
      projects: eudProjectWorkspace,
      autosave: dependencies.autosaveController,
      additionalBusy: () =>
          eudBuildPreparationController.busy || objectEditingController.isBusy,
      additionalChanges: objectEditingController.changes,
      disposeOwned: () async {
        // The keyed editor must unmount before its texture controllers are freed.
        final detached = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => detached.complete(),
        );
        WidgetsBinding.instance.scheduleFrame();
        await detached.future;
        await assetSubscription.cancel();
        await dependencies.autosaveController?.dispose();
        eudBuildPreparationController.cancel();
        dependencies.isomFillController?.invalidate();
        await placementCatalogController.dispose();
        await objectPaletteController.dispose();
        await objectEditingController.dispose();
        await terrainEditingController.dispose();
        terrainTileTextureController.dispose();
        objectSpriteTextureController.dispose();
        eudProjectWorkspace.dispose();
        eudProjectWorkspace.projects.dispose();
        eudSourceController.dispose();
        await eudBuildController.dispose();
        await saveMapController.dispose();
        await mapLayerController.dispose();
        await openMapController.dispose();
        await operationProgressController.dispose();
      },
    );
  }

  workspace = DocumentWorkspaceController(
    createDocument: createDocument,
    filePicker: filePicker,
    paths: saveFiles,
  );
  final dependencies = workspace.addEmpty().value;

  // Read the saved display language first so the first frame is already in
  // the chosen language. Load never throws; unreadable settings mean
  // "follow the system language".
  unawaited(
    languageController.load().then(
      (_) => runApp(
        StarCraftMapEditorApp(dependencies: dependencies, workspace: workspace),
      ),
    ),
  );
}
