import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
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
                  if (widget.hasDraft) Text(context.l10n.editorUnappliedDraft),
                ],
              ),
              if (stale)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context
                            .l10n
                            .editorTheMapChangedInAnotherEditorOrThroughUndo,
                      ),
                    ),
                    TextButton(
                      key: const Key('settings-reload'),
                      onPressed: widget.onReload,
                      child: Text(context.l10n.editorReloadAndDiscardThisDraft),
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
                    (action) => action.key == const Key('settings-undo'),
                  )) ...[
                    TextButton(
                      key: const Key('settings-undo'),
                      onPressed: widget.controller.canUndo
                          ? () {
                              widget.controller.undo();
                              widget.onReload();
                            }
                          : null,
                      child: Text(
                        context.l10n.editorUndo(
                          context.localizeEditorText(
                            widget.controller.undoLabel ?? "—",
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('settings-redo'),
                      onPressed: widget.controller.canRedo
                          ? () {
                              widget.controller.redo();
                              widget.onReload();
                            }
                          : null,
                      child: Text(
                        context.l10n.editorRedo(
                          context.localizeEditorText(
                            widget.controller.redoLabel ?? "—",
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (final action in widget.actions)
                    if (action.key == const Key('settings-cancel'))
                      TextButton(
                        key: const Key('settings-discard'),
                        onPressed: widget.onReload,
                        child: Text(context.l10n.editorDiscardTabDraft),
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
