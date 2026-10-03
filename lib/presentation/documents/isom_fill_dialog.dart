import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../application/documents/isom_fill_controller.dart';
import '../../application/terrain/solid_isom_catalog_builder.dart';
import '../../domain/terrain/isom_terrain_fill.dart';
import '../../domain/terrain/isom_terrain_paint.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';
import '../localization/l10n.dart';

class IsomFillDialog extends StatefulWidget {
  const IsomFillDialog({
    required this.controller,
    this.initialMode = 0,
    super.key,
  });
  final IsomFillController controller;
  final int initialMode;
  @override
  State<IsomFillDialog> createState() => _IsomFillDialogState();
}

class _IsomFillDialogState extends State<IsomFillDialog> {
  SolidIsomCatalog? _catalog;
  int? _type;
  IsomFillPreview? _preview;
  Object? _error;
  bool _loading = true;
  int _mode = 0;
  bool get _convert => _mode == 1;
  bool get _interactive => _mode >= 2;
  int _size = 1;
  int _seed = 0;
  TerrainEditingTool _tool = TerrainEditingTool.brush;
  final Set<IsomDiamond> _stroke = {};
  DoodadPlacementRecipe? _ramp;
  TerrainTileTextureController? _textures;
  StreamSubscription<TerrainTileTextureState>? _textureSubscription;
  StreamSubscription<Object?>? _mapSubscription;
  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _mapSubscription = widget.controller.maps.changes.listen((state) {
      final source = widget.controller.source;
      if (mounted && source != null && !identical(source, state.session)) {
        setState(() {
          _catalog = null;
          _preview = null;
          _error = StateError('The map changed. Reopen terrain editing.');
        });
      }
    });
    if (widget.controller.atlasLoader case final loader?) {
      _textures = TerrainTileTextureController(loader: loader);
      _textureSubscription = _textures!.changes.listen((_) {
        if (mounted) setState(() {});
      });
    }
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
        _ramp = widget.controller.ramps.firstOrNull;
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
    if (_interactive) {
      widget.controller.discardPreview();
      _refreshTextures();
      return;
    }
    try {
      _preview = _convert
          ? widget.controller.previewConversion(seed: _seed)
          : widget.controller.preview(terrainType: _type!, seed: _seed);
    } on Object catch (e) {
      _error = e;
    }
    _refreshTextures();
  }

  void _refreshTextures() {
    final source = widget.controller.source;
    if (source == null || _textures == null) return;
    try {
      unawaited(
        _textures!.synchronize(
          metadataViews: source.metadataViews,
          terrainViews: widget.controller.previewTerrainViews(_preview),
          assetState: widget.controller.assets(),
        ),
      );
    } on Object catch (e) {
      _error = e;
    }
  }

  void _collect(List<TerrainTileCoordinate> tiles) {
    final view = widget.controller.previewTerrain(_preview);
    for (final t in tiles) {
      final center = IsomTerrainPaint.diamondAtTile(t.x, t.y);
      for (var a = 0; a < _size; a++) {
        for (var b = 0; b < _size; b++) {
          final d = (center.$1 + a - b, center.$2 + a + b);
          if (d.$1 >= 0 &&
              d.$1 <= view.width! ~/ 2 &&
              d.$2 >= 0 &&
              d.$2 <= view.height!) {
            _stroke.add(d);
          }
        }
      }
    }
  }

  void _paint() {
    if (_stroke.isEmpty) return;
    setState(() {
      try {
        _preview = widget.controller.previewPaint(
          terrainType: _type!,
          diamonds: {..._stroke},
          basePreview: _preview,
          seed: _seed,
        );
        _error = null;
      } on Object catch (e) {
        _error = e;
      }
      _stroke.clear();
    });
    _refreshTextures();
  }

  void _rectangle(TerrainTileRegion r) {
    _stroke.clear();
    _collect([
      for (var y = r.top; y <= r.bottom; y++)
        for (var x = r.left; x <= r.right; x++)
          TerrainTileCoordinate(x: x, y: y),
    ]);
    _paint();
  }

  void _placeRamp(TerrainTileCoordinate t) {
    if (_ramp == null) return;
    setState(() {
      try {
        _preview = widget.controller.previewRamp(
          recipe: _ramp!,
          x: t.x,
          y: t.y,
        );
        _error = null;
      } on Object catch (e) {
        _preview = null;
        _error = e;
      }
    });
    _refreshTextures();
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
    _textureSubscription?.cancel();
    _mapSubscription?.cancel();
    _textures?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.isomFillTitle),
      content: SizedBox(
        width: _interactive ? 900 : 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.isomFillScope),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l.isomFillMode)),
                  ButtonSegment(value: 1, label: Text(l.isomConvertMode)),
                  ButtonSegment(value: 2, label: Text(l.isomBrushMode)),
                  ButtonSegment(value: 3, label: Text(l.isomRampMode)),
                ],
                selected: {_mode},
                onSelectionChanged: _loading
                    ? null
                    : (v) => setState(() {
                        _mode = v.single;
                        _refresh();
                      }),
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('isom-variation-seed-$_seed'),
                      initialValue: '$_seed',
                      decoration: InputDecoration(
                        labelText: l.terrainVariationSeed,
                      ),
                      keyboardType: TextInputType.number,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (text) {
                        final seed = int.tryParse(text ?? '');
                        return seed == null || seed < 0 || seed > 0xffffffff
                            ? l.terrainSeedInvalid
                            : null;
                      },
                      onFieldSubmitted: (text) {
                        final seed = int.tryParse(text);
                        if (seed != null && seed >= 0 && seed <= 0xffffffff) {
                          setState(() {
                            _seed = seed;
                            _refresh();
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    key: const Key('isom-randomize'),
                    tooltip: l.terrainVariationSeed,
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                            _seed = Random().nextInt(0x7fffffff);
                            _refresh();
                          }),
                    icon: const Icon(Icons.shuffle),
                  ),
                ],
              ),
              if (!_convert && _mode != 3 && _catalog != null)
                DropdownButtonFormField<int>(
                  key: const Key('isom-terrain-type'),
                  initialValue: _type,
                  decoration: InputDecoration(labelText: l.isomTerrainType),
                  items: [
                    for (final type in _catalog!.shapes.keys)
                      DropdownMenuItem(
                        value: type,
                        child: Text(l.isomTerrainId(type)),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v;
                    if (!_interactive) _refresh();
                  }),
                ),
              if (_mode == 2 && _catalog != null) ...[
                const SizedBox(height: 8),
                Text(l.isomBrushHint),
                Row(
                  children: [
                    SegmentedButton<TerrainEditingTool>(
                      segments: [
                        ButtonSegment(
                          value: TerrainEditingTool.brush,
                          label: Text(l.isomBrushFreehand),
                        ),
                        ButtonSegment(
                          value: TerrainEditingTool.rectangle,
                          label: Text(l.isomBrushRectangle),
                        ),
                      ],
                      selected: {_tool},
                      onSelectionChanged: (v) =>
                          setState(() => _tool = v.single),
                    ),
                    const SizedBox(width: 12),
                    Text('${l.isomBrushSize}: $_size'),
                    Expanded(
                      child: Slider(
                        value: _size.toDouble(),
                        min: 1,
                        max: 4,
                        divisions: 3,
                        onChanged: (v) => setState(() => _size = v.round()),
                      ),
                    ),
                  ],
                ),
              ],
              if (_mode == 3 && _catalog != null) ...[
                Text(l.isomRampHint),
                if (widget.controller.ramps.isEmpty)
                  Text(l.isomRampEmpty)
                else
                  DropdownButtonFormField<DoodadPlacementRecipe>(
                    key: const Key('isom-ramp-recipe'),
                    initialValue: _ramp,
                    decoration: InputDecoration(labelText: l.isomRampRecipe),
                    items: [
                      for (final r in widget.controller.ramps)
                        DropdownMenuItem(
                          value: r,
                          child: Text(
                            'Doodad #${r.doodadType} / CV5 #${r.startTileGroup} (${r.width} × ${r.height})',
                          ),
                        ),
                    ],
                    onChanged: (r) => setState(() {
                      _ramp = r;
                      _refresh();
                    }),
                  ),
              ],
              if (_interactive && _catalog != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: Builder(
                    builder: (context) {
                      final view = widget.controller.previewTerrain(_preview);
                      return MapCanvas(
                        key: const Key('isom-brush-canvas'),
                        mapWidth: view.width!,
                        mapHeight: view.height!,
                        rawTileValues: view.rawTileValues,
                        terrainTextureState:
                            _textures?.state ??
                            const TerrainTileTextureState.idle(),
                        editingTool: _mode == 3
                            ? TerrainEditingTool.select
                            : _tool,
                        onTileSelected: _mode == 3 ? _placeRamp : null,
                        onBrushStrokeStarted: () => _stroke.clear(),
                        onBrushStroke: _collect,
                        onBrushStrokeEnded: _paint,
                        onBrushStrokeCancelled: () => _stroke.clear(),
                        onRectangleFilled: _rectangle,
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => setState(_refresh),
                  child: Text(l.isomBrushReset),
                ),
              ],
              if (_preview case final IsomFillPreview p) ...[
                const SizedBox(height: 16),
                Text(
                  _convert
                      ? l.isomConvertPreview(p.changedTileCount)
                      : l.isomFillPreview(p.changedTileCount),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                if (_mode == 2 && _preview != null)
                  Text(l.isomBrushStrokeRejected),
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
          child: Text(
            _interactive
                ? l.isomBrushApply
                : _convert
                ? l.isomConvertApply
                : l.isomFillApply,
          ),
        ),
      ],
    );
  }
}
