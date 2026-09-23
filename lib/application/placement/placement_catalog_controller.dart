import '../../domain/placement/unit_weapon_references.dart';
import 'catalog_thumbnail_pixels.dart';
import 'dart:async';
import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../domain/placement/unit_placement_capability.dart';
import '../documents/open_map_controller.dart';
import '../documents/opened_map_session.dart';
import '../editing/object_editing_controller.dart';
import '../editing/object_placement.dart';
import '../objects/object_placement_catalog_loader.dart';
import '../ports/starcraft_object_atlas_gateway.dart';
import '../ports/starcraft_placement_catalog_gateway.dart';
import '../ports/starcraft_tile_atlas_gateway.dart';
import '../terrain/terrain_editing_controller.dart';
import '../terrain/tile_placement_catalog_loader.dart';

/// Reasons the catalog cannot be browsed at all.
abstract final class PlacementCatalogDiagnosticCodes {
  static const installationMissing = 'PLACEMENT_CATALOG_INSTALLATION_MISSING';
  static const mapTilesetUnavailable =
      'PLACEMENT_CATALOG_MAP_TILESET_UNAVAILABLE';
  static const loadersUnavailable = 'PLACEMENT_CATALOG_LOADERS_UNAVAILABLE';
  static const noOpenMap = 'PLACEMENT_CATALOG_NO_OPEN_MAP';
  static const unsupportedSelection = 'PLACEMENT_CATALOG_UNSUPPORTED_SELECTION';
  static const inconsistentPage = 'PLACEMENT_CATALOG_INCONSISTENT_PAGE';
}

/// One catalog row with the thumbnail the loaders produced for it.
final class PlacementCatalogItem {
  PlacementCatalogItem({
    required this.entry,
    this.thumbnailRgba,
    this.thumbnailWidth = 0,
    this.thumbnailHeight = 0,
  });

  final StarCraftPlacementCatalogEntry entry;
  final Uint8List? thumbnailRgba;
  final int thumbnailWidth;
  final int thumbnailHeight;

  StarCraftPlacementCatalogKey get key => entry.key;

  String get displayName => entry.displayName;

  bool get isPlaceable => entry.isPlaceable;

  String? get issueCode => entry.issue?.code;

  String? get issueMessage => entry.issue?.message;

  bool get hasThumbnail =>
      thumbnailRgba != null && thumbnailWidth > 0 && thumbnailHeight > 0;

  bool matches(String normalizedQuery) {
    return _matchesTerms(normalizedQuery.split(_queryWhitespace));
  }

  static final _queryWhitespace = RegExp(r'\s+');

  // Entries are immutable, so every query can reuse this normalized text.
  late final String _searchable =
      '$displayName ${entry.key.kind.fallbackLabel} #${entry.key.id} '
              '${entry.categoryPath.join(' ')}'
          .toLowerCase();

  bool _matchesTerms(List<String> terms) =>
      terms.every((term) => term.isEmpty || _searchable.contains(term));
}

/// What the canvas will place on the next confirmed click.
final class PlacementSelection {
  PlacementSelection({
    required this.kind,
    required this.key,
    required this.displayName,
    this.doodadRecipe,
    this.unitCapability,
  });

  final StarCraftPlacementKind kind;
  final StarCraftPlacementCatalogKey key;
  final String displayName;
  final DoodadPlacementRecipe? doodadRecipe;
  final UnitPlacementCapability? unitCapability;

  /// A Tile selection becomes the terrain brush value instead of a canvas
  /// click target, so it never activates the object placement cursor.
  bool get usesCanvasClick => kind != StarCraftPlacementKind.tile;
}

final class PlacementCatalogState {
  PlacementCatalogState({
    this.kind = StarCraftPlacementKind.tile,
    Iterable<PlacementCatalogItem> items = const [],
    this.query = '',
    this.isLoading = false,
    this.totalEntries = 0,
    this.tileset,
    this.previewKey,
    this.selection,
    this.owner = 0,
    this.isContinuous = false,
    this.lastPlacementIssueCode,
    Iterable<EditorDiagnostic> diagnostics = const [],
    Iterable<StarCraftPlacementCatalogKey> recentKeys = const [],
  }) : items = List.unmodifiable(items),
       diagnostics = List.unmodifiable(diagnostics),
       recentKeys = List.unmodifiable(recentKeys);

