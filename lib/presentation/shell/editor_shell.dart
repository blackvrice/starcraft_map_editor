import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/commands/editor_command_dispatcher.dart';

class EditorShell extends StatelessWidget {
  const EditorShell({required this.commandDispatcher, super.key});

  final EditorCommandDispatcher commandDispatcher;

  VoidCallback? _callbackFor(EditorCommandId command) {
    if (!commandDispatcher.canDispatch(command)) {
      return null;
    }

    return () => unawaited(commandDispatcher.dispatch(command));
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
                Expanded(child: _EditorWorkspace(openMap: openMap)),
                const Divider(height: 1),
                const _OutputPanel(),
                const Divider(height: 1),
                const _StatusBar(),
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
  const _EditorWorkspace({required this.openMap});

  final VoidCallback? openMap;

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
        Expanded(child: _MapWorkspace(openMap: openMap)),
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
  const _MapWorkspace({required this.openMap});

  final VoidCallback? openMap;

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 128,
      child: ColoredBox(
        color: Color(0xFF151A22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
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
            Divider(height: 1),
            Expanded(
              child: Center(
                child: Text(
                  'No problems detected',
                  style: TextStyle(color: Color(0xFF8994A8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: ColoredBox(
        color: Color(0xFF1B4E8A),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14),
              SizedBox(width: 6),
              Text('Ready', style: TextStyle(fontSize: 12)),
              Spacer(),
              Text('No document', style: TextStyle(fontSize: 12)),
              SizedBox(width: 18),
              Text('100%', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
