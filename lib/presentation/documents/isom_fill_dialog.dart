import 'package:flutter/material.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/terrain/solid_isom_catalog_builder.dart';
import '../../domain/terrain/isom_terrain_fill.dart';
import '../localization/l10n.dart';

class IsomFillDialog extends StatefulWidget {
  const IsomFillDialog({required this.controller, super.key});
  final IsomFillController controller;
  @override
  State<IsomFillDialog> createState() => _IsomFillDialogState();
}

class _IsomFillDialogState extends State<IsomFillDialog> {
  SolidIsomCatalog? _catalog;
  int? _type;
  IsomFillPreview? _preview;
  Object? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await widget.controller.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
        _type = catalog.shapes.keys.first;
        _loading = false;
        _refresh();
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  void _refresh() {
    _preview = null;
    _error = null;
    try {
      _preview = widget.controller.preview(terrainType: _type!);
    } on Object catch (e) {
      _error = e;
    }
  }

  void _apply() {
    try {
      final changed = widget.controller.apply(_preview!);
      Navigator.of(context).pop(changed);
    } on Object catch (e) {
      setState(() {
        _preview = null;
        _error = e;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.invalidate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.isomFillTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.isomFillScope),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_catalog case final SolidIsomCatalog catalog)
                DropdownButtonFormField<int>(
                  key: const Key('isom-terrain-type'),
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l.isomTerrainType),
                  items: [
                    for (final type in catalog.shapes.keys)
                      DropdownMenuItem(
                        value: type,
                        child: Text(l.isomTerrainId(type)),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v;
                    _refresh();
                  }),
                ),
              if (_preview case final IsomFillPreview p) ...[
                const SizedBox(height: 16),
                Text(l.isomFillPreview(p.changedTileCount)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(l.isomFillUnavailable),
                const SizedBox(height: 8),
                SelectableText(
                  '$_error',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.isomFillCancel),
        ),
        FilledButton(
          key: const Key('isom-fill-apply'),
          onPressed: _preview?.hasChanges == true ? _apply : null,
          child: Text(l.isomFillApply),
        ),
      ],
    );
  }
}
