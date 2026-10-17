import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/documents/document_workspace_controller.dart';
import '../application/documents/new_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/settings/app_language_controller.dart';
import '../application/terrain/tile_placement_catalog_loader.dart';
import '../presentation/documents/new_map_dialog.dart';
import '../presentation/documents/recovery_dialog.dart';
import '../presentation/localization/l10n.dart';
import '../presentation/shell/editor_shell.dart';
import 'app.dart';
import '../application/editing/document_transfer_controller.dart';
import '../presentation/documents/document_transfer_dialog.dart';
import '../presentation/documents/mixed_document_transfer_dialog.dart';
import '../application/editing/basic_editing_controller.dart';
import '../application/editing/mixed_clipboard_controller.dart';

enum _CloseChoice { cancel, save, discard }

/// Each keyed shell stays mounted, preserving drafts, camera and local focus.
class DocumentWorkspaceHost extends StatefulWidget {
  const DocumentWorkspaceHost({
    required this.workspace,
    this.language,
    super.key,
  });
  final DocumentWorkspaceController<EditorAppDependencies> workspace;
  final AppLanguageController? language;
  @override
  State<DocumentWorkspaceHost> createState() => _DocumentWorkspaceHostState();
}

class _DocumentWorkspaceHostState extends State<DocumentWorkspaceHost>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _subscription;
  bool _closing = false;
  late final String? _initialId = widget.workspace.active?.id;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.workspace.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(widget.workspace.dispose());
    super.dispose();
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.workspaceRequestFailed}\n$e')),
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      _error(e);
    }
  }

  String _name(WorkspaceDocument<EditorAppDependencies> d) {
    final session = d.maps.state.session;
    if (session == null) {
      return d.sources.state.document?.fileName ?? context.l10n.workspaceStart;
    }
    return session.sourcePath?.replaceAll('\\', '/').split('/').last ??
        context.l10n.workspaceUntitled(d.id.split('-').last);
  }

  Future<void> _newMap() => _run(() async {
    if (widget.workspace.active?.maps.editHistory.isTransactionActive ??
        false) {
      throw StateError('WORKSPACE_DOCUMENT_BUSY');
    }
    final workspace = widget.workspace,
        d = workspace.prepareDocument(),
        deps = d.value;
    final catalog = deps.placementCatalogController;
    final controller = NewMapController(
      maps: d.maps,
      terrainGateway: deps.isomFillController?.gateway,
      assets: () => deps.starCraftDataAssetSettingsController.state,
      loader: catalog.catalogGateway == null || catalog.tileAtlasGateway == null
          ? null
          : TilePlacementCatalogLoader(
              catalogGateway: catalog.catalogGateway!,
              tileAtlasGateway: catalog.tileAtlasGateway!,
            ),
    );
    var published = false;
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => NewMapDialog(controller: controller),
      );
      if (created == true && mounted) {
        workspace.publish(d);
        published = true;
      }
    } finally {
      controller.dispose();
      if (!published) await workspace.abandon(d);
    }
  });
  Future<void> _recovery() => _run(() async {
    final workspace = widget.workspace, d = workspace.prepareDocument();
    var published = false;
    try {
      final controller = d.autosave;
      if (controller == null) return;
      await controller.initialize();
      await controller.refresh();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => RecoveryDialog(controller: controller),
      );
      if (mounted &&
          (d.maps.state.session != null ||
              d.sources.state.document != null ||
              d.projects?.projects.project != null)) {
        workspace.publish(d);
        published = true;
      }
    } finally {
      if (!published) await workspace.abandon(d);
    }
  });

  Future<void> _transfer() => _run(() async {
    final workspace = widget.workspace, source = workspace.active;
    if (source == null || source.maps.state.session == null) return;
    final controller = DocumentTransferController(
      workspace: workspace,
      access: (d) => DocumentTransferAccess(
        d.value.mapLayerController,
        d.value.objectEditingController,
      ),
    );
    try {
      final target = await showDialog<String>(
        context: context,
        builder: (_) => DocumentTransferDialog(
          controller: controller,
          nameOf: _name,
          initialSource: source,
        ),
      );
      if (target != null && mounted) workspace.activate(target);
    } finally {
      controller.dispose();
    }
  });

  Future<void> _transferRegion() => _run(() async {
    final workspace = widget.workspace, source = workspace.active;
    if (source == null || source.maps.state.session == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => MixedDocumentTransferDialog(
        workspace: workspace,
        source: source,
        nameOf: _name,
        loader: source.value.isomFillController,
        textures: source.value.terrainTileTextureController.state,
        createController: (target) => BasicEditingController(
          maps: source.maps,
          layers: source.value.mapLayerController,
          mixedClipboard: MixedClipboardController.betweenDocuments(
            maps: source.maps,
            layers: source.value.mapLayerController,
            targetMaps: target.maps,
            targetLayers: target.value.mapLayerController,
            isAvailable: () =>
                workspace.contains(source) &&
                workspace.contains(target) &&
                !source.busy &&
                !target.busy,
            apply: (expected, result, label) {
              if (identical(expected, result)) return false;
              target.value.objectEditingController.applyDocumentTransfer(
                expectedDocument: expected,
                updatedDocument: result,
                resourceEdits: target.maps.state.session!.resourceEdits,
                includeTerrain: true,
              );
              return true;
            },
          ),
        ),
      ),
    );
  });

  Future<int?> _confirm(WorkspaceDocument<EditorAppDependencies> d) async {
    final w = widget.workspace;
    while (w.contains(d)) {
      if (!mounted) return null;
      if (d.busy) {
        _error(context.l10n.workspaceBusy);
        return null;
      }
      final revision = d.revision;
      if (d.maps.state.session == null &&
          d.sources.state.document == null &&
          d.projects?.projects.project == null) {
        return revision;
      }
      final l = context.l10n;
      final choice = await showDialog<_CloseChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.workspaceCloseTitle(_name(d))),
          content: Text(l.workspaceCloseWarning),
          actions: [
            TextButton(
              key: const Key('workspace-close-cancel'),
              onPressed: () => Navigator.pop(context, _CloseChoice.cancel),
              child: Text(l.recoveryCancel),
            ),
            if (d.maps.state.session != null)
              TextButton(
                key: const Key('workspace-close-save'),
                onPressed: () => Navigator.pop(context, _CloseChoice.save),
                child: Text(l.menuSaveAs),
              ),
            TextButton(
              key: const Key('workspace-close-discard'),
              onPressed: () => Navigator.pop(context, _CloseChoice.discard),
              child: Text(l.workspaceDiscardClose),
            ),
          ],
        ),
      );
      if (choice == null || choice == _CloseChoice.cancel) return null;
      if (!w.contains(d)) return null;
      if (d.revision != revision || d.busy) {
        _error(l.workspaceChanged);
        continue;
      }
      if (choice == _CloseChoice.save) {
        final saved = await d.saves.saveAs();
        if (saved.status != SaveMapStatus.saved) {
          _error(l.workspaceSaveIncomplete);
          return null;
        }
        // Map Save As does not save project/source or unapplied form drafts.
        continue;
      }
      return revision;
    }
    return null;
  }

  Future<void> _close(WorkspaceDocument<EditorAppDependencies> d) async {
    if (_closing) return;
    setState(() => _closing = true);
    try {
      final revision = await _confirm(d);
      if (revision == null || !mounted) return;
      if (!await widget.workspace.close(
        d,
        expectedRevision: revision,
        discardChanges: true,
      )) {
        if (mounted) _error(context.l10n.workspaceChanged);
        return;
      }
      if (mounted && widget.workspace.documents.isEmpty) {
        widget.workspace.addEmpty();
      }
    } on Object catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (_closing || widget.workspace.busy) {
      _error(context.l10n.workspaceBusy);
      return AppExitResponse.cancel;
    }
    setState(() => _closing = true);
    try {
      final approvals = <WorkspaceDocument<EditorAppDependencies>, int>{};
      for (final d in widget.workspace.documents) {
        final revision = await _confirm(d);
        if (revision == null) return AppExitResponse.cancel;
        approvals[d] = revision;
      }
      // Exit is all-or-nothing. A cancelled later prompt must not close A.
      if (widget.workspace.busy ||
          widget.workspace.documents.length != approvals.length ||
          approvals.entries.any(
            (e) =>
                !widget.workspace.contains(e.key) || e.key.revision != e.value,
          )) {
        if (mounted) _error(context.l10n.workspaceChanged);
        return AppExitResponse.cancel;
      }
      return AppExitResponse.exit;
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Widget _editor(WorkspaceDocument<EditorAppDependencies> entry) {
    final d = entry.value;
    return EditorShell(
      key: ValueKey('workspace-editor-${entry.id}'),
      onNewMap: _newMap,
      onRecovery: _recovery,
      showStartupRecovery: entry.id == _initialId,
      loadGlobalSettings: entry.id == _initialId,
      isDocumentActive: identical(widget.workspace.active, entry),
      autosaveController: d.autosaveController,
      isomFillController: d.isomFillController,
      brushLibrary: d.brushLibrary,
      commandDispatcher: d.commandDispatcher,
      openMapController: d.openMapController,
      saveMapController: d.saveMapController,
      eudBuildController: d.eudBuildController,
      eudSourceController: d.eudSourceController,
      eudProjectWorkspace: d.eudProjectWorkspace,
      eudToolSettingsController: d.eudToolSettingsController,
      eudBuildPreparationController: d.eudBuildPreparationController,
      operationProgressController: d.operationProgressController,
      recentProjectsService: d.recentProjectsService,
      starCraftDataAssetSettingsController:
          d.starCraftDataAssetSettingsController,
      terrainEditingController: d.terrainEditingController,
      mapLayerController: d.mapLayerController,
      objectEditingController: d.objectEditingController,
      objectPaletteController: d.objectPaletteController,
      placementCatalogController: d.placementCatalogController,
      terrainTileTextureController: d.terrainTileTextureController,
      objectSpriteTextureController: d.objectSpriteTextureController,
      languageController: widget.language,
    );
  }

  void _cycle({bool previous = false}) {
    final docs = widget.workspace.documents;
    if (docs.length < 2) return;
    final index = docs.indexOf(widget.workspace.active!);
    try {
      widget.workspace.activate(
        docs[(index + (previous ? -1 : 1)) % docs.length].id,
      );
    } on Object catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace, docs = w.documents, l = context.l10n;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
            _cycle(),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () =>
            _cycle(previous: true),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
          if (w.active != null) unawaited(_close(w.active!));
        },
      },
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final d in docs)
                            Semantics(
                              selected: identical(w.active, d),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 120,
                                  maxWidth: 250,
                                ),
                                decoration: BoxDecoration(
                                  color: identical(w.active, d)
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest
                                      : null,
                                  border: Border(
                                    bottom: BorderSide(
                                      width: 2,
                                      color: identical(w.active, d)
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message:
                                            d.maps.state.session?.sourcePath ??
                                            _name(d),
                                        child: TextButton(
                                          key: ValueKey(
                                            'workspace-tab-${d.id}',
                                          ),
                                          onPressed: _closing
                                              ? null
                                              : () {
                                                  try {
                                                    w.activate(d.id);
                                                  } on Object catch (e) {
                                                    _error(e);
                                                  }
                                                },
                                          child: Text(
                                            '${d.dirty ? '* ' : ''}${_name(d)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (d.busy)
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    IconButton(
                                      key: ValueKey('workspace-close-${d.id}'),
                                      tooltip: l.workspaceClose,
                                      onPressed: _closing || d.busy
                                          ? null
                                          : () => unawaited(_close(d)),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('workspace-transfer'),
                    tooltip: l.transferTitle,
                    onPressed:
                        _closing ||
                            w.active?.maps.state.session == null ||
                            docs
                                    .where((d) => d.maps.state.session != null)
                                    .length <
                                2
                        ? null
                        : _transfer,
                    icon: const Icon(Icons.copy_all),
                  ),
                  IconButton(
                    key: const Key('workspace-transfer-region'),
                    tooltip: l.transferRegionTitle,
                    onPressed:
                        _closing ||
                            w.active?.maps.state.session == null ||
                            docs
                                    .where((d) => d.maps.state.session != null)
                                    .length <
                                2
                        ? null
                        : _transferRegion,
                    icon: const Icon(Icons.select_all),
                  ),
                  IconButton(
                    key: const Key('workspace-new'),
                    tooltip: l.menuNewMap,
                    onPressed: _closing ? null : _newMap,
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    key: const Key('workspace-open'),
                    tooltip: l.menuOpenMap,
                    onPressed: _closing
                        ? null
                        : () => _run(() => w.open().then((_) {})),
                    icon: const Icon(Icons.folder_open),
                  ),
                ],
              ),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final d in docs)
                          Offstage(
                            key: ValueKey('workspace-view-${d.id}'),
                            offstage: !identical(w.active, d),
                            child: TickerMode(
                              enabled: identical(w.active, d),
                              child: ExcludeFocus(
                                excluding: !identical(w.active, d),
                                child: _editor(d),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
