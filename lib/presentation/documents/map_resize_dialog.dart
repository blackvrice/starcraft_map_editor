import 'package:flutter/material.dart';
import '../../application/documents/map_resize_controller.dart';
import '../../domain/chk/map_resize.dart';

class MapResizeDialog extends StatefulWidget {
  const MapResizeDialog({required this.controller, super.key});
  final MapResizeController controller;
  @override
  State<MapResizeDialog> createState() => _MapResizeDialogState();
}

class _MapResizeDialogState extends State<MapResizeDialog> {
  int _width = 128, _height = 128;
  MapResizeAnchor _anchor = MapResizeAnchor.topLeft;
  final _fillX = TextEditingController(text: '0');
  final _fillY = TextEditingController(text: '0');
  MapResizePreview? _preview;
  String? _error;
  bool _accept = false;

  @override
  void initState() {
    super.initState();
    final terrain = widget.controller.source!.terrainViews.tileMaps;
    if (terrain.length == 1) {
      final w = terrain.single.width, h = terrain.single.height;
      if (w != null && w >= 32 && w <= 256 && w % 32 == 0) _width = w;
      if (h != null && h >= 32 && h <= 256 && h % 32 == 0) _height = h;
    }
    _refresh();
  }

  void _refresh() {
    _accept = false;
    _preview = null;
    _error = null;
    try {
      _preview = widget.controller.preview(
        MapResizeOptions(
          width: _width,
          height: _height,
          anchor: _anchor,
          fillX: int.parse(_fillX.text),
          fillY: int.parse(_fillY.text),
        ),
      );
    } on Object catch (e) {
      _error = '$e';
    }
  }

  void _apply() {
    try {
      widget.controller.apply(_preview!, acceptCropping: _accept);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return AlertDialog(
      title: const Text('Resize Map'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose the new size and where to keep the existing map. Changes apply together and can be undone.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _size('Width', _width, (v) => _width = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _size('Height', _height, (v) => _height = v)),
                ],
              ),
              DropdownButtonFormField<MapResizeAnchor>(
                initialValue: _anchor,
                decoration: const InputDecoration(labelText: 'Anchor'),
                items: [
                  for (final a in MapResizeAnchor.values)
                    DropdownMenuItem(value: a, child: Text(a.label)),
                ],
                onChanged: (a) => setState(() {
                  _anchor = a!;
                  _refresh();
                }),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fill added terrain using an existing map tile (zero-based coordinates). If fog data exists, added cells are hidden for all players.',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fillX,
                      key: const Key('resize-fill-x'),
                      decoration: const InputDecoration(
                        labelText: 'Sample tile X',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(_refresh),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fillY,
                      key: const Key('resize-fill-y'),
                      decoration: const InputDecoration(
                        labelText: 'Sample tile Y',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(_refresh),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (p != null) ...[
                Text(
                  '${p.oldWidth} × ${p.oldHeight} → $_width × $_height; shift ${p.dx}, ${p.dy} tiles',
                ),
                Text(
                  'Terrain / fog: ${p.croppedTiles} cells cropped, ${p.addedTiles} added; fill tile #${p.fillTile}',
                ),
                Text(
                  'Units moved: ${p.movedUnits}; outside: ${p.outsideUnits}',
                ),
                Text(
                  'Sprites moved: ${p.movedSprites}; outside: ${p.outsideSprites}',
                ),
                Text(
                  'Locations clipped: ${p.clippedLocations}. IDs and names are retained; the standard Anywhere region follows the new size.',
                ),
                for (final b in p.blockers)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      b,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (p.needsCropConfirmation)
                  CheckboxListTile(
                    key: const Key('resize-confirm-crop'),
                    contentPadding: EdgeInsets.zero,
                    value: _accept,
                    onChanged: (v) => setState(() => _accept = v!),
                    title: const Text(
                      'Apply the terrain/fog cropping and clip location edges (fully outside locations become zero-area).',
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Trigger and EUD code coordinates are preserved. Review custom coordinates after resizing. ISOM and maps with doodads are not supported yet.',
              ),
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
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('resize-apply'),
          onPressed:
              _error == null &&
                  p != null &&
                  p.canApply &&
                  (!p.needsCropConfirmation || _accept)
              ? _apply
              : null,
          child: const Text('Apply resize'),
        ),
      ],
    );
  }

  Widget _size(String label, int value, void Function(int) change) =>
      DropdownButtonFormField<int>(
        key: Key('resize-${label.toLowerCase()}'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var i = 32; i <= 256; i += 32)
            DropdownMenuItem(value: i, child: Text('$i')),
        ],
        onChanged: (v) => setState(() {
          change(v!);
          _refresh();
        }),
      );

  @override
  void dispose() {
    _fillX.dispose();
    _fillY.dispose();
    super.dispose();
  }
}
