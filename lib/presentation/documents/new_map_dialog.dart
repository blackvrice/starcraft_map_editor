import 'package:flutter/material.dart';

import '../../application/documents/new_map_controller.dart';
import '../../application/terrain/tile_placement_catalog_loader.dart';
import '../../application/terrain/solid_isom_catalog_builder.dart';
import 'dart:math';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/chk/new_map_factory.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../localization/l10n.dart';
import '../placement/catalog_thumbnail.dart';

enum _NewMapStep { basics, players, review }

/// Guided three-step dialog for creating a new map.
///
/// Every step can be revisited from the step list, and "Create" is available
/// as soon as the required starting tile is chosen, so experienced users are
/// not forced through the wizard.
class NewMapDialog extends StatefulWidget {
  const NewMapDialog({required this.controller, super.key});
  final NewMapController controller;
  @override
  State<NewMapDialog> createState() => _NewMapDialogState();
}

class _NewMapDialogState extends State<NewMapDialog> {
  static const _sizeValues = [32, 64, 96, 128, 160, 192, 224, 256];

  TextEditingController? _title;
  final _description = TextEditingController();
  int _width = 128, _height = 128, _players = 1, _offset = 0, _revision = 0;
  int? _tile;
  int? _terrainType;
  SolidIsomCatalog? _terrain;
  late bool _terrainMode;
  final int _terrainSeed = Random().nextInt(0x7fffffff);
  bool _customSize = false;
  var _step = _NewMapStep.basics;
  var _tileset = StarCraftTilesetAssetSet.badlands;
  TilePlacementCatalogBatch? _batch;
  bool _loading = true, _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _terrainMode = widget.controller.terrainGateway != null;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _title ??= TextEditingController(text: context.l10n.newMapDefaultTitle);
  }

  @override
  void dispose() {
    _title?.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _tile = null;
      _batch = null;
      _terrain = null;
      _terrainType = null;
      _error = null;
    });
    try {
      if (_terrainMode) {
        final terrain = await widget.controller.loadTerrain(_tileset);
        if (mounted && revision == _revision) {
          setState(() {
            _terrain = terrain;
            _terrainType = terrain.shapes.keys.firstWhere(
              (type) => terrain.catalog.pairs.any(
                (p) => p.terrainType == type && p.members.length > 1,
              ),
              orElse: () => terrain.shapes.keys.first,
            );
            _tile = 0;
          });
        }
      } else {
        final batch = await widget.controller.loadTiles(
          _tileset,
          offset: _offset,
        );
        if (mounted && revision == _revision) setState(() => _batch = batch);
      }
    } catch (e) {
      if (mounted && revision == _revision) setState(() => _error = '$e');
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      var options = NewMapOptions(
        width: _width,
        height: _height,
        humanPlayers: _players,
        tileset: ChkTileset.values.firstWhere(
          (v) => v.rawValue == _tileset.rawValue,
        ),
        rawTileValue: _tile!,
        title: _title!.text,
        description: _description.text,
      );
      if (_terrainMode) {
        options = widget.controller.terrainOptions(
          options,
          _terrainType!,
          _terrainSeed,
        );
      }
      if (widget.controller.expectedSession?.isDirty ?? false) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.newMapDiscardTitle),
            content: Text(l10n.newMapDiscardBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.newMapKeepCurrent),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.newMapDiscardAndCreate),
              ),
            ],
          ),
        );
        if (!mounted || discard != true) return;
      }
      if (!mounted) return;
      widget.controller.create(options);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _selectTileset(StarCraftTilesetAssetSet tileset) {
    if (_creating || tileset == _tileset) return;
    setState(() {
      _tileset = tileset;
      _offset = 0;
    });
    _load();
  }

  void _selectPreset(int size) {
    if (_creating) return;
    setState(() {
      _customSize = false;
      _width = size;
      _height = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canCreate = !_loading && !_creating && _tile != null;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 800;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact)
                  _StepList(
                    current: _step,
                    onSelected: _creating
                        ? null
                        : (s) => setState(() => _step = s),
                  ),
                if (!compact) const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (compact)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Text(
                            l10n.newMapTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (compact)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: SegmentedButton<_NewMapStep>(
                            key: const Key('new-map-compact-steps'),
                            segments: [
                              ButtonSegment(
                                value: _NewMapStep.basics,
                                label: Text(l10n.newMapStepBasics),
                              ),
                              ButtonSegment(
                                value: _NewMapStep.players,
                                label: Text(l10n.newMapStepPlayers),
                              ),
                              ButtonSegment(
                                value: _NewMapStep.review,
                                label: Text(l10n.newMapStepReview),
                              ),
                            ],
                            selected: {_step},
                            showSelectedIcon: false,
                            onSelectionChanged: _creating
                                ? null
                                : (steps) =>
                                      setState(() => _step = steps.single),
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                          child: switch (_step) {
                            _NewMapStep.basics => _basics(context),
                            _NewMapStep.players => _playersStep(context),
                            _NewMapStep.review => _review(context),
                          },
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _summary(l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFA7AFB8),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _creating
                                  ? null
                                  : () => Navigator.pop(context, false),
                              child: Text(l10n.newMapCancel),
                            ),
                            if (_step != _NewMapStep.basics) ...[
                              const SizedBox(width: 6),
                              OutlinedButton(
                                key: const Key('new-map-back'),
                                onPressed: _creating
                                    ? null
                                    : () => setState(
                                        () => _step =
                                            _NewMapStep.values[_step.index - 1],
                                      ),
                                child: Text(l10n.newMapBack),
                              ),
                            ],
                            if (_step != _NewMapStep.review) ...[
                              const SizedBox(width: 6),
                              OutlinedButton(
                                key: const Key('new-map-next'),
                                onPressed: _creating
                                    ? null
                                    : () => setState(
                                        () => _step =
                                            _NewMapStep.values[_step.index + 1],
                                      ),
                                child: Text(l10n.newMapContinue),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Tooltip(
                              message: canCreate ? '' : l10n.newMapTileRequired,
                              child: FilledButton.icon(
                                key: const Key('create-new-map'),
                                onPressed: canCreate ? _create : null,
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(l10n.newMapCreate),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _summary(AppLocalizations l10n) => [
    l10n.newMapSizeValue(_width, _height),
    _tilesetName(l10n, _tileset),
    l10n.newMapPlayersValue(_players),
    _terrainMode && _terrainType != null
        ? l10n.isomTerrainId(_terrainType!)
        : _tile == null
        ? l10n.newMapReviewNoTile
        : l10n.newMapReviewTile('$_tile'),
  ].join(' · ');

  Widget _basics(BuildContext context) {
    final l10n = context.l10n;
    final batch = _batch;
    final presets = [
      (64, l10n.newMapSizeSmall, l10n.newMapSizeSmallNote),
      (96, l10n.newMapSizeCompact, l10n.newMapSizeCompactNote),
      (128, l10n.newMapSizeMedium, l10n.newMapSizeMediumNote),
      (192, l10n.newMapSizeLarge, l10n.newMapSizeLargeNote),
      (256, l10n.newMapSizeHuge, l10n.newMapSizeHugeNote),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('new-map-title'),
          controller: _title,
          enabled: !_creating,
          decoration: InputDecoration(labelText: l10n.newMapName),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          enabled: !_creating,
          decoration: InputDecoration(labelText: l10n.newMapDescription),
        ),
        const SizedBox(height: 20),
        _SectionTitle(l10n.newMapSize),
        const SizedBox(height: 8),
        GridView(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisExtent: 90,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final (size, label, note) in presets)
              _ChoiceCard(
                key: Key('new-map-size-$size'),
                selected: !_customSize && _width == size && _height == size,
                onTap: () => _selectPreset(size),
                title: label,
                subtitle: l10n.newMapSizeValue(size, size),
                caption: note,
              ),
            _ChoiceCard(
              key: const Key('new-map-size-custom'),
              selected: _customSize || _width != _height,
              onTap: () => setState(() => _customSize = true),
              title: l10n.newMapSizeCustom,
              subtitle: '…',
              caption: l10n.newMapSizeCustomNote,
            ),
          ],
        ),
        if (_customSize || _width != _height) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _dimension(l10n.newMapWidth, _width, (v) => _width = v),
              const SizedBox(width: 12),
              _dimension(l10n.newMapHeight, _height, (v) => _height = v),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _SectionTitle(l10n.newMapTileset, hint: l10n.newMapTilesetHint),
        const SizedBox(height: 8),
        GridView(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 64,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final tileset in StarCraftTilesetAssetSet.values)
              _TilesetCard(
                key: Key('new-map-tileset-${tileset.fileStem}'),
                name: _tilesetName(l10n, tileset),
                colors: _tilesetColors(tileset),
                selected: tileset == _tileset,
                onTap: () => _selectTileset(tileset),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.controller.terrainGateway != null)
          SegmentedButton<bool>(
            key: const Key('new-map-terrain-mode'),
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.landscape_outlined),
                label: Text(l10n.terrainModeNatural),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.grid_on),
                label: Text(l10n.terrainModeTile),
              ),
            ],
            selected: {_terrainMode},
            onSelectionChanged: _creating
                ? null
                : (v) {
                    setState(() => _terrainMode = v.single);
                    _load();
                  },
          ),
        const SizedBox(height: 8),
        _SectionTitle(
          _terrainMode ? l10n.isomTerrainType : l10n.newMapInitialTile,
        ),
        const SizedBox(height: 8),
        if (_loading)
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.newMapTilesLoading)),
            ],
          ),
        if (_terrain case final terrain?)
          SizedBox(
            height: 220,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisExtent: 92,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: terrain.shapes.length,
              itemBuilder: (context, index) {
                final type = terrain.shapes.keys.elementAt(index);
                return InkWell(
                  key: Key('new-map-terrain-$type'),
                  onTap: _creating
                      ? null
                      : () => setState(() => _terrainType = type),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _terrainType == type
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF454A50),
                        width: _terrainType == type ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.controller.terrainPreviews[type]
                            case final pixels?)
                          CatalogThumbnail(
                            rgbaBytes: pixels,
                            width: 32,
                            height: 32,
                          ),
                        Text(
                          l10n.isomTerrainId(type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (batch != null)
          SizedBox(
            height: 176,
            child: GridView.count(
              crossAxisCount: 10,
              children: [
                for (final entry in batch.page.entries)
                  Tooltip(
                    message: entry.displayName,
                    child: InkWell(
                      key: ValueKey('new-map-tile-${entry.key.id}'),
                      borderRadius: BorderRadius.circular(6),
                      onTap:
                          !_creating &&
                              entry.isPlaceable &&
                              batch.thumbnails.containsKey(entry.key.id)
                          ? () => setState(() => _tile = entry.key.id)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _tile == entry.key.id
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF2F343B),
                            width: _tile == entry.key.id ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (batch.thumbnails[entry.key.id]
                                case final pixels?)
                              CatalogThumbnail(
                                rgbaBytes: pixels,
                                width: 32,
                                height: 32,
                              ),
                            Text(
                              '#${entry.key.id}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton(
              onPressed: !_loading && !_creating && _offset > 0
                  ? () {
                      _offset -= 64;
                      _load();
                    }
                  : null,
              child: Text(l10n.newMapPrevious),
            ),
            if (batch != null && batch.page.entries.isNotEmpty)
              Text(
                l10n.newMapTilePage(
                  _offset + 1,
                  _offset + batch.page.entries.length,
                  batch.page.totalEntries,
                ),
              ),
            TextButton(
              onPressed:
                  !_loading &&
                      !_creating &&
                      batch != null &&
                      _offset + 64 < batch.page.totalEntries
                  ? () {
                      _offset += 64;
                      _load();
                    }
                  : null,
              child: Text(l10n.newMapNext),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: !_loading && !_creating ? _load : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.newMapReload),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dimension(String label, int value, ValueChanged<int> change) =>
      Expanded(
        child: DropdownButtonFormField<int>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final v in _sizeValues)
              DropdownMenuItem(value: v, child: Text('$v')),
          ],
          onChanged: _creating ? null : (v) => setState(() => change(v!)),
        ),
      );

  Widget _playersStep(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.newMapPlayersTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.newMapPlayersHint,
          style: const TextStyle(color: Color(0xFFA7AFB8), height: 1.5),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var count = 1; count <= 8; count++)
              SizedBox(
                width: 96,
                height: 72,
                child: _ChoiceCard(
                  key: Key('new-map-players-$count'),
                  selected: _players == count,
                  onTap: _creating
                      ? null
                      : () => setState(() => _players = count),
                  title: '$count',
                  subtitle: l10n.newMapPlayersValue(count),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _review(BuildContext context) {
    final l10n = context.l10n;
    final rows = [
      (l10n.newMapName, _title!.text),
      (l10n.newMapSize, l10n.newMapSizeValue(_width, _height)),
      (l10n.newMapTileset, _tilesetName(l10n, _tileset)),
      (
        l10n.newMapInitialTile,
        _terrainMode && _terrainType != null
            ? l10n.isomTerrainId(_terrainType!)
            : _tile == null
            ? l10n.newMapReviewNoTile
            : l10n.newMapReviewTile('$_tile'),
      ),
      (l10n.newMapStepPlayers, l10n.newMapPlayersValue(_players)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.newMapReviewTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    label,
                    style: const TextStyle(color: Color(0xFFA7AFB8)),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _Notice(
          icon: Icons.description_outlined,
          text: l10n.newMapReviewFormat,
        ),
        _Notice(
          icon: Icons.info_outline_rounded,
          text: l10n.newMapInitialTileHint,
        ),
        _Notice(
          icon: Icons.account_tree_outlined,
          text: l10n.newMapReviewNoTriggers,
        ),
        if (_tile == null)
          _Notice(
            icon: Icons.warning_amber_rounded,
            text: l10n.newMapTileRequired,
            warning: true,
          ),
      ],
    );
  }
}

String _tilesetName(AppLocalizations l10n, StarCraftTilesetAssetSet tileset) =>
    switch (tileset) {
      StarCraftTilesetAssetSet.badlands => l10n.tilesetBadlands,
      StarCraftTilesetAssetSet.spacePlatform => l10n.tilesetSpacePlatform,
      StarCraftTilesetAssetSet.installation => l10n.tilesetInstallation,
      StarCraftTilesetAssetSet.ashworld => l10n.tilesetAshworld,
      StarCraftTilesetAssetSet.jungle => l10n.tilesetJungle,
      StarCraftTilesetAssetSet.desert => l10n.tilesetDesert,
      StarCraftTilesetAssetSet.ice => l10n.tilesetIce,
      StarCraftTilesetAssetSet.twilight => l10n.tilesetTwilight,
    };

/// Representative swatches only; the real tiles come from local game data.
List<Color> _tilesetColors(StarCraftTilesetAssetSet tileset) =>
    switch (tileset) {
      StarCraftTilesetAssetSet.badlands => const [
        Color(0xFF4A3E2D),
        Color(0xFF675742),
        Color(0xFF3D3326),
      ],
      StarCraftTilesetAssetSet.spacePlatform => const [
        Color(0xFF2A2F3A),
        Color(0xFF4A5160),
        Color(0xFF1A1D24),
      ],
      StarCraftTilesetAssetSet.installation => const [
        Color(0xFF3B3F45),
        Color(0xFF5B6068),
        Color(0xFF2A2C30),
      ],
      StarCraftTilesetAssetSet.ashworld => const [
        Color(0xFF4A2F2A),
        Color(0xFF6B3F33),
        Color(0xFF2A1A17),
      ],
      StarCraftTilesetAssetSet.jungle => const [
        Color(0xFF2F4A2D),
        Color(0xFF4A6B3A),
        Color(0xFF1F331D),
      ],
      StarCraftTilesetAssetSet.desert => const [
        Color(0xFF6B5A3A),
        Color(0xFF8A7650),
        Color(0xFF4A3D27),
      ],
      StarCraftTilesetAssetSet.ice => const [
        Color(0xFFB8C6D0),
        Color(0xFF8FA3B0),
        Color(0xFFE6EEF2),
      ],
      StarCraftTilesetAssetSet.twilight => const [
        Color(0xFF3A2F4A),
        Color(0xFF5A4A6B),
        Color(0xFF231D2E),
      ],
    };

class _StepList extends StatelessWidget {
  const _StepList({required this.current, required this.onSelected});

  final _NewMapStep current;
  final ValueChanged<_NewMapStep>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      _NewMapStep.basics: l10n.newMapStepBasics,
      _NewMapStep.players: l10n.newMapStepPlayers,
      _NewMapStep.review: l10n.newMapStepReview,
    };
    return Container(
      width: 230,
      color: const Color(0xFF16191D),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: Text(
              l10n.newMapTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          for (final step in _NewMapStep.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: step == current
                    ? const Color(0xFF23343A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                child: InkWell(
                  key: Key('new-map-step-${step.name}'),
                  borderRadius: BorderRadius.circular(9),
                  onTap: onSelected == null ? null : () => onSelected!(step),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: step == current
                              ? const Color(0xFF56C2D6)
                              : Colors.transparent,
                          foregroundColor: step == current
                              ? const Color(0xFF0B1A1E)
                              : const Color(0xFFA7AFB8),
                          child: Text(
                            '${step.index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labels[step]!,
                                style: TextStyle(
                                  fontWeight: step == current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              if (step == current)
                                Text(
                                  l10n.newMapStepCurrent,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8FB9C2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121417),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262A30)),
            ),
            child: Text(
              l10n.newMapSideNote,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFA7AFB8),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        children: [
          if (hint != null)
            TextSpan(
              text: ' · $hint',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                color: Color(0xFF8B939C),
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.caption,
    super.key,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFF1E2A2E) : const Color(0xFF1B1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFF56C2D6) : const Color(0xFF2F343B),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA7AFB8),
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B939C),
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

class _TilesetCard extends StatelessWidget {
  const _TilesetCard({
    required this.name,
    required this.colors,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String name;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0xFF1E2A2E) : const Color(0xFF1B1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFF56C2D6) : const Color(0xFF2F343B),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 42,
                    height: 30,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final color in colors)
                          Expanded(child: ColoredBox(color: color)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.warning = false});

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFE3C267) : const Color(0xFF8DA2C2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFC9CFD6), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
