import 'package:flutter/material.dart';
import '../../application/documents/new_map_controller.dart';
import '../../application/terrain/tile_placement_catalog_loader.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/chk/new_map_factory.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../placement/catalog_thumbnail.dart';

class NewMapDialog extends StatefulWidget {
  const NewMapDialog({required this.controller, super.key});
  final NewMapController controller;
  @override
  State<NewMapDialog> createState() => _NewMapDialogState();
}

class _NewMapDialogState extends State<NewMapDialog> {
  final _title = TextEditingController(text: 'Untitled Scenario');
  final _description = TextEditingController();
  int _width = 128, _height = 128, _players = 1, _offset = 0, _revision = 0;
  int? _tile;
  var _tileset = StarCraftTilesetAssetSet.badlands;
  TilePlacementCatalogBatch? _batch;
  bool _loading = true, _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _tile = null;
      _batch = null;
      _error = null;
    });
    try {
      final batch = await widget.controller.loadTiles(
        _tileset,
        offset: _offset,
      );
      if (mounted && revision == _revision) setState(() => _batch = batch);
    } catch (e) {
      if (mounted && revision == _revision) setState(() => _error = '$e');
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final options = NewMapOptions(
        width: _width,
        height: _height,
        humanPlayers: _players,
        tileset: ChkTileset.values.firstWhere(
          (v) => v.rawValue == _tileset.rawValue,
        ),
        rawTileValue: _tile!,
        title: _title.text,
        description: _description.text,
      );
      if (widget.controller.expectedSession?.isDirty ?? false) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved map changes?'),
            content: const Text(
              'Creating a new map replaces the current document. Save it first if you want to keep these changes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current map'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard and create'),
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

  Widget _number(
    String label,
    int value,
    Iterable<int> values,
    ValueChanged<int> change,
  ) => Expanded(
    child: DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final v in values) DropdownMenuItem(value: v, child: Text('$v')),
      ],
      onChanged: _creating ? null : (v) => setState(() => change(v!)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    return AlertDialog(
      title: const Text('New Map'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                enabled: !_creating,
                decoration: const InputDecoration(labelText: 'Map title'),
              ),
              TextField(
                controller: _description,
                enabled: !_creating,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              Row(
                children: [
                  _number(
                    'Width (tiles)',
                    _width,
                    List.generate(8, (i) => (i + 1) * 32),
                    (v) => _width = v,
                  ),
                  const SizedBox(width: 12),
                  _number(
                    'Height (tiles)',
                    _height,
                    List.generate(8, (i) => (i + 1) * 32),
                    (v) => _height = v,
                  ),
                  const SizedBox(width: 12),
                  _number(
                    'Human players',
                    _players,
                    List.generate(8, (i) => i + 1),
                    (v) => _players = v,
                  ),
                ],
              ),
              DropdownButtonFormField<StarCraftTilesetAssetSet>(
                initialValue: _tileset,
                decoration: const InputDecoration(labelText: 'Tileset'),
                items: [
                  for (final t in StarCraftTilesetAssetSet.values)
                    DropdownMenuItem(value: t, child: Text(t.displayName)),
                ],
                onChanged: _creating
                    ? null
                    : (v) {
                        setState(() {
                          _tileset = v!;
                          _offset = 0;
                        });
                        _load();
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'Select the initial raw tile. ISOM terrain is not generated; walkability is not guaranteed.',
              ),
              if (_loading) const LinearProgressIndicator(),
              if (batch != null)
                SizedBox(
                  height: 220,
                  child: GridView.count(
                    crossAxisCount: 8,
                    children: [
                      for (final entry in batch.page.entries)
                        Tooltip(
                          message: entry.displayName,
                          child: InkWell(
                            key: ValueKey('new-map-tile-${entry.key.id}'),
                            onTap:
                                !_creating &&
                                    entry.isPlaceable &&
                                    batch.thumbnails.containsKey(entry.key.id)
                                ? () => setState(() => _tile = entry.key.id)
                                : null,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _tile == entry.key.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
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
                    child: const Text('Previous'),
                  ),
                  Text(
                    batch == null
                        ? ''
                        : '${_offset + 1}–${_offset + batch.page.entries.length} / ${batch.page.totalEntries}',
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
                    child: const Text('Next'),
                  ),
                  TextButton(
                    onPressed: !_loading && !_creating ? _load : null,
                    child: const Text('Reload tiles'),
                  ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const Text(
                'Brood War UMS (.scx). Players start as Terran with start locations. No victory or resource triggers are added.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('create-new-map'),
          onPressed: !_loading && !_creating && _tile != null ? _create : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
