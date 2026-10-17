import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/documents/document_workspace_controller.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../localization/l10n.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';
import 'mixed_clipboard_pane.dart';

class MixedDocumentTransferDialog<T> extends StatefulWidget {
  const MixedDocumentTransferDialog({
    required this.workspace,
    required this.source,
    required this.nameOf,
    required this.createController,
    this.loader,
    this.textures = const TerrainTileTextureState.idle(),
    super.key,
  });
  final DocumentWorkspaceController<T> workspace;
  final WorkspaceDocument<T> source;
  final String Function(WorkspaceDocument<T>) nameOf;
  final BasicEditingController Function(WorkspaceDocument<T>) createController;
  final IsomFillController? loader;
  final TerrainTileTextureState textures;
  @override
  State<MixedDocumentTransferDialog<T>> createState() =>
      _MixedDocumentTransferDialogState<T>();
}

class _MixedDocumentTransferDialogState<T>
    extends State<MixedDocumentTransferDialog<T>> {
  late WorkspaceDocument<T> _target = _targets.first;
  late BasicEditingController _controller = widget.createController(_target);
  StreamSubscription<void>? _workspaceChanges;
  @override
  void initState() {
    super.initState();
    _workspaceChanges = widget.workspace.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  List<WorkspaceDocument<T>> get _targets => widget.workspace.documents
      .where((d) => d != widget.source && d.maps.state.session != null)
      .toList();
  @override
  void dispose() {
    unawaited(_workspaceChanges?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!widget.workspace.contains(widget.source) ||
        !widget.workspace.contains(_target)) {
      return AlertDialog(
        title: Text(l.transferRegionTitle),
        content: const Text('WORKSPACE_DOCUMENT_STALE'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.recoveryClose),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.transferRegionTitle),
      content: SizedBox(
        width: 1000,
        height: 700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${l.transferSource}: ${widget.nameOf(widget.source)}'),
            DropdownButtonFormField<String>(
              key: const Key('mixed-transfer-target'),
              initialValue: _target.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.transferTarget),
              items: [
                for (final d in _targets)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      widget.nameOf(d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() {
                final old = _controller;
                _target = _targets.singleWhere((d) => d.id == id);
                _controller = widget.createController(_target);
                unawaited(old.dispose());
              }),
            ),
            Expanded(
              child: MixedClipboardPane(
                key: ValueKey(_target.id),
                controller: _controller,
                loader: widget.loader,
                textures: widget.textures,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.recoveryClose),
        ),
      ],
    );
  }
}
