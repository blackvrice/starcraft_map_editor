import 'package:flutter/material.dart';
import '../../application/documents/document_workspace_controller.dart';
import '../../application/documents/opened_map_session.dart';
import '../../application/editing/document_transfer_controller.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../domain/chk/typed/chk_trigger_editor.dart';
import '../localization/l10n.dart';

class DocumentTransferDialog<T> extends StatefulWidget {
  const DocumentTransferDialog({
    required this.controller,
    required this.nameOf,
    required this.initialSource,
    super.key,
  });
  final DocumentTransferController<T> controller;
  final String Function(WorkspaceDocument<T>) nameOf;
  final WorkspaceDocument<T> initialSource;
  @override
  State<DocumentTransferDialog<T>> createState() =>
      _DocumentTransferDialogState<T>();
}

class _DocumentTransferDialogState<T> extends State<DocumentTransferDialog<T>> {
  late WorkspaceDocument<T> _source = widget.initialSource;
  late WorkspaceDocument<T> _target = _documents.firstWhere(
    (d) => d != _source,
  );
  OpenedMapSession? _sourceSession;
  final _selected = <String, Set<int>>{},
      _triggers = <int>{},
      _briefings = <int>{};
  final _x = TextEditingController(text: '0'),
      _y = TextEditingController(text: '0');
  final _owners = {for (var i = 0; i < 12; i++) i: i};
  bool _busy = false;
  String? _error;
  List<WorkspaceDocument<T>> get _documents => widget
      .controller
      .workspace
      .documents
      .where((d) => d.maps.state.session != null)
      .toList();
  @override
  void initState() {
    super.initState();
    _captureSelection();
  }

  void _captureSelection() {
    _sourceSession = _source.maps.state.session;
    _selected.clear();
    _triggers.clear();
    _briefings.clear();
    for (final s in widget.controller.access(_source).layers.state.selections) {
      final kind = switch (s.object.layer) {
        MapLayerType.units => 'UNIT',
        MapLayerType.sprites => 'THG2',
        MapLayerType.locations => 'MRGN',
        _ => null,
      };
      if (kind != null &&
          _sourceSession!.rawDocument.sections[s.object.sectionIndex].name ==
              kind) {
        (_selected[kind] ??= {}).add(s.object.recordIndex);
      }
    }
    _invalidate();
  }

  void _invalidate() {
    widget.controller.invalidate();
    _error = null;
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.prepare(
        source: _source,
        target: _target,
        expectedSource: _sourceSession,
        selected: {
          for (final e in _selected.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
        triggers: _triggers,
        briefings: _briefings,
        offsetX: int.parse(_x.text),
        offsetY: int.parse(_y.text),
        owners: _owners,
      );
    } on Object catch (e) {
      if (mounted) _error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _kind(String name) => switch (name) {
    'UNIT' => context.l10n.layerUnits,
    'THG2' => context.l10n.layerSprites,
    _ => context.l10n.layerLocations,
  };
  Widget _records(bool briefing) {
    final selected = briefing ? _briefings : _triggers;
    final name = briefing
        ? context.l10n.railBriefing
        : context.l10n.railTriggers;
    List<ChkTrigger> records;
    try {
      records = ChkTriggers.read(
        _sourceSession!.rawDocument,
        briefing: briefing,
      ).records;
    } on Object catch (e) {
      return Text('$name: $e');
    }
    return ExpansionTile(
      title: Text('$name (${records.length})'),
      children: [
        CheckboxListTile(
          value: records.isNotEmpty && selected.length == records.length,
          title: Text(context.l10n.transferSelectAll),
          onChanged: _busy || records.length > 4096
              ? null
              : (v) => setState(() {
                  _invalidate();
                  selected.clear();
                  if (v == true) {
                    selected.addAll(Iterable.generate(records.length));
                  }
                }),
        ),
        SizedBox(
          height: records.isEmpty ? 0 : 180,
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (_, i) => CheckboxListTile(
              key: ValueKey('transfer-${briefing ? 'briefing' : 'trigger'}-$i'),
              title: Text('$name ${i + 1}'),
              value: selected.contains(i),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _invalidate();
                      v == true ? selected.add(i) : selected.remove(i);
                    }),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, preview = widget.controller.preview;
    Widget documentPicker(bool source) => DropdownButtonFormField<String>(
      key: ValueKey('transfer-${source ? 'source' : 'target'}'),
      initialValue: (source ? _source : _target).id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: source ? l.transferSource : l.transferTarget,
      ),
      items: [
        for (final d in _documents)
          DropdownMenuItem(
            value: d.id,
            child: Text(
              widget.nameOf(d),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _busy
          ? null
          : (id) => setState(() {
              final d = _documents.singleWhere((d) => d.id == id);
              if (source) {
                _source = d;
                _captureSelection();
              } else {
                _target = d;
                _invalidate();
              }
            }),
    );
    return AlertDialog(
      title: Text(l.transferTitle),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              documentPicker(true),
              const SizedBox(height: 12),
              documentPicker(false),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final (controller, label, key) in [
                    (_x, l.transferOffsetX, 'transfer-x'),
                    (_y, l.transferOffsetY, 'transfer-y'),
                  ])
                    SizedBox(
                      width: 150,
                      child: TextField(
                        key: ValueKey(key),
                        controller: controller,
                        enabled: !_busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        decoration: InputDecoration(labelText: label),
                        onChanged: (_) => setState(_invalidate),
                      ),
                    ),
                ],
              ),
              for (final e in _selected.entries)
                for (final index in e.value.toList()..sort())
                  ListTile(
                    dense: true,
                    title: Text('${_kind(e.key)} ${index + 1}'),
                    trailing: IconButton(
                      tooltip: l.transferExclude,
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _invalidate();
                              e.value.remove(index);
                            }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
              _records(false),
              _records(true),
              ExpansionTile(
                title: Text(l.transferOwners),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (var p = 0; p < 12; p++)
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<int>(
                            initialValue: _owners[p],
                            decoration: InputDecoration(
                              labelText: l.catalogOwnerPlayer(p + 1),
                            ),
                            items: [
                              for (var n = 0; n < 12; n++)
                                DropdownMenuItem(
                                  value: n,
                                  child: Text(l.catalogOwnerPlayer(n + 1)),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (n) => setState(() {
                                    _invalidate();
                                    _owners[p] = n!;
                                  }),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (preview != null) ...[
                const Divider(),
                Text(
                  l.transferRemapping,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final (name, ids) in [
                  (l.layerUnits, preview.plan.units),
                  (l.layerLocations, preview.plan.locations),
                  (l.transferStrings, preview.plan.strings),
                  (l.transferSwitches, preview.plan.switches),
                  (l.transferProperties, preview.plan.properties),
                ])
                  if (ids.isNotEmpty)
                    SelectableText(
                      '$name: ${ids.entries.map((e) => '${e.key} -> ${e.value}').join(', ')}',
                    ),
                for (final path in preview.plan.clipboard.sounds.values.toSet())
                  SelectableText(path),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.recoveryCancel),
        ),
        TextButton(
          key: const Key('transfer-preview'),
          onPressed: _busy ? null : _preview,
          child: Text(l.triggerPreviewChanges),
        ),
        FilledButton(
          key: const Key('transfer-apply'),
          onPressed: _busy || preview == null
              ? null
              : () {
                  try {
                    widget.controller.apply(preview);
                    Navigator.pop(context, preview.target.id);
                  } on Object catch (e) {
                    setState(() {
                      widget.controller.invalidate();
                      _error = '$e';
                    });
                  }
                },
          child: Text(l.autosaveApply),
        ),
      ],
    );
  }
}
