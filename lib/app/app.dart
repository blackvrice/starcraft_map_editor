import 'package:flutter/material.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/eud/eud_build_controller.dart';
import '../application/eud/eud_source_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/ports/settings_store.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../application/settings/starcraft_data_asset_settings_controller.dart';
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
      ),
    );
  }
}
