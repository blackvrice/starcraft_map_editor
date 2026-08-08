import 'dart:async';

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
import '../../application/eud/eud_source_document.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/operations/operation_progress.dart';
import '../../application/operations/operation_progress_controller.dart';
import '../../application/recent_projects/recent_project.dart';
import '../../application/recent_projects/recent_projects_service.dart';
import '../../application/settings/starcraft_data_asset_settings_controller.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../../domain/terrain/terrain_tile_display_value.dart';
import '../eud_editor/eud_source_editor.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';
import '../settings/starcraft_asset_settings_dialog.dart';

enum _WorkspaceView { map, eud }

class EditorShell extends StatefulWidget {
  const EditorShell({
    required this.commandDispatcher,
    required this.openMapController,
    required this.saveMapController,
    required this.eudBuildController,
    required this.eudSourceController,
    required this.operationProgressController,
    required this.recentProjectsService,
    required this.starCraftDataAssetSettingsController,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.terrainTileTextureController,
    super.key,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OpenMapController openMapController;
  final SaveMapController saveMapController;
  final EudBuildController eudBuildController;
  final EudSourceController eudSourceController;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;
  final StarCraftDataAssetSettingsController
  starCraftDataAssetSettingsController;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final TerrainTileTextureController terrainTileTextureController;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late Future<List<RecentProject>> _recentProjects;
  late StreamSubscription<OpenMapState> _openMapSubscription;
  late StreamSubscription<SaveMapState> _saveMapSubscription;
  late StreamSubscription<EudBuildState> _eudBuildSubscription;
  late StreamSubscription<EudSourceState> _eudSourceSubscription;
  late StreamSubscription<StarCraftDataAssetSettingsState>
  _starCraftDataAssetSettingsSubscription;
  late StreamSubscription<TerrainEditingState> _terrainEditingSubscription;
  late StreamSubscription<MapLayerState> _mapLayerSubscription;
  late StreamSubscription<ObjectEditingState> _objectEditingSubscription;
  late StreamSubscription<ObjectPaletteState> _objectPaletteSubscription;
  late StreamSubscription<TerrainTileTextureState>
  _terrainTileTextureSubscription;
  late List<EditorDiagnostic> _documentDiagnostics;
  late _WorkspaceView _workspaceView;

  @override
  void initState() {
    super.initState();
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
    _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
    _saveMapSubscription = _listenForSavedMaps(widget.saveMapController);
    _eudBuildSubscription = _listenForEudBuild(widget.eudBuildController);
    _eudSourceSubscription = _listenForEudSources(widget.eudSourceController);
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
    _terrainTileTextureSubscription = _listenForTerrainTileTextures(
      widget.terrainTileTextureController,
    );
    _synchronizeTerrainTextures();
    unawaited(widget.starCraftDataAssetSettingsController.load());
  }

  @override
  void didUpdateWidget(EditorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    var synchronizeTerrainTextures = false;
    if (oldWidget.recentProjectsService != widget.recentProjectsService) {
      _recentProjects = widget.recentProjectsService.load();
    }
    if (oldWidget.openMapController != widget.openMapController) {
      unawaited(_openMapSubscription.cancel());
      _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
      synchronizeTerrainTextures = true;
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
    if (synchronizeTerrainTextures) {
      _synchronizeTerrainTextures();
    }
  }

  StreamSubscription<OpenMapState> _listenForOpenedMaps(
    OpenMapController controller,
  ) {
    return controller.changes.listen((state) {
      if (mounted) {
        setState(() {
          _documentDiagnostics = state.diagnostics;
          if (state.status == OpenMapStatus.opened) {
            _workspaceView = _WorkspaceView.map;
            _recentProjects = widget.recentProjectsService.load();
          }
          widget.terrainEditingController.synchronizeSession(state.session);
          widget.mapLayerController.synchronizeSession(state.session);
          widget.objectEditingController.synchronizeSession(state.session);
          widget.objectPaletteController.synchronizeSession(state.session);
        });
        _synchronizeTerrainTextures();
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
    return controller.changes.listen((_) {
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

  @override
  void dispose() {
    unawaited(_openMapSubscription.cancel());
    unawaited(_saveMapSubscription.cancel());
    unawaited(_eudBuildSubscription.cancel());
    unawaited(_eudSourceSubscription.cancel());
    unawaited(_starCraftDataAssetSettingsSubscription.cancel());
    unawaited(_terrainEditingSubscription.cancel());
    unawaited(_mapLayerSubscription.cancel());
    unawaited(_objectEditingSubscription.cancel());
    unawaited(_objectPaletteSubscription.cancel());
    unawaited(_terrainTileTextureSubscription.cancel());
    widget.terrainTileTextureController.clear();
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
    final buildEud = widget.eudBuildController.canStart
        ? _callbackFor(EditorCommandId.buildEud)
        : null;
    final cancelEudBuild = eudBuildState.canCancel
        ? _callbackFor(EditorCommandId.cancelEudBuild)
        : null;
    final newEudSource =
        widget.commandDispatcher.canDispatch(EditorCommandId.newEudSource)
        ? _newEudSource
        : null;
    final objectLayerActive =
        widget.mapLayerController.state.activeLayer != MapLayerType.terrain;
    final undoEdit = _workspaceView != _WorkspaceView.map
        ? null
        : objectLayerActive && widget.objectEditingController.canUndo
        ? widget.objectEditingController.undo
        : !objectLayerActive && widget.terrainEditingController.canUndo
        ? widget.terrainEditingController.undo
        : null;
    final redoEdit = _workspaceView != _WorkspaceView.map
        ? null
        : objectLayerActive && widget.objectEditingController.canRedo
        ? widget.objectEditingController.redo
        : !objectLayerActive && widget.terrainEditingController.canRedo
        ? widget.terrainEditingController.redo
        : null;
    final deleteObjects =
        _workspaceView == _WorkspaceView.map &&
            widget.objectEditingController.canEditSelection
        ? widget.objectEditingController.deleteSelection
        : null;
    final cancelObjectPlacement =
        _workspaceView == _WorkspaceView.map &&
            widget.objectPaletteController.state.isPlacementActive
        ? widget.objectPaletteController.cancelPlacement
        : null;
    final cancelLocationCreation =
        _workspaceView == _WorkspaceView.map &&
            widget.objectEditingController.state.isCreatingLocation
        ? widget.objectEditingController.cancelLocationCreation
        : null;
    final starCraftDataAssetState =
        widget.starCraftDataAssetSettingsController.state;
    final terrainTileTextureState = widget.terrainTileTextureController.state;
    final visibleDiagnostics = [
      ..._documentDiagnostics,
      ...starCraftDataAssetState.diagnostics,
      ...terrainTileTextureState.diagnostics,
    ];

    final shortcuts = <ShortcutActivator, VoidCallback>{};
    if (openMap != null) {
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
                  openMap: openMap,
                  saveAs: saveAs,
                  newEudSource: newEudSource,
                  buildEud: buildEud,
                  cancelEudBuild: cancelEudBuild,
                  undo: undoEdit,
                  redo: redoEdit,
                  openSettings: _showStarCraftDataAssetSettings,
                ),
                const Divider(height: 1),
                _EditorToolbar(
                  openMap: openMap,
                  saveAs: saveAs,
                  newEudSource: newEudSource,
                  buildEud: buildEud,
                  cancelEudBuild: cancelEudBuild,
                  eudBuildActive: eudBuildState.isActive,
                  starCraftDataAssetState: starCraftDataAssetState,
                  openSettings: _showStarCraftDataAssetSettings,
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
                            terrainEditingController:
                                widget.terrainEditingController,
                            mapLayerController: widget.mapLayerController,
                            objectEditingController:
                                widget.objectEditingController,
                            objectPaletteController:
                                widget.objectPaletteController,
                            terrainTileTextureState: terrainTileTextureState,
                            workspaceView: _workspaceView,
                            onShowMap: _showMapWorkspace,
                            onShowEud: _showEudWorkspace,
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
    required this.openMap,
    required this.saveAs,
    required this.newEudSource,
    required this.buildEud,
    required this.cancelEudBuild,
    required this.undo,
    required this.redo,
    required this.openSettings,
  });

  final VoidCallback? openMap;
  final VoidCallback? saveAs;
  final VoidCallback? newEudSource;
  final VoidCallback? buildEud;
  final VoidCallback? cancelEudBuild;
  final VoidCallback? undo;
  final VoidCallback? redo;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    return MenuBar(
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(onPressed: openMap, child: const Text('Open Map…')),
            MenuItemButton(onPressed: saveAs, child: const Text('Save As…')),
            const Divider(),
            const MenuItemButton(onPressed: null, child: Text('Close')),
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              key: const Key('menu-undo'),
              onPressed: undo,
              child: const Text('Undo'),
            ),
            MenuItemButton(
              key: const Key('menu-redo'),
              onPressed: redo,
              child: const Text('Redo'),
            ),
            const Divider(),
            MenuItemButton(
              key: const Key('menu-settings'),
              onPressed: openSettings,
              child: const Text('Settings…'),
            ),
          ],
          child: const Text('Edit'),
        ),
        SubmenuButton(
          menuChildren: const [
            MenuItemButton(onPressed: null, child: Text('Reset Layout')),
          ],
          child: const Text('View'),
        ),
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: newEudSource,
              child: const Text('New epScript'),
            ),
            const Divider(),
            MenuItemButton(
              key: const Key('menu-build-eud'),
              onPressed: buildEud,
              child: const Text('Build EUD Map'),
            ),
            MenuItemButton(
              key: const Key('menu-cancel-eud-build'),
              onPressed: cancelEudBuild,
              child: const Text('Cancel EUD Build'),
            ),
          ],
          child: const Text('EUD'),
        ),
        SubmenuButton(
          menuChildren: const [
            MenuItemButton(onPressed: null, child: Text('Documentation')),
            MenuItemButton(onPressed: null, child: Text('About')),
          ],
          child: const Text('Help'),
        ),
      ],
    );
  }
}

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
  });

  final VoidCallback? openMap;
  final VoidCallback? saveAs;
  final VoidCallback? newEudSource;
  final VoidCallback? buildEud;
  final VoidCallback? cancelEudBuild;
  final bool eudBuildActive;
  final StarCraftDataAssetSettingsState starCraftDataAssetState;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1350;
          final compactEnvironmentBadge =
              !compact && constraints.maxWidth < 1550;
          final showEnvironmentBadge = constraints.maxWidth >= 1000;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Color(0xFF70A1FF)),
                const SizedBox(width: 10),
                const Text(
                  'StarCraft Map Editor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (showEnvironmentBadge) ...[
                  const SizedBox(width: 12),
                  _EnvironmentBadge(
                    assetState: starCraftDataAssetState,
                    onPressed: openSettings,
                    compact: compactEnvironmentBadge,
                  ),
                ],
                const Spacer(),
                if (compact) ...[
                  IconButton(
                    key: const Key('toolbar-open-map'),
                    onPressed: openMap,
                    tooltip: 'Open Map',
                    icon: const Icon(Icons.folder_open),
                  ),
                  IconButton(
                    key: const Key('toolbar-save-as'),
                    onPressed: saveAs,
                    tooltip: 'Save As',
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton(
                    key: const Key('toolbar-new-eud-source'),
                    onPressed: newEudSource,
                    tooltip: 'New epScript',
                    icon: const Icon(Icons.code_rounded),
                  ),
                  if (eudBuildActive)
                    IconButton.filled(
                      key: const Key('toolbar-cancel-eud-build'),
                      onPressed: cancelEudBuild,
                      tooltip: 'Cancel EUD Build',
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    IconButton.filled(
                      key: const Key('toolbar-build-eud'),
                      onPressed: buildEud,
                      tooltip: 'Build EUD',
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                ] else ...[
                  TextButton.icon(
                    key: const Key('toolbar-open-map'),
                    onPressed: openMap,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open Map'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('toolbar-save-as'),
                    onPressed: saveAs,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save As'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    key: const Key('toolbar-new-eud-source'),
                    onPressed: newEudSource,
                    icon: const Icon(Icons.code_rounded),
                    label: const Text('New epScript'),
                  ),
                  const SizedBox(width: 8),
                  if (eudBuildActive)
                    FilledButton.icon(
                      key: const Key('toolbar-cancel-eud-build'),
                      onPressed: cancelEudBuild,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Cancel Build'),
                    )
                  else
                    FilledButton.icon(
                      key: const Key('toolbar-build-eud'),
                      onPressed: buildEud,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Build EUD'),
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
    final (label, compactLabel, color) = switch (assetState.status) {
      StarCraftDataAssetSettingsStatus.loading ||
      StarCraftDataAssetSettingsStatus.inspecting => (
        'Assets checking',
        'Checking',
        const Color(0xFFAAC8FF),
      ),
      StarCraftDataAssetSettingsStatus.ready => (
        'Assets ready',
        'Ready',
        const Color(0xFF7ADAA5),
      ),
      StarCraftDataAssetSettingsStatus.unconfigured => (
        'Assets not configured',
        'Setup',
        const Color(0xFFFFC56E),
      ),
      StarCraftDataAssetSettingsStatus.unavailable => (
        'Assets unavailable',
        'Missing',
        const Color(0xFFFFB454),
      ),
    };

    return Tooltip(
      message: 'Open StarCraft data asset settings • $label',
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
            compact ? 'SC:R • $compactLabel' : 'Windows • SC:R • $label',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _EditorWorkspace extends StatelessWidget {
  const _EditorWorkspace({
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
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.terrainTileTextureState,
    required this.workspaceView,
    required this.onShowMap,
    required this.onShowEud,
  });

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
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final TerrainTileTextureState terrainTileTextureState;
  final _WorkspaceView workspaceView;
  final VoidCallback onShowMap;
  final VoidCallback onShowEud;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;
    final eudDocument = eudSourceController.state.document;
    final showingEud =
        workspaceView == _WorkspaceView.eud && eudDocument != null;

    return Row(
      children: [
        SizedBox(
          width: 210,
          child: _EditorPane(
            title: showingEud
                ? 'Project / Sources'
                : session == null
                ? 'Project / Layers'
                : 'Layers / Object Palette',
            child: showingEud
                ? _EudSourceList(document: eudDocument, onSelected: onShowEud)
                : session == null
                ? const _EmptyPaneMessage(
                    icon: Icons.layers_outlined,
                    message: 'No map layers',
                  )
                : _MapLayersAndPalette(
                    session: session,
                    layerController: mapLayerController,
                    paletteController: objectPaletteController,
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
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              if (session != null || eudDocument != null)
                _DocumentTabs(
                  session: session,
                  eudDocument: eudDocument,
                  workspaceView: workspaceView,
                  onShowMap: onShowMap,
                  onShowEud: onShowEud,
                ),
              Expanded(
                child: _MapWorkspace(
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
                  terrainTileTextureState: terrainTileTextureState,
                  workspaceView: workspaceView,
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 260,
          child: _EditorPane(
            title: 'Inspector',
            child: showingEud
                ? _EudSourceInspector(document: eudDocument)
                : session == null
                ? const _EmptyPaneMessage(
                    icon: Icons.tune,
                    message: 'Nothing selected',
                  )
                : _MapInspector(
                    session: session,
                    mapLayerController: mapLayerController,
                    objectEditingController: objectEditingController,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DocumentTabs extends StatelessWidget {
  const _DocumentTabs({
    required this.session,
    required this.eudDocument,
    required this.workspaceView,
    required this.onShowMap,
    required this.onShowEud,
  });

  final OpenedMapSession? session;
  final EudSourceDocument? eudDocument;
  final _WorkspaceView workspaceView;
  final VoidCallback onShowMap;
  final VoidCallback onShowEud;

  @override
  Widget build(BuildContext context) {
    final document = eudDocument;
    return SizedBox(
      height: 40,
      child: ColoredBox(
        color: const Color(0xFF171C24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session case final session?)
              _DocumentTab(
                key: const Key('map-document-tab'),
                label: _fileName(session.sourcePath),
                dirty: session.isDirty,
                icon: Icons.map_outlined,
                selected: workspaceView == _WorkspaceView.map,
                onPressed: onShowMap,
              ),
            if (document != null)
              _DocumentTab(
                key: const Key('eud-source-tab'),
                label: document.fileName,
                dirty: document.isDirty,
                icon: Icons.code_rounded,
                selected: workspaceView == _WorkspaceView.eud,
                onPressed: onShowEud,
              ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTab extends StatelessWidget {
  const _DocumentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.dirty = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF0D1117) : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                width: 2,
                color: selected ? const Color(0xFF70A1FF) : Colors.transparent,
              ),
              right: const BorderSide(color: Color(0xFF252C38)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? const Color(0xFF8EB5FF)
                    : const Color(0xFF778398),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$label${dirty ? ' •' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFE1E8F3)
                        : const Color(0xFF9AA5B8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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
            subtitle: Text(document.isUntitled ? 'Draft' : 'epScript source'),
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
    return ListView(
      key: const Key('eud-source-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _InspectorValue(label: 'File', value: document.fileName),
        _InspectorValue(
          label: 'Location',
          value: document.sourcePath ?? 'In-memory draft',
        ),
        _InspectorValue(label: 'Lines', value: '${document.lineCount}'),
        _InspectorValue(label: 'Characters', value: '${document.text.length}'),
        _InspectorValue(label: 'Revision', value: '${document.revision}'),
        _InspectorValue(
          label: 'State',
          value: document.isDirty ? 'Modified' : 'Clean',
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
            Icon(icon, size: 24, color: const Color(0xFF657086)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8994A8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapWorkspace extends StatelessWidget {
  const _MapWorkspace({
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
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.terrainTileTextureState,
    required this.workspaceView,
  });

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
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final TerrainTileTextureState terrainTileTextureState;
  final _WorkspaceView workspaceView;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;
    final eudDocument = eudSourceController.state.document;
    if (workspaceView == _WorkspaceView.eud && eudDocument != null) {
      return EudSourceEditor(
        document: eudDocument,
        sourceController: eudSourceController,
      );
    }
    if (session != null) {
      return _OpenedMapWorkspace(
        session: session,
        diagnostics: [
          ...session.diagnostics,
          ...terrainTileTextureState.diagnostics,
        ],
        terrainEditingController: terrainEditingController,
        mapLayerController: mapLayerController,
        objectEditingController: objectEditingController,
        objectPaletteController: objectPaletteController,
        terrainTileTextureState: terrainTileTextureState,
      );
    }

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
                    'Open a map to begin',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The first release will support unprotected StarCraft: '
                    'Remastered UMS maps.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF929DB0)),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('open-map-button'),
                    onPressed: openMap,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open Map'),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Recent maps',
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
                    const _RecentProjectsMessage(
                      icon: Icons.warning_amber_rounded,
                      message: 'Recent maps could not be loaded.',
                    )
                  else if (recentProjects.isEmpty)
                    const _RecentProjectsMessage(
                      icon: Icons.history,
                      message: 'Maps you open will appear here.',
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
    required this.session,
    required this.diagnostics,
    required this.terrainEditingController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.objectPaletteController,
    required this.terrainTileTextureState,
  });

  final OpenedMapSession session;
  final List<EditorDiagnostic> diagnostics;
  final TerrainEditingController terrainEditingController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final ObjectPaletteController objectPaletteController;
  final TerrainTileTextureState terrainTileTextureState;

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

    return ColoredBox(
      key: const Key('map-workspace'),
      color: const Color(0xFF101319),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                        message: session.sourcePath,
                        child: Text(
                          _fileName(session.sourcePath),
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
                      editable: canEditTerrain,
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
                          ? 'Size unavailable'
                          : '${dimensions.width} × ${dimensions.height}',
                    ),
                    _MapCanvasMetadata(
                      icon: Icons.landscape_outlined,
                      value: tileset == null
                          ? 'Tileset unavailable'
                          : tileset.knownTileset == null
                          ? 'Tileset ${tileset.rawValue}'
                          : _humanizeEnumName(tileset.knownTileset!.name),
                    ),
                    _MapCanvasMetadata(
                      icon: rawTileValues == null
                          ? Icons.border_all_rounded
                          : Icons.texture_rounded,
                      value: rawTileValues == null
                          ? 'Geometry preview'
                          : '${rawTileValues.length} MTXM tiles',
                    ),
                    const _MapCanvasMetadata(
                      key: Key('map-canvas-navigation-help'),
                      icon: Icons.pan_tool_alt_rounded,
                      value: 'Wheel zoom · Space/middle drag',
                    ),
                    _MapCanvasMetadata(
                      key: const Key('map-layer-selection-priority'),
                      icon: Icons.layers_rounded,
                      value:
                          'Pick ${layerState.selectionPriority.map((layer) => layer.label).join(' → ')}',
                    ),
                    if (paletteState.selectedEntry case final entry?)
                      _MapCanvasMetadata(
                        key: const Key('object-placement-active'),
                        icon: Icons.add_location_alt_outlined,
                        value: 'Place ${entry.label} · Esc cancel',
                      ),
                    if (objectEditingController.state.isCreatingLocation)
                      const _MapCanvasMetadata(
                        key: Key('location-creation-active'),
                        icon: Icons.crop_free_rounded,
                        value: 'Drag new location · Esc cancel',
                      ),
                    if (blockingCount > 0 || warningCount > 0)
                      _MapCanvasMetadata(
                        icon: Icons.report_problem_outlined,
                        value:
                            '$blockingCount blocking · $warningCount warning',
                      ),
                  ],
                ),
                const SizedBox(height: 9),
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
                              selection.object.layer != MapLayerType.terrain,
                        )
                        .length,
                    canEdit: objectEditingController.canEditSelection,
                    undoLabel: objectEditingController.undoLabel,
                    redoLabel: objectEditingController.redoLabel,
                    onDelete: objectEditingController.canEditSelection
                        ? objectEditingController.deleteSelection
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
                      if (objectEditingController.state.isCreatingLocation) {
                        objectEditingController.cancelLocationCreation();
                      } else {
                        objectPaletteController.cancelPlacement();
                        objectEditingController.startLocationCreation();
                      }
                    },
                  ),
              ],
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
                    key: ValueKey('map-canvas:${session.sourcePath}'),
                    mapWidth: dimensions.width,
                    mapHeight: dimensions.height,
                    rawTileValues: terrainLayer.isVisible
                        ? rawTileValues
                        : null,
                    terrainTextureState: terrainTileTextureState,
                    editingTool: editingState.tool,
                    selectedTile: selectedTerrainTile,
                    layerScene: layerScene,
                    isObjectPlacementActive:
                        paletteState.isPlacementActive ||
                        objectEditingController.state.isCreatingLocation,
                    onSelectionRequested:
                        editingState.tool == TerrainEditingTool.select
                        ? (request) {
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
                            !paletteState.isPlacementActive &&
                            !objectEditingController.state.isCreatingLocation &&
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
    );
  }
}

class _MapCanvasMetadata extends StatelessWidget {
  const _MapCanvasMetadata({
    required this.icon,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF202733),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF313C4F)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF91ACD8)),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(color: Color(0xFFC2CAD8), fontSize: 10),
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
    return Wrap(
      key: const Key('object-editing-toolbar'),
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showLocationCreation)
          _TerrainToolButton(
            key: const Key('object-create-location'),
            label: locationCreationActive ? 'Cancel location' : 'New location',
            icon: locationCreationActive
                ? Icons.close_rounded
                : Icons.crop_free_rounded,
            selected: locationCreationActive,
            enabled: locationCreationActive || canCreateLocation,
            onPressed: onToggleLocationCreation,
          ),
        _TerrainToolButton(
          key: const Key('object-delete'),
          label: 'Delete',
          icon: Icons.delete_outline_rounded,
          selected: false,
          enabled: onDelete != null,
          onPressed: onDelete,
        ),
        _TerrainToolButton(
          key: const Key('object-undo'),
          label: 'Undo',
          icon: Icons.undo_rounded,
          selected: false,
          enabled: onUndo != null,
          onPressed: onUndo,
        ),
        _TerrainToolButton(
          key: const Key('object-redo'),
          label: 'Redo',
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
              ? 'Click or drag to select objects'
              : '$selectedCount selected · drag selection to move',
        ),
        _MapCanvasMetadata(
          key: const Key('object-editing-history'),
          icon: canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded,
          value: [
            if (undoLabel != null) 'Undo $undoLabel',
            if (redoLabel != null) 'Redo $redoLabel',
            if (undoLabel == null && redoLabel == null)
              'Ctrl/Shift click adds · Delete removes',
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
        ? 'Select a source tile'
        : 'Raw tile ${selectedDisplayValue.rawValue} · '
              'group ${selectedDisplayValue.groupIndex} · '
              'member ${selectedDisplayValue.groupMember}'
              '${selectedIsUnsupported ? ' · unsupported' : ''}'
              '${selection == null ? '' : ' from ${selection.x},${selection.y}'}';

    return Wrap(
      key: const Key('terrain-editing-toolbar'),
      spacing: 7,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TerrainToolButton(
          key: const Key('terrain-tool-select'),
          label: 'Select tile',
          icon: Icons.colorize_rounded,
          selected: state.tool == TerrainEditingTool.select,
          enabled: canSelectTiles,
          onPressed: () => onToolSelected(TerrainEditingTool.select),
        ),
        _TerrainToolButton(
          key: const Key('terrain-tool-brush'),
          label: 'Brush',
          icon: Icons.brush_rounded,
          selected: state.tool == TerrainEditingTool.brush,
          enabled: canEditTerrain && hasSelectedTile,
          onPressed: () => onToolSelected(TerrainEditingTool.brush),
        ),
        _TerrainToolButton(
          key: const Key('terrain-tool-rectangle'),
          label: 'Rectangle',
          icon: Icons.crop_square_rounded,
          selected: state.tool == TerrainEditingTool.rectangle,
          enabled: canEditTerrain && hasSelectedTile,
          onPressed: () => onToolSelected(TerrainEditingTool.rectangle),
        ),
        _TerrainToolButton(
          key: const Key('terrain-undo'),
          label: 'Undo',
          icon: Icons.undo_rounded,
          selected: false,
          enabled: onUndo != null,
          onPressed: onUndo,
        ),
        _TerrainToolButton(
          key: const Key('terrain-redo'),
          label: 'Redo',
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
        const _MapCanvasMetadata(
          key: Key('terrain-editing-scope'),
          icon: Icons.shield_outlined,
          value: 'MTXM only · TILE/ISOM preserved',
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
      height: 28,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFFE8F0FF)
              : const Color(0xFFB8C4D8),
          backgroundColor: selected ? const Color(0xFF29466F) : null,
          side: BorderSide(
            color: selected ? const Color(0xFF70A1FF) : const Color(0xFF3A465A),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          textStyle: const TextStyle(fontSize: 10),
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
    return const ColoredBox(
      key: Key('map-canvas-unavailable'),
      color: Color(0xFF0C1016),
      child: Center(
        child: _EmptyPaneMessage(
          icon: Icons.grid_off_rounded,
          message: 'A unique, non-zero DIM section is required for the canvas.',
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
    return Container(
      key: const Key('opened-map-mode'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        restricted
            ? 'Restricted'
            : dirty
            ? 'Modified'
            : editable
            ? 'Editable'
            : 'Read-only preview',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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
    required this.onLayerActivated,
  });

  final OpenedMapSession session;
  final MapLayerController layerController;
  final ObjectPaletteController paletteController;
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
          child: _ObjectPalettePanel(controller: paletteController),
        ),
      ],
    );
  }
}

class _ObjectPalettePanel extends StatelessWidget {
  const _ObjectPalettePanel({required this.controller});

  final ObjectPaletteController controller;

  @override
  Widget build(BuildContext context) {
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
                const Expanded(
                  child: Text(
                    'Object Palette',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (selectedEntry != null)
                  IconButton(
                    key: const Key('object-palette-cancel'),
                    tooltip: 'Cancel placement (Esc)',
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
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                hintText: 'Search type or #id',
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
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
              '${selectedEntry.label}: click map to place',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFA9C7FF), fontSize: 10),
            ),
          ),
        Expanded(
          child: state.entries.isEmpty
              ? const _ObjectPaletteMessage(
                  message: 'No map-local object templates.',
                )
              : state.visibleEntries.isEmpty
              ? const _ObjectPaletteMessage(message: 'No matching templates.')
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
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Text(
                          '×${entry.count}',
                          style: const TextStyle(
                            color: Color(0xFF7F8BA0),
                            fontSize: 9,
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
          style: const TextStyle(color: Color(0xFF7F8BA0), fontSize: 10),
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
                ? 'Click the canvas to inspect the first unlocked object.'
                : selections.length == 1
                ? '${selections.single.object.label} · '
                      '${selections.single.pixelX},${selections.single.pixelY}px'
                : '${selections.length} objects selected',
            key: const Key('map-layer-selection-summary'),
            style: const TextStyle(color: Color(0xFF8F9BB0), fontSize: 10),
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
    return Material(
      color: isActive ? const Color(0xFF23304A) : Colors.transparent,
      child: InkWell(
        key: Key('map-layer-${layer.name}'),
        onTap: onActivate,
        child: SizedBox(
          height: 46,
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
                      layer.label,
                      style: TextStyle(
                        color: status.isVisible
                            ? const Color(0xFFD8DEE9)
                            : const Color(0xFF707A8E),
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      '$objectCount items',
                      style: const TextStyle(
                        color: Color(0xFF707C91),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              _MapLayerToggle(
                key: Key('map-layer-${layer.name}-visible'),
                tooltip: status.isVisible
                    ? 'Hide ${layer.label}'
                    : 'Show ${layer.label}',
                icon: status.isVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                isActive: status.isVisible,
                onPressed: () => onVisibilityChanged(!status.isVisible),
              ),
              _MapLayerToggle(
                key: Key('map-layer-${layer.name}-locked'),
                tooltip: status.isLocked
                    ? 'Unlock ${layer.label}'
                    : 'Lock ${layer.label}',
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
    return ListView(
      key: const Key('map-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _InspectorValue(label: 'File', value: _fileName(session.sourcePath)),
        _InspectorValue(label: 'Source path', value: session.sourcePath),
        _InspectorValue(
          label: 'Map size',
          value: dimensions == null
              ? 'Unavailable'
              : '${dimensions.width} × ${dimensions.height}',
        ),
        _InspectorValue(
          label: 'Tileset',
          value: tileset == null
              ? 'Unavailable'
              : tileset.knownTileset == null
              ? 'Unknown (${tileset.rawValue})'
              : _humanizeEnumName(tileset.knownTileset!.name),
        ),
        _InspectorValue(
          label: 'Map version',
          value: version == null
              ? 'Unavailable'
              : version.knownVersion == null
              ? 'Unknown (${version.rawValue})'
              : '${_humanizeEnumName(version.knownVersion!.name)} '
                    '(${version.rawValue})',
        ),
        _InspectorValue(
          label: 'Scenario type',
          value: scenarioType?.fourCharacterCode ?? 'Unavailable',
        ),
        _InspectorValue(
          label: 'Terrain',
          value: terrain == null
              ? '${session.terrainViews.tileMaps.length} MTXM views'
              : '${terrain.tileCount} raw tiles',
        ),
        _InspectorValue(
          label: 'Archive size',
          value: _formatBytes(archive.archiveSizeBytes),
        ),
        _InspectorValue(
          label: 'Entries',
          value:
              '${archive.entries.length} listed / ${archive.totalEntryCount}',
        ),
        _InspectorValue(
          label: 'CHK size',
          value: _formatBytes(session.scenarioChkSizeBytes),
        ),
        _InspectorValue(
          label: 'CHK sections',
          value: '${session.rawDocument.sections.length}',
        ),
        _InspectorValue(
          label: 'Diagnostics',
          value: '${session.diagnostics.length}',
        ),
      ],
    );
  }
}

class _MultiObjectInspector extends StatelessWidget {
  const _MultiObjectInspector({required this.selections});

  final List<MapLayerSelection> selections;

  @override
  Widget build(BuildContext context) {
    final layers = {
      for (final selection in selections) selection.object.layer.label,
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
          '${selections.length} objects selected',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _InspectorValue(label: 'Common layers', value: layers),
        const _InspectorNotice(
          icon: Icons.info_outline_rounded,
          message:
              'Select one object to edit its properties. Movement and deletion still apply to the full selection.',
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
                '${_objectKind(properties)} #${properties.object.recordIndex}',
                key: const Key('object-inspector-title'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _integerField(ObjectPropertyFields.typeId, 'Type ID', canEdit),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _integerField(ObjectPropertyFields.x, 'X (px)', canEdit),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _integerField(ObjectPropertyFields.y, 'Y (px)', canEdit),
            ),
          ],
        ),
        _integerField(ObjectPropertyFields.owner, 'Owner (raw 0-255)', canEdit),
        if (properties is UnitObjectProperties) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.hitpointPercent,
                  'HP %',
                  canEdit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.shieldPercent,
                  'Shield %',
                  canEdit,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _integerField(
                  ObjectPropertyFields.energyPercent,
                  'Energy %',
                  canEdit,
                ),
              ),
            ],
          ),
          _integerField(
            ObjectPropertyFields.resourceAmount,
            'Resource amount',
            canEdit,
          ),
          _integerField(
            ObjectPropertyFields.hangarAmount,
            'Hangar amount',
            canEdit,
          ),
        ],
        if (properties is DoodadObjectProperties)
          _integerField(
            ObjectPropertyFields.enabledValue,
            'Enabled raw (0=yes, 1=no)',
            canEdit,
          ),
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const Key('object-inspector-apply'),
          onPressed: canEdit ? _apply : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Apply properties'),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('object-inspector-message'),
            style: const TextStyle(color: Color(0xFFAFC7F5), fontSize: 10),
          ),
        ],
        if (!canEdit) ...[
          const SizedBox(height: 8),
          const _InspectorNotice(
            icon: Icons.lock_outline_rounded,
            message: 'Unlock this layer and use an editable map to apply.',
          ),
        ],
        const Divider(height: 24),
        const Text(
          'Preserved raw fields',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._rawValues(properties),
        const _InspectorNotice(
          icon: Icons.shield_outlined,
          message:
              'Raw flags and reserved fields are read-only and remain byte-exact.',
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
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          labelText: label,
          errorText: _errors[field],
          isDense: true,
        ),
      ),
    );
  }

  void _apply() {
    final parseErrors = <String, String>{};
    final values = <String, int>{};
    for (final entry in _fields.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value == null) {
        parseErrors[entry.key] = 'Enter a whole number.';
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
        ObjectPropertyEditStatus.applied => 'Properties applied.',
        ObjectPropertyEditStatus.noChanges => 'No property changes.',
        ObjectPropertyEditStatus.invalid => 'Fix the highlighted fields.',
        ObjectPropertyEditStatus.unavailable =>
          'Property editing is no longer available.',
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
    return ListView(
      key: const Key('location-properties-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Location ${properties.locationId}',
          key: const Key('object-inspector-title'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('location-inspector-name'),
          controller: _nameController,
          enabled: canEdit && properties.canRename,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: _errors[ObjectPropertyFields.name],
            isDense: true,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _boundField(ObjectPropertyFields.left, 'Left')),
            const SizedBox(width: 7),
            Expanded(child: _boundField(ObjectPropertyFields.top, 'Top')),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _boundField(ObjectPropertyFields.right, 'Right')),
            const SizedBox(width: 7),
            Expanded(child: _boundField(ObjectPropertyFields.bottom, 'Bottom')),
          ],
        ),
        FilledButton.icon(
          key: const Key('location-inspector-apply'),
          onPressed: canEdit ? _apply : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Apply location'),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            key: const Key('location-inspector-message'),
            style: const TextStyle(color: Color(0xFFAFC7F5), fontSize: 10),
          ),
        ],
        const Divider(height: 24),
        _InspectorValue(label: 'String ID', value: '${properties.stringId}'),
        _InspectorValue(
          label: 'Elevation flags',
          value: _hex(properties.elevationFlags, 4),
        ),
        if (!properties.canRename)
          _InspectorNotice(
            icon: Icons.info_outline_rounded,
            message:
                properties.renameUnavailableReason ??
                'Location naming is unavailable for this map.',
          )
        else
          const _InspectorNotice(
            icon: Icons.shield_outlined,
            message:
                'Renaming allocates a new string ID so shared map strings remain unchanged.',
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
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          labelText: label,
          errorText: _errors[field],
          isDense: true,
        ),
      ),
    );
  }

  void _apply() {
    final values = <String, int>{};
    final parseErrors = <String, String>{};
    for (final entry in _bounds.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value == null) {
        parseErrors[entry.key] = 'Enter a whole number.';
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
        ObjectPropertyEditStatus.applied => 'Location applied.',
        ObjectPropertyEditStatus.noChanges => 'No location changes.',
        ObjectPropertyEditStatus.invalid => 'Fix the highlighted fields.',
        ObjectPropertyEditStatus.unavailable =>
          'Location editing is no longer available.',
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
              style: const TextStyle(color: Color(0xFF9EABC0), fontSize: 10),
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

String _objectKind(ObjectProperties properties) => switch (properties) {
  UnitObjectProperties() => 'Unit',
  DoodadObjectProperties() => 'Doodad',
  SpriteObjectProperties() => 'Sprite',
  LocationObjectProperties() => 'Location',
};

List<Widget> _rawValues(ObjectProperties properties) => switch (properties) {
  UnitObjectProperties() => [
    _InspectorValue(label: 'Class ID', value: _hex(properties.classId, 8)),
    _InspectorValue(
      label: 'Relation flags',
      value: _hex(properties.relationFlags, 4),
    ),
    _InspectorValue(
      label: 'Valid state flags',
      value: _hex(properties.validStateFlags, 4),
    ),
    _InspectorValue(
      label: 'Valid field flags',
      value: _hex(properties.validFieldFlags, 4),
    ),
    _InspectorValue(
      label: 'State flags',
      value: _hex(properties.stateFlags, 4),
    ),
    _InspectorValue(label: 'Unused', value: _hex(properties.unused, 8)),
    _InspectorValue(
      label: 'Relation class ID',
      value: _hex(properties.relationClassId, 8),
    ),
  ],
  DoodadObjectProperties() => const [],
  SpriteObjectProperties() => [
    _InspectorValue(label: 'Unused', value: _hex(properties.unused, 2)),
    _InspectorValue(label: 'Flags', value: _hex(properties.flags, 4)),
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
            style: const TextStyle(color: Color(0xFF8994A8), fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
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
          tooltip: 'Remove from recent maps',
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
    return SizedBox(
      height: 128,
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
                      label: 'Problems',
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
                      label: 'Output',
                      selected: _selectedTab == _OutputPanelTab.output,
                      onPressed: () {
                        setState(() {
                          _selectedTab = _OutputPanelTab.output;
                        });
                      },
                    ),
                    _OutputPanelTabButton(
                      key: const Key('output-tab-build-log'),
                      label: 'Build Log',
                      selected: _selectedTab == _OutputPanelTab.buildLog,
                      count:
                          widget.eudBuildState.latestRecord?.logEntries.length,
                      onPressed: () {
                        setState(() {
                          _selectedTab = _OutputPanelTab.buildLog;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_selectedTab) {
                _OutputPanelTab.problems =>
                  diagnostics.isEmpty
                      ? const _OutputPanelMessage('No problems detected')
                      : _DiagnosticList(diagnostics: diagnostics),
                _OutputPanelTab.output =>
                  widget.progress == null
                      ? const _OutputPanelMessage('No operation output')
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
      child: Text(count == null || count == 0 ? label : '$label ($count)'),
    );
  }
}

class _OutputPanelMessage extends StatelessWidget {
  const _OutputPanelMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: Color(0xFF8994A8))),
    );
  }
}

class _EudBuildLog extends StatelessWidget {
  const _EudBuildLog({required this.state});

  final EudBuildState state;

  @override
  Widget build(BuildContext context) {
    final record = state.latestRecord;
    if (record == null) {
      return _OutputPanelMessage(_emptyMessage(state.status));
    }
    final items = _buildLogItems(record);

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

String _emptyMessage(EudBuildStatus status) {
  return switch (status) {
    EudBuildStatus.notConfigured => 'Build settings are not ready',
    EudBuildStatus.ready => 'Ready to build',
    EudBuildStatus.running => 'Starting euddraft…',
    EudBuildStatus.cancelling => 'Stopping euddraft…',
    EudBuildStatus.finalizing => 'Validating and promoting output…',
    EudBuildStatus.succeeded => 'Build completed',
    EudBuildStatus.failed => 'Build failed without output',
    EudBuildStatus.cancelled => 'Build cancelled',
  };
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

List<_EudBuildLogItem> _buildLogItems(EudBuildRecord record) {
  const metadataColor = Color(0xFF8EA0BB);
  const stdoutColor = Color(0xFFAAB5C8);
  const stderrColor = Color(0xFFFFC66D);
  final items = <_EudBuildLogItem>[
    _EudBuildLogItem(
      icon: Icons.tag_rounded,
      color: metadataColor,
      text: 'Build: ${record.buildId}',
    ),
    _EudBuildLogItem(
      icon: Icons.construction_rounded,
      color: metadataColor,
      text: 'Tool: euddraft ${record.toolVersion}',
    ),
    if (record.isTerminal)
      _EudBuildLogItem(
        icon: _buildRecordStatusIcon(record.status),
        color: _buildRecordStatusColor(record.status),
        text:
            '${_buildRecordStatusLabel(record.status)} • '
            '${record.exitCode == null ? 'exit code unavailable' : 'exit code ${record.exitCode}'}',
      ),
    _EudBuildLogItem(
      icon: Icons.schedule_rounded,
      color: metadataColor,
      text: 'Started: ${record.startedAt.toIso8601String()}',
    ),
    if (record.isTerminal)
      _EudBuildLogItem(
        icon: Icons.schedule_rounded,
        color: metadataColor,
        text: 'Completed: ${record.completedAt!.toIso8601String()}',
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
            '${_diagnosticLocationPrefix(diagnostic)}${diagnostic.message}',
      ),
  ];
  return items;
}

String _buildRecordStatusLabel(EudBuildRecordStatus status) {
  return switch (status) {
    EudBuildRecordStatus.running => 'Running',
    EudBuildRecordStatus.succeeded => 'Succeeded',
    EudBuildRecordStatus.failed => 'Failed',
    EudBuildRecordStatus.cancelled => 'Cancelled',
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: diagnostics.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final diagnostic = diagnostics[index];
        return Row(
          key: ValueKey('diagnostic-${diagnostic.code}-$index'),
          children: [
            Icon(
              _diagnosticIcon(diagnostic.severity),
              size: 16,
              color: _diagnosticColor(diagnostic.severity),
            ),
            const SizedBox(width: 8),
            Text(
              diagnostic.code,
              style: const TextStyle(
                color: Color(0xFFAAB5C8),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                diagnostic.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
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
        );
      },
    );
  }
}

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
            progress.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              progress.message ?? _phaseLabel(progress.phase),
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
                    ? 'Ready'
                    : currentProgress.message ??
                          _phaseLabel(currentProgress.phase),
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                showingEud
                    ? '${eudDocument.fileName}'
                          '${eudDocument.isDirty ? ' • Modified' : ' • Clean'}'
                    : session == null
                    ? 'No document'
                    : '${_fileName(session.sourcePath)}'
                          '${session.isDirty ? ' • Modified' : ' • Clean'}',
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

String _phaseLabel(OperationPhase phase) {
  return switch (phase) {
    OperationPhase.queued => 'Queued',
    OperationPhase.reading => 'Reading',
    OperationPhase.parsing => 'Parsing',
    OperationPhase.validating => 'Validating',
    OperationPhase.writing => 'Writing',
    OperationPhase.compiling => 'Compiling',
    OperationPhase.verifying => 'Verifying',
    OperationPhase.succeeded => 'Completed',
    OperationPhase.failed => 'Failed',
    OperationPhase.cancelled => 'Cancelled',
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
