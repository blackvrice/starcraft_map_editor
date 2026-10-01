import 'dart:async';
import '../../application/placement/placement_catalog_controller.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../application/documents/opened_map_session.dart';
import 'package:flutter/material.dart';
import '../../application/editing/basic_editing_controller.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/terrain/terrain_editing_controller.dart';
import '../../domain/chk/chk.dart';
import '../localization/l10n.dart';
import '../map_canvas/map_canvas.dart';
import '../map_canvas/terrain_tile_texture_controller.dart';

class BasicEditingToolsDialog extends StatefulWidget {
  const BasicEditingToolsDialog({
    required this.controller,
    this.textures = const TerrainTileTextureState.idle(),
    this.catalog,
    this.initialTab = 0,
    super.key,
  });
  final BasicEditingController controller;
  final TerrainTileTextureState textures;
  final PlacementCatalogController? catalog;
  final int initialTab;
  @override
  State<BasicEditingToolsDialog> createState() =>
      _BasicEditingToolsDialogState();
}

class _BasicEditingToolsDialogState extends State<BasicEditingToolsDialog> {
  int _player = 0, _elevation = 63;
  int? _location;
  bool _hidden = false;
  TerrainEditingTool _fogTool = TerrainEditingTool.brush;
  final _fields = {
    for (final name in [
      'owner',
      'hp',
      'shields',
      'energy',
      'resources',
      'hangar',
      'tileLeft',
      'tileTop',
      'tileRight',
      'tileBottom',
      'tileX',
      'tileY',
      'cutReplacement',
      'spriteOwner',
      'pasteX',
      'pasteY',
      'x',
      'y',
    ])
      name: TextEditingController(),
  };
  final _states = <int, bool?>{};
  final _valid = <int, bool>{};
  String? _error;
  String _locationSearch = '';
  List<DoodadPlacementRecipe> _recipes = [];
  DoodadPlacementRecipe? _recipe;
  MapLayerObjectRef? _doodad;
  int? _overlay;
  int _spriteDisabled = -1;
  bool _doodadEnabled = true;
  bool _loadingRecipe = false;
  RawChkDocument? _draft;
  StreamSubscription<void>? _previewChanges;
  StreamSubscription<Object?>? _mapChanges;
  @override
  void initState() {
    super.initState();
    _draft = widget.controller.maps.state.session?.rawDocument;
    _fields['x']!.text = '128';
    _fields['y']!.text = '128';
    _fields['pasteX']!.text = '128';
    _fields['pasteY']!.text = '128';
    for (final name in [
      'tileLeft',
      'tileTop',
      'tileRight',
      'tileBottom',
      'tileX',
      'tileY',
    ]) {
      _fields[name]!.text = '0';
    }
    _fields['cutReplacement']!.text =
        widget
            .controller
            .maps
            .state
            .session
            ?.terrainViews
            .tileMaps
            .firstOrNull
            ?.rawTileValues
            .firstOrNull
            ?.toString() ??
        '0';
    _previewChanges = widget.controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _mapChanges = widget.controller.maps.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _run(void Function() action, {bool checkDraft = true}) {
    try {
      if (checkDraft &&
          !identical(
            _draft,
            widget.controller.maps.state.session?.rawDocument,
          )) {
        throw StateError(
          'The map changed. Reopen this tool before applying your draft.',
        );
      }
      action();
      _draft = widget.controller.maps.state.session?.rawDocument;
      if (mounted) {
        setState(() {
          _error = null;
        });
      }
    } on Object catch (e) {
      widget.controller.cancelFogStroke();
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    }
  }

  int? _value(String name) => _fields[name]!.text.trim().isEmpty
      ? null
      : int.parse(_fields[name]!.text.trim());
  @override
  void dispose() {
    unawaited(_previewChanges?.cancel());
    unawaited(_mapChanges?.cancel());
    widget.controller.cancelFogStroke();
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, s = widget.controller.maps.state.session;
    return Dialog(
      child: SizedBox(
        width: 960,
        height: 660,
        child: DefaultTabController(
          length: 7,
          initialIndex: widget.initialTab,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.basicToolsTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('basic-tools-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                onTap: (_) => widget.controller.cancelFogStroke(),
                tabs: [
                  Tab(text: l.basicFog),
                  Tab(text: l.basicUnits),
                  Tab(text: l.basicStarts),
                  Tab(text: l.basicLocations),
                  Tab(text: l.basicSpritesDoodads),
                  Tab(text: l.basicClipboard),
                  Tab(text: l.basicRawTerrain),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    '$_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (s == null ||
                  s.requiresRestrictedEditing ||
                  s.metadataViews.dimensions.length != 1 ||
                  s.terrainViews.tileMaps.length != 1)
                Expanded(child: Center(child: Text(l.basicOpenMap)))
              else
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _fog(s),
                      _units(s),
                      _starts(s),
                      _locations(s),
                      _spritesDoodads(s),
                      _clipboard(s),
                      _rawTerrain(s),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fog(OpenedMapSession s) {
    final l = context.l10n;
    List<int>? mask;
    try {
      mask = widget.controller.fog;
    } on Object catch (_) {}
    final dims = s.metadataViews.dimensions;
    if (dims.length != 1 || mask == null) {
      return Center(child: Text(l.basicFogUnavailable));
    }
    final dim = dims.single, terrain = s.terrainViews.tileMaps;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<int>(
                key: const Key('fog-player'),
                value: _player,
                items: [
                  for (var i = 0; i < 8; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(l.basicPlayer(i + 1)),
                    ),
                ],
                onChanged: (v) {
                  widget.controller.cancelFogStroke();
                  setState(() {
                    _player = v!;
                  });
                },
              ),
              FilterChip(
                label: Text(l.basicFogHide),
                selected: _hidden,
                onSelected: (v) {
                  widget.controller.cancelFogStroke();
                  setState(() {
                    _hidden = v;
                  });
                },
              ),
              ChoiceChip(
                label: Text(l.basicBrush),
                selected: _fogTool == TerrainEditingTool.brush,
                onSelected: (_) {
                  widget.controller.cancelFogStroke();
                  setState(() {
                    _fogTool = TerrainEditingTool.brush;
                  });
                },
              ),
              ChoiceChip(
                label: Text(l.basicRectangle),
                selected: _fogTool == TerrainEditingTool.rectangle,
                onSelected: (_) {
                  widget.controller.cancelFogStroke();
                  setState(() {
                    _fogTool = TerrainEditingTool.rectangle;
                  });
                },
              ),
              OutlinedButton(
                key: const Key('fog-fill-all'),
                onPressed: () => _run(() {
                  widget.controller.fillFog(
                    TerrainTileRegion.fromCorners(
                      const TerrainTileCoordinate(x: 0, y: 0),
                      TerrainTileCoordinate(
                        x: dim.width - 1,
                        y: dim.height - 1,
                      ),
                    ),
                    player: _player,
                    hidden: _hidden,
                  );
                }),
                child: Text(l.basicFillAll),
              ),
              Text(l.basicFogScope),
            ],
          ),
        ),
        Expanded(
          child: MapCanvas(
            mapWidth: dim.width,
            mapHeight: dim.height,
            rawTileValues: terrain.length == 1
                ? terrain.single.rawTileValues
                : null,
            terrainTextureState: widget.textures,
            editingTool: _fogTool,
            onEditingToolRequested: (tool) {
              widget.controller.cancelFogStroke();
              setState(() {
                _fogTool = tool;
              });
            },
            fogValues: mask,
            fogPlayer: _player,
            onBrushStrokeStarted: () => _run(widget.controller.beginFogStroke),
            onBrushStroke: (cells) => _run(
              () => widget.controller.paintFog(
                cells,
                player: _player,
                hidden: _hidden,
              ),
            ),
            onBrushStrokeEnded: () => _run(widget.controller.endFogStroke),
            onBrushStrokeCancelled: widget.controller.cancelFogStroke,
            onRectangleFilled: (region) => _run(
              () => widget.controller.fillFog(
                region,
                player: _player,
                hidden: _hidden,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _number(String name, String label) => SizedBox(
    width: 130,
    child: TextField(
      key: ValueKey('basic-$name'),
      controller: _fields[name],
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
    ),
  );
  Widget _units(OpenedMapSession s) {
    final l = context.l10n;
    final selected = widget.controller.layers.state.selections
        .where((x) => x.object.layer == MapLayerType.units)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.basicSelectedUnits(selected.length)),
        const SizedBox(height: 8),
        Text(l.basicKeepBlank),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _number('owner', l.basicOwner),
            _number('hp', l.basicHitpoints),
            _number('shields', l.basicShields),
            _number('energy', l.basicEnergy),
            _number('resources', l.basicResources),
            _number('hangar', l.basicHangar),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.basicUnitStates),
        for (final (bit, label) in [
          (1, l.basicCloak),
          (2, l.basicBurrow),
          (4, l.basicLifted),
          (8, l.basicHallucination),
          (16, l.basicInvincible),
        ])
          Row(
            children: [
              Expanded(child: Text(label)),
              DropdownButton<int>(
                key: ValueKey('basic-state-$bit'),
                value: !_states.containsKey(bit)
                    ? -1
                    : _states[bit] == null
                    ? 2
                    : _states[bit]!
                    ? 1
                    : 0,
                items: [
                  DropdownMenuItem(value: -1, child: Text(l.basicKeep)),
                  DropdownMenuItem(value: 0, child: Text(l.basicOff)),
                  DropdownMenuItem(value: 1, child: Text(l.basicOn)),
                  DropdownMenuItem(value: 2, child: Text(l.basicInherit)),
                ],
                onChanged: (v) => setState(() {
                  if (v == -1) {
                    _states.remove(bit);
                  } else {
                    _states[bit] = v == 2 ? null : v == 1;
                  }
                }),
              ),
            ],
          ),
        ExpansionTile(
          title: Text(l.basicValidFields),
          children: [
            for (final (bit, label) in [
              (1, l.basicOwner),
              (2, l.basicHitpoints),
              (4, l.basicShields),
              (8, l.basicEnergy),
              (16, l.basicResources),
              (32, l.basicHangar),
            ])
              Row(
                children: [
                  Expanded(child: Text(label)),
                  DropdownButton<int>(
                    value: !_valid.containsKey(bit)
                        ? -1
                        : _valid[bit]!
                        ? 1
                        : 0,
                    items: [
                      DropdownMenuItem(value: -1, child: Text(l.basicKeep)),
                      DropdownMenuItem(value: 0, child: Text(l.basicInherit)),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(l.basicApplyStored),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      if (v == -1) {
                        _valid.remove(bit);
                      } else {
                        _valid[bit] = v == 1;
                      }
                    }),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('basic-units-apply'),
          onPressed: selected.isEmpty
              ? null
              : () => _run(() {
                  final owner = _value('owner');
                  widget.controller.patchUnits(
                    states: _states,
                    validFields: _valid,
                    owner: owner == null ? null : owner - 1,
                    hitpoints: _value('hp'),
                    shields: _value('shields'),
                    energy: _value('energy'),
                    resources: _value('resources'),
                    hangar: _value('hangar'),
                  );
                }),
          child: Text(l.basicApply),
        ),
        const SizedBox(height: 16),
        Text(l.basicRelationHelp),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: selected.length != 2
                  ? null
                  : () => _run(() {
                      widget.controller.linkUnits(addon: true);
                    }),
              child: Text(l.basicLinkAddon),
            ),
            OutlinedButton(
              onPressed: selected.length != 2
                  ? null
                  : () => _run(() {
                      widget.controller.linkUnits(addon: false);
                    }),
              child: Text(l.basicLinkNydus),
            ),
            OutlinedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => _run(widget.controller.unlinkUnits),
              child: Text(l.basicUnlink),
            ),
          ],
        ),
      ],
    );
  }

  Widget _starts(OpenedMapSession s) {
    final l = context.l10n, units = s.objectViews.unitSections;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.basicStartsHelp),
        DropdownButton<int>(
          value: _player,
          items: [
            for (var i = 0; i < 8; i++)
              DropdownMenuItem(value: i, child: Text(l.basicPlayer(i + 1))),
          ],
          onChanged: (v) => setState(() {
            _player = v!;
          }),
        ),
        Wrap(
          spacing: 12,
          children: [_number('x', l.basicPixelX), _number('y', l.basicPixelY)],
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('basic-start-apply'),
          onPressed: () => _run(() {
            widget.controller.setStartLocation(
              player: _player,
              x: _value('x')!,
              y: _value('y')!,
            );
          }),
          child: Text(l.basicApply),
        ),
        const SizedBox(height: 12),
        for (var player = 0; player < 8; player++)
          ListTile(
            title: Text(l.basicPlayer(player + 1)),
            subtitle: Text(_startSubtitle(s, player)),
            onTap: () => setState(() {
              _player = player;
              final starts = [
                for (final section in units)
                  for (final u in section.units)
                    if (u.unitType == 214 && u.owner == player) (section, u),
              ];
              if (starts.length == 1) {
                final (section, u) = starts.single;
                _fields['x']!.text = u.x.toString();
                _fields['y']!.text = u.y.toString();
                widget.controller.layers.setActiveLayer(MapLayerType.units);
                widget.controller.layers.selectObject(
                  session: s,
                  object: MapLayerObjectRef(
                    layer: MapLayerType.units,
                    sectionIndex: section.sectionIndex,
                    recordIndex: u.recordIndex,
                  ),
                );
              }
            }),
          ),
        Text(l.basicStartCanvasHelp),
        if (s.metadataViews.dimensions.length == 1)
          SizedBox(
            height: 260,
            child: MapCanvas(
              mapWidth: s.metadataViews.dimensions.single.width,
              mapHeight: s.metadataViews.dimensions.single.height,
              rawTileValues: s.terrainViews.tileMaps.single.rawTileValues,
              terrainTextureState: widget.textures,
              layerScene: widget.controller.layers.sceneFor(s),
              onCanvasSelected: (p) => setState(() {
                _fields['x']!.text = p.pixelX.toString();
                _fields['y']!.text = p.pixelY.toString();
              }),
            ),
          ),
      ],
    );
  }

