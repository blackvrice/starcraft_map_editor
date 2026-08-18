import 'package:flutter/material.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/editing/object_editing_controller.dart';
import '../application/editing/object_palette_controller.dart';
import '../application/eud/eud_build_controller.dart';
import '../application/eud/eud_source_controller.dart';
import '../application/layers/map_layer_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/ports/settings_store.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../application/settings/starcraft_data_asset_settings_controller.dart';
import '../application/terrain/terrain_editing_controller.dart';
import '../presentation/map_canvas/terrain_tile_texture_controller.dart';
import '../presentation/map_canvas/object_sprite_texture_controller.dart';
import '../presentation/shell/editor_shell.dart';

class EditorAppDependencies {
  const EditorAppDependencies({
    required this.commandDispatcher,
    required this.openMapController,
    required this.saveMapController,
    required this.eudBuildController,
    required this.eudSourceController,
    required this.operationProgressController,
    required this.recentProjectsService,
    required this.settingsStore,
    required this.starCraftDataAssetSettingsController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.terrainTileTextureController,
    required this.objectSpriteTextureController,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OpenMapController openMapController;
  final SaveMapController saveMapController;
  final EudBuildController eudBuildController;
  final EudSourceController eudSourceController;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;
  final SettingsStore settingsStore;
  final StarCraftDataAssetSettingsController
  starCraftDataAssetSettingsController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final TerrainTileTextureController terrainTileTextureController;
  final ObjectSpriteTextureController objectSpriteTextureController;
}

class StarCraftMapEditorApp extends StatelessWidget {
  const StarCraftMapEditorApp({required this.dependencies, super.key});

  final EditorAppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D7EFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'StarCraft Map Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11141A),
        useMaterial3: true,
      ),
      home: EditorShell(
        commandDispatcher: dependencies.commandDispatcher,
        openMapController: dependencies.openMapController,
        saveMapController: dependencies.saveMapController,
        eudBuildController: dependencies.eudBuildController,
        eudSourceController: dependencies.eudSourceController,
        operationProgressController: dependencies.operationProgressController,
        recentProjectsService: dependencies.recentProjectsService,
        starCraftDataAssetSettingsController:
            dependencies.starCraftDataAssetSettingsController,
        terrainEditingController: dependencies.terrainEditingController,
        mapLayerController: dependencies.mapLayerController,
        objectEditingController: dependencies.objectEditingController,
        objectPaletteController: dependencies.objectPaletteController,
        terrainTileTextureController: dependencies.terrainTileTextureController,
        objectSpriteTextureController:
            dependencies.objectSpriteTextureController,
      ),
    );
  }
}
