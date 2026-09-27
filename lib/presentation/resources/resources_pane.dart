import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';
import '../../domain/chk/typed/chk_resource_editor.dart';
import '../../domain/chk/typed/chk_trigger_resources.dart';

class ResourcesPane extends StatefulWidget {
  const ResourcesPane({
    required this.controller,
    required this.active,
    super.key,
  });
  final ObjectEditingController controller;
  final bool active;
  @override
  State<ResourcesPane> createState() => _ResourcesPaneState();
}

class _ResourcesPaneState extends State<ResourcesPane> {
  String? _previewSource;
  String _query = '';
  String? _error;
  bool _busy = false;
  Future<void> _run(FutureOr<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _stop() {
    final gateway = widget.controller.resourceGateway;
    if (gateway != null) unawaited(gateway.stopPreview());
  }

  @override
  void didUpdateWidget(covariant ResourcesPane old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _edit(RawChkDocument doc, int? id) async {
    final result = await showDialog<RawChkDocument>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StringDialog(document: doc, id: id),
    );
    if (result != null && mounted) {
      widget.controller.applyTriggerResources(
        expectedDocument: doc,
        updatedDocument: result,
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: widget.controller.changes,
    builder: (context, _) {
      final session = widget.controller.openMapController.state.session;
      if (_previewSource != session?.sourcePath) {
        _previewSource = session?.sourcePath;
        _stop();
      }
      if (session == null) {
        return const Center(child: Text('Open a map to manage resources.'));
      }
      final doc = session.rawDocument, refs = ChkResourceEditor.references(doc);
      try {
        final table = ChkResourceEditor.table(doc, forEditing: false);
        final rows = table.entries
            .where(
              (e) =>
                  '${e.stringId} ${e.rawBytes == null ? '' : utf8.decode(e.rawBytes!, allowMalformed: true)}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()),
            )
            .toList();
        String identity(String path) =>
            path.replaceAll('/', '\\').toLowerCase();
        final candidates = <String>[
          for (final e in session.archiveMetadata.entries)
            if (e.path.toLowerCase().endsWith('.wav') && !e.nameIsSynthetic)
              e.path,
          for (final u in refs.uses.where((u) => u.sound))
            if (table.entryForId(u.id)?.rawBytes != null)
              utf8.decode(
                table.entryForId(u.id)!.rawBytes!,
                allowMalformed: true,
              ),
          ...session.resourceEdits.keys,
        ];
        final byPath = {for (final path in candidates) identity(path): path};
        for (final edit in session.resourceEdits.entries) {
          if (edit.value == null) byPath.remove(identity(edit.key));
        }
        final paths =
            byPath.values
                .where((p) => p.toLowerCase().contains(_query.toLowerCase()))
                .toList()
              ..sort();
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Resources', style: TextStyle(fontSize: 22)),
                  TextButton(
                    onPressed: _busy || !widget.controller.canUndo
                        ? null
                        : () => _run(widget.controller.undo),
                    child: const Text('Undo'),
                  ),
                  TextButton(
                    onPressed: _busy || !widget.controller.canRedo
                        ? null
                        : () => _run(widget.controller.redo),
                    child: const Text('Redo'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _edit(doc, null)),
                    child: const Text('Add string'),
                  ),
                  TextButton(
                    onPressed:
                        _busy || widget.controller.resourceGateway == null
                        ? null
                        : () => _run(widget.controller.importSound),
                    child: const Text('Import PCM WAV'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _stop,
                    child: const Text('Stop preview'),
                  ),
                ],
              ),
              Text(
                '${table.declaredStringCount} strings • ${table.rawSection.payload.length} bytes • offset limit ${table.kind.maximumOffset} • Save As writes pending resource changes.',
              ),
              if (refs.uncertainties.isNotEmpty)
                ExpansionTile(
                  title: const Text(
                    'Reference coverage incomplete — deletion restricted',
                  ),
                  children: [
                    for (final reason in refs.uncertainties) Text(reason),
                  ],
                ),
              if (!session.archiveMetadata.listingComplete)
                const Text(
                  'Archive listing incomplete. Unlisted sounds may exist; imports/deletions are restricted.',
                ),
              TextField(
                key: const Key('resource-search'),
                decoration: const InputDecoration(
                  labelText: 'Search text, string ID or sound path',
                ),
                onChanged: (s) => setState(() => _query = s),
              ),
              if (_error != null) Text(_error!),
              if (_busy) const Text('Working…'),
              for (final diagnostic in table.diagnostics)
                Text(diagnostic.message),
              const TabBar(
                tabs: [
                  Tab(text: 'Strings'),
                  Tab(text: 'Sounds'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        String text;
                        bool decoded = true;
                        try {
                          if (!row.isStructurallyValid) {
                            throw const FormatException();
                          }
                          text = utf8.decode(
                            row.rawBytes ?? [],
                            allowMalformed: false,
                          );
                        } catch (_) {
                          decoded = false;
                          text = 'Invalid UTF-8 — raw bytes preserved';
                        }
                        final uses = refs.uses
                            .where((u) => u.id == row.stringId)
                            .toList();
                        return ListTile(
                          key: ValueKey(('resource-string', row.stringId)),
                          title: Text(
                            '#${row.stringId}  $text',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${row.rawBytes?.length ?? 0} bytes • ${uses.length} known use(s)${decoded ? '' : ' • explicit replacement required'}',
                          ),
                          onTap: _busy
                              ? null
                              : () => _run(() => _edit(doc, row.stringId)),
                          trailing: IconButton(
                            tooltip: 'Clear unreferenced string',
                            onPressed:
                                _busy ||
                                    uses.isNotEmpty ||
                                    refs.uncertainties.isNotEmpty
                                ? null
                                : () => _run(() {
                                    widget.controller.applyTriggerResources(
                                      expectedDocument: doc,
                                      updatedDocument: ChkResourceEditor.edit(
                                        doc,
                                        row.stringId,
                                        '',
                                        clear: true,
                                      ),
                                    );
                                  }),
                            icon: const Icon(Icons.clear),
                          ),
                        );
                      },
                    ),
                    ListView.builder(
                      itemCount: paths.length,
                      itemBuilder: (context, i) {
                        final path = paths[i];
                        final entries = session.archiveMetadata.entries
                            .where(
                              (e) => e.path.toLowerCase() == path.toLowerCase(),
                            )
                            .toList();
                        return ListTile(
                          title: Text(path),
                          subtitle: Text(
                            session.resourceEdits[path] != null
                                ? '${session.resourceEdits[path]!.length} bytes • pending import'
                                : entries.isEmpty
                                ? 'Referenced path; not listed in this map'
                                : '${entries.first.uncompressedSizeBytes} bytes • locale ${entries.first.locale}',
                          ),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Preview sound',
                                icon: const Icon(Icons.play_arrow),
                                onPressed:
                                    _busy ||
                                        widget.controller.resourceGateway ==
                                            null
                                    ? null
                                    : () => _run(() async {
                                        final bytes = await widget.controller
                                            .soundBytes(path);
                                        if (!mounted || !widget.active) return;
                                        await widget.controller.resourceGateway!
                                            .preview(bytes);
                                        if (!mounted || !widget.active) _stop();
                                      }),
                              ),
                              IconButton(
                                tooltip: 'Export sound',
                                icon: const Icon(Icons.save_alt),
                                onPressed:
                                    _busy ||
                                        widget.controller.resourceGateway ==
                                            null
                                    ? null
                                    : () => _run(() async {
                                        await widget.controller.resourceGateway!
                                            .exportSound(
                                              path,
                                              await widget.controller
                                                  .soundBytes(path),
                                            );
                                      }),
                              ),
                              IconButton(
                                tooltip: 'Delete sound',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        final accepted = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete sound?'),
                                            content: Text(
                                              '$path\nRemoval applies on Save As. Undo restores this edit.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (accepted == true) {
                                          if (!identical(
                                            session,
                                            widget
                                                .controller
                                                .openMapController
                                                .state
                                                .session,
                                          )) {
                                            throw StateError('Map changed.');
                                          }
                                          widget.controller.deleteSound(path);
                                        }
                                      }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      } catch (e) {
        return Center(child: SelectableText('Resources are read-only: $e'));
      }
    },
  );
}

class _StringDialog extends StatefulWidget {
  const _StringDialog({required this.document, required this.id});
  final RawChkDocument document;
  final int? id;
  @override
  State<_StringDialog> createState() => _StringDialogState();
}

class _StringDialogState extends State<_StringDialog> {
  late final TextEditingController _text;
  late final AppLifecycleListener _lifecycle;
  int _target = -1;
  String? _error;
  @override
  void initState() {
    super.initState();
    var text = '';
    if (widget.id != null) {
      try {
        text = utf8.decode(
          ChkResourceEditor.table(
            widget.document,
          ).entryForId(widget.id!)!.rawBytes!,
          allowMalformed: false,
        );
      } catch (_) {
        _error =
            'Invalid UTF-8. Enter explicit replacement text; original bytes remain until Apply.';
      }
    }
    _text = TextEditingController(text: text);
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async => AppExitResponse.cancel,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refs = ChkResourceEditor.references(widget.document);
    final uses = refs.uses.where((u) => u.id == widget.id).toList();
    return AlertDialog(
      title: Text(widget.id == null ? 'Add string' : 'String #${widget.id}'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.id != null)
                DropdownButton<int>(
                  isExpanded: true,
                  value: _target,
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Edit shared ID — affects all references'),
                    ),
                    for (var i = 0; i < uses.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          'Separate: ${uses[i].label}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _target = v!),
                ),
              if (refs.uncertainties.isNotEmpty)
                const Text(
                  'Additional unknown uses may exist. No automatic cleanup is performed.',
                ),
              TextField(
                key: const Key('resource-string-text'),
                controller: _text,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'UTF-8 text'),
              ),
              if (uses.isNotEmpty)
                ExpansionTile(
                  title: Text('${uses.length} known references'),
                  children: [for (final use in uses) Text(use.label)],
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
          key: const Key('resource-string-apply'),
          onPressed: () {
            try {
              final doc = widget.id == null
                  ? ChkTriggerResources.addText(widget.document, _text.text).$1
                  : ChkResourceEditor.edit(
                      widget.document,
                      widget.id!,
                      _text.text,
                      onlyUse: _target < 0 ? null : uses[_target],
                    );
              Navigator.pop(context, doc);
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