  final StarCraftPlacementKind kind;
  final List<PlacementCatalogItem> items;
  final String query;
  final bool isLoading;
  final int totalEntries;
  final StarCraftTilesetAssetSet? tileset;
  final StarCraftPlacementCatalogKey? previewKey;
  final PlacementSelection? selection;
  final int owner;
  final bool isContinuous;
  final String? lastPlacementIssueCode;
  final List<EditorDiagnostic> diagnostics;
  final List<StarCraftPlacementCatalogKey> recentKeys;

  List<PlacementCatalogItem> get visibleItems => _visibleItems;

  // A state is an immutable snapshot. Rebuilds must not refilter the same page.
  late final List<PlacementCatalogItem> _visibleItems = _filterItems();

  List<PlacementCatalogItem> _filterItems() {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return items;
    final terms = normalized.split(PlacementCatalogItem._queryWhitespace);
    return List.unmodifiable(items.where((item) => item._matchesTerms(terms)));
  }

  PlacementCatalogItem? get previewItem =>
      items.where((item) => item.key == previewKey).firstOrNull;

  bool get hasMore =>
      items.length < totalEntries &&
      !diagnostics.any(
        (diagnostic) =>
            diagnostic.code == PlacementCatalogDiagnosticCodes.inconsistentPage,
      );

  bool get isPlacementActive => selection != null && selection!.usesCanvasClick;
}

/// Browses the local StarCraft catalog and turns a confirmed choice into a
/// placement the canvas can apply.
///
/// The controller never touches game files itself: it asks the catalog loaders
/// and routes a confirmed selection to the terrain or object editing
/// controller, so the placement rules and Undo history stay in one place.
class PlacementCatalogController {
  PlacementCatalogController({
    required this.openMapController,
    required this.objectEditingController,
    required this.terrainEditingController,
    this.catalogGateway,
    this.tileAtlasGateway,
    this.objectAtlasGateway,
    this.pageSize = StarCraftPlacementCatalogRequest.defaultLimit,
    this.recentLimit = 12,
  });

  static const maximumRecentPerKind = 12;

  final OpenMapController openMapController;
  final ObjectEditingController objectEditingController;
  final TerrainEditingController terrainEditingController;
  final StarCraftPlacementCatalogGateway? catalogGateway;
  final StarCraftTileAtlasGateway? tileAtlasGateway;
  final StarCraftObjectAtlasGateway? objectAtlasGateway;
  final int pageSize;
  final int recentLimit;

  final StreamController<PlacementCatalogState> _changes =
      StreamController<PlacementCatalogState>.broadcast(sync: true);
  final Map<StarCraftPlacementKind, List<StarCraftPlacementCatalogKey>>
  _recentKeys = {};

  PlacementCatalogState _state = PlacementCatalogState();
  int _requestSequence = 0;
  String? _installationPath;
  Object? _mapSnapshot;
  bool _disposed = false;
  int weaponReferenceEpoch = 0;
  int _weaponRequest = 0;
  String? _weaponOperation;

  PlacementCatalogState get state => _state;

  Stream<PlacementCatalogState> get changes => _changes.stream;

  /// The tileset every tileset-scoped catalog page uses, taken from the single
  /// `ERA` section of the open map.
  StarCraftTilesetAssetSet? get mapTileset {
    final session = openMapController.state.session;
    if (session == null || session.metadataViews.tilesets.length != 1) {
      return null;
    }
    final rawValue = session.metadataViews.tilesets.single.rawValue;
    for (final tileset in StarCraftTilesetAssetSet.values) {
      if (tileset.rawValue == rawValue) {
        return tileset;
      }
    }
    return null;
  }

  void setInstallationPath(String? path) {
    if (_disposed) return;
    final normalized = (path ?? '').trim();
    final next = normalized.isEmpty ? null : normalized;
    if (next == _installationPath) return;
    _installationPath = next;
    _invalidateCatalog();
  }

  void synchronizeSession(OpenedMapSession? session) {
    if (_disposed) return;
    final snapshot = session?.extractedMap;
    if (identical(snapshot, _mapSnapshot)) return;
    _mapSnapshot = snapshot;
    _invalidateCatalog();
  }

