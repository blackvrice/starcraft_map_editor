import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import '../../application/editing/object_editing_controller.dart';
import '../../application/triggers/trigger_script_controller.dart';
import '../../domain/triggers/trigger_script.dart';
import '../eud_editor/ep_script_text_controller.dart';
import '../localization/l10n.dart';

class TriggerScriptDialog extends StatefulWidget {
  const TriggerScriptDialog({required this.editing, super.key});
  final ObjectEditingController editing;
  @override
  State<TriggerScriptDialog> createState() => _TriggerScriptDialogState();
}

class _TriggerScriptDialogState extends State<TriggerScriptDialog> {
  late final _controller = TriggerScriptController(
    editing: widget.editing,
    gateway: widget.editing.triggerScriptGateway!,
    files: widget.editing.triggerScriptFiles,
  );
  final _source = EpScriptTextController(), _output = EpScriptTextController();
  final _sourceFocus = FocusNode();
  Object? _previewIdentity;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<void>? _subscription;
  TriggerScriptLanguage _requested = TriggerScriptLanguage.python;
  bool _allowDeletion = false, _closing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async => AppExitResponse.cancel,
    );
    _subscription = _controller.changes.listen((_) {
      if (!mounted) return;
      if (!identical(_previewIdentity, _controller.preview)) {
        _previewIdentity = _controller.preview;
        _allowDeletion = false;
      }
      _source.grammar = _controller.language.extension;
      _source.symbols = _symbols(_controller.language);
      if (_source.text != _controller.text) _source.text = _controller.text;
      _output.grammar = (_controller.target ?? _controller.language).extension;
      _output.text = _controller.preview?.generated ?? '';
      setState(() {});
    });
    unawaited(_run(() => _controller.open()));
  }

  List<String> _symbols(TriggerScriptLanguage language) => [
    'MapScript',
    'MapTrigger',
    'Source',
    'New',
    'Owners',
    'Enabled',
    'Conditions',
    'Actions',
    'RawCondition',
    'RawAction',
    language.boolean(true),
    language.boolean(false),
    ...TriggerScriptSnapshot.conditionNames.keys,
    ...TriggerScriptSnapshot.actionNames.keys,
  ];
  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_subscription?.cancel());
    unawaited(_controller.dispose());
    _source.dispose();
    _output.dispose();
    _sourceFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<bool> _keepDraft() async {
    if (!_controller.dirty) return true;
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.scriptDraftTitle),
            content: Text(l.scriptKeepDraft),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.trigCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.scriptArchive),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _close() async {
    final c = _controller, l = context.l10n;
    if (c.hasPendingSources) {
      final choice = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.scriptDraftTitle),
          content: Text(l.scriptCloseDraft),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: Text(l.trigCancel),
            ),
            TextButton(
              key: const Key('script-discard-close'),
              onPressed: () => Navigator.pop(context, 1),
              child: Text(l.scriptDiscardClose),
            ),
            FilledButton(
              onPressed: c.files == null
                  ? null
                  : () => Navigator.pop(context, 2),
              child: Text(l.scriptSaveClose),
            ),
          ],
        ),
      );
      if (choice == null || choice == 0 || !mounted) return;
      if (choice == 2) {
        try {
          if (!await c.exportPending()) return;
        } on Object catch (e) {
          if (mounted) setState(() => _error = '$e');
          return;
        }
      }
    }
    if (!mounted) return;
    c.discardRecovery();
    setState(() => _closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _diagnostic() {
    final diagnostic = _controller.preview?.diagnostic;
    if (diagnostic == null) return;
    _source.selection = TextSelection.collapsed(
      offset: diagnostic.offset.clamp(0, _source.text.length),
    );
    _sourceFocus.requestFocus();
  }

  Future<void> _history() async {
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.scriptHistory),
        content: SizedBox(
          width: 800,
          height: 450,
          child: ListView(
            children: [
              for (final (index, draft) in _controller.history.indexed)
                ExpansionTile(
                  title: Text('${index + 1}. ${draft.language.name}'),
                  children: [
                    SelectableText(
                      draft.text,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      tooltip: l.scriptSaveAs,
                      onPressed: _controller.files == null
                          ? null
                          : () => _run(
                              () => _controller.exportSource(draft: draft),
                            ),
                      icon: const Icon(Icons.save_as),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.trigClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller, l = context.l10n;
    final diagnostic = c.preview?.diagnostic, program = c.preview?.program;
    final position = diagnostic?.position(c.text);
    final size = MediaQuery.sizeOf(context);
    Widget editor(EpScriptTextController controller, bool readOnly) =>
        TextField(
          key: Key(readOnly ? 'script-preview' : 'script-source'),
          controller: controller,
          focusNode: readOnly ? null : _sourceFocus,
          readOnly: readOnly || c.busy,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(
            fontFamily: 'Consolas',
            fontSize: 13,
            height: 1.45,
          ),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: readOnly
                ? l.scriptPreview
                : '${l.scriptSource} (${c.language.name})',
            alignLabelWithHint: true,
          ),
          onChanged: readOnly
              ? null
              : (v) {
                  _allowDeletion = false;
                  c.updateText(v);
                },
          onTap: () => setState(() {}),
        );
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Dialog(
        child: SizedBox(
          width: 1120,
          height: size.height * 0.88,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.scriptTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('script-close'),
                      tooltip: l.trigClose,
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('script-import'),
                      tooltip: l.scriptImport,
                      onPressed: c.files == null || c.busy
                          ? null
                          : () => _run(() async {
                              if (await _keepDraft()) {
                                return c.importSource(keepDraft: true);
                              }
                              return false;
                            }),
                      icon: const Icon(Icons.folder_open),
                    ),
                    IconButton(
                      key: const Key('script-save-as'),
                      tooltip: l.scriptSaveAs,
                      onPressed: c.files == null || c.busy
                          ? null
                          : () => _run(() => c.exportSource()),
                      icon: const Icon(Icons.save_as),
                    ),
                    IconButton(
                      key: const Key('script-reload'),
                      tooltip: l.scriptReload,
                      onPressed: c.busy
                          ? null
                          : () => _run(() async {
                              if (await _keepDraft()) {
                                return c.reload(keepDraft: true);
                              }
                              return false;
                            }),
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: l.scriptHistory,
                      onPressed: c.history.isEmpty ? null : _history,
                      icon: const Icon(Icons.history),
                    ),
                    SizedBox(
                      width: 145,
                      child: DropdownButton<TriggerScriptLanguage>(
                        key: const Key('script-language'),
                        value: _requested,
                        isExpanded: true,
                        items: [
                          for (final lang in TriggerScriptLanguage.values)
                            DropdownMenuItem(
                              value: lang,
                              child: Text(lang.name),
                            ),
                        ],
                        onChanged: c.busy
                            ? null
                            : (v) {
                                if (v != null) setState(() => _requested = v);
                              },
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('script-convert'),
                      onPressed: c.busy || c.stale || _requested == c.language
                          ? null
                          : () => _run(() => c.analyze(convertTo: _requested)),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(l.scriptConvert),
                    ),
                    OutlinedButton(
                      key: const Key('script-accept-conversion'),
                      onPressed:
                          c.busy ||
                              c.target == null ||
                              c.target == c.language ||
                              c.preview?.isSuccess != true ||
                              c.stale
                          ? null
                          : () => _run(() async => c.acceptConversion()),
                      child: Text(l.scriptAcceptConversion),
                    ),
                    OutlinedButton.icon(
                      key: const Key('script-validate'),
                      onPressed: c.busy || c.stale
                          ? null
                          : () => _run(c.analyze),
                      icon: const Icon(Icons.fact_check),
                      label: Text(l.trigValidate),
                    ),
                    FilledButton.icon(
                      key: const Key('script-apply'),
                      onPressed:
                          !c.canApply ||
                              (program!.opaqueDeletions > 0 && !_allowDeletion)
                          ? null
                          : () => _run(
                              () => c.apply(allowDeletion: _allowDeletion),
                            ),
                      icon: const Icon(Icons.check),
                      label: Text(l.trigApply),
                    ),
                  ],
                ),
                if (c.busy) const LinearProgressIndicator(),
                if (c.stale) Text(l.scriptStale),
                if (program != null)
                  Text(
                    '${l.scriptRecords}: ${program.records.length}; '
                    '${l.scriptOpaqueDeletions}: ${program.opaqueDeletions}',
                  ),
                if ((program?.opaqueDeletions ?? 0) > 0)
                  CheckboxListTile(
                    key: const Key('script-deletion-consent'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.scriptAllowDeletion),
                    value: _allowDeletion,
                    onChanged: (v) =>
                        setState(() => _allowDeletion = v ?? false),
                  ),
                if (_error != null || c.error != null)
                  TextButton(
                    key: const Key('script-diagnostic'),
                    onPressed: _diagnostic,
                    child: Text(
                      '${position == null ? "" : "${position.line}:${position.column} "}'
                      '${_error ?? c.error}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 800
                        ? Row(
                            children: [
                              Expanded(child: editor(_source, false)),
                              const SizedBox(width: 12),
                              Expanded(child: editor(_output, true)),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: editor(_source, false)),
                              const SizedBox(height: 8),
                              Expanded(child: editor(_output, true)),
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final symbol in _source.completions)
                        TextButton(
                          onPressed: () {
                            _source.complete(symbol);
                            c.updateText(_source.text);
                          },
                          child: Text(symbol),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
