import 'package:flutter/material.dart';
import '../../domain/chk/typed/chk_trigger_search.dart';
import '../localization/l10n.dart';
import 'trigger_reference_labels.dart';

class TriggerReplaceDialog extends StatefulWidget {
  const TriggerReplaceDialog({
    required this.search,
    required this.selected,
    super.key,
  });
  final ChkTriggerSearch search;
  final Set<int> selected;
  @override
  State<TriggerReplaceDialog> createState() => _TriggerReplaceDialogState();
}

class _TriggerReplaceDialogState extends State<TriggerReplaceDialog> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _kind = 'location';
  TriggerReplacementPreview? _preview;
  String? _error;
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _invalidate() => setState(() {
    _preview = null;
    _error = null;
  });
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.triggerReplaceReferences),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.trigSelectedCount(widget.selected.length)),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const Key('trigger-replace-kind'),
                initialValue: _kind,
                decoration: InputDecoration(labelText: l10n.triggerReference),
                items: [
                  for (final kind in ChkTriggerSearch.replaceable)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(triggerReferenceLabel(context, kind)),
                    ),
                ],
                onChanged: (v) {
                  _kind = v!;
                  _invalidate();
                },
              ),
              TextField(
                key: const Key('trigger-replace-from'),
                controller: _from,
                decoration: InputDecoration(labelText: l10n.triggerReplaceFrom),
                onChanged: (_) => _invalidate(),
              ),
              TextField(
                key: const Key('trigger-replace-to'),
                controller: _to,
                decoration: InputDecoration(labelText: l10n.triggerReplaceTo),
                onChanged: (_) => _invalidate(),
              ),
              if (_preview case final preview?) ...[
                Text(l10n.triggerPreviewSummary),
                Text(
                  '${preview.replacements} / ${preview.changedRecords.length} / ${preview.skipped}',
                  key: const Key('trigger-replace-summary'),
                ),
                Text(preview.changedRecords.map((r) => '#${r + 1}').join(', ')),
              ],
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
          child: Text(l10n.trigCancel),
        ),
        OutlinedButton(
          key: const Key('trigger-replace-preview'),
          onPressed: () {
            try {
              final preview = widget.search.replace(
                selected: widget.selected,
                reference: _kind,
                from: int.parse(_from.text.trim()),
                to: int.parse(_to.text.trim()),
              );
              setState(() {
                _preview = preview;
                _error = null;
              });
            } catch (e) {
              setState(() {
                _preview = null;
                _error = e.toString();
              });
            }
          },
          child: Text(l10n.triggerPreviewChanges),
        ),
        FilledButton(
          key: const Key('trigger-replace-apply'),
          onPressed: _preview == null || _preview!.replacements == 0
              ? null
              : () => Navigator.pop(context, _preview),
          child: Text(l10n.editorApply),
        ),
      ],
    );
  }
}
