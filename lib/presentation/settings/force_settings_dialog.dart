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
    return AlertDialog(
      title: const Text('Force Settings'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Player assignment'),
              DropdownButton<int>(
                key: const Key('force-player'),
                value: _player,
                isExpanded: true,
                items: [
                  for (var i = 0; i < 8; i++)
                    DropdownMenuItem(value: i, child: Text('Player ${i + 1}')),
                ],
                onChanged: (v) => setState(() => _player = v!),
              ),
              DropdownButton<int>(
                key: const Key('force-assignment'),
                value: assignment,
                isExpanded: true,
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('Assign to Force ${i + 1}'),
                    ),
                  if (storedAssignment != null && storedAssignment > 3)
                    DropdownMenuItem(
                      value: storedAssignment,
                      child: Text('Stored ID $storedAssignment (preserved)'),
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
              DropdownButton<int>(
                key: const Key('force-selection'),
                value: _force,
                isExpanded: true,
                items: [
                  for (var i = 0; i < 4; i++)
                    DropdownMenuItem(value: i, child: Text('Force ${i + 1}')),
                ],
                onChanged: (v) => setState(() {
                  _force = v!;
                  _name.text = _names[_force] ?? settings?.names[_force] ?? '';
                }),
              ),
              TextField(
                key: const Key('force-name'),
                controller: _name,
                enabled:
                    settings != null && settings.nameIssues[_force] == null,
                decoration: const InputDecoration(labelText: 'Force name'),
                onChanged: (v) => setState(() {
                  if (v == settings!.names[_force]) {
                    _names.remove(_force);
                  } else {
                    _names[_force] = v;
                  }
                }),
              ),
              if (settings?.nameIssues[_force] != null)
                Text(settings!.nameIssues[_force]!),
              for (final option in const {
                1: 'Randomize start locations',
                2: 'Allies',
                4: 'Allied victory',
                8: 'Shared vision',
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
              const Text(
                'Apply updates all edited players and forces. Save As writes the map.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('force-error'),
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
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
