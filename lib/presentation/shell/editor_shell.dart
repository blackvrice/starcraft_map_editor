import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/commands/editor_command_dispatcher.dart';
import '../../application/operations/operation_progress.dart';
import '../../application/operations/operation_progress_controller.dart';
import '../../application/recent_projects/recent_project.dart';
import '../../application/recent_projects/recent_projects_service.dart';

class EditorShell extends StatefulWidget {
  const EditorShell({
    required this.commandDispatcher,
    required this.operationProgressController,
    required this.recentProjectsService,
    super.key,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

class _EditorShellState extends State<EditorShell> {
  late Future<List<RecentProject>> _recentProjects;

  @override
  void initState() {
    super.initState();
    _recentProjects = widget.recentProjectsService.load();
  }

  @override
  void didUpdateWidget(EditorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recentProjectsService != widget.recentProjectsService) {
      _recentProjects = widget.recentProjectsService.load();
    }
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
                  child: FutureBuilder<List<RecentProject>>(
                    future: _recentProjects,
                    builder: (context, snapshot) {
                      return _EditorWorkspace(
                        openMap: openMap,
                        recentProjects: snapshot.data ?? const [],
                        recentProjectsError: snapshot.hasError,
                        recentProjectsLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                        onOpenRecentProject:
                            widget.commandDispatcher.canDispatch(
                              EditorCommandId.openMap,
                            )
                            ? _openRecentProject
                            : null,
                        onRemoveRecentProject: _removeRecentProject,
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
                        _OutputPanel(progress: snapshot.data),
                        const Divider(height: 1),
                        _StatusBar(progress: snapshot.data),
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
    required this.recentProjects,
    required this.recentProjectsError,
    required this.recentProjectsLoading,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
  });

  final VoidCallback? openMap;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 210,
          child: _EditorPane(
            title: 'Project / Layers',
            child: _EmptyPaneMessage(
              icon: Icons.layers_outlined,
              message: 'No map layers',
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _MapWorkspace(
            openMap: openMap,
            recentProjects: recentProjects,
            recentProjectsError: recentProjectsError,
            recentProjectsLoading: recentProjectsLoading,
            onOpenRecentProject: onOpenRecentProject,
            onRemoveRecentProject: onRemoveRecentProject,
          ),
        ),
        const VerticalDivider(width: 1),
        const SizedBox(
          width: 260,
          child: _EditorPane(
            title: 'Inspector',
            child: _EmptyPaneMessage(
              icon: Icons.tune,
              message: 'Nothing selected',
            ),
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
    required this.recentProjects,
    required this.recentProjectsError,
    required this.recentProjectsLoading,
    required this.onOpenRecentProject,
    required this.onRemoveRecentProject,
  });

  final VoidCallback? openMap;
  final List<RecentProject> recentProjects;
  final bool recentProjectsError;
  final bool recentProjectsLoading;
  final ValueChanged<RecentProject>? onOpenRecentProject;
  final ValueChanged<RecentProject> onRemoveRecentProject;

  @override
  Widget build(BuildContext context) {
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
  const _OutputPanel({required this.progress});

  final OperationProgress? progress;

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
              child: progress == null
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
  const _StatusBar({required this.progress});

  final OperationProgress? progress;

  @override
  Widget build(BuildContext context) {
    final currentProgress = progress;
    final active = currentProgress != null && !currentProgress.isTerminal;

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
              const Text('No document', style: TextStyle(fontSize: 12)),
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
