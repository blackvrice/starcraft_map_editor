import 'package:flutter/material.dart';

import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_field_manifest.dart';
import '../../domain/eud/eud_project.dart';
import '../settings/default_settings_names.dart';
import '../settings/default_unit_names.dart';

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
}) => showDialog<void>(
  context: context,
  builder: (_) => _FieldEditor(controller: controller),
);

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({required this.controller});
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
        throw StateError('Project changed. Reopen the editor.');
      }
      widget.controller.replaceOverrides(_draft.values);
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
      title: const Text('EUD field extensions'),
      content: SizedBox(
        width: 760,
        height: 590,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Candidate settings • Runtime unverified. Add each edit to the draft, then apply the draft to the project. Unsaved input is discarded when changing selection.',
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final table in EudTable.values)
                    ChoiceChip(
                      key: Key('eud-category-${table.name}'),
                      label: Text(table.name),
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
              DropdownButton<EudFieldDefinition>(
                key: const Key('eud-extension-field'),
                isExpanded: true,
                value: _field,
                items: [
                  for (final f in fields)
                    DropdownMenuItem(value: f, child: Text(f.key)),
                ],
                onChanged: (field) => setState(() {
                  _field = field!;
                  if (_target >= _field.targetCount) _target = 0;
                  _load();
                }),
              ),
              TextField(
                key: ValueKey('eud-target-search-${_table.name}'),
                decoration: const InputDecoration(
                  labelText: 'Find target by name or ID',
                ),
                onChanged: (value) => setState(() => _search = value),
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
                    ? 'Selected player slot only. Supply uses half-points (400 = 200 supply).'
                    : 'Global type setting, shared across players. DAT defaults are not loaded. Shared-reference impact is not resolved for this editor.',
              ),
              Text('Candidate API: ${_field.member} • ${_field.unit.name}'),
              if (_field.type == EudValueType.unsignedInteger) ...[
                Text(
                  'Storage input: 0–${_field.valueMaximum}${_field.allowedBits == null ? '' : ' • Allowed mask: 0x${_field.allowedBits!.toRadixString(16)}'}. Gameplay limits are unverified.',
                ),
                TextField(
                  key: const Key('eud-extension-number'),
                  controller: _number,
                  decoration: const InputDecoration(
                    labelText: 'Value (decimal integer)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ] else
                DropdownButton<Object>(
                  key: const Key('eud-extension-choice'),
                  isExpanded: true,
                  hint: Text(
                    _value == null
                        ? 'Choose a value'
                        : 'Unsupported stored value: $_value',
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
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  onChanged: (value) => setState(() => _value = value),
                ),
              if (_field.overlapsChk)
                CheckboxListTile(
                  key: const Key('eud-extension-override-chk'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Explicitly override ordinary CHK settings',
                  ),
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
                    child: const Text('Add / update draft'),
                  ),
                  TextButton(
                    key: const Key('eud-extension-remove'),
                    onPressed: _draft.containsKey(_identity)
                        ? () => setState(() {
                            _stage(remove: true);
                          })
                        : null,
                    child: const Text('Remove from draft'),
                  ),
                ],
              ),
              Text(
                '${_draft.length} draft overrides • Current: ${_draft[_identity]?.value ?? 'No override'}',
              ),
              if (_error != null)
                Text(
                  _error!,
                  key: const Key('eud-extension-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('eud-extension-apply'),
          onPressed: _apply,
          child: const Text('Apply draft to project'),
        ),
      ],
    );
  }
}
