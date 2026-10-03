import '../localization/editor_message_localization.dart';
import '../localization/l10n.dart';
import 'settings_surface.dart';
import 'package:flutter/material.dart';

import '../../application/editing/object_editing_controller.dart';
import '../../domain/chk/raw_chk_document.dart';

class MapInformationDialog extends StatefulWidget {
  const MapInformationDialog({required this.controller, super.key});
  final ObjectEditingController controller;

  @override
  State<MapInformationDialog> createState() => _MapInformationDialogState();
}

class _MapInformationDialogState extends State<MapInformationDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  RawChkDocument? _snapshot;
  String? _error;
  String _savedTitle = '';
  String _savedDescription = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    try {
      final info = widget.controller.mapInformation;
      _snapshot =
          widget.controller.openMapController.state.session!.rawDocument;
      _title.text = _savedTitle = info.title;
      _description.text = _savedDescription = info.description;
      _error = null;
    } catch (error) {
      _snapshot = null;
      _error = error is FormatException
          ? 'The existing text is not valid UTF-8. Its original bytes are preserved; editing is unavailable.'
          : error.toString();
    }
  }

  void _apply() {
    setState(() {
      try {
        widget.controller.applyMapInformation(
          expectedDocument: _snapshot!,
          title: _title.text,
          description: _description.text,
        );
        _reload();
      } catch (error) {
        _error = error.toString();
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsSurface(
    controller: widget.controller,
    snapshot: _snapshot,
    hasDraft:
        _title.text != _savedTitle || _description.text != _savedDescription,
    onReload: () => setState(_reload),
    title: Text(context.l10n.editorMapInformation),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('map-information-title'),
              controller: _title,
              onChanged: (_) => setState(() {}),
              enabled: _snapshot != null,
              decoration: InputDecoration(
                labelText: context.l10n.editorMapTitle,
              ),
            ),
            TextField(
              key: const Key('map-information-description'),
              controller: _description,
              onChanged: (_) => setState(() {}),
              enabled: _snapshot != null,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: context.l10n.editorDescription,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context
                  .l10n
                  .editorApplyUpdatesThisMapOnlySharedNamesRemainUnchanged,
            ),
            if (_error != null)
              Text(
                context.localizeEditorText(_error!),
                key: const Key('map-information-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('settings-undo'),
        onPressed: widget.controller.canUndo
            ? () => setState(() {
                widget.controller.undo();
                _reload();
              })
            : null,
        child: Text(
          context.l10n.editorUndo(
            context.localizeEditorText(widget.controller.undoLabel ?? "—"),
          ),
        ),
      ),
      TextButton(
        key: const Key('settings-redo'),
        onPressed: widget.controller.canRedo
            ? () => setState(() {
                widget.controller.redo();
                _reload();
              })
            : null,
        child: Text(
          context.l10n.editorRedo(
            context.localizeEditorText(widget.controller.redoLabel ?? "—"),
          ),
        ),
      ),
      TextButton(
        key: const Key('settings-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.editorCancel),
      ),
      FilledButton(
        key: const Key('map-information-apply'),
        onPressed: _snapshot == null ? null : _apply,
        child: Text(context.l10n.editorApply),
      ),
    ],
  );
}
