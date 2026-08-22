import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';

abstract final class StarCraftPlacementCatalogDiagnosticCodes {
  static const installationPathInvalid = 'SC_CATALOG_INSTALLATION_PATH_INVALID';
  static const helperNotFound = 'SC_CATALOG_HELPER_NOT_FOUND';
  static const helperStartFailed = 'SC_CATALOG_HELPER_START_FAILED';
  static const helperTimedOut = 'SC_CATALOG_HELPER_TIMED_OUT';
  static const helperCancelled = 'SC_CATALOG_HELPER_CANCELLED';
  static const helperOutputLimitExceeded =
      'SC_CATALOG_HELPER_OUTPUT_LIMIT_EXCEEDED';
  static const helperInvalidResponse = 'SC_CATALOG_HELPER_INVALID_RESPONSE';
  static const storageOpenFailed = 'SC_CATALOG_STORAGE_OPEN_FAILED';
  static const metadataMissing = 'SC_CATALOG_METADATA_MISSING';
  static const metadataInvalid = 'SC_CATALOG_METADATA_INVALID';
  static const listingFailed = 'SC_CATALOG_LISTING_FAILED';
}

abstract interface class StarCraftPlacementCatalogGateway {
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  );

  Future<void> cancel(String operationId);
}

enum StarCraftPlacementKind {
  tile(0, 'tile', 'Tile', true),
  doodad(1, 'doodad', 'Doodad', true),
  unit(2, 'unit', 'Unit', false),
  pureSprite(3, 'pureSprite', 'Sprite', false),
  spriteUnit(4, 'spriteUnit', 'Sprite-unit', false);

  const StarCraftPlacementKind(
    this.sortOrder,
    this.wireName,
    this.fallbackLabel,
    this.isTilesetScoped,
  );

  final int sortOrder;
  final String wireName;
  final String fallbackLabel;
  final bool isTilesetScoped;
}

enum StarCraftPlacementCatalogSource { localData, mapTemplate }

enum StarCraftPlacementAvailability { placeable, unsupported, invalid }

