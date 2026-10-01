import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/layers/map_layer_controller.dart';
import '../../application/layers/selection_navigation_controller.dart';
import '../localization/l10n.dart';
import '../settings/default_unit_names.dart';

String _layerLabel(BuildContext context, MapLayerType layer) {
  final l = context.l10n;
  return switch (layer) {
    MapLayerType.terrain => l.layerTerrain,
    MapLayerType.locations => l.layerLocations,
    MapLayerType.doodads => l.layerDoodads,
    MapLayerType.sprites => l.layerSprites,
    MapLayerType.units => l.layerUnits,
  };
}

String objectSearchLabel(MapObjectSearchEntry entry) {
  final id = entry.typeId;
  final unit =
      entry.object.layer == MapLayerType.units || entry.drawsAsSprite == false;
  final name =
      entry.name ??
      (unit && id != null && id >= 0 && id < defaultUnitNames.length
          ? defaultUnitNames[id]
          : entry.object.layer.label);
  return '$name (#$id) · ${entry.object.label}';
}

class SelectionNavigationDialog extends StatefulWidget {
  const SelectionNavigationDialog({
    required this.controller,
    required this.onNavigate,
    this.coordinateFocus = false,
    super.key,
  });
  final SelectionNavigationController controller;
  final ValueChanged<MapNavigationTarget> onNavigate;
  final bool coordinateFocus;
  @override
  State<SelectionNavigationDialog> createState() =>
      _SelectionNavigationDialogState();
}

