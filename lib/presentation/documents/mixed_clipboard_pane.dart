import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../../application/editing/mixed_clipboard_controller.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/chk/chk_mixed_clipboard.dart';
import '../../domain/terrain/isom_doodad_overlay.dart';
import '../localization/l10n.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';

class MixedClipboardPane extends StatefulWidget {
  const MixedClipboardPane({
    required this.controller,
    this.loader,
    this.textures = const TerrainTileTextureState.idle(),
    super.key,
  });
  final BasicEditingController controller;
  final IsomFillController? loader;
  final TerrainTileTextureState textures;
  @override
  State<MixedClipboardPane> createState() => _MixedClipboardPaneState();
}

class _MixedClipboardPaneState extends State<MixedClipboardPane> {
  final _fields = {
    for (final entry in {
      'left': '0',
      'top': '0',
      'right': '7',
      'bottom': '3',
      'x': '8',
      'y': '8',
      'fill': '0',
    }.entries)
      entry.key: TextEditingController(text: entry.value),
  };
  final _kinds = <String>{'UNIT', 'THG2', 'MRGN', 'DD2 '};
  final _overlays = <int, int>{};
  List<IsomDoodadInstance> _doodads = [];
  MixedClipboardProfile _profile = MixedClipboardProfile.raw;
  StreamSubscription<Object?>? _changes;
  StreamSubscription<Object?>? _targetChanges;
  bool _loading = false;
  int? _fillShape;
  String? _error;
  MixedClipboardController get _mixed => widget.controller.mixedClipboard;
  @override
  void initState() {
    super.initState();
    final doc = widget.controller.maps.state.session?.rawDocument;
    _profile = doc?.sections.any((s) => s.name == 'ISOM') == true
        ? MixedClipboardProfile.isom
        : MixedClipboardProfile.raw;
    final copied = _mixed.clipboard;
    if (copied != null) {
      _profile = copied.profile;
      for (final (name, value) in [
        ('left', copied.region.left),
        ('top', copied.region.top),
        ('right', copied.region.right),
        ('bottom', copied.region.bottom),
      ]) {
        _fields[name]!.text = '$value';
      }
    }
    _changes = widget.controller.maps.changes.listen((_) {
      if (mounted) {
        setState(() {
          _doodads = [];
          _overlays.clear();
        });
      }
    });
    _targetChanges = _mixed.targetMaps?.changes.listen((_) {
      if (mounted) setState(_mixed.invalidatePreview);
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    unawaited(_targetChanges?.cancel());
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  int _number(String name) => int.parse(_fields[name]!.text.trim());
  ClipboardRegion get _region => ClipboardRegion(
    _number('left'),
    _number('top'),
    _number('right'),
    _number('bottom'),
  );
  void _run(void Function() action) {
    try {
      action();
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _sourceChanged() {
    _mixed.clear();
    _overlays.clear();
    _doodads = [];
    setState(() => _error = null);
  }

  Widget _field(String name, String label, {bool source = false}) => SizedBox(
    width: 140,
    child: TextField(
      key: Key('mixed-$name'),
      controller: _fields[name],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) {
        if (source) {
          _sourceChanged();
        } else {
          setState(_mixed.invalidatePreview);
        }
      },
    ),
  );
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _doodads = [];
      _overlays.clear();
    });
    try {
      await _mixed.load(widget.loader!);
      if (mounted) setState(() => _error = null);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scan() {
    _mixed.clear();
    _overlays.clear();
    _doodads = _mixed.doodads(_region, _profile);
  }

  void _capture() => _mixed.capture(
    region: _region,
    profile: _profile,
    kinds: _kinds,
    overlays: _overlays,
  );

  String _message(String error) {
    final l = context.l10n;
    final label = switch (error) {
      final s when s.contains('PARTIAL_DOODAD') => l.mixedPartialDoodad,
      final s when s.contains('PARTIAL_LOCATION') => l.mixedPartialLocation,
      final s when s.contains('OVERLAY') => l.mixedOverlayError,
      final s when s.contains('ISOM_ALIGNMENT') || s.contains('PROFILE') =>
        l.mixedProfileError,
      final s when s.contains('LAYER') => l.mixedLayerError,
      final s when s.contains('STALE') => l.mixedStale,
      _ => l.mixedRejected,
    };
    return '$label\n$error';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, session = widget.controller.maps.state.session;
    if (session == null) return const SizedBox.shrink();
    final clipboard = _mixed.clipboard, preview = _mixed.preview;
    final current = _mixed.isPreviewCurrent;
    final terrain = widget.controller.maps.terrainViewDecoder
        .decode(current ? preview!.result : session.rawDocument)
        .tileMaps
        .single;
    final dims =
        (current ? preview!.session : session).metadataViews.dimensions.single;
    final sprites = widget.controller.editor
        .section(session.rawDocument, 'THG2', stride: 10)
        ?.payload;
    final sp = sprites == null ? null : ByteData.sublistView(sprites);
    final catalog = _mixed.catalog;
    return ListView(
      key: const Key('mixed-list'),
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<MixedClipboardProfile>(
              segments: [
                ButtonSegment(
                  value: MixedClipboardProfile.raw,
                  label: Text(l.mixedRaw),
                ),
                ButtonSegment(
                  value: MixedClipboardProfile.isom,
                  label: Text(l.mixedIsom),
                ),
              ],
              selected: {_profile},
              onSelectionChanged: _loading
                  ? null
                  : (values) {
                      _profile = values.single;
                      _sourceChanged();
                    },
            ),
            OutlinedButton.icon(
              key: const Key('mixed-load'),
              onPressed: _loading || widget.loader == null ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(l.mixedLoad),
            ),
            Text(_mixed.hasData ? l.mixedDataReady : l.mixedDataAbsent),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _field('left', l.basicTileLeft, source: true),
            _field('top', l.basicTileTop, source: true),
            _field('right', l.basicTileRight, source: true),
            _field('bottom', l.basicTileBottom, source: true),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (kind, label) in [
              ('UNIT', l.basicUnits),
              ('THG2', 'Sprite'),
              ('DD2 ', l.layerDoodads),
              ('MRGN', l.basicLocations),
            ])
              SizedBox(
                width: 175,
                child: CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: _kinds.contains(kind),
                  onChanged: (v) {
                    v == true ? _kinds.add(kind) : _kinds.remove(kind);
                    _sourceChanged();
                  },
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('mixed-scan'),
              onPressed: _loading ? null : () => _run(_scan),
              icon: const Icon(Icons.search),
              label: Text(l.mixedScan),
            ),
            OutlinedButton.icon(
              key: const Key('mixed-copy'),
              onPressed: _loading ? null : () => _run(_capture),
              icon: const Icon(Icons.copy),
              label: Text(l.basicCopy),
            ),
          ],
        ),
        for (final d in _doodads.where((d) => d.recipe.overlay != null))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<int>(
              key: ValueKey(
                'mixed-overlay-${d.recordIndex}-${session.rawDocument.hashCode}',
              ),
              initialValue: _overlays[d.recordIndex],
              isExpanded: true,
              decoration: InputDecoration(
                labelText:
                    'DD2 #${d.recordIndex + 1} · ${l.mixedOverlay} (${d.recipe.overlay!.id})',
              ),
              items: [
                if (sp != null)
                  for (var i = 0; i < sp.lengthInBytes ~/ 10; i++)
                    if (sp.getUint16(i * 10, Endian.little) ==
                        d.recipe.overlay!.id)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          'THG2 #${i + 1} · ${sp.getUint16(i * 10 + 2, Endian.little)}, ${sp.getUint16(i * 10 + 4, Endian.little)}',
                        ),
                      ),
              ],
              onChanged: (v) {
                setState(() {
                  _mixed.clear();
                  if (v == null) {
                    _overlays.remove(d.recordIndex);
                  } else {
                    _overlays[d.recordIndex] = v;
                  }
                });
              },
            ),
          ),
        if (clipboard != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.mixedSummary(
                clipboard.region.width,
                clipboard.region.height,
                clipboard.objectCount,
                clipboard.skippedReserved,
              ),
            ),
          ),
        const Divider(),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _field('x', l.basicTileX),
            _field('y', l.basicTileY),
            if (!_mixed.isCrossDocument &&
                _profile == MixedClipboardProfile.raw)
              _field('fill', l.basicCutReplacement)
            else if (!_mixed.isCrossDocument)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  initialValue:
                      catalog?.shapes.values.contains(_fillShape) == true
                      ? _fillShape
                      : null,
                  decoration: InputDecoration(labelText: l.mixedFill),
                  items: [
                    if (catalog != null)
                      for (final e in catalog.shapes.entries)
                        DropdownMenuItem(
                          value: e.value,
                          child: Text(
                            '${l.isomTerrainType} ${e.key} / ${e.value}',
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() {
                    _fillShape = v;
                    _mixed.invalidatePreview();
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('mixed-preview-paste'),
              onPressed: clipboard == null
                  ? null
                  : () => _run(
                      () =>
                          _mixed.previewPaste(x: _number('x'), y: _number('y')),
                    ),
              icon: const Icon(Icons.content_paste),
              label: Text(l.mixedPreviewPaste),
            ),
            if (!_mixed.isCrossDocument)
              OutlinedButton.icon(
                key: const Key('mixed-preview-cut'),
                onPressed: clipboard == null
                    ? null
                    : () => _run(
                        () => _mixed.previewCut(
                          rawReplacement: _profile == MixedClipboardProfile.raw
                              ? _number('fill')
                              : null,
                          fillShape: _fillShape,
                        ),
                      ),
                icon: const Icon(Icons.content_cut),
                label: Text(l.mixedPreviewCut),
              ),
            FilledButton.icon(
              key: const Key('mixed-apply'),
              onPressed: !current || preview == null
                  ? null
                  : () => _run(() => _mixed.applyPreview(preview)),
              icon: const Icon(Icons.check),
              label: Text(l.mixedApply),
            ),
            if (!_mixed.isCrossDocument)
              IconButton(
                tooltip: l.menuUndo,
                onPressed: widget.controller.maps.editHistory.canUndo
                    ? () =>
                          _run(() => widget.controller.maps.editHistory.undo())
                    : null,
                icon: const Icon(Icons.undo),
              ),
            if (!_mixed.isCrossDocument)
              IconButton(
                tooltip: l.menuRedo,
                onPressed: widget.controller.maps.editHistory.canRedo
                    ? () =>
                          _run(() => widget.controller.maps.editHistory.redo())
                    : null,
                icon: const Icon(Icons.redo),
              ),
          ],
        ),
        if (current && preview != null)
          Text(l.mixedPreviewSummary(preview.changedSections)),
        if (preview?.transfer case final transfer? when current) ...[
          for (final (name, ids) in [
            (l.layerUnits, transfer.units),
            (l.layerLocations, transfer.references?.locations ?? <int, int>{}),
            (l.transferStrings, transfer.references?.strings ?? <int, int>{}),
          ])
            if (ids.isNotEmpty)
              SelectableText(
                '$name: ${ids.entries.map((e) => '${e.key} -> ${e.value}').join(', ')}',
              ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              _message(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: MapCanvas(
            key: const Key('mixed-canvas'),
            mapWidth: dims.width,
            mapHeight: dims.height,
            rawTileValues: terrain.rawTileValues,
            terrainTextureState: widget.textures,
            layerScene: widget.controller.layers.sceneFor(
              current ? preview!.session : session,
            ),
            editingTool: _mixed.isCrossDocument && current
                ? TerrainEditingTool.select
                : TerrainEditingTool.rectangle,
            onRectangleFilled: _mixed.isCrossDocument && current
                ? null
                : (r) {
                    for (final (name, value) in [
                      ('left', r.left),
                      ('top', r.top),
                      ('right', r.right),
                      ('bottom', r.bottom),
                    ]) {
                      _fields[name]!.text = '$value';
                    }
                    _sourceChanged();
                  },
          ),
        ),
      ],
    );
  }
}