  String _startSubtitle(OpenedMapSession s, int player) {
    final l = context.l10n,
        starts = [
          for (final section in s.objectViews.unitSections)
            for (final u in section.units)
              if (u.unitType == 214 && u.owner == player) u,
        ];
    if (starts.isEmpty) return l.basicStartMissing;
    return '${starts.length > 1 ? '${l.basicStartDuplicate(starts.length)} · ' : ''}${starts.map((u) => '${u.x}, ${u.y}').join(' / ')}';
  }

  Widget _locations(OpenedMapSession s) {
    final l = context.l10n, tables = s.objectViews.locationSections;
    if (tables.length != 1) {
      return Center(child: Text(l.basicLocationsUnavailable));
    }
    final list = tables.single.locations
        .where(
          (v) =>
              _locationSearch.isEmpty ||
              v.locationId.toString().contains(_locationSearch) ||
              widget.controller
                  .locationName(v)
                  .toLowerCase()
                  .contains(_locationSearch.toLowerCase()),
        )
        .toList();
    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final v = list[i];
              final name = widget.controller.locationName(v);
              return ListTile(
                selected: _location == v.recordIndex,
                title: Text('${v.locationId}: $name'),
                subtitle: Text('${v.left},${v.top} – ${v.right},${v.bottom}'),
                onTap: () => setState(() {
                  _location = v.recordIndex;
                  _elevation = v.elevationFlags & 63;
                  widget.controller.layers.setActiveLayer(
                    MapLayerType.locations,
                  );
                  widget.controller.layers.selectObject(
                    session: s,
                    object: MapLayerObjectRef(
                      layer: MapLayerType.locations,
                      sectionIndex: tables.single.sectionIndex,
                      recordIndex: v.recordIndex,
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const VerticalDivider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('basic-location-search'),
                decoration: InputDecoration(labelText: l.basicLocationSearch),
                onChanged: (v) => setState(() {
                  _locationSearch = v;
                }),
              ),
              const SizedBox(height: 12),
              Text(l.basicElevationHelp),
              for (final (bit, label) in [
                (1, l.basicLowGround),
                (2, l.basicMediumGround),
                (4, l.basicHighGround),
                (8, l.basicLowAir),
                (16, l.basicMediumAir),
                (32, l.basicHighAir),
              ])
                CheckboxListTile(
                  title: Text(label),
                  value: _elevation & bit != 0,
                  onChanged: (v) => setState(() {
                    _elevation = v!
                        ? _elevation | bit
                        : _elevation & (63 ^ bit);
                  }),
                ),
              FilledButton(
                key: const Key('basic-location-apply'),
                onPressed: _location == null
                    ? null
                    : () => _run(() {
                        widget.controller.setLocationElevation(
                          _location!,
                          _elevation,
                        );
                      }),
                child: Text(l.basicApply),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('basic-location-batch'),
                onPressed: widget.controller.layers.state.selections.isEmpty
                    ? null
                    : () => _run(
                        () => widget.controller.setSelectedLocationElevations(
                          _elevation,
                        ),
                      ),
                child: Text(l.basicApplySelectedLocations),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _clipboard(OpenedMapSession s) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.basicClipboardHelp),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              key: const Key('basic-copy'),
              onPressed: () => _run(widget.controller.copyObjects),
              child: Text(l.basicCopy),
            ),
            OutlinedButton(
              key: const Key('basic-cut'),
              onPressed: () =>
                  _run(() => widget.controller.copyObjects(cut: true)),
              child: Text(l.basicCut),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            _number('pasteX', l.basicPixelX),
            _number('pasteY', l.basicPixelY),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('basic-paste'),
          onPressed: widget.controller.hasClipboard
              ? () => _run(() {
                  widget.controller.pasteObjects(
                    x: _value('pasteX')!,
                    y: _value('pasteY')!,
                  );
                })
              : null,
          child: Text(l.basicPaste),
        ),
      ],
    );
  }

  TerrainTileRegion _rawRegion() => TerrainTileRegion.fromCorners(
    TerrainTileCoordinate(x: _value('tileLeft')!, y: _value('tileTop')!),
    TerrainTileCoordinate(x: _value('tileRight')!, y: _value('tileBottom')!),
  );

  Widget _rawTerrain(OpenedMapSession s) {
    final l = context.l10n,
        dim = s.metadataViews.dimensions.single,
        terrain = s.terrainViews.tileMaps;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(l.basicRawClipboardHelp),
              Wrap(
                spacing: 12,
                children: [
                  _number('tileLeft', l.basicTileLeft),
                  _number('tileTop', l.basicTileTop),
                  _number('tileRight', l.basicTileRight),
                  _number('tileBottom', l.basicTileBottom),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  _number('cutReplacement', l.basicCutReplacement),
                  OutlinedButton(
                    key: const Key('basic-terrain-copy'),
                    onPressed: () =>
                        _run(() => widget.controller.copyTerrain(_rawRegion())),
                    child: Text(l.basicCopy),
                  ),
                  OutlinedButton(
                    key: const Key('basic-terrain-cut'),
                    onPressed: () => _run(
                      () => widget.controller.copyTerrain(
                        _rawRegion(),
                        cutReplacement: _value('cutReplacement')!,
                      ),
                    ),
                    child: Text(l.basicCut),
                  ),
                  _number('tileX', l.basicTileX),
                  _number('tileY', l.basicTileY),
                  FilledButton(
                    key: const Key('basic-terrain-paste'),
                    onPressed: widget.controller.hasTerrainClipboard
                        ? () => _run(
                            () => widget.controller.pasteTerrain(
                              x: _value('tileX')!,
                              y: _value('tileY')!,
                            ),
                          )
                        : null,
                    child: Text(l.basicPaste),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: MapCanvas(
            mapWidth: dim.width,
            mapHeight: dim.height,
            rawTileValues: terrain.length == 1
                ? terrain.single.rawTileValues
                : null,
            terrainTextureState: widget.textures,
            editingTool: TerrainEditingTool.rectangle,
            onRectangleFilled: (r) => setState(() {
              _fields['tileLeft']!.text = r.left.toString();
              _fields['tileTop']!.text = r.top.toString();
              _fields['tileRight']!.text = r.right.toString();
              _fields['tileBottom']!.text = r.bottom.toString();
            }),
          ),
        ),
      ],
    );
  }

  Future<void> _loadDoodad() async {
    try {
      final s = widget.controller.source,
          selected = widget.controller.layers.state.selections;
      if (!identical(_draft, s.rawDocument) ||
          selected.length != 1 ||
          selected.single.object.layer != MapLayerType.doodads) {
        throw StateError('Select one Doodad in the current document.');
      }
      final object = selected.single.object;
      if (s.objectViews.spriteSections.length > 1) {
        throw StateError('Multiple THG2 sections are ambiguous.');
      }
      final dd = s.objectViews.doodadSections
          .singleWhere((v) => v.sectionIndex == object.sectionIndex)
          .doodads[object.recordIndex];
      setState(() {
        _loadingRecipe = true;
        _recipes = [];
        _recipe = null;
        _overlay = null;
        _doodad = null;
      });
      final recipes = await widget.catalog!.doodadRecipes(dd.doodadType);
      if (!mounted) return;
      if (!identical(s.rawDocument, widget.controller.source.rawDocument) ||
          widget.controller.layers.state.selection?.object != object) {
        throw StateError(
          'The map or selection changed. Load the recipe again.',
        );
      }
      if (recipes.isEmpty) {
        throw StateError('No verified local recipe is available.');
      }
      setState(() {
        _recipes = recipes;
        _recipe = recipes.first;
        _doodad = object;
        _doodadEnabled = dd.enabledValue == 0;
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecipe = false;
        });
      }
    }
  }

