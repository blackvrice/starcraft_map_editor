import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../application/ports/starcraft_placement_catalog_gateway.dart';

const _kinds = <StarCraftPlacementKind>[
  StarCraftPlacementKind.tile,
  StarCraftPlacementKind.doodad,
  StarCraftPlacementKind.unit,
  StarCraftPlacementKind.pureSprite,
];

String _tabLabel(StarCraftPlacementKind kind) => switch (kind) {
  StarCraftPlacementKind.tile => 'Tiles',
  StarCraftPlacementKind.doodad => 'Doodads',
  StarCraftPlacementKind.unit => 'Units',
  StarCraftPlacementKind.pureSprite => 'Sprites',
  StarCraftPlacementKind.spriteUnit => 'Sprite-units',
};

/// Opens the placement catalog and returns true when the user confirmed a
/// placement selection.
Future<bool> showPlacementCatalogDialog({
  required BuildContext context,
  required PlacementCatalogController controller,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => PlacementCatalogDialog(controller: controller),
  );
  return confirmed ?? false;
}

/// A resizable catalog browser with one tab per placement kind.
///
/// Browsing never changes the open map: only the explicit `Place` action
/// confirms a selection, and the canvas applies it afterwards.
class PlacementCatalogDialog extends StatefulWidget {
  const PlacementCatalogDialog({required this.controller, super.key});

  final PlacementCatalogController controller;

  @override
  State<PlacementCatalogDialog> createState() => _PlacementCatalogDialogState();
}

class _PlacementCatalogDialogState extends State<PlacementCatalogDialog> {
  late StreamSubscription<PlacementCatalogState> _subscription;
  final TextEditingController _search = TextEditingController();
  Size? _size;
  String? _category;

