import 'package:flutter/material.dart';
import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_field_manifest.dart';
import '../../domain/eud/eud_project.dart';
import '../settings/default_settings_names.dart';

Future<void> showEudWeaponEditor(
  BuildContext context, {
  required EudProjectController controller,
  required int weapon,
  bool Function()? referenceIsCurrent,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _WeaponDialog(
    controller: controller,
    weapon: weapon,
    referenceIsCurrent: referenceIsCurrent,
  ),
);

class EudWeaponEditor extends StatefulWidget {
  const EudWeaponEditor({
    required this.controller,
    required this.enabled,
    required this.onEditingChanged,
    super.key,
  });
  final EudProjectController controller;
  final bool enabled;
  final ValueChanged<bool> onEditingChanged;
  @override
  State<EudWeaponEditor> createState() => _EudWeaponEditorState();
}

class _EudWeaponEditorState extends State<EudWeaponEditor> {
  int _weapon = 0;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 320,
        child: DropdownButton<int>(
          key: const Key('eud-weapon-selector'),
          isExpanded: true,
          value: _weapon,
          items: [
            for (var i = 0; i < 130; i++)
              DropdownMenuItem(
                value: i,
                child: Text('${defaultWeaponNames[i]} (#$i)'),
              ),
          ],
          onChanged: widget.enabled
              ? (value) => setState(() => _weapon = value!)
              : null,
        ),
      ),
      OutlinedButton(
        onPressed: widget.enabled
            ? () async {
                widget.onEditingChanged(true);
                try {
                  await showEudWeaponEditor(
                    context,
                    controller: widget.controller,
                    weapon: _weapon,
                  );
                } finally {
                  if (mounted) widget.onEditingChanged(false);
                }
              }
            : null,
        child: const Text('Edit weapon EUD settings'),
      ),
    ],
  );
}

class _WeaponDialog extends StatefulWidget {
  const _WeaponDialog({
    required this.controller,
    required this.weapon,
    this.referenceIsCurrent,
  });
  final EudProjectController controller;
  final int weapon;
  final bool Function()? referenceIsCurrent;
  @override
  State<_WeaponDialog> createState() => _WeaponDialogState();
}

class _WeaponDialogState extends State<_WeaponDialog> {
  static const fields = [
    'weapon.minRange',
    'weapon.maxRange',
    'weapon.damageType',
  ];
  late final EudProject _base;
  late final TextEditingController _min;
  late final TextEditingController _max;
  String _damage = '';
  String? _error;
  @override
  void initState() {
    super.initState();
    _base = widget.controller.project!;
    Object? value(String field) => _base.overrides
        .where((o) => o.field == field && o.targetId == widget.weapon)
        .firstOrNull
        ?.value;
    _min = TextEditingController(text: value(fields[0])?.toString() ?? '');
    _max = TextEditingController(text: value(fields[1])?.toString() ?? '');
    _damage = value(fields[2])?.toString() ?? '';
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      if (widget.referenceIsCurrent?.call() == false) {
        throw StateError(
          'Weapon reference source changed. Cancel and reload references.',
        );
      }
      if (!identical(_base, widget.controller.project)) {
        throw StateError('Project changed. Cancel and reopen this editor.');
      }
      final values = [
        for (final item in _base.overrides)
          if (item.targetId != widget.weapon || !fields.contains(item.field))
            item,
      ];
      for (final pair in [(fields[0], _min.text), (fields[1], _max.text)]) {
        final text = pair.$2.trim();
        if (text.isEmpty) continue;
        if (!RegExp(r'^\d{1,10}$').hasMatch(text)) {
          throw FormatException(
            '${pair.$1}: enter a whole number from 0 to 4294967295.',
          );
        }
        values.add(
          EudOverride(
            field: pair.$1,
            targetId: widget.weapon,
            value: int.parse(text),
          ),
        );
      }
      if (_damage.isNotEmpty) {
        values.add(
          EudOverride(
            field: fields[2],
            targetId: widget.weapon,
            value: _damage,
          ),
        );
      }
      widget.controller.replaceOverrides(values);
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = EudFieldManifest.find(fields[2])!.choices;
    return AlertDialog(
      title: Text(
        '${defaultWeaponNames[widget.weapon]} (#${widget.weapon}) — EUD',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Shared weapon ID for ground/air users. Review Static unit / weapon impact after applying. This does not reassign a unit’s weapon.',
              ),
              const Text(
                'Distances are raw integers; tile conversion and runtime support are unverified. Blank removes the override; game defaults remain unknown. Applying changes only the project, not the game.',
              ),
              TextField(
                key: const Key('eud-min-range'),
                controller: _min,
                decoration: const InputDecoration(
                  labelText: 'Minimum range (raw)',
                ),
              ),
              TextField(
                key: const Key('eud-max-range'),
                controller: _max,
                decoration: const InputDecoration(
                  labelText: 'Maximum range (raw)',
                ),
              ),
              DropdownButton<String>(
                key: const Key('eud-damage-type'),
                isExpanded: true,
                value: _damage,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('No damage type override'),
                  ),
                  for (final value in choices)
                    DropdownMenuItem(value: value, child: Text(value)),
                  if (_damage.isNotEmpty && !choices.contains(_damage))
                    DropdownMenuItem(
                      value: _damage,
                      child: Text('Unsupported: $_damage'),
                    ),
                ],
                onChanged: (value) => setState(() => _damage = value!),
              ),
              if (_error != null)
                Text(
                  _error!,
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
        FilledButton(onPressed: _apply, child: const Text('Apply to project')),
      ],
    );
  }
}
