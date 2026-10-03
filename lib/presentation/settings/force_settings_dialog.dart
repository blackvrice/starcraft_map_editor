import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import 'settings_surface.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_force_settings_editor.dart';

class ForceSettingsDialog extends StatefulWidget {
  const ForceSettingsDialog({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<ForceSettingsDialog> createState() => _ForceSettingsDialogState();
}

class _ForceSettingsDialogState extends State<ForceSettingsDialog> {
  RawChkDocument? _snapshot;
  ChkForceSettings? _settings;
  final _assignments = <int, int>{};
  final _flags = <int, int>{};
  final _names = <int, String>{};
  final _name = TextEditingController();
  int _force = 0;
  int _player = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _reload() {
    _assignments.clear();
    _flags.clear();
    _names.clear();
    try {
      _settings = widget.controller.forceSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
    } catch (e) {
      _settings = null;
      _snapshot = null;
      _error = e.toString();
    }
    _name.text = _settings?.names[_force] ?? '';
  }

  void _run(VoidCallback action) => setState(() {
    try {
      action();
      _reload();
    } catch (e) {
      _error = e.toString();
    }
  });

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final storedAssignment = settings?.assignments[_player];
    final assignment = _assignments[_player] ?? storedAssignment;
    final flags = _flags[_force] ?? ((settings?.flags[_force] ?? 0) & 15);
    final dirty =
        _assignments.isNotEmpty || _flags.isNotEmpty || _names.isNotEmpty;
    return SettingsSurface(
      controller: widget.controller,
      snapshot: _snapshot,
      hasDraft: dirty,
      onReload: () => setState(_reload),
      title: Text(context.l10n.editorForceSettings),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.editorPlayerAssignment),
              SettingsSelection(
                prefix: 'force-players',
                selectorKey: const Key('force-player'),
                count: 8,
                idBase: 1,
                selected: _player,
                revision: _snapshot,
                label: (id) => context.l10n.editorPlayer((id + 1).toString()),
                onSelected: (id) => setState(() => _player = id),
                scope: context
                    .l10n
                    .editorCopiesOnlyTheEditedForceAssignmentToPlayers1,
                onCopy: settings == null
                    ? null
                    : (ids) {
                        final copies = copySettingsDraft(
                          _assignments,
                          (id) => id == _player,
                          (_, id) => id,
                          ids,
                        );
                        setState(() => _assignments.addAll(copies));
                        return copies.length;
                      },
              ),
              DropdownButton<int>(
                key: const Key('force-assignment'),
                value: assignment,
                isExpanded: true,
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        context.l10n.editorAssignToForce((i + 1).toString()),
                      ),
                    ),
                  if (storedAssignment != null && storedAssignment > 3)
                    DropdownMenuItem(
                      value: storedAssignment,
                      child: Text(
                        context.l10n.editorStoredIDPreserved(
                          (storedAssignment).toString(),
                        ),
                      ),
                    ),
                ],
                onChanged: settings == null
                    ? null
                    : (v) => setState(() {
                        if (v == settings.assignments[_player]) {
                          _assignments.remove(_player);
                        } else if (v != null) {
                          _assignments[_player] = v;
                        }
                      }),
              ),
              const Divider(),
              SettingsSelection(
                prefix: 'forces',
                selectorKey: const Key('force-selection'),
                count: 4,
                idBase: 1,
                selected: _force,
                revision: _snapshot,
                label: (id) => context.l10n.editorForce((id + 1).toString()),
                searchText: (id) => _names[id] ?? settings?.names[id] ?? '',
                onSelected: (id) => setState(() {
                  _force = id;
                  _name.text = _names[id] ?? settings?.names[id] ?? '';
                }),
                scope: context
                    .l10n
                    .editorCopiesEditedForceNamesAndOptionsOnlyPlayerAssignments,
                onCopy: settings == null
                    ? null
                    : (ids) {
                        final names = copySettingsDraft(
                          _names,
                          (id) => id == _force,
                          (_, id) => id,
                          ids,
                        );
                        final flags = copySettingsDraft(
                          _flags,
                          (id) => id == _force,
                          (_, id) => id,
                          ids,
                        );
                        setState(() {
                          _names.addAll(names);
                          _flags.addAll(flags);
                        });
                        return names.length + flags.length;
                      },
              ),
              TextField(
                key: const Key('force-name'),
                controller: _name,
                enabled:
                    settings != null && settings.nameIssues[_force] == null,
                decoration: InputDecoration(
                  labelText: context.l10n.editorForceName,
                ),
                onChanged: (v) => setState(() {
                  if (v == settings!.names[_force]) {
                    _names.remove(_force);
                  } else {
                    _names[_force] = v;
                  }
                }),
              ),
              if (settings?.nameIssues[_force] != null)
                Text(context.localizeEditorText(settings!.nameIssues[_force]!)),
              for (final option in {
                1: context.l10n.editorRandomizeStartLocations,
                2: context.l10n.editorAllies,
                4: context.l10n.editorAlliedVictory,
                8: context.l10n.editorSharedVision,
              }.entries)
                CheckboxListTile(
                  key: Key('force-flag-${option.key}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.value),
                  value: (flags & option.key) != 0,
                  onChanged: settings == null
                      ? null
                      : (v) => setState(() {
                          final next = v!
                              ? flags | option.key
                              : flags & ~option.key;
                          if (next == (settings.flags[_force] & 15)) {
                            _flags.remove(_force);
                          } else {
                            _flags[_force] = next;
                          }
                        }),
                ),
              Text(
                context.l10n.editorApplyUpdatesAllEditedPlayersAndForcesSaveAs,
              ),
              if (_error != null)
                Text(
                  context.localizeEditorText(_error!),
                  key: const Key('force-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('settings-undo'),
          onPressed: widget.controller.canUndo
              ? () => _run(widget.controller.undo)
              : null,
          child: Text(
            context.l10n.editorUndo(
              context.localizeEditorText(widget.controller.undoLabel ?? "—"),
            ),
          ),
        ),
        TextButton(
          key: const Key('settings-redo'),
          onPressed: widget.controller.canRedo
              ? () => _run(widget.controller.redo)
              : null,
          child: Text(
            context.l10n.editorRedo(
              context.localizeEditorText(widget.controller.redoLabel ?? "—"),
            ),
          ),
        ),
        TextButton(
          key: const Key('settings-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.editorCancel),
        ),
        FilledButton(
          key: const Key('force-apply'),
          onPressed: _snapshot == null || !dirty
              ? null
              : () => _run(() {
                  widget.controller.applyForceSettings(
                    expectedDocument: _snapshot!,
                    assignments: _assignments,
                    flags: _flags,
                    names: _names,
                  );
                }),
          child: Text(context.l10n.editorApply),
        ),
      ],
    );
  }
}
