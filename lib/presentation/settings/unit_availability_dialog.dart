import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_unit_availability_editor.dart';

class UnitAvailabilityDialog extends StatefulWidget {
  const UnitAvailabilityDialog({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<UnitAvailabilityDialog> createState() => _UnitAvailabilityDialogState();
}

class _UnitAvailabilityDialogState extends State<UnitAvailabilityDialog> {
  ChkUnitAvailability? _settings;
  RawChkDocument? _snapshot;
  final _draft = <UnitAvailabilityKey, int>{};
  int _player = 0;
  int _unit = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _draft.clear();
    try {
      _settings = widget.controller.unitAvailability;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
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
  UnitAvailabilityKey _key(ChkUnitAvailabilityField field) =>
      (field == ChkUnitAvailabilityField.global ? null : _player, _unit, field);
  int? _value(ChkUnitAvailabilityField field) =>
      _draft[_key(field)] ?? _settings?.value(_key(field));
  Widget _field(
    ChkUnitAvailabilityField field,
    String label,
    String zero,
    String one,
  ) {
    final key = _key(field);
    final stored = _settings?.value(key);
    final value = _value(field);
    final editable =
        _settings != null &&
        (field == ChkUnitAvailabilityField.global || _player < 8) &&
        (field != ChkUnitAvailabilityField.player ||
            _value(ChkUnitAvailabilityField.inherit) == 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        DropdownButton<int>(
          key: Key('availability-${field.name}'),
          isExpanded: true,
          value: value,
          items: [
            DropdownMenuItem(value: 0, child: Text(zero)),
            DropdownMenuItem(value: 1, child: Text(one)),
            if (stored != null && stored > 1)
              DropdownMenuItem(
                value: stored,
                child: Text('Stored ID $stored (preserved)'),
              ),
          ],
          onChanged: editable
              ? (v) => setState(() {
                  if (v == stored) {
                    _draft.remove(key);
                  } else if (v != null) {
                    _draft[key] = v;
                  }
                })
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inherit = _value(ChkUnitAvailabilityField.inherit);
    final effective = inherit == 1
        ? _value(ChkUnitAvailabilityField.global)
        : inherit == 0
        ? _value(ChkUnitAvailabilityField.player)
        : null;
    return AlertDialog(
      title: const Text('Unit Availability'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<int>(
                key: const Key('availability-unit'),
                value: _unit,
                isExpanded: true,
                items: [
                  for (var i = 0; i < 228; i++)
                    DropdownMenuItem(value: i, child: Text('Unit #$i')),
                ],
                onChanged: (v) => setState(() => _unit = v!),
              ),
              _field(
                ChkUnitAvailabilityField.global,
                'Map default — affects all inheriting players',
                'Default: prohibited',
                'Default: allowed',
              ),
              DropdownButton<int>(
                key: const Key('availability-player-selection'),
                value: _player,
                isExpanded: true,
                items: [
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
              _field(
                ChkUnitAvailabilityField.inherit,
                'Player setting source',
                'Use player override',
                'Inherit map default',
              ),
              _field(
                ChkUnitAvailabilityField.player,
                'Stored player override',
                'Player: prohibited',
                'Player: allowed',
              ),
              Text(
                'Effective availability: ${effective == 0
                    ? "prohibited"
                    : effective == 1
                    ? "allowed"
                    : "unknown (stored flags preserved)"}',
                key: const Key('availability-effective'),
              ),
              const Text(
                'Inheritance preserves the stored override. Availability does not bypass game prerequisites or create placed units.',
              ),
              Text(
                '${_draft.length} pending changes. Apply updates all edited units and players; Save As writes the map.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('availability-error'),
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
          key: const Key('availability-apply'),
          onPressed: _snapshot == null || _draft.isEmpty
              ? null
              : () => _run(
                  () => widget.controller.applyUnitAvailability(
                    expectedDocument: _snapshot!,
                    changes: _draft,
                  ),
                ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
