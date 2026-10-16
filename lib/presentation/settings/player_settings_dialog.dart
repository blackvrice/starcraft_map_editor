import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import 'settings_surface.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_player_settings_editor.dart';
import '../../domain/chk/typed/chk_player_colors.dart';

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
  final _colors = <int, List<String>>{};
  bool _advanced = false;
  int _player = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _draft.clear();
    _colors.clear();
    try {
      _groups = widget.controller.playerSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _advanced = _snapshot!.sections.any((s) => s.name == 'CRGB');
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

  Map<int, ChkPlayerColor> _parsedColors() => {
    for (final e in _colors.entries)
      e.key: ChkPlayerColor(
        int.parse(e.value[0]),
        int.parse(e.value[1]),
        int.parse(e.value[2]),
        int.parse(e.value[3]),
      ),
  };

  Widget _colorDiff() {
    if (_snapshot == null || _colors.isEmpty) return const SizedBox.shrink();
    try {
      final next = ChkPlayerColors.edit(_snapshot!, _parsedColors());
      final differences = <String>[];
      for (var s = 0; s < next.sections.length; s++) {
        final after = next.sections[s],
            before = s < _snapshot!.sections.length
                ? _snapshot!.sections[s].payload
                : <int>[];
        if (s < _snapshot!.sections.length &&
            identical(after, _snapshot!.sections[s])) {
          continue;
        }
        for (var i = 0; i < after.payload.length; i++) {
          if (i >= before.length || before[i] != after.payload[i]) {
            differences.add(
              '${after.name}[$i]: ${i < before.length ? before[i] : "-"} -> ${after.payload[i]}',
            );
          }
        }
      }
      return ExpansionTile(
        title: Text(context.l10n.settingsPreviewBytes),
        children: [SelectableText(differences.join('\n'))],
      );
    } catch (e) {
      return Text(e.toString(), key: const Key('player-color-preview-error'));
    }
  }

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

  Widget _colorFields() {
    final l10n = context.l10n;
    if (_snapshot == null || _player >= 8) return const SizedBox.shrink();
    List<ChkPlayerColor> current;
    try {
      current = ChkPlayerColors.read(_snapshot!);
    } catch (e) {
      return Text(e.toString());
    }
    final c = current[_player];
    final values =
        _colors[_player] ??
        ['${c.mode}', '${c.red}', '${c.green}', '${c.blue}'];
    void change(int index, String text) => setState(() {
      _colors[_player] = values.toList()..[index] = text;
    });
    final hasCrgb = _snapshot!.sections.any((s) => s.name == 'CRGB');
    final mode = int.parse(values[0]);
    final channelValues = values.skip(1).map(int.tryParse).toList();
    final preview = channelValues.any((v) => v == null)
        ? null
        : ChkPlayerColor(
            mode,
            channelValues[0]!,
            channelValues[1]!,
            channelValues[2]!,
          ).argb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const Key('player-advanced-color'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.playerAdvancedColor),
          value: _advanced,
          onChanged: hasCrgb
              ? null
              : (v) => setState(() {
                  _advanced = v!;
                  _colors.clear();
                  if (v) {
                    for (var i = 0; i < 8; i++) {
                      final color = current[i];
                      _colors[i] = [
                        '${color.mode}',
                        '${color.red}',
                        '${color.green}',
                        '${_draft[(i, ChkPlayerField.color)] ?? color.blue}',
                      ];
                    }
                    _draft.removeWhere(
                      (key, _) => key.$2 == ChkPlayerField.color,
                    );
                  }
                }),
        ),
        if (_advanced) ...[
          DropdownButton<int>(
            key: const Key('player-color-mode'),
            isExpanded: true,
            value: mode,
            items: [
              for (final e in {
                0: l10n.playerColorRandom,
                1: l10n.playerColorChoice,
                2: l10n.playerColorRgb,
                3: l10n.playerColorId,
                if (mode > 3) mode: l10n.editorStoredIDPreserved('$mode'),
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => change(0, '$v'),
          ),
          if (preview != null)
            Container(
              key: const Key('player-color-swatch'),
              height: 24,
              color: Color(preview),
            ),
          for (final index
              in mode == 2
                  ? [1, 2, 3]
                  : mode == 3
                  ? [3]
                  : <int>[])
            TextFormField(
              key: ValueKey(('player-color-channel', _player, index, mode)),
              initialValue: values[index],
              decoration: InputDecoration(
                labelText: mode == 3
                    ? l10n.playerColorId
                    : ['R', 'G', 'B'][index - 1],
              ),
              onChanged: (v) => change(index, v),
            ),
          Text(l10n.playerColorPreviewLimit),
          Text(l10n.settingsVersionUpgrade),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SettingsSurface(
    controller: widget.controller,
    snapshot: _snapshot,
    hasDraft: _draft.isNotEmpty || _colors.isNotEmpty,
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
                      setState(() {
                        _draft.addAll(copies);
                        if (_colors.containsKey(_player)) {
                          for (final id in ids) {
                            _colors[id] = _colors[_player]!.toList();
                          }
                        }
                      });
                      return copies.length +
                          (_colors.containsKey(_player) ? ids.length : 0);
                    },
            ),
            if (_player >= 8)
              Text(
                context.l10n.editorOnlyTheEightPlayableSlotsCanBeEditedPlayers,
              ),
            for (final group in _groups)
              if (group.field != ChkPlayerField.color || !_advanced)
                _field(group),
            _colorFields(),
            _colorDiff(),
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
        onPressed: _snapshot == null || (_draft.isEmpty && _colors.isEmpty)
            ? null
            : () => _run(() {
                widget.controller.applyPlayerSettings(
                  expectedDocument: _snapshot!,
                  changes: [
                    for (final e in _draft.entries)
                      ChkPlayerChange(e.key.$1, e.key.$2, e.value),
                  ],
                  colorChanges: _parsedColors(),
                );
              }),
        child: Text(context.l10n.editorApply),
      ),
    ],
  );
}
