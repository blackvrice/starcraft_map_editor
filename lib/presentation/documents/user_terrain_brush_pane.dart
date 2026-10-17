import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../../application/terrain/terrain_brush_library.dart';
import '../../application/terrain/user_terrain_brush_controller.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/chk/chk_mixed_clipboard.dart';
import '../../domain/terrain/user_terrain_brush.dart';
import '../localization/l10n.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';

class UserTerrainBrushPane extends StatefulWidget {
  const UserTerrainBrushPane({
    required this.editing,
    this.library,
    this.loader,
    this.textures = const TerrainTileTextureState.idle(),
    super.key,
  });
  final BasicEditingController editing;
  final TerrainBrushLibrary? library;
  final IsomFillController? loader;
  final TerrainTileTextureState textures;
  @override
  State<UserTerrainBrushPane> createState() => _UserTerrainBrushPaneState();
}

class _UserTerrainBrushPaneState extends State<UserTerrainBrushPane> {
  late final _controller = UserTerrainBrushController(
    widget.editing,
    loader: widget.loader,
  );
  final _fields = {
    for (final e in {
      'name': '',
      'left': '0',
      'top': '0',
      'right': '7',
      'bottom': '3',
      'x': '8',
      'y': '8',
    }.entries)
      e.key: TextEditingController(text: e.value),
  };
  StreamSubscription<Object?>? _maps, _layers;
  List<UserTerrainBrush> _brushes = [];
  UserTerrainBrush? _selected;
  TerrainBrushProfile _profile = TerrainBrushProfile.raw;
  bool _busy = false, _mirrorX = false, _mirrorY = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.editing.maps.state.session?.rawDocument.sections.any(
          (s) => s.name == 'ISOM',
        ) ==
        true) {
      _profile = TerrainBrushProfile.isom;
    }
    _maps = widget.editing.maps.changes.listen((_) {
      if (mounted) setState(_controller.invalidate);
    });
    _layers = widget.editing.layers.changes.listen((_) {
      if (mounted) setState(_controller.invalidate);
    });
    if (widget.library != null) unawaited(_reload());
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_maps?.cancel());
    unawaited(_layers?.cancel());
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  int _number(String name) => int.parse(_fields[name]!.text.trim());
  void _run(void Function() action) {
    try {
      action();
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _async(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _controller.invalidate();
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _adopt(List<UserTerrainBrush> brushes) {
    if (!mounted) return;
    setState(() {
      final old = _selected?.name;
      _brushes = brushes;
      _selected = brushes.where((b) => b.name == old).firstOrNull;
    });
  }

  Future<void> _reload() => _async(() async {
    _adopt(await widget.library!.load());
  });
  Future<void> _save() => _async(() async {
    final brush = _controller.capture(
      _fields['name']!.text,
      ClipboardRegion(
        _number('left'),
        _number('top'),
        _number('right'),
        _number('bottom'),
      ),
      _profile,
    );
    final brushes = await widget.library!.add(brush);
    if (!mounted) return;
    _selected = brush;
    _mirrorX = false;
    _mirrorY = false;
    _adopt(brushes);
  });
  Future<void> _delete() async {
    final selected = _selected;
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.brushDeleteTitle),
        content: Text(selected.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.editorCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.brushDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _async(() async {
      _adopt(await widget.library!.remove(selected));
    });
  }

  Widget _field(String name, String label, {double width = 140}) => SizedBox(
    width: width,
    child: TextField(
      key: Key('brush-$name'),
      controller: _fields[name],
      enabled: !_busy,
      keyboardType: name == 'name' ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(_controller.invalidate),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, source = widget.editing.maps.state.session;
    if (source == null) return const SizedBox.shrink();
    final preview = _controller.preview;
    final terrain = widget.editing.maps.terrainViewDecoder
        .decode(preview?.result ?? source.rawDocument)
        .tileMaps
        .single;
    final dimensions = source.metadataViews.dimensions.single;
    return ListView(
      key: const Key('brush-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TerrainBrushProfile>(
              segments: [
                ButtonSegment(
                  value: TerrainBrushProfile.raw,
                  label: Text(l.mixedRaw),
                ),
                ButtonSegment(
                  value: TerrainBrushProfile.isom,
                  label: Text(l.mixedIsom),
                ),
              ],
              selected: {_profile},
              onSelectionChanged: _busy
                  ? null
                  : (v) => setState(() {
                      _profile = v.single;
                      _controller.invalidate();
                    }),
            ),
            OutlinedButton.icon(
              key: const Key('brush-catalog'),
              onPressed: _busy || widget.loader == null
                  ? null
                  : () => _async(_controller.loadCatalog),
              icon: const Icon(Icons.refresh),
              label: Text(l.mixedLoad),
            ),
            Text(
              _controller.catalog == null
                  ? l.mixedDataAbsent
                  : l.mixedDataReady,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _field('name', l.brushName, width: 230),
            _field('left', l.basicTileLeft),
            _field('top', l.basicTileTop),
            _field('right', l.basicTileRight),
            _field('bottom', l.basicTileBottom),
            OutlinedButton.icon(
              key: const Key('brush-save'),
              onPressed: _busy || widget.library == null ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(l.brushSave),
            ),
          ],
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<UserTerrainBrush>(
                key: ValueKey(
                  'brush-selection-${_selected?.name}-${_brushes.hashCode}',
                ),
                initialValue: _selected,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.brushLibrary),
                items: [
                  for (final b in _brushes)
                    DropdownMenuItem(
                      value: b,
                      child: Text(
                        '${b.name} · ${b.profile.name} · ${b.width} × ${b.height}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _selected = v;
                        _controller.invalidate();
                        _mirrorX = false;
                        _mirrorY = false;
                      }),
              ),
            ),
            IconButton(
              tooltip: l.brushReload,
              onPressed: _busy || widget.library == null ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              key: const Key('brush-delete'),
              tooltip: l.brushDelete,
              onPressed: _busy || _selected == null ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _field('x', l.basicTileX),
            _field('y', l.basicTileY),
            for (final (horizontal, label) in [
              (true, l.brushMirrorX),
              (false, l.brushMirrorY),
            ])
              SizedBox(
                width: 180,
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: horizontal ? _mirrorX : _mirrorY,
                  onChanged:
                      _busy || _selected?.profile != TerrainBrushProfile.isom
                      ? null
                      : (v) => setState(() {
                          if (horizontal) {
                            _mirrorX = v!;
                          } else {
                            _mirrorY = v!;
                          }
                          _controller.invalidate();
                        }),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('brush-preview'),
              onPressed: _busy || _selected == null
                  ? null
                  : () => _run(() {
                      _controller.previewPaste(
                        _selected!,
                        x: _number('x'),
                        y: _number('y'),
                        mirrorX: _mirrorX,
                        mirrorY: _mirrorY,
                      );
                    }),
              icon: const Icon(Icons.preview),
              label: Text(l.mixedPreviewPaste),
            ),
            FilledButton.icon(
              key: const Key('brush-apply'),
              onPressed: _busy || preview == null
                  ? null
                  : () => _run(() => _controller.apply(preview)),
              icon: const Icon(Icons.check),
              label: Text(l.mixedApply),
            ),
            IconButton(
              tooltip: l.menuUndo,
              onPressed: !_busy && widget.editing.maps.editHistory.canUndo
                  ? () => _run(() => widget.editing.maps.editHistory.undo())
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: l.menuRedo,
              onPressed: !_busy && widget.editing.maps.editHistory.canRedo
                  ? () => _run(() => widget.editing.maps.editHistory.redo())
                  : null,
              icon: const Icon(Icons.redo),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              '${l.brushRejected}\n$_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: MapCanvas(
            key: const Key('brush-canvas'),
            mapWidth: dimensions.width,
            mapHeight: dimensions.height,
            rawTileValues: terrain.rawTileValues,
            terrainTextureState: widget.textures,
            editingTool: TerrainEditingTool.rectangle,
            onRectangleFilled: _busy
                ? null
                : (r) => setState(() {
                    for (final (name, value) in [
                      ('left', r.left),
                      ('top', r.top),
                      ('right', r.right),
                      ('bottom', r.bottom),
                    ]) {
                      _fields[name]!.text = '$value';
                    }
                    _controller.invalidate();
                  }),
          ),
        ),
      ],
    );
  }
}
