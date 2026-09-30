import 'package:flutter/material.dart';
import '../localization/l10n.dart';
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
        throw StateError(context.l10n.eudProjectChanged);
      }
      if (_enabled == 'unsupported') {
        throw FormatException(context.l10n.eudShieldChooseSupported);
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
          throw FormatException(context.l10n.eudShieldWholeNumber);
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        l10n.eudShieldTitle(
          '${defaultUnitNames[widget.unit]} (#${widget.unit})',
        ),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.eudShieldHelp),
              DropdownButton<String>(
                key: const Key('eud-shield-enabled'),
                isExpanded: true,
                value: _enabled,
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(l10n.eudShieldNoOverride),
                  ),
                  DropdownMenuItem(
                    value: 'true',
                    child: Text(l10n.eudShieldEnabled),
                  ),
                  DropdownMenuItem(
                    value: 'false',
                    child: Text(l10n.eudShieldDisabled),
                  ),
                  if (_enabled == 'unsupported')
                    DropdownMenuItem(
                      value: 'unsupported',
                      child: Text(l10n.eudShieldUnsupported),
                    ),
                ],
                onChanged: (value) => setState(() => _enabled = value!),
              ),
              TextField(
                key: const Key('eud-shield-maximum'),
                controller: _maximum,
                decoration: InputDecoration(labelText: l10n.eudShieldMaximum),
              ),
              CheckboxListTile(
                key: const Key('eud-shield-override-chk'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.eudShieldOverrideChk),
                value: _overrideChk,
                onChanged: (value) => setState(() => _overrideChk = value!),
              ),
              Text(
                l10n.eudShieldInitNote,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFA7AFB8),
                ),
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
