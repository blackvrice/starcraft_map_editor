import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'default_settings_names.dart';
import 'default_unit_names.dart';
import 'settings_surface.dart';
import '../../application/editing/settings_id_selection.dart';
import 'settings_selection.dart';
import '../../application/placement/placement_catalog_controller.dart';
import 'weapon_impact_panel.dart';
import 'unit_context_card.dart';
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_unit_settings_editor.dart';

class UnitSettingsDialog extends StatefulWidget {
  const UnitSettingsDialog({
    required this.controller,
    this.catalogController,
    this.selectedUnit,
    this.onUnitSelected,
    super.key,
  });
  final ObjectEditingController controller;
  final PlacementCatalogController? catalogController;
  final int? selectedUnit;
  final ValueChanged<int>? onUnitSelected;
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
    _unit = widget.selectedUnit ?? 0;
    _reload();
  }

  @override
  void didUpdateWidget(UnitSettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedUnit != null &&
        oldWidget.selectedUnit != widget.selectedUnit) {
      _unit = widget.selectedUnit!;
    }
  }

  void _selectUnit(int unit) {
    setState(() => _unit = unit);
    widget.onUnitSelected?.call(unit);
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
      title: Text(context.l10n.editorUnitSettings),
      content: SizedBox(
        width: 680,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context
                    .l10n
                    .editorMapWideUnitTypesSeparateFromPlacedUnitProperties,
              ),
              if (settings != null)
                Text(
                  context.l10n.editorEditing4dc9e6e6(
                    (settings.sectionName).toString(),
                    (settings.hasAlternate
                            ? context
                                  .l10n
                                  .editorAlternateSectionPreservedWithoutSynchronization
                            : '')
                        .toString(),
                  ),
                ),
              SettingsSelection(
                visual: true,
                visualCatalog: widget.catalogController,
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
                label: (id) {
                  String? custom = _names[id];
                  try {
                    custom ??= settings?.name(id);
                  } catch (_) {}
                  final name = custom == null || custom.isEmpty
                      ? defaultUnitNames[id]
                      : custom;
                  return context.l10n.editorUnit38894196(
                    (name).toString(),
                    (id).toString(),
                  );
                },
                onSelected: _selectUnit,
                scope: context
                    .l10n
                    .editorUnitValuesNamesAndDefaultFlagsOnlySharedWeapon,
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
              UnitContextCard(
                unit: _unit,
                catalog: widget.catalogController,
                onUnit: _selectUnit,
                onWeapon: (weapon) {
                  if (settings != null && weapon < settings.weaponCount) {
                    setState(() => _weapon = weapon);
                  }
                },
              ),
              if (mode == null || mode == 0 || mode == 1)
                CheckboxListTile(
                  key: const Key('unit-settings-defaults'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(context.l10n.editorUseGameDefaults),
                  value: mode == 1,
                  onChanged: settings == null
                      ? null
                      : (checked) => setState(() {
                          final value = checked == true ? 1 : 0;
                          if (value == storedMode) {
                            _defaults.remove(_unit);
                          } else {
                            _defaults[_unit] = value;
                          }
                        }),
                )
              else
                DropdownButton<int>(
                  key: const Key('unit-settings-defaults'),
                  value: mode,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(context.l10n.editorUseCustomValues),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(context.l10n.editorUseGameDefaults),
                    ),
                    if (storedMode != null && storedMode > 1)
                      DropdownMenuItem(
                        value: storedMode,
                        child: Text(
                          context.l10n.editorStoredDefaultFlagPreserved(
                            (storedMode).toString(),
                          ),
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
              Text(
                context
                    .l10n
                    .editorFieldsShowStoredCustomValuesGameDefaultNumbersAre,
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
                child: Text(context.l10n.editorRestoreSelectedUnitDefaults),
              ),
              TextFormField(
                key: ValueKey('unit-name-$_unit-$_generation'),
                initialValue: _names[_unit] ?? name ?? '',
                enabled: mode == 0 && nameIssue == null && settings != null,
                decoration: InputDecoration(
                  labelText: context.l10n.editorUnitNameEmptyGameName,
                ),
                onChanged: (v) => setState(() {
                  if (v == name) {
                    _names.remove(_unit);
                  } else {
                    _names[_unit] = v;
                  }
                }),
              ),
              if (nameIssue != null)
                Text(context.localizeEditorText(nameIssue)),
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
                        decoration: InputDecoration(
                          labelText: context.localizeEditorText(field.label),
                        ),
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
              Text(context.l10n.editorSharedWeaponDamage),
              Text(
                context.l10n.editorAWeaponChangeAffectsEveryUnitUsingThatWeapon,
              ),
              if (settings != null)
                SettingsSelection(
                  visual: true,
                  weapons: true,
                  visualCatalog: widget.catalogController,
                  revision: _snapshot,
                  prefix: 'weapon-settings',
                  selectorKey: const Key('unit-settings-weapon'),
                  count: settings.weaponCount,
                  selected: _weapon,
                  label: (id) => settingsName(
                    context.l10n.editorWeapon,
                    id,
                    defaultWeaponNames,
                  ),
                  onSelected: (id) => setState(() => _weapon = id),
                  scope: context
                      .l10n
                      .editorSharedWeaponDamageOnlyAllUnitsReferencingTargetWeapons,
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
                    labelText: bonus
                        ? context.l10n.editorDamagePerUpgrade
                        : context.l10n.editorBaseDamage,
                  ),
                  onChanged: (v) => setState(() {
                    if (v == '${settings!.damage(_weapon, bonus: bonus)}') {
                      _damage.remove((_weapon, bonus));
                    } else {
                      _damage[(_weapon, bonus)] = v;
                    }
                  }),
                ),
              Text(
                context.l10n.editorApplyUpdatesAllEditedUnitTypesAndWeaponsSave,
              ),
              if (_error != null)
                Text(
                  context.localizeEditorText(_error!),
                  key: const Key('unit-settings-error'),
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
          key: const Key('unit-settings-apply'),
          onPressed: _snapshot != null && dirty ? () => _run(_apply) : null,
          child: Text(context.l10n.editorApply),
        ),
      ],
    );
  }
}
