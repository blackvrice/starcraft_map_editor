import 'package:flutter/material.dart';
import 'dart:ui' show AppExitResponse;
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_trigger_editor.dart';
import '../../domain/chk/typed/chk_trigger_resources.dart';
import '../localization/l10n.dart';
import 'trigger_labels.dart';
import 'trigger_resource_dialog.dart';
import '../settings/default_unit_names.dart';

const _ownerOffset = 2372;

List<String> _ownerNames(ChkTrigger record, String localeName) => [
  for (final e in TriggerOpcodes.owners.entries)
    if (record.bytes[_ownerOffset + e.key] != 0)
      TriggerLabels.value(localeName, e.value),
];

List<List<int>> _usedSlots(ChkTrigger record, bool action) => [
  for (var i = 0; i < (action ? 64 : 16); i++)
    if (record.slot(action, i).any((b) => b != 0)) record.slot(action, i),
];

class TriggerPane extends StatefulWidget {
  const TriggerPane({
    required this.controller,
    this.briefing = false,
    super.key,
  });
  final ObjectEditingController controller;
  final bool briefing;
  @override
  State<TriggerPane> createState() => _TriggerPaneState();
}

class _TriggerPaneState extends State<TriggerPane> {
  String? _error;
  final _selected = <int>{};
  RawChkDocument? _selectionDocument;
  Future<void> _owners(ChkTriggers data, RawChkDocument snapshot) async {
    final l10n = context.l10n;
    final localeName = l10n.localeName;
    final changes = <int, bool>{};
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(
            widget.briefing
                ? l10n.trigOwnersBriefingTitle
                : l10n.trigOwnersTitle,
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.trigOwnersHelp,
                    style: const TextStyle(color: Color(0xFFA7AFB8)),
                  ),
                  const SizedBox(height: 8),
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
                          0: l10n.trigOwnerUnchanged,
                          1: l10n.trigOwnerAdd,
                          2: l10n.trigOwnerRemove,
                        }.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              '${TriggerLabels.value(localeName, owner.value)}: ${e.value}',
                            ),
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
              child: Text(l10n.trigCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.trigApplyOwners),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    _run(
      () => widget.controller.applyTriggers(
        briefing: widget.briefing,
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
        briefing: widget.briefing,
        expectedDocument: snapshot,
        records: [...triggers.records]..[index] = result,
      ),
    );
  }

  void _validate(RawChkDocument snapshot) {
    final l10n = context.l10n;
    final issues = ChkTriggers.validationIssues(
      snapshot,
      briefing: widget.briefing,
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trigValidationTitle),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: SelectableText(
              issues.isEmpty ? l10n.trigValidationOk : issues.join('\n'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.trigClose),
          ),
        ],
      ),
    );
  }

  Future<void> _resources(
    TriggerResourceKind kind,
    RawChkDocument snapshot,
  ) async {
    final result = await showDialog<RawChkDocument>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TriggerResourceDialog(document: snapshot, kind: kind),
    );
    if (result != null && mounted) {
      _run(
        () => widget.controller.applyTriggerResources(
          expectedDocument: snapshot,
          updatedDocument: result,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ObjectEditingState>(
    stream: widget.controller.changes,
    builder: (context, _) {
      final l10n = context.l10n;
      ChkTriggers? triggers;
      String? readError;
      try {
        triggers = widget.controller.readTriggers(briefing: widget.briefing);
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
          briefing: widget.briefing,
          expectedDocument: snapshot!,
          records: records,
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  widget.briefing ? l10n.trigBriefingTitle : l10n.trigTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data != null) ...[
                  const SizedBox(width: 10),
                  _Pill(text: l10n.trigCount(data.records.length)),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.controller.canUndo
                      ? () => _run(widget.controller.undo)
                      : null,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(l10n.trigUndo),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: widget.controller.canRedo
                      ? () => _run(widget.controller.redo)
                      : null,
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  label: Text(l10n.trigRedo),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const Key('trigger-add'),
                  onPressed: data == null
                      ? null
                      : () => apply([
                          ...data.records,
                          ChkTrigger.create(briefing: widget.briefing),
                        ]),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    widget.briefing ? l10n.trigAddBriefing : l10n.trigAdd,
                  ),
                ),
              ],
            ),
          ),
          if (data != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 20, 4),
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _validate(snapshot!),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: Text(l10n.trigValidate),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(
                      () => _selected.length == data.records.length
                          ? _selected.clear()
                          : _selected.addAll(
                              List.generate(data.records.length, (i) => i),
                            ),
                    ),
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: Text(l10n.trigSelectAll),
                  ),
                  for (final kind
                      in widget.briefing
                          ? [TriggerResourceKind.text]
                          : TriggerResourceKind.values)
                    TextButton.icon(
                      onPressed: () => _resources(kind, snapshot!),
                      icon: Icon(switch (kind) {
                        TriggerResourceKind.text => Icons.notes_rounded,
                        TriggerResourceKind.switchName =>
                          Icons.toggle_on_outlined,
                        TriggerResourceKind.property => Icons.tune_rounded,
                      }, size: 18),
                      label: Text(switch (kind) {
                        TriggerResourceKind.text => l10n.trigAddText,
                        TriggerResourceKind.switchName => l10n.trigSwitchNames,
                        TriggerResourceKind.property => l10n.trigUnitProperties,
                      }),
                    ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _Pill(
                      text: l10n.trigSelectedCount(_selected.length),
                      accent: true,
                    ),
                  ],
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _owners(data, snapshot!),
                    child: Text(l10n.trigOwners),
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
                        enabled
                            ? l10n.trigEnableSelected
                            : l10n.trigDisableSelected,
                      ),
                    ),
                ],
              ),
            ),
          _Banner(
            icon: Icons.lightbulb_outline_rounded,
            text: widget.briefing ? l10n.trigBriefingHelp : l10n.trigHelp,
          ),
          if (readError != null || _error != null)
            _Banner(
              icon: Icons.error_outline_rounded,
              text: _error ?? readError!,
              error: true,
            ),
          if (data != null && data.records.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  l10n.trigEmpty,
                  style: const TextStyle(color: Color(0xFFA7AFB8)),
                ),
              ),
            ),
          if (data != null && data.records.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: data.records.length,
                itemBuilder: (context, index) => _TriggerCard(
                  key: ValueKey(('trigger', index)),
                  record: data.records[index],
                  index: index,
                  count: data.records.length,
                  briefing: widget.briefing,
                  selected: _selected.contains(index),
                  onSelected: (v) => setState(
                    () => v ? _selected.add(index) : _selected.remove(index),
                  ),
                  onOpen: () => _edit(data, index, snapshot!),
                  onMove: (delta) {
                    final next = [...data.records];
                    final record = next[index];
                    next[index] = next[index + delta];
                    next[index + delta] = record;
                    apply(next);
                  },
                  onDuplicate: () => apply(
                    [...data.records]..insert(
                      index + 1,
                      ChkTrigger(
                        data.records[index].bytes,
                        briefing: widget.briefing,
                      ),
                    ),
                  ),
                  onDelete: () async {
                    final name = widget.briefing
                        ? l10n.trigBriefingItemTitle(index + 1)
                        : l10n.trigItemTitle(index + 1);
                    final accepted = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.trigDeleteTitle(name)),
                        content: Text(l10n.trigDeleteBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n.trigCancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l10n.trigDeleteConfirm),
                          ),
                        ],
                      ),
                    );
                    if (accepted == true && mounted) {
                      apply([...data.records]..removeAt(index));
                    }
                  },
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({
    required this.record,
    required this.index,
    required this.count,
    required this.briefing,
    required this.selected,
    required this.onSelected,
    required this.onOpen,
    required this.onMove,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final ChkTrigger record;
  final int index;
  final int count;
  final bool briefing;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onOpen;
  final ValueChanged<int> onMove;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  String _summary(BuildContext context, bool action) {
    final l10n = context.l10n;
    final slots = _usedSlots(record, action);
    if (slots.isEmpty) return l10n.trigNothing;
    final names = [
      for (final slot in slots.take(2))
        TriggerLabels.slotSentence(
          l10n.localeName,
          slot,
          action: action,
          briefing: briefing,
        ),
    ];
    return [
      ...names,
      if (slots.length > 2) l10n.trigMore(slots.length - 2),
    ].join('   ·   ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final owners = _ownerNames(record, l10n.localeName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFF1E2A2E) : const Color(0xFF1B1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? const Color(0xFF56C2D6) : const Color(0xFF2C3137),
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: record.enabled ? 1 : 0.6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: selected, onChanged: (v) => onSelected(v!)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              briefing
                                  ? l10n.trigBriefingItemTitle(index + 1)
                                  : l10n.trigItemTitle(index + 1),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _Pill(
                              text: record.enabled ? l10n.trigOn : l10n.trigOff,
                              accent: record.enabled,
                            ),
                            Text(
                              owners.isEmpty
                                  ? l10n.trigNoOwner
                                  : owners.join(', '),
                              style: TextStyle(
                                fontSize: 12,
                                color: owners.isEmpty
                                    ? const Color(0xFFE3C267)
                                    : const Color(0xFFA7AFB8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!briefing)
                          _SummaryLine(
                            label: l10n.trigWhen,
                            color: const Color(0xFFA9C7EE),
                            background: const Color(0xFF1D2836),
                            text: _summary(context, false),
                          ),
                        _SummaryLine(
                          label: briefing
                              ? l10n.trigBriefingSteps
                              : l10n.trigThen,
                          color: const Color(0xFFF0C982),
                          background: const Color(0xFF2A2418),
                          text: _summary(context, true),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.trigMoveUp,
                    onPressed: index == 0 ? null : () => onMove(-1),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.trigMoveDown,
                    onPressed: index == count - 1 ? null : () => onMove(1),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton(
                    tooltip: briefing
                        ? l10n.trigDuplicateBriefing
                        : l10n.trigDuplicate,
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: briefing
                        ? l10n.trigDeleteBriefing
                        : l10n.trigDelete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.color,
    required this.background,
    required this.text,
  });

  final String label;
  final Color color;
  final Color background;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFFDFE3E8)),
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: accent ? const Color(0xFF16231A) : const Color(0xFF23272C),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: accent ? const Color(0xFF2F4A36) : Colors.transparent,
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: accent ? const Color(0xFF9FDCB2) : const Color(0xFFC9CFD6),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: error ? const Color(0xFF241A1C) : const Color(0xFF16191D),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: error ? const Color(0xFF5A3A3E) : const Color(0xFF262A30),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: error ? const Color(0xFFEF8A91) : const Color(0xFF8DA2C2),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFC9CFD6),
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
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
        briefing: _draft.briefing,
        original: add ? null : original,
        document: widget.document,
      ),
    );
    if (result != null && mounted) {
      setState(() => _draft = _draft.withSlot(action, index, result));
    }
  }

  Widget _slots(bool action) {
    final l10n = context.l10n;
    final count = action ? 64 : 16;
    final used = [
      for (var i = 0; i < count; i++)
        if (_draft.slot(action, i).any((b) => b != 0)) i,
    ];
    final available = [
      for (var i = 0; i < count; i++)
        if (!used.contains(i)) i,
    ];
    final (label, labelColor, labelBackground, hint, accent) = action
        ? (
            _draft.briefing ? l10n.trigBriefingSteps : l10n.trigThen,
            const Color(0xFFF0C982),
            const Color(0xFF2A2418),
            l10n.trigThenInOrder,
            const Color(0xFFE3A64A),
          )
        : (
            l10n.trigWhen,
            const Color(0xFFA9C7EE),
            const Color(0xFF1D2836),
            l10n.trigWhenAll,
            const Color(0xFF7FB2FF),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: labelBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(hint, style: const TextStyle(color: Color(0xFFA7AFB8))),
            const Spacer(),
            Text(
              l10n.trigSlotCount(used.length, count),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7D8691)),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: Key(action ? 'trigger-add-action' : 'trigger-add-condition'),
              onPressed: available.isEmpty
                  ? null
                  : () => _slot(action, available.first, add: true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.trigAddSlot),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final index in used)
          Builder(
            builder: (context) {
              final slot = _draft.slot(action, index);
              final editable = ChkTrigger.editable(
                action,
                slot,
                briefing: _draft.briefing,
              );
              final slotEnabled = slot[action ? 28 : 17] & 2 == 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: const Color(0xFF1B1E22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF2C3137)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: editable ? () => _slot(action, index) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Opacity(
                              opacity: slotEnabled ? 1 : 0.5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TriggerLabels.slotSentence(
                                      l10n.localeName,
                                      slot,
                                      action: action,
                                      briefing: _draft.briefing,
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  if (!editable)
                                    Text(
                                      '${l10n.trigPreserved} · ${slot.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8B939C),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (editable) ...[
                            IconButton(
                              tooltip: l10n.trigSlotEnabled,
                              icon: Icon(
                                slotEnabled
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                              ),
                              onPressed: () => setState(
                                () => _draft = _draft.withSlotEnabled(
                                  action,
                                  index,
                                  !slotEnabled,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.trigSlotUp,
                              icon: const Icon(Icons.arrow_upward_rounded),
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
                              tooltip: l10n.trigSlotDown,
                              icon: const Icon(Icons.arrow_downward_rounded),
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
                              tooltip: l10n.trigSlotDuplicate,
                              icon: const Icon(Icons.copy_rounded),
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
                              tooltip: l10n.trigSlotRemove,
                              onPressed: () => setState(
                                () => _draft = _draft.withSlot(
                                  action,
                                  index,
                                  List.filled(action ? 32 : 20, 0),
                                ),
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// A short plain-language explanation of how the draft behaves.
  List<String> _explanation(AppLocalizations l10n) {
    final owners = _ownerNames(_draft, l10n.localeName);
    final conditions = _usedSlots(_draft, false);
    final actions = _usedSlots(_draft, true);
    bool hasCondition(int id) =>
        conditions.any((slot) => ChkTrigger.type(false, slot) == id);
    final preserve = actions.any((slot) => ChkTrigger.type(true, slot) == 3);
    return [
      if (!_draft.enabled) l10n.trigExplainDisabled,
      if (owners.isEmpty)
        l10n.trigExplainNoOwner
      else
        l10n.trigExplainOwners(owners.join(', ')),
      if (!_draft.briefing) ...[
        if (hasCondition(23))
          l10n.trigExplainNever
        else if (hasCondition(22) && conditions.length == 1)
          l10n.trigExplainAlways
        else if (conditions.isEmpty)
          l10n.trigExplainNoConditions
        else
          l10n.trigExplainConditions(conditions.length),
      ],
      l10n.trigExplainActions(actions.length),
      if (!_draft.briefing)
        preserve ? l10n.trigExplainPreserve : l10n.trigExplainOnce,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                _draft.briefing
                    ? l10n.trigEditBriefingTitle
                    : l10n.trigEditTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.trigWho,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.trigWhoHelp,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B939C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              FilterChip(
                                label: Text(
                                  _draft.briefing
                                      ? l10n.trigBriefingEnabledChip
                                      : l10n.trigEnabledChip,
                                ),
                                selected: _draft.enabled,
                                onSelected: (v) => setState(
                                  () => _draft = _draft.withEnabled(v),
                                ),
                              ),
                              for (final entry in TriggerOpcodes.owners.entries)
                                FilterChip(
                                  label: Text(
                                    TriggerLabels.value(
                                      l10n.localeName,
                                      entry.value,
                                    ),
                                  ),
                                  selected:
                                      _draft.bytes[_ownerOffset + entry.key] !=
                                      0,
                                  onSelected: (v) => setState(
                                    () =>
                                        _draft = _draft.withOwner(entry.key, v),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (!_draft.briefing) ...[
                            _slots(false),
                            const SizedBox(height: 16),
                          ],
                          _slots(true),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 300,
                    child: Material(
                      color: const Color(0xFF16191D),
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          Text(
                            l10n.trigExplainTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA7AFB8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            key: const Key('trigger-explanation'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121417),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF262A30),
                              ),
                            ),
                            child: Text(
                              _explanation(l10n).join(' '),
                              style: const TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.trigDraftNote,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B939C),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              l10n.trigRawRecord,
                              style: const TextStyle(fontSize: 13),
                            ),
                            children: [
                              SelectableText(
                                _draft.bytes
                                    .map(
                                      (b) =>
                                          b.toRadixString(16).padLeft(2, '0'),
                                    )
                                    .join(' '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.trigCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('trigger-apply'),
                    onPressed: () => Navigator.pop(context, _draft),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.trigApply),
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

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({
    required this.action,
    required this.briefing,
    required this.original,
    required this.document,
  });
  final bool action, briefing;
  final List<int>? original;
  final RawChkDocument document;
  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  Widget _argumentWidget(TriggerArgument arg) {
    final localeName = context.l10n.localeName;
    final units = arg.reference == 'unit' || arg.reference == 'unitGroup';
    final choices = <int, String>{
      for (final e in arg.choices.entries)
        e.key: TriggerLabels.value(localeName, e.value),
    };
    if (units) {
      for (var i = 0; i < 228; i++) {
        choices[i] = '${defaultUnitNames[i]} (#$i)';
      }
    }
    if (arg.reference == 'unitGroup') {
      choices.addAll({
        229: TriggerLabels.value(localeName, 'Any unit'),
        230: TriggerLabels.value(localeName, 'Men'),
        231: TriggerLabels.value(localeName, 'Buildings'),
        232: TriggerLabels.value(localeName, 'Factories'),
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
      ? (widget.briefing
            ? TriggerOpcodes.briefingActions.first
            : widget.action
            ? TriggerOpcodes.actions.firstWhere((op) => op.id == 3)
            : TriggerOpcodes.conditions.first)
      : TriggerOpcodes.find(
          widget.action,
          ChkTrigger.type(widget.action, widget.original!),
          briefing: widget.briefing,
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.action ? l10n.trigSlotAction : l10n.trigSlotCondition),
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
                      in widget.briefing
                          ? TriggerOpcodes.briefingActions
                          : widget.action
                          ? TriggerOpcodes.actions
                          : TriggerOpcodes.conditions)
                    DropdownMenuItem(
                      value: op,
                      child: Text(
                        TriggerLabels.opcodeName(
                          l10n.localeName,
                          op,
                          action: widget.action,
                          briefing: widget.briefing,
                        ),
                      ),
                    ),
                ],
                onChanged: (op) => setState(() {
                  _opcode = op!;
                  _reset();
                }),
              ),
              if (widget.original != null) Text(l10n.trigSlotReplaceNote),
              if (!widget.briefing &&
                  widget.action &&
                  {7, 9}.contains(_opcode.id))
                CheckboxListTile(
                  title: Text(l10n.trigAlwaysDisplay),
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
          child: Text(l10n.trigCancel),
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
                briefing: widget.briefing,
                original:
                    widget.original != null &&
                        ChkTrigger.type(widget.action, widget.original!) ==
                            _opcode.id
                    ? widget.original
                    : null,
              );
              if (!widget.briefing &&
                  widget.action &&
                  {7, 9}.contains(_opcode.id)) {
                slot[28] = _alwaysDisplay ? slot[28] | 4 : slot[28] & ~4;
              }
              Navigator.pop(context, slot);
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: Text(l10n.trigUseSlot),
        ),
      ],
    );
  }
}
