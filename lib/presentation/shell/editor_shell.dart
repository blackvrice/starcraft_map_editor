import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/commands/editor_command_dispatcher.dart';
import '../../application/documents/open_map_controller.dart';
import '../../application/documents/opened_map_session.dart';
import '../../application/operations/operation_progress.dart';
import '../../application/operations/operation_progress_controller.dart';
import '../../application/recent_projects/recent_project.dart';
import '../../application/recent_projects/recent_projects_service.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({
    required this.commandDispatcher,
    required this.openMapController,
    required this.operationProgressController,
    required this.recentProjectsService,
    super.key,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OpenMapController openMapController;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late Future<List<RecentProject>> _recentProjects;
  late StreamSubscription<OpenMapState> _openMapSubscription;

  @override
  void initState() {
    super.initState();
    _recentProjects = widget.recentProjectsService.load();
    _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
  }

  @override
  void didUpdateWidget(EditorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recentProjectsService != widget.recentProjectsService) {
      _recentProjects = widget.recentProjectsService.load();
    }
    if (oldWidget.openMapController != widget.openMapController) {
      unawaited(_openMapSubscription.cancel());
      _openMapSubscription = _listenForOpenedMaps(widget.openMapController);
    }
  }

  StreamSubscription<OpenMapState> _listenForOpenedMaps(
    OpenMapController controller,
  ) {
    return controller.changes.listen((state) {
      if (mounted) {
        setState(() {
          if (state.status == OpenMapStatus.opened) {
            _recentProjects = widget.recentProjectsService.load();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_openMapSubscription.cancel());
    super.dispose();
  }

  VoidCallback? _callbackFor(EditorCommandId command) {
    if (!widget.commandDispatcher.canDispatch(command)) {
      return null;
    }

    return () => unawaited(widget.commandDispatcher.dispatch(command));
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

  @override
  Widget build(BuildContext context) {
    final openMap = _callbackFor(EditorCommandId.openMap);
    final saveAs = _callbackFor(EditorCommandId.saveAs);
    final buildEud = _callbackFor(EditorCommandId.buildEud);

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
                  buildEud: buildEud,
                ),
                const Divider(height: 1),
                _EditorToolbar(
                  openMap: openMap,
                  saveAs: saveAs,
                  buildEud: buildEud,
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
                          diagnostics:
                              widget.openMapController.state.diagnostics,
                        ),
                        const Divider(height: 1),
                        _StatusBar(
                          progress: snapshot.data,
                          session: widget.openMapController.state.session,
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
    required this.buildEud,
  });

  final VoidCallback? openMap;
  final VoidCallback? saveAs;
  final VoidCallback? buildEud;

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
          menuChildren: const [
            MenuItemButton(onPressed: null, child: Text('Undo')),
            MenuItemButton(onPressed: null, child: Text('Redo')),
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
              onPressed: buildEud,
              child: const Text('Build EUD Map'),
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
    required this.buildEud,
  });

  final VoidCallback? openMap;
  final VoidCallback? saveAs;
  final VoidCallback? buildEud;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1000;

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
                if (!compact) ...[
                  const SizedBox(width: 12),
                  const _EnvironmentBadge(),
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
                    onPressed: saveAs,
                    tooltip: 'Save As',
                    icon: const Icon(Icons.save_outlined),
                  ),
                  IconButton.filled(
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
                    onPressed: saveAs,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save As'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
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
  const _EnvironmentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1D2738),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF33445F)),
      ),
      child: const Text(
        'Windows • SC:R',
        style: TextStyle(color: Color(0xFFAAC8FF), fontSize: 12),
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
  });

  final VoidCallback? openMap;
  final OpenMapState openMapState;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;

    return Row(
      children: [
        SizedBox(
          width: 210,
          child: _EditorPane(
            title: session == null ? 'Project / Layers' : 'Archive Entries',
            child: session == null
                ? const _EmptyPaneMessage(
                    icon: Icons.layers_outlined,
                    message: 'No map layers',
                  )
                : _ArchiveEntryList(session: session),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _MapWorkspace(
            openMap: openMap,
            openMapState: openMapState,
            recentProjects: recentProjects,
            recentProjectsError: recentProjectsError,
            recentProjectsLoading: recentProjectsLoading,
            onOpenRecentProject: onOpenRecentProject,
            onRemoveRecentProject: onRemoveRecentProject,
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 260,
          child: _EditorPane(
            title: 'Inspector',
            child: session == null
                ? const _EmptyPaneMessage(
                    icon: Icons.tune,
                    message: 'Nothing selected',
                  )
                : _MapInspector(session: session),
          ),
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
  });

  final VoidCallback? openMap;
  final OpenMapState openMapState;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;

  @override
  Widget build(BuildContext context) {
    final session = openMapState.session;
    if (session != null) {
      return _OpenedMapWorkspace(
        session: session,
        diagnostics: session.diagnostics,
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
  const _OpenedMapWorkspace({required this.session, required this.diagnostics});

  final OpenedMapSession session;
  final List<EditorDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    final metadataViews = session.metadataViews;
    final dimensions = metadataViews.dimensions.isEmpty
        ? null
        : metadataViews.dimensions.first;
    final version = metadataViews.versions.isEmpty
        ? null
        : metadataViews.versions.first;
    final tileset = metadataViews.tilesets.isEmpty
        ? null
        : metadataViews.tilesets.first;
    final scenarioType = metadataViews.types.isEmpty
        ? null
        : metadataViews.types.first;
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2738),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: Color(0xFF70A1FF),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fileName(session.sourcePath),
                            key: const Key('opened-map-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.sourcePath,
                            key: const Key('opened-map-path'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF929DB0),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SessionStatusChip(
                      restricted: session.requiresRestrictedEditing,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MapSummaryMetric(
                      label: 'CHK sections',
                      value: '${session.rawDocument.sections.length}',
                      icon: Icons.view_list_outlined,
                    ),
                    _MapSummaryMetric(
                      label: 'Map size',
                      value: dimensions == null
                          ? 'Unknown'
                          : '${dimensions.width} × ${dimensions.height}',
                      icon: Icons.aspect_ratio,
                    ),
                    _MapSummaryMetric(
                      label: 'Archive entries',
                      value:
                          '${session.archiveMetadata.entries.length} / '
                          '${session.archiveMetadata.totalEntryCount}',
                      icon: Icons.inventory_2_outlined,
                    ),
                    _MapSummaryMetric(
                      label: 'CHK size',
                      value: _formatBytes(session.scenarioChkSizeBytes),
                      icon: Icons.data_object,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SummaryCard(
                  title: 'Scenario summary',
                  rows: [
                    (
                      'Map version',
                      version == null
                          ? 'Not present'
                          : version.knownVersion == null
                          ? 'Unknown (${version.rawValue})'
                          : '${_humanizeEnumName(version.knownVersion!.name)} '
                                '(${version.rawValue})',
                    ),
                    (
                      'Scenario type',
                      scenarioType == null
                          ? 'Not present'
                          : scenarioType.fourCharacterCode,
                    ),
                    (
                      'Tileset',
                      tileset == null
                          ? 'Not present'
                          : tileset.knownTileset == null
                          ? 'Unknown (${tileset.rawValue})'
                          : _humanizeEnumName(tileset.knownTileset!.name),
                    ),
                    (
                      'MPQ format',
                      'Version ${session.archiveMetadata.formatVersion}',
                    ),
                    (
                      'Archive listing',
                      session.archiveMetadata.listingComplete
                          ? 'Complete'
                          : 'Partial',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  title: 'Open diagnostics',
                  rows: [
                    ('Blocking', '$blockingCount'),
                    ('Warnings', '$warningCount'),
                    (
                      'Mode',
                      session.requiresRestrictedEditing
                          ? 'Restricted read-only'
                          : 'Read-only preview',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionStatusChip extends StatelessWidget {
  const _SessionStatusChip({required this.restricted});

  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final color = restricted
        ? const Color(0xFFFFB454)
        : const Color(0xFF68D391);
    return Container(
      key: const Key('opened-map-mode'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        restricted ? 'Restricted' : 'Read-only preview',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MapSummaryMetric extends StatelessWidget {
  const _MapSummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF293242)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF70A1FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8994A8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF293242)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    rows[index].$1,
                    style: const TextStyle(
                      color: Color(0xFF8994A8),
                      fontSize: 12,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    rows[index].$2,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveEntryList extends StatelessWidget {
  const _ArchiveEntryList({required this.session});

  final OpenedMapSession session;

  @override
  Widget build(BuildContext context) {
    final entries = session.archiveMetadata.entries;
    return ListView.builder(
      key: const Key('archive-entry-list'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          dense: true,
          leading: Icon(
            entry.nameIsSynthetic
                ? Icons.help_outline
                : Icons.insert_drive_file_outlined,
            size: 18,
            color: entry.nameIsSynthetic
                ? const Color(0xFFFFB454)
                : const Color(0xFF7F8BA0),
          ),
          title: Text(
            entry.path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          subtitle: Text(
            _formatBytes(entry.uncompressedSizeBytes),
            style: const TextStyle(fontSize: 10),
          ),
        );
      },
    );
  }
}

class _MapInspector extends StatelessWidget {
  const _MapInspector({required this.session});

  final OpenedMapSession session;

  @override
  Widget build(BuildContext context) {
    final archive = session.archiveMetadata;
    return ListView(
      key: const Key('map-inspector'),
      padding: const EdgeInsets.all(12),
      children: [
        _InspectorValue(label: 'File', value: _fileName(session.sourcePath)),
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

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({required this.progress, required this.diagnostics});

  final OperationProgress? progress;
  final List<EditorDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ColoredBox(
        color: const Color(0xFF151A22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 36,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      'Problems',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 22),
                    Text('Output', style: TextStyle(color: Color(0xFF8994A8))),
                    SizedBox(width: 22),
                    Text(
                      'Build Log',
                      style: TextStyle(color: Color(0xFF8994A8)),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: progress != null && !progress!.isTerminal
                  ? _OperationSummary(progress: progress!)
                  : diagnostics.isNotEmpty
                  ? _DiagnosticList(diagnostics: diagnostics)
                  : progress == null
                  ? const Center(
                      child: Text(
                        'No problems detected',
                        style: TextStyle(color: Color(0xFF8994A8)),
                      ),
                    )
                  : _OperationSummary(progress: progress!),
            ),
          ],
        ),
      ),
    );
  }
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
          ],
        );
      },
    );
  }
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
  const _StatusBar({required this.progress, required this.session});

  final OperationProgress? progress;
  final OpenedMapSession? session;

  @override
  Widget build(BuildContext context) {
    final currentProgress = progress;
    final active = currentProgress != null && !currentProgress.isTerminal;
    final session = this.session;

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
                session == null ? 'No document' : _fileName(session.sourcePath),
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
