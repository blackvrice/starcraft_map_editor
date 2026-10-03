import 'package:flutter/material.dart';
import 'dart:async';
import '../../application/placement/placement_catalog_controller.dart';

import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_field_manifest.dart';
import '../../domain/eud/eud_project.dart';
import '../settings/default_settings_names.dart';
import '../settings/default_unit_names.dart';
import '../localization/l10n.dart';
import '../settings/visual_settings_picker.dart';
import 'eud_field_labels.dart';

String eudTargetName(EudTable table, int id) {
  final names = switch (table) {
    EudTable.unit => defaultUnitNames,
    EudTable.weapon => defaultWeaponNames,
    EudTable.upgrade => defaultUpgradeNames,
    EudTable.tech => defaultTechNames,
    _ => const <String>[],
  };
  if (table == EudTable.player) return 'Player ${id + 1} (#$id)';
  final name = id >= 0 && id < names.length ? names[id] : '';
  return name.isEmpty ? '${table.name} #$id' : '$name (#$id)';
}

Future<void> showEudFieldEditor(
  BuildContext context, {
  required EudProjectController controller,
  PlacementCatalogController? catalog,
}) => showDialog<void>(
  context: context,
  builder: (_) => _FieldEditor(controller: controller, catalog: catalog),
);

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({required this.controller, this.catalog});
  final PlacementCatalogController? catalog;
  final EudProjectController controller;
  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  late final EudProject _base = widget.controller.project!;
  late final Map<String, EudOverride> _draft = {
    for (final item in _base.overrides) item.identity: item,
  };
  EudTable _table = EudTable.unit;
  EudFieldDefinition _field = EudFieldManifest.fields.first;
  int _target = 0;
  final _number = TextEditingController();
  String _search = '';
  Object? _value;
  bool _overrideChk = false;
  String? _error;
  bool _loadingDefaults = false;
  StreamSubscription<PlacementCatalogState>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _dataSubscription = widget.catalog?.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _number.dispose();
    super.dispose();
  }

  String get _identity => '${_field.key}:$_target';

  void _load() {
    final stored = _draft[_identity];
    _value = stored?.value;
    _number.text = stored?.value is int ? '${stored!.value}' : '';
    _overrideChk = stored?.overrideChk ?? false;
    _error = null;
  }

  Future<void> _readDefaults() async {
    setState(() => _loadingDefaults = true);
    try {
      await widget.catalog!.loadEudData();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDefaults = false);
    }
  }

  void _useDefault() {
    final value = widget.catalog?.eudData?.snapshot.value(_field.key, _target);
    if (value == null) return;
    setState(() {
      _value = value;
      _number.text = value is int ? '$value' : '';
    });
  }

  bool _stage({bool remove = false}) {
    if (remove) {
      _draft.remove(_identity);
      _load();
      return true;
    }
    final value = _field.type == EudValueType.unsignedInteger
        ? int.tryParse(_number.text.trim())
        : _value;
    final error = _field.validate(_target, value);
    if (error != null || (_field.overlapsChk && !_overrideChk)) {
      _error = error?.name ?? 'explicitChkOverrideRequired';
      return false;
    }
    _draft[_identity] = EudOverride(
      field: _field.key,
      targetId: _target,
      value: value!,
      overrideChk: _overrideChk,
    );
    _error = null;
    return true;
  }

  void _apply() {
    try {
      if (!identical(widget.controller.project, _base)) {
        throw StateError(context.l10n.eudProjectChanged);
      }
      widget.controller.replaceOverrides(_draft.values);
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final friendlyError = switch (_error) {
      'explicitChkOverrideRequired' => l10n.eudFieldsNeedChk,
      'outOfRange' => l10n.eudFieldsOutOfRange,
      'invalidType' ||
      'invalidEnum' ||
      'invalidTarget' => l10n.eudFieldsInvalid,
      _ => null,
    };
    final fields = EudFieldManifest.fields
        .where((f) => f.table == _table)
        .toList();
    final targets =
        List.generate(_field.targetCount, (i) => i)
            .where(
              (id) => eudTargetName(
                _table,
                id,
              ).toLowerCase().contains(_search.toLowerCase()),
            )
            .toSet()
          ..add(_target);
    return AlertDialog(
      title: Text(l10n.eudFieldsTitle),
      content: SizedBox(
        width: 760,
        height: 590,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.eudFieldsIntro,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFA7AFB8),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final table in EudTable.values)
                    ChoiceChip(
                      key: Key('eud-category-${table.name}'),
                      label: Text(EudFieldLabels.group(locale, table.name)),
                      selected: _table == table,
                      onSelected: (_) => setState(() {
                        _table = table;
                        _field = EudFieldManifest.fields.firstWhere(
                          (f) => f.table == table,
                        );
                        _target = 0;
                        _search = '';
                        _load();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                l10n.eudFieldsField,
                style: const TextStyle(fontSize: 12, color: Color(0xFFA7AFB8)),
              ),
              DropdownButton<EudFieldDefinition>(
                key: const Key('eud-extension-field'),
                isExpanded: true,
                value: _field,
                items: [
                  for (final f in fields)
                    DropdownMenuItem(
                      value: f,
                      child: Text(
                        '${EudFieldLabels.label(locale, f.key)} · ${f.key}',
                      ),
                    ),
                ],
                onChanged: (field) => setState(() {
                  _field = field!;
                  if (_target >= _field.targetCount) _target = 0;
                  _load();
                }),
              ),
              TextField(
                key: ValueKey('eud-target-search-${_table.name}'),
                decoration: InputDecoration(
                  labelText: l10n.eudFieldsSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.eudFieldsTarget,
                style: const TextStyle(fontSize: 12, color: Color(0xFFA7AFB8)),
              ),
              if (_table == EudTable.unit || _table == EudTable.weapon)
                VisualSettingsPicker(
                  ids: targets.where((id) => id >= 0).toList(),
                  selected: _target,
                  prefix: 'eud-extension-target',
                  catalog: widget.catalog,
                  weapons: _table == EudTable.weapon,
                  label: (id) => eudTargetName(_table, id),
                  onSelected: (id) => setState(() {
                    _target = id;
                    _load();
                  }),
                ),
              DropdownButton<int>(
                key: const Key('eud-extension-target'),
                isExpanded: true,
                value: _target,
                items: [
                  for (final id in targets)
                    DropdownMenuItem(
                      value: id,
                      child: Text(eudTargetName(_table, id)),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _target = id!;
                  _load();
                }),
              ),
              Text(
                _table == EudTable.player
                    ? l10n.eudFieldsPlayerNote
                    : l10n.eudFieldsGlobalNote,
                style: const TextStyle(fontSize: 12.5),
              ),
              Text(
                l10n.eudFieldsApi(_field.member, _field.unit.name),
                style: const TextStyle(fontSize: 12, color: Color(0xFFA7AFB8)),
              ),
              if (_field.type == EudValueType.unsignedInteger) ...[
                Text(
                  l10n.eudFieldsStorage(
                    '${_field.valueMaximum}',
                    _field.allowedBits == null
                        ? ''
                        : l10n.eudFieldsMask(
                            '0x${_field.allowedBits!.toRadixString(16)}',
                          ),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA7AFB8),
                  ),
                ),
                TextField(
                  key: const Key('eud-extension-number'),
                  controller: _number,
                  decoration: InputDecoration(labelText: l10n.eudFieldsValue),
                  keyboardType: TextInputType.number,
                ),
              ] else if (_field.type == EudValueType.boolean)
                CheckboxListTile(
                  key: const Key('eud-extension-choice'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.eudFieldsValue),
                  value: _value is bool ? _value as bool : null,
                  tristate: _value is! bool,
                  onChanged: (value) => setState(() => _value = value),
                )
              else
                DropdownButton<Object>(
                  key: const Key('eud-extension-choice'),
                  isExpanded: true,
                  hint: Text(
                    _value == null
                        ? l10n.eudFieldsChoose
                        : l10n.eudFieldsUnsupported('$_value'),
                  ),
                  value:
                      (_field.type == EudValueType.boolean
                              ? [true, false]
                              : _field.choices)
                          .contains(_value)
                      ? _value
                      : null,
                  items: [
                    for (final value
                        in _field.type == EudValueType.boolean
                            ? <Object>[true, false]
                            : _field.choices)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == true
                              ? l10n.eudFieldsYes
                              : value == false
                              ? l10n.eudFieldsNo
                              : '$value',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _value = value),
                ),
              if (_field.overlapsChk)
                CheckboxListTile(
                  key: const Key('eud-extension-override-chk'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.eudFieldsOverrideChk),
                  value: _overrideChk,
                  onChanged: (value) => setState(() => _overrideChk = value!),
                ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('eud-extension-stage'),
                    onPressed: () => setState(() {
                      _stage();
                    }),
                    child: Text(l10n.eudFieldsStage),
                  ),
                  TextButton(
                    key: const Key('eud-extension-remove'),
                    onPressed: _draft.containsKey(_identity)
                        ? () => setState(() {
                            _stage(remove: true);
                          })
                        : null,
                    child: Text(l10n.eudFieldsRemove),
                  ),
                ],
              ),
              Text(
                l10n.eudFieldsDraftSummary(
                  _draft.length,
                  '${_draft[_identity]?.value ?? l10n.eudFieldsNoOverride}',
                ),
              ),
              Text(
                l10n.eudDatDefault(
                  '${widget.catalog?.eudData?.snapshot.raw(_field.key, _target) ?? l10n.eudDatUnavailable}',
                  widget.catalog?.eudData?.label ?? l10n.eudDatUnavailable,
                ),
                key: const Key('eud-dat-default'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('eud-dat-load'),
                    onPressed:
                        widget.catalog?.eudDatGateway == null ||
                            _loadingDefaults
                        ? null
                        : _readDefaults,
                    child: Text(l10n.eudDatLoad),
                  ),
                  TextButton(
                    key: const Key('eud-dat-use-default'),
                    onPressed:
                        widget.catalog?.eudData?.snapshot.value(
                              _field.key,
                              _target,
                            ) ==
                            null
                        ? null
                        : _useDefault,
                    child: Text(l10n.eudDatUseDefault),
                  ),
                ],
              ),
              if (_loadingDefaults) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('eud-extension-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (friendlyError != null)
                Text(
                  friendlyError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.eudCancel),
        ),
        FilledButton(
          key: const Key('eud-extension-apply'),
          onPressed: _apply,
          child: Text(l10n.eudFieldsApply),
        ),
      ],
    );
  }
}