  Future<WeaponReferenceSnapshot> loadWeaponReferences() async {
    final gateway = catalogGateway;
    final path = _installationPath;
    final epoch = weaponReferenceEpoch;
    if (_disposed || gateway == null || path == null) {
      throw StateError(
        'Choose a StarCraft installation to load weapon references.',
      );
    }
    final operation = 'weapon-references-${++_weaponRequest}';
    _weaponOperation = operation;
    try {
      final page = await gateway.list(
        StarCraftPlacementCatalogRequest(
          operationId: operation,
          installationPath: path,
          kind: StarCraftPlacementKind.unit,
          tileset: mapTileset ?? StarCraftTilesetAssetSet.badlands,
          limit: 228,
          unitMetadataOnly: true,
        ),
      );
      if (_disposed || epoch != weaponReferenceEpoch) {
        throw StateError(
          'The installation or map changed. Reload weapon references.',
        );
      }
      if (!page.isSuccess) {
        throw StateError(
          page.diagnostics.map((d) => '${d.code}: ${d.message}').join('\n'),
        );
      }
      if (page.totalEntries != 228 ||
          page.entries.length != 228 ||
          page.helperVersion == null ||
          page.storageBuildNumber == null) {
        throw StateError(
          'Incomplete weapon reference coverage or source metadata.',
        );
      }
      final units = <UnitWeaponReferences>[];
      for (var i = 0; i < 228; i++) {
        final entry = page.entries[i];
        final references = entry.unitCapability?.weaponReferences;
        if (entry.key.id != i || references == null) {
          throw StateError('Weapon references for Unit #$i are unavailable.');
        }
        units.add(references);
      }
      return WeaponReferenceSnapshot(
        UnitWeaponIndex(units),
        epoch,
        '${page.storageProduct} build ${page.storageBuildNumber}; helper ${page.helperVersion}',
      );
    } finally {
      if (_weaponOperation == operation) _weaponOperation = null;
    }
  }

  /// Reads one preview without changing the placement selection or catalog page.
  Future<PlacementCatalogItem?> loadUnitPreview(int unit) async {
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    final path = _installationPath;
    final epoch = weaponReferenceEpoch;
    if (_disposed ||
        path == null ||
        catalogGateway == null ||
        objectAtlasGateway == null) {
      return null;
    }
    final batch =
        await ObjectPlacementCatalogLoader(
          catalogGateway: catalogGateway!,
          objectAtlasGateway: objectAtlasGateway!,
        ).load(
          StarCraftPlacementCatalogRequest(
            operationId: 'unit-preview-${++_weaponRequest}',
            installationPath: path,
            kind: StarCraftPlacementKind.unit,
            tileset: mapTileset ?? StarCraftTilesetAssetSet.badlands,
            offset: unit,
            limit: 1,
          ),
        );
    if (_disposed ||
        epoch != weaponReferenceEpoch ||
        !batch.page.isSuccess ||
        batch.page.entries.length != 1) {
      return null;
    }
    final entry = batch.page.entries.single;
    if (entry.key.id != unit) return null;
    final thumbnail = batch.thumbnails[entry.key];
    return PlacementCatalogItem(
      entry: entry,
      thumbnailRgba: thumbnail?.rgbaBytes,
      thumbnailWidth: thumbnail?.width ?? 0,
      thumbnailHeight: thumbnail?.height ?? 0,
    );
  }

  void _invalidateCatalog() {
    weaponReferenceEpoch++;
    final operation = _weaponOperation;
    if (operation != null) unawaited(catalogGateway?.cancel(operation));
    ++_requestSequence;
    _recentKeys.clear();
    _emit(PlacementCatalogState(kind: _state.kind, owner: _state.owner));
  }

  /// Loads the first page of [kind]. Returns false when the catalog cannot be
  /// browsed and records why in the state diagnostics.
  Future<bool> load(StarCraftPlacementKind kind) async {
    if (_disposed) return false;
    final sequence = ++_requestSequence;
    final blocked = _blockingCode(kind);
    if (blocked != null) {
      _emit(
        _copy(
          kind: kind,
          items: const [],
          totalEntries: 0,
          isLoading: false,
          diagnostics: [_diagnostic(blocked)],
          clearPreview: true,
        ),
      );
      return false;
    }
    _emit(
      _copy(
        kind: kind,
        items: const [],
        totalEntries: 0,
        isLoading: true,
        diagnostics: const [],
        clearPreview: true,
        tileset: mapTileset,
      ),
    );
    return _loadPage(kind: kind, offset: 0, sequence: sequence);
  }

  /// Loads the next page of the current kind for the virtualized grid.
  Future<bool> loadMore() async {
    if (_disposed ||
        _state.isLoading ||
        !_state.hasMore ||
        _blockingCode(_state.kind) != null) {
      return false;
    }
    final sequence = ++_requestSequence;
    _emit(_copy(isLoading: true));
    return _loadPage(
      kind: _state.kind,
      offset: _state.items.length,
      sequence: sequence,
    );
  }