  Widget _spritesDoodads(OpenedMapSession s) {
    final l = context.l10n, overlay = _recipe?.overlay;
    final dd = _doodad == null
        ? null
        : s.objectViews.doodadSections
              .where((v) => v.sectionIndex == _doodad!.sectionIndex)
              .firstOrNull
              ?.doodads
              .elementAtOrNull(_doodad!.recordIndex);
    final candidates = [
      for (final section in s.objectViews.spriteSections)
        for (final sprite in section.sprites)
          if (overlay != null &&
              dd != null &&
              sprite.spriteType == overlay.id &&
              sprite.x == dd.x &&
              sprite.y == dd.y &&
              sprite.owner == dd.owner &&
              (sprite.flags == overlay.thg2Flags ||
                  (overlay.thg2Flags & 0x1000 == 0 &&
                      sprite.flags == (overlay.thg2Flags | 0x8000))) &&
              sprite.unused == 0)
            sprite,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.basicSpriteHelp),
        const SizedBox(height: 12),
        _number('spriteOwner', l.basicOwner),
        Row(
          children: [
            Expanded(child: Text(l.basicSpriteDisabled)),
            DropdownButton<int>(
              value: _spriteDisabled,
              items: [
                DropdownMenuItem(value: -1, child: Text(l.basicKeep)),
                DropdownMenuItem(value: 0, child: Text(l.basicOff)),
                DropdownMenuItem(value: 1, child: Text(l.basicOn)),
              ],
              onChanged: (v) => setState(() {
                _spriteDisabled = v!;
              }),
            ),
          ],
        ),
        FilledButton(
          key: const Key('basic-sprites-apply'),
          onPressed: () => _run(() {
            final owner = _value('spriteOwner');
            widget.controller.patchSprites(
              owner: owner == null ? null : owner - 1,
              disabled: _spriteDisabled < 0 ? null : _spriteDisabled == 1,
            );
          }),
          child: Text(l.basicApply),
        ),
        const Divider(height: 32),
        Text(l.basicDoodadHelp),
        OutlinedButton(
          key: const Key('basic-load-doodad'),
          onPressed: widget.catalog == null || _loadingRecipe
              ? null
              : _loadDoodad,
          child: Text(l.basicLoadDoodad),
        ),
        if (_recipes.isNotEmpty)
          DropdownButton<DoodadPlacementRecipe>(
            value: _recipe,
            items: [
              for (var i = 0; i < _recipes.length; i++)
                DropdownMenuItem(
                  value: _recipes[i],
                  child: Text(
                    'Variant ${i + 1} (${_recipes[i].width} × ${_recipes[i].height})',
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _recipe = v;
              _overlay = null;
            }),
          ),
        if (overlay != null)
          DropdownButton<int>(
            hint: Text(l.basicOverlay),
            value: candidates.any((v) => v.recordIndex == _overlay)
                ? _overlay
                : null,
            items: [
              for (final v in candidates)
                DropdownMenuItem(
                  value: v.recordIndex,
                  child: Text('THG2 #${v.recordIndex + 1}'),
                ),
            ],
            onChanged: (v) => setState(() {
              _overlay = v;
            }),
          ),
        CheckboxListTile(
          title: Text(l.basicDoodadEnabled),
          value: _doodadEnabled,
          onChanged: (v) => setState(() {
            _doodadEnabled = v!;
          }),
        ),
        FilledButton(
          key: const Key('basic-doodad-apply'),
          onPressed:
              _recipe == null ||
                  _doodad == null ||
                  (overlay != null && _overlay == null)
              ? null
              : () => _run(() {
                  widget.controller.setDoodadEnabled(
                    recipe: _recipe!,
                    recordIndex: _doodad!.recordIndex,
                    enabled: _doodadEnabled,
                    overlayRecordIndex: _overlay,
                  );
                }),
          child: Text(l.basicApply),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              key: const Key('basic-doodad-copy'),
              onPressed:
                  _recipe == null ||
                      _doodad == null ||
                      (overlay != null && _overlay == null)
                  ? null
                  : () => _run(
                      () => widget.controller.copyDoodad(
                        recipe: _recipe!,
                        recordIndex: _doodad!.recordIndex,
                        overlayRecordIndex: _overlay,
                      ),
                    ),
              child: Text(l.basicCopy),
            ),
            OutlinedButton(
              key: const Key('basic-doodad-cut'),
              onPressed:
                  _recipe == null ||
                      _doodad == null ||
                      (overlay != null && _overlay == null)
                  ? null
                  : () => _run(() {
                      widget.controller.copyDoodad(
                        recipe: _recipe!,
                        recordIndex: _doodad!.recordIndex,
                        overlayRecordIndex: _overlay,
                        cut: true,
                      );
                      _doodad = null;
                      _overlay = null;
                      _recipes = [];
                      _recipe = null;
                    }),
              child: Text(l.basicCut),
            ),
            _number('tileX', l.basicTileX),
            _number('tileY', l.basicTileY),
            FilledButton(
              key: const Key('basic-doodad-paste'),
              onPressed: widget.controller.hasDoodadClipboard
                  ? () => _run(
                      () => widget.controller.pasteDoodad(
                        tileX: _value('tileX')!,
                        tileY: _value('tileY')!,
                      ),
                    )
                  : null,
              child: Text(l.basicPaste),
            ),
          ],
        ),
      ],
    );
  }
}
