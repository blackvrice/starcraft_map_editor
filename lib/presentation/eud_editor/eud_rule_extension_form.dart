import 'package:flutter/material.dart';
import '../../domain/eud/eud_rule_expression.dart';

class EudRuleExtensionForm extends StatefulWidget {
  const EudRuleExtensionForm({this.initial, this.onEnabledChanged, super.key});
  final EudRuleExtension? initial;
  final ValueChanged<bool>? onEnabledChanged;
  @override
  State<EudRuleExtensionForm> createState() => EudRuleExtensionFormState();
}

class EudRuleExtensionFormState extends State<EudRuleExtensionForm> {
  late bool _enabled = widget.initial != null;
  late EudRuleAction _action = widget.initial?.action ?? EudRuleAction.variable;
  late EudRuleTiming _timing =
      widget.initial?.timing ?? EudRuleTiming.beforeTriggers;
  late final _target = TextEditingController(
    text: '${widget.initial?.target ?? 0}',
  );
  late final _unit = TextEditingController(
    text: '${widget.initial?.unitType ?? 0}',
  );
  late final _text = TextEditingController(
    text: widget.initial?.text ?? 'Value',
  );
  final _values = List.generate(7, (_) => GlobalKey<_ValueFormState>());
  EudRuleExtension? read() => !_enabled
      ? null
      : EudRuleExtension(
          action: _action,
          timing: _timing,
          target: int.parse(_target.text),
          unitType: int.parse(_unit.text),
          text: _text.text,
          left: _values[0].currentState!.read(),
          right: _values[1].currentState!.read(),
          value: _values[2].currentState!.read(),
          coordinates: _action == EudRuleAction.location
              ? [for (var i = 3; i < 7; i++) _values[i].currentState!.read()]
              : [],
        );
  @override
  void dispose() {
    _target.dispose();
    _unit.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Extended execution rule'),
        value: _enabled,
        onChanged: (v) {
          setState(() => _enabled = v);
          widget.onEnabledChanged?.call(v);
        },
      ),
      if (_enabled) ...[
        const Text(
          'Values: unsigned 16-bit, clamped to 0–65535. Variables 0–15 start at zero. Formula: source × factor + offset. Non-resource actions set their value.',
        ),
        DropdownButtonFormField<EudRuleAction>(
          initialValue: _action,
          decoration: const InputDecoration(labelText: 'Target action'),
          items: [
            for (final a in EudRuleAction.values)
              DropdownMenuItem(value: a, child: Text(a.name)),
          ],
          onChanged: (a) => setState(() {
            _action = a!;
            _target.text =
                {
                  EudRuleAction.location,
                  EudRuleAction.followUnit,
                  EudRuleAction.sound,
                }.contains(a)
                ? '1'
                : '0';
          }),
        ),
        TextField(
          controller: _target,
          decoration: const InputDecoration(
            labelText:
                'Target ID: variable 0–15, upgrade 0–60, tech 0–43, location 1–255 (except 64), sound string ID; otherwise 0',
          ),
        ),
        TextField(
          controller: _unit,
          decoration: const InputDecoration(
            labelText: 'Unit type ID (0–227; instance/follow actions)',
          ),
        ),
        if ({
          EudRuleAction.unitHp,
          EudRuleAction.unitShields,
          EudRuleAction.unitEnergy,
          EudRuleAction.followUnit,
        }.contains(_action))
          const Text(
            'Binds the first living unit of this type owned by the selected player. Death, morph or ownership change invalidates the binding permanently. It never acquires a replacement unit. At most four unit rules.',
          ),
        if (_action == EudRuleAction.text)
          TextField(
            controller: _text,
            decoration: const InputDecoration(
              labelText: 'Text prefix (selected player only)',
            ),
          ),
        if (_action == EudRuleAction.sound)
          const Text(
            'Use a registered WAV string ID from Resources. Only the selected player hears the sound.',
          ),
        DropdownButtonFormField<EudRuleTiming>(
          initialValue: _timing,
          decoration: const InputDecoration(labelText: 'Execution timing'),
          items: [
            for (final t in EudRuleTiming.values)
              DropdownMenuItem(value: t, child: Text(t.name)),
          ],
          onChanged: (t) => setState(() => _timing = t!),
        ),
        _ValueForm(
          key: _values[0],
          label: 'Condition left',
          initial: widget.initial?.left,
        ),
        _ValueForm(
          key: _values[1],
          label: 'Condition right',
          initial: widget.initial?.right,
        ),
        _ValueForm(
          key: _values[2],
          label: 'Action value',
          initial: widget.initial?.value,
        ),
        if (_action == EudRuleAction.location)
          for (var i = 0; i < 4; i++)
            _ValueForm(
              key: _values[i + 3],
              label: ['X', 'Y', 'Width', 'Height'][i],
              initial: widget.initial?.coordinates.length == 4
                  ? widget.initial!.coordinates[i]
                  : null,
            ),
      ],
    ],
  );
}

class _ValueForm extends StatefulWidget {
  const _ValueForm({required this.label, this.initial, super.key});
  final String label;
  final EudRuleValue? initial;
  @override
  State<_ValueForm> createState() => _ValueFormState();
}

class _ValueFormState extends State<_ValueForm> {
  late EudValueSource _source =
      widget.initial?.source ?? EudValueSource.constant;
  late final _index = TextEditingController(
    text: '${widget.initial?.index ?? 0}',
  );
  late final _player = TextEditingController(
    text: '${(widget.initial?.player ?? 0) + 1}',
  );
  late final _factor = TextEditingController(
    text: '${widget.initial?.factor ?? 1}',
  );
  late final _offset = TextEditingController(
    text: '${widget.initial?.offset ?? 0}',
  );
  EudRuleValue read() => EudRuleValue(
    source: _source,
    index: int.parse(_index.text),
    player: int.parse(_player.text) - 1,
    factor: int.parse(_factor.text),
    offset: int.parse(_offset.text),
  );
  @override
  void dispose() {
    for (final c in [_index, _player, _factor, _offset]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
        DropdownButtonFormField<EudValueSource>(
          initialValue: _source,
          items: [
            for (final s in EudValueSource.values)
              DropdownMenuItem(value: s, child: Text(s.name)),
          ],
          onChanged: (s) => setState(() {
            _source = s!;
            _index.text = '0';
          }),
        ),
        Row(
          children: [
            for (final item in [
              (_index, 'Constant / ID'),
              (_player, 'Player 1–8'),
              (_factor, '× (0–255)'),
              (_offset, '+ offset'),
            ])
              Expanded(
                child: TextField(
                  controller: item.$1,
                  decoration: InputDecoration(labelText: item.$2),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
