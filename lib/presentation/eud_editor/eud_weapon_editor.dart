import 'package:flutter/material.dart';
import '../localization/l10n.dart';
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
    this.selectedWeapon = 0,
    super.key,
  });
  final EudProjectController controller;
  final bool enabled;
  final ValueChanged<bool> onEditingChanged;
  final int selectedWeapon;
  @override
  State<EudWeaponEditor> createState() => _EudWeaponEditorState();
}

class _EudWeaponEditorState extends State<EudWeaponEditor> {
  int _weapon = 0;
  @override
  void initState() {
    super.initState();
    _weapon = widget.selectedWeapon;
  }

  @override
  void didUpdateWidget(EudWeaponEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeapon != widget.selectedWeapon) {
      _weapon = widget.selectedWeapon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.gps_fixed_rounded,
              size: 18,
              color: Color(0xFFE3A64A),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.eudWeaponCardTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.eudWeaponCardHelp,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFFA7AFB8)),
        ),
        const SizedBox(height: 8),
        Wrap(
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
              child: Text(l10n.eudWeaponEdit),
            ),
          ],
        ),
      ],
    );
  }
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
        throw StateError(context.l10n.eudWeaponReferenceChanged);
      }
      if (!identical(_base, widget.controller.project)) {
        throw StateError(context.l10n.eudProjectChanged);
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
          throw FormatException(context.l10n.eudWeaponWholeNumber(pair.$1));
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
    final l10n = context.l10n;
    final choices = EudFieldManifest.find(fields[2])!.choices;
    String damage(String value) => switch (value) {
      'Independent' => l10n.eudDamageIndependent,
      'Explosive' => l10n.eudDamageExplosive,
      'Concussive' => l10n.eudDamageConcussive,
      'Normal' => l10n.eudDamageNormal,
      'IgnoreArmor' => l10n.eudDamageIgnoreArmor,
      _ => value,
    };
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
              Text(l10n.eudWeaponSharedHelp),
              const SizedBox(height: 6),
              Text(
                l10n.eudWeaponRawHelp,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFA7AFB8),
                ),
              ),
              TextField(
                key: const Key('eud-min-range'),
                controller: _min,
                decoration: InputDecoration(labelText: l10n.eudWeaponMinRange),
              ),
              TextField(
                key: const Key('eud-max-range'),
                controller: _max,
                decoration: InputDecoration(labelText: l10n.eudWeaponMaxRange),
              ),
              DropdownButton<String>(
                key: const Key('eud-damage-type'),
                isExpanded: true,
                value: _damage,
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.eudWeaponNoDamage),
                  ),
                  for (final value in choices)
                    DropdownMenuItem(value: value, child: Text(damage(value))),
                  if (_damage.isNotEmpty && !choices.contains(_damage))
                    DropdownMenuItem(
                      value: _damage,
                      child: Text(l10n.eudWeaponUnsupported(_damage)),
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
          child: Text(l10n.eudCancel),
        ),
        FilledButton(onPressed: _apply, child: Text(l10n.eudApplyToProject)),
      ],
    );
  }
}
