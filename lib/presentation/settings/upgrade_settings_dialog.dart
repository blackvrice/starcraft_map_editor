import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_upgrade_settings_editor.dart';

class UpgradeSettingsDialog extends StatefulWidget {
  const UpgradeSettingsDialog({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<UpgradeSettingsDialog> createState() => _UpgradeSettingsDialogState();
}

class _UpgradeSettingsDialogState extends State<UpgradeSettingsDialog> {
  ChkUpgradeSettings? _settings;
  RawChkDocument? _snapshot;
  final _draft = <UpgradeSettingKey, String>{};
  int _upgrade = 0;
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
      _settings = widget.controller.upgradeSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
      if (_upgrade >= _settings!.count) _upgrade = 0;
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
  UpgradeSettingKey _key(ChkUpgradeField field) =>
      (_upgrade, field.isCost || _player == -1 ? null : _player, field);
  String _text(UpgradeSettingKey key) =>
      _draft[key] ?? '${_settings!.value(key)}';
  void _change(UpgradeSettingKey key, String text) => setState(() {
    if (text == '${_settings!.value(key)}') {
      _draft.remove(key);
    } else {
      _draft[key] = text;
    }
  });
  Widget _flag(
    ChkUpgradeField field,
    String zero,
    String one, {
    bool enabled = true,
  }) {
    final key = _key(field);
    final stored = _settings!.value(key);
    return DropdownButton<int>(
      key: Key('upgrade-${field.name}'),
      value: int.parse(_text(key)),
      isExpanded: true,
      items: [
        DropdownMenuItem(value: 0, child: Text(zero)),
        DropdownMenuItem(value: 1, child: Text(one)),
        if (stored > 1)
          DropdownMenuItem(
            value: stored,
            child: Text('Stored flag $stored (preserved)'),
          ),
      ],
      onChanged: enabled ? (v) => _change(key, '$v') : null,
    );
  }

  Widget _number(ChkUpgradeField field, bool enabled) {
    final key = _key(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        key: ValueKey(('upgrade-input', _generation, key)),
        initialValue: _text(key),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: '0–${field.limit}',
        ),
        onChanged: (text) => _change(key, text),
      ),
    );
  }

  void _apply() {
    final changes = <UpgradeSettingKey, int>{};
    for (final e in _draft.entries) {
      try {
        // Existing nonstandard flags may be retained without normalization.
        changes[e.key] = e.value == '${_settings!.value(e.key)}'
            ? _settings!.value(e.key)
            : e.key.$3.parse(e.value);
      } catch (error) {
        throw FormatException(
          'Upgrade #${e.key.$1}, ${e.key.$2 == null ? "map" : "Player ${e.key.$2! + 1}"}: $error',
        );
      }
    }
    widget.controller.applyUpgradeSettings(
      expectedDocument: _snapshot!,
      changes: changes,
    );
  }

  String _effective() {
    int? player = _player == -1 ? null : _player;
    if (player != null) {
      final flag = int.parse(
        _text((_upgrade, player, ChkUpgradeField.inherit)),
      );
      if (flag > 1) return 'Effective levels: unknown (stored flag preserved)';
      if (flag == 1) player = null;
    }
    return 'Effective levels: ${_text((_upgrade, player, ChkUpgradeField.start))} / ${_text((_upgrade, player, ChkUpgradeField.maximum))} (start / maximum)';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final costEnabled =
        settings != null && settings.data.containsKey(settings.costName);
    final levelEnabled =
        settings != null && settings.data.containsKey(settings.levelName);
    return AlertDialog(
      title: const Text('Upgrade Settings'),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings != null) ...[
                Text(
                  'Editing ${settings.costName} / ${settings.levelName}${settings.hasAlternate ? "; alternate sections preserved" : ""}.',
                ),
                DropdownButton<int>(
                  key: const Key('upgrade-selection'),
                  value: _upgrade,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < settings.count; i++)
                      DropdownMenuItem(value: i, child: Text('Upgrade #$i')),
                  ],
                  onChanged: (v) => setState(() => _upgrade = v!),
                ),
                for (final issue in settings.issues.values) Text(issue),
                if (costEnabled) ...[
                  _flag(
                    ChkUpgradeField.useDefault,
                    'Use custom costs',
                    'Use game defaults',
                  ),
                  for (final field in ChkUpgradeField.values.where(
                    (f) => f.isCost && !f.isFlag,
                  ))
                    _number(
                      field,
                      _text(_key(ChkUpgradeField.useDefault)) == '0',
                    ),
                  const Text(
                    'Game defaults preserve stored custom costs. Default game values are not loaded here.',
                  ),
                ],
                if (levelEnabled) ...[
                  DropdownButton<int>(
                    key: const Key('upgrade-player'),
                    value: _player,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Map default levels'),
                      ),
                      for (var i = 0; i < 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            'Player ${i + 1}${i >= 8 ? " (read-only)" : ""}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _player = v!),
                  ),
                  if (_player >= 0)
                    _flag(
                      ChkUpgradeField.inherit,
                      'Use player levels',
                      'Inherit map levels',
                      enabled: _player < 8,
                    ),
                  for (final field in [
                    ChkUpgradeField.start,
                    ChkUpgradeField.maximum,
                  ])
                    _number(
                      field,
                      _player == -1 ||
                          (_player < 8 &&
                              _text(_key(ChkUpgradeField.inherit)) == '0'),
                    ),
                  Text(_effective()),
                  const Text(
                    'Map levels affect inheriting players. Inheritance preserves stored player levels. Starting level must not exceed maximum.',
                  ),
                ],
              ],
              Text(
                '${_draft.length} pending changes across upgrades and players. Apply updates the document; Save As writes the map.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('upgrade-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
          key: const Key('upgrade-apply'),
          onPressed: _snapshot != null && _draft.isNotEmpty
              ? () => _run(_apply)
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