  void setQuery(String query) {
    if (_state.query == query) {
      return;
    }
    _emit(_copy(query: query));
  }

  void setOwner(int owner) {
    RangeError.checkValueInInterval(owner, 0, 0xff, 'owner');
    if (_state.owner == owner) {
      return;
    }
    _emit(_copy(owner: owner));
  }

  void setContinuous(bool isContinuous) {
    if (_state.isContinuous == isContinuous) {
      return;
    }
    _emit(_copy(isContinuous: isContinuous));
  }

  /// Highlights an item in the detail pane. Browsing never changes the map.
  void preview(StarCraftPlacementCatalogKey key) {
    if (_state.previewKey == key) {
      return;
    }
    _emit(_copy(previewKey: key));
  }

  /// Confirms the previewed item as the active placement.
  ///
  /// A Tile becomes the terrain brush value; every other kind waits for a
  /// canvas click. An unplaceable item is refused with its own reason.
  bool confirm(StarCraftPlacementCatalogKey key) {
    final item = _state.items.where((entry) => entry.key == key).firstOrNull;
    if (item == null || !item.isPlaceable) {
      _emit(_copy(lastPlacementIssueCode: item?.issueCode));
      return false;
    }
    if (item.key.kind == StarCraftPlacementKind.tile) {
      if (!terrainEditingController.selectCatalogTile(item.key.id)) {
        _emit(
          _copy(
            lastPlacementIssueCode:
                ObjectPlacementDiagnosticCodes.terrainUnavailable,
          ),
        );
        return false;
      }
    }
    _rememberRecent(item.key);
    _emit(
      _copy(
        previewKey: key,
        selection: PlacementSelection(
          kind: item.key.kind,
          key: item.key,
          displayName: item.displayName,
          doodadRecipe: item.entry.doodadRecipe,
          unitCapability: item.entry.unitCapability,
        ),
        lastPlacementIssueCode: null,
        recentKeys: _recentKeys[item.key.kind] ?? const [],
      ),
    );
    return true;
  }

  void cancelSelection() {
    if (_state.selection == null) {
      return;
    }
    _emit(_copy(clearSelection: true, lastPlacementIssueCode: null));
  }

  /// Applies the active selection at a canvas position.
  ///
  /// Tiles never reach this path: they are painted by the terrain brush.
  ObjectPlacementResult placeAt({
    required int pixelX,
    required int pixelY,
    required int tileX,
    required int tileY,
  }) {
    final selection = _state.selection;
    if (selection == null || !selection.usesCanvasClick) {
      return ObjectPlacementResult.refused(
        PlacementCatalogDiagnosticCodes.noOpenMap,
      );
    }
    final result = switch (selection.kind) {
      StarCraftPlacementKind.pureSprite =>
        objectEditingController.placeCatalogPureSprite(
          spriteId: selection.key.id,
          owner: _state.owner,
          pixelX: pixelX,
          pixelY: pixelY,
        ),
      StarCraftPlacementKind.doodad => _placeDoodad(
        selection,
        tileX: tileX,
        tileY: tileY,
      ),
      StarCraftPlacementKind.unit => _placeUnit(
        selection,
        pixelX: pixelX,
        pixelY: pixelY,
      ),
      StarCraftPlacementKind.spriteUnit ||
      StarCraftPlacementKind.tile => ObjectPlacementResult.refused(
        PlacementCatalogDiagnosticCodes.unsupportedSelection,
      ),
    };
    if (result.isPlaced && !_state.isContinuous) {
      _emit(_copy(clearSelection: true, lastPlacementIssueCode: null));
    } else {
      _emit(_copy(lastPlacementIssueCode: result.issueCode));
    }
    return result;
  }

  ObjectPlacementResult _placeUnit(
    PlacementSelection selection, {
    required int pixelX,
    required int pixelY,
  }) {
    final capability = selection.unitCapability;
    if (capability == null) {
      return ObjectPlacementResult.refused(
        'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
      );
    }
    return objectEditingController.placeCatalogUnit(
      capability: capability,
      unitId: selection.key.id,
      owner: _state.owner,
      pixelX: pixelX,
      pixelY: pixelY,
    );
  }

