import '../documents/selection_navigation_dialog.dart';
import '../../application/documents/autosave_controller.dart';
import '../documents/recovery_dialog.dart';
import '../../application/layers/selection_navigation_controller.dart';
import '../documents/isom_fill_dialog.dart';
import '../documents/basic_editing_tools_dialog.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../documents/terrain_data_panel.dart';
import '../../application/documents/map_resize_controller.dart';
import '../documents/map_resize_dialog.dart';
import '../../application/documents/new_map_controller.dart';
import '../../application/terrain/tile_placement_catalog_loader.dart';
import '../documents/new_map_dialog.dart';
import '../resources/resources_pane.dart';
import '../../application/eud/eud_build_preparation_controller.dart';
import '../../application/settings/eud_tool_settings_controller.dart';
import '../settings/map_settings_dialog.dart';
import '../triggers/trigger_pane.dart';
import '../settings/eud_tool_settings_dialog.dart';
import '../settings/eud_build_preparation_dialog.dart';
import 'dart:async';
import '../placement/doodad_delete_dialog.dart';
import '../../application/ports/starcraft_placement_catalog_gateway.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/commands/editor_command_dispatcher.dart';
import '../../application/documents/open_map_controller.dart';
import '../../application/documents/opened_map_session.dart';
import '../../application/documents/save_map_controller.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../application/editing/object_palette_controller.dart';
import '../../application/editing/object_properties.dart';
import '../../application/eud/eud_build_controller.dart';
import '../../application/eud/eud_build_record.dart';
import '../../application/eud/eud_source_controller.dart';
import '../../application/eud/eud_project_workspace.dart';
import '../eud_editor/eud_project_pane.dart';
import '../eud_editor/eud_rules_editor.dart';
import '../../application/eud/eud_source_document.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/operations/operation_progress.dart';
import '../../application/operations/operation_progress_controller.dart';
import '../../application/recent_projects/recent_project.dart';
import '../../application/recent_projects/recent_projects_service.dart';
import '../../application/settings/app_language_controller.dart';
import '../../application/settings/starcraft_data_asset_settings_controller.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../../domain/terrain/terrain_tile_display_value.dart';
import '../eud_editor/eud_build_steps.dart';
import '../eud_editor/eud_source_editor.dart';
import '../localization/l10n.dart';
import '../localization/editor_message_localization.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/object_sprite_texture_controller.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';
import '../placement/placement_catalog_pane.dart';
import '../settings/map_information_dialog.dart';
import '../settings/player_settings_dialog.dart';
import '../settings/force_settings_dialog.dart';
import '../settings/unit_settings_dialog.dart';
import '../settings/unit_availability_dialog.dart';
import '../settings/upgrade_settings_dialog.dart';
import '../settings/tech_settings_dialog.dart';
import '../settings/starcraft_asset_settings_dialog.dart';

enum _WorkspaceView {
  map,
  eud,
  catalog,
  settings,
  project,
  triggers,
  resources,
  briefing,
}

