import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/placement/placement_catalog_controller.dart';
import '../../application/ports/starcraft_placement_catalog_gateway.dart';
import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../localization/l10n.dart';
import 'catalog_thumbnail.dart';

const _kinds = <StarCraftPlacementKind>[
  StarCraftPlacementKind.unit,
  StarCraftPlacementKind.doodad,
  StarCraftPlacementKind.pureSprite,
  StarCraftPlacementKind.tile,
];

/// Player colours used for owner buttons. The number is always shown as well,
/// so colour is never the only cue.
const _playerColors = <Color>[
  Color(0xFFD8434B),
  Color(0xFF3A6FE0),
  Color(0xFF2FB7A6),
  Color(0xFF9A5AD0),
  Color(0xFFE38A2F),
  Color(0xFF6B4A2E),
  Color(0xFFE9E9E9),
  Color(0xFFE8D34A),
  Color(0xFF8A8F96),
  Color(0xFF5A7F3A),
  Color(0xFF7E8FB0),
  Color(0xFF3AA6D0),
];

String _kindLabel(AppLocalizations l10n, StarCraftPlacementKind kind) =>
    switch (kind) {
      StarCraftPlacementKind.tile => l10n.catalogKindTile,
      StarCraftPlacementKind.doodad => l10n.catalogKindDoodad,
      StarCraftPlacementKind.unit => l10n.catalogKindUnit,
      StarCraftPlacementKind.pureSprite => l10n.catalogKindSprite,
      StarCraftPlacementKind.spriteUnit => l10n.catalogKindSpriteUnit,
    };

IconData _kindIcon(StarCraftPlacementKind kind) => switch (kind) {
  StarCraftPlacementKind.tile => Icons.grid_4x4_rounded,
  StarCraftPlacementKind.doodad => Icons.park_outlined,
  StarCraftPlacementKind.unit => Icons.adjust_rounded,
  StarCraftPlacementKind.pureSprite ||
  StarCraftPlacementKind.spriteUnit => Icons.auto_awesome_outlined,
};

String _tilesetLabel(AppLocalizations l10n, StarCraftTilesetAssetSet t) =>
    switch (t) {
      StarCraftTilesetAssetSet.badlands => l10n.tilesetBadlands,
      StarCraftTilesetAssetSet.spacePlatform => l10n.tilesetSpacePlatform,
      StarCraftTilesetAssetSet.installation => l10n.tilesetInstallation,
      StarCraftTilesetAssetSet.ashworld => l10n.tilesetAshworld,
      StarCraftTilesetAssetSet.jungle => l10n.tilesetJungle,
      StarCraftTilesetAssetSet.desert => l10n.tilesetDesert,
      StarCraftTilesetAssetSet.ice => l10n.tilesetIce,
      StarCraftTilesetAssetSet.twilight => l10n.tilesetTwilight,
    };

/// A plain-language reason for a locked entry. The stable code is still shown
/// underneath for bug reports.
String _issueText(AppLocalizations l10n, PlacementCatalogItem item) {
  final code = item.issueCode ?? '';
  if (code.endsWith('UNIT_RELATION_REQUIRED')) return l10n.catalogIssueRelation;
  if (code.endsWith('UNIT_CAPABILITY_UNAVAILABLE')) {
    return l10n.catalogIssueCapability;
  }
  if (code.endsWith('OBJECT_GRAPHIC_UNAVAILABLE')) {
    return l10n.catalogIssueGraphic;
  }
  if (code.endsWith('DOODAD_RECIPE_INVALID')) return l10n.catalogIssueRecipe;
  return item.issueMessage ?? l10n.catalogCannotPlace;
}

/// The placement catalog as a workspace tab.
///
/// The pane fills the workspace next to the map tab instead of covering it, so
/// the catalog stays open while the user works. Browsing never changes the open
/// map: only `Place` confirms a selection, and the canvas applies it afterwards.
class PlacementCatalogPane extends StatefulWidget {
  const PlacementCatalogPane({
    required this.controller,
    this.onPlacementConfirmed,
    this.onClose,
    super.key,
  });

  final PlacementCatalogController controller;

  /// Called after an entry is confirmed, so the shell can show the map tab
  /// where the placement is applied.
  final VoidCallback? onPlacementConfirmed;

  /// Called when the user leaves the catalog without confirming anything.
  final VoidCallback? onClose;

  @override
  State<PlacementCatalogPane> createState() => _PlacementCatalogPaneState();
}

class _PlacementCatalogPaneState extends State<PlacementCatalogPane> {
  late StreamSubscription<PlacementCatalogState> _subscription;
  final TextEditingController _search = TextEditingController();
  String? _category;
  bool _placeableOnly = false;

