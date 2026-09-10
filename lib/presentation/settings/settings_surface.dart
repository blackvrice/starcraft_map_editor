import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';

class SettingsPageScope extends InheritedWidget {
  const SettingsPageScope({
    required this.reportDraft,
    required super.child,
    super.key,
  });
  final ValueChanged<bool> reportDraft;
  @override
  bool updateShouldNotify(SettingsPageScope oldWidget) => false;
}

/// Shares the existing editors between standalone dialogs and the tab host.
class SettingsSurface extends StatefulWidget {
  const SettingsSurface({
    required this.controller,
    required this.snapshot,
    required this.hasDraft,
    required this.onReload,
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });
  final ObjectEditingController controller;
  final RawChkDocument? snapshot;
  final bool hasDraft;
  final VoidCallback onReload;
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  @override
  State<SettingsSurface> createState() => _SettingsSurfaceState();
}

class _SettingsSurfaceState extends State<SettingsSurface> {
  Object? _scheduled;
  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SettingsPageScope>();
    if (scope == null) {
      return AlertDialog(
        title: widget.title,
        content: widget.content,
        actions: widget.actions,
      );
    }
    scope.reportDraft(widget.hasDraft);
    return StreamBuilder(
      stream: widget.controller.openMapController.changes,
      builder: (context, _) {
        final current =
            widget.controller.openMapController.state.session?.rawDocument;
        final stale = !identical(current, widget.snapshot);
        if (stale && !widget.hasDraft && !identical(_scheduled, current)) {
          _scheduled = current;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !widget.hasDraft) widget.onReload();
          });
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: widget.title),
                  if (widget.hasDraft) const Text('Unapplied draft'),
                ],
              ),
              if (stale)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'The map changed in another editor or through Undo/Redo. Reload before applying this tab.',
                      ),
                    ),
                    TextButton(
                      key: const Key('settings-reload'),
                      onPressed: widget.onReload,
                      child: const Text('Reload and discard this draft'),
                    ),
                  ],
                ),
              Expanded(
                child: SizedBox(width: double.infinity, child: widget.content),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  if (!widget.actions.any(
                    (action) =>
                        action is TextButton &&
                        action.child is Text &&
                        ((action.child as Text).data ?? '').startsWith('Undo:'),
                  )) ...[
                    TextButton(
                      onPressed: widget.controller.canUndo
                          ? () {
                              widget.controller.undo();
                              widget.onReload();
                            }
                          : null,
                      child: Text(
                        'Undo: ${widget.controller.undoLabel ?? "—"}',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.controller.canRedo
                          ? () {
                              widget.controller.redo();
                              widget.onReload();
                            }
                          : null,
                      child: Text(
                        'Redo: ${widget.controller.redoLabel ?? "—"}',
                      ),
                    ),
                  ],
                  for (final action in widget.actions)
                    if (action is TextButton &&
                        action.child is Text &&
                        (action.child as Text).data == 'Cancel')
                      TextButton(
                        onPressed: widget.onReload,
                        child: const Text('Discard tab draft'),
                      )
                    else if (stale && action is FilledButton)
                      FilledButton(
                        key: action.key,
                        onPressed: null,
                        child: action.child,
                      )
                    else
                      action,
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
