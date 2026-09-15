import 'package:flutter/material.dart';
import '../../application/eud/eud_project_controller.dart';
import '../../domain/eud/eud_project.dart';
import '../settings/default_unit_names.dart';

Future<void> showEudShieldEditor(
  BuildContext context, {
  required EudProjectController controller,
  required int unit,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ShieldDialog(controller: controller, unit: unit),
);

class _ShieldDialog extends StatefulWidget {
  const _ShieldDialog({required this.controller, required this.unit});
  final EudProjectController controller;
  final int unit;
  @override
  State<_ShieldDialog> createState() => _ShieldDialogState();
}

class _ShieldDialogState extends State<_ShieldDialog> {
  late final EudProject _base;
  late final TextEditingController _maximum;
  String _enabled = '';
  bool _overrideChk = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _base = widget.controller.project!;
    EudOverride? find(String field) => _base.overrides
        .where((o) => o.field == field && o.targetId == widget.unit)
        .firstOrNull;
    final enabled = find('unit.hasShield');
    _enabled = enabled == null
        ? ''
        : enabled.value is bool
        ? enabled.value.toString()
        : 'unsupported';
    final maximum = find('unit.maxShield');
    _maximum = TextEditingController(text: maximum?.value.toString() ?? '');
    _overrideChk = maximum?.overrideChk ?? false;
  }

  @override
  void dispose() {
    _maximum.dispose();
    super.dispose();
  }

  void _apply() {
    try {
      if (!identical(_base, widget.controller.project)) {
        throw StateError('Project changed. Cancel and reopen this editor.');
      }
      if (_enabled == 'unsupported') {
        throw const FormatException(
          'Choose a supported shield activation value.',
        );
      }
      final values = [
        for (final item in _base.overrides)
          if (item.targetId != widget.unit ||
              !['unit.hasShield', 'unit.maxShield'].contains(item.field))
            item,
      ];
      if (_enabled.isNotEmpty) {
        values.add(
          EudOverride(
            field: 'unit.hasShield',
            targetId: widget.unit,
            value: _enabled == 'true',
          ),
        );
      }
      final text = _maximum.text.trim();
      if (text.isNotEmpty) {
        if (!RegExp(r'^\d{1,5}$').hasMatch(text)) {
          throw const FormatException(
            'Maximum shields require a whole number from 0 to 65535.',
          );
        }
        values.add(
          EudOverride(
            field: 'unit.maxShield',
            targetId: widget.unit,
            value: int.parse(text),
            overrideChk: _overrideChk,
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${defaultUnitNames[widget.unit]} (#${widget.unit}) — Shields'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activation and maximum are independent type settings shared by all players. Blank maximum or No override removes that setting; defaults are unknown.',
            ),
            DropdownButton<String>(
              key: const Key('eud-shield-enabled'),
              isExpanded: true,
              value: _enabled,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('No activation override'),
                ),
                const DropdownMenuItem(
                  value: 'true',
                  child: Text('Shields enabled'),
                ),
                const DropdownMenuItem(
                  value: 'false',
                  child: Text('Shields disabled'),
                ),
                if (_enabled == 'unsupported')
                  const DropdownMenuItem(
                    value: 'unsupported',
                    child: Text('Unsupported imported activation'),
                  ),
              ],
              onChanged: (value) => setState(() => _enabled = value!),
            ),
            TextField(
              key: const Key('eud-shield-maximum'),
              controller: _maximum,
              decoration: const InputDecoration(
                labelText: 'Maximum shields (0–65535)',
              ),
            ),
            CheckboxListTile(
              key: const Key('eud-shield-override-chk'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Explicitly override CHK maximum shields'),
              value: _overrideChk,
              onChanged: (value) => setState(() => _overrideChk = value!),
            ),
            const Text(
              'Initialization is not implemented: existing placed units keep their CHK shield percentages; no current-shield refill, clamp or recurring write is generated. New-unit initialization requires runtime verification. Applying saves project intent only; EUD build integration is pending.',
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