final class StarCraftPlacementCatalogKey
    implements Comparable<StarCraftPlacementCatalogKey> {
  StarCraftPlacementCatalogKey._({
    required this.kind,
    required this.id,
    this.tileset,
    this.doodadStartTileGroup,
  }) {
    if (id < 0 || id > maximumId) {
      throw RangeError.range(id, 0, maximumId, 'id');
    }
    if (kind.isTilesetScoped != (tileset != null)) {
      throw ArgumentError('Only tile and doodad keys must include a tileset.');
    }
    if (kind == StarCraftPlacementKind.doodad) {
      final startTileGroup = doodadStartTileGroup;
      if (startTileGroup == null) {
        throw ArgumentError.notNull('doodadStartTileGroup');
      }
      if (startTileGroup < 0 || startTileGroup > maximumId) {
        throw RangeError.range(
          startTileGroup,
          0,
          maximumId,
          'doodadStartTileGroup',
        );
      }
    } else if (doodadStartTileGroup != null) {
      throw ArgumentError('Only doodad keys can include a start tile group.');
    }
  }

  factory StarCraftPlacementCatalogKey.tile({
    required StarCraftTilesetAssetSet tileset,
    required int rawValue,
  }) => StarCraftPlacementCatalogKey._(
    kind: StarCraftPlacementKind.tile,
    id: rawValue,
    tileset: tileset,
  );

  factory StarCraftPlacementCatalogKey.doodad({
    required StarCraftTilesetAssetSet tileset,
    required int doodadId,
    required int startTileGroup,
  }) => StarCraftPlacementCatalogKey._(
    kind: StarCraftPlacementKind.doodad,
    id: doodadId,
    tileset: tileset,
    doodadStartTileGroup: startTileGroup,
  );

  factory StarCraftPlacementCatalogKey.unit(int unitId) =>
      StarCraftPlacementCatalogKey._(
        kind: StarCraftPlacementKind.unit,
        id: unitId,
      );

  factory StarCraftPlacementCatalogKey.pureSprite(int spriteId) =>
      StarCraftPlacementCatalogKey._(
        kind: StarCraftPlacementKind.pureSprite,
        id: spriteId,
      );

  factory StarCraftPlacementCatalogKey.spriteUnit(int unitId) =>
      StarCraftPlacementCatalogKey._(
        kind: StarCraftPlacementKind.spriteUnit,
        id: unitId,
      );

  static const maximumId = 0xffff;

  final StarCraftPlacementKind kind;
  final int id;
  final StarCraftTilesetAssetSet? tileset;
  final int? doodadStartTileGroup;

  String get stableId {
    final prefix = tileset == null
        ? kind.wireName
        : '${kind.wireName}:${tileset!.rawValue}';
    return doodadStartTileGroup == null
        ? '$prefix:$id'
        : '$prefix:$id:$doodadStartTileGroup';
  }

  @override
  int compareTo(StarCraftPlacementCatalogKey other) {
    var comparison = kind.sortOrder.compareTo(other.kind.sortOrder);
    if (comparison != 0) {
      return comparison;
    }
    comparison = (tileset?.rawValue ?? -1).compareTo(
      other.tileset?.rawValue ?? -1,
    );
    if (comparison != 0) {
      return comparison;
    }
    comparison = id.compareTo(other.id);
    if (comparison != 0) {
      return comparison;
    }
    return (doodadStartTileGroup ?? -1).compareTo(
      other.doodadStartTileGroup ?? -1,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StarCraftPlacementCatalogKey &&
        other.kind == kind &&
        other.id == id &&
        other.tileset == tileset &&
        other.doodadStartTileGroup == doodadStartTileGroup;
  }

  @override
  int get hashCode => Object.hash(kind, id, tileset, doodadStartTileGroup);
}

final class StarCraftPlacementCatalogIssue {
  StarCraftPlacementCatalogIssue({required this.code, required String message})
    : message = message.trim() {
    if (!_isSafeIdentifier(code, maximumCodeLength) ||
        !code.startsWith('SC_CATALOG_ITEM_')) {
      throw ArgumentError.value(
        code,
        'code',
        'Must be a stable SC_CATALOG_ITEM_* identifier.',
      );
    }
    if (!_isSafeDisplayText(this.message, maximumMessageLength)) {
      throw ArgumentError.value(
        message,
        'message',
        'Must be safe single-line display text.',
      );
    }
  }

  static const maximumCodeLength = 128;
  static const maximumMessageLength = 256;

  final String code;
  final String message;
}

final class StarCraftPlacementCatalogEntry {
  StarCraftPlacementCatalogEntry({
    required this.key,
    required this.source,
    required this.availability,
    String? verifiedName,
    Iterable<String> categoryPath = const [],
    this.issue,
  }) : verifiedName = _safeOptionalDisplayText(verifiedName, maximumNameLength),
       categoryPath = List.unmodifiable(
         categoryPath.map((segment) {
           final normalized = segment.trim();
           if (!_isSafeDisplayText(normalized, maximumCategoryLength)) {
             throw ArgumentError.value(
               segment,
               'categoryPath',
               'Each category must be safe single-line display text.',
             );
           }
           return normalized;
         }),
       ) {
    if (this.categoryPath.length > maximumCategoryDepth) {
      throw RangeError.range(
        this.categoryPath.length,
        0,
        maximumCategoryDepth,
        'categoryPath.length',
      );
    }
    if ((availability == StarCraftPlacementAvailability.placeable) !=
        (issue == null)) {
      throw ArgumentError(
        'Placeable entries cannot have an issue and unavailable entries '
        'must explain why.',
      );
    }
  }

  static const maximumNameLength = 128;
  static const maximumCategoryLength = 64;
  static const maximumCategoryDepth = 8;

  final StarCraftPlacementCatalogKey key;
  final StarCraftPlacementCatalogSource source;
  final StarCraftPlacementAvailability availability;
  final String? verifiedName;
  final List<String> categoryPath;
  final StarCraftPlacementCatalogIssue? issue;

  String get displayName =>
      verifiedName ?? '${key.kind.fallbackLabel} #${key.id}';

  String get thumbnailKey => key.stableId;

  bool get isPlaceable =>
      availability == StarCraftPlacementAvailability.placeable;
}

final class StarCraftPlacementCatalogRequest {
  StarCraftPlacementCatalogRequest({
    required this.operationId,
    required this.installationPath,
    required this.kind,
    required this.tileset,
    this.offset = 0,
    this.limit = defaultLimit,
  }) {
    if (!_isSafeIdentifier(operationId, maximumOperationIdLength)) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must contain 1-128 safe ASCII identifier characters.',
      );
    }
    if (installationPath.trim().isEmpty) {
      throw ArgumentError.value(
        installationPath,
        'installationPath',
        'Must not be empty.',
      );
    }
    if (offset < 0 || offset > maximumOffset) {
      throw RangeError.range(offset, 0, maximumOffset, 'offset');
    }
    if (limit < 1 || limit > maximumLimit) {
      throw RangeError.range(limit, 1, maximumLimit, 'limit');
    }
  }

  static const defaultLimit = 128;
  static const maximumLimit = 256;
  static const maximumOffset = 0xffff;
  static const maximumOperationIdLength = 128;

  final String operationId;
  final String installationPath;
  final StarCraftPlacementKind kind;
  final StarCraftTilesetAssetSet tileset;
  final int offset;
  final int limit;
}

