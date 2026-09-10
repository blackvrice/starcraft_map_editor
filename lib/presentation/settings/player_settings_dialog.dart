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
      options[stored] = 'Stored ID $stored (preserved)';
    }
    final label = switch (field) {
      ChkPlayerField.owner => 'Slot type',
      ChkPlayerField.race => 'Race',
      ChkPlayerField.color => 'Color',
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
            hint: const Text('Unavailable'),
            items: [
              for (final option in options.entries)
                DropdownMenuItem(
                  value: option.key,
                  child: Text('${option.value} (${option.key})'),
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
          if (group.issue != null) Text(group.issue!),
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
    title: const Text('Player Settings'),
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
              label: (id) => 'Player ${id + 1}${id >= 8 ? " (read-only)" : ""}',
              onSelected: (id) => setState(() => _player = id),
              scope:
                  'Slot type, race and color edits for playable Players 1–8 only.',
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
              const Text(
                'Only the eight playable slots can be edited. Players 9–12 have no COLR color entry.',
              ),
            for (final group in _groups) _field(group),
            const Text(
              'Color settings are saved to the map. Canvas previews currently use default player colors.',
            ),
            Text(
              '${_draft.length} pending field changes. Apply updates all edited players; Save As writes the map.',
            ),
            if (_error != null)
              Text(
                _error!,
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
                Text(diagnostic.message),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: widget.controller.canUndo
            ? () => _run(widget.controller.undo)
            : null,
        child: Text('Undo: ${widget.controller.undoLabel ?? "—"}'),
      ),
      TextButton(
        onPressed: widget.controller.canRedo
            ? () => _run(widget.controller.redo)
            : null,
        child: Text('Redo: ${widget.controller.redoLabel ?? "—"}'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
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
        child: const Text('Apply'),
      ),
    ],
  );
}