class EditorShell extends StatefulWidget {
  const EditorShell({
    this.autosaveController,
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
    required this.starCraftDataAssetSettingsController,
    this.isomFillController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.placementCatalogController,
    required this.terrainTileTextureController,
    required this.objectSpriteTextureController,
    this.languageController,
    super.key,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OpenMapController openMapController;
  final AutosaveController? autosaveController;
  final SaveMapController saveMapController;
  final EudBuildController eudBuildController;
  final EudSourceController eudSourceController;
  final EudProjectWorkspace? eudProjectWorkspace;
  final EudToolSettingsController? eudToolSettingsController;
  final EudBuildPreparationController? eudBuildPreparationController;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;
  final StarCraftDataAssetSettingsController
  starCraftDataAssetSettingsController;
  final IsomFillController? isomFillController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final PlacementCatalogController placementCatalogController;
  final TerrainTileTextureController terrainTileTextureController;
  final ObjectSpriteTextureController objectSpriteTextureController;

  /// Display language control. The language menu is hidden without it.
  final AppLanguageController? languageController;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> with WidgetsBindingObserver {
  late Future<List<RecentProject>> _recentProjects;
  late StreamSubscription<OpenMapState> _openMapSubscription;
  late StreamSubscription<SaveMapState> _saveMapSubscription;
  late StreamSubscription<EudBuildState> _eudBuildSubscription;
  late StreamSubscription<EudSourceState> _eudSourceSubscription;
  StreamSubscription<void>? _projectSubscription;
  StreamSubscription<AppLanguagePreference>? _languageSubscription;
  late StreamSubscription<StarCraftDataAssetSettingsState>
  _starCraftDataAssetSettingsSubscription;
  late StreamSubscription<TerrainEditingState> _terrainEditingSubscription;
  late StreamSubscription<MapLayerState> _mapLayerSubscription;
  late StreamSubscription<ObjectEditingState> _objectEditingSubscription;
  late StreamSubscription<ObjectPaletteState> _objectPaletteSubscription;
  late StreamSubscription<PlacementCatalogState> _placementCatalogSubscription;
  late StreamSubscription<TerrainTileTextureState>
  _terrainTileTextureSubscription;
  late StreamSubscription<ObjectSpriteTextureState>
  _objectSpriteTextureSubscription;
  late List<EditorDiagnostic> _documentDiagnostics;
  late _WorkspaceView _workspaceView;
  bool _settingsVisited = false;
  late BasicEditingController _basicEditing;
  late SelectionNavigationController _selectionNavigation;
  MapNavigationTarget? _navigationTarget;
  int _selectionInteractionRevision = 0;
  void _prepareSelection() {
    setState(() => _selectionInteractionRevision++);
    widget.terrainEditingController.cancelBrushStroke();
    widget.terrainEditingController.setTool(TerrainEditingTool.select);
    widget.objectPaletteController.cancelPlacement();
    if (widget.placementCatalogController.state.isPlacementActive) {
      widget.placementCatalogController.cancelSelection();
    }
    widget.objectEditingController.cancelLocationCreation();
  }

  void _navigateTo(MapNavigationTarget? target) {
    if (target == null ||
        !identical(
          target.document,
          widget.openMapController.state.session?.rawDocument,
        )) {
      return;
    }
    _prepareSelection();
    setState(() {
      _navigationTarget = target;
      _workspaceView = _WorkspaceView.map;
    });
  }

  void _selectionAction(bool Function() action) {
    _prepareSelection();
    action();
  }

  Future<void> _openSelectionNavigation({bool coordinates = false}) async {
    _prepareSelection();
    await showDialog<void>(
      context: context,
      builder: (_) => SelectionNavigationDialog(
        controller: _selectionNavigation,
        coordinateFocus: coordinates,
        onNavigate: _navigateTo,
      ),
    );
  }

  Future<void> _openBasicTools({int initialTab = 0}) async {
    if (widget.openMapController.state.session == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => BasicEditingToolsDialog(
        controller: _basicEditing,
        initialTab: initialTab,
        catalog: widget.placementCatalogController,
        textures: widget.terrainTileTextureController.state,
      ),
    );
  }

  void _copyObjectsShortcut({bool cut = false}) {
    try {
      _basicEditing.copyObjects(cut: cut);
    } on Object catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _fillIsom({int initialMode = 0}) async {
    final controller = widget.isomFillController;
    if (controller == null) return;
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          IsomFillDialog(controller: controller, initialMode: initialMode),
    );
  }

  Future<void> _resizeMap() async {
    if (widget.openMapController.state.session == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => MapResizeDialog(
        controller: MapResizeController(
          widget.openMapController,
          terrainLoader: widget.isomFillController,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(() => _workspaceView = _WorkspaceView.map);
    }
  }

  Future<void> _newMap() async {
    final catalog = widget.placementCatalogController;
    final controller = NewMapController(
      maps: widget.openMapController,
      terrainGateway: widget.isomFillController?.gateway,
      assets: () => widget.starCraftDataAssetSettingsController.state,
      loader: catalog.catalogGateway == null || catalog.tileAtlasGateway == null
          ? null
          : TilePlacementCatalogLoader(
              catalogGateway: catalog.catalogGateway!,
              tileAtlasGateway: catalog.tileAtlasGateway!,
            ),
    );
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => NewMapDialog(controller: controller),
      );
      if (mounted && created == true) {
        setState(() => _workspaceView = _WorkspaceView.map);
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _basicEditing = BasicEditingController(
      maps: widget.openMapController,
      layers: widget.mapLayerController,
    );
    _selectionNavigation = SelectionNavigationController(
      maps: widget.openMapController,
      layers: widget.mapLayerController,
    );
    _recentProjects = widget.recentProjectsService.load();
    _documentDiagnostics = widget.openMapController.state.diagnostics;
    _workspaceView = widget.eudSourceController.state.hasDocument
        ? _WorkspaceView.eud
        : _WorkspaceView.map;
    widget.terrainEditingController.synchronizeSession(
      widget.openMapController.state.session,
    );
    widget.mapLayerController.synchronizeSession(
      widget.openMapController.state.session,
    );
    widget.objectEditingController.synchronizeSession(
      widget.openMapController.state.session,
    );
    widget.objectPaletteController.synchronizeSession(
      widget.openMapController.state.session,
    );
    widget.placementCatalogController.synchronizeSession(
      widget.openMapController.state.session,
    );
    _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
    _saveMapSubscription = _listenForSavedMaps(widget.saveMapController);
    _eudBuildSubscription = _listenForEudBuild(widget.eudBuildController);
    _eudSourceSubscription = _listenForEudSources(widget.eudSourceController);
    _projectSubscription = widget.eudProjectWorkspace?.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _starCraftDataAssetSettingsSubscription = _listenForStarCraftDataAssets(
      widget.starCraftDataAssetSettingsController,
    );
    _terrainEditingSubscription = _listenForTerrainEditing(
      widget.terrainEditingController,
    );
    _mapLayerSubscription = _listenForMapLayers(widget.mapLayerController);
    _objectEditingSubscription = _listenForObjectEditing(
      widget.objectEditingController,
    );
    _objectPaletteSubscription = _listenForObjectPalette(
      widget.objectPaletteController,
    );
    _placementCatalogSubscription = widget.placementCatalogController.changes
        .listen((state) {
          if (state.selection != null) {
            widget.objectPaletteController.cancelPlacement();
            widget.objectEditingController.cancelLocationCreation();
            widget.mapLayerController.setActiveLayer(
              switch (state.selection!.kind) {
                StarCraftPlacementKind.tile => MapLayerType.terrain,
                StarCraftPlacementKind.doodad => MapLayerType.doodads,
                StarCraftPlacementKind.unit => MapLayerType.units,
                StarCraftPlacementKind.pureSprite ||
                StarCraftPlacementKind.spriteUnit => MapLayerType.sprites,
              },
            );
          }
          if (mounted) {
            setState(() {});
          }
        });
    _terrainTileTextureSubscription = _listenForTerrainTileTextures(
      widget.terrainTileTextureController,
    );
    _objectSpriteTextureSubscription = _listenForObjectSpriteTextures(
      widget.objectSpriteTextureController,
    );
    _synchronizeTerrainTextures();
    _synchronizeObjectTextures();
    _languageSubscription = _listenForLanguage(widget.languageController);
    unawaited(widget.starCraftDataAssetSettingsController.load());
    final autosave = widget.autosaveController;
    if (autosave != null) {
      _autosaveSubscription = autosave.changes.listen((_) {
        if (mounted) setState(() {});
      });
      unawaited(
        autosave.initialize().then((_) {
          if (mounted && autosave.candidates.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_showRecovery());
            });
          }
        }),
      );
    }
  }

  StreamSubscription<void>? _autosaveSubscription;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.autosaveController?.checkpoint());
    }
  }

  Future<void> _showRecovery() async {
    final controller = widget.autosaveController;
    if (controller == null) return;
    await controller.refresh();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => RecoveryDialog(controller: controller),
    );
  }

  StreamSubscription<AppLanguagePreference>? _listenForLanguage(
    AppLanguageController? controller,
  ) {
    return controller?.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _setLanguage(AppLanguagePreference preference) {
    final controller = widget.languageController;
    if (controller == null) {
      return;
    }
    unawaited(
      controller.setPreference(preference).then((_) {
        if (mounted && controller.lastSaveFailed) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(context.l10n.languageSaveFailed)),
          );
        }
      }),
    );
  }

  @override
  void didUpdateWidget(EditorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openMapController != widget.openMapController ||
        oldWidget.mapLayerController != widget.mapLayerController) {
      unawaited(_basicEditing.dispose());
      _basicEditing = BasicEditingController(
        maps: widget.openMapController,
        layers: widget.mapLayerController,
      );
      _selectionNavigation = SelectionNavigationController(
        maps: widget.openMapController,
        layers: widget.mapLayerController,
      );
      _navigationTarget = null;
    }
    if (oldWidget.eudProjectWorkspace != widget.eudProjectWorkspace) {
      _projectSubscription?.cancel();
      _projectSubscription = widget.eudProjectWorkspace?.changes.listen((_) {
        if (mounted) setState(() {});
      });
    }
    if (oldWidget.languageController != widget.languageController) {
      unawaited(_languageSubscription?.cancel());
      _languageSubscription = _listenForLanguage(widget.languageController);
    }
    var synchronizeTerrainTextures = false;
    var synchronizeObjectTextures = false;
    if (oldWidget.recentProjectsService != widget.recentProjectsService) {
      _recentProjects = widget.recentProjectsService.load();
    }
    if (oldWidget.openMapController != widget.openMapController) {
      unawaited(_openMapSubscription.cancel());
      _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
      synchronizeTerrainTextures = true;
      synchronizeObjectTextures = true;
    }
    if (oldWidget.saveMapController != widget.saveMapController) {
      unawaited(_saveMapSubscription.cancel());
      _saveMapSubscription = _listenForSavedMaps(widget.saveMapController);
    }
    if (oldWidget.eudBuildController != widget.eudBuildController) {
      unawaited(_eudBuildSubscription.cancel());
      _eudBuildSubscription = _listenForEudBuild(widget.eudBuildController);
    }
    if (oldWidget.eudSourceController != widget.eudSourceController) {
      unawaited(_eudSourceSubscription.cancel());
      _eudSourceSubscription = _listenForEudSources(widget.eudSourceController);
      _workspaceView = widget.eudSourceController.state.hasDocument
          ? _WorkspaceView.eud
          : _WorkspaceView.map;
    }
    if (oldWidget.starCraftDataAssetSettingsController !=
        widget.starCraftDataAssetSettingsController) {
      unawaited(_starCraftDataAssetSettingsSubscription.cancel());
      _starCraftDataAssetSettingsSubscription = _listenForStarCraftDataAssets(
        widget.starCraftDataAssetSettingsController,
      );
      unawaited(widget.starCraftDataAssetSettingsController.load());
      synchronizeTerrainTextures = true;
      synchronizeObjectTextures = true;
    }
    if (oldWidget.terrainEditingController != widget.terrainEditingController) {
      unawaited(_terrainEditingSubscription.cancel());
      widget.terrainEditingController.synchronizeSession(
        widget.openMapController.state.session,
      );
      _terrainEditingSubscription = _listenForTerrainEditing(
        widget.terrainEditingController,
      );
    }
    if (oldWidget.mapLayerController != widget.mapLayerController) {
      unawaited(_mapLayerSubscription.cancel());
      widget.mapLayerController.synchronizeSession(
        widget.openMapController.state.session,
      );
      _mapLayerSubscription = _listenForMapLayers(widget.mapLayerController);
    }
    if (oldWidget.objectEditingController != widget.objectEditingController) {
      unawaited(_objectEditingSubscription.cancel());
      widget.objectEditingController.synchronizeSession(
        widget.openMapController.state.session,
      );
      _objectEditingSubscription = _listenForObjectEditing(
        widget.objectEditingController,
      );
    }
    if (oldWidget.objectPaletteController != widget.objectPaletteController) {
      unawaited(_objectPaletteSubscription.cancel());
      widget.objectPaletteController.synchronizeSession(
        widget.openMapController.state.session,
      );
      _objectPaletteSubscription = _listenForObjectPalette(
        widget.objectPaletteController,
      );
    }
    if (oldWidget.terrainTileTextureController !=
        widget.terrainTileTextureController) {
      unawaited(_terrainTileTextureSubscription.cancel());
      _terrainTileTextureSubscription = _listenForTerrainTileTextures(
        widget.terrainTileTextureController,
      );
      synchronizeTerrainTextures = true;
    }
    if (oldWidget.objectSpriteTextureController !=
        widget.objectSpriteTextureController) {
      unawaited(_objectSpriteTextureSubscription.cancel());
      _objectSpriteTextureSubscription = _listenForObjectSpriteTextures(
        widget.objectSpriteTextureController,
      );
      synchronizeObjectTextures = true;
    }
    if (synchronizeTerrainTextures) {
      _synchronizeTerrainTextures();
    }
    if (synchronizeObjectTextures) {
      _synchronizeObjectTextures();
    }
  }

  StreamSubscription<OpenMapState> _listenForOpenedMaps(
    OpenMapController controller,
  ) {
    var previousStatus = controller.state.status;
    return controller.changes.listen((state) {
      if (mounted) {
        setState(() {
          _documentDiagnostics = state.diagnostics;
          if (state.status == OpenMapStatus.opened) {
            if (previousStatus != OpenMapStatus.opened) {
              _workspaceView = _WorkspaceView.map;
            }
            _recentProjects = widget.recentProjectsService.load();
          }
          previousStatus = state.status;
          widget.terrainEditingController.synchronizeSession(state.session);
          widget.mapLayerController.synchronizeSession(state.session);
          widget.objectEditingController.synchronizeSession(state.session);
          widget.objectPaletteController.synchronizeSession(state.session);
          widget.placementCatalogController.synchronizeSession(state.session);
        });
        _synchronizeTerrainTextures();
        _synchronizeObjectTextures();
      }
    });
  }

  StreamSubscription<SaveMapState> _listenForSavedMaps(
    SaveMapController controller,
  ) {
    return controller.changes.listen((state) {
      if (mounted) {
        setState(() {
          _documentDiagnostics = state.diagnostics;
          if (state.status == SaveMapStatus.saved) {
            _recentProjects = widget.recentProjectsService.load();
          }
        });
      }
    });
  }

  StreamSubscription<EudSourceState> _listenForEudSources(
    EudSourceController controller,
  ) {
    return controller.changes.listen((state) {
      if (mounted) {
        setState(() {
          if (state.hasDocument) {
            _workspaceView = _WorkspaceView.eud;
          } else {
            _workspaceView = _WorkspaceView.map;
          }
        });
      }
    });
  }

  StreamSubscription<EudBuildState> _listenForEudBuild(
    EudBuildController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<StarCraftDataAssetSettingsState>
  _listenForStarCraftDataAssets(
    StarCraftDataAssetSettingsController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
        _synchronizeTerrainTextures();
        _synchronizeObjectTextures();
      }
    });
  }

  StreamSubscription<TerrainEditingState> _listenForTerrainEditing(
    TerrainEditingController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<MapLayerState> _listenForMapLayers(
    MapLayerController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<ObjectEditingState> _listenForObjectEditing(
    ObjectEditingController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<ObjectPaletteState> _listenForObjectPalette(
    ObjectPaletteController controller,
  ) {
    return controller.changes.listen((state) {
      if (state.isPlacementActive) {
        widget.placementCatalogController.cancelSelection();
        widget.objectEditingController.cancelLocationCreation();
        widget.terrainEditingController.cancelBrushStroke();
        widget.terrainEditingController.setTool(TerrainEditingTool.select);
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<TerrainTileTextureState> _listenForTerrainTileTextures(
    TerrainTileTextureController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  StreamSubscription<ObjectSpriteTextureState> _listenForObjectSpriteTextures(
    ObjectSpriteTextureController controller,
  ) {
    return controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _synchronizeTerrainTextures() {
    final session = widget.openMapController.state.session;
    if (session == null) {
      widget.terrainTileTextureController.clear();
      return;
    }
    unawaited(
      widget.terrainTileTextureController.synchronize(
        metadataViews: session.metadataViews,
        terrainViews: session.terrainViews,
        assetState: widget.starCraftDataAssetSettingsController.state,
      ),
    );
  }

  void _synchronizeObjectTextures() {
    final session = widget.openMapController.state.session;
    if (session == null) {
      widget.objectSpriteTextureController.clear();
      return;
    }
    unawaited(
      widget.objectSpriteTextureController.synchronize(
        metadataViews: session.metadataViews,
        objectViews: session.objectViews,
        assetState: widget.starCraftDataAssetSettingsController.state,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_autosaveSubscription?.cancel());
    unawaited(_basicEditing.dispose());
    unawaited(_openMapSubscription.cancel());
    unawaited(_saveMapSubscription.cancel());
    unawaited(_eudBuildSubscription.cancel());
    unawaited(_eudSourceSubscription.cancel());
    _projectSubscription?.cancel();
    unawaited(_languageSubscription?.cancel());
    unawaited(_starCraftDataAssetSettingsSubscription.cancel());
    unawaited(_terrainEditingSubscription.cancel());
    unawaited(_mapLayerSubscription.cancel());
    unawaited(_objectEditingSubscription.cancel());
    unawaited(_objectPaletteSubscription.cancel());
    unawaited(_placementCatalogSubscription.cancel());
    unawaited(_terrainTileTextureSubscription.cancel());
    unawaited(_objectSpriteTextureSubscription.cancel());
    widget.terrainTileTextureController.clear();
    widget.objectSpriteTextureController.clear();
    super.dispose();
  }

  VoidCallback? _callbackFor(EditorCommandId command) {
    if (!widget.commandDispatcher.canDispatch(command)) {
      return null;
    }

    return () => unawaited(widget.commandDispatcher.dispatch(command));
  }

  void _newEudSource() {
    setState(() {
      _workspaceView = _WorkspaceView.eud;
    });
    unawaited(widget.commandDispatcher.dispatch(EditorCommandId.newEudSource));
  }

  void _showMapWorkspace() {
    setState(() {
      _workspaceView = _WorkspaceView.map;
    });
  }

  void _showSettingsWorkspace() {
    setState(() {
      _settingsVisited = true;
      _workspaceView = _WorkspaceView.settings;
    });
  }

  void _showCatalogWorkspace() {
    setState(() {
      _workspaceView = _WorkspaceView.catalog;
    });
  }

  void _showEudWorkspace() {
    setState(() {
      _workspaceView = _WorkspaceView.eud;
    });
  }

  void _openRecentProject(RecentProject project) {
    unawaited(
      widget.commandDispatcher.dispatch(
        EditorCommandId.openMap,
        argument: project.path,
      ),
    );
  }

  void _removeRecentProject(RecentProject project) {
    setState(() {
      _recentProjects = widget.recentProjectsService.remove(project.path);
    });
  }

  String? _activeDocumentName() {
    final eudDocument = widget.eudSourceController.state.document;
    if (_workspaceView == _WorkspaceView.eud && eudDocument != null) {
      return eudDocument.fileName;
    }
    final session = widget.openMapController.state.session;
    return session == null ? null : _sessionName(context.l10n, session);
  }

  bool _activeDocumentDirty() {
    final eudDocument = widget.eudSourceController.state.document;
    if (_workspaceView == _WorkspaceView.eud && eudDocument != null) {
      return eudDocument.isDirty;
    }
    return widget.openMapController.state.session?.isDirty ?? false;
  }

  void _showStarCraftDataAssetSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => StarCraftAssetSettingsDialog(
        controller: widget.starCraftDataAssetSettingsController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openMap = _callbackFor(EditorCommandId.openMap);
    final saveAs = widget.openMapController.state.session == null
        ? null
        : _callbackFor(EditorCommandId.saveAs);
    final eudBuildState = widget.eudBuildController.state;
    final buildEud =
        widget.eudBuildController.canStart &&
            !(widget.eudBuildPreparationController?.busy ?? false) &&
            widget.eudBuildPreparationController?.blockReason() == null &&
            (eudBuildState.plan?.contextIsCurrent?.call() ?? true)
        ? _callbackFor(EditorCommandId.buildEud)
        : null;
    final cancelEudBuild = eudBuildState.canCancel
        ? _callbackFor(EditorCommandId.cancelEudBuild)
        : null;
    final newEudSource =
        widget.commandDispatcher.canDispatch(EditorCommandId.newEudSource)
        ? _newEudSource
        : null;
    final undoEdit =
        _workspaceView == _WorkspaceView.map &&
            widget.openMapController.editHistory.canUndo
        ? widget.openMapController.editHistory.undo
        : null;
    final redoEdit =
        _workspaceView == _WorkspaceView.map &&
            widget.openMapController.editHistory.canRedo
        ? widget.openMapController.editHistory.redo
        : null;
    final deleteObjects =
        _workspaceView == _WorkspaceView.map &&
            widget.objectEditingController.canEditSelection
        ? () => deleteObjectsWithDoodadReview(
            context,
            widget.objectEditingController,
            widget.placementCatalogController,
          )
        : null;
    final cancelObjectPlacement =
        _workspaceView == _WorkspaceView.map &&
            (widget.objectPaletteController.state.isPlacementActive ||
                widget.placementCatalogController.state.isPlacementActive)
        ? () {
            widget.objectPaletteController.cancelPlacement();
            widget.placementCatalogController.cancelSelection();
          }
        : null;
    final cancelLocationCreation =
        _workspaceView == _WorkspaceView.map &&
            widget.objectEditingController.state.isCreatingLocation
        ? widget.objectEditingController.cancelLocationCreation
        : null;
    final starCraftDataAssetState =
        widget.starCraftDataAssetSettingsController.state;
    final terrainTileTextureState = widget.terrainTileTextureController.state;
    final objectSpriteTextureState = widget.objectSpriteTextureController.state;
    final visibleDiagnostics = [
      ..._documentDiagnostics,
      ...starCraftDataAssetState.diagnostics,
      ...terrainTileTextureState.diagnostics,
      ...objectSpriteTextureState.diagnostics,
    ];

    final VoidCallback? prepareEud =
        widget.eudBuildPreparationController == null || eudBuildState.isActive
        ? null
        : () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => EudBuildPreparationDialog(
              controller: widget.eudBuildPreparationController!,
              baseMap: widget.openMapController.state.session?.sourcePath ?? '',
              entrySource:
                  widget.eudSourceController.state.document?.sourcePath ?? '',
            ),
          );
    final activeSession = widget.openMapController.state.session;
    final activeEudDocument = widget.eudSourceController.state.document;
    final eudBuildSteps = activeEudDocument == null
        ? null
        : EudBuildSteps(
            map: activeSession == null
                ? EudBuildMapStep.none
                : activeSession.isDirty || activeSession.sourcePath == null
                ? EudBuildMapStep.dirty
                : EudBuildMapStep.saved,
            source: activeEudDocument.isUntitled
                ? EudBuildSourceStep.untitled
                : activeEudDocument.isDirty
                ? EudBuildSourceStep.dirty
                : EudBuildSourceStep.saved,
            status: eudBuildState.status,
            onPrepare: prepareEud,
            onBuild: buildEud,
          );

    final shortcuts = <ShortcutActivator, VoidCallback>{};
    if (openMap != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyN, control: true)] =
          _newMap;
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyO, control: true)] =
          openMap;
    }
    if (saveAs != null) {
      shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyS,
            control: true,
            shift: true,
          )] =
          saveAs;
    }
    if (buildEud != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyB, control: true)] =
          buildEud;
    }
    if (cancelEudBuild != null) {
      shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyB,
            control: true,
            shift: true,
          )] =
          cancelEudBuild;
    }
    if (newEudSource != null) {
      shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyN,
            control: true,
            alt: true,
          )] =
          newEudSource;
    }
    if (undoEdit != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyZ, control: true)] =
          undoEdit;
    }
    if (redoEdit != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyY, control: true)] =
          redoEdit;
    }
    if (deleteObjects != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.delete)] =
          deleteObjects;
    }
    if (_workspaceView == _WorkspaceView.map &&
        openMap != null &&
        widget.openMapController.state.session != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyF, control: true)] =
          _openSelectionNavigation;
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyG,
        control: true,
      )] = () =>
          _openSelectionNavigation(coordinates: true);
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyA,
        control: true,
      )] = () =>
          _selectionAction(_selectionNavigation.selectAll);
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyI,
        control: true,
      )] = () =>
          _selectionAction(_selectionNavigation.invert);
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyT,
        control: true,
        shift: true,
      )] = () =>
          _selectionAction(() => _selectionNavigation.selectRelated());
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyJ,
        control: true,
      )] = () =>
          _navigateTo(_selectionNavigation.focusSelection());
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyJ,
        control: true,
        shift: true,
      )] = () =>
          _navigateTo(_selectionNavigation.focusSelection(fit: true));
      shortcuts[const SingleActivator(LogicalKeyboardKey.keyC, control: true)] =
          _copyObjectsShortcut;
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyX,
        control: true,
      )] = () =>
          _copyObjectsShortcut(cut: true);
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyV,
        control: true,
      )] = () =>
          _openBasicTools(initialTab: 5);
      shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyE,
            control: true,
            shift: true,
          )] =
          _openBasicTools;
    }
    if (cancelObjectPlacement != null || cancelLocationCreation != null) {
      shortcuts[const SingleActivator(LogicalKeyboardKey.escape)] = () {
        cancelObjectPlacement?.call();
        cancelLocationCreation?.call();
      };
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: const Key('editor-shell'),
          body: SafeArea(
            child: Column(
              children: [
                _EditorMenuBar(
                  recovery: widget.autosaveController == null
                      ? null
                      : _showRecovery,
                  autosaveSettings: widget.autosaveController == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => AutosaveSettingsDialog(
                            controller: widget.autosaveController!,
                          ),
                        ),
                  newMap: openMap == null ? null : _newMap,
                  selectionNavigation:
                      widget.openMapController.state.session == null
                      ? null
                      : _openSelectionNavigation,
                  basicTools:
                      openMap != null &&
                          widget.openMapController.state.session != null
                      ? _openBasicTools
                      : null,
                  fillIsom:
                      widget.isomFillController != null &&
                          openMap != null &&
                          widget.openMapController.state.session != null
                      ? _fillIsom
                      : null,
                  resizeMap:
                      openMap == null ||
                          widget.openMapController.state.session == null
                      ? null
                      : _resizeMap,
                  prepareEud: prepareEud,
                  openEudTools: widget.eudToolSettingsController == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => EudToolSettingsDialog(
                            controller: widget.eudToolSettingsController!,
                          ),
                        ),
                  openMapSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : _showSettingsWorkspace,
                  openTechSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => TechSettingsDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openUpgradeSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => UpgradeSettingsDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openUnitAvailability:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => UnitAvailabilityDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openUnitSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => UnitSettingsDialog(
                            catalogController:
                                widget.placementCatalogController,
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openForceSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => ForceSettingsDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openPlayerSettings:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => PlayerSettingsDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openMapInformation:
                      widget.openMapController.state.session == null
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) => MapInformationDialog(
                            controller: widget.objectEditingController,
                          ),
                        ),
                  openMap: openMap,
                  saveAs: saveAs,
                  newEudSource: newEudSource,
                  buildEud: buildEud,
                  cancelEudBuild: cancelEudBuild,
                  undo: undoEdit,
                  redo: redoEdit,
                  openSettings: _showStarCraftDataAssetSettings,
                  languagePreference: widget.languageController?.preference,
                  onLanguageSelected: widget.languageController == null
                      ? null
                      : _setLanguage,
                ),
                const Divider(height: 1),
                if (widget.autosaveController?.lastError != null)
                  MaterialBanner(
                    content: Text(context.l10n.autosaveFailed),
                    actions: [
                      TextButton(
                        onPressed: _showRecovery,
                        child: Text(context.l10n.recoveryTitle),
                      ),
                    ],
                  ),
                _EditorToolbar(
                  openMap: openMap,
                  saveAs: saveAs,
                  newEudSource: newEudSource,
                  buildEud: buildEud,
                  cancelEudBuild: cancelEudBuild,
                  eudBuildActive: eudBuildState.isActive,
                  starCraftDataAssetState: starCraftDataAssetState,
                  openSettings: _showStarCraftDataAssetSettings,
                  documentName: _activeDocumentName(),
                  documentDirty: _activeDocumentDirty(),
                  languagePreference: widget.languageController?.preference,
                  onLanguageSelected: widget.languageController == null
                      ? null
                      : _setLanguage,
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<OpenMapState>(
                    initialData: widget.openMapController.state,
                    stream: widget.openMapController.changes,
                    builder: (context, openMapSnapshot) {
                      return FutureBuilder<List<RecentProject>>(
                        future: _recentProjects,
                        builder: (context, recentProjectsSnapshot) {
                          return _EditorWorkspace(
                            onEditTerrain: widget.isomFillController == null
                                ? null
                                : () => _fillIsom(initialMode: 2),
                            eudBuildSteps: eudBuildSteps,
                            openMap: openMap,
                            openMapState:
                                openMapSnapshot.data ??
                                const OpenMapState.idle(),
                            recentProjects:
                                recentProjectsSnapshot.data ?? const [],
                            recentProjectsError:
                                recentProjectsSnapshot.hasError,
                            recentProjectsLoading:
                                recentProjectsSnapshot.connectionState ==
                                ConnectionState.waiting,
                            onOpenRecentProject:
                                widget.commandDispatcher.canDispatch(
                                  EditorCommandId.openMap,
                                )
                                ? _openRecentProject
                                : null,
                            onRemoveRecentProject: _removeRecentProject,
                            eudSourceController: widget.eudSourceController,
                            projectWorkspace: widget.eudProjectWorkspace,
                            onShowProject: () => setState(
                              () => _workspaceView = _WorkspaceView.project,
                            ),
                            terrainEditingController:
                                widget.terrainEditingController,
                            mapLayerController: widget.mapLayerController,
                            selectionNavigation: _selectionNavigation,
                            navigationTarget: _navigationTarget,
                            selectionInteractionRevision:
                                _selectionInteractionRevision,
                            objectEditingController:
                                widget.objectEditingController,
                            objectPaletteController:
                                widget.objectPaletteController,
                            placementCatalogController:
                                widget.placementCatalogController,
                            terrainTileTextureState: terrainTileTextureState,
                            objectSpriteTextureState: objectSpriteTextureState,
                            workspaceView: _workspaceView,
                            onShowMap: _showMapWorkspace,
                            onShowEud: _showEudWorkspace,
                            onShowCatalog: _showCatalogWorkspace,
                            onOpenSettings: _showSettingsWorkspace,
                            onShowBriefing: () => setState(
                              () => _workspaceView = _WorkspaceView.briefing,
                            ),
                            onShowResources: () => setState(
                              () => _workspaceView = _WorkspaceView.resources,
                            ),
                            onShowTriggers: () => setState(
                              () => _workspaceView = _WorkspaceView.triggers,
                            ),
                            settingsPage: _settingsVisited
                                ? MapSettingsDialog(
                                    controller: widget.objectEditingController,
                                    catalogController:
                                        widget.placementCatalogController,
                                    embedded: true,
                                    onExecutionRules:
                                        widget.eudProjectWorkspace == null
                                        ? null
                                        : () => setState(
                                            () => _workspaceView =
                                                _WorkspaceView.project,
                                          ),
                                    onClosed: _showMapWorkspace,
                                  )
                                : const SizedBox.shrink(),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                StreamBuilder<OperationProgress?>(
                  initialData: widget.operationProgressController.current,
                  stream: widget.operationProgressController.changes,
                  builder: (context, snapshot) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _OutputPanel(
                          progress: snapshot.data,
                          diagnostics: visibleDiagnostics,
                          eudBuildState: eudBuildState,
                        ),
                        const Divider(height: 1),
                        _StatusBar(
                          progress: snapshot.data,
                          session: widget.openMapController.state.session,
                          eudDocument:
                              widget.eudSourceController.state.document,
                          workspaceView: _workspaceView,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorMenuBar extends StatelessWidget {
  const _EditorMenuBar({
    this.recovery,
    this.autosaveSettings,
    this.prepareEud,
    this.openEudTools,
    required this.openUnitAvailability,
    required this.openUpgradeSettings,
    required this.openTechSettings,
    required this.openMapSettings,
    required this.openUnitSettings,
    required this.openForceSettings,
    required this.openPlayerSettings,
    required this.openMapInformation,
    required this.newMap,
    required this.fillIsom,
    required this.basicTools,
    required this.selectionNavigation,
    required this.resizeMap,
    required this.openMap,
    required this.saveAs,
    required this.newEudSource,
    required this.buildEud,
    required this.cancelEudBuild,
    required this.undo,
    required this.redo,
    required this.openSettings,
    required this.languagePreference,
    required this.onLanguageSelected,
  });

  final VoidCallback? newMap;
  final VoidCallback? recovery;
  final VoidCallback? autosaveSettings;
  final VoidCallback? fillIsom;
  final VoidCallback? basicTools;
  final VoidCallback? selectionNavigation;
  final VoidCallback? resizeMap;
  final VoidCallback? openMap;
  final VoidCallback? openEudTools;
  final VoidCallback? prepareEud;
  final VoidCallback? openMapInformation;
  final VoidCallback? openUnitAvailability;
  final VoidCallback? openUpgradeSettings;
  final VoidCallback? openTechSettings;
  final VoidCallback? openMapSettings;
  final VoidCallback? openUnitSettings;
  final VoidCallback? openForceSettings;
  final VoidCallback? openPlayerSettings;
  final VoidCallback? saveAs;
  final VoidCallback? newEudSource;
  final VoidCallback? buildEud;
  final VoidCallback? cancelEudBuild;
  final VoidCallback? undo;
  final VoidCallback? redo;
  final VoidCallback openSettings;
  final AppLanguagePreference? languagePreference;
  final ValueChanged<AppLanguagePreference>? onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuBar(
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('menu-new-map'),
              onPressed: newMap,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
              ),
              child: Text(l10n.menuNewMap),
            ),
            MenuItemButton(
              onPressed: openMap,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ),
              child: Text(l10n.menuOpenMap),
            ),
            MenuItemButton(
              onPressed: saveAs,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
                shift: true,
              ),
              child: Text(l10n.menuSaveAs),
            ),
            MenuItemButton(
              onPressed: recovery,
              leadingIcon: const Icon(Icons.restore),
              child: Text(l10n.recoveryTitle),
            ),
            MenuItemButton(
              onPressed: autosaveSettings,
              leadingIcon: const Icon(Icons.schedule),
              child: Text(l10n.autosaveSettings),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: openMapInformation,
              child: Text(l10n.menuMapInformation),
            ),
            MenuItemButton(
              key: const Key('menu-isom-fill'),
              onPressed: fillIsom,
              child: Text(l10n.isomFillTitle),
            ),
            MenuItemButton(
              onPressed: openMapSettings,
              child: Text(l10n.menuMapSettings),
            ),
            MenuItemButton(
              onPressed: openPlayerSettings,
              child: Text(l10n.menuPlayerSettings),
            ),
            MenuItemButton(
              onPressed: openForceSettings,
              child: Text(l10n.menuForceSettings),
            ),
            MenuItemButton(
              onPressed: openUnitSettings,
              child: Text(l10n.menuUnitSettings),
            ),
            MenuItemButton(
              onPressed: openUnitAvailability,
              child: Text(l10n.menuUnitAvailability),
            ),
            MenuItemButton(
              onPressed: openUpgradeSettings,
              child: Text(l10n.menuUpgradeSettings),
            ),
            MenuItemButton(
              onPressed: openTechSettings,
              child: Text(l10n.menuTechSettings),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: prepareEud,
              child: Text(l10n.menuPrepareEudBuild),
            ),
            MenuItemButton(
              onPressed: openEudTools,
              child: Text(l10n.menuEudTools),
            ),
            const Divider(),
            MenuItemButton(onPressed: null, child: Text(l10n.menuClose)),
          ],
          child: Text(l10n.menuFile),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('menu-undo'),
              onPressed: undo,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
              ),
              child: Text(l10n.menuUndo),
            ),
            MenuItemButton(
              key: const Key('menu-redo'),
              onPressed: redo,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyY,
                control: true,
              ),
              child: Text(l10n.menuRedo),
            ),
            const Divider(),
            MenuItemButton(
              key: const Key('menu-selection-navigation'),
              onPressed: selectionNavigation,
              child: Text(l10n.selectionTitle),
            ),
            MenuItemButton(
              key: const Key('menu-basic-tools'),
              onPressed: basicTools,
              child: Text(l10n.basicToolsTitle),
            ),
            MenuItemButton(
              key: const Key('menu-settings'),
              onPressed: openSettings,
              child: Text(l10n.menuSettings),
            ),
            if (onLanguageSelected case final onSelected?)
              SubmenuButton(
                key: const Key('menu-language'),
                leadingIcon: const Icon(Icons.translate_rounded, size: 18),
                menuChildren: [
                  for (final preference in AppLanguagePreference.values)
                    MenuItemButton(
                      key: Key('menu-language-${preference.storageValue}'),
                      leadingIcon: Icon(
                        preference == languagePreference
                            ? Icons.check_rounded
                            : null,
                        size: 18,
                      ),
                      onPressed: () => onSelected(preference),
                      child: Text(_languageOptionLabel(l10n, preference)),
                    ),
                ],
                child: Text(l10n.menuLanguage),
              ),
          ],
          child: Text(l10n.menuEdit),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(onPressed: null, child: Text(l10n.menuResetLayout)),
          ],
          child: Text(l10n.menuView),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: newEudSource,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
                alt: true,
              ),
              child: Text(l10n.menuNewEpScript),
            ),
            const Divider(),
            MenuItemButton(
              key: const Key('menu-build-eud'),
              onPressed: buildEud,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyB,
                control: true,
              ),
              child: Text(l10n.menuBuildEudMap),
            ),
            MenuItemButton(
              key: const Key('menu-cancel-eud-build'),
              onPressed: cancelEudBuild,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyB,
                control: true,
                shift: true,
              ),
              child: Text(l10n.menuCancelEudBuild),
            ),
          ],
          child: Text(l10n.menuEud),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: null,
              child: Text(l10n.menuDocumentation),
            ),
            MenuItemButton(onPressed: null, child: Text(l10n.menuAbout)),
          ],
          child: Text(l10n.menuHelp),
        ),
      ],
    );
  }
}

