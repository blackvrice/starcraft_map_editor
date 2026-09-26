import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_trigger_editor.dart';
import '../settings/default_unit_names.dart';

class TriggerPane extends StatefulWidget {
  const TriggerPane({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<TriggerPane> createState() => _TriggerPaneState();
}

class _TriggerPaneState extends State<TriggerPane> {
  String? _error;
  void _run(VoidCallback action) {
    try {
      action();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _edit(
    ChkTriggers triggers,
    int index,
    RawChkDocument snapshot,
  ) async {
    final result = await showDialog<ChkTrigger>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _RecordDialog(record: triggers.records[index], document: snapshot),
    );
    if (result == null || !mounted) return;
    _run(
      () => widget.controller.applyTriggers(
        expectedDocument: snapshot,
        records: [...triggers.records]..[index] = result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ObjectEditingState>(
    stream: widget.controller.changes,
    builder: (context, _) {
      ChkTriggers? triggers;
      String? readError;
      try {
        triggers = widget.controller.triggers;
      } catch (e) {
        readError = e.toString();
      }
      final data = triggers;
      final snapshot =
          widget.controller.openMapController.state.session?.rawDocument;
      void apply(List<ChkTrigger> records) => _run(
        () => widget.controller.applyTriggers(
          expectedDocument: snapshot!,
          records: records,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Triggers', style: TextStyle(fontSize: 22)),
                FilledButton(
                  key: const Key('trigger-add'),
                  onPressed: data == null
                      ? null
                      : () => apply([...data.records, ChkTrigger.create()]),
                  child: const Text('Add trigger'),
                ),
                TextButton(
                  onPressed: widget.controller.canUndo
                      ? () => _run(widget.controller.undo)
                      : null,
                  child: const Text('Undo'),
                ),
                TextButton(
                  onPressed: widget.controller.canRedo
                      ? () => _run(widget.controller.redo)
                      : null,
                  child: const Text('Redo'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Ordinary TRIG editor • 8 condition types / 12 action types. Unsupported and EUD slots remain raw. New triggers start with Never. Save As writes applied changes.',
            ),
          ),
          if (readError != null || _error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error ?? readError!),
            ),
          if (data != null)
            Expanded(
              child: ListView.builder(
                itemCount: data.records.length,
                itemBuilder: (context, index) {
                  final record = data.records[index];
                  final owners = [
                    for (var p = 0; p < 8; p++)
                      if (record.bytes[2372 + p] != 0) 'P${p + 1}',
                  ];
                  return ListTile(
                    key: ValueKey(('trigger', index)),
                    title: Text(
                      'Trigger ${index + 1} — ${owners.isEmpty ? 'No P1–P8 owner' : owners.join(', ')}',
                    ),
                    subtitle: Text(
                      '${_summary(record, false)} → ${_summary(record, true)}',
                    ),
                    onTap: () => _edit(data, index, snapshot!),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: index == 0
                              ? null
                              : () {
                                  final next = [...data.records];
                                  next[index] = next[index - 1];
                                  next[index - 1] = record;
                                  apply(next);
                                },
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: index == data.records.length - 1
                              ? null
                              : () {
                                  final next = [...data.records];
                                  next[index] = next[index + 1];
                                  next[index + 1] = record;
                                  apply(next);
                                },
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Duplicate trigger',
                          onPressed: () => apply(
                            [...data.records]
                              ..insert(index + 1, ChkTrigger(record.bytes)),
                          ),
                          icon: const Icon(Icons.copy),
                        ),
                        IconButton(
                          tooltip: 'Delete trigger',
                          onPressed: () async {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete trigger ${index + 1}?'),
                                content: const Text(
                                  'The entire record, including preserved unsupported slots, will be removed. Undo restores it.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (accepted == true && mounted) {
                              apply([...data.records]..removeAt(index));
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
  String _summary(ChkTrigger record, bool action) {
    final names = <String>[];
    for (var i = 0; i < (action ? 64 : 16); i++) {
      final slot = record.slot(action, i);
      if (slot.every((b) => b == 0)) continue;
      final id = ChkTrigger.type(action, slot);
      names.add(TriggerOpcodes.find(action, id)?.name ?? 'Raw #$id');
    }
    return names.isEmpty ? 'None' : names.take(3).join(', ');
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({required this.record, required this.document});
  final ChkTrigger record;
  final RawChkDocument document;
  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async => AppExitResponse.cancel,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  late ChkTrigger _draft = widget.record;
  Future<void> _slot(bool action, int index, {bool add = false}) async {
    final original = _draft.slot(action, index);
    final result = await showDialog<List<int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SlotDialog(
        action: action,
        original: add ? null : original,
        document: widget.document,
      ),
    );
    if (result != null && mounted) {
      setState(() => _draft = _draft.withSlot(action, index, result));
    }
  }

  Widget _slots(bool action) {
    final count = action ? 64 : 16;
    final used = [
      for (var i = 0; i < count; i++)
        if (_draft.slot(action, i).any((b) => b != 0)) i,
    ];
    final available = [
      for (var i = 0; i < count; i++)
        if (!used.contains(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              action
                  ? 'Actions (${used.length}/64)'
                  : 'Conditions (${used.length}/16)',
            ),
            const Spacer(),
            TextButton(
              key: Key(action ? 'trigger-add-action' : 'trigger-add-condition'),
              onPressed: available.isEmpty
                  ? null
                  : () => _slot(action, available.first, add: true),
              child: const Text('Add'),
            ),
          ],
        ),
        for (final index in used)
          Builder(
            builder: (context) {
              final slot = _draft.slot(action, index);
              final opcode = TriggerOpcodes.find(
                action,
                ChkTrigger.type(action, slot),
              );
              final editable = ChkTrigger.editable(action, slot);
              return ListTile(
                dense: true,
                title: Text(
                  '${index + 1}. ${opcode?.name ?? 'Raw type ${ChkTrigger.type(action, slot)}'}${editable ? '' : ' (preserved)'}',
                ),
                subtitle: Text(
                  editable
                      ? opcode!.arguments
                            .map(
                              (a) =>
                                  '${a.name}: ${ChkTrigger.argument(slot, a)}',
                            )
                            .join(', ')
                      : slot
                            .map((b) => b.toRadixString(16).padLeft(2, '0'))
                            .join(' '),
                ),
                onTap: editable ? () => _slot(action, index) : null,
                trailing: editable
                    ? IconButton(
                        tooltip: 'Remove slot',
                        onPressed: () => setState(
                          () => _draft = _draft.withSlot(
                            action,
                            index,
                            List.filled(action ? 32 : 20, 0),
                          ),
                        ),
                        icon: const Icon(Icons.remove_circle_outline),
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit trigger'),
    content: SizedBox(
      width: 820,
      height: 560,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Changes remain in this draft until Apply to map. Other owner bytes, execution flags and raw slots are preserved.',
            ),
            Wrap(
              children: [
                for (var p = 0; p < 8; p++)
                  FilterChip(
                    label: Text('Player ${p + 1}'),
                    selected: _draft.bytes[2372 + p] != 0,
                    onSelected: (v) =>
                        setState(() => _draft = _draft.withOwner(p, v)),
                  ),
              ],
            ),
            _slots(false),
            const Divider(),
            _slots(true),
            ExpansionTile(
              title: const Text('Raw record (read-only)'),
              children: [
                SelectableText(
                  _draft.bytes
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' '),
                ),
              ],
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
        key: const Key('trigger-apply'),
        onPressed: () => Navigator.pop(context, _draft),
        child: const Text('Apply to map'),
      ),
    ],
  );
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({
    required this.action,
    required this.original,
    required this.document,
  });
  final bool action;
  final List<int>? original;
  final RawChkDocument document;
  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  late TriggerOpcode _opcode = widget.original == null
      ? (widget.action
            ? TriggerOpcodes.actions.firstWhere((op) => op.id == 3)
            : TriggerOpcodes.conditions.first)
      : TriggerOpcodes.find(
          widget.action,
          ChkTrigger.type(widget.action, widget.original!),
        )!;
  final _values = <String, int>{};
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _values.clear();
    for (final arg in _opcode.arguments) {
      _values[arg.name] =
          widget.original != null &&
              _opcode.id == ChkTrigger.type(widget.action, widget.original!)
          ? ChkTrigger.argument(widget.original!, arg)
          : arg.choices.isNotEmpty
          ? arg.choices.keys.first
          : arg.reference == 'location' ||
                arg.reference == 'string' ||
                arg.name == 'Count'
          ? 1
          : 0;
    }
    _generation++;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.action ? 'Action' : 'Condition'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<TriggerOpcode>(
              key: const Key('trigger-opcode'),
              isExpanded: true,
              value: _opcode,
              items: [
                for (final op
                    in widget.action
                        ? TriggerOpcodes.actions
                        : TriggerOpcodes.conditions)
                  DropdownMenuItem(value: op, child: Text(op.name)),
              ],
              onChanged: widget.original != null
                  ? null
                  : (op) => setState(() {
                      _opcode = op!;
                      _reset();
                    }),
            ),
            if (widget.original != null)
              const Text('Remove and add a slot to change its type.'),
            for (final arg in _opcode.arguments)
              if (arg.choices.isNotEmpty || arg.reference == 'unit')
                DropdownButton<int>(
                  key: ValueKey(('trigger-argument', arg.name)),
                  isExpanded: true,
                  value: _values[arg.name],
                  items: [
                    if (arg.reference == 'unit')
                      for (var i = 0; i < 228; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${defaultUnitNames[i]} (#$i)'),
                        )
                    else
                      for (final choice in arg.choices.entries)
                        DropdownMenuItem(
                          value: choice.key,
                          child: Text('${arg.name}: ${choice.value}'),
                        ),
                    if (arg.reference != 'unit' &&
                        !arg.choices.containsKey(_values[arg.name]))
                      DropdownMenuItem(
                        value: _values[arg.name],
                        child: Text('Stored ${_values[arg.name]}'),
                      ),
                    if (arg.reference == 'unit' && _values[arg.name]! > 227)
                      DropdownMenuItem(
                        value: _values[arg.name],
                        child: Text('Stored unit ${_values[arg.name]}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _values[arg.name] = v!),
                )
              else
                TextFormField(
                  key: ValueKey(('trigger-number', _generation, arg.name)),
                  initialValue: '${_values[arg.name]}',
                  decoration: InputDecoration(labelText: arg.name),
                  onChanged: (text) =>
                      _values[arg.name] = int.tryParse(text) ?? -1,
                ),
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
      FilledButton(
        key: const Key('trigger-slot-apply'),
        onPressed: () {
          try {
            final slot = ChkTrigger.makeSlot(
              widget.action,
              _opcode,
              _values,
              widget.document,
              original: widget.original,
            );
            Navigator.pop(context, slot);
          } catch (e) {
            setState(() => _error = e.toString());
          }
        },
        child: const Text('Use slot'),
      ),
    ],
  );
}
