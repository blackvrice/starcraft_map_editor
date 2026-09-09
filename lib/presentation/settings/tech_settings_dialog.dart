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
            child: Text('Stored flag $stored (preserved)'),
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
          labelText: field.label,
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
      if (flag > 1) return 'Effective state: unknown (stored flag preserved)';
      if (flag == 1) player = null;
    }
    String state(ChkTechField field) =>
        switch (int.parse(_text((_tech, player, field)))) {
          0 => 'no',
          1 => 'yes',
          _ => 'unknown',
        };
    return 'Effective state: available ${state(ChkTechField.available)}, researched ${state(ChkTechField.researched)}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final costEnabled =
        settings != null && settings.data.containsKey(settings.costName);
    final stateEnabled =
        settings != null && settings.data.containsKey(settings.stateName);
    return AlertDialog(
      title: const Text('Tech Settings'),
      content: SizedBox(
        width: 640,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings != null) ...[
                Text(
                  'Editing ${settings.costName} / ${settings.stateName}${settings.hasAlternate ? "; alternate sections preserved" : ""}.',
                ),
                DropdownButton<int>(
                  key: const Key('tech-selection'),
                  value: _tech,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < settings.count; i++)
                      DropdownMenuItem(value: i, child: Text('Tech #$i')),
                  ],
                  onChanged: (v) => setState(() => _tech = v!),
                ),
                for (final issue in settings.issues.values) Text(issue),
                if (costEnabled) ...[
                  _flag(
                    ChkTechField.useDefault,
                    'Use custom costs',
                    'Use game defaults',
                  ),
                  for (final field in ChkTechField.values.where(
                    (f) => f.isCost && !f.isFlag,
                  ))
                    _number(field, _text(_key(ChkTechField.useDefault)) == '0'),
                  const Text(
                    'Game defaults preserve stored custom costs. Default game values are not loaded here.',
                  ),
                ],
                if (stateEnabled) ...[
                  DropdownButton<int>(
                    key: const Key('tech-player'),
                    value: _player,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: -1,
                        child: Text('Map default settings'),
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
                      ChkTechField.inherit,
                      'Use player settings',
                      'Inherit map settings',
                      enabled: _player < 8,
                    ),
                  _flag(
                    ChkTechField.available,
                    'Unavailable',
                    'Available',
                    enabled:
                        _player == -1 ||
                        (_player < 8 &&
                            _text(_key(ChkTechField.inherit)) == '0'),
                  ),
                  _flag(
                    ChkTechField.researched,
                    'Not researched',
                    'Already researched',
                    enabled:
                        _player == -1 ||
                        (_player < 8 &&
                            _text(_key(ChkTechField.inherit)) == '0'),
                  ),
                  Text(_effective()),
                  const Text(
                    'Map settings affect inheriting players. Inheritance preserves stored player flags. Availability and research status are independent.',
                  ),
                ],
              ],
              Text(
                '${_draft.length} pending changes across techs and players. Apply updates the document; Save As writes the map.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('tech-error'),
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
          key: const Key('tech-apply'),
          onPressed: _snapshot != null && _draft.isNotEmpty
              ? () => _run(_apply)
              : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
