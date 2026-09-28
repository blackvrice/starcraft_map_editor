import 'package:flutter/material.dart';
import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_execution_rule.dart';
import '../../domain/eud/eud_project.dart';

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

  @override
  Widget build(BuildContext context) {
    final project = controller.project!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EUD execution rules (${project.rules.length}/${EudProject.maxRules})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Synchronized player resources • Executes before ordinary triggers. Periods count trigger cycles, not seconds. Save Project, then Prepare EUD Build to test.',
            ),
            const Text(
              'One enabled writer per player/resource. User code and ordinary triggers may also change resources; review them separately.',
            ),
            OutlinedButton.icon(
              key: const Key('eud-rule-add'),
              onPressed: enabled && project.rules.length < EudProject.maxRules
                  ? () => _edit(context, null)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Add execution rule'),
            ),
            for (final rule in project.rules)
              ListTile(
                title: Text('${rule.name}${rule.enabled ? '' : ' (disabled)'}'),
                subtitle: Text(
                  'Player ${rule.player + 1} • ${rule.resource.name} ${rule.comparison.name} ${rule.threshold} → ${rule.operation.name} ${rule.amount} • ${rule.schedule == EudRuleSchedule.once ? 'Once on first match' : 'Every ${rule.interval} cycles'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit rule',
                      onPressed: enabled ? () => _edit(context, rule) : null,
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Delete rule',
                      onPressed: enabled
                          ? () => controller.replaceRules(
                              project.rules.where((r) => r.id != rule.id),
                              expectedProject: project,
                            )
                          : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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
  late final _name = TextEditingController(
    text: widget.original?.name ?? 'Resource rule',
  );
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
  late bool _enabled = widget.original?.enabled ?? true;
  String? _error;

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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.original == null ? 'Add execution rule' : 'Edit execution rule',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Rule name'),
            ),
            _choices(
              'Player',
              _player,
              List.generate(8, (i) => i),
              (p) => 'Player ${p + 1}',
              (p) => _player = p,
            ),
            _choices(
              'Resource (condition and action)',
              _resource,
              EudResource.values,
              (r) => r == EudResource.ore ? 'Minerals' : 'Gas',
              (r) => _resource = r,
            ),
            _choices(
              'Comparison',
              _comparison,
              EudComparison.values,
              (v) => v.name,
              (v) => _comparison = v,
            ),
            TextField(
              controller: _threshold,
              decoration: const InputDecoration(
                labelText: 'Threshold (0–2147483647)',
              ),
            ),
            _choices(
              'Action',
              _operation,
              EudResourceOperation.values,
              (v) => v.name,
              (v) => _operation = v,
            ),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Amount (0–2147483647)',
              ),
            ),
            _choices(
              'Schedule',
              _schedule,
              EudRuleSchedule.values,
              (v) => v == EudRuleSchedule.once
                  ? 'Once on first match'
                  : 'Periodic',
              (v) => _schedule = v,
            ),
            TextField(
              controller: _interval,
              enabled: _schedule == EudRuleSchedule.periodic,
              decoration: const InputDecoration(
                labelText: 'Interval (12–86400 trigger cycles)',
              ),
            ),
            SwitchListTile(
              title: const Text('Enabled'),
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
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('eud-rule-apply'),
        onPressed: _apply,
        child: const Text('Apply rule'),
      ),
    ],
  );
}