final class StarCraftPlacementCatalogPage {
  StarCraftPlacementCatalogPage({
    required this.request,
    required this.totalEntries,
    Iterable<StarCraftPlacementCatalogEntry> entries = const [],
    this.storageProduct,
    this.storageBuildNumber,
    this.helperVersion,
    this.cascLibRevision,
    this.totalMetadataBytes = 0,
    Iterable<EditorDiagnostic> diagnostics = const [],
  }) : entries = List.unmodifiable(entries),
       diagnostics = List.unmodifiable(diagnostics) {
    if (totalEntries < 0 ||
        totalEntries > maximumTotalEntries ||
        totalMetadataBytes < 0 ||
        this.entries.length > request.limit ||
        (request.offset >= totalEntries
            ? this.entries.isNotEmpty
            : this.entries.isEmpty ||
                  request.offset + this.entries.length > totalEntries)) {
      throw ArgumentError('Catalog page counts are inconsistent.');
    }
    StarCraftPlacementCatalogKey? previous;
    for (final entry in this.entries) {
      if (entry.source != StarCraftPlacementCatalogSource.localData ||
          entry.key.kind != request.kind ||
          (entry.key.kind.isTilesetScoped &&
              entry.key.tileset != request.tileset) ||
          (previous != null && previous.compareTo(entry.key) >= 0)) {
        throw ArgumentError(
          'Catalog entries must match the request and be strictly sorted.',
        );
      }
      previous = entry.key;
    }
  }

  factory StarCraftPlacementCatalogPage.failed({
    required StarCraftPlacementCatalogRequest request,
    required EditorDiagnostic diagnostic,
  }) {
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 0,
      diagnostics: [diagnostic],
    );
  }

  static const maximumTotalEntries = 0x10000;

  final StarCraftPlacementCatalogRequest request;
  final int totalEntries;
  final List<StarCraftPlacementCatalogEntry> entries;
  final String? storageProduct;
  final int? storageBuildNumber;
  final String? helperVersion;
  final String? cascLibRevision;
  final int totalMetadataBytes;
  final List<EditorDiagnostic> diagnostics;

  int? get nextOffset {
    final candidate = request.offset + entries.length;
    return candidate < totalEntries ? candidate : null;
  }

  bool get isSuccess => diagnostics.isEmpty;
}

String? _safeOptionalDisplayText(String? value, int maximumRunes) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim();
  return _isSafeDisplayText(normalized, maximumRunes) ? normalized : null;
}

bool _isSafeDisplayText(String value, int maximumRunes) {
  if (value.isEmpty || value.runes.length > maximumRunes) {
    return false;
  }
  for (final rune in value.runes) {
    if (rune < 0x20 || (rune >= 0x7f && rune <= 0x9f)) {
      return false;
    }
  }
  return true;
}

bool _isSafeIdentifier(String value, int maximumLength) {
  if (value.isEmpty || value.length > maximumLength) {
    return false;
  }
  for (final codeUnit in value.codeUnits) {
    final isLetter =
        (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a);
    final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
    if (!isLetter &&
        !isDigit &&
        codeUnit != 0x2d &&
        codeUnit != 0x2e &&
        codeUnit != 0x5f) {
      return false;
    }
  }
  return true;
}
