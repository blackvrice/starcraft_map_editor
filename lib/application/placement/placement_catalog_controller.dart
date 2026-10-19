import '../../domain/placement/unit_weapon_references.dart';
import '../ports/eud_dat_gateway.dart';
import 'catalog_thumbnail_pixels.dart';
import 'doodad_placement_catalog_loader.dart';
import 'dart:async';
import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../../domain/placement/doodad_placement_recipe.dart';
import '../../domain/placement/unit_placement_capability.dart';
import '../../domain/placement/unit_collision_catalog.dart';
import '../../domain/placement/unit_resource_distance_catalog.dart';
import 'unit_resource_distance_inspection.dart';
import '../../domain/placement/unit_power_catalog.dart';
import '../ports/unit_power_state_gateway.dart';
import 'unit_power_inspection.dart';
import '../../domain/placement/unit_creep_catalog.dart';
import '../../domain/placement/unit_creep_coverage.dart';
import '../ports/unit_creep_state_gateway.dart';
import 'unit_creep_inspection.dart';
import '../../domain/placement/terrain_placement_snapshot.dart';
import '../../domain/placement/unit_placement_policy.dart';
import 'placement_policy_support.dart';
import '../ports/terrain_placement_snapshot_gateway.dart';
import '../../domain/placement/point_placement_snap.dart';
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
    this.thumbnailEvicted = false,
    this.thumbnailIssueCode,
  });

  final StarCraftPlacementCatalogEntry entry;
  final Uint8List? thumbnailRgba;
  final int thumbnailWidth;
  final int thumbnailHeight;
  final bool thumbnailEvicted;
  final String? thumbnailIssueCode;

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
    this.unitSourceIdentity,
  });

  final StarCraftPlacementKind kind;
  final StarCraftPlacementCatalogKey key;
  final String displayName;
  final DoodadPlacementRecipe? doodadRecipe;
  final UnitPlacementCapability? unitCapability;
  final (String?, int?, String?, String?)? unitSourceIdentity;

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
    this.pointSnap = PointPlacementSnap.disabled,
    this.gridVisible = true,
    this.gridSpacingPixels,
    this.alignBuildingsToTiles = false,
    this.allowUnitOverlap = true,
    this.isCollisionMetadataLoading = false,
    this.checkUnitTerrain = false,
    this.checkResourceDistance = false,
    this.checkPreplacedPower = false,
    this.checkCreep = false,
    this.isTerrainPlacementLoading = false,
    this.lastPlacementIssueCode,
    Iterable<EditorDiagnostic> diagnostics = const [],
    Iterable<EditorDiagnostic> previewDiagnostics = const [],
    Iterable<StarCraftPlacementCatalogKey> recentKeys = const [],
  }) : items = List.unmodifiable(items),
       diagnostics = List.unmodifiable(diagnostics),
       previewDiagnostics = List.unmodifiable(previewDiagnostics),
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
  final PointPlacementSnap pointSnap;
  final bool gridVisible;
  final int? gridSpacingPixels;
  final bool alignBuildingsToTiles;
  final bool allowUnitOverlap;
  final bool isCollisionMetadataLoading;
  final bool checkUnitTerrain;
  final bool checkResourceDistance;
  final bool checkPreplacedPower;
  final bool checkCreep;
  final bool isTerrainPlacementLoading;
  late final unitPlacementPolicy = UnitPlacementPolicy(
    checkTerrain: checkUnitTerrain,
    allowOverlap: allowUnitOverlap,
    checkResourceDistance: checkResourceDistance,
    checkPreplacedPower: checkPreplacedPower,
    checkCreep: checkCreep,
  );
  final String? lastPlacementIssueCode;
  final List<EditorDiagnostic> diagnostics;

  /// Nonblocking graphic failures; metadata and placement remain independent.
  final List<EditorDiagnostic> previewDiagnostics;
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

  late final Map<StarCraftPlacementCatalogKey, PlacementCatalogItem>
  _itemsByKey = {for (final item in items) item.key: item};
  PlacementCatalogItem? get previewItem => _itemsByKey[previewKey];

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
    this.eudDatGateway,
    this.tileAtlasGateway,
    this.objectAtlasGateway,
    this.terrainPlacementGateway,
    this.unitPowerStateGateway,
    this.unitCreepStateGateway,
    this.pageSize = StarCraftPlacementCatalogRequest.defaultLimit,
    this.recentLimit = 12,
    this.tileThumbnailBudgetBytes = 16 * 1024 * 1024,
  }) {
    if (tileThumbnailBudgetBytes < 4096) {
      throw ArgumentError.value(
        tileThumbnailBudgetBytes,
        'tileThumbnailBudgetBytes',
      );
    }
    // Both inspections share document events, not packets or cancellation.
    _powerSession = openMapController.state.session;
    _powerSessionSubscription = openMapController.changes.listen((state) {
      if (!identical(_powerSession, state.session)) {
        _powerSession = state.session;
        _invalidateDoodadRecipes();
        _invalidatePowerState();
        _invalidateCreepState();
        _notifyEnvironment();
      }
    });
    // History notifications also invalidate an edit/Undo cycle that returns to
    // an earlier snapshot. Never revive a previously collected state packet.
    _powerHistorySubscription = openMapController.editHistory.changes.listen((
      _,
    ) {
      _invalidateDoodadRecipes();
      _invalidatePowerState();
      _invalidateCreepState();
      _notifyEnvironment();
    });
  }

  static const maximumRecentPerKind = 12;

  final OpenMapController openMapController;
  final ObjectEditingController objectEditingController;
  final TerrainEditingController terrainEditingController;
  final StarCraftPlacementCatalogGateway? catalogGateway;
  final StarCraftTileAtlasGateway? tileAtlasGateway;
  final StarCraftObjectAtlasGateway? objectAtlasGateway;
  final TerrainPlacementSnapshotGateway? terrainPlacementGateway;
  final UnitPowerStateGateway? unitPowerStateGateway;
  final UnitCreepStateGateway? unitCreepStateGateway;
  final int pageSize;
  final int recentLimit;
  final int tileThumbnailBudgetBytes;
  final Map<StarCraftPlacementCatalogKey, int> _thumbnailUse = {};
  final Set<StarCraftPlacementCatalogKey> _thumbnailQueue = {};
  final Set<StarCraftPlacementCatalogKey> _thumbnailFailures = {};
  int _thumbnailClock = 0;
  final _unitGridPages = <int, Future<List<PlacementCatalogItem>>>{};
  int _thumbnailEpoch = 0;
  bool _hydratingThumbnails = false;
  (String?, int?, String?, String?)? _tileAtlasIdentity;

  int get retainedThumbnailBytes => _state.items.fold(
    0,
    (sum, item) => sum + (item.thumbnailRgba?.lengthInBytes ?? 0),
  );

  /// Called for grid/prefetch entries and the detail preview. No synchronous
  /// state notification: Flutter may call this while building a frame.
  void requestThumbnail(StarCraftPlacementCatalogKey key) {
    if (_disposed || key.kind != StarCraftPlacementKind.tile) return;
    final item = _state._itemsByKey[key];
    if (item == null) return;
    _thumbnailUse[key] = ++_thumbnailClock;
    if (!item.thumbnailEvicted || _thumbnailFailures.contains(key)) return;
    _thumbnailQueue.add(key);
    if (!_hydratingThumbnails) unawaited(_hydrateThumbnails());
  }

  void _resetThumbnails() {
    _tileAtlasIdentity = null;
    _thumbnailEpoch++;
    _thumbnailUse.clear();
    _thumbnailQueue.clear();
    _thumbnailFailures.clear();
  }

  List<PlacementCatalogItem> _boundTileThumbnails(
    List<PlacementCatalogItem> items,
  ) {
    if (items.isEmpty || items.first.key.kind != StarCraftPlacementKind.tile) {
      return items;
    }
    var bytes = 0;
    final candidates = <PlacementCatalogItem>[];
    for (final item in items) {
      if (!item.hasThumbnail) continue;
      bytes += item.thumbnailRgba!.lengthInBytes;
      _thumbnailUse.putIfAbsent(item.key, () => ++_thumbnailClock);
      candidates.add(item);
    }
    if (bytes <= tileThumbnailBudgetBytes) return items;
    candidates.sort(
      (a, b) => _thumbnailUse[a.key]!.compareTo(_thumbnailUse[b.key]!),
    );
    final evict = <StarCraftPlacementCatalogKey>{};
    for (final item in candidates) {
      if (bytes <= tileThumbnailBudgetBytes) break;
      evict.add(item.key);
      bytes -= item.thumbnailRgba!.lengthInBytes;
    }
    return [
      for (final item in items)
        if (evict.contains(item.key))
          PlacementCatalogItem(entry: item.entry, thumbnailEvicted: true)
        else
          item,
    ];
  }

  Future<void> _hydrateThumbnails() async {
    _hydratingThumbnails = true;
    try {
      // Coalesce all cells requested during one grid build into a batch.
      await Future<void>.delayed(Duration.zero);
      while (!_disposed && _thumbnailQueue.isNotEmpty) {
        _thumbnailQueue.removeWhere(
          (key) => _state._itemsByKey[key]?.thumbnailEvicted != true,
        );
        if (_thumbnailQueue.isEmpty) break;
        final epoch = _thumbnailEpoch;
        final keys = _thumbnailQueue.take(128).toList()..sort();
        _thumbnailQueue.removeAll(keys);
        final path = _installationPath;
        final tileset = mapTileset;
        final gateway = tileAtlasGateway;
        if (path == null || tileset == null || gateway == null) break;
        try {
          final request = StarCraftTileAtlasRequest(
            installationPath: path,
            tileset: tileset,
            rawValues: [for (final key in keys) key.id],
          );
          final result = await gateway.render(request);
          if (_disposed || epoch != _thumbnailEpoch) continue;
          if (!result.isSuccess ||
              _tileAtlasIdentity !=
                  (
                    result.storageProduct,
                    result.storageBuildNumber,
                    result.helperVersion,
                    result.cascLibRevision,
                  ) ||
              result.unsupportedRawValues.isNotEmpty ||
              result.request.installationPath != request.installationPath ||
              result.request.tileset != request.tileset ||
              result.rawValues.length != keys.length ||
              !List.generate(
                keys.length,
                (i) => result.rawValues[i] == keys[i].id,
              ).every((v) => v)) {
            _thumbnailFailures.addAll(keys);
            continue;
          }
          final pixels = <StarCraftPlacementCatalogKey, Uint8List>{};
          for (var i = 0; i < keys.length; i++) {
            pixels[keys[i]] = Uint8List.fromList(
              Uint8List.sublistView(result.rgbaBytes, i * 4096, (i + 1) * 4096),
            ).asUnmodifiableView();
            _thumbnailUse[keys[i]] = ++_thumbnailClock;
          }
          _emit(
            _copy(
              items: _boundTileThumbnails([
                for (final item in _state.items)
                  if (pixels.containsKey(item.key))
                    PlacementCatalogItem(
                      entry: item.entry,
                      thumbnailRgba: pixels[item.key],
                      thumbnailWidth: 32,
                      thumbnailHeight: 32,
                    )
                  else
                    item,
              ]),
            ),
          );
        } catch (_) {
          if (!_disposed && epoch == _thumbnailEpoch) {
            _thumbnailFailures.addAll(keys);
          }
        }
      }
    } finally {
      _hydratingThumbnails = false;
    }
  }

  final StreamController<PlacementCatalogState> _changes =
      StreamController<PlacementCatalogState>.broadcast(sync: true);
  final Map<StarCraftPlacementKind, List<StarCraftPlacementCatalogKey>>
  _recentKeys = {};

  PlacementCatalogState _state = PlacementCatalogState();
  int _requestSequence = 0;
  String? _installationPath;
  Object? _mapSnapshot;
  bool _disposed = false;
  UnitCollisionCatalog? _collisionCatalog;
  UnitResourceDistanceCatalog? _resourceDistanceCatalog;
  UnitPowerCatalog? _powerCatalog;
  OpenedMapSession? _powerSession;
  late final StreamSubscription<OpenMapState> _powerSessionSubscription;
  late final StreamSubscription<void> _powerHistorySubscription;
  int _powerDocumentRevision = 0;
  Future<bool>? _powerStatePending;
  UnitPowerStateRequest? _powerStateRequest;
  UnitPowerStateSnapshot? _powerStateSnapshot;
  UnitPowerStateReadResult? lastUnitPowerStateRead;
  UnitCreepCatalog? _creepCatalog;
  int _creepDocumentRevision = 0;
  Future<bool>? _creepStatePending;
  UnitCreepStateRequest? _creepStateRequest;
  UnitCreepStateSnapshot? _creepStateSnapshot;
  UnitCreepStateReadResult? lastUnitCreepStateRead;
  (String?, int?, String?, String?)? _collisionIdentity;
  (String?, int?, String?, String?)? _unitCatalogIdentity;
  Future<bool>? _collisionPending;
  String? _collisionOperation;
  int _collisionEpoch = 0;
  StarCraftPlacementCatalogPage? lastCollisionMetadataPage;
  TerrainPlacementSource? _terrainPlacementSource;
  Future<bool>? _terrainPlacementPending;
  String? _terrainPlacementOperation;
  int _terrainPlacementEpoch = 0;
  StarCraftTilesetAssetSet? _sessionTileset;
  TerrainPlacementReadResult? lastTerrainPlacementRead;
  final EudDatGateway? eudDatGateway;
  EudDatSource? _eudData;
  Future<EudDatSource>? _eudDataPending;
  String? _eudDataOperation;
  EudDatReadResult? lastEudDatRead;
  EudDatSource? get eudData => _eudData;

  /// Read-only inspection does not require changing the placement selection.
  bool get _inspectionReady =>
      !_disposed &&
      _installationPath != null &&
      openMapController.state.session != null &&
      identical(_mapSnapshot, openMapController.state.session!.extractedMap);
  EudDatSource? get inspectionDatSource => _inspectionReady ? _eudData : null;
  TerrainPlacementSource? get inspectionTerrainSource =>
      _inspectionReady &&
          _terrainPlacementSource?.snapshot.tileset == mapTileset?.rawValue
      ? _terrainPlacementSource
      : null;
  UnitPowerCatalog? get inspectionPowerCatalog =>
      _inspectionReady ? _powerCatalog : null;
  (String?, int?, String?, String?)? get inspectionUnitIdentity =>
      _inspectionReady ? _collisionIdentity : null;

  Future<EudDatSource> loadEudData() {
    if (_eudData != null) return Future.value(_eudData);
    if (_eudDataPending != null) return _eudDataPending!;
    final gateway = eudDatGateway, path = _installationPath;
    if (_disposed || gateway == null || path == null) {
      return Future.error(
        StateError('Choose a StarCraft installation to load EUD DAT.'),
      );
    }
    final epoch = weaponReferenceEpoch;
    final operation = 'eud-dat-${++_weaponRequest}';
    _eudDataOperation = operation;
    final future = () async {
      try {
        final result = await gateway.read(
          operationId: operation,
          installationPath: path,
        );
        if (_disposed || epoch != weaponReferenceEpoch) {
          throw StateError('Installation or map changed. Reload EUD DAT.');
        }
        lastEudDatRead = result;
        if (!result.isSuccess) {
          throw StateError(result.errorCode ?? 'EUD DAT unavailable');
        }
        _eudData = result.source!;
        _emit(_state);
        return result.source!;
      } finally {
        if (_eudDataOperation == operation) {
          _eudDataPending = null;
          _eudDataOperation = null;
        }
      }
    }();
    _eudDataPending = future;
    return future;
  }

  void _invalidateEudData() {
    final operation = _eudDataOperation;
    if (operation != null) eudDatGateway?.cancel(operation);
    _eudDataOperation = null;
    _eudDataPending = null;
    _eudData = null;
    lastEudDatRead = null;
  }

  int weaponReferenceEpoch = 0;
  int _weaponRequest = 0;
  String? _weaponOperation;

  PlacementCatalogState get state => _state;

  Stream<PlacementCatalogState> get changes => _changes.stream;

  static const maximumDoodadRecipeTypes = 32;
  int _doodadRecipeEpoch = 0;
  int _doodadRecipeSequence = 0;
  final _doodadRecipeOperations = <String>{};

  Future<List<DoodadPlacementRecipe>> doodadRecipes(int type) async =>
      (await doodadRecipesForTypes([type]))[type]!;

  /// Scans metadata once for the whole selection, without loading thumbnails.
  /// No partial result escapes if a later page or the document is invalidated.
  Future<Map<int, List<DoodadPlacementRecipe>>> doodadRecipesForTypes(
    Iterable<int> types,
  ) async {
    final requested = types.take(maximumDoodadRecipeTypes + 1).toList();
    if (requested.length > maximumDoodadRecipeTypes) {
      throw ArgumentError('Too many Doodad recipe types.');
    }
    for (final type in requested) {
      RangeError.checkValueInInterval(type, 0, 0xffff, 'type');
    }
    if (requested.isEmpty) return const {};
    final path = _installationPath;
    final tileset = mapTileset;
    final gateway = catalogGateway;
    final document = openMapController.state.session?.rawDocument;
    final epoch = _doodadRecipeEpoch;
    if (_disposed || path == null || tileset == null || gateway == null) {
      throw StateError('Choose a StarCraft installation and open a map.');
    }
    final recipes = <int, List<DoodadPlacementRecipe>>{
      for (final type in requested) type: [],
    };
    final sequence = ++_doodadRecipeSequence;
    StarCraftPlacementCatalogPage? previous;
    var offset = 0;
    while (true) {
      final request = StarCraftPlacementCatalogRequest(
        operationId: 'doodad-recipes-$sequence-$offset',
        installationPath: path,
        kind: StarCraftPlacementKind.doodad,
        tileset: tileset,
        offset: offset,
        limit: 256,
      );
      final StarCraftPlacementCatalogPage page;
      _doodadRecipeOperations.add(request.operationId);
      try {
        page = await gateway.list(request);
      } finally {
        _doodadRecipeOperations.remove(request.operationId);
      }
      if (_disposed ||
          epoch != _doodadRecipeEpoch ||
          !identical(document, openMapController.state.session?.rawDocument)) {
        throw StateError('Map or installation changed.');
      }
      if (!page.isSuccess ||
          page.request.operationId != request.operationId ||
          page.request.installationPath != path ||
          page.request.offset != offset ||
          page.request.tileset != tileset ||
          page.request.kind != request.kind ||
          page.request.limit != request.limit ||
          page.request.unitMetadataOnly != request.unitMetadataOnly) {
        throw StateError('Doodad catalog could not be verified.');
      }
      if (previous != null &&
          (page.totalEntries != previous.totalEntries ||
              (
                    page.storageProduct,
                    page.storageBuildNumber,
                    page.helperVersion,
                    page.cascLibRevision,
                  ) !=
                  (
                    previous.storageProduct,
                    previous.storageBuildNumber,
                    previous.helperVersion,
                    previous.cascLibRevision,
                  ) ||
              page.entries.isEmpty ||
              previous.entries.last.key.compareTo(page.entries.first.key) >=
                  0)) {
        throw StateError('Doodad catalog pages are inconsistent.');
      }
      for (final entry in page.entries) {
        final recipe = entry.doodadRecipe;
        if (recipe != null) recipes[entry.key.id]?.add(recipe);
      }
      final next = page.nextOffset;
      if (next == null) break;
      if (next <= offset) throw StateError('Doodad catalog made no progress.');
      previous = page;
      offset = next;
    }
    return Map.unmodifiable({
      for (final entry in recipes.entries)
        entry.key: List<DoodadPlacementRecipe>.unmodifiable(entry.value),
    });
  }

  void _invalidateDoodadRecipes() {
    _doodadRecipeEpoch++;
    for (final operation in _doodadRecipeOperations.toList()) {
      unawaited(
        Future.sync(
          () => catalogGateway?.cancel(operation),
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    _doodadRecipeOperations.clear();
  }

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
    if (!identical(_powerSession, session)) {
      _powerSession = session;
      _invalidateDoodadRecipes();
      _invalidatePowerState();
      _invalidateCreepState();
    }
    final snapshot = session?.extractedMap;
    final tileset = mapTileset;
    if (identical(snapshot, _mapSnapshot)) {
      if (tileset != _sessionTileset) {
        _sessionTileset = tileset;
        _invalidateTerrainPlacement();
        _emit(_state);
        if (_state.checkUnitTerrain) unawaited(loadTerrainPlacement());
      }
      return;
    }
    _mapSnapshot = snapshot;
    _sessionTileset = tileset;
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

  /// Grid previews share a bounded 32-unit request instead of starting one
  /// native process per visible cell. They never change placement selection.
  Future<PlacementCatalogItem?> loadUnitGridPreview(int unit) async {
    RangeError.checkValueInInterval(unit, 0, 227, 'unit');
    final offset = unit ~/ 32 * 32;
    final epoch = weaponReferenceEpoch;
    final page = await _unitGridPages.putIfAbsent(offset, () async {
      final path = _installationPath;
      if (_disposed ||
          path == null ||
          catalogGateway == null ||
          objectAtlasGateway == null) {
        return const [];
      }
      final batch =
          await ObjectPlacementCatalogLoader(
            catalogGateway: catalogGateway!,
            objectAtlasGateway: objectAtlasGateway!,
          ).load(
            StarCraftPlacementCatalogRequest(
              operationId: 'unit-grid-${++_weaponRequest}',
              installationPath: path,
              kind: StarCraftPlacementKind.unit,
              tileset: mapTileset ?? StarCraftTilesetAssetSet.badlands,
              offset: offset,
              limit: (228 - offset).clamp(1, 32),
            ),
          );
      if (_disposed || epoch != weaponReferenceEpoch || !batch.isSuccess) {
        return const [];
      }
      return [
        for (final entry in batch.page.entries)
          _objectCatalogItem(entry, batch.thumbnails[entry.key]),
      ];
    });
    if (_disposed || epoch != weaponReferenceEpoch) return null;
    return page.where((item) => item.key.id == unit).firstOrNull;
  }

  void _invalidateCatalog() {
    _invalidateDoodadRecipes();
    _invalidateCollisionMetadata();
    _invalidateTerrainPlacement();
    _unitCatalogIdentity = null;
    _unitGridPages.clear();
    _invalidateEudData();
    _resetThumbnails();
    weaponReferenceEpoch++;
    final operation = _weaponOperation;
    if (operation != null) unawaited(catalogGateway?.cancel(operation));
    ++_requestSequence;
    _recentKeys.clear();
    _emit(
      PlacementCatalogState(
        kind: _state.kind,
        owner: _state.owner,
        pointSnap: _state.pointSnap,
        gridVisible: _state.gridVisible,
        gridSpacingPixels: _state.gridSpacingPixels,
        alignBuildingsToTiles: _state.alignBuildingsToTiles,
        allowUnitOverlap: _state.allowUnitOverlap,
        checkUnitTerrain: _state.checkUnitTerrain,
        checkResourceDistance: _state.checkResourceDistance,
        checkPreplacedPower: _state.checkPreplacedPower,
        checkCreep: _state.checkCreep,
      ),
    );
  }

  /// Loads the first page of [kind]. Returns false when the catalog cannot be
  /// browsed and records why in the state diagnostics.
  Future<bool> load(StarCraftPlacementKind kind) async {
    if (_disposed) return false;
    _resetThumbnails();
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
          previewDiagnostics: const [],
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
        previewDiagnostics: const [],
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
    } else {
      // A previous terrain brush must not consume the next object click.
      terrainEditingController.cancelBrushStroke();
      terrainEditingController.setTool(TerrainEditingTool.select);
      objectEditingController.cancelLocationCreation();
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
          unitSourceIdentity: item.key.kind == StarCraftPlacementKind.unit
              ? _unitCatalogIdentity
              : null,
        ),
        lastPlacementIssueCode: null,
        recentKeys: _recentKeys[item.key.kind] ?? const [],
      ),
    );
    if ((!_state.allowUnitOverlap ||
            _state.checkResourceDistance ||
            _state.checkPreplacedPower ||
            _state.checkCreep) &&
        item.key.kind == StarCraftPlacementKind.unit) {
      unawaited(loadCollisionMetadata());
    }
    if (_state.checkUnitTerrain &&
        item.key.kind == StarCraftPlacementKind.unit) {
      unawaited(loadTerrainPlacement());
    }
    return true;
  }

  void cancelSelection() {
    if (_state.selection == null) {
      return;
    }
    _emit(_copy(clearSelection: true, lastPlacementIssueCode: null));
  }

  void setPointSnap({required bool enabled, required int step}) {
    final snap = PointPlacementSnap(enabled: enabled, step: step);
    if (snap.enabled == _state.pointSnap.enabled &&
        snap.step == _state.pointSnap.step) {
      return;
    }
    _emit(_copy(pointSnap: snap));
  }

  void setBuildingTileAlignment(bool enabled) {
    if (enabled == _state.alignBuildingsToTiles) return;
    _emit(_copy(alignBuildingsToTiles: enabled));
  }

  void setAllowUnitOverlap(bool allowed) {
    if (_disposed || allowed == _state.allowUnitOverlap) return;
    _emit(_copy(allowUnitOverlap: allowed));
    if (!allowed) unawaited(loadCollisionMetadata());
  }

  void setCheckUnitTerrain(bool enabled) {
    if (_disposed || enabled == _state.checkUnitTerrain) return;
    _emit(_copy(checkUnitTerrain: enabled));
    if (enabled) unawaited(loadTerrainPlacement());
  }

  void setCheckResourceDistance(bool enabled) {
    if (_disposed || enabled == _state.checkResourceDistance) return;
    _emit(_copy(checkResourceDistance: enabled));
    if (enabled) unawaited(loadCollisionMetadata());
  }

  void setCheckPreplacedPower(bool enabled) {
    if (_disposed || enabled == _state.checkPreplacedPower) return;
    _emit(_copy(checkPreplacedPower: enabled));
    if (enabled) unawaited(loadCollisionMetadata());
  }

  void setCheckCreep(bool enabled) {
    if (_disposed || enabled == _state.checkCreep) return;
    _emit(_copy(checkCreep: enabled));
    // Metadata may load automatically, but engine collection always stays explicit.
    if (enabled) unawaited(loadCollisionMetadata());
  }

  /// Apply all preferences atomically; never paint or normalize existing UNITs.
  void setUnitPlacementPolicy(UnitPlacementPolicy policy) {
    if (_disposed ||
        (policy.checkTerrain == _state.checkUnitTerrain &&
            policy.allowOverlap == _state.allowUnitOverlap &&
            policy.checkResourceDistance == _state.checkResourceDistance &&
            policy.checkPreplacedPower == _state.checkPreplacedPower &&
            policy.checkCreep == _state.checkCreep)) {
      return;
    }
    _emit(
      _copy(
        checkUnitTerrain: policy.checkTerrain,
        allowUnitOverlap: policy.allowOverlap,
        checkResourceDistance: policy.checkResourceDistance,
        checkPreplacedPower: policy.checkPreplacedPower,
        checkCreep: policy.checkCreep,
      ),
    );
    if (policy.checkTerrain) unawaited(loadTerrainPlacement());
    if (!policy.allowOverlap ||
        policy.checkResourceDistance ||
        policy.checkPreplacedPower ||
        policy.checkCreep) {
      unawaited(loadCollisionMetadata());
    }
  }

  Map<PlacementPolicyRule, PlacementPolicySupportStatus>
  get placementPolicySupport {
    final selection = _state.selection;
    final isUnit = selection?.kind == StarCraftPlacementKind.unit;
    final cap = isUnit ? selection?.unitCapability : null;
    final building = cap?.isBuilding == true;
    final profile = cap?.collisionProfile;
    PlacementPolicySupportStatus terrainStatus() {
      if (!isUnit) return PlacementPolicySupportStatus.notApplicable;
      if (!_state.checkUnitTerrain) return PlacementPolicySupportStatus.skipped;
      if (profile == null) return PlacementPolicySupportStatus.unavailable;
      if (!building && profile.isFlyer) {
        return PlacementPolicySupportStatus.notApplicable;
      }
      if (_state.isTerrainPlacementLoading) {
        return PlacementPolicySupportStatus.loading;
      }
      return _currentTerrainPlacement == null
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled;
    }

    PlacementPolicySupportStatus overlapStatus() {
      if (!isUnit) return PlacementPolicySupportStatus.notApplicable;
      if (_state.allowUnitOverlap) return PlacementPolicySupportStatus.skipped;
      if (_state.isCollisionMetadataLoading) {
        return PlacementPolicySupportStatus.loading;
      }
      return profile == null || _currentCollisionCatalog == null
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled;
    }

    PlacementPolicySupportStatus resourceStatus() {
      if (!isUnit) return PlacementPolicySupportStatus.notApplicable;
      if (!_state.checkResourceDistance) {
        return PlacementPolicySupportStatus.skipped;
      }
      if (_state.isCollisionMetadataLoading) {
        return PlacementPolicySupportStatus.loading;
      }
      final catalog = _currentResourceDistanceCatalog;
      final role = cap?.resourceProfile;
      final sourceRole = catalog?.units[cap?.unitId]?.resourceProfile;
      if (catalog == null ||
          role == null ||
          sourceRole == null ||
          role.isDepot != sourceRole.isDepot ||
          role.isResource != sourceRole.isResource) {
        return PlacementPolicySupportStatus.unavailable;
      }
      if (!role.isDepot && !role.isResource) {
        return PlacementPolicySupportStatus.notApplicable;
      }
      return profile == null || profile.isFlyer
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled;
    }

    PlacementPolicySupportStatus preplacedPowerStatus() {
      if (!isUnit) return PlacementPolicySupportStatus.notApplicable;
      if (!_state.checkPreplacedPower) {
        return PlacementPolicySupportStatus.skipped;
      }
      if (_state.isCollisionMetadataLoading) {
        return PlacementPolicySupportStatus.loading;
      }
      final catalog = _currentPreplacedPowerCatalog;
      final source = catalog?.units[cap?.unitId];
      final role = cap?.environmentProfile;
      final sourceRole = source?.environmentProfile;
      if (cap == null ||
          source == null ||
          role == null ||
          sourceRole == null ||
          role.requiresPsi != sourceRole.requiresPsi ||
          role.requiresCreep != sourceRole.requiresCreep ||
          cap.isBuilding != source.isBuilding ||
          cap.isSubunit != source.isSubunit ||
          cap.isFlyingBuilding != source.isFlyingBuilding ||
          cap.requiresRelationLink != source.requiresRelationLink) {
        return PlacementPolicySupportStatus.unavailable;
      }
      if (!role.requiresPsi) return PlacementPolicySupportStatus.notApplicable;
      final box = cap.placementBox, sourceBox = source.placementBox;
      return !cap.isBuilding ||
              cap.isSubunit ||
              cap.isFlyingBuilding ||
              cap.requiresRelationLink ||
              profile == null ||
              profile.isFlyer ||
              source.collisionProfile?.isFlyer != profile.isFlyer ||
              box == null ||
              sourceBox == null ||
              box.width != sourceBox.width ||
              box.height != sourceBox.height
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled;
    }

    PlacementPolicySupportStatus creepStatus() {
      if (!isUnit) return PlacementPolicySupportStatus.notApplicable;
      if (!_state.checkCreep) return PlacementPolicySupportStatus.skipped;
      if (_state.isCollisionMetadataLoading || isUnitCreepStateLoading) {
        return PlacementPolicySupportStatus.loading;
      }
      final source = _currentCreepCatalog?.units[cap?.unitId];
      final role = cap?.environmentProfile,
          verified = source?.environmentProfile;
      if (cap == null ||
          source == null ||
          role == null ||
          verified == null ||
          role.requiresCreep != verified.requiresCreep ||
          role.requiresPsi != verified.requiresPsi ||
          cap.isBuilding != source.isBuilding ||
          cap.isSubunit != source.isSubunit ||
          cap.isFlyingBuilding != source.isFlyingBuilding ||
          cap.requiresRelationLink != source.requiresRelationLink ||
          cap.isGasResourceContainer != source.isGasResourceContainer) {
        return PlacementPolicySupportStatus.unavailable;
      }
      if (!role.requiresCreep) {
        return PlacementPolicySupportStatus.notApplicable;
      }
      final box = cap.placementBox, sourceBox = source.placementBox;
      return !cap.isBuilding ||
              cap.isSubunit ||
              cap.isFlyingBuilding ||
              cap.requiresRelationLink ||
              cap.isGasResourceContainer ||
              profile == null ||
              profile.isFlyer ||
              source.collisionProfile?.isFlyer != profile.isFlyer ||
              box == null ||
              sourceBox == null ||
              box.width != sourceBox.width ||
              box.height != sourceBox.height ||
              _currentCreepCoverage == null
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled;
    }

    // Report configured support, not a cached preview verdict. Existing UNIT
    // metadata, map structure and exact footprints are rechecked at placement.
    return Map.unmodifiable({
      PlacementPolicyRule.recordSafety: PlacementPolicySupportStatus.enforced,
      PlacementPolicyRule.buildingAlignment: !isUnit || !building
          ? PlacementPolicySupportStatus.notApplicable
          : !_state.alignBuildingsToTiles
          ? PlacementPolicySupportStatus.skipped
          : cap?.placementBox == null
          ? PlacementPolicySupportStatus.unavailable
          : PlacementPolicySupportStatus.enabled,
      PlacementPolicyRule.unitOverlap: overlapStatus(),
      PlacementPolicyRule.terrain: terrainStatus(),
      PlacementPolicyRule.resourceDistance: resourceStatus(),
      PlacementPolicyRule.preplacedPower: preplacedPowerStatus(),
      PlacementPolicyRule.power: building
          ? PlacementPolicySupportStatus.notImplemented
          : PlacementPolicySupportStatus.notApplicable,
      PlacementPolicyRule.creep: creepStatus(),
      PlacementPolicyRule.eudRuntime: isUnit
          ? PlacementPolicySupportStatus.notImplemented
          : PlacementPolicySupportStatus.notApplicable,
      PlacementPolicyRule.gameAcceptance:
          PlacementPolicySupportStatus.acceptancePending,
    });
  }

  void _invalidateTerrainPlacement() {
    _terrainPlacementEpoch++;
    final operation = _terrainPlacementOperation;
    if (operation != null) terrainPlacementGateway?.cancel(operation);
    _terrainPlacementOperation = null;
    _terrainPlacementPending = null;
    _terrainPlacementSource = null;
    lastTerrainPlacementRead = null;
    _state = _copy(isTerrainPlacementLoading: false);
  }

  /// Cache numeric assets, not MTXM decisions: every hover/click reads the
  /// current document. Only explicit load/reload starts an external process.
  Future<bool> loadTerrainPlacement({bool reload = false}) {
    if (_disposed) return Future.value(false);
    if (reload ||
        (_terrainPlacementSource != null &&
            _terrainPlacementSource!.snapshot.tileset !=
                mapTileset?.rawValue)) {
      _invalidateTerrainPlacement();
    }
    if (_terrainPlacementSource != null) return Future.value(true);
    if (_terrainPlacementPending != null) return _terrainPlacementPending!;
    final gateway = terrainPlacementGateway, path = _installationPath;
    final tileset = mapTileset;
    if (gateway == null || path == null || tileset == null) {
      if (reload) _emit(_state);
      return Future.value(false);
    }
    final epoch = _terrainPlacementEpoch;
    final operation = 'unit-terrain-${++_weaponRequest}';
    _terrainPlacementOperation = operation;
    final future = () async {
      try {
        final result = await Future.sync(
          () => gateway.readPlacement(
            operationId: operation,
            installationPath: path,
            tileset: tileset.rawValue,
          ),
        );
        if (_disposed ||
            epoch != _terrainPlacementEpoch ||
            mapTileset != tileset) {
          return false;
        }
        lastTerrainPlacementRead = result;
        final source = result.source;
        if (!result.isSuccess ||
            source == null ||
            source.snapshot.tileset != tileset.rawValue ||
            source.revision.isEmpty ||
            source.storageProduct.isEmpty ||
            source.helperVersion.isEmpty ||
            source.cascLibRevision.isEmpty ||
            source.storageBuildNumber < 0) {
          return false;
        }
        _terrainPlacementSource = source;
        return true;
      } catch (_) {
        return false;
      } finally {
        if (!_disposed && _terrainPlacementOperation == operation) {
          _terrainPlacementOperation = null;
          _terrainPlacementPending = null;
          _emit(_copy(isTerrainPlacementLoading: false));
        }
      }
    }();
    _terrainPlacementPending = future;
    _emit(_copy(isTerrainPlacementLoading: true));
    return future;
  }

  TerrainPlacementSnapshot? get _currentTerrainPlacement {
    final source = _terrainPlacementSource;
    if (source == null || source.snapshot.tileset != mapTileset?.rawValue) {
      return null;
    }
    final identity = (
      source.storageProduct,
      source.storageBuildNumber,
      source.helperVersion,
      source.cascLibRevision,
    );
    return _state.selection?.unitSourceIdentity == identity
        ? source.snapshot
        : null;
  }

  void _invalidateCollisionMetadata() {
    _invalidatePowerState();
    _invalidateCreepState();
    _collisionEpoch++;
    final operation = _collisionOperation;
    if (operation != null) unawaited(catalogGateway?.cancel(operation));
    _collisionOperation = null;
    _collisionPending = null;
    _collisionCatalog = null;
    _resourceDistanceCatalog = null;
    _powerCatalog = null;
    _creepCatalog = null;
    _collisionIdentity = null;
    lastCollisionMetadataPage = null;
    _state = _copy(isCollisionMetadataLoading: false);
  }

  /// Coalesces the full numeric metadata request; hover never starts a process.
  /// A returned failure is retryable and never authorizes placement.
  Future<bool> loadCollisionMetadata({bool reload = false}) {
    if (_disposed) return Future.value(false);
    if (reload) _invalidateCollisionMetadata();
    if (_collisionCatalog != null) return Future.value(true);
    if (_collisionPending != null) return _collisionPending!;
    final gateway = catalogGateway, path = _installationPath;
    if (gateway == null || path == null) return Future.value(false);
    final epoch = _collisionEpoch;
    final operation = 'unit-collision-${++_weaponRequest}';
    _collisionOperation = operation;
    final request = StarCraftPlacementCatalogRequest(
      operationId: operation,
      installationPath: path,
      kind: StarCraftPlacementKind.unit,
      tileset: mapTileset ?? StarCraftTilesetAssetSet.badlands,
      limit: 228,
      unitMetadataOnly: true,
    );
    final future = () async {
      try {
        final page = await Future.sync(() => gateway.list(request));
        if (_disposed || epoch != _collisionEpoch) return false;
        lastCollisionMetadataPage = page;
        final source = (
          page.storageProduct,
          page.storageBuildNumber,
          page.helperVersion,
          page.cascLibRevision,
        );
        if (!page.isSuccess ||
            page.totalEntries != 228 ||
            page.entries.length != 228 ||
            source.$1 == null ||
            source.$1!.isEmpty ||
            source.$2 == null ||
            source.$3 == null ||
            source.$3!.isEmpty ||
            source.$4 == null ||
            source.$4!.isEmpty ||
            page.request.operationId != operation ||
            page.request.installationPath != path ||
            page.request.kind != request.kind ||
            page.request.tileset != request.tileset ||
            page.request.offset != 0 ||
            page.request.limit != 228 ||
            !page.request.unitMetadataOnly) {
          return false;
        }
        final units = <int, UnitPlacementCapability>{};
        for (var i = 0; i < 228; i++) {
          final entry = page.entries[i];
          if (entry.key.id != i) return false;
          final capability = entry.unitCapability;
          if (capability != null) {
            if (capability.unitId != i) return false;
            units[i] = capability;
          }
        }
        _collisionCatalog = UnitCollisionCatalog(units);
        _resourceDistanceCatalog = UnitResourceDistanceCatalog(units);
        _powerCatalog = UnitPowerCatalog(units);
        _creepCatalog = UnitCreepCatalog(units);
        _collisionIdentity = source;
        return true;
      } catch (_) {
        return false;
      } finally {
        if (!_disposed && _collisionOperation == operation) {
          _collisionPending = null;
          _collisionOperation = null;
          _emit(_copy(isCollisionMetadataLoading: false));
        }
      }
    }();
    _collisionPending = future;
    _emit(_copy(isCollisionMetadataLoading: true));
    return future;
  }

  UnitCollisionCatalog? get _currentCollisionCatalog =>
      _state.selection?.unitSourceIdentity != null &&
          _state.selection!.unitSourceIdentity == _collisionIdentity
      ? _collisionCatalog
      : null;

  UnitResourceDistanceCatalog? get _currentResourceDistanceCatalog =>
      _currentCollisionCatalog == null ? null : _resourceDistanceCatalog;

  // Power and creep bind to the same source-matched numeric DAT snapshot.
  UnitPowerDataIdentity? get _currentUnitDataIdentity {
    final source = _collisionIdentity;
    if (_currentCollisionCatalog == null ||
        source == null ||
        source.$1 == null ||
        source.$1!.isEmpty ||
        source.$2 == null ||
        source.$2! < 0 ||
        source.$3 == null ||
        source.$3!.isEmpty ||
        source.$4 == null ||
        source.$4!.isEmpty) {
      return null;
    }
    return (source.$1!, source.$2!, source.$3!, source.$4!);
  }

  UnitPowerCatalog? get _currentPreplacedPowerCatalog =>
      _currentUnitDataIdentity == null ? null : _powerCatalog;

  UnitCreepCatalog? get _currentCreepCatalog =>
      _currentUnitDataIdentity == null ? null : _creepCatalog;

  UnitCreepCoverage? get _currentCreepCoverage {
    final snapshot = _creepStateSnapshot;
    return snapshot != null && _isCreepRequestCurrent(snapshot.request)
        ? snapshot.coverageFor(snapshot.request)
        : null;
  }

  void _invalidatePowerState() {
    _powerDocumentRevision++;
    final request = _powerStateRequest;
    _powerStateRequest = null;
    _powerStateSnapshot = null;
    _powerStatePending = null;
    lastUnitPowerStateRead = null;
    if (request != null) {
      unawaited(
        Future.sync(
          () => unitPowerStateGateway?.cancel(request.operationId),
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
  }

  bool _isPowerRequestCurrent(UnitPowerStateRequest request) =>
      !_disposed &&
      !openMapController.editHistory.isTransactionActive &&
      request.documentRevision == _powerDocumentRevision &&
      identical(request.session, openMapController.state.session) &&
      request.installationPath == _installationPath &&
      request.dataIdentity == _currentUnitDataIdentity;

  bool get isUnitPowerStateLoading => _powerStatePending != null;
  bool get isUnitCreepStateLoading => _creepStatePending != null;

  bool supportsUnitPowerStateModel(UnitPowerStateModel model) {
    if (unitPowerStateGateway case UnitPowerStateModelSupport(
      :final supportedPowerModels,
    )) {
      return !_disposed &&
          model != UnitPowerStateModel.live &&
          supportedPowerModels.contains(model);
    }
    return false;
  }

  // Inspection data lives outside the immutable preferences snapshot.
  void _notifyEnvironment() => _emit(_state);

  /// Explicit collection/projection only; never called by hover/preview/Apply.
  /// An adapter must not substitute a layout model for actual initial state.
  Future<bool> loadUnitPowerState({
    bool reload = false,
    UnitPowerStateModel model = UnitPowerStateModel.initialMap,
  }) {
    if (_disposed) return Future.value(false);
    final previousModel =
        _powerStateSnapshot?.model ?? _powerStateRequest?.model;
    if (reload || (previousModel != null && previousModel != model)) {
      _invalidatePowerState();
    }
    if (model == UnitPowerStateModel.live) return Future.value(false);
    final cached = _powerStateSnapshot;
    if (cached != null && _isPowerRequestCurrent(cached.request)) {
      return Future.value(true);
    }
    if (_powerStatePending != null) return _powerStatePending!;
    final session = openMapController.state.session;
    final source = _currentUnitDataIdentity;
    final gateway = unitPowerStateGateway;
    if (session == null ||
        source == null ||
        gateway == null ||
        openMapController.editHistory.isTransactionActive ||
        session.requiresRestrictedEditing) {
      return Future.value(false);
    }
    final request = UnitPowerStateRequest(
      operationId: 'unit-power-${++_weaponRequest}',
      session: session,
      documentRevision: _powerDocumentRevision,
      installationPath: _installationPath!,
      dataIdentity: source,
      model: model,
    );
    _powerStateRequest = request;
    final future = () async {
      try {
        final result = await Future.sync(() => gateway.read(request));
        if (!_isPowerRequestCurrent(request) ||
            !identical(_powerStateRequest, request)) {
          return false;
        }
        lastUnitPowerStateRead = result;
        final snapshot = result.snapshot;
        if (!result.isSuccess ||
            snapshot == null ||
            !identical(snapshot.request, request) ||
            snapshot.providerId.trim().isEmpty ||
            snapshot.revision.trim().isEmpty ||
            snapshot.model != request.model ||
            snapshot.powerModelRevision != UnitPowerCatalog.revision ||
            snapshot.units.length != request.units.length) {
          return false;
        }
        for (var i = 0; i < request.units.length; i++) {
          if (!identical(snapshot.units[i].unit, request.units[i])) {
            return false;
          }
        }
        _powerStateSnapshot = snapshot;
        return true;
      } catch (_) {
        return false;
      } finally {
        if (identical(_powerStateRequest, request)) {
          _powerStateRequest = null;
          _powerStatePending = null;
          _notifyEnvironment();
        }
      }
    }();
    _powerStatePending = future;
    _notifyEnvironment();
    return future;
  }

  UnitPowerInspection inspectUnitPowerAt({
    required int pixelX,
    required int pixelY,
    UnitPowerStateModel model = UnitPowerStateModel.initialMap,
  }) {
    if (_state.selection?.kind != StarCraftPlacementKind.unit) {
      return const UnitPowerInspection.notApplicable();
    }
    String? preflight(int x, int y) => _previewAt(
      pixelX: x,
      pixelY: y,
      tileX: x ~/ 32,
      tileY: y ~/ 32,
      checkPolicies: false,
    );
    final issue = preflight(pixelX, pixelY);
    if (issue != null) return UnitPowerInspection.refused(issue);
    final point = resolvePoint(pixelX, pixelY);
    if (point != (x: pixelX, y: pixelY)) {
      final finalIssue = preflight(point.x, point.y);
      if (finalIssue != null) return UnitPowerInspection.refused(finalIssue);
    }
    final session = openMapController.state.session!;
    final dimensions = session.metadataViews.dimensions.single;
    final snapshot = _powerStateSnapshot;
    final candidate = _state.selection!.unitCapability!;
    final catalog = _currentUnitDataIdentity == null ? null : _powerCatalog;
    final statesCurrent =
        model != UnitPowerStateModel.live &&
        snapshot != null &&
        snapshot.model == model &&
        _isPowerRequestCurrent(snapshot.request);
    // A confirmed no-psi candidate needs no supplier facts. All other cases
    // require a current packet, including a verified empty UNIT collection.
    final check =
        catalog == null ||
            (candidate.environmentProfile?.requiresPsi != false &&
                !statesCurrent)
        ? UnitPowerCheck.unavailable
        : catalog.check(
            candidate: candidate,
            owner: _state.owner,
            x: point.x,
            y: point.y,
            mapWidthTiles: dimensions.width,
            mapHeightTiles: dimensions.height,
            existing: statesCurrent ? snapshot.units : const [],
          );
    return UnitPowerInspection.checked(
      check,
      point: point,
      model: model,
      providerId: statesCurrent ? snapshot.providerId : null,
      stateRevision: statesCurrent ? snapshot.revision : null,
    );
  }

  void _invalidateCreepState() {
    _creepDocumentRevision++;
    final request = _creepStateRequest;
    _creepStateRequest = null;
    _creepStateSnapshot = null;
    _creepStatePending = null;
    lastUnitCreepStateRead = null;
    if (request != null) {
      unawaited(
        Future.sync(
          () => unitCreepStateGateway?.cancel(request.operationId),
        ).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
  }

  bool _isCreepRequestCurrent(UnitCreepStateRequest request) =>
      !_disposed &&
      !openMapController.editHistory.isTransactionActive &&
      request.isCurrentFor(
        session: openMapController.state.session,
        documentRevision: _creepDocumentRevision,
        installationPath: _installationPath,
        dataIdentity: _currentUnitDataIdentity,
      );

  /// Explicit trusted collection only. No default collector is registered;
  /// hover/preview/Apply never starts this request or invents coverage.
  Future<bool> loadUnitCreepState({
    bool reload = false,
    UnitCreepStateModel model = UnitCreepStateModel.initialMap,
  }) {
    if (_disposed) return Future.value(false);
    final previousModel =
        _creepStateSnapshot?.model ?? _creepStateRequest?.model;
    if (reload || (previousModel != null && previousModel != model)) {
      _invalidateCreepState();
    }
    final session = openMapController.state.session;
    final source = _currentUnitDataIdentity;
    final gateway = unitCreepStateGateway;
    if (model != UnitCreepStateModel.initialMap ||
        _state.selection?.kind != StarCraftPlacementKind.unit ||
        session == null ||
        source == null ||
        gateway == null ||
        openMapController.editHistory.isTransactionActive ||
        session.requiresRestrictedEditing) {
      return Future.value(false);
    }
    final cached = _creepStateSnapshot;
    if (cached != null && _isCreepRequestCurrent(cached.request)) {
      return Future.value(true);
    }
    if (_creepStatePending != null) return _creepStatePending!;
    final request = UnitCreepStateRequest(
      operationId: 'unit-creep-${++_weaponRequest}',
      session: session,
      documentRevision: _creepDocumentRevision,
      installationPath: _installationPath!,
      dataIdentity: source,
      model: model,
    );
    _creepStateRequest = request;
    final future = () async {
      try {
        final result = await Future.sync(() => gateway.read(request));
        // Cancellation is advisory. Identity/revision checks discard a late
        // reply before it can replace a newer packet or its raw diagnostics.
        if (!_isCreepRequestCurrent(request) ||
            !identical(_creepStateRequest, request)) {
          return false;
        }
        lastUnitCreepStateRead = result;
        final snapshot = result.snapshot;
        if (!result.isSuccess ||
            snapshot == null ||
            snapshot.coverageFor(request) == null) {
          return false;
        }
        _creepStateSnapshot = snapshot;
        return true;
      } catch (_) {
        return false;
      } finally {
        if (identical(_creepStateRequest, request)) {
          _creepStateRequest = null;
          _creepStatePending = null;
          _notifyEnvironment();
        }
      }
    }();
    _creepStatePending = future;
    _notifyEnvironment();
    return future;
  }

  UnitCreepInspection inspectUnitCreepAt({
    required int pixelX,
    required int pixelY,
    UnitCreepStateModel model = UnitCreepStateModel.initialMap,
  }) {
    if (_state.selection?.kind != StarCraftPlacementKind.unit) {
      return const UnitCreepInspection.notApplicable();
    }
    String? preflight(int x, int y) => _previewAt(
      pixelX: x,
      pixelY: y,
      tileX: x ~/ 32,
      tileY: y ~/ 32,
      checkPolicies: false,
    );
    final issue = preflight(pixelX, pixelY);
    if (issue != null) return UnitCreepInspection.refused(issue);
    final point = resolvePoint(pixelX, pixelY);
    if (point != (x: pixelX, y: pixelY)) {
      final finalIssue = preflight(point.x, point.y);
      if (finalIssue != null) return UnitCreepInspection.refused(finalIssue);
    }
    final session = openMapController.state.session!;
    final dimensions = session.metadataViews.dimensions.single;
    final snapshot = _creepStateSnapshot;
    final coverage =
        model == UnitCreepStateModel.initialMap &&
            snapshot != null &&
            snapshot.model == model &&
            _isCreepRequestCurrent(snapshot.request)
        ? snapshot.coverageFor(snapshot.request)
        : null;
    final catalog = _currentUnitDataIdentity == null ? null : _creepCatalog;
    return UnitCreepInspection.checked(
      catalog?.checkRequirement(
            candidate: _state.selection!.unitCapability!,
            x: point.x,
            y: point.y,
            mapWidthTiles: dimensions.width,
            mapHeightTiles: dimensions.height,
            coverage: coverage,
          ) ??
          UnitCreepCheck.unavailable,
      point: point,
      model: model,
      providerId: coverage == null ? null : snapshot!.providerId,
      stateRevision: coverage == null ? null : snapshot!.revision,
    );
  }

  /// Uses the current UNIT document and source-matched numeric metadata only.
  /// Does not load assets, mutate history, or enable a placement policy.
  UnitResourceDistanceInspection inspectUnitResourceDistanceAt({
    required int pixelX,
    required int pixelY,
  }) {
    if (_state.selection?.kind != StarCraftPlacementKind.unit) {
      return const UnitResourceDistanceInspection.notApplicable();
    }
    String? preflight(int x, int y) => _previewAt(
      pixelX: x,
      pixelY: y,
      tileX: x ~/ 32,
      tileY: y ~/ 32,
      checkPolicies: false,
    );
    final inputIssue = preflight(pixelX, pixelY);
    if (inputIssue != null) {
      return UnitResourceDistanceInspection.refused(inputIssue);
    }
    final point = resolvePoint(pixelX, pixelY);
    if (point != (x: pixelX, y: pixelY)) {
      final issue = preflight(point.x, point.y);
      if (issue != null) return UnitResourceDistanceInspection.refused(issue);
    }
    // Common preflight has established one usable DIM and an editable session.
    final session = openMapController.state.session!;
    final dimensions = session.metadataViews.dimensions.single;
    final catalog = _currentResourceDistanceCatalog;
    return UnitResourceDistanceInspection.checked(
      catalog?.check(
            candidate: _state.selection!.unitCapability!,
            x: point.x,
            y: point.y,
            mapWidthTiles: dimensions.width,
            mapHeightTiles: dimensions.height,
            existing: session.objectViews.unitSections.expand(
              (section) => section.units,
            ),
          ) ??
          UnitResourceDistanceCatalogCheck.metadataUnavailable,
      point: point,
    );
  }

  bool get isBuildingTileAlignmentActive =>
      _state.alignBuildingsToTiles &&
      _state.selection?.kind == StarCraftPlacementKind.unit &&
      _state.selection?.unitCapability?.isBuilding == true;

  void setGridVisible(bool visible) {
    if (visible == _state.gridVisible) return;
    _emit(_copy(gridVisible: visible));
  }

  void setGridSpacing(int? pixels) {
    if (pixels != null && !PointPlacementSnap.presets.contains(pixels)) {
      throw ArgumentError.value(pixels, 'pixels');
    }
    if (pixels == _state.gridSpacingPixels) return;
    _emit(_copy(gridSpacingPixels: pixels, clearGridSpacing: pixels == null));
  }

  bool get isPointSnapActive =>
      _state.pointSnap.enabled &&
      !isBuildingTileAlignmentActive &&
      (_state.selection?.kind == StarCraftPlacementKind.unit ||
          _state.selection?.kind == StarCraftPlacementKind.pureSprite ||
          _state.selection?.kind == StarCraftPlacementKind.spriteUnit);

  ({int x, int y}) resolvePoint(int x, int y) {
    if (isBuildingTileAlignmentActive) {
      return _state.selection!.unitCapability!.placementBox?.align(x, y) ??
          (x: x, y: y);
    }
    return isPointSnapActive ? _state.pointSnap.resolve(x, y) : (x: x, y: y);
  }

  /// Validates both the input and aligned output; never clamps at map edges.
  String? previewAt({
    required int pixelX,
    required int pixelY,
    required int tileX,
    required int tileY,
  }) {
    final issue = _previewAt(
      pixelX: pixelX,
      pixelY: pixelY,
      tileX: tileX,
      tileY: tileY,
      checkPolicies: !isPointSnapActive,
    );
    if (issue != null || !isPointSnapActive) return issue;
    final point = resolvePoint(pixelX, pixelY);
    return _previewAt(
      pixelX: point.x,
      pixelY: point.y,
      tileX: point.x ~/ 32,
      tileY: point.y ~/ 32,
    );
  }

  /// Reads current document/layer state without changing selection or history.
  /// Coordinates are already resolved; only Doodads use a tile footprint origin.
  String? _previewAt({
    required int pixelX,
    required int pixelY,
    required int tileX,
    required int tileY,
    bool checkPolicies = true,
  }) {
    final selection = _state.selection;
    if (selection == null || !selection.usesCanvasClick) {
      return PlacementCatalogDiagnosticCodes.unsupportedSelection;
    }
    switch (selection.kind) {
      case StarCraftPlacementKind.pureSprite:
        return objectEditingController.previewCatalogPureSprite(
          spriteId: selection.key.id,
          owner: _state.owner,
          pixelX: pixelX,
          pixelY: pixelY,
        );
      case StarCraftPlacementKind.unit:
      case StarCraftPlacementKind.spriteUnit:
        final capability = selection.unitCapability;
        if (capability == null) {
          return 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE';
        }
        return selection.kind == StarCraftPlacementKind.unit
            ? objectEditingController.previewCatalogUnit(
                capability: capability,
                unitId: selection.key.id,
                owner: _state.owner,
                pixelX: pixelX,
                pixelY: pixelY,
                alignBuildingToTiles: _state.alignBuildingsToTiles,
                allowUnitOverlap: !checkPolicies || _state.allowUnitOverlap,
                collisionCatalog: _currentCollisionCatalog,
                checkTerrain: checkPolicies && _state.checkUnitTerrain,
                terrainSnapshot: _currentTerrainPlacement,
                checkResourceDistance:
                    checkPolicies && _state.checkResourceDistance,
                resourceDistanceCatalog: _currentResourceDistanceCatalog,
                checkPreplacedPower:
                    checkPolicies && _state.checkPreplacedPower,
                preplacedPowerCatalog: _currentPreplacedPowerCatalog,
                checkCreep: checkPolicies && _state.checkCreep,
                creepCatalog: _currentCreepCatalog,
                creepCoverage: _currentCreepCoverage,
              )
            : objectEditingController.previewCatalogSpriteUnit(
                capability: capability,
                unitId: selection.key.id,
                owner: _state.owner,
                pixelX: pixelX,
                pixelY: pixelY,
              );
      case StarCraftPlacementKind.doodad:
        final recipe = selection.doodadRecipe;
        if (recipe == null) return 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID';
        final originX = tileX - recipe.width ~/ 2;
        final originY = tileY - recipe.height ~/ 2;
        if (originX < 0 || originY < 0) {
          return ObjectPlacementDiagnosticCodes.outOfBounds;
        }
        return objectEditingController.previewCatalogDoodad(
          recipe: recipe,
          owner: _state.owner,
          originTileX: originX,
          originTileY: originY,
        );
      case StarCraftPlacementKind.tile:
        return PlacementCatalogDiagnosticCodes.unsupportedSelection;
    }
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
        PlacementCatalogDiagnosticCodes.unsupportedSelection,
      );
    }
    if (isPointSnapActive) {
      final inputIssue = _previewAt(
        pixelX: pixelX,
        pixelY: pixelY,
        tileX: tileX,
        tileY: tileY,
        checkPolicies: false,
      );
      if (inputIssue != null) {
        _emit(_copy(lastPlacementIssueCode: inputIssue));
        return ObjectPlacementResult.refused(inputIssue);
      }
      final point = resolvePoint(pixelX, pixelY);
      pixelX = point.x;
      pixelY = point.y;
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
      StarCraftPlacementKind.spriteUnit => _placeUnit(
        selection,
        pixelX: pixelX,
        pixelY: pixelY,
      ),
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
    if (selection.kind == StarCraftPlacementKind.spriteUnit) {
      return objectEditingController.placeCatalogSpriteUnit(
        capability: capability,
        unitId: selection.key.id,
        owner: _state.owner,
        pixelX: pixelX,
        pixelY: pixelY,
      );
    }
    return objectEditingController.placeCatalogUnit(
      capability: capability,
      unitId: selection.key.id,
      owner: _state.owner,
      pixelX: pixelX,
      pixelY: pixelY,
      alignBuildingToTiles: _state.alignBuildingsToTiles,
      allowUnitOverlap: _state.allowUnitOverlap,
      collisionCatalog: _currentCollisionCatalog,
      checkTerrain: _state.checkUnitTerrain,
      terrainSnapshot: _currentTerrainPlacement,
      checkResourceDistance: _state.checkResourceDistance,
      resourceDistanceCatalog: _currentResourceDistanceCatalog,
      checkPreplacedPower: _state.checkPreplacedPower,
      preplacedPowerCatalog: _currentPreplacedPowerCatalog,
      checkCreep: _state.checkCreep,
      creepCatalog: _currentCreepCatalog,
      creepCoverage: _currentCreepCoverage,
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

  Future<void> dispose() async {
    _invalidateDoodadRecipes();
    _invalidateCollisionMetadata();
    _invalidateTerrainPlacement();
    _invalidateEudData();
    if (_disposed) return _changes.close();
    _resetThumbnails();
    _disposed = true;
    _unitGridPages.clear();
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
    await _powerSessionSubscription.cancel();
    await _powerHistorySubscription.cancel();
    await _changes.close();
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
    var previewDiagnostics = <EditorDiagnostic>[];
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
      if (offset == 0 && batch.isSuccess) {
        _tileAtlasIdentity = (
          batch.page.storageProduct,
          batch.page.storageBuildNumber,
          batch.page.helperVersion,
          batch.page.cascLibRevision,
        );
      }
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
      final batch =
          await DoodadPlacementCatalogLoader(
            catalogGateway: catalogGateway!,
            tileAtlasGateway: tileAtlasGateway,
            objectAtlasGateway: objectAtlasGateway,
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
            thumbnailRgba: batch.thumbnails[entry.key]?.rgba,
            thumbnailWidth: batch.thumbnails[entry.key]?.width ?? 0,
            thumbnailHeight: batch.thumbnails[entry.key]?.height ?? 0,
            thumbnailIssueCode: batch.previewIssues[entry.key],
          ),
      ];
      previewDiagnostics = batch.previewDiagnostics;
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
      if (kind == StarCraftPlacementKind.unit && diagnostics.isEmpty) {
        final identity = (
          batch.page.storageProduct,
          batch.page.storageBuildNumber,
          batch.page.helperVersion,
          batch.page.cascLibRevision,
        );
        if (offset > 0 && _unitCatalogIdentity != identity) {
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
        _unitCatalogIdentity = identity;
        if (_collisionIdentity != null && _collisionIdentity != identity) {
          _invalidateCollisionMetadata();
        }
        final terrainSource = _terrainPlacementSource;
        if (terrainSource != null &&
            (
                  terrainSource.storageProduct,
                  terrainSource.storageBuildNumber,
                  terrainSource.helperVersion,
                  terrainSource.cascLibRevision,
                ) !=
                identity) {
          _invalidateTerrainPlacement();
        }
      }
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
        items: _boundTileThumbnails(
          offset == 0 ? loaded : [..._state.items, ...loaded],
        ),
        totalEntries: totalEntries,
        isLoading: false,
        diagnostics: diagnostics,
        tileset: tileset,
        previewDiagnostics: previewDiagnostics,
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
    messageId: switch (code) {
      PlacementCatalogDiagnosticCodes.noOpenMap =>
        'editorOpenAMapBeforeBrowsingThePlacementCatalog',
      PlacementCatalogDiagnosticCodes.installationMissing =>
        'editorSetTheStarCraftRemasteredDataFolderInSettingsFirst',
      PlacementCatalogDiagnosticCodes.mapTilesetUnavailable =>
        'editorTheMapNeedsExactlyOneERASectionWithA',
      PlacementCatalogDiagnosticCodes.inconsistentPage =>
        'editorTheCatalogChangedOrReturnedOverlappingPagesSelectThe',
      _ => 'editorThePlacementCatalogIsUnavailableInThisBuild',
    },
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
    PointPlacementSnap? pointSnap,
    bool? gridVisible,
    int? gridSpacingPixels,
    bool? alignBuildingsToTiles,
    bool? allowUnitOverlap,
    bool? isCollisionMetadataLoading,
    bool? checkUnitTerrain,
    bool? checkResourceDistance,
    bool? checkPreplacedPower,
    bool? checkCreep,
    bool? isTerrainPlacementLoading,
    String? lastPlacementIssueCode,
    List<EditorDiagnostic>? diagnostics,
    List<EditorDiagnostic>? previewDiagnostics,
    List<StarCraftPlacementCatalogKey>? recentKeys,
    bool clearPreview = false,
    bool clearSelection = false,
    bool clearGridSpacing = false,
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
    pointSnap: pointSnap ?? _state.pointSnap,
    alignBuildingsToTiles:
        alignBuildingsToTiles ?? _state.alignBuildingsToTiles,
    allowUnitOverlap: allowUnitOverlap ?? _state.allowUnitOverlap,
    isCollisionMetadataLoading:
        isCollisionMetadataLoading ?? _state.isCollisionMetadataLoading,
    checkUnitTerrain: checkUnitTerrain ?? _state.checkUnitTerrain,
    checkResourceDistance:
        checkResourceDistance ?? _state.checkResourceDistance,
    checkPreplacedPower: checkPreplacedPower ?? _state.checkPreplacedPower,
    checkCreep: checkCreep ?? _state.checkCreep,
    isTerrainPlacementLoading:
        isTerrainPlacementLoading ?? _state.isTerrainPlacementLoading,
    gridVisible: gridVisible ?? _state.gridVisible,
    gridSpacingPixels: clearGridSpacing
        ? null
        : (gridSpacingPixels ?? _state.gridSpacingPixels),
    lastPlacementIssueCode: lastPlacementIssueCode,
    diagnostics: diagnostics ?? _state.diagnostics,
    previewDiagnostics: previewDiagnostics ?? _state.previewDiagnostics,
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
