import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_trigger_editor.dart';
import '../../domain/chk/typed/chk_trigger_resources.dart';
import 'trigger_resource_dialog.dart';
import '../settings/default_unit_names.dart';

class TriggerPane extends StatefulWidget {
  const TriggerPane({required this.controller, super.key});
  final ObjectEditingController controller;
  @override
  State<TriggerPane> createState() => _TriggerPaneState();
}

class _TriggerPaneState extends State<TriggerPane> {
  String? _error;
  final _selected = <int>{};
  RawChkDocument? _selectionDocument;
  Future<void> _owners(ChkTriggers data, RawChkDocument snapshot) async {
    final changes = <int, bool>{};
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Owners for selected triggers'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unchanged preserves each trigger’s owner. Choose Add or Remove to apply.',
                  ),
                  for (final owner in TriggerOpcodes.owners.entries)
                    DropdownButton<int>(
                      isExpanded: true,
                      value: changes[owner.key] == null
                          ? 0
                          : changes[owner.key]!
                          ? 1
                          : 2,
                      items: [
                        for (final e in {
                          0: 'Unchanged',
                          1: 'Add',
                          2: 'Remove',
                        }.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Text('${owner.value}: ${e.value}'),
                          ),
                      ],
                      onChanged: (v) => set(
                        () => v == 0
                            ? changes.remove(owner.key)
                            : changes[owner.key] = v == 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply owners'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    _run(
      () => widget.controller.applyTriggers(
        expectedDocument: snapshot,
        records: [
          for (var i = 0; i < data.records.length; i++)
            _selected.contains(i)
                ? changes.entries.fold(
                    data.records[i],
                    (r, e) => r.withOwner(e.key, e.value),
                  )
                : data.records[i],
        ],
      ),
    );
  }

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
      if (!identical(snapshot, _selectionDocument)) {
        _selected.clear();
        _selectionDocument = snapshot;
      }
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
                if (data != null)
                  TextButton(
                    onPressed: () {
                      final issues = ChkTriggers.validationIssues(snapshot!);
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Trigger validation'),
                          content: SizedBox(
                            width: 640,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                issues.isEmpty
                                    ? 'Supported slots have valid field values and references. Raw/EUD slots are not interpreted.'
                                    : issues.join('\n'),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Validate references'),
                  ),
                if (data != null) ...[
                  TextButton(
                    onPressed: () => setState(
                      () => _selected.length == data.records.length
                          ? _selected.clear()
                          : _selected.addAll(
                              List.generate(data.records.length, (i) => i),
                            ),
                    ),
                    child: const Text('Select all / none'),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _owners(data, snapshot!),
                    child: const Text('Owners…'),
                  ),
                  for (final enabled in [true, false])
                    TextButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => apply([
                              for (var i = 0; i < data.records.length; i++)
                                _selected.contains(i)
                                    ? data.records[i].withEnabled(enabled)
                                    : data.records[i],
                            ]),
                      child: Text(
                        enabled ? 'Enable selected' : 'Disable selected',
                      ),
                    ),
                  for (final kind in TriggerResourceKind.values)
                    TextButton(
                      onPressed: () async {
                        final result = await showDialog<RawChkDocument>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => TriggerResourceDialog(
                            document: snapshot!,
                            kind: kind,
                          ),
                        );
                        if (result != null && mounted) {
                          _run(
                            () => widget.controller.applyTriggerResources(
                              expectedDocument: snapshot!,
                              updatedDocument: result,
                            ),
                          );
                        }
                      },
                      child: Text(switch (kind) {
                        TriggerResourceKind.text => 'Add text…',
                        TriggerResourceKind.switchName => 'Switch names…',
                        TriggerResourceKind.property => 'Unit properties…',
                      }),
                    ),
                ],
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
              'Ordinary TRIG editor • 22 condition types / 57 action types. Unsupported and EUD slots remain raw. New triggers start with Never. Save As writes applied changes.',
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
                    for (final e in TriggerOpcodes.owners.entries)
                      if (record.bytes[2372 + e.key] != 0) e.value,
                  ];
                  return ListTile(
                    key: ValueKey(('trigger', index)),
                    leading: Checkbox(
                      value: _selected.contains(index),
                      onChanged: (v) => setState(
                        () =>
                            v! ? _selected.add(index) : _selected.remove(index),
                      ),
                    ),
                    title: Text(
                      'Trigger ${index + 1}${record.enabled ? '' : ' (disabled)'} — ${owners.isEmpty ? 'No owner' : owners.join(', ')}',
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
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip:
                                '${action ? 'Action' : 'Condition'} enabled',
                            icon: Icon(
                              slot[action ? 28 : 17] & 2 == 0
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                            ),
                            onPressed: () => setState(
                              () => _draft = _draft.withSlotEnabled(
                                action,
                                index,
                                slot[action ? 28 : 17] & 2 != 0,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Move slot up',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: index == 0
                                ? null
                                : () => setState(
                                    () => _draft = _draft.moveSlot(
                                      action,
                                      index,
                                      index - 1,
                                    ),
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Move slot down',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: index == count - 1
                                ? null
                                : () => setState(
                                    () => _draft = _draft.moveSlot(
                                      action,
                                      index,
                                      index + 1,
                                    ),
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Duplicate slot',
                            icon: const Icon(Icons.copy),
                            onPressed: available.isEmpty
                                ? null
                                : () => setState(
                                    () => _draft = _draft.withSlot(
                                      action,
                                      available.first,
                                      slot,
                                    ),
                                  ),
                          ),
                          IconButton(
                            tooltip: 'Remove slot',
                            onPressed: () => setState(
                              () => _draft = _draft.withSlot(
                                action,
                                index,
                                List.filled(action ? 32 : 20, 0),
                              ),
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
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
                FilterChip(
                  label: const Text('Trigger enabled'),
                  selected: _draft.enabled,
                  onSelected: (v) =>
                      setState(() => _draft = _draft.withEnabled(v)),
                ),
                for (final entry in TriggerOpcodes.owners.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _draft.bytes[2372 + entry.key] != 0,
                    onSelected: (v) =>
                        setState(() => _draft = _draft.withOwner(entry.key, v)),
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
  Widget _argumentWidget(TriggerArgument arg) {
    final units = arg.reference == 'unit' || arg.reference == 'unitGroup';
    final choices = <int, String>{...arg.choices};
    if (units) {
      for (var i = 0; i < 228; i++) {
        choices[i] = '${defaultUnitNames[i]} (#$i)';
      }
    }
    if (arg.reference == 'unitGroup') {
      choices.addAll({
        229: 'Any unit',
        230: 'Men',
        231: 'Buildings',
        232: 'Factories',
      });
    }
    if (choices.isNotEmpty) {
      choices.putIfAbsent(
        _values[arg.name]!,
        () => 'Stored ${_values[arg.name]}',
      );
      return DropdownButton<int>(
        key: ValueKey(('trigger-argument', arg.name)),
        isExpanded: true,
        value: _values[arg.name],
        items: [
          for (final e in choices.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(
                '${arg.name}: ${e.value}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => _values[arg.name] = v!),
      );
    }
    if (arg.reference == 'script') {
      return TextFormField(
        key: ValueKey(('trigger-script', _generation)),
        initialValue: _values[arg.name] == 0
            ? ''
            : String.fromCharCodes(
                List.generate(4, (i) => (_values[arg.name]! >> (8 * i)) & 255),
              ),
        decoration: InputDecoration(labelText: arg.name),
        maxLength: 4,
        onChanged: (s) {
          _values[arg.name] =
              s.length == 4 && s.codeUnits.every((c) => c >= 32 && c <= 126)
              ? s.codeUnits.asMap().entries.fold<int>(
                  0,
                  (n, e) => n | (e.value << (8 * e.key)),
                )
              : -1;
        },
      );
    }
    String? hint;
    try {
      if (arg.reference == 'switch') {
        hint = ChkTriggerResources.switchName(
          widget.document,
          (_values[arg.name] ?? 0).clamp(0, 255),
        );
      }
      if (arg.reference == 'string') {
        hint = ChkTriggerResources.stringLabel(
          widget.document,
          _values[arg.name] ?? 0,
        );
      }
    } catch (e) {
      hint = e.toString();
    }
    return TextFormField(
      key: ValueKey(('trigger-number', _generation, arg.name)),
      initialValue: '${_values[arg.name]}',
      decoration: InputDecoration(
        labelText: arg.name,
        helperText: hint,
        helperMaxLines: 2,
      ),
      onChanged: (s) =>
          setState(() => _values[arg.name] = int.tryParse(s) ?? -1),
    );
  }

  late TriggerOpcode _opcode = widget.original == null
      ? (widget.action
            ? TriggerOpcodes.actions.firstWhere((op) => op.id == 3)
            : TriggerOpcodes.conditions.first)
      : TriggerOpcodes.find(
          widget.action,
          ChkTrigger.type(widget.action, widget.original!),
        )!;
  final _values = <String, int>{};
  late bool _alwaysDisplay =
      widget.original == null || widget.original![28] & 4 != 0;
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
                arg.reference == 'property' ||
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
              onChanged: (op) => setState(() {
                _opcode = op!;
                _reset();
              }),
            ),
            if (widget.original != null)
              const Text(
                'Changing type replaces this slot’s arguments when applied.',
              ),
            if (widget.action && {7, 9}.contains(_opcode.id))
              CheckboxListTile(
                title: const Text('Always display text'),
                value: _alwaysDisplay,
                onChanged: (v) => setState(() => _alwaysDisplay = v!),
              ),
            for (final arg in _opcode.arguments) _argumentWidget(arg),
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
              original:
                  widget.original != null &&
                      ChkTrigger.type(widget.action, widget.original!) ==
                          _opcode.id
                  ? widget.original
                  : null,
            );
            if (widget.action && {7, 9}.contains(_opcode.id)) {
              slot[28] = _alwaysDisplay ? slot[28] | 4 : slot[28] & ~4;
            }
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