  ObjectPlacementResult _placeDoodad(
    PlacementSelection selection, {
    required int tileX,
    required int tileY,
  }) {
    final recipe = selection.doodadRecipe;
    if (recipe == null) {
      return ObjectPlacementResult.refused(
        'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
      );
    }
    // The cursor points at the footprint centre, so the origin is half the
    // footprint up and to the left. A negative origin lands outside the map
    // and is refused by the placement command.
    final originTileX = tileX - (recipe.width ~/ 2);
    final originTileY = tileY - (recipe.height ~/ 2);
    if (originTileX < 0 || originTileY < 0) {
      return ObjectPlacementResult.refused(
        ObjectPlacementDiagnosticCodes.outOfBounds,
      );
    }
    return objectEditingController.placeCatalogDoodad(
      recipe: recipe,
      owner: _state.owner,
      originTileX: originTileX,
      originTileY: originTileY,
    );
  }

  Future<void> dispose() {
    if (_disposed) return _changes.close();
    _disposed = true;
    weaponReferenceEpoch++;
    final weaponOperation = _weaponOperation;
    if (weaponOperation != null) {
      unawaited(catalogGateway?.cancel(weaponOperation));
    }
    ++_requestSequence;
    _state = PlacementCatalogState();
    _recentKeys.clear();
    _mapSnapshot = null;
    _installationPath = null;
    _weaponOperation = null;
    return _changes.close();
  }

  String? _blockingCode(StarCraftPlacementKind kind) {
    if (openMapController.state.session == null) {
      return PlacementCatalogDiagnosticCodes.noOpenMap;
    }
    if (_installationPath == null) {
      return PlacementCatalogDiagnosticCodes.installationMissing;
    }
    if (mapTileset == null) {
      return PlacementCatalogDiagnosticCodes.mapTilesetUnavailable;
    }
    if (catalogGateway == null) {
      return PlacementCatalogDiagnosticCodes.loadersUnavailable;
    }
    final hasLoader = switch (kind) {
      StarCraftPlacementKind.tile => tileAtlasGateway != null,
      StarCraftPlacementKind.doodad => true,
      _ => objectAtlasGateway != null,
    };
    return hasLoader
        ? null
        : PlacementCatalogDiagnosticCodes.loadersUnavailable;
  }

  Future<bool> _loadPage({
    required StarCraftPlacementKind kind,
    required int offset,
    required int sequence,
  }) async {
    final tileset = mapTileset!;
    final request = StarCraftPlacementCatalogRequest(
      operationId: 'placement-catalog-${kind.wireName}-$sequence',
      installationPath: _installationPath!,
      kind: kind,
      tileset: tileset,
      offset: offset,
      limit: pageSize,
    );

    final List<PlacementCatalogItem> loaded;
    final List<EditorDiagnostic> diagnostics;
    final int totalEntries;
    if (kind == StarCraftPlacementKind.tile) {
      final batch =
          await TilePlacementCatalogLoader(
            catalogGateway: catalogGateway!,
            tileAtlasGateway: tileAtlasGateway!,
          ).load(
            request,
            isCancelled: () => _disposed || sequence != _requestSequence,
          );
      if (_disposed || sequence != _requestSequence) return false;
      diagnostics = batch.diagnostics;
      totalEntries = batch.page.totalEntries;
      loaded = [
        for (final entry in batch.page.entries)
          PlacementCatalogItem(
            entry: entry,
            thumbnailRgba: batch.thumbnails[entry.key.id],
            thumbnailWidth: batch.thumbnails[entry.key.id] == null ? 0 : 32,
            thumbnailHeight: batch.thumbnails[entry.key.id] == null ? 0 : 32,
          ),
      ];
    } else if (kind == StarCraftPlacementKind.doodad) {
      // A Doodad has no object graphic of its own: its preview is the
      // footprint recipe, so the catalog gateway alone is enough.
      final page = await catalogGateway!.list(request);
      diagnostics = page.diagnostics;
      totalEntries = page.totalEntries;
      loaded = [
        for (final entry in page.entries) PlacementCatalogItem(entry: entry),
      ];
    } else {
      final batch =
          await ObjectPlacementCatalogLoader(
            catalogGateway: catalogGateway!,
            objectAtlasGateway: objectAtlasGateway!,
          ).load(
            request,
            isCancelled: () => _disposed || sequence != _requestSequence,
          );
      if (_disposed || sequence != _requestSequence) return false;
      diagnostics = batch.diagnostics;
      totalEntries = batch.page.totalEntries;
      loaded = [
        for (final entry in batch.page.entries)
          _objectCatalogItem(entry, batch.thumbnails[entry.key]),
      ];
    }

    if (sequence != _requestSequence) {
      return false;
    }
    if (offset > 0 &&
        diagnostics.isEmpty &&
        (totalEntries != _state.totalEntries ||
            loaded.isEmpty ||
            _state.items.last.key.compareTo(loaded.first.key) >= 0)) {
      // Individually valid pages can still overlap or belong to a changed
      // catalog. Preserve the accepted snapshot and stop automatic paging.
      _emit(
        _copy(
          isLoading: false,
          diagnostics: [
            _diagnostic(PlacementCatalogDiagnosticCodes.inconsistentPage),
          ],
        ),
      );
      return false;
    }
    _emit(
      _copy(
        kind: kind,
        items: offset == 0 ? loaded : [..._state.items, ...loaded],
        totalEntries: totalEntries,
        isLoading: false,
        diagnostics: diagnostics,
        tileset: tileset,
      ),
    );
    return diagnostics.isEmpty;
  }

