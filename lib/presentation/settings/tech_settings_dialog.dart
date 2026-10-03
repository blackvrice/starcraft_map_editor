import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'default_settings_names.dart';
import 'settings_surface.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_tech_settings_editor.dart';

class TechSettingsDialog extends StatefulWidget {
  const TechSettingsDialog({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<TechSettingsDialog> createState() => _TechSettingsDialogState();
}

class _TechSettingsDialogState extends State<TechSettingsDialog> {
  ChkTechSettings? _settings;
  RawChkDocument? _snapshot;
  final _draft = <TechSettingKey, String>{};
  int _tech = 0;
  int _player = -1;
  int _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _draft.clear();
    _generation++;
    try {
      _settings = widget.controller.techSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
      if (_tech >= _settings!.count) _tech = 0;
    } catch (e) {
      _settings = null;
      _snapshot = null;
      _error = e.toString();
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
  TechSettingKey _key(ChkTechField field) =>
      (_tech, field.isCost || _player == -1 ? null : _player, field);
  String _text(TechSettingKey key) => _draft[key] ?? '${_settings!.value(key)}';
  void _change(TechSettingKey key, String text) => setState(() {
    if (text == '${_settings!.value(key)}') {
      _draft.remove(key);
    } else {
      _draft[key] = text;
    }
  });
  Widget _flag(
    ChkTechField field,
    String zero,
    String one, {
    bool enabled = true,
  }) {
    final key = _key(field);
    final stored = _settings!.value(key);
    final value = int.parse(_text(key));
    if (value == 0 || value == 1) {
      return CheckboxListTile(
        key: Key('tech-${field.name}'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(one),
        value: value == 1,
        onChanged: enabled ? (v) => _change(key, v == true ? '1' : '0') : null,
      );
    }
    return DropdownButton<int>(
      key: Key('tech-${field.name}'),
      value: int.parse(_text(key)),
      isExpanded: true,
      items: [
        DropdownMenuItem(value: 0, child: Text(zero)),
        DropdownMenuItem(value: 1, child: Text(one)),
        if (stored > 1)
          DropdownMenuItem(
            value: stored,
            child: Text(
              context.l10n.editorStoredFlagPreserved((stored).toString()),
            ),
          ),
      ],
      onChanged: enabled ? (v) => _change(key, '$v') : null,
    );
  }

  Widget _number(ChkTechField field, bool enabled) {
    final key = _key(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: ValueKey(('tech-input', _generation, key)),
        initialValue: _text(key),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: context.localizeEditorText(field.label),
          helperText: '0–${field.limit}',
        ),
        onChanged: (text) => _change(key, text),
      ),
    );
  }

  void _apply() {
    final changes = <TechSettingKey, int>{};
    for (final e in _draft.entries) {
      try {
        // Existing nonstandard flags may be retained without normalization.
        changes[e.key] = e.value == '${_settings!.value(e.key)}'
            ? _settings!.value(e.key)
            : e.key.$3.parse(e.value);
      } catch (error) {
        throw FormatException(
          'Tech #${e.key.$1}, ${e.key.$2 == null ? "map" : "Player ${e.key.$2! + 1}"}: $error',
        );
      }
    }
    widget.controller.applyTechSettings(
      expectedDocument: _snapshot!,
      changes: changes,
    );
  }

  String _effective() {
    int? player = _player == -1 ? null : _player;
    if (player != null) {
      final flag = int.parse(_text((_tech, player, ChkTechField.inherit)));
      if (flag > 1) {
        return context.l10n.editorEffectiveStateUnknownStoredFlagPreserved;
      }
      if (flag == 1) player = null;
    }
    String state(ChkTechField field) =>
        switch (int.parse(_text((_tech, player, field)))) {
          0 => context.l10n.editorNo,
          1 => context.l10n.editorYes,
          _ => context.l10n.editorUnknown,
        };
    return context.l10n.editorEffectiveStateAvailableResearched(
      (state(ChkTechField.available)).toString(),
      (state(ChkTechField.researched)).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final costEnabled =
        settings != null && settings.data.containsKey(settings.costName);
    final stateEnabled =
        settings != null && settings.data.containsKey(settings.stateName);
    return SettingsSurface(
      controller: widget.controller,
      snapshot: _snapshot,
      hasDraft: _draft.isNotEmpty,
      onReload: () => setState(_reload),
      title: Text(context.l10n.editorTechSettings),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings != null) ...[
                Text(
                  context.l10n.editorEditing(
                    (settings.costName).toString(),
                    (settings.stateName).toString(),
                    (settings.hasAlternate
                            ? context.l10n.editorAlternateSectionsPreserved
                            : "")
                        .toString(),
                  ),
                ),
                SettingsSelection(
                  revision: _snapshot,
                  prefix: 'tech',
                  selectorKey: const Key('tech-selection'),
                  count: settings.count,
                  selected: _tech,
                  label: (id) => settingsName(
                    context.l10n.editorTech,
                    id,
                    defaultTechNames,
                  ),
                  onSelected: (id) => setState(() => _tech = id),
                  scope: context.l10n
                      .editorMapCostsAndOnlyInheritanceFlagsChangeOnlyIf(
                        (_player == -1
                                ? context.l10n.editorMapDefaults
                                : context.l10n.editorPlayer(
                                    (_player + 1).toString(),
                                  ))
                            .toString(),
                      ),
                  onCopy: (ids) {
                    final copies = copySettingsDraft(
                      _draft,
                      (key) =>
                          key.$1 == _tech &&
                          (key.$3.isCost ||
                              key.$2 == (_player == -1 ? null : _player)),
                      (key, id) => (id, key.$2, key.$3),
                      ids,
                    );
                    for (final e in copies.entries) {
                      e.key.$3.parse(e.value);
                    }
                    setState(() {
                      _draft.addAll(copies);
                      _generation++;
                    });
                    return copies.length;
                  },
                ),
                for (final issue in settings.issues.values)
                  Text(context.localizeEditorText(issue)),
                if (costEnabled) ...[
                  _flag(
                    ChkTechField.useDefault,
                    context.l10n.editorUseCustomCosts,
                    context.l10n.editorUseGameDefaults,
                  ),
                  for (final field in ChkTechField.values.where(
                    (f) => f.isCost && !f.isFlag,
                  ))
                    _number(field, _text(_key(ChkTechField.useDefault)) == '0'),
                  Text(
                    context
                        .l10n
                        .editorGameDefaultsPreserveStoredCustomCostsDefaultGameValues,
                  ),
                ],
                if (stateEnabled) ...[
                  SettingsSelection(
                    prefix: 'tech-players',
                    selectorKey: const Key('tech-player'),
                    count: 12,
                    copyCount: 8,
                    idBase: 1,
                    includeMapDefault: true,
                    selected: _player,
                    revision: _snapshot,
                    label: (id) => id == -1
                        ? context.l10n.editorMapDefaultSettings
                        : context.l10n.editorPlayer203c6551(
                            (id + 1).toString(),
                            (id >= 8 ? context.l10n.editorReadOnly : "")
                                .toString(),
                          ),
                    onSelected: (id) => setState(() => _player = id),
                    scope: context.l10n
                        .editorCopiesOnlyCurrentTechPlayerEditsToPlayers1(
                          (_tech).toString(),
                        ),
                    onCopy: _player < 0 || _player >= 8
                        ? null
                        : (ids) {
                            final copies = copySettingsDraft(
                              _draft,
                              (key) => key.$1 == _tech && key.$2 == _player,
                              (key, id) => (key.$1, id, key.$3),
                              ids,
                            );
                            for (final e in copies.entries) {
                              e.key.$3.parse(e.value);
                            }
                            setState(() {
                              _draft.addAll(copies);
                              _generation++;
                            });
                            return copies.length;
                          },
                  ),
                  if (_player >= 0)
                    _flag(
                      ChkTechField.inherit,
                      context.l10n.editorUsePlayerSettings,
                      context.l10n.editorInheritMapSettings,
                      enabled: _player < 8,
                    ),
                  _flag(
                    ChkTechField.available,
                    context.l10n.editorUnavailable,
                    context.l10n.editorAvailable,
                    enabled:
                        _player == -1 ||
                        (_player < 8 &&
                            _text(_key(ChkTechField.inherit)) == '0'),
                  ),
                  _flag(
                    ChkTechField.researched,
                    context.l10n.editorNotResearched,
                    context.l10n.editorAlreadyResearched,
                    enabled:
                        _player == -1 ||
                        (_player < 8 &&
                            _text(_key(ChkTechField.inherit)) == '0'),
                  ),
                  Text(_effective()),
                  Text(
                    context
                        .l10n
                        .editorMapSettingsAffectInheritingPlayersInheritancePreservesStoredPlayer,
                  ),
                ],
              ],
              Text(
                context.l10n
                    .editorPendingChangesAcrossTechsAndPlayersApplyUpdatesThe(
                      (_draft.length).toString(),
                    ),
              ),
              if (_error != null)
                Text(
                  context.localizeEditorText(_error!),
                  key: const Key('tech-error'),
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
          key: const Key('tech-apply'),
          onPressed: _snapshot != null && _draft.isNotEmpty
              ? () => _run(_apply)
              : null,
          child: Text(context.l10n.editorApply),
        ),
      ],
    );
  }
}
