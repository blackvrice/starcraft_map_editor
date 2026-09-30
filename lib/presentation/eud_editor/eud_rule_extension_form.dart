import 'package:flutter/material.dart';
import '../../domain/eud/eud_rule_expression.dart';
import '../localization/l10n.dart';
import 'eud_rule_labels.dart';

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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        SwitchListTile(
          title: Text(l10n.eudExtTitle),
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            widget.onEnabledChanged?.call(v);
          },
        ),
        if (_enabled) ...[
          Text(l10n.eudExtHelp),
          DropdownButtonFormField<EudRuleAction>(
            initialValue: _action,
            decoration: InputDecoration(labelText: l10n.eudExtTargetAction),
            items: [
              for (final a in EudRuleAction.values)
                DropdownMenuItem(
                  value: a,
                  child: Text(EudRuleLabels.action(l10n, a)),
                ),
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
            decoration: InputDecoration(labelText: l10n.eudExtTargetId),
          ),
          TextField(
            controller: _unit,
            decoration: InputDecoration(labelText: l10n.eudExtUnitType),
          ),
          if ({
            EudRuleAction.unitHp,
            EudRuleAction.unitShields,
            EudRuleAction.unitEnergy,
            EudRuleAction.followUnit,
          }.contains(_action))
            Text(l10n.eudExtUnitBindHelp),
          if (_action == EudRuleAction.text)
            TextField(
              controller: _text,
              decoration: InputDecoration(labelText: l10n.eudExtTextPrefix),
            ),
          if (_action == EudRuleAction.sound) Text(l10n.eudExtSoundHelp),
          DropdownButtonFormField<EudRuleTiming>(
            initialValue: _timing,
            decoration: InputDecoration(labelText: l10n.eudExtTiming),
            items: [
              for (final t in EudRuleTiming.values)
                DropdownMenuItem(
                  value: t,
                  child: Text(EudRuleLabels.timing(l10n, t)),
                ),
            ],
            onChanged: (t) => setState(() => _timing = t!),
          ),
          _ValueForm(
            key: _values[0],
            label: l10n.eudExtLeft,
            initial: widget.initial?.left,
          ),
          _ValueForm(
            key: _values[1],
            label: l10n.eudExtRight,
            initial: widget.initial?.right,
          ),
          _ValueForm(
            key: _values[2],
            label: l10n.eudExtValue,
            initial: widget.initial?.value,
          ),
          if (_action == EudRuleAction.location)
            for (var i = 0; i < 4; i++)
              _ValueForm(
                key: _values[i + 3],
                label: [
                  l10n.eudExtX,
                  l10n.eudExtY,
                  l10n.eudExtWidth,
                  l10n.eudExtHeight,
                ][i],
                initial: widget.initial?.coordinates.length == 4
                    ? widget.initial!.coordinates[i]
                    : null,
              ),
        ],
      ],
    );
  }
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          DropdownButtonFormField<EudValueSource>(
            initialValue: _source,
            items: [
              for (final s in EudValueSource.values)
                DropdownMenuItem(
                  value: s,
                  child: Text(EudRuleLabels.source(l10n, s)),
                ),
            ],
            onChanged: (s) => setState(() {
              _source = s!;
              _index.text = '0';
            }),
          ),
          Row(
            children: [
              for (final item in [
                (_index, l10n.eudExtConstantId),
                (_player, l10n.eudExtPlayerRange),
                (_factor, l10n.eudExtFactor),
                (_offset, l10n.eudExtOffset),
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
}