  @override
  void initState() {
    super.initState();
    _search.text = widget.controller.state.query;
    _subscription = widget.controller.changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // Reopening the tab keeps the page that is already loaded instead of
    // asking the helper for it again. The controller notifies synchronously,
    // so the first load waits for the frame that builds this pane.
    if (widget.controller.state.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.state.items.isEmpty) {
          unawaited(widget.controller.load(widget.controller.state.kind));
        }
      });
    }
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
    // A Material ancestor is required so the lists and grid can paint their
    // selection and ink effects.
    return Material(
      key: const Key('placement-catalog-pane'),
      color: const Color(0xFF101319),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: narrow ? 176 : 220, child: _kindList(state)),
              const VerticalDivider(width: 1),
              Expanded(child: _browser(state)),
              const VerticalDivider(width: 1),
              SizedBox(width: narrow ? 250 : 320, child: _detail(state)),
            ],
          );
        },
      ),
    );
  }

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
    return state.visibleItems
        .where(
          (item) =>
              (category == null ||
                  (item.entry.categoryPath.isNotEmpty &&
                      item.entry.categoryPath.first == category)) &&
              (!_placeableOnly || item.isPlaceable),
        )
        .toList(growable: false);
  }

  Widget _kindList(PlacementCatalogState state) {
    final l10n = context.l10n;
    final categories = _categories(state);
    final tileset = state.tileset;
    return Material(
      color: const Color(0xFF1B1E22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              l10n.catalogTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('placement-catalog-kinds'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final kind in _kinds) ...[
                  _NavTile(
                    key: Key('placement-catalog-tab-${kind.wireName}'),
                    icon: _kindIcon(kind),
                    label: _kindLabel(l10n, kind),
                    selected: state.kind == kind,
                    onTap: state.kind == kind
                        ? null
                        : () {
                            setState(() => _category = null);
                            unawaited(widget.controller.load(kind));
                          },
                  ),
                  if (state.kind == kind && categories.isNotEmpty) ...[
                    _NavTile(
                      key: const Key('placement-catalog-category-all'),
                      label: l10n.catalogCategoryAll,
                      indent: 26,
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final category in categories)
                      _NavTile(
                        key: Key('placement-catalog-category-$category'),
                        label: category,
                        indent: 26,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                  ],
                ],
              ],
            ),
          ),
          if (tileset != null)
            Container(
              key: const Key('placement-catalog-tileset'),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121417),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF262A30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.catalogTilesetTitle(
                            _tilesetLabel(l10n, tileset),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.catalogTilesetHint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA7AFB8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _browser(PlacementCatalogState state) {
    final l10n = context.l10n;
    final items = _filtered(state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('placement-catalog-search'),
                  controller: _search,
                  onChanged: widget.controller.setQuery,
                  decoration: InputDecoration(
                    hintText: l10n.catalogSearchHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: OutlinedButton.icon(
                  key: const Key('placement-catalog-close'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(
                    l10n.catalogBackToMap,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const Key('placement-catalog-placeable-only'),
                label: Text(l10n.catalogPlaceableOnly),
                selected: _placeableOnly,
                onSelected: (value) => setState(() => _placeableOnly = value),
              ),
              if (state.diagnostics.isEmpty && state.items.isNotEmpty)
                Text(
                  l10n.catalogShownCount(items.length),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA7AFB8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _grid(state, items)),
        ],
      ),
    );
  }

  Widget _grid(PlacementCatalogState state, List<PlacementCatalogItem> items) {
    if (state.diagnostics.isNotEmpty) {
      return _message(
        key: const Key('placement-catalog-blocked'),
        text: state.diagnostics.first.message,
        icon: Icons.warning_amber_rounded,
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
    if (items.isEmpty) {
      return _message(
        key: const Key('placement-catalog-empty'),
        text: context.l10n.catalogEmpty,
        icon: Icons.search_off_rounded,
      );
    }
    return GridView.builder(
      key: const Key('placement-catalog-grid'),
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
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
    if (item.key.kind == StarCraftPlacementKind.tile) {
      widget.controller.requestThumbnail(item.key);
    }
    final isPreviewed = state.previewKey == item.key;
    return Tooltip(
      message: item.isPlaceable
          ? item.displayName
          : '${item.displayName}\n${_issueText(context.l10n, item)}',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: isPreviewed ? const Color(0xFF1E2A2E) : const Color(0xFF1B1E22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isPreviewed
                ? const Color(0xFF56C2D6)
                : const Color(0xFF2C3137),
            width: 1.5,
          ),
        ),
        child: InkWell(
          key: Key('placement-catalog-item-${item.key.stableId}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.controller.preview(item.key),
          onDoubleTap: item.isPlaceable ? () => _confirm(item) : null,
          child: Opacity(
            opacity: item.isPlaceable ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF121417),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: item.hasThumbnail
                                  ? CatalogThumbnail(
                                      rgbaBytes: item.thumbnailRgba!,
                                      width: item.thumbnailWidth,
                                      height: item.thumbnailHeight,
                                    )
                                  : Icon(
                                      _kindIcon(item.key.kind),
                                      size: 22,
                                      color: const Color(0xFF6B737D),
                                    ),
                            ),
                          ),
                        ),
                        if (!item.isPlaceable)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: Color(0xFFA7AFB8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '#${item.key.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B939C),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(PlacementCatalogState state) {
    final l10n = context.l10n;
    final item = state.previewItem;
    if (item?.key.kind == StarCraftPlacementKind.tile) {
      widget.controller.requestThumbnail(item!.key);
    }
    return Material(
      color: const Color(0xFF1B1E22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: item == null
                ? _message(
                    key: const Key('placement-catalog-detail-empty'),
                    text: l10n.catalogDetailEmpty,
                    icon: Icons.touch_app_outlined,
                  )
                : ListView(
                    key: const Key('placement-catalog-detail'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF121417),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2C3137)),
                        ),
                        child: Center(
                          child: item.hasThumbnail
                              ? CatalogThumbnail(
                                  rgbaBytes: item.thumbnailRgba!,
                                  width: item.thumbnailWidth,
                                  height: item.thumbnailHeight,
                                  scale: 2,
                                )
                              : const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_kindLabel(l10n, item.key.kind)} · #${item.key.id}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA7AFB8),
                        ),
                      ),
                      if (item.entry.doodadRecipe case final recipe?) ...[
                        const SizedBox(height: 4),
                        Text(
                          recipe.overlay == null
                              ? l10n.catalogFootprint(
                                  recipe.width,
                                  recipe.height,
                                )
                              : l10n.catalogFootprintOverlay(
                                  recipe.width,
                                  recipe.height,
                                ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFA7AFB8),
                          ),
                        ),
                      ],
                      if (!item.isPlaceable) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('placement-catalog-detail-issue'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1C16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF3D3622)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: Color(0xFFE3C267),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _issueText(l10n, item),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                    if (item.issueCode case final code?)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          l10n.catalogIssueCode(code),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF8B939C),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        l10n.catalogOwner,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA7AFB8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _OwnerPicker(
                        owner: state.owner,
                        onChanged: widget.controller.setOwner,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        key: const Key('placement-catalog-continuous'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: state.isContinuous,
                        title: Text(
                          l10n.catalogKeepPlacing,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onChanged: widget.controller.setContinuous,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121417),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF262A30)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.catalogHowTo,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final step in [
                              l10n.catalogHowTo1,
                              l10n.catalogHowTo2,
                              l10n.catalogHowTo3,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  step,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFA7AFB8),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                key: const Key('placement-catalog-place'),
                onPressed: item != null && item.isPlaceable
                    ? () => _confirm(item)
                    : null,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(l10n.catalogPlace),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirming only arms the placement: the canvas applies it on the next
  /// click, so the tab hands control back to the map view.
  void _confirm(PlacementCatalogItem item) {
    if (widget.controller.confirm(item.key)) {
      widget.onPlacementConfirmed?.call();
    }
  }

  Widget _message({
    required Key key,
    required String text,
    required IconData icon,
  }) => Center(
    key: key,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: const Color(0xFF6B737D)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFFA7AFB8)),
          ),
        ],
      ),
    ),
  );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.indent = 0,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? const Color(0xFF23343A) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10 + indent, 9, 10, 9),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? const Color(0xFF56C2D6)
                        : const Color(0xFF8B939C),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? const Color(0xFFCFEEF4)
                          : const Color(0xFFDFE3E8),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
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

class _OwnerPicker extends StatelessWidget {
  const _OwnerPicker({required this.owner, required this.onChanged});

  final int owner;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      key: const Key('placement-catalog-owner'),
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var player = 0; player < 12; player++)
          Tooltip(
            message: l10n.catalogOwnerPlayer(player + 1),
            child: Semantics(
              button: true,
              selected: owner == player,
              label: l10n.catalogOwnerPlayer(player + 1),
              child: InkWell(
                key: Key('placement-catalog-owner-$player'),
                onTap: () => onChanged(player),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 36,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _playerColors[player],
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: owner == player
                          ? const Color(0xFFFFFFFF)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${player + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _playerColors[player].computeLuminance() > 0.45
                          ? const Color(0xFF121417)
                          : const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
