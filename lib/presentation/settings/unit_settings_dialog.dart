import 'settings_surface.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import '../../application/placement/placement_catalog_controller.dart';
import 'weapon_impact_panel.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_unit_settings_editor.dart';

class UnitSettingsDialog extends StatefulWidget {
  const UnitSettingsDialog({
    required this.controller,
    this.catalogController,
    super.key,
  });
  final ObjectEditingController controller;
  final PlacementCatalogController? catalogController;
  @override
  State<UnitSettingsDialog> createState() => _UnitSettingsDialogState();
}

class _UnitSettingsDialogState extends State<UnitSettingsDialog> {
  RawChkDocument? _snapshot;
  ChkUnitSettings? _settings;
  final _values = <(int, ChkUnitSettingField), String>{};
  final _defaults = <int, int>{};
  final _damage = <(int, bool), String>{};
  final _names = <int, String>{};
  int _unit = 0;
  int _weapon = 0;
  int _generation = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _values.clear();
    _defaults.clear();
    _damage.clear();
    _names.clear();
    _generation++;
    try {
      _settings = widget.controller.unitSettings;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _error = null;
      if (_weapon >= _settings!.weaponCount) _weapon = 0;
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
  void _apply() {
    final values = <(int, ChkUnitSettingField), int>{};
    for (final e in _values.entries) {
      try {
        values[e.key] = e.key.$2.parse(e.value);
      } catch (e2) {
        throw FormatException('Unit #${e.key.$1}: $e2');
      }
    }
    for (final e in _defaults.entries) {
      values[(e.key, ChkUnitSettingField.useDefault)] = e.value;
    }
    final damage = <(int, bool), int>{};
    for (final e in _damage.entries) {
      try {
        damage[e.key] = ChkUnitSettingField.shields.parse(e.value);
      } catch (_) {
        throw FormatException(
          'Weapon #${e.key.$1}: damage must be an integer from 0 to 65535.',
        );
      }
    }
    widget.controller.applyUnitSettings(
      expectedDocument: _snapshot!,
      values: values,
      damage: damage,
      names: _names,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final storedMode = settings?.value(_unit, ChkUnitSettingField.useDefault);
    final mode = _defaults[_unit] ?? storedMode;
    String? name;
    String? nameIssue;
    if (settings != null) {
      try {
        name = settings.name(_unit);
      } catch (e) {
        nameIssue = e.toString();
      }
    }
    final dirty =
        _values.isNotEmpty ||
        _defaults.isNotEmpty ||
        _damage.isNotEmpty ||
        _names.isNotEmpty;
    return SettingsSurface(
      controller: widget.controller,
      snapshot: _snapshot,
      hasDraft: dirty,
      onReload: () => setState(_reload),
      title: const Text('Unit Settings'),
      content: SizedBox(
        width: 680,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map-wide unit types, separate from placed-unit properties.',
              ),
              if (settings != null)
                Text(
                  'Editing ${settings.sectionName}${settings.hasAlternate ? '; alternate section preserved without synchronization' : ''}.',
                ),
              SettingsSelection(
                revision: _snapshot,
                searchText: (id) {
                  if (_names.containsKey(id)) return _names[id]!;
                  try {
                    return settings?.name(id) ?? '';
                  } catch (_) {
                    return '';
                  }
                },
                prefix: 'unit-settings',
                selectorKey: const Key('unit-settings-unit'),
                count: 228,
                selected: _unit,
                label: (id) => 'Unit #$id',
                onSelected: (id) => setState(() => _unit = id),
                scope:
                    'Unit values, names and default flags only. Shared weapon damage uses its own selection below.',
                onCopy: settings == null
                    ? null
                    : (ids) {
                        final values = copySettingsDraft(
                          _values,
                          (key) => key.$1 == _unit,
                          (key, id) => (id, key.$2),
                          ids,
                        );
                        for (final e in values.entries) {
                          e.key.$2.parse(e.value);
                        }
                        final names = copySettingsDraft(
                          _names,
                          (key) => key == _unit,
                          (key, id) => id,
                          ids,
                        );
                        final defaults = copySettingsDraft(
                          _defaults,
                          (key) => key == _unit,
                          (key, id) => id,
                          ids,
                        );
                        setState(() {
                          _values.addAll(values);
                          _names.addAll(names);
                          _defaults.addAll(defaults);
                          _generation++;
                        });
                        return values.length + names.length + defaults.length;
                      },
              ),
              DropdownButton<int>(
                key: const Key('unit-settings-defaults'),
                value: mode,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Use custom values'),
                  ),
                  const DropdownMenuItem(
                    value: 1,
                    child: Text('Use game defaults'),
                  ),
                  if (storedMode != null && storedMode > 1)
                    DropdownMenuItem(
                      value: storedMode,
                      child: Text(
                        'Stored default flag $storedMode (preserved)',
                      ),
                    ),
                ],
                onChanged: settings == null
                    ? null
                    : (v) => setState(() {
                        if (v == storedMode) {
                          _defaults.remove(_unit);
                        } else {
                          _defaults[_unit] = v!;
                        }
                      }),
              ),
              const Text(
                'Fields show stored custom values. Game default numbers are not loaded.',
              ),
              TextButton(
                key: const Key('unit-settings-restore'),
                onPressed: settings == null
                    ? null
                    : () => setState(() {
                        if (storedMode == 1) {
                          _defaults.remove(_unit);
                        } else {
                          _defaults[_unit] = 1;
                        }
                        _values.removeWhere((key, _) => key.$1 == _unit);
                        _names.remove(_unit);
                        _generation++;
                      }),
                child: const Text('Restore selected unit defaults'),
              ),
              TextFormField(
                key: ValueKey('unit-name-$_unit-$_generation'),
                initialValue: _names[_unit] ?? name ?? '',
                enabled: mode == 0 && nameIssue == null && settings != null,
                decoration: const InputDecoration(
                  labelText: 'Unit name (empty = game name)',
                ),
                onChanged: (v) => setState(() {
                  if (v == name) {
                    _names.remove(_unit);
                  } else {
                    _names[_unit] = v;
                  }
                }),
              ),
              if (nameIssue != null) Text(nameIssue),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final field in ChkUnitSettingField.values.where(
                    (f) => f != ChkUnitSettingField.useDefault,
                  ))
                    SizedBox(
                      width: 300,
                      child: TextFormField(
                        key: ValueKey('unit-${field.name}-$_unit-$_generation'),
                        initialValue:
                            _values[(_unit, field)] ??
                            (settings == null
                                ? ''
                                : field.display(settings.value(_unit, field))),
                        enabled: settings != null && mode == 0,
                        decoration: InputDecoration(labelText: field.label),
                        onChanged: (v) => setState(() {
                          if (v ==
                              field.display(settings!.value(_unit, field))) {
                            _values.remove((_unit, field));
                          } else {
                            _values[(_unit, field)] = v;
                          }
                        }),
                      ),
                    ),
                ],
              ),
              const Divider(),
              const Text('Shared weapon damage'),
              const Text(
                'A weapon change affects every unit using that weapon. Restoring a unit does not reset shared weapon damage.',
              ),
              if (settings != null)
                SettingsSelection(
                  revision: _snapshot,
                  prefix: 'weapon-settings',
                  selectorKey: const Key('unit-settings-weapon'),
                  count: settings.weaponCount,
                  selected: _weapon,
                  label: (id) => 'Weapon #$id',
                  onSelected: (id) => setState(() => _weapon = id),
                  scope:
                      'Shared weapon damage only. All units referencing target weapons may be affected.',
                  onCopy: (ids) {
                    final copies = copySettingsDraft(
                      _damage,
                      (key) => key.$1 == _weapon,
                      (key, id) => (id, key.$2),
                      ids,
                    );
                    for (final value in copies.values) {
                      ChkUnitSettingField.shields.parse(value);
                    }
                    setState(() {
                      _damage.addAll(copies);
                      _generation++;
                    });
                    return copies.length;
                  },
                ),
              if (widget.catalogController != null)
                WeaponImpactPanel(
                  controller: widget.catalogController!,
                  weapon: _weapon,
                ),
              for (final bonus in [false, true])
                TextFormField(
                  key: ValueKey('weapon-$bonus-$_weapon-$_generation'),
                  initialValue:
                      _damage[(_weapon, bonus)] ??
                      (settings == null
                          ? ''
                          : '${settings.damage(_weapon, bonus: bonus)}'),
                  enabled: settings != null,
                  decoration: InputDecoration(
                    labelText: bonus ? 'Damage per upgrade' : 'Base damage',
                  ),
                  onChanged: (v) => setState(() {
                    if (v == '${settings!.damage(_weapon, bonus: bonus)}') {
                      _damage.remove((_weapon, bonus));
                    } else {
                      _damage[(_weapon, bonus)] = v;
                    }
                  }),
                ),
              const Text(
                'Apply updates all edited unit types and weapons. Save As writes the map.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('unit-settings-error'),
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
          key: const Key('unit-settings-apply'),
          onPressed: _snapshot != null && dirty ? () => _run(_apply) : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
