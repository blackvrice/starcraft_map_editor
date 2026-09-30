import '../application/documents/isom_fill_controller.dart';
import '../application/eud/eud_build_preparation_controller.dart';
import '../application/settings/eud_tool_settings_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/editing/object_editing_controller.dart';
import '../application/editing/object_palette_controller.dart';
import '../application/placement/placement_catalog_controller.dart';
import '../application/eud/eud_build_controller.dart';
import '../application/eud/eud_source_controller.dart';
import '../application/eud/eud_project_workspace.dart';
import '../application/layers/map_layer_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/ports/settings_store.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../application/settings/app_language_controller.dart';
import '../application/settings/starcraft_data_asset_settings_controller.dart';
import '../application/terrain/terrain_editing_controller.dart';
import '../presentation/map_canvas/terrain_tile_texture_controller.dart';
import '../presentation/map_canvas/object_sprite_texture_controller.dart';
import '../presentation/localization/l10n.dart';
import '../presentation/shell/editor_shell.dart';

class EditorAppDependencies {
  const EditorAppDependencies({
    required this.commandDispatcher,
    required this.openMapController,
    required this.saveMapController,
    required this.eudBuildController,
    required this.eudSourceController,
    this.eudProjectWorkspace,
    this.eudToolSettingsController,
    this.eudBuildPreparationController,
    required this.operationProgressController,
    required this.recentProjectsService,
    required this.settingsStore,
    required this.starCraftDataAssetSettingsController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.placementCatalogController,
    required this.terrainTileTextureController,
    required this.objectSpriteTextureController,
    this.languageController,
    this.isomFillController,
  });

  final IsomFillController? isomFillController;
  final EditorCommandDispatcher commandDispatcher;
  final OpenMapController openMapController;
  final SaveMapController saveMapController;
  final EudBuildController eudBuildController;
  final EudSourceController eudSourceController;
  final EudProjectWorkspace? eudProjectWorkspace;
  final EudToolSettingsController? eudToolSettingsController;
  final EudBuildPreparationController? eudBuildPreparationController;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;
  final SettingsStore settingsStore;
  final StarCraftDataAssetSettingsController
  starCraftDataAssetSettingsController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final PlacementCatalogController placementCatalogController;
  final TerrainTileTextureController terrainTileTextureController;
  final ObjectSpriteTextureController objectSpriteTextureController;

  /// Display language preference. When omitted the app creates one backed by
  /// [settingsStore].
  final AppLanguageController? languageController;
}

class StarCraftMapEditorApp extends StatefulWidget {
  const StarCraftMapEditorApp({required this.dependencies, super.key});

  final EditorAppDependencies dependencies;

  @override
  State<StarCraftMapEditorApp> createState() => _StarCraftMapEditorAppState();
}

class _StarCraftMapEditorAppState extends State<StarCraftMapEditorApp> {
  late AppLanguageController _languageController;
  late bool _ownsLanguageController;
  StreamSubscription<AppLanguagePreference>? _languageSubscription;

  @override
  void initState() {
    super.initState();
    _attachLanguageController();
  }

  @override
  void didUpdateWidget(StarCraftMapEditorApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependencies.languageController !=
            widget.dependencies.languageController ||
        oldWidget.dependencies.settingsStore !=
            widget.dependencies.settingsStore) {
      _detachLanguageController();
      _attachLanguageController();
    }
  }

  @override
  void dispose() {
    _detachLanguageController();
    super.dispose();
  }

  void _attachLanguageController() {
    final provided = widget.dependencies.languageController;
    _ownsLanguageController = provided == null;
    _languageController =
        provided ??
        AppLanguageController(store: widget.dependencies.settingsStore);
    _languageSubscription = _languageController.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (_ownsLanguageController) {
      unawaited(_languageController.load());
    }
  }

  void _detachLanguageController() {
    unawaited(_languageSubscription?.cancel());
    _languageSubscription = null;
    if (_ownsLanguageController) {
      _languageController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D7EFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: localeForLanguagePreference(_languageController.preference),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11141A),
        useMaterial3: true,
      ),
      home: EditorShell(
        isomFillController: dependencies.isomFillController,
        commandDispatcher: dependencies.commandDispatcher,
        openMapController: dependencies.openMapController,
        saveMapController: dependencies.saveMapController,
        eudBuildController: dependencies.eudBuildController,
        eudSourceController: dependencies.eudSourceController,
        eudProjectWorkspace: dependencies.eudProjectWorkspace,
        eudToolSettingsController: dependencies.eudToolSettingsController,
        eudBuildPreparationController:
            dependencies.eudBuildPreparationController,
        operationProgressController: dependencies.operationProgressController,
        recentProjectsService: dependencies.recentProjectsService,
        starCraftDataAssetSettingsController:
            dependencies.starCraftDataAssetSettingsController,
        terrainEditingController: dependencies.terrainEditingController,
        mapLayerController: dependencies.mapLayerController,
        objectEditingController: dependencies.objectEditingController,
        objectPaletteController: dependencies.objectPaletteController,
        placementCatalogController: dependencies.placementCatalogController,
        terrainTileTextureController: dependencies.terrainTileTextureController,
        objectSpriteTextureController:
            dependencies.objectSpriteTextureController,
        languageController: _languageController,
      ),
    );
  }
}