String _languageOptionLabel(
  AppLocalizations l10n,
  AppLanguagePreference preference,
) => switch (preference) {
  AppLanguagePreference.system => l10n.languageSystem(
    languageAutonym(AppLanguagePreference.system),
  ),
  _ => languageAutonym(preference),
};

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.openMap,
    required this.saveAs,
    required this.newEudSource,
    required this.buildEud,
    required this.cancelEudBuild,
    required this.eudBuildActive,
    required this.starCraftDataAssetState,
    required this.openSettings,
    required this.documentName,
    required this.documentDirty,
    required this.languagePreference,
    required this.onLanguageSelected,
  });

  final VoidCallback? openMap;
  final VoidCallback? saveAs;
  final VoidCallback? newEudSource;
  final VoidCallback? buildEud;
  final VoidCallback? cancelEudBuild;
  final bool eudBuildActive;
  final StarCraftDataAssetSettingsState starCraftDataAssetState;
  final VoidCallback openSettings;
  final String? documentName;
  final bool documentDirty;
  final AppLanguagePreference? languagePreference;
  final ValueChanged<AppLanguagePreference>? onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1420;
          final compactEnvironmentBadge =
              !compact && constraints.maxWidth < 1550;
          final showEnvironmentBadge = constraints.maxWidth >= 1000;
          final documentName = this.documentName;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Color(0xFF70A1FF)),
                const SizedBox(width: 10),
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showEnvironmentBadge) ...[
                  const SizedBox(width: 12),
                  _EnvironmentBadge(
                    assetState: starCraftDataAssetState,
                    onPressed: openSettings,
                    compact: compactEnvironmentBadge,
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: documentName == null
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          builder: (context, statusConstraints) =>
                              statusConstraints.maxWidth < 96
                              ? const SizedBox.shrink()
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: _DocumentSaveStatus(
                                    name: documentName,
                                    dirty: documentDirty,
                                  ),
                                ),
                        ),
                ),
                if (onLanguageSelected case final onSelected?)
                  PopupMenuButton<AppLanguagePreference>(
                    key: const Key('toolbar-language'),
                    tooltip: l10n.languageTooltip,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(36, 36),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.translate_rounded, size: 20),
                    initialValue: languagePreference,
                    onSelected: onSelected,
                    itemBuilder: (context) => [
                      for (final preference in AppLanguagePreference.values)
                        CheckedPopupMenuItem(
                          key: Key(
                            'toolbar-language-${preference.storageValue}',
                          ),
                          value: preference,
                          checked: preference == languagePreference,
                          child: Text(_languageOptionLabel(l10n, preference)),
                        ),
                    ],
                  ),
                if (compact) ...[
                  IconButton(
                    key: const Key('toolbar-open-map'),
                    onPressed: openMap,
                    tooltip: l10n.toolbarOpenMap,
                    icon: const Icon(Icons.folder_open),
                  ),
                  IconButton(
                    key: const Key('toolbar-save-as'),
                    onPressed: saveAs,
                    tooltip: l10n.toolbarSaveAs,
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton(
                    key: const Key('toolbar-new-eud-source'),
                    onPressed: newEudSource,
                    tooltip: l10n.toolbarNewEpScript,
                    icon: const Icon(Icons.code_rounded),
                  ),
                  if (eudBuildActive)
                    IconButton.filled(
                      key: const Key('toolbar-cancel-eud-build'),
                      onPressed: cancelEudBuild,
                      tooltip: l10n.menuCancelEudBuild,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    IconButton.filled(
                      key: const Key('toolbar-build-eud'),
                      onPressed: buildEud,
                      tooltip: l10n.toolbarBuildEud,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                ] else ...[
                  TextButton.icon(
                    key: const Key('toolbar-open-map'),
                    onPressed: openMap,
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.toolbarOpenMap),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('toolbar-save-as'),
                    onPressed: saveAs,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.toolbarSaveAs),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('toolbar-new-eud-source'),
                    onPressed: newEudSource,
                    icon: const Icon(Icons.code_rounded),
                    label: Text(l10n.toolbarNewEpScript),
                  ),
                  const SizedBox(width: 8),
                  if (eudBuildActive)
                    FilledButton.icon(
                      key: const Key('toolbar-cancel-eud-build'),
                      onPressed: cancelEudBuild,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(l10n.toolbarCancelBuild),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('toolbar-build-eud'),
                      onPressed: buildEud,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l10n.toolbarBuildEud),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The active document and whether it still has unsaved edits, spelled out
/// instead of relying on a bullet next to a tab.
class _DocumentSaveStatus extends StatelessWidget {
  const _DocumentSaveStatus({required this.name, required this.dirty});

  final String name;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = dirty ? const Color(0xFFF6C85F) : const Color(0xFF8994A8);
    return Row(
      key: const Key('toolbar-document-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dirty ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$name · ${dirty ? l10n.documentUnsaved : l10n.documentSaved}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EnvironmentBadge extends StatelessWidget {
  const _EnvironmentBadge({
    required this.assetState,
    required this.onPressed,
    required this.compact,
  });

  final StarCraftDataAssetSettingsState assetState;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, compactLabel, color) = switch (assetState.status) {
      StarCraftDataAssetSettingsStatus.loading ||
      StarCraftDataAssetSettingsStatus.inspecting => (
        l10n.assetsChecking,
        l10n.assetsCheckingShort,
        const Color(0xFFAAC8FF),
      ),
      StarCraftDataAssetSettingsStatus.ready => (
        l10n.assetsReady,
        l10n.assetsReadyShort,
        const Color(0xFF7ADAA5),
      ),
      StarCraftDataAssetSettingsStatus.unconfigured => (
        l10n.assetsNotConfigured,
        l10n.assetsNotConfiguredShort,
        const Color(0xFFFFC56E),
      ),
      StarCraftDataAssetSettingsStatus.unavailable => (
        l10n.assetsUnavailable,
        l10n.assetsUnavailableShort,
        const Color(0xFFFFB454),
      ),
    };

    return Tooltip(
      message: l10n.environmentBadgeTooltip(label),
      child: InkWell(
        key: const Key('starcraft-asset-environment-status'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2738),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF33445F)),
          ),
          child: Text(
            compact
                ? l10n.environmentBadgeCompact(compactLabel)
                : l10n.environmentBadge(label),
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _EditorWorkspace extends StatelessWidget {
  const _EditorWorkspace({
    this.onEditTerrain,
    this.eudBuildSteps,
    required this.openMap,
    required this.openMapState,
    required this.recentProjects,
    required this.recentProjectsError,
    required this.recentProjectsLoading,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
    required this.eudSourceController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.selectionNavigation,
    this.navigationTarget,
    this.selectionInteractionRevision = 0,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.placementCatalogController,
    required this.terrainTileTextureState,
    required this.objectSpriteTextureState,
    required this.workspaceView,
    required this.onShowMap,
    required this.onShowEud,
    required this.onShowCatalog,
    required this.onOpenSettings,
    required this.settingsPage,
    required this.projectWorkspace,
    required this.onShowProject,
    required this.onShowTriggers,
    required this.onShowResources,
    required this.onShowBriefing,
  });

  final VoidCallback? onEditTerrain;
  final Widget? eudBuildSteps;
  final VoidCallback? openMap;
  final OpenMapState openMapState;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;
  final EudSourceController eudSourceController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final SelectionNavigationController selectionNavigation;
  final MapNavigationTarget? navigationTarget;
  final int selectionInteractionRevision;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final PlacementCatalogController placementCatalogController;
  final TerrainTileTextureState terrainTileTextureState;
  final ObjectSpriteTextureState objectSpriteTextureState;
  final _WorkspaceView workspaceView;
  final VoidCallback onShowMap;
  final VoidCallback onShowEud;
  final VoidCallback onShowCatalog;
  final VoidCallback onOpenSettings;
  final Widget settingsPage;
  final EudProjectWorkspace? projectWorkspace;
  final VoidCallback onShowProject;
  final VoidCallback onShowTriggers;
  final VoidCallback onShowResources;
  final VoidCallback onShowBriefing;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;
    final eudDocument = eudSourceController.state.document;
    final fullWidth =
        workspaceView == _WorkspaceView.briefing ||
        workspaceView == _WorkspaceView.resources ||
        workspaceView == _WorkspaceView.triggers ||
        workspaceView == _WorkspaceView.settings ||
        workspaceView == _WorkspaceView.project;
    final showingEud =
        workspaceView == _WorkspaceView.eud && eudDocument != null;
    final l10n = context.l10n;
    final showRail =
        session != null || eudDocument != null || projectWorkspace != null;

    return Row(
      children: [
        if (showRail) ...[
          _WorkspaceRail(
            session: session,
            eudDocument: eudDocument,
            workspaceView: workspaceView,
            onShowMap: onShowMap,
            onShowEud: onShowEud,
            onShowCatalog: onShowCatalog,
            onOpenSettings: onOpenSettings,
            projectWorkspace: projectWorkspace,
            onShowProject: onShowProject,
            onShowTriggers: onShowTriggers,
            onShowResources: onShowResources,
            onShowBriefing: onShowBriefing,
          ),
          const VerticalDivider(width: 1),
        ],
        SizedBox(
          width: fullWidth ? 0 : 210,
          child: Offstage(
            offstage: fullWidth,
            child: _EditorPane(
              title: showingEud
                  ? l10n.paneProjectSources
                  : session == null
                  ? l10n.paneProjectLayers
                  : l10n.paneLayersPalette,
              child: showingEud
                  ? _EudSourceList(document: eudDocument, onSelected: onShowEud)
                  : session == null
                  ? _EmptyPaneMessage(
                      icon: Icons.layers_outlined,
                      message: l10n.emptyLayers,
                    )
                  : _MapLayersAndPalette(
                      session: session,
                      layerController: mapLayerController,
                      paletteController: objectPaletteController,
                      onShowCatalog: onShowCatalog,
                      onLayerActivated: (layer) {
                        objectPaletteController.cancelPlacement();
                        objectEditingController.cancelLocationCreation();
                        mapLayerController.setActiveLayer(layer);
                        if (layer != MapLayerType.terrain) {
                          terrainEditingController.setTool(
                            TerrainEditingTool.select,
                          );
                        }
                      },
                    ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: workspaceView == _WorkspaceView.briefing
                      ? 5
                      : workspaceView == _WorkspaceView.resources
                      ? 4
                      : workspaceView == _WorkspaceView.triggers
                      ? 3
                      : workspaceView == _WorkspaceView.project
                      ? 2
                      : workspaceView == _WorkspaceView.settings
                      ? 1
                      : 0,
                  children: [
                    _MapWorkspace(
                      onEditTerrain: onEditTerrain,
                      eudBuildSteps: eudBuildSteps,
                      selectionNavigation: selectionNavigation,
                      navigationTarget: navigationTarget,
                      selectionInteractionRevision:
                          selectionInteractionRevision,
                      openMap: openMap,
                      openMapState: openMapState,
                      recentProjects: recentProjects,
                      recentProjectsError: recentProjectsError,
                      recentProjectsLoading: recentProjectsLoading,
                      onOpenRecentProject: onOpenRecentProject,
                      onRemoveRecentProject: onRemoveRecentProject,
                      eudSourceController: eudSourceController,
                      terrainEditingController: terrainEditingController,
                      mapLayerController: mapLayerController,
                      objectEditingController: objectEditingController,
                      objectPaletteController: objectPaletteController,
                      placementCatalogController: placementCatalogController,
                      terrainTileTextureState: terrainTileTextureState,
                      objectSpriteTextureState: objectSpriteTextureState,
                      workspaceView: workspaceView,
                      onShowMap: onShowMap,
                    ),
                    settingsPage,
                    if (projectWorkspace != null)
                      EudProjectPane(
                        key: ObjectKey(projectWorkspace),
                        workspace: projectWorkspace!,
                        sourceController: eudSourceController,
                        catalog: placementCatalogController,
                      )
                    else
                      const SizedBox.shrink(),
                    DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(text: l10n.triggersOrdinary),
                              Tab(text: l10n.triggersEudExtensions),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                TriggerPane(
                                  controller: objectEditingController,
                                ),
                                if (projectWorkspace != null)
                                  StreamBuilder<void>(
                                    stream: projectWorkspace!.changes,
                                    builder: (context, _) {
                                      final controller =
                                          projectWorkspace!.projects;
                                      return ListView(
                                        padding: const EdgeInsets.all(16),
                                        children: [
                                          TextButton(
                                            onPressed: onShowProject,
                                            child: Text(
                                              l10n.triggersOpenEudProject,
                                            ),
                                          ),
                                          if (controller.project != null) ...[
                                            Material(
                                              color: const Color(0xFF1B1F24),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: const BorderSide(
                                                  color: Color(0xFF2C3238),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: EudRulesEditor(
                                                  controller: controller,
                                                  enabled:
                                                      !projectWorkspace!.isBusy,
                                                ),
                                              ),
                                            ),
                                            Wrap(
                                              children: [
                                                TextButton(
                                                  onPressed: controller.canUndo
                                                      ? controller.undo
                                                      : null,
                                                  child: Text(
                                                    l10n.triggersUndoProject,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: controller.canRedo
                                                      ? controller.redo
                                                      : null,
                                                  child: Text(
                                                    l10n.triggersRedoProject,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  )
                                else
                                  Text(l10n.triggersEudUnavailable),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ResourcesPane(
                      controller: objectEditingController,
                      active: workspaceView == _WorkspaceView.resources,
                    ),
                    TriggerPane(
                      controller: objectEditingController,
                      briefing: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: fullWidth ? 0 : 260,
          child: Offstage(
            offstage: fullWidth,
            child: _EditorPane(
              title: l10n.paneInspector,
              child: showingEud
                  ? _EudSourceInspector(document: eudDocument)
                  : session == null
                  ? _EmptyPaneMessage(
                      icon: Icons.tune,
                      message: l10n.emptyInspector,
                    )
                  : _MapInspector(
                      session: session,
                      mapLayerController: mapLayerController,
                      objectEditingController: objectEditingController,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical navigation between the open map, its editors and EUD documents.
///
/// Each destination shows an icon and a short label so the user does not need
/// to recognise document tabs by file name alone. The keys match the former
/// document tabs so existing automation keeps working.
class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({
    required this.session,
    required this.eudDocument,
    required this.workspaceView,
    required this.onShowMap,
    required this.onShowEud,
    required this.onShowCatalog,
    required this.onOpenSettings,
    required this.projectWorkspace,
    required this.onShowProject,
    required this.onShowTriggers,
    required this.onShowResources,
    required this.onShowBriefing,
  });

  final OpenedMapSession? session;
  final EudSourceDocument? eudDocument;
  final _WorkspaceView workspaceView;
  final VoidCallback onShowMap;
  final VoidCallback onShowEud;
  final VoidCallback onShowCatalog;
  final VoidCallback onOpenSettings;
  final EudProjectWorkspace? projectWorkspace;
  final VoidCallback onShowProject;
  final VoidCallback onShowTriggers;
  final VoidCallback onShowResources;
  final VoidCallback onShowBriefing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final document = eudDocument;
    final session = this.session;
    return Semantics(
      container: true,
      label: l10n.railLabel,
      child: SizedBox(
        key: const Key('workspace-rail'),
        width: 88,
        child: ColoredBox(
          color: const Color(0xFF12161D),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session != null)
                  _RailDestination(
                    key: const Key('map-document-tab'),
                    label: l10n.railMap,
                    tooltip: _sessionName(l10n, session),
                    dirty: session.isDirty,
                    icon: Icons.map_outlined,
                    selected: workspaceView == _WorkspaceView.map,
                    onPressed: onShowMap,
                  ),
                if (session != null)
                  _RailDestination(
                    key: const Key('placement-catalog-tab'),
                    label: l10n.railCatalog,
                    icon: Icons.grid_view_rounded,
                    selected: workspaceView == _WorkspaceView.catalog,
                    onPressed: onShowCatalog,
                  ),
                if (session != null)
                  _RailDestination(
                    key: const Key('map-settings-tab'),
                    label: l10n.railMapSettings,
                    icon: Icons.tune,
                    selected: workspaceView == _WorkspaceView.settings,
                    onPressed: onOpenSettings,
                  ),
                if (session != null)
                  _RailDestination(
                    key: const Key('triggers-tab'),
                    label: l10n.railTriggers,
                    icon: Icons.account_tree_outlined,
                    selected: workspaceView == _WorkspaceView.triggers,
                    onPressed: onShowTriggers,
                  ),
                if (session != null)
                  _RailDestination(
                    key: const Key('resources-tab'),
                    label: l10n.railResources,
                    icon: Icons.library_music,
                    selected: workspaceView == _WorkspaceView.resources,
                    onPressed: onShowResources,
                  ),
                if (session != null)
                  _RailDestination(
                    key: const Key('briefing-tab'),
                    label: l10n.railBriefing,
                    icon: Icons.movie_outlined,
                    selected: workspaceView == _WorkspaceView.briefing,
                    onPressed: onShowBriefing,
                  ),
                if (session != null &&
                    (document != null || projectWorkspace != null))
                  const Divider(height: 17, indent: 10, endIndent: 10),
                if (document != null)
                  _RailDestination(
                    key: const Key('eud-source-tab'),
                    label: document.fileName,
                    tooltip: document.sourcePath ?? document.fileName,
                    dirty: document.isDirty,
                    icon: Icons.code_rounded,
                    selected: workspaceView == _WorkspaceView.eud,
                    onPressed: onShowEud,
                  ),
                if (projectWorkspace != null)
                  _RailDestination(
                    key: const Key('eud-project-tab'),
                    label: l10n.railEudProject,
                    dirty: projectWorkspace!.projects.isDirty,
                    icon: Icons.folder_open,
                    selected: workspaceView == _WorkspaceView.project,
                    onPressed: onShowProject,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.tooltip,
    this.dirty = false,
    super.key,
  });

  final String label;
  final String? tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = tooltip ?? label;
    final foreground = selected
        ? const Color(0xFFE1E8F3)
        : const Color(0xFF9AA5B8);
    return Tooltip(
      message: dirty ? l10n.railUnsavedTooltip(name) : name,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? const Color(0xFF223450) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: selected
                            ? const Color(0xFF8EB5FF)
                            : const Color(0xFF778398),
                      ),
                      if (dirty)
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF6C85F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$label${dirty ? ' •' : ''}',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EudSourceList extends StatelessWidget {
  const _EudSourceList({required this.document, required this.onSelected});

  final EudSourceDocument document;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('eud-source-list'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            selected: true,
            dense: true,
            leading: const Icon(
              Icons.code_rounded,
              size: 18,
              color: Color(0xFF70A1FF),
            ),
            title: Text(
              '${document.fileName}${document.isDirty ? ' •' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              document.isUntitled
                  ? context.l10n.sourceDraft
                  : context.l10n.sourceEpScript,
            ),
            onTap: onSelected,
          ),
        ),
      ],
    );
  }
}

class _EudSourceInspector extends StatelessWidget {
  const _EudSourceInspector({required this.document});

  final EudSourceDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('eud-source-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _InspectorValue(label: l10n.inspectorFile, value: document.fileName),
        _InspectorValue(
          label: l10n.inspectorLocation,
          value: document.sourcePath ?? l10n.inMemoryDraft,
        ),
        _InspectorValue(
          label: l10n.inspectorLines,
          value: '${document.lineCount}',
        ),
        _InspectorValue(
          label: l10n.inspectorCharacters,
          value: '${document.text.length}',
        ),
        _InspectorValue(
          label: l10n.inspectorRevision,
          value: '${document.revision}',
        ),
        _InspectorValue(
          label: l10n.inspectorState,
          value: document.isDirty ? l10n.stateModified : l10n.stateClean,
        ),
      ],
    );
  }
}

class _EditorPane extends StatelessWidget {
  const _EditorPane({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF151A22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF1A202A),
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EmptyPaneMessage extends StatelessWidget {
  const _EmptyPaneMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF657086)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9AA5B8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapWorkspace extends StatelessWidget {
  const _MapWorkspace({
    this.onEditTerrain,
    this.eudBuildSteps,
    required this.openMap,
    required this.openMapState,
    required this.recentProjects,
    required this.recentProjectsError,
    required this.recentProjectsLoading,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
    required this.eudSourceController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.selectionNavigation,
    this.navigationTarget,
    this.selectionInteractionRevision = 0,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.placementCatalogController,
    required this.terrainTileTextureState,
    required this.objectSpriteTextureState,
    required this.workspaceView,
    required this.onShowMap,
  });

  final VoidCallback? onEditTerrain;
  final Widget? eudBuildSteps;
  final VoidCallback? openMap;
  final OpenMapState openMapState;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;
  final EudSourceController eudSourceController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final SelectionNavigationController selectionNavigation;
  final MapNavigationTarget? navigationTarget;
  final int selectionInteractionRevision;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final PlacementCatalogController placementCatalogController;
  final TerrainTileTextureState terrainTileTextureState;
  final ObjectSpriteTextureState objectSpriteTextureState;
  final _WorkspaceView workspaceView;
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;
    final eudDocument = eudSourceController.state.document;
    if (workspaceView == _WorkspaceView.eud && eudDocument != null) {
      final editor = EudSourceEditor(
        document: eudDocument,
        sourceController: eudSourceController,
      );
      final steps = eudBuildSteps;
      return steps == null
          ? editor
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                steps,
                const Divider(height: 1),
                Expanded(child: editor),
              ],
            );
    }
    if (workspaceView == _WorkspaceView.catalog && session != null) {
      return PlacementCatalogPane(
        controller: placementCatalogController,
        onPlacementConfirmed: onShowMap,
        onClose: onShowMap,
      );
    }
    if (session != null) {
      return _OpenedMapWorkspace(
        onEditTerrain: onEditTerrain,
        session: session,
        selectionNavigation: selectionNavigation,
        navigationTarget: navigationTarget,
        selectionInteractionRevision: selectionInteractionRevision,
        diagnostics: [
          ...session.diagnostics,
          ...terrainTileTextureState.diagnostics,
          ...objectSpriteTextureState.diagnostics,
        ],
        terrainEditingController: terrainEditingController,
        mapLayerController: mapLayerController,
        objectEditingController: objectEditingController,
        objectPaletteController: objectPaletteController,
        placementCatalogController: placementCatalogController,
        terrainTileTextureState: terrainTileTextureState,
        objectSpriteTextureState: objectSpriteTextureState,
      );
    }

    final l10n = context.l10n;
    return ColoredBox(
      key: const Key('map-workspace'),
      color: const Color(0xFF101319),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: Color(0xFF5E7193),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.startTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFA3ADBF),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('open-map-button'),
                    onPressed: openMap,
                    icon: const Icon(Icons.folder_open),
                    label: Text(l10n.toolbarOpenMap),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.startShortcutHint,
                    style: const TextStyle(
                      color: Color(0xFF7F8BA0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        l10n.recentMaps,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (recentProjectsLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    )
                  else if (recentProjectsError)
                    _RecentProjectsMessage(
                      icon: Icons.warning_amber_rounded,
                      message: l10n.recentMapsLoadFailed,
                    )
                  else if (recentProjects.isEmpty)
                    _RecentProjectsMessage(
                      icon: Icons.history,
                      message: l10n.recentMapsEmpty,
                    )
                  else
                    for (final project in recentProjects)
                      _RecentProjectTile(
                        project: project,
                        onOpen: onOpenRecentProject == null
                            ? null
                            : () => onOpenRecentProject!(project),
                        onRemove: () => onRemoveRecentProject(project),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenedMapWorkspace extends StatelessWidget {
  const _OpenedMapWorkspace({
    this.onEditTerrain,
    required this.session,
    required this.diagnostics,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.selectionNavigation,
    this.navigationTarget,
    this.selectionInteractionRevision = 0,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.placementCatalogController,
    required this.terrainTileTextureState,
    required this.objectSpriteTextureState,
  });

  final VoidCallback? onEditTerrain;
  final OpenedMapSession session;
  final List<EditorDiagnostic> diagnostics;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final SelectionNavigationController selectionNavigation;
  final MapNavigationTarget? navigationTarget;
  final int selectionInteractionRevision;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final PlacementCatalogController placementCatalogController;
  final TerrainTileTextureState terrainTileTextureState;
  final ObjectSpriteTextureState objectSpriteTextureState;

  @override
  Widget build(BuildContext context) {
    final metadataViews = session.metadataViews;
    final dimensions = metadataViews.dimensions.length == 1
        ? metadataViews.dimensions.single
        : null;
    final tileset = metadataViews.tilesets.length == 1
        ? metadataViews.tilesets.single
        : null;
    final terrain = session.terrainViews.tileMaps.length == 1
        ? session.terrainViews.tileMaps.single
        : null;
    final rawTileValues =
        dimensions != null &&
            terrain != null &&
            terrain.hasGridDimensions &&
            terrain.width == dimensions.width &&
            terrain.height == dimensions.height
        ? terrain.rawTileValues
        : null;
    final layerState = mapLayerController.state;
    final layerScene = mapLayerController.sceneFor(session);
    final paletteState = objectPaletteController.state;
    final terrainLayer = layerState.statusOf(MapLayerType.terrain);
    final editingState = terrainEditingController.state;
    final canSelectTiles =
        terrainEditingController.canSelectTiles && terrainLayer.isSelectable;
    final canEditTerrain =
        terrainEditingController.canEditTerrain &&
        terrainLayer.isSelectable &&
        layerState.activeLayer == MapLayerType.terrain;
    final selectedLayerObject = layerState.selection;
    final selectedTerrainTile =
        selectedLayerObject?.object.layer == MapLayerType.terrain
        ? TerrainTileCoordinate(
            x: selectedLayerObject!.pixelX ~/ 32,
            y: selectedLayerObject.pixelY ~/ 32,
          )
        : layerState.activeLayer == MapLayerType.terrain
        ? editingState.selectedTile
        : null;
    final warningCount = diagnostics
        .where(
          (diagnostic) => diagnostic.severity == DiagnosticSeverity.warning,
        )
        .length;
    final blockingCount = diagnostics
        .where((diagnostic) => diagnostic.blocksOperation)
        .length;
    final l10n = context.l10n;

    return ColoredBox(
      key: const Key('map-workspace'),
      color: const Color(0xFF101319),
      child: LayoutBuilder(
        builder: (context, workspaceConstraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // On short windows the header scrolls instead of pushing the canvas
            // out of view.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: workspaceConstraints.maxHeight * 0.55,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  color: const Color(0xFF171C24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: Color(0xFF70A1FF),
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Tooltip(
                              message: session.sourcePath ?? l10n.untitledMap,
                              child: Text(
                                _sessionName(l10n, session),
                                key: const Key('opened-map-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _SessionStatusChip(
                            restricted: session.requiresRestrictedEditing,
                            // Editability is a property of the map session, not of
                            // the active layer: selecting Units must not make the
                            // chip claim the map is read-only.
                            editable: terrainEditingController.canEditTerrain,
                            dirty: session.isDirty,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _MapCanvasMetadata(
                            key: const Key('map-canvas-size'),
                            icon: Icons.aspect_ratio_rounded,
                            value: dimensions == null
                                ? l10n.mapSizeUnavailable
                                : '${dimensions.width} × ${dimensions.height}',
                          ),
                          _MapCanvasMetadata(
                            icon: Icons.landscape_outlined,
                            value: tileset == null
                                ? l10n.mapTilesetUnavailable
                                : tileset.knownTileset == null
                                ? l10n.mapTilesetRaw('${tileset.rawValue}')
                                : _humanizeEnumName(tileset.knownTileset!.name),
                          ),
                          _MapCanvasMetadata(
                            icon: rawTileValues == null
                                ? Icons.border_all_rounded
                                : Icons.texture_rounded,
                            value: rawTileValues == null
                                ? l10n.mapGeometryPreview
                                : l10n.mapMtxmTiles(rawTileValues.length),
                          ),
                          _MapCanvasMetadata(
                            key: const Key('map-canvas-navigation-help'),
                            icon: Icons.pan_tool_alt_rounded,
                            value: l10n.mapNavigationHelp,
                          ),
                          _MapCanvasMetadata(
                            key: const Key('map-layer-selection-priority'),
                            icon: Icons.layers_rounded,
                            value: l10n.mapPickPriority(
                              layerState.selectionPriority
                                  .map((layer) => layer.localizedLabel(l10n))
                                  .join(' → '),
                            ),
                          ),
                          if (paletteState.selectedEntry case final entry?)
                            _MapCanvasMetadata(
                              key: const Key('object-placement-active'),
                              icon: Icons.add_location_alt_outlined,
                              value: l10n.mapPlacing(entry.label),
                              highlighted: true,
                            ),
                          if (placementCatalogController.state.selection
                              case final selection?
                              when selection.usesCanvasClick)
                            _MapCanvasMetadata(
                              key: const Key('catalog-placement-active'),
                              icon: Icons.add_location_alt_outlined,
                              value: l10n.mapPlacing(selection.displayName),
                              highlighted: true,
                            ),
                          if (objectEditingController.state.isCreatingLocation)
                            _MapCanvasMetadata(
                              key: const Key('location-creation-active'),
                              icon: Icons.crop_free_rounded,
                              value: l10n.mapCreatingLocation,
                              highlighted: true,
                            ),
                          if (blockingCount > 0 || warningCount > 0)
                            _MapCanvasMetadata(
                              icon: Icons.report_problem_outlined,
                              value: l10n.mapProblemCounts(
                                blockingCount,
                                warningCount,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      if (placementCatalogController
                              .state
                              .lastPlacementIssueCode
                          case final code?)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Text(
                              '${placementFailureText(l10n, code)}\n$code',
                              key: const Key('catalog-placement-error'),
                              style: const TextStyle(color: Color(0xFFFFB4AB)),
                            ),
                          ),
                        ),
                      if (layerState.activeLayer == MapLayerType.terrain &&
                          onEditTerrain != null)
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('terrain-natural-editor'),
                              onPressed: onEditTerrain,
                              icon: const Icon(Icons.landscape_outlined),
                              label: Text(l10n.terrainModeNatural),
                            ),
                            OutlinedButton.icon(
                              key: const Key('terrain-tile-editor'),
                              onPressed: () async {
                                await placementCatalogController.load(
                                  StarCraftPlacementKind.tile,
                                );
                                if (context.mounted) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (dialogContext) => Dialog(
                                      child: SizedBox(
                                        width: 1000,
                                        height: 680,
                                        child: PlacementCatalogPane(
                                          controller:
                                              placementCatalogController,
                                          onPlacementConfirmed: () =>
                                              Navigator.pop(dialogContext),
                                          onClose: () =>
                                              Navigator.pop(dialogContext),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.grid_on),
                              label: Text(l10n.terrainModeTile),
                            ),
                          ],
                        ),
                      if (layerState.activeLayer == MapLayerType.terrain)
                        _TerrainEditingToolbar(
                          state: editingState,
                          unsupportedRawValues:
                              terrainTileTextureState.unsupportedRawValues,
                          canSelectTiles: canSelectTiles,
                          canEditTerrain: canEditTerrain,
                          onToolSelected: terrainEditingController.setTool,
                          onUndo: editingState.canUndo
                              ? terrainEditingController.undo
                              : null,
                          onRedo: editingState.canRedo
                              ? terrainEditingController.redo
                              : null,
                        )
                      else
                        _ObjectEditingToolbar(
                          selectedCount: layerState.selections
                              .where(
                                (selection) =>
                                    selection.object.layer !=
                                    MapLayerType.terrain,
                              )
                              .length,
                          canEdit: objectEditingController.canEditSelection,
                          undoLabel: objectEditingController.undoLabel,
                          redoLabel: objectEditingController.redoLabel,
                          onDelete: objectEditingController.canEditSelection
                              ? () => deleteObjectsWithDoodadReview(
                                  context,
                                  objectEditingController,
                                  placementCatalogController,
                                )
                              : null,
                          onUndo: objectEditingController.canUndo
                              ? objectEditingController.undo
                              : null,
                          onRedo: objectEditingController.canRedo
                              ? objectEditingController.redo
                              : null,
                          showLocationCreation:
                              layerState.activeLayer == MapLayerType.locations,
                          locationCreationActive:
                              objectEditingController.state.isCreatingLocation,
                          canCreateLocation:
                              objectEditingController.canCreateLocation,
                          onToggleLocationCreation: () {
                            if (objectEditingController
                                .state
                                .isCreatingLocation) {
                              objectEditingController.cancelLocationCreation();
                            } else {
                              objectPaletteController.cancelPlacement();
                              placementCatalogController.cancelSelection();
                              terrainEditingController.cancelBrushStroke();
                              terrainEditingController.setTool(
                                TerrainEditingTool.select,
                              );
                              objectEditingController.startLocationCreation();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  dimensions == null ||
                      dimensions.width == 0 ||
                      dimensions.height == 0
                  ? const _MapCanvasUnavailable()
                  : MapCanvas(
                      key: ObjectKey(session.extractedMap),
                      navigationTarget:
                          identical(
                            navigationTarget?.document,
                            session.rawDocument,
                          )
                          ? navigationTarget
                          : null,
                      interactionRevision: selectionInteractionRevision,
                      onOverlapSelectionRequested: (request) async {
                        final hits = mapLayerController
                            .orderedHitsAt(
                              session: session,
                              pixelX: request.coordinate.pixelX,
                              pixelY: request.coordinate.pixelY,
                            )
                            .where(
                              (e) => e.object.layer != MapLayerType.terrain,
                            )
                            .toList();
                        if (hits.isEmpty) return;
                        final labels = {
                          for (final e in selectionNavigation.entries)
                            e.object: objectSearchLabel(e),
                        };
                        final chosen = await showMenu<MapLayerObjectRef>(
                          context: context,
                          semanticLabel: context.l10n.selectionOverlap,
                          position: RelativeRect.fromRect(
                            Rect.fromLTWH(
                              request.globalPosition.dx,
                              request.globalPosition.dy,
                              0,
                              0,
                            ),
                            Offset.zero & MediaQuery.sizeOf(context),
                          ),
                          items: [
                            for (final hit in hits)
                              PopupMenuItem(
                                value: hit.object,
                                child: Text(
                                  labels[hit.object] ?? hit.object.label,
                                ),
                              ),
                          ],
                        );
                        if (chosen != null &&
                            identical(
                              selectionNavigation
                                  .maps
                                  .state
                                  .session
                                  ?.rawDocument,
                              session.rawDocument,
                            ) &&
                            context.mounted) {
                          mapLayerController.selectObject(
                            session: session,
                            object: chosen,
                          );
                        }
                      },
                      mapWidth: dimensions.width,
                      mapHeight: dimensions.height,
                      rawTileValues: terrainLayer.isVisible
                          ? rawTileValues
                          : null,
                      terrainTextureState: terrainTileTextureState,
                      objectSpriteTextureState: objectSpriteTextureState,
                      editingTool: editingState.tool,
                      onEditingToolRequested: (tool) {
                        if (tool != TerrainEditingTool.select &&
                            !terrainLayer.isSelectable) {
                          return;
                        }
                        mapLayerController.setActiveLayer(MapLayerType.terrain);
                        terrainEditingController.setTool(tool);
                      },
                      selectedTile: selectedTerrainTile,
                      onSelectionCleared: mapLayerController.clearSelection,
                      layerScene: layerScene,
                      isObjectPlacementActive:
                          paletteState.isPlacementActive ||
                          placementCatalogController.state.isPlacementActive ||
                          objectEditingController.state.isCreatingLocation,
                      placementGhost: _placementGhostFor(
                        placementCatalogController.state.selection,
                      ),
                      onSelectionRequested:
                          editingState.tool == TerrainEditingTool.select
                          ? (request) {
                              if (placementCatalogController
                                  .state
                                  .isPlacementActive) {
                                placementCatalogController.placeAt(
                                  pixelX: request.coordinate.pixelX,
                                  pixelY: request.coordinate.pixelY,
                                  tileX: request.coordinate.tileX,
                                  tileY: request.coordinate.tileY,
                                );
                                return;
                              }
                              if (paletteState.isPlacementActive) {
                                objectPaletteController.placeSelected(
                                  pixelX: request.coordinate.pixelX,
                                  pixelY: request.coordinate.pixelY,
                                );
                                return;
                              }
                              if (objectEditingController
                                  .state
                                  .isCreatingLocation) {
                                return;
                              }
                              final selection = mapLayerController.selectAt(
                                session: session,
                                pixelX: request.coordinate.pixelX,
                                pixelY: request.coordinate.pixelY,
                                additive: request.additive,
                                cycle: request.cycle,
                              );
                              if (selection?.object.layer ==
                                      MapLayerType.terrain &&
                                  canSelectTiles) {
                                terrainEditingController.selectTileAt(
                                  TerrainTileCoordinate(
                                    x: request.coordinate.tileX,
                                    y: request.coordinate.tileY,
                                  ),
                                );
                              }
                            }
                          : null,
                      onSelectionRegionRequested:
                          editingState.tool == TerrainEditingTool.select &&
                              !placementCatalogController
                                  .state
                                  .isPlacementActive &&
                              !paletteState.isPlacementActive
                          ? (request) {
                              if (objectEditingController
                                  .state
                                  .isCreatingLocation) {
                                objectEditingController.createLocation(
                                  request.region,
                                );
                              } else {
                                mapLayerController.selectRegion(
                                  session: session,
                                  region: request.region,
                                  additive: request.additive,
                                );
                              }
                            }
                          : null,
                      onSelectedObjectsMoved:
                          editingState.tool == TerrainEditingTool.select &&
                              !placementCatalogController
                                  .state
                                  .isPlacementActive &&
                              !paletteState.isPlacementActive &&
                              !objectEditingController
                                  .state
                                  .isCreatingLocation &&
                              objectEditingController.canEditSelection
                          ? (request) => objectEditingController.moveSelection(
                              dx: request.dx,
                              dy: request.dy,
                            )
                          : null,
                      onBrushStroke:
                          canEditTerrain && editingState.hasSelectedTile
                          ? terrainEditingController.paintTiles
                          : null,
                      onBrushStrokeStarted:
                          canEditTerrain && editingState.hasSelectedTile
                          ? terrainEditingController.beginBrushStroke
                          : null,
                      onBrushStrokeEnded:
                          canEditTerrain && editingState.hasSelectedTile
                          ? terrainEditingController.commitBrushStroke
                          : null,
                      onBrushStrokeCancelled:
                          canEditTerrain && editingState.hasSelectedTile
                          ? terrainEditingController.cancelBrushStroke
                          : null,
                      onRectangleFilled:
                          canEditTerrain && editingState.hasSelectedTile
                          ? terrainEditingController.fillRectangle
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The footprint the canvas draws under the cursor for the active catalog
/// selection. A Doodad uses its recipe footprint; a Unit or Sprite is a single
/// tile because its record is one point.
MapCanvasPlacementGhost? _placementGhostFor(PlacementSelection? selection) {
  if (selection == null || !selection.usesCanvasClick) {
    return null;
  }
  final recipe = selection.doodadRecipe;
  if (recipe == null) {
    return const MapCanvasPlacementGhost();
  }
  return MapCanvasPlacementGhost(
    tileWidth: recipe.width,
    tileHeight: recipe.height,
  );
}

class _MapCanvasMetadata extends StatelessWidget {
  const _MapCanvasMetadata({
    required this.icon,
    required this.value,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String value;

  /// Emphasises an instruction the user should act on now, such as an active
  /// placement, instead of passive map information.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF173A4A) : const Color(0xFF202733),
        borderRadius: BorderRadius.circular(highlighted ? 999 : 5),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF3E7A8E)
              : const Color(0xFF313C4F),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: highlighted
                  ? const Color(0xFF8FDCEB)
                  : const Color(0xFF91ACD8),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: highlighted
                      ? const Color(0xFFD6F3F8)
                      : const Color(0xFFC2CAD8),
                  fontSize: 11,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectEditingToolbar extends StatelessWidget {
  const _ObjectEditingToolbar({
    required this.selectedCount,
    required this.canEdit,
    required this.undoLabel,
    required this.redoLabel,
    required this.onDelete,
    required this.onUndo,
    required this.onRedo,
    required this.showLocationCreation,
    required this.locationCreationActive,
    required this.canCreateLocation,
    required this.onToggleLocationCreation,
  });

  final int selectedCount;
  final bool canEdit;
  final String? undoLabel;
  final String? redoLabel;
  final VoidCallback? onDelete;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool showLocationCreation;
  final bool locationCreationActive;
  final bool canCreateLocation;
  final VoidCallback onToggleLocationCreation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      key: const Key('object-editing-toolbar'),
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showLocationCreation)
          _TerrainToolButton(
            key: const Key('object-create-location'),
            label: locationCreationActive
                ? l10n.objectCancelLocation
                : l10n.objectNewLocation,
            icon: locationCreationActive
                ? Icons.close_rounded
                : Icons.crop_free_rounded,
            selected: locationCreationActive,
            enabled: locationCreationActive || canCreateLocation,
            onPressed: onToggleLocationCreation,
          ),
        _TerrainToolButton(
          key: const Key('object-delete'),
          label: l10n.objectDelete,
          icon: Icons.delete_outline_rounded,
          selected: false,
          enabled: onDelete != null,
          onPressed: onDelete,
        ),
        _TerrainToolButton(
          key: const Key('object-undo'),
          label: l10n.objectUndo,
          icon: Icons.undo_rounded,
          selected: false,
          enabled: onUndo != null,
          onPressed: onUndo,
        ),
        _TerrainToolButton(
          key: const Key('object-redo'),
          label: l10n.objectRedo,
          icon: Icons.redo_rounded,
          selected: false,
          enabled: onRedo != null,
          onPressed: onRedo,
        ),
        _MapCanvasMetadata(
          key: const Key('object-selection-count'),
          icon: selectedCount == 0
              ? Icons.info_outline_rounded
              : Icons.select_all_rounded,
          value: selectedCount == 0
              ? l10n.objectSelectHint
              : l10n.objectSelectedMove(selectedCount),
        ),
        _MapCanvasMetadata(
          key: const Key('object-editing-history'),
          icon: canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded,
          value: [
            if (undoLabel != null) l10n.objectUndoAction(undoLabel!),
            if (redoLabel != null) l10n.objectRedoAction(redoLabel!),
            if (undoLabel == null && redoLabel == null) l10n.objectShortcutHint,
          ].join(' · '),
        ),
      ],
    );
  }
}

class _TerrainEditingToolbar extends StatelessWidget {
  const _TerrainEditingToolbar({
    required this.state,
    required this.unsupportedRawValues,
    required this.canSelectTiles,
    required this.canEditTerrain,
    required this.onToolSelected,
    required this.onUndo,
    required this.onRedo,
  });

  final TerrainEditingState state;
  final List<int> unsupportedRawValues;
  final bool canSelectTiles;
  final bool canEditTerrain;
  final ValueChanged<TerrainEditingTool> onToolSelected;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSelectedTile = state.hasSelectedTile;
    final selection = state.selectedTile;
    final selectedRawTileValue = state.selectedRawTileValue;
    final selectedDisplayValue = selectedRawTileValue == null
        ? null
        : TerrainTileDisplayValue.fromRawValue(selectedRawTileValue);
    final selectedIsUnsupported =
        selectedRawTileValue != null &&
        unsupportedRawValues.contains(selectedRawTileValue);
    final selectedLabel = selectedDisplayValue == null
        ? l10n.terrainSelectSource
        : l10n.terrainRawTile(
                '${selectedDisplayValue.rawValue}',
                '${selectedDisplayValue.groupIndex}',
                '${selectedDisplayValue.groupMember}',
              ) +
              (selectedIsUnsupported ? l10n.terrainUnsupportedSuffix : '') +
              (selection == null
                  ? ''
                  : l10n.terrainFromSuffix('${selection.x}', '${selection.y}'));

    return Wrap(
      key: const Key('terrain-editing-toolbar'),
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TerrainToolButton(
          key: const Key('terrain-tool-select'),
          label: l10n.terrainToolSelect,
          icon: Icons.colorize_rounded,
          selected: state.tool == TerrainEditingTool.select,
          enabled: canSelectTiles,
          onPressed: () => onToolSelected(TerrainEditingTool.select),
        ),
        _TerrainToolButton(
          key: const Key('terrain-tool-brush'),
          label: l10n.terrainToolBrush,
          icon: Icons.brush_rounded,
          selected: state.tool == TerrainEditingTool.brush,
          enabled: canEditTerrain && hasSelectedTile,
          onPressed: () => onToolSelected(TerrainEditingTool.brush),
        ),
        _TerrainToolButton(
          key: const Key('terrain-tool-rectangle'),
          label: l10n.terrainToolRectangle,
          icon: Icons.crop_square_rounded,
          selected: state.tool == TerrainEditingTool.rectangle,
          enabled: canEditTerrain && hasSelectedTile,
          onPressed: () => onToolSelected(TerrainEditingTool.rectangle),
        ),
        _TerrainToolButton(
          key: const Key('terrain-undo'),
          label: l10n.objectUndo,
          icon: Icons.undo_rounded,
          selected: false,
          enabled: onUndo != null,
          onPressed: onUndo,
        ),
        _TerrainToolButton(
          key: const Key('terrain-redo'),
          label: l10n.objectRedo,
          icon: Icons.redo_rounded,
          selected: false,
          enabled: onRedo != null,
          onPressed: onRedo,
        ),
        _MapCanvasMetadata(
          key: const Key('terrain-selected-tile'),
          icon: hasSelectedTile
              ? Icons.texture_rounded
              : Icons.info_outline_rounded,
          value: selectedLabel,
        ),
        _MapCanvasMetadata(
          key: const Key('terrain-editing-scope'),
          icon: Icons.shield_outlined,
          value: l10n.terrainScope,
        ),
      ],
    );
  }
}

class _TerrainToolButton extends StatelessWidget {
  const _TerrainToolButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFFE8F0FF)
              : const Color(0xFFB8C4D8),
          backgroundColor: selected ? const Color(0xFF29466F) : null,
          side: BorderSide(
            color: selected ? const Color(0xFF70A1FF) : const Color(0xFF3A465A),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _MapCanvasUnavailable extends StatelessWidget {
  const _MapCanvasUnavailable();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('map-canvas-unavailable'),
      color: const Color(0xFF0C1016),
      child: Center(
        child: _EmptyPaneMessage(
          icon: Icons.grid_off_rounded,
          message: context.l10n.mapCanvasUnavailable,
        ),
      ),
    );
  }
}

class _SessionStatusChip extends StatelessWidget {
  const _SessionStatusChip({
    required this.restricted,
    required this.editable,
    required this.dirty,
  });

  final bool restricted;
  final bool editable;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final color = restricted
        ? const Color(0xFFFFB454)
        : dirty
        ? const Color(0xFFF6C85F)
        : editable
        ? const Color(0xFF68D391)
        : const Color(0xFF91ACD8);
    final l10n = context.l10n;
    return Tooltip(
      message: restricted
          ? l10n.sessionRestrictedHelp
          : dirty
          ? l10n.sessionModifiedHelp
          : editable
          ? l10n.sessionEditableHelp
          : l10n.sessionReadOnlyHelp,
      child: Container(
        key: const Key('opened-map-mode'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          restricted
              ? l10n.sessionRestricted
              : dirty
              ? l10n.sessionModified
              : editable
              ? l10n.sessionEditable
              : l10n.sessionReadOnly,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MapLayersAndPalette extends StatelessWidget {
  const _MapLayersAndPalette({
    required this.session,
    required this.layerController,
    required this.paletteController,
    required this.onShowCatalog,
    required this.onLayerActivated,
  });

  final OpenedMapSession session;
  final MapLayerController layerController;
  final ObjectPaletteController paletteController;
  final VoidCallback onShowCatalog;
  final ValueChanged<MapLayerType> onLayerActivated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _MapLayerList(
            session: session,
            controller: layerController,
            onLayerActivated: onLayerActivated,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: _ObjectPalettePanel(
            controller: paletteController,
            onShowCatalog: onShowCatalog,
          ),
        ),
      ],
    );
  }
}

class _ObjectPalettePanel extends StatelessWidget {
  const _ObjectPalettePanel({
    required this.controller,
    required this.onShowCatalog,
  });

  final ObjectPaletteController controller;
  final VoidCallback onShowCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = controller.state;
    final selectedEntry = state.selectedEntry;
    return Column(
      key: const Key('object-palette-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: Color(0xFF8DB4FF),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l10n.paletteTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('placement-catalog-open'),
                  tooltip: l10n.paletteCatalogTooltip,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: () {
                    controller.cancelPlacement();
                    onShowCatalog();
                  },
                ),
                if (selectedEntry != null)
                  IconButton(
                    key: const Key('object-palette-cancel'),
                    tooltip: l10n.paletteCancelTooltip,
                    onPressed: controller.cancelPlacement,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
          child: SizedBox(
            height: 34,
            child: TextField(
              key: const Key('object-palette-search'),
              onChanged: controller.setQuery,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: l10n.paletteSearchHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
        if (selectedEntry != null)
          Container(
            key: const Key('object-palette-placement-hint'),
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1D3049),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.paletteClickToPlace(selectedEntry.label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFA9C7FF), fontSize: 11),
            ),
          ),
        Expanded(
          child: state.entries.isEmpty
              ? _ObjectPaletteMessage(message: l10n.paletteEmpty)
              : state.visibleEntries.isEmpty
              ? _ObjectPaletteMessage(message: l10n.paletteNoMatch)
              : ListView.builder(
                  key: const Key('object-palette-list'),
                  padding: const EdgeInsets.only(bottom: 6),
                  itemCount: state.visibleEntries.length,
                  itemBuilder: (context, index) {
                    final entry = state.visibleEntries[index];
                    final canSelect = controller.canSelectEntry(entry);
                    final selected = selectedEntry?.id == entry.id;
                    return Material(
                      color: selected
                          ? const Color(0xFF233A59)
                          : Colors.transparent,
                      child: ListTile(
                        key: Key(
                          'object-palette-${entry.layer.name}-${entry.typeId}',
                        ),
                        dense: true,
                        enabled: canSelect,
                        selected: selected,
                        minLeadingWidth: 18,
                        horizontalTitleGap: 6,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        leading: Icon(_iconForLayer(entry.layer), size: 16),
                        title: Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          '×${entry.count}',
                          style: const TextStyle(
                            color: Color(0xFF8994A8),
                            fontSize: 11,
                          ),
                        ),
                        onTap: canSelect
                            ? () => controller.selectEntry(entry)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ObjectPaletteMessage extends StatelessWidget {
  const _ObjectPaletteMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF8994A8), fontSize: 12),
        ),
      ),
    );
  }
}

class _MapLayerList extends StatelessWidget {
  const _MapLayerList({
    required this.session,
    required this.controller,
    required this.onLayerActivated,
  });

  final OpenedMapSession session;
  final MapLayerController controller;
  final ValueChanged<MapLayerType> onLayerActivated;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final scene = controller.sceneFor(session);
    final selections = state.selections;
    final l10n = context.l10n;
    return ListView(
      key: const Key('map-layer-list'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        for (final layer in MapLayerController.paintOrder.reversed)
          _MapLayerRow(
            layer: layer,
            status: state.statusOf(layer),
            objectCount: scene.objectCounts[layer] ?? 0,
            isActive: state.activeLayer == layer,
            onActivate: () => onLayerActivated(layer),
            onVisibilityChanged: (visible) =>
                controller.setVisible(layer, visible),
            onLockChanged: (locked) => controller.setLocked(layer, locked),
          ),
        const Divider(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            selections.isEmpty
                ? l10n.layerSelectionHint
                : selections.length == 1
                ? '${selections.single.object.label} · '
                      '${selections.single.pixelX},${selections.single.pixelY}px'
                : l10n.layerObjectsSelected(selections.length),
            key: const Key('map-layer-selection-summary'),
            style: const TextStyle(color: Color(0xFF9AA5B8), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _MapLayerRow extends StatelessWidget {
  const _MapLayerRow({
    required this.layer,
    required this.status,
    required this.objectCount,
    required this.isActive,
    required this.onActivate,
    required this.onVisibilityChanged,
    required this.onLockChanged,
  });

  final MapLayerType layer;
  final MapLayerStatus status;
  final int objectCount;
  final bool isActive;
  final VoidCallback onActivate;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<bool> onLockChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layerName = layer.localizedLabel(l10n);
    return Material(
      color: isActive ? const Color(0xFF23304A) : Colors.transparent,
      child: InkWell(
        key: Key('map-layer-${layer.name}'),
        onTap: onActivate,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(
                _iconForLayer(layer),
                size: 17,
                color: isActive
                    ? const Color(0xFF8DB4FF)
                    : const Color(0xFF8490A5),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layerName,
                      style: TextStyle(
                        color: status.isVisible
                            ? const Color(0xFFD8DEE9)
                            : const Color(0xFF707A8E),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      l10n.layerItems(objectCount),
                      style: const TextStyle(
                        color: Color(0xFF8994A8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _MapLayerToggle(
                key: Key('map-layer-${layer.name}-visible'),
                tooltip: status.isVisible
                    ? l10n.layerHide(layerName)
                    : l10n.layerShow(layerName),
                icon: status.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                isActive: status.isVisible,
                onPressed: () => onVisibilityChanged(!status.isVisible),
              ),
              _MapLayerToggle(
                key: Key('map-layer-${layer.name}-locked'),
                tooltip: status.isLocked
                    ? l10n.layerUnlock(layerName)
                    : l10n.layerLock(layerName),
                icon: status.isLocked
                    ? Icons.lock_outline_rounded
                    : Icons.lock_open_rounded,
                isActive: status.isLocked,
                onPressed: () => onLockChanged(!status.isLocked),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLayerToggle extends StatelessWidget {
  const _MapLayerToggle({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 15,
      color: isActive ? const Color(0xFFAFC7F5) : const Color(0xFF68758A),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

IconData _iconForLayer(MapLayerType layer) => switch (layer) {
  MapLayerType.terrain => Icons.grid_4x4_rounded,
  MapLayerType.locations => Icons.crop_free_rounded,
  MapLayerType.doodads => Icons.park_outlined,
  MapLayerType.sprites => Icons.auto_awesome_outlined,
  MapLayerType.units => Icons.adjust_rounded,
};

class _MapInspector extends StatelessWidget {
  const _MapInspector({
    required this.session,
    required this.mapLayerController,
    required this.objectEditingController,
  });

  final OpenedMapSession session;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;

  @override
  Widget build(BuildContext context) {
    final selections = mapLayerController.state.selections
        .where((selection) => selection.object.layer != MapLayerType.terrain)
        .toList(growable: false);
    if (selections.length > 1) {
      return _MultiObjectInspector(selections: selections);
    }
    final properties = objectEditingController.selectedProperties;
    if (properties != null) {
      return _ObjectPropertiesInspector(
        properties: properties,
        controller: objectEditingController,
      );
    }
    return _MapDocumentInspector(session: session);
  }
}

class _MapDocumentInspector extends StatelessWidget {
  const _MapDocumentInspector({required this.session});

  final OpenedMapSession session;

  @override
  Widget build(BuildContext context) {
    final archive = session.archiveMetadata;
    final metadata = session.metadataViews;
    final dimensions = metadata.dimensions.length == 1
        ? metadata.dimensions.single
        : null;
    final version = metadata.versions.length == 1
        ? metadata.versions.single
        : null;
    final scenarioType = metadata.types.length == 1
        ? metadata.types.single
        : null;
    final tileset = metadata.tilesets.length == 1
        ? metadata.tilesets.single
        : null;
    final terrain = session.terrainViews.tileMaps.length == 1
        ? session.terrainViews.tileMaps.single
        : null;
    final l10n = context.l10n;
    return ListView(
      key: const Key('map-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _InspectorValue(
          label: l10n.inspectorFile,
          value: _sessionName(l10n, session),
        ),
        _InspectorValue(
          label: l10n.inspectorSourcePath,
          value: session.sourcePath ?? l10n.notSavedYet,
        ),
        _InspectorValue(
          label: l10n.inspectorMapSize,
          value: dimensions == null
              ? l10n.valueUnavailable
              : '${dimensions.width} × ${dimensions.height}',
        ),
        _InspectorValue(
          label: l10n.inspectorTileset,
          value: tileset == null
              ? l10n.valueUnavailable
              : tileset.knownTileset == null
              ? l10n.valueUnknown('${tileset.rawValue}')
              : _humanizeEnumName(tileset.knownTileset!.name),
        ),
        _InspectorValue(
          label: l10n.inspectorMapVersion,
          value: version == null
              ? l10n.valueUnavailable
              : version.knownVersion == null
              ? l10n.valueUnknown('${version.rawValue}')
              : '${_humanizeEnumName(version.knownVersion!.name)} '
                    '(${version.rawValue})',
        ),
        _InspectorValue(
          label: l10n.inspectorScenarioType,
          value: scenarioType?.fourCharacterCode ?? l10n.valueUnavailable,
        ),
        _InspectorValue(
          label: l10n.inspectorTerrain,
          value: terrain == null
              ? l10n.inspectorMtxmViews(session.terrainViews.tileMaps.length)
              : l10n.inspectorRawTiles(terrain.tileCount),
        ),
        _InspectorValue(
          label: l10n.inspectorArchiveSize,
          value: _formatBytes(archive.archiveSizeBytes),
        ),
        _InspectorValue(
          label: l10n.inspectorEntries,
          value: l10n.inspectorEntriesListed(
            archive.entries.length,
            archive.totalEntryCount,
          ),
        ),
        _InspectorValue(
          label: l10n.inspectorChkSize,
          value: _formatBytes(session.scenarioChkSizeBytes),
        ),
        _InspectorValue(
          label: l10n.inspectorChkSections,
          value: '${session.rawDocument.sections.length}',
        ),
        _InspectorValue(
          label: l10n.inspectorDiagnostics,
          value: '${session.diagnostics.length}',
        ),
        TerrainDataPanel(report: session.editorTerrain),
      ],
    );
  }
}

class _MultiObjectInspector extends StatelessWidget {
  const _MultiObjectInspector({required this.selections});

  final List<MapLayerSelection> selections;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layers = {
      for (final selection in selections)
        selection.object.layer.localizedLabel(l10n),
    }.join(', ');
    return ListView(
      key: const Key('multi-object-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        const Icon(
          Icons.select_all_rounded,
          size: 28,
          color: Color(0xFF8DB4FF),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.layerObjectsSelected(selections.length),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _InspectorValue(label: l10n.inspectorCommonLayers, value: layers),
        _InspectorNotice(
          icon: Icons.info_outline_rounded,
          message: l10n.inspectorMultiNotice,
        ),
      ],
    );
  }
}

class _ObjectPropertiesInspector extends StatefulWidget {
  const _ObjectPropertiesInspector({
    required this.properties,
    required this.controller,
  });

  final ObjectProperties properties;
  final ObjectEditingController controller;

  @override
  State<_ObjectPropertiesInspector> createState() =>
      _ObjectPropertiesInspectorState();
}

class _ObjectPropertiesInspectorState
    extends State<_ObjectPropertiesInspector> {
  final Map<String, TextEditingController> _fields = {};
  Map<String, String> _errors = const {};
  String? _message;
  late String _propertiesSignature;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void didUpdateWidget(_ObjectPropertiesInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signatureOf(widget.properties);
    if (signature != _propertiesSignature) {
      _loadProperties();
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadProperties() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _fields
      ..clear()
      ..addAll({
        for (final entry in _editableValues(widget.properties).entries)
          entry.key: TextEditingController(text: '${entry.value}'),
      });
    _propertiesSignature = _signatureOf(widget.properties);
    _errors = const {};
    _message = null;
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.properties;
    if (properties is LocationObjectProperties) {
      return _LocationPropertiesInspector(
        properties: properties,
        controller: widget.controller,
      );
    }
    final canEdit = widget.controller.canEditProperties;
    final l10n = context.l10n;
    return ListView(
      key: const Key('object-properties-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Icon(
              _iconForLayer(properties.object.layer),
              size: 20,
              color: const Color(0xFF8DB4FF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_objectKind(l10n, properties)} '
                '#${properties.object.recordIndex}',
                key: const Key('object-inspector-title'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _integerField(ObjectPropertyFields.typeId, l10n.fieldTypeId, canEdit),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.objectPlacedOnlyNotice,
            style: const TextStyle(color: Color(0xFF9EABC0), fontSize: 11),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _integerField(
                ObjectPropertyFields.x,
                l10n.fieldX,
                canEdit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _integerField(
                ObjectPropertyFields.y,
                l10n.fieldY,
                canEdit,
              ),
            ),
          ],
        ),
        _integerField(ObjectPropertyFields.owner, l10n.fieldOwnerRaw, canEdit),
        if (properties is UnitObjectProperties) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.hitpointPercent,
                  l10n.fieldHitpointPercent,
                  canEdit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.shieldPercent,
                  l10n.fieldShieldPercent,
                  canEdit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.energyPercent,
                  l10n.fieldEnergyPercent,
                  canEdit,
                ),
              ),
            ],
          ),
          _integerField(
            ObjectPropertyFields.resourceAmount,
            l10n.fieldResourceAmount,
            canEdit,
          ),
          _integerField(
            ObjectPropertyFields.hangarAmount,
            l10n.fieldHangarAmount,
            canEdit,
          ),
        ],
        if (properties is DoodadObjectProperties)
          _integerField(
            ObjectPropertyFields.enabledValue,
            l10n.fieldDoodadEnabledRaw,
            canEdit,
          ),
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const Key('object-inspector-apply'),
          onPressed: canEdit ? _apply : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text(l10n.applyProperties),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('object-inspector-message'),
            style: const TextStyle(color: Color(0xFFAFC7F5), fontSize: 12),
          ),
        ],
        if (!canEdit) ...[
          const SizedBox(height: 8),
          _InspectorNotice(
            icon: Icons.lock_outline_rounded,
            message: l10n.unlockToApply,
          ),
        ],
        const Divider(height: 24),
        // Raw bytes are rarely needed while placing objects, so they start
        // collapsed under an explicit "Advanced" heading.
        Material(
          type: MaterialType.transparency,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const Key('object-inspector-raw-fields'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(
                l10n.rawFieldsTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                ..._rawValues(l10n, properties),
                _InspectorNotice(
                  icon: Icons.shield_outlined,
                  message: l10n.rawFieldsNotice,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _integerField(String field, String label, bool enabled) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        key: Key('object-inspector-$field'),
        controller: _fields[field],
        enabled: enabled,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          errorText: _errors[field],
          errorMaxLines: 3,
          isDense: true,
        ),
      ),
    );
  }

  void _apply() {
    final l10n = context.l10n;
    final parseErrors = <String, String>{};
    final values = <String, int>{};
    for (final entry in _fields.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value == null) {
        parseErrors[entry.key] = l10n.enterWholeNumber;
      } else {
        values[entry.key] = value;
      }
    }
    if (parseErrors.isNotEmpty) {
      setState(() {
        _errors = parseErrors;
        _message = null;
      });
      return;
    }
    final properties = widget.properties;
    final update = switch (properties) {
      UnitObjectProperties() => UnitObjectPropertyUpdate(
        object: properties.object,
        typeId: values[ObjectPropertyFields.typeId]!,
        x: values[ObjectPropertyFields.x]!,
        y: values[ObjectPropertyFields.y]!,
        owner: values[ObjectPropertyFields.owner]!,
        hitpointPercent: values[ObjectPropertyFields.hitpointPercent]!,
        shieldPercent: values[ObjectPropertyFields.shieldPercent]!,
        energyPercent: values[ObjectPropertyFields.energyPercent]!,
        resourceAmount: values[ObjectPropertyFields.resourceAmount]!,
        hangarAmount: values[ObjectPropertyFields.hangarAmount]!,
      ),
      DoodadObjectProperties() => DoodadObjectPropertyUpdate(
        object: properties.object,
        typeId: values[ObjectPropertyFields.typeId]!,
        x: values[ObjectPropertyFields.x]!,
        y: values[ObjectPropertyFields.y]!,
        owner: values[ObjectPropertyFields.owner]!,
        enabledValue: values[ObjectPropertyFields.enabledValue]!,
      ),
      SpriteObjectProperties() => SpriteObjectPropertyUpdate(
        object: properties.object,
        typeId: values[ObjectPropertyFields.typeId]!,
        x: values[ObjectPropertyFields.x]!,
        y: values[ObjectPropertyFields.y]!,
        owner: values[ObjectPropertyFields.owner]!,
      ),
      LocationObjectProperties() => throw StateError(
        'Locations are read-only in this inspector.',
      ),
    };
    final result = widget.controller.updateProperties(update);
    setState(() {
      _errors = result.errors;
      _message = switch (result.status) {
        ObjectPropertyEditStatus.applied => l10n.propertiesApplied,
        ObjectPropertyEditStatus.noChanges => l10n.propertiesNoChanges,
        ObjectPropertyEditStatus.invalid => l10n.fixHighlightedFields,
        ObjectPropertyEditStatus.unavailable => l10n.propertiesUnavailable,
      };
    });
  }
}

class _LocationPropertiesInspector extends StatefulWidget {
  const _LocationPropertiesInspector({
    required this.properties,
    required this.controller,
  });

  final LocationObjectProperties properties;
  final ObjectEditingController controller;

  @override
  State<_LocationPropertiesInspector> createState() =>
      _LocationPropertiesInspectorState();
}

class _LocationPropertiesInspectorState
    extends State<_LocationPropertiesInspector> {
  late TextEditingController _nameController;
  final Map<String, TextEditingController> _bounds = {};
  Map<String, String> _errors = const {};
  String? _message;
  late String _signature;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_LocationPropertiesInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_locationSignature(widget.properties) != _signature) {
      _disposeControllers();
      _load();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _load() {
    final properties = widget.properties;
    _nameController = TextEditingController(text: properties.name);
    _bounds
      ..clear()
      ..addAll({
        ObjectPropertyFields.left: TextEditingController(
          text: '${properties.left}',
        ),
        ObjectPropertyFields.top: TextEditingController(
          text: '${properties.top}',
        ),
        ObjectPropertyFields.right: TextEditingController(
          text: '${properties.right}',
        ),
        ObjectPropertyFields.bottom: TextEditingController(
          text: '${properties.bottom}',
        ),
      });
    _signature = _locationSignature(properties);
    _errors = const {};
    _message = null;
  }

  void _disposeControllers() {
    _nameController.dispose();
    for (final controller in _bounds.values) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final properties = widget.properties;
    final canEdit = widget.controller.canEditProperties;
    final l10n = context.l10n;
    return ListView(
      key: const Key('location-properties-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          l10n.locationTitle('${properties.locationId}'),
          key: const Key('object-inspector-title'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('location-inspector-name'),
          controller: _nameController,
          enabled: canEdit && properties.canRename,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: l10n.fieldName,
            errorText: _errors[ObjectPropertyFields.name],
            isDense: true,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _boundField(ObjectPropertyFields.left, l10n.fieldLeft),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _boundField(ObjectPropertyFields.top, l10n.fieldTop),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _boundField(ObjectPropertyFields.right, l10n.fieldRight),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _boundField(ObjectPropertyFields.bottom, l10n.fieldBottom),
            ),
          ],
        ),
        FilledButton.icon(
          key: const Key('location-inspector-apply'),
          onPressed: canEdit ? _apply : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text(l10n.applyLocation),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('location-inspector-message'),
            style: const TextStyle(color: Color(0xFFAFC7F5), fontSize: 12),
          ),
        ],
        const Divider(height: 24),
        _InspectorValue(
          label: l10n.inspectorStringId,
          value: '${properties.stringId}',
        ),
        _InspectorValue(
          label: l10n.inspectorElevationFlags,
          value: _hex(properties.elevationFlags, 4),
        ),
        if (!properties.canRename)
          _InspectorNotice(
            icon: Icons.info_outline_rounded,
            message:
                properties.renameUnavailableReason ??
                l10n.locationNamingUnavailable,
          )
        else
          _InspectorNotice(
            icon: Icons.shield_outlined,
            message: l10n.locationRenameNotice,
          ),
      ],
    );
  }

  Widget _boundField(String field, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        key: Key('location-inspector-$field'),
        controller: _bounds[field],
        enabled: widget.controller.canEditProperties,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          errorText: _errors[field],
          errorMaxLines: 3,
          isDense: true,
        ),
      ),
    );
  }

  void _apply() {
    final l10n = context.l10n;
    final values = <String, int>{};
    final parseErrors = <String, String>{};
    for (final entry in _bounds.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value == null) {
        parseErrors[entry.key] = l10n.enterWholeNumber;
      } else {
        values[entry.key] = value;
      }
    }
    if (parseErrors.isNotEmpty) {
      setState(() {
        _errors = parseErrors;
        _message = null;
      });
      return;
    }
    final result = widget.controller.updateProperties(
      LocationObjectPropertyUpdate(
        object: widget.properties.object,
        left: values[ObjectPropertyFields.left]!,
        top: values[ObjectPropertyFields.top]!,
        right: values[ObjectPropertyFields.right]!,
        bottom: values[ObjectPropertyFields.bottom]!,
        name: _nameController.text,
      ),
    );
    setState(() {
      _errors = result.errors;
      _message = switch (result.status) {
        ObjectPropertyEditStatus.applied => l10n.locationApplied,
        ObjectPropertyEditStatus.noChanges => l10n.locationNoChanges,
        ObjectPropertyEditStatus.invalid => l10n.fixHighlightedFields,
        ObjectPropertyEditStatus.unavailable => l10n.locationUnavailable,
      };
    });
  }
}

String _locationSignature(LocationObjectProperties properties) =>
    '${properties.object.sectionIndex}:${properties.object.recordIndex}:'
    '${properties.left},${properties.top},${properties.right},'
    '${properties.bottom},${properties.stringId},${properties.elevationFlags}:'
    '${properties.name}:${properties.canRename}';

class _InspectorNotice extends StatelessWidget {
  const _InspectorNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2330),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF303C50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF8DA2C2)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFA9B5C8), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, int> _editableValues(ObjectProperties properties) =>
    switch (properties) {
      UnitObjectProperties() => {
        ObjectPropertyFields.typeId: properties.typeId,
        ObjectPropertyFields.x: properties.x,
        ObjectPropertyFields.y: properties.y,
        ObjectPropertyFields.owner: properties.owner,
        ObjectPropertyFields.hitpointPercent: properties.hitpointPercent,
        ObjectPropertyFields.shieldPercent: properties.shieldPercent,
        ObjectPropertyFields.energyPercent: properties.energyPercent,
        ObjectPropertyFields.resourceAmount: properties.resourceAmount,
        ObjectPropertyFields.hangarAmount: properties.hangarAmount,
      },
      DoodadObjectProperties() => {
        ObjectPropertyFields.typeId: properties.typeId,
        ObjectPropertyFields.x: properties.x,
        ObjectPropertyFields.y: properties.y,
        ObjectPropertyFields.owner: properties.owner,
        ObjectPropertyFields.enabledValue: properties.enabledValue,
      },
      SpriteObjectProperties() => {
        ObjectPropertyFields.typeId: properties.typeId,
        ObjectPropertyFields.x: properties.x,
        ObjectPropertyFields.y: properties.y,
        ObjectPropertyFields.owner: properties.owner,
      },
      LocationObjectProperties() => const {},
    };

String _signatureOf(ObjectProperties properties) =>
    '${properties.object.layer.name}:${properties.object.sectionIndex}:'
    '${properties.object.recordIndex}:${_editableValues(properties).values.join(',')}:'
    '${_rawSignature(properties)}';

String _rawSignature(ObjectProperties properties) => switch (properties) {
  UnitObjectProperties() =>
    '${properties.classId},${properties.relationFlags},'
        '${properties.validStateFlags},${properties.validFieldFlags},'
        '${properties.stateFlags},${properties.unused},'
        '${properties.relationClassId}',
  DoodadObjectProperties() => '',
  SpriteObjectProperties() => '${properties.unused},${properties.flags}',
  LocationObjectProperties() =>
    '${properties.locationId},${properties.left},${properties.top},'
        '${properties.right},${properties.bottom},${properties.stringId},'
        '${properties.elevationFlags}',
};

String _objectKind(AppLocalizations l10n, ObjectProperties properties) =>
    switch (properties) {
      UnitObjectProperties() => l10n.objectKindUnit,
      DoodadObjectProperties() => l10n.objectKindDoodad,
      SpriteObjectProperties() => l10n.objectKindSprite,
      LocationObjectProperties() => l10n.objectKindLocation,
    };

List<Widget> _rawValues(
  AppLocalizations l10n,
  ObjectProperties properties,
) => switch (properties) {
  UnitObjectProperties() => [
    _InspectorValue(label: l10n.rawClassId, value: _hex(properties.classId, 8)),
    _InspectorValue(
      label: l10n.rawRelationFlags,
      value: _hex(properties.relationFlags, 4),
    ),
    _InspectorValue(
      label: l10n.rawValidStateFlags,
      value: _hex(properties.validStateFlags, 4),
    ),
    _InspectorValue(
      label: l10n.rawValidFieldFlags,
      value: _hex(properties.validFieldFlags, 4),
    ),
    _InspectorValue(
      label: l10n.rawStateFlags,
      value: _hex(properties.stateFlags, 4),
    ),
    _InspectorValue(label: l10n.rawUnused, value: _hex(properties.unused, 8)),
    _InspectorValue(
      label: l10n.rawRelationClassId,
      value: _hex(properties.relationClassId, 8),
    ),
  ],
  DoodadObjectProperties() => const [],
  SpriteObjectProperties() => [
    _InspectorValue(label: l10n.rawUnused, value: _hex(properties.unused, 2)),
    _InspectorValue(label: l10n.rawFlags, value: _hex(properties.flags, 4)),
  ],
  LocationObjectProperties() => const [],
};

String _hex(int value, int width) =>
    '0x${value.toRadixString(16).toUpperCase().padLeft(width, '0')}';

class _InspectorValue extends StatelessWidget {
  const _InspectorValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9AA5B8), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RecentProjectTile extends StatelessWidget {
  const _RecentProjectTile({
    required this.project,
    required this.onOpen,
    required this.onRemove,
  });

  final RecentProject project;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final fileName = project.path.replaceAll('\\', '/').split('/').last;
    final openedAt = project.lastOpenedAt;
    final openedLabel =
        '${openedAt.year.toString().padLeft(4, '0')}-'
        '${openedAt.month.toString().padLeft(2, '0')}-'
        '${openedAt.day.toString().padLeft(2, '0')} '
        '${openedAt.hour.toString().padLeft(2, '0')}:'
        '${openedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: ValueKey('recent-project-${project.path}'),
        dense: true,
        enabled: onOpen != null,
        onTap: onOpen,
        leading: const Icon(Icons.map_outlined),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${project.path}\n$openedLabel',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          key: ValueKey('remove-recent-project-${project.path}'),
          tooltip: context.l10n.recentMapsRemove,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    );
  }
}

class _RecentProjectsMessage extends StatelessWidget {
  const _RecentProjectsMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF657086)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8994A8), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OutputPanelTab { problems, output, buildLog }

class _OutputPanel extends StatefulWidget {
  const _OutputPanel({
    required this.progress,
    required this.diagnostics,
    required this.eudBuildState,
  });

  final OperationProgress? progress;
  final List<EditorDiagnostic> diagnostics;
  final EudBuildState eudBuildState;

  @override
  State<_OutputPanel> createState() => _OutputPanelState();
}

class _OutputPanelState extends State<_OutputPanel> {
  late _OutputPanelTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab =
        widget.eudBuildState.isActive || widget.eudBuildState.events.isNotEmpty
        ? _OutputPanelTab.buildLog
        : widget.progress != null && !widget.progress!.isTerminal
        ? _OutputPanelTab.output
        : _OutputPanelTab.problems;
  }

  @override
  void didUpdateWidget(_OutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final buildStarted =
        !oldWidget.eudBuildState.isActive && widget.eudBuildState.isActive;
    final firstBuildEvent =
        oldWidget.eudBuildState.events.isEmpty &&
        widget.eudBuildState.events.isNotEmpty;
    if (buildStarted || firstBuildEvent) {
      _selectedTab = _OutputPanelTab.buildLog;
      return;
    }
    final operationStarted =
        (oldWidget.progress == null || oldWidget.progress!.isTerminal) &&
        widget.progress != null &&
        !widget.progress!.isTerminal;
    if (operationStarted) {
      _selectedTab = _OutputPanelTab.output;
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = [
      ...widget.diagnostics,
      ...widget.eudBuildState.diagnostics,
    ];
    final l10n = context.l10n;
    final errorCount = diagnostics
        .where(
          (diagnostic) =>
              diagnostic.severity == DiagnosticSeverity.error ||
              diagnostic.severity == DiagnosticSeverity.fatal,
        )
        .length;
    final warningCount = diagnostics
        .where(
          (diagnostic) => diagnostic.severity == DiagnosticSeverity.warning,
        )
        .length;
    final infoCount = diagnostics.length - errorCount - warningCount;
    return SizedBox(
      height: 150,
      child: ColoredBox(
        color: const Color(0xFF151A22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _OutputPanelTabButton(
                      key: const Key('output-tab-problems'),
                      label: l10n.tabProblems,
                      selected: _selectedTab == _OutputPanelTab.problems,
                      count: diagnostics.length,
                      onPressed: () {
                        setState(() {
                          _selectedTab = _OutputPanelTab.problems;
                        });
                      },
                    ),
                    _OutputPanelTabButton(
                      key: const Key('output-tab-output'),
                      label: l10n.tabOutput,
                      selected: _selectedTab == _OutputPanelTab.output,
                      onPressed: () {
                        setState(() {
                          _selectedTab = _OutputPanelTab.output;
                        });
                      },
                    ),
                    _OutputPanelTabButton(
                      key: const Key('output-tab-build-log'),
                      label: l10n.tabBuildLog,
                      selected: _selectedTab == _OutputPanelTab.buildLog,
                      count:
                          widget.eudBuildState.latestRecord?.logEntries.length,
                      onPressed: () {
                        setState(() {
                          _selectedTab = _OutputPanelTab.buildLog;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: diagnostics.isEmpty
                            ? const SizedBox.shrink()
                            : _ProblemSummary(
                                key: const Key('problems-summary'),
                                errors: errorCount,
                                warnings: warningCount,
                                infos: infoCount,
                                label: l10n.problemsSummary(
                                  errorCount,
                                  warningCount,
                                  infoCount,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedTab = _OutputPanelTab.problems;
                                  });
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_selectedTab) {
                _OutputPanelTab.problems =>
                  diagnostics.isEmpty
                      ? _OutputPanelMessage(l10n.noProblems)
                      : _DiagnosticList(diagnostics: diagnostics),
                _OutputPanelTab.output =>
                  widget.progress == null
                      ? _OutputPanelMessage(l10n.noOutput)
                      : _OperationSummary(progress: widget.progress!),
                _OutputPanelTab.buildLog => _EudBuildLog(
                  state: widget.eudBuildState,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputPanelTabButton extends StatelessWidget {
  const _OutputPanelTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.count,
    super.key,
  });

  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? const Color(0xFFE7EDF8)
            : const Color(0xFF8994A8),
        textStyle: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      child: Text(
        count == null || count == 0
            ? label
            : context.l10n.tabWithCount(label, count),
      ),
    );
  }
}

/// Error, warning and info counts at a glance; tapping opens Problems.
class _ProblemSummary extends StatelessWidget {
  const _ProblemSummary({
    required this.errors,
    required this.warnings,
    required this.infos,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final int errors;
  final int warnings;
  final int infos;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final severity = errors > 0
        ? DiagnosticSeverity.error
        : warnings > 0
        ? DiagnosticSeverity.warning
        : DiagnosticSeverity.info;
    final color = _diagnosticColor(severity);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_diagnosticIcon(severity), size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputPanelMessage extends StatelessWidget {
  const _OutputPanelMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Color(0xFF9AA5B8))),
    );
  }
}

class _EudBuildLog extends StatelessWidget {
  const _EudBuildLog({required this.state});

  final EudBuildState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final record = state.latestRecord;
    if (record == null) {
      return _OutputPanelMessage(_emptyMessage(l10n, state.status));
    }
    final items = _buildLogItems(l10n, record);

    // A plain-language result sits beside the raw euddraft log so users see
    // what happened first and can still read every original line.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 340, child: _EudBuildSummary(record: record)),
        const VerticalDivider(width: 1),
        Expanded(child: _rawLog(items)),
      ],
    );
  }

  Widget _rawLog(List<_EudBuildLogItem> items) {
    return ListView.builder(
      key: const Key('eud-build-log'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey('eud-build-log-$index'),
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  item.text,
                  style: TextStyle(
                    color: item.color,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _emptyMessage(AppLocalizations l10n, EudBuildStatus status) {
  return switch (status) {
    EudBuildStatus.notConfigured => l10n.buildNotConfigured,
    EudBuildStatus.ready => l10n.buildReady,
    EudBuildStatus.running => l10n.buildStarting,
    EudBuildStatus.cancelling => l10n.buildStopping,
    EudBuildStatus.finalizing => l10n.buildFinalizing,
    EudBuildStatus.succeeded => l10n.buildCompleted,
    EudBuildStatus.failed => l10n.buildFailedNoOutput,
    EudBuildStatus.cancelled => l10n.buildCancelled,
  };
}

class _EudBuildSummary extends StatelessWidget {
  const _EudBuildSummary({required this.record});

  final EudBuildRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, color, headline) = switch (record.status) {
      EudBuildRecordStatus.running => (
        Icons.pending_outlined,
        const Color(0xFF8EA0BB),
        l10n.buildSummaryRunning,
      ),
      EudBuildRecordStatus.succeeded => (
        Icons.check_circle_outline,
        const Color(0xFF7ADAA5),
        l10n.buildSummarySucceeded,
      ),
      EudBuildRecordStatus.failed => (
        Icons.error_outline,
        const Color(0xFFFF7B86),
        l10n.buildSummaryFailed,
      ),
      EudBuildRecordStatus.cancelled => (
        Icons.stop_circle_outlined,
        const Color(0xFFF0B85A),
        l10n.buildSummaryCancelled,
      ),
    };
    final firstProblem = record.diagnostics
        .where(
          (diagnostic) =>
              diagnostic.severity == DiagnosticSeverity.error ||
              diagnostic.severity == DiagnosticSeverity.fatal,
        )
        .firstOrNull;
    final problemLocation = firstProblem == null
        ? null
        : _diagnosticLocationLabel(firstProblem);
    return SingleChildScrollView(
      key: const Key('eud-build-summary'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (firstProblem != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.buildSummaryFirstError(
                problemLocation == null
                    ? firstProblem.message
                    : l10n.buildSummaryAt(
                        problemLocation,
                        firstProblem.message,
                      ),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
          if (record.status == EudBuildRecordStatus.failed ||
              record.status == EudBuildRecordStatus.cancelled) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: Color(0xFF9FDCB2),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.buildSummaryUnchanged,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9FDCB2),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            l10n.buildSummaryRawLog,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8994A8)),
          ),
        ],
      ),
    );
  }
}

final class _EudBuildLogItem {
  const _EudBuildLogItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;
}

List<_EudBuildLogItem> _buildLogItems(
  AppLocalizations l10n,
  EudBuildRecord record,
) {
  const metadataColor = Color(0xFF8EA0BB);
  const stdoutColor = Color(0xFFAAB5C8);
  const stderrColor = Color(0xFFFFC66D);
  final items = <_EudBuildLogItem>[
    _EudBuildLogItem(
      icon: Icons.tag_rounded,
      color: metadataColor,
      text: l10n.logBuildId(record.buildId),
    ),
    _EudBuildLogItem(
      icon: Icons.construction_rounded,
      color: metadataColor,
      text: l10n.logTool('${record.toolVersion}'),
    ),
    if (record.isTerminal)
      _EudBuildLogItem(
        icon: _buildRecordStatusIcon(record.status),
        color: _buildRecordStatusColor(record.status),
        text:
            '${_buildRecordStatusLabel(l10n, record.status)} • '
            '${record.exitCode == null ? l10n.logExitCodeUnavailable : l10n.logExitCode('${record.exitCode}')}',
      ),
    _EudBuildLogItem(
      icon: Icons.schedule_rounded,
      color: metadataColor,
      text: l10n.logStarted(record.startedAt.toIso8601String()),
    ),
    if (record.isTerminal)
      _EudBuildLogItem(
        icon: Icons.schedule_rounded,
        color: metadataColor,
        text: l10n.logCompleted(record.completedAt!.toIso8601String()),
      ),
    for (final entry in record.logEntries)
      _EudBuildLogItem(
        icon: entry.channel == EudBuildLogChannel.stdout
            ? Icons.chevron_right_rounded
            : Icons.warning_amber_rounded,
        color: entry.channel == EudBuildLogChannel.stdout
            ? stdoutColor
            : stderrColor,
        text: '[${entry.channel.name}] ${entry.text}',
      ),
    for (final diagnostic in record.diagnostics)
      _EudBuildLogItem(
        icon: _diagnosticIcon(diagnostic.severity),
        color: _diagnosticColor(diagnostic.severity),
        text:
            '[${diagnostic.code}] '
            '${_diagnosticLocationPrefix(diagnostic)}${localizedDiagnosticMessage(l10n, diagnostic)}',
      ),
  ];
  return items;
}

String _buildRecordStatusLabel(
  AppLocalizations l10n,
  EudBuildRecordStatus status,
) {
  return switch (status) {
    EudBuildRecordStatus.running => l10n.recordRunning,
    EudBuildRecordStatus.succeeded => l10n.recordSucceeded,
    EudBuildRecordStatus.failed => l10n.recordFailed,
    EudBuildRecordStatus.cancelled => l10n.recordCancelled,
  };
}

IconData _buildRecordStatusIcon(EudBuildRecordStatus status) {
  return switch (status) {
    EudBuildRecordStatus.running => Icons.pending_outlined,
    EudBuildRecordStatus.succeeded => Icons.check_circle_outline,
    EudBuildRecordStatus.failed => Icons.error_outline,
    EudBuildRecordStatus.cancelled => Icons.stop_circle_outlined,
  };
}

Color _buildRecordStatusColor(EudBuildRecordStatus status) {
  return switch (status) {
    EudBuildRecordStatus.running => const Color(0xFF8EA0BB),
    EudBuildRecordStatus.succeeded => const Color(0xFF7ADAA5),
    EudBuildRecordStatus.failed ||
    EudBuildRecordStatus.cancelled => const Color(0xFFFF7B86),
  };
}

class _DiagnosticList extends StatelessWidget {
  const _DiagnosticList({required this.diagnostics});

  final List<EditorDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: diagnostics.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final diagnostic = diagnostics[index];
        final color = _diagnosticColor(diagnostic.severity);
        return Tooltip(
          message: [
            context.diagnosticMessage(diagnostic),
            ?context.diagnosticRemediation(diagnostic),
          ].join('\n'),
          waitDuration: const Duration(milliseconds: 600),
          child: Row(
            key: ValueKey('diagnostic-${diagnostic.code}-$index'),
            children: [
              Icon(
                _diagnosticIcon(diagnostic.severity),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 58,
                child: Text(
                  _diagnosticSeverityLabel(l10n, diagnostic.severity),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  context.diagnosticMessage(diagnostic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                diagnostic.code,
                style: const TextStyle(
                  color: Color(0xFF8994A8),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
              if (_diagnosticLocationLabel(diagnostic) case final location?)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: Color(0xFF8994A8),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _diagnosticSeverityLabel(
  AppLocalizations l10n,
  DiagnosticSeverity severity,
) => switch (severity) {
  DiagnosticSeverity.info => l10n.severityInfo,
  DiagnosticSeverity.warning => l10n.severityWarning,
  DiagnosticSeverity.error || DiagnosticSeverity.fatal => l10n.severityError,
};

String _diagnosticLocationPrefix(EditorDiagnostic diagnostic) {
  final location = _diagnosticLocationLabel(diagnostic);
  return location == null ? '' : '$location: ';
}

String? _diagnosticLocationLabel(EditorDiagnostic diagnostic) {
  final filePath = diagnostic.filePath?.trim();
  final line = diagnostic.sourceLine;
  final column = diagnostic.sourceColumn;
  if ((filePath == null || filePath.isEmpty) &&
      line == null &&
      column == null) {
    return null;
  }

  final segments = filePath
      ?.replaceAll(r'\', '/')
      .split('/')
      .where((segment) => segment.isNotEmpty);
  final fileName = segments == null || segments.isEmpty ? null : segments.last;
  return [
    ?fileName,
    if (line != null) '$line',
    if (column != null) '$column',
  ].join(':');
}

class _OperationSummary extends StatelessWidget {
  const _OperationSummary({required this.progress});

  final OperationProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            _phaseIcon(progress.phase),
            size: 18,
            color: _phaseColor(progress.phase),
          ),
          const SizedBox(width: 10),
          Text(
            context.localizeEditorText(progress.label),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              progress.message == null
                  ? _phaseLabel(context.l10n, progress.phase)
                  : context.localizeEditorText(progress.message!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8994A8)),
            ),
          ),
          if (progress.fraction case final fraction?)
            Text('${(fraction * 100).round()}%'),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.progress,
    required this.session,
    required this.eudDocument,
    required this.workspaceView,
  });

  final OperationProgress? progress;
  final OpenedMapSession? session;
  final EudSourceDocument? eudDocument;
  final _WorkspaceView workspaceView;

  @override
  Widget build(BuildContext context) {
    final currentProgress = progress;
    final active = currentProgress != null && !currentProgress.isTerminal;
    final session = this.session;
    final eudDocument = this.eudDocument;
    final showingEud =
        workspaceView == _WorkspaceView.eud && eudDocument != null;
    final l10n = context.l10n;

    return SizedBox(
      height: 28,
      child: ColoredBox(
        color: const Color(0xFF1B4E8A),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              if (active)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: currentProgress.fraction,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  currentProgress == null
                      ? Icons.check_circle_outline
                      : _phaseIcon(currentProgress.phase),
                  size: 14,
                ),
              const SizedBox(width: 6),
              Text(
                currentProgress == null
                    ? l10n.statusReady
                    : currentProgress.message ??
                          _phaseLabel(l10n, currentProgress.phase),
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                showingEud
                    ? l10n.statusDocument(
                        eudDocument.fileName,
                        eudDocument.isDirty
                            ? l10n.stateModified
                            : l10n.stateClean,
                      )
                    : session == null
                    ? l10n.statusNoDocument
                    : l10n.statusDocument(
                        _sessionName(l10n, session),
                        session.isDirty ? l10n.stateModified : l10n.stateClean,
                      ),
                key: const Key('active-document-status'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 18),
              Text(
                currentProgress == null
                    ? '100%'
                    : currentProgress.fraction == null
                    ? '—'
                    : '${(currentProgress.fraction! * 100).round()}%',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _phaseLabel(AppLocalizations l10n, OperationPhase phase) {
  return switch (phase) {
    OperationPhase.queued => l10n.phaseQueued,
    OperationPhase.reading => l10n.phaseReading,
    OperationPhase.parsing => l10n.phaseParsing,
    OperationPhase.validating => l10n.phaseValidating,
    OperationPhase.writing => l10n.phaseWriting,
    OperationPhase.compiling => l10n.phaseCompiling,
    OperationPhase.verifying => l10n.phaseVerifying,
    OperationPhase.succeeded => l10n.phaseSucceeded,
    OperationPhase.failed => l10n.phaseFailed,
    OperationPhase.cancelled => l10n.phaseCancelled,
  };
}

IconData _phaseIcon(OperationPhase phase) {
  return switch (phase) {
    OperationPhase.succeeded => Icons.check_circle_outline,
    OperationPhase.failed => Icons.error_outline,
    OperationPhase.cancelled => Icons.cancel_outlined,
    _ => Icons.pending_outlined,
  };
}

Color _phaseColor(OperationPhase phase) {
  return switch (phase) {
    OperationPhase.succeeded => const Color(0xFF65D28A),
    OperationPhase.failed => const Color(0xFFFF7B72),
    OperationPhase.cancelled => const Color(0xFFF0B85A),
    _ => const Color(0xFF70A1FF),
  };
}

IconData _diagnosticIcon(DiagnosticSeverity severity) {
  return switch (severity) {
    DiagnosticSeverity.info => Icons.info_outline,
    DiagnosticSeverity.warning => Icons.warning_amber_rounded,
    DiagnosticSeverity.error || DiagnosticSeverity.fatal => Icons.error_outline,
  };
}

Color _diagnosticColor(DiagnosticSeverity severity) {
  return switch (severity) {
    DiagnosticSeverity.info => const Color(0xFF70A1FF),
    DiagnosticSeverity.warning => const Color(0xFFFFB454),
    DiagnosticSeverity.error ||
    DiagnosticSeverity.fatal => const Color(0xFFFF7B72),
  };
}

String _sessionName(AppLocalizations l10n, OpenedMapSession session) {
  final path = session.sourcePath;
  return path == null ? l10n.untitledMap : _fileName(path);
}

String _fileName(String path) {
  return path.replaceAll('\\', '/').split('/').last;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

String _humanizeEnumName(String name) {
  final buffer = StringBuffer();
  for (var index = 0; index < name.length; index++) {
    final character = name[index];
    if (index > 0 && character.toUpperCase() == character) {
      buffer.write(' ');
    }
    buffer.write(index == 0 ? character.toUpperCase() : character);
  }
  return buffer.toString();
}
