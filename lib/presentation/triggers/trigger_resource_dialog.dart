import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_trigger_resources.dart';

enum TriggerResourceKind { text, switchName, property }

class TriggerResourceDialog extends StatefulWidget {
  const TriggerResourceDialog({
    required this.document,
    required this.kind,
    super.key,
  });
  final RawChkDocument document;
  final TriggerResourceKind kind;
  @override
  State<TriggerResourceDialog> createState() => _TriggerResourceDialogState();
}

class _TriggerResourceDialogState extends State<TriggerResourceDialog> {
  int _id = 1, _generation = 0;
  String _text = '', _message = '';
  String? _error;
  Map<String, int?> _values = {};
  List<bool?> _special = List.filled(5, null);
  RawChkDocument? _prepared;
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async => AppExitResponse.cancel,
    );
    if (widget.kind == TriggerResourceKind.switchName) _id = 0;
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _load() {
    _error = null;
    _prepared = null;
    _message = '';
    _generation++;
    try {
      if (widget.kind == TriggerResourceKind.property) {
        _values = ChkTriggerResources.propertyValues(widget.document, _id);
        _special = ChkTriggerResources.specialValues(widget.document, _id);
        _message =
            '${ChkTriggerResources.propertyUsers(widget.document, _id)} action(s) reference this slot. Applying changes affects all of them.';
      }
      if (widget.kind == TriggerResourceKind.switchName) {
        _text = ChkTriggerResources.switchName(widget.document, _id);
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  void _prepare() {
    try {
      switch (widget.kind) {
        case TriggerResourceKind.text:
          final added = ChkTriggerResources.addText(widget.document, _text);
          _prepared = added.$1;
          _message =
              'New string ID: ${added.$2}. Use this ID in a trigger action.';
        case TriggerResourceKind.switchName:
          _prepared = ChkTriggerResources.renameSwitch(
            widget.document,
            _id,
            _text,
          );
        case TriggerResourceKind.property:
          _prepared = ChkTriggerResources.editProperty(
            widget.document,
            _id,
            _values,
            _special,
          );
      }
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(switch (widget.kind) {
      TriggerResourceKind.text => 'Add trigger text',
      TriggerResourceKind.switchName => 'Switch names',
      TriggerResourceKind.property => 'Unit property slots',
    }),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.kind != TriggerResourceKind.text)
              DropdownButton<int>(
                key: const Key('trigger-resource-id'),
                isExpanded: true,
                value: _id,
                items: [
                  for (
                    var i = widget.kind == TriggerResourceKind.property ? 1 : 0;
                    i <
                        (widget.kind == TriggerResourceKind.property
                            ? 65
                            : 256);
                    i++
                  )
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${widget.kind == TriggerResourceKind.property ? 'Property' : 'Switch'} ID $i',
                      ),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _id = id!;
                  _load();
                }),
              ),
            if (widget.kind != TriggerResourceKind.property)
              TextFormField(
                key: ValueKey(('trigger-resource-text', _generation)),
                initialValue: _text,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Text'),
                onChanged: (s) => setState(() {
                  _text = s;
                  _prepared = null;
                }),
              ),
            if (widget.kind == TriggerResourceKind.property) ...[
              const Text(
                'Unchecked values inherit the game default. Special states can inherit, enable or disable.',
              ),
              for (final arg in ChkTriggerResources.propertyFields)
                Row(
                  children: [
                    Checkbox(
                      value: _values[arg.name] != null,
                      onChanged: (v) => setState(() {
                        _values[arg.name] = v! ? 0 : null;
                        _prepared = null;
                        _generation++;
                      }),
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey((_generation, arg.name)),
                        enabled: _values[arg.name] != null,
                        initialValue: '${_values[arg.name] ?? 0}',
                        decoration: InputDecoration(labelText: arg.name),
                        onChanged: (s) => setState(() {
                          _values[arg.name] = int.tryParse(s) ?? -1;
                          _prepared = null;
                        }),
                      ),
                    ),
                  ],
                ),
              for (var i = 0; i < 5; i++)
                DropdownButton<int>(
                  isExpanded: true,
                  value: _special[i] == null
                      ? 0
                      : _special[i]!
                      ? 1
                      : 2,
                  items: [
                    for (final e in {
                      0: 'Inherit',
                      1: 'Enabled',
                      2: 'Disabled',
                    }.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          '${ChkTriggerResources.specialNames[i]}: ${e.value}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _special[i] = v == 0 ? null : v == 1;
                    _prepared = null;
                  }),
                ),
            ],
            if (_message.isNotEmpty) Text(_message),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (_prepared == null)
        FilledButton(
          key: const Key('trigger-resource-prepare'),
          onPressed: _prepare,
          child: const Text('Prepare changes'),
        )
      else
        FilledButton(
          key: const Key('trigger-resource-apply'),
          onPressed: () => Navigator.pop(context, _prepared),
          child: const Text('Apply to map'),
        ),
    ],
  );
}
