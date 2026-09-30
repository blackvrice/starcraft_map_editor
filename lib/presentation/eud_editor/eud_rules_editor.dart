import 'package:flutter/material.dart';
import 'eud_rule_extension_form.dart';
import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_execution_rule.dart';
import '../../domain/eud/eud_project.dart';
import '../localization/l10n.dart';
import 'eud_rule_labels.dart';

class EudRulesEditor extends StatelessWidget {
  const EudRulesEditor({
    required this.controller,
    required this.enabled,
    super.key,
  });
  final EudProjectController controller;
  final bool enabled;

  Future<void> _edit(BuildContext context, EudExecutionRule? rule) async {
    final snapshot = controller.project!;
    await showDialog<void>(
      context: context,
      builder: (_) => _RuleDialog(
        controller: controller,
        snapshot: snapshot,
        original: rule,
      ),
    );
  }

  void _replace(
    BuildContext context,
    EudProject snapshot,
    Iterable<EudExecutionRule> rules,
  ) {
    try {
      controller.replaceRules(rules, expectedProject: snapshot);
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _move(
    BuildContext context,
    EudProject snapshot,
    EudExecutionRule rule,
    int delta,
  ) {
    final rules = [...snapshot.rules];
    final index = rules.indexOf(rule);
    rules.removeAt(index);
    rules.insert(index + delta, rule);
    _replace(context, snapshot, rules);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = controller.project!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFE3A64A)),
            const SizedBox(width: 8),
            Text(
              l10n.eudRulesTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF23272C),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.eudRulesCount(project.rules.length, EudProject.maxRules),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              key: const Key('eud-rule-add'),
              onPressed: enabled && project.rules.length < EudProject.maxRules
                  ? () => _edit(context, null)
                  : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.eudRuleAdd),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.eudRulesHelp,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFFA7AFB8)),
        ),
        Text(
          l10n.eudRulesHelp2,
          style: const TextStyle(fontSize: 12, color: Color(0xFFA7AFB8)),
        ),
        if (project.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(l10n.eudRulesEmpty),
          ),
        for (final (index, rule) in project.rules.indexed)
          Container(
            key: ValueKey(('eud-rule', rule.id)),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16191D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2C3238)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFF2A2418),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFE3A64A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: rule.enabled ? 1 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.enabled
                              ? rule.name
                              : '${rule.name} · ${l10n.eudRuleDisabled}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${l10n.eudRulePlayerN('${rule.player + 1}')} · '
                          '${EudRuleLabels.sentence(l10n, rule)} · '
                          '${EudRuleLabels.schedule(l10n, rule)}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.eudRuleMoveUp,
                  onPressed: enabled && project.rules.first != rule
                      ? () => _move(context, project, rule, -1)
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: l10n.eudRuleMoveDown,
                  onPressed: enabled && project.rules.last != rule
                      ? () => _move(context, project, rule, 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: l10n.eudRuleEdit,
                  onPressed: enabled ? () => _edit(context, rule) : null,
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: l10n.eudRuleDelete,
                  onPressed: enabled
                      ? () => _replace(
                          context,
                          project,
                          project.rules.where((r) => r.id != rule.id),
                        )
                      : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({
    required this.controller,
    required this.snapshot,
    this.original,
  });
  final EudProjectController controller;
  final EudProject snapshot;
  final EudExecutionRule? original;
  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final _name = TextEditingController(text: widget.original?.name);
  late final _threshold = TextEditingController(
    text: '${widget.original?.threshold ?? 100}',
  );
  late final _amount = TextEditingController(
    text: '${widget.original?.amount ?? 50}',
  );
  late final _interval = TextEditingController(
    text: '${widget.original?.interval ?? 24}',
  );
  late int _player = widget.original?.player ?? 0;
  late EudResource _resource = widget.original?.resource ?? EudResource.ore;
  late EudComparison _comparison =
      widget.original?.comparison ?? EudComparison.atLeast;
  late EudResourceOperation _operation =
      widget.original?.operation ?? EudResourceOperation.add;
  late EudRuleSchedule _schedule =
      widget.original?.schedule ?? EudRuleSchedule.once;
  late bool _isExtended = widget.original?.extension != null;
  late bool _enabled = widget.original?.enabled ?? true;
  String? _error;
  final _extension = GlobalKey<EudRuleExtensionFormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.original == null && _name.text.isEmpty) {
      _name.text = context.l10n.eudRuleDefaultName;
    }
  }

  @override
  void dispose() {
    for (final text in [_name, _threshold, _amount, _interval]) {
      text.dispose();
    }
    super.dispose();
  }

  Widget _choices<T>(
    String label,
    T value,
    List<T> values,
    String Function(T) text,
    void Function(T) change,
  ) => DropdownButtonFormField<T>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final item in values)
        DropdownMenuItem(value: item, child: Text(text(item))),
    ],
    onChanged: (next) {
      if (next != null) setState(() => change(next));
    },
  );

  void _apply() {
    try {
      var sequence = 1;
      while (widget.snapshot.rules.any((r) => r.id == 'rule_$sequence')) {
        sequence++;
      }
      final rule = EudExecutionRule(
        id: widget.original?.id ?? 'rule_$sequence',
        name: _name.text.trim(),
        player: _player,
        resource: _resource,
        comparison: _comparison,
        threshold: int.parse(_threshold.text.trim()),
        operation: _operation,
        amount: int.parse(_amount.text.trim()),
        schedule: _schedule,
        interval: int.parse(_interval.text.trim()),
        enabled: _enabled,
        extension: _extension.currentState?.read(),
      );
      widget.controller.replaceRules([
        for (final existing in widget.snapshot.rules)
          existing.id == rule.id ? rule : existing,
        if (widget.original == null) rule,
      ], expectedProject: widget.snapshot);
      Navigator.pop(context);
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.original == null ? l10n.eudRuleAdd : l10n.eudRuleEditTitle,
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.eudRuleName),
              ),
              _choices(
                l10n.eudRulePlayer,
                _player,
                List.generate(8, (i) => i),
                (p) => l10n.eudRulePlayerN('${p + 1}'),
                (p) => _player = p,
              ),
              if (!_isExtended)
                _choices(
                  l10n.eudRuleResource,
                  _resource,
                  EudResource.values,
                  (r) => EudRuleLabels.resource(l10n, r),
                  (r) => _resource = r,
                ),
              _choices(
                l10n.eudRuleComparison,
                _comparison,
                EudComparison.values,
                (v) => EudRuleLabels.comparison(l10n, v),
                (v) => _comparison = v,
              ),
              if (!_isExtended)
                TextField(
                  controller: _threshold,
                  decoration: InputDecoration(labelText: l10n.eudRuleThreshold),
                ),
              _choices(
                l10n.eudRuleAction,
                _operation,
                EudResourceOperation.values,
                (v) => EudRuleLabels.operation(l10n, v),
                (v) => _operation = v,
              ),
              if (!_isExtended)
                TextField(
                  controller: _amount,
                  decoration: InputDecoration(labelText: l10n.eudRuleAmount),
                ),
              EudRuleExtensionForm(
                key: _extension,
                initial: widget.original?.extension,
                onEnabledChanged: (value) =>
                    setState(() => _isExtended = value),
              ),
              _choices(
                l10n.eudRuleSchedule,
                _schedule,
                EudRuleSchedule.values,
                (v) => v == EudRuleSchedule.once
                    ? l10n.eudRuleOnce
                    : l10n.eudRulePeriodic,
                (v) => _schedule = v,
              ),
              TextField(
                controller: _interval,
                enabled: _schedule == EudRuleSchedule.periodic,
                decoration: InputDecoration(labelText: l10n.eudRuleInterval),
              ),
              SwitchListTile(
                title: Text(l10n.eudRuleEnabled),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
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
        FilledButton(
          key: const Key('eud-rule-apply'),
          onPressed: _apply,
          child: Text(l10n.eudRuleApply),
        ),
      ],
    );
  }
}