  @override
  void initState() {
    super.initState();
    _search.text = widget.controller.state.query;
    _subscription = widget.controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(widget.controller.load(widget.controller.state.kind));
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final media = MediaQuery.of(context).size;
    final size =
        _size ??
        Size(
          media.width.clamp(_minimumWidth, 1100.0),
          media.height.clamp(_minimumHeight, 720.0),
        );
    return Dialog(
      key: const Key('placement-catalog-dialog'),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(state),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 150, child: _kindList(state)),
                      const VerticalDivider(width: 1),
                      Expanded(child: _grid(state)),
                      const VerticalDivider(width: 1),
                      SizedBox(width: 230, child: _detail(state)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _footer(state),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  key: const Key('placement-catalog-resize'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    _size = Size(
                      (size.width + details.delta.dx).clamp(
                        _minimumWidth,
                        media.width,
                      ),
                      (size.height + details.delta.dy).clamp(
                        _minimumHeight,
                        media.height,
                      ),
                    );
                  }),
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: Icon(Icons.drag_handle_rounded, size: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _minimumWidth = 480.0;
  static const _minimumHeight = 360.0;

  /// Verified category paths the current page exposes. The catalog only fills
  /// these when the local data supplies a validated classification, so the
  /// filter appears with the data instead of inventing groups.
  List<String> _categories(PlacementCatalogState state) {
    final categories = <String>{
      for (final item in state.items)
        if (item.entry.categoryPath.isNotEmpty) item.entry.categoryPath.first,
    };
    return categories.toList()..sort();
  }

  List<PlacementCatalogItem> _filtered(PlacementCatalogState state) {
    final category = _category;
    if (category == null) {
      return state.visibleItems;
    }
    return state.visibleItems
        .where(
          (item) =>
              item.entry.categoryPath.isNotEmpty &&
              item.entry.categoryPath.first == category,
        )
        .toList(growable: false);
  }

  Widget _header(PlacementCatalogState state) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Row(
      children: [
        const Icon(Icons.grid_view_rounded, size: 18),
        const SizedBox(width: 8),
        const Text(
          'Place from catalog',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (state.tileset != null) ...[
          const SizedBox(width: 10),
          Chip(
            key: const Key('placement-catalog-tileset'),
            visualDensity: VisualDensity.compact,
            label: Text(
              state.tileset!.displayName,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
        const Spacer(),
        SizedBox(
          width: 220,
          height: 34,
          child: TextField(
            key: const Key('placement-catalog-search'),
            controller: _search,
            onChanged: widget.controller.setQuery,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'Search name or #id',
              prefixIcon: Icon(Icons.search_rounded, size: 16),
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _kindList(PlacementCatalogState state) {
    final categories = _categories(state);
    return ListView(
      key: const Key('placement-catalog-kinds'),
      children: [
        for (final kind in _kinds)
          ListTile(
            key: Key('placement-catalog-tab-${kind.wireName}'),
            dense: true,
            selected: state.kind == kind,
            title: Text(_tabLabel(kind), style: const TextStyle(fontSize: 11)),
            onTap: state.kind == kind
                ? null
                : () {
                    setState(() => _category = null);
                    unawaited(widget.controller.load(kind));
                  },
          ),
        if (categories.isNotEmpty) ...[
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Text(
              'Categories',
              style: TextStyle(fontSize: 9, color: Color(0xFF7F8BA0)),
            ),
          ),
          ListTile(
            key: const Key('placement-catalog-category-all'),
            dense: true,
            selected: _category == null,
            title: const Text('All', style: TextStyle(fontSize: 10)),
            onTap: () => setState(() => _category = null),
          ),
          for (final category in categories)
            ListTile(
              key: Key('placement-catalog-category-$category'),
              dense: true,
              selected: _category == category,
              title: Text(category, style: const TextStyle(fontSize: 10)),
              onTap: () => setState(() => _category = category),
            ),
        ],
      ],
    );
  }

  Widget _grid(PlacementCatalogState state) {
    if (state.diagnostics.isNotEmpty) {
      return _message(
        key: const Key('placement-catalog-blocked'),
        text: state.diagnostics.first.message,
      );
    }
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        key: Key('placement-catalog-loading'),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final items = _filtered(state);
    if (items.isEmpty) {
      return _message(
        key: const Key('placement-catalog-empty'),
        text: 'No catalog entry matches this search.',
      );
    }
    return GridView.builder(
      key: const Key('placement-catalog-grid'),
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (index == items.length - 1 && state.hasMore && !state.isLoading) {
          // The controller notifies synchronously, so the next page must be
          // requested after this frame instead of during the grid build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(widget.controller.loadMore());
            }
          });
        }
        return _tile(state, items[index]);
      },
    );
  }

  Widget _tile(PlacementCatalogState state, PlacementCatalogItem item) {
    final isPreviewed = state.previewKey == item.key;
    return InkWell(
      key: Key('placement-catalog-item-${item.key.stableId}'),
      onTap: () => widget.controller.preview(item.key),
      onDoubleTap: item.isPlaceable ? () => _confirm(item) : null,
      child: Opacity(
        opacity: item.isPlaceable ? 1 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isPreviewed
                  ? const Color(0xFF8DB4FF)
                  : const Color(0xFF2A3446),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: item.hasThumbnail
                      ? _RgbaThumbnail(
                          rgbaBytes: item.thumbnailRgba!,
                          width: item.thumbnailWidth,
                          height: item.thumbnailHeight,
                        )
                      : Text(
                          '#${item.key.id}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF7F8BA0),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(PlacementCatalogState state) {
    final item = state.previewItem;
    if (item == null) {
      return _message(
        key: const Key('placement-catalog-detail-empty'),
        text: 'Select an entry to see its details.',
      );
    }
    return ListView(
      key: const Key('placement-catalog-detail'),
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 96,
          child: Center(
            child: item.hasThumbnail
                ? _RgbaThumbnail(
                    rgbaBytes: item.thumbnailRgba!,
                    width: item.thumbnailWidth,
                    height: item.thumbnailHeight,
                    scale: 2,
                  )
                : const Icon(Icons.image_not_supported_outlined, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.displayName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${item.key.kind.fallbackLabel} #${item.key.id}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF7F8BA0)),
        ),
        if (item.entry.doodadRecipe case final recipe?) ...[
          const SizedBox(height: 4),
          Text(
            'Footprint ${recipe.width} × ${recipe.height} tiles'
            '${recipe.overlay == null ? '' : ' + overlay'}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF7F8BA0)),
          ),
        ],
        if (!item.isPlaceable) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('placement-catalog-detail-issue'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A2A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${item.issueMessage ?? 'This entry cannot be placed.'}\n'
              '${item.issueCode ?? ''}',
              style: const TextStyle(fontSize: 9, color: Color(0xFFFFC2C2)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer(PlacementCatalogState state) {
    final item = state.previewItem;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          const Text('Owner', style: TextStyle(fontSize: 10)),
          const SizedBox(width: 6),
          DropdownButton<int>(
            key: const Key('placement-catalog-owner'),
            value: state.owner,
            isDense: true,
            style: const TextStyle(fontSize: 11),
            items: [
              for (var player = 0; player < 12; player++)
                DropdownMenuItem(
                  value: player,
                  child: Text('Player ${player + 1}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                widget.controller.setOwner(value);
              }
            },
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                key: const Key('placement-catalog-continuous'),
                value: state.isContinuous,
                visualDensity: VisualDensity.compact,
                onChanged: (value) =>
                    widget.controller.setContinuous(value ?? false),
              ),
              const Text('Keep placing', style: TextStyle(fontSize: 10)),
            ],
          ),
          const Spacer(),
          TextButton(
            key: const Key('placement-catalog-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('placement-catalog-place'),
            onPressed: item != null && item.isPlaceable
                ? () => _confirm(item)
                : null,
            child: const Text('Place'),
          ),
        ],
      ),
    );
  }

  void _confirm(PlacementCatalogItem item) {
    if (widget.controller.confirm(item.key)) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _message({required Key key, required String text}) => Center(
    key: key,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: Color(0xFF7F8BA0)),
      ),
    ),
  );
}

/// Draws one catalog thumbnail from the raw RGBA bytes the loaders returned.
class _RgbaThumbnail extends StatefulWidget {
  const _RgbaThumbnail({
    required this.rgbaBytes,
    required this.width,
    required this.height,
    this.scale = 1,
  });

  final Uint8List rgbaBytes;
  final int width;
  final int height;
  final double scale;

  @override
  State<_RgbaThumbnail> createState() => _RgbaThumbnailState();
}

class _RgbaThumbnailState extends State<_RgbaThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    if (widget.rgbaBytes.length != widget.width * widget.height * 4) {
      return;
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(widget.rgbaBytes);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: widget.width,
        height: widget.height,
        rowBytes: widget.width * 4,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return SizedBox(
        width: widget.width * widget.scale,
        height: widget.height * widget.scale,
      );
    }
    return RawImage(
      image: image,
      width: widget.width * widget.scale,
      height: widget.height * widget.scale,
      filterQuality: FilterQuality.none,
    );
  }
}