  PlacementCatalogItem _objectCatalogItem(
    StarCraftPlacementCatalogEntry entry,
    ObjectPlacementCatalogThumbnail? thumbnail,
  ) {
    if (thumbnail == null) return PlacementCatalogItem(entry: entry);
    final pixels = CatalogThumbnailPixels.fromRgba(
      thumbnail.rgbaBytes,
      thumbnail.width,
      thumbnail.height,
    );
    return PlacementCatalogItem(
      entry: entry,
      thumbnailRgba: pixels.rgba,
      thumbnailWidth: pixels.width,
      thumbnailHeight: pixels.height,
    );
  }

  void _rememberRecent(StarCraftPlacementCatalogKey key) {
    final keys = _recentKeys.putIfAbsent(key.kind, () => []);
    keys
      ..removeWhere((candidate) => candidate == key)
      ..insert(0, key);
    final limit = recentLimit < maximumRecentPerKind
        ? recentLimit
        : maximumRecentPerKind;
    if (keys.length > limit) {
      keys.removeRange(limit, keys.length);
    }
  }

  EditorDiagnostic _diagnostic(String code) => EditorDiagnostic(
    code: code,
    message: switch (code) {
      PlacementCatalogDiagnosticCodes.noOpenMap =>
        'Open a map before browsing the placement catalog.',
      PlacementCatalogDiagnosticCodes.installationMissing =>
        'Set the StarCraft: Remastered data folder in settings first.',
      PlacementCatalogDiagnosticCodes.mapTilesetUnavailable =>
        'The map needs exactly one ERA section with a known tileset.',
      PlacementCatalogDiagnosticCodes.inconsistentPage =>
        'The catalog changed or returned overlapping pages. Select the catalog kind again to reload.',
      _ => 'The placement catalog is unavailable in this build.',
    },
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
  );

  PlacementCatalogState _copy({
    StarCraftPlacementKind? kind,
    List<PlacementCatalogItem>? items,
    String? query,
    bool? isLoading,
    int? totalEntries,
    StarCraftTilesetAssetSet? tileset,
    StarCraftPlacementCatalogKey? previewKey,
    PlacementSelection? selection,
    int? owner,
    bool? isContinuous,
    String? lastPlacementIssueCode,
    List<EditorDiagnostic>? diagnostics,
    List<StarCraftPlacementCatalogKey>? recentKeys,
    bool clearPreview = false,
    bool clearSelection = false,
  }) => PlacementCatalogState(
    kind: kind ?? _state.kind,
    items: items ?? _state.items,
    query: query ?? _state.query,
    isLoading: isLoading ?? _state.isLoading,
    totalEntries: totalEntries ?? _state.totalEntries,
    tileset: tileset ?? _state.tileset,
    previewKey: clearPreview ? null : (previewKey ?? _state.previewKey),
    selection: clearSelection ? null : (selection ?? _state.selection),
    owner: owner ?? _state.owner,
    isContinuous: isContinuous ?? _state.isContinuous,
    lastPlacementIssueCode: lastPlacementIssueCode,
    diagnostics: diagnostics ?? _state.diagnostics,
    recentKeys: recentKeys ?? _state.recentKeys,
  );

  void _emit(PlacementCatalogState state) {
    if (_disposed) return;
    _state = state;
    _changes.add(state);
  }
}

final class WeaponReferenceSnapshot {
  const WeaponReferenceSnapshot(this.index, this.epoch, this.source);
  final UnitWeaponIndex index;
  final int epoch;
  final String source;
}