class _SelectionNavigationDialogState extends State<SelectionNavigationDialog> {
  final _query = TextEditingController(),
      _x = TextEditingController(text: '0'),
      _y = TextEditingController(text: '0');
  MapLayerType? _layer;
  int? _owner;
  bool _selectable = true, _tiles = false;
  String? _error;
  StreamSubscription<Object?>? _mapChanges, _layerChanges;
  @override
  void initState() {
    super.initState();
    _mapChanges = widget.controller.maps.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _layerChanges = widget.controller.layers.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_mapChanges?.cancel());
    unawaited(_layerChanges?.cancel());
    _query.dispose();
    _x.dispose();
    _y.dispose();
    super.dispose();
  }

  void _run(bool Function() action) {
    try {
      if (!action()) throw StateError(context.l10n.selectionStale);
      setState(() => _error = null);
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  void _navigate(MapNavigationTarget? Function() action) {
    try {
      final target = action();
      if (target == null) throw StateError(context.l10n.selectionEmpty);
      widget.onNavigate(target);
      Navigator.of(context).pop();
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, c = widget.controller;
    final entries = c.search(
      query: _query.text,
      layer: _layer,
      owner: _owner,
      selectableOnly: _selectable,
      label: (e) =>
          '${_layerLabel(context, e.object.layer)} ${objectSearchLabel(e)}',
    );
    final selected = c.layers.state.selections.map((e) => e.object).toSet();
    return Dialog(
      child: SizedBox(
        width: 960,
        height: 660,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.selectionTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('selection-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: l.menuClose,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('selection-search'),
                controller: _query,
                autofocus: !widget.coordinateFocus,
                decoration: InputDecoration(
                  labelText: l.selectionSearch,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<MapLayerType?>(
                    key: const Key('selection-layer'),
                    value: _layer,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l.selectionAllLayers),
                      ),
                      for (final v in MapLayerType.values.where(
                        (v) => v != MapLayerType.terrain,
                      ))
                        DropdownMenuItem(
                          value: v,
                          child: Text(_layerLabel(context, v)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _layer = v),
                  ),
                  DropdownButton<int?>(
                    key: const Key('selection-owner'),
                    value: _owner,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l.selectionAllOwners),
                      ),
                      for (var i = 0; i < 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(l.basicPlayer(i + 1)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _owner = v),
                  ),
                  FilterChip(
                    label: Text(l.selectionSelectable),
                    selected: _selectable,
                    onSelected: (v) => setState(() => _selectable = v),
                  ),
                  Text(l.selectionCounts(entries.length, selected.length)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    key: const Key('selection-results'),
                    onPressed: entries.isEmpty
                        ? null
                        : () => _run(() => c.select(entries)),
                    child: Text(l.selectionResults),
                  ),
                  OutlinedButton(
                    onPressed: () => _run(c.selectAll),
                    child: Text(l.selectionAll),
                  ),
                  OutlinedButton(
                    onPressed: () => _run(c.invert),
                    child: Text(l.selectionInvert),
                  ),
                  OutlinedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => _run(() => c.selectRelated()),
                    child: Text(l.selectionSameType),
                  ),
                  OutlinedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => _run(() => c.selectRelated(byOwner: true)),
                    child: Text(l.selectionSameOwner),
                  ),
                  OutlinedButton(
                    onPressed: c.layers.clearSelection,
                    child: Text(l.selectionClear),
                  ),
                  OutlinedButton(
                    key: const Key('selection-focus'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => _navigate(c.focusSelection),
                    child: Text(l.selectionFocus),
                  ),
                  OutlinedButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => _navigate(() => c.focusSelection(fit: true)),
                    child: Text(l.selectionFit),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(),
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text(l.selectionNoResults))
                  : ListView.builder(
                      key: const Key('selection-list'),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i],
                            enabled = c.layers.state
                                .statusOf(entries[i].object.layer)
                                .isSelectable;
                        void toggle() => _run(() {
                          if (!identical(
                            e.document,
                            c.maps.state.session?.rawDocument,
                          )) {
                            return false;
                          }
                          return c.select([
                            for (final v in c.entries)
                              if ((selected.contains(v.object) &&
                                      v.object != e.object) ||
                                  (!selected.contains(e.object) &&
                                      v.object == e.object))
                                v,
                          ]);
                        });
                        return ListTile(
                          key: ValueKey(
                            'search-${e.object.layer.name}-${e.object.sectionIndex}-${e.object.recordIndex}',
                          ),
                          selected: selected.contains(e.object),
                          leading: Checkbox(
                            value: selected.contains(e.object),
                            onChanged: enabled ? (_) => toggle() : null,
                          ),
                          title: Text(objectSearchLabel(e)),
                          subtitle: Text(
                            '${e.x}, ${e.y}${e.owner == null ? '' : ' · ${l.basicPlayer(e.owner! + 1)}'}${enabled ? '' : ' · ${l.selectionUnavailable}'}',
                          ),
                          onTap: enabled ? toggle : null,
                          trailing: IconButton(
                            tooltip: l.selectionGoTo,
                            icon: const Icon(Icons.my_location),
                            onPressed: () => _navigate(() {
                              if (!identical(
                                e.document,
                                c.maps.state.session?.rawDocument,
                              )) {
                                throw StateError(l.selectionStale);
                              }
                              return c.goTo(e.x, e.y);
                            }),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (key, field) in [('x', _x), ('y', _y)])
                    SizedBox(
                      width: 90,
                      child: TextField(
                        key: ValueKey('selection-$key'),
                        controller: field,
                        autofocus: widget.coordinateFocus && key == 'x',
                        decoration: InputDecoration(
                          labelText: key.toUpperCase(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  FilterChip(
                    label: Text(l.selectionTileCoordinates),
                    selected: _tiles,
                    onSelected: (v) => setState(() => _tiles = v),
                  ),
                  FilledButton(
                    key: const Key('selection-goto'),
                    onPressed: () => _navigate(
                      () => c.goTo(
                        int.parse(_x.text.trim()),
                        int.parse(_y.text.trim()),
                        tiles: _tiles,
                      ),
                    ),
                    child: Text(l.selectionGoTo),
                  ),
                  OutlinedButton(
                    key: const Key('selection-fit-map'),
                    onPressed: () => _navigate(c.fitMap),
                    child: Text(l.selectionFitMap),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
