import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/placement/placement_catalog_controller.dart';
import '../placement/catalog_thumbnail.dart';
import 'default_unit_names.dart';

/// Weapon cells use a verified representative unit, not an invented icon.
class VisualSettingsPicker extends StatefulWidget {
  const VisualSettingsPicker({
    required this.ids,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.prefix,
    this.catalog,
    this.weapons = false,
    super.key,
  });
  final List<int> ids;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onSelected;
  final String prefix;
  final PlacementCatalogController? catalog;
  final bool weapons;
  @override
  State<VisualSettingsPicker> createState() => _VisualSettingsPickerState();
}

class _VisualSettingsPickerState extends State<VisualSettingsPicker> {
  final _previews = <int, Future<({PlacementCatalogItem? item, int? unit})>>{};
  Future<WeaponReferenceSnapshot>? _references;
  StreamSubscription<PlacementCatalogState>? _subscription;
  int? _epoch;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _subscription?.cancel();
    _epoch = widget.catalog?.weaponReferenceEpoch;
    _previews.clear();
    _references = null;
    _subscription = widget.catalog?.changes.listen((_) {
      if (_epoch != widget.catalog?.weaponReferenceEpoch && mounted) {
        setState(_bind);
      }
    });
  }

  @override
  void didUpdateWidget(VisualSettingsPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog ||
        oldWidget.weapons != widget.weapons) {
      _bind();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<({PlacementCatalogItem? item, int? unit})> _preview(int id) async {
    final catalog = widget.catalog;
    if (catalog == null) return (item: null, unit: null);
    try {
      int? unit = id;
      if (widget.weapons) {
        final references = await (_references ??= catalog
            .loadWeaponReferences());
        unit =
            references.index.subunitUsers(id).firstOrNull ??
            references.index.directUsers(id).firstOrNull;
      }
      return (
        item: unit == null ? null : await catalog.loadUnitGridPreview(unit),
        unit: unit,
      );
    } on Object {
      return (item: null, unit: null);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: Key('${widget.prefix}-visual-grid'),
    height: 224,
    child: GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 148,
        mainAxisExtent: 106,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: widget.ids.length,
      itemBuilder: (context, index) {
        final id = widget.ids[index];
        return FutureBuilder<({PlacementCatalogItem? item, int? unit})>(
          future: _previews.putIfAbsent(id, () => _preview(id)),
          builder: (context, snapshot) {
            final item = snapshot.data?.item;
            final label = widget.label(id);
            final representative = widget.weapons && snapshot.data?.unit != null
                ? '\n${defaultUnitNames[snapshot.data!.unit!]}'
                : '';
            return Tooltip(
              message: '$label$representative',
              child: InkWell(
                key: Key('${widget.prefix}-visual-$id'),
                onTap: () => widget.onSelected(id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: id == widget.selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: Border.all(
                      color: id == widget.selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Expanded(
                          child: item?.hasThumbnail == true
                              ? CatalogThumbnail(
                                  rgbaBytes: item!.thumbnailRgba!,
                                  width: item.thumbnailWidth,
                                  height: item.thumbnailHeight,
                                  scale: 2,
                                )
                              : Icon(
                                  widget.weapons
                                      ? Icons.gps_fixed
                                      : Icons.person_outline,
                                  size: 28,
                                ),
                        ),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
