import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import 'settings_surface.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_player_settings_editor.dart';

class PlayerSettingsDialog extends StatefulWidget {
  const PlayerSettingsDialog({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<PlayerSettingsDialog> createState() => _PlayerSettingsDialogState();
}

class _PlayerSettingsDialogState extends State<PlayerSettingsDialog> {
  RawChkDocument? _snapshot;
  List<ChkPlayerSettingGroup> _groups = [];
  final _draft = <(int, ChkPlayerField), int>{};
  int _player = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _draft.clear();
    try {
      _groups = widget.controller.playerSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _snapshot = null;
      _groups = [];
    }
  }

  void _run(VoidCallback action) => setState(() {
    try {
      action();
      _reload();
    } catch (e) {
      _error = e.toString();
    }
  });

  Widget _field(ChkPlayerSettingGroup group) {
    final field = group.field;
    final stored = group.values != null && _player < group.values!.length
        ? group.values![_player]
        : null;
    final value = _draft[(_player, field)] ?? stored;
    final options = {...field.options};
    if (stored != null && !options.containsKey(stored)) {
      options[stored] = context.l10n.editorStoredIDPreserved(
        (stored).toString(),
      );
    }
    final label = switch (field) {
      ChkPlayerField.owner => context.l10n.editorSlotType,
      ChkPlayerField.race => context.l10n.editorRace,
      ChkPlayerField.color => context.l10n.editorColor,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          DropdownButton<int>(
            key: Key('player-settings-${field.name}'),
            isExpanded: true,
            value: value,
            hint: Text(context.l10n.editorUnavailable),
            items: [
              for (final option in options.entries)
                DropdownMenuItem(
                  value: option.key,
                  child: Text(
                    '${context.localizeEditorText(option.value)} (${option.key})',
                  ),
                ),
            ],
            onChanged: _snapshot != null && group.canEdit && _player < 8
                ? (next) => setState(() {
                    if (next == stored) {
                      _draft.remove((_player, field));
                    } else if (next != null) {
                      _draft[(_player, field)] = next;
                    }
                  })
                : null,
          ),
          if (group.issue != null)
            Text(context.localizeEditorText(group.issue!)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsSurface(
    controller: widget.controller,
    snapshot: _snapshot,
    hasDraft: _draft.isNotEmpty,
    onReload: () => setState(_reload),
    title: Text(context.l10n.editorPlayerSettings),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSelection(
              prefix: 'players',
              selectorKey: const Key('player-settings-player'),
              count: 12,
              copyCount: 8,
              idBase: 1,
              selected: _player,
              revision: _snapshot,
              label: (id) => context.l10n.editorPlayer203c6551(
                (id + 1).toString(),
                (id >= 8 ? context.l10n.editorReadOnly : "").toString(),
              ),
              onSelected: (id) => setState(() => _player = id),
              scope: context
                  .l10n
                  .editorSlotTypeRaceAndColorEditsForPlayablePlayers,
              onCopy: _snapshot == null || _player >= 8
                  ? null
                  : (ids) {
                      final copies = copySettingsDraft(
                        _draft,
                        (key) => key.$1 == _player,
                        (key, id) => (id, key.$2),
                        ids,
                      );
                      setState(() => _draft.addAll(copies));
                      return copies.length;
                    },
            ),
            if (_player >= 8)
              Text(
                context.l10n.editorOnlyTheEightPlayableSlotsCanBeEditedPlayers,
              ),
            for (final group in _groups) _field(group),
            Text(
              context.l10n.editorColorSettingsAreSavedToTheMapCanvasPreviews,
            ),
            Text(
              context.l10n
                  .editorPendingFieldChangesApplyUpdatesAllEditedPlayersSave(
                    (_draft.length).toString(),
                  ),
            ),
            if (_error != null)
              Text(
                context.localizeEditorText(_error!),
                key: const Key('player-settings-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final diagnostic
                in widget
                        .controller
                        .openMapController
                        .state
                        .session
                        ?.diagnostics ??
                    [])
              if (diagnostic.code.startsWith(
                ChkPlayerSettingsEditor.diagnosticPrefix,
              ))
                Text(context.diagnosticMessage(diagnostic)),
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
        key: const Key('player-settings-apply'),
        onPressed: _snapshot == null || _draft.isEmpty
            ? null
            : () => _run(() {
                widget.controller.applyPlayerSettings(
                  expectedDocument: _snapshot!,
                  changes: [
                    for (final e in _draft.entries)
                      ChkPlayerChange(e.key.$1, e.key.$2, e.value),
                  ],
                );
              }),
        child: Text(context.l10n.editorApply),
      ),
    ],
  );
}
