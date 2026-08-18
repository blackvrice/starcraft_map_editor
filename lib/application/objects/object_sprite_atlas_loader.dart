import 'dart:collection';
import 'dart:typed_data';

import '../../domain/assets/starcraft_data_asset_manifest.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../../domain/chk/typed/chk_object_views.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/starcraft_object_atlas_gateway.dart';
import '../settings/starcraft_data_asset_settings_controller.dart';

abstract final class ObjectSpriteAtlasDiagnosticCodes {
  static const gatewayFailed = 'SC_CASC_OBJECT_ATLAS_GATEWAY_FAILED';
  static const resultMismatch = 'SC_CASC_OBJECT_ATLAS_RESULT_MISMATCH';
}

final class ObjectSpriteAtlasIdentity {
  ObjectSpriteAtlasIdentity({
    required this.installationPath,
    required this.storageProduct,
    required this.storageBuildNumber,
    required this.helperVersion,
    required this.cascLibRevision,
    required this.tileset,
    required this.inspectionSnapshot,
  }) : _normalizedInstallationPath = _normalizeWindowsPath(installationPath);

  final String installationPath;
  final String storageProduct;
  final int storageBuildNumber;
  final String helperVersion;
  final String cascLibRevision;
  final StarCraftTilesetAssetSet tileset;
  final Object inspectionSnapshot;
  final String _normalizedInstallationPath;

  @override
  bool operator ==(Object other) {
    return other is ObjectSpriteAtlasIdentity &&
        other._normalizedInstallationPath == _normalizedInstallationPath &&
        other.storageProduct == storageProduct &&
        other.storageBuildNumber == storageBuildNumber &&
        other.helperVersion == helperVersion &&
        other.cascLibRevision == cascLibRevision &&
        other.tileset == tileset &&
        identical(other.inspectionSnapshot, inspectionSnapshot);
  }

  @override
  int get hashCode => Object.hash(
    _normalizedInstallationPath,
    storageProduct,
    storageBuildNumber,
    helperVersion,
    cascLibRevision,
    tileset,
    identityHashCode(inspectionSnapshot),
  );
}

final class ObjectSpriteAtlasContext {
  ObjectSpriteAtlasContext({
    required this.identity,
    required List<StarCraftObjectGraphicKey> objectKeys,
  }) : objectKeys = List.unmodifiable(objectKeys);

  final ObjectSpriteAtlasIdentity identity;
  final List<StarCraftObjectGraphicKey> objectKeys;
}

final class ObjectSpriteRgbaFrame {
  ObjectSpriteRgbaFrame({
    required this.key,
    required this.spriteId,
    required this.imageId,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
    required this.frameIndex,
    required Uint8List rgbaBytes,
  }) : rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView();

  factory ObjectSpriteRgbaFrame.fromEntry(StarCraftObjectAtlasEntry entry) {
    return ObjectSpriteRgbaFrame(
      key: entry.key,
      spriteId: entry.spriteId,
      imageId: entry.imageId,
      width: entry.width,
      height: entry.height,
      anchorX: entry.anchorX,
      anchorY: entry.anchorY,
      frameIndex: entry.frameIndex,
      rgbaBytes: entry.rgbaBytes,
    );
  }

  final StarCraftObjectGraphicKey key;
  final int spriteId;
  final int imageId;
  final int width;
  final int height;
  final int anchorX;
  final int anchorY;
  final int frameIndex;
  final Uint8List rgbaBytes;
}

final class ObjectSpriteAtlasBatchResult {
  ObjectSpriteAtlasBatchResult({
    required Map<StarCraftObjectGraphicKey, ObjectSpriteRgbaFrame> frames,
    required List<StarCraftUnsupportedObjectGraphic> unsupportedObjects,
    required List<EditorDiagnostic> diagnostics,
  }) : frames = Map.unmodifiable(frames),
       unsupportedObjects = List.unmodifiable(unsupportedObjects),
       diagnostics = List.unmodifiable(diagnostics);

  final Map<StarCraftObjectGraphicKey, ObjectSpriteRgbaFrame> frames;
  final List<StarCraftUnsupportedObjectGraphic> unsupportedObjects;
  final List<EditorDiagnostic> diagnostics;

  bool get isSuccess => diagnostics.isEmpty;
}

final class ObjectSpriteAtlasLoader {
  const ObjectSpriteAtlasLoader({required this.gateway});

  final StarCraftObjectAtlasGateway gateway;

  ObjectSpriteAtlasContext? createContext({
    required ChkMetadataViews metadataViews,
    required ChkObjectViews objectViews,
    required StarCraftDataAssetSettingsState assetState,
  }) {
    if (!assetState.isReady || metadataViews.tilesets.length != 1) {
      return null;
    }
    final inspection = assetState.inspection;
    final knownTileset = metadataViews.tilesets.single.knownTileset;
    if (inspection == null || !inspection.isReady || knownTileset == null) {
      return null;
    }
    final storageProduct = inspection.storageProduct;
    final storageBuildNumber = inspection.storageBuildNumber;
    final helperVersion = inspection.helperVersion;
    final cascLibRevision = inspection.cascLibRevision;
    if (storageProduct == null ||
        storageProduct.isEmpty ||
        storageBuildNumber == null ||
        helperVersion == null ||
        helperVersion.isEmpty ||
        cascLibRevision == null ||
        cascLibRevision.isEmpty) {
      return null;
    }

    final objectKeys = SplayTreeSet<StarCraftObjectGraphicKey>();
    for (final section in objectViews.unitSections) {
      for (final unit in section.units) {
        objectKeys.add(
          StarCraftObjectGraphicKey(
            kind: StarCraftObjectGraphicKind.unit,
            id: unit.unitType,
            playerColor: _playerColor(unit.owner),
          ),
        );
      }
    }
    for (final section in objectViews.spriteSections) {
      for (final sprite in section.sprites) {
        objectKeys.add(
          StarCraftObjectGraphicKey(
            kind: sprite.drawsAsSprite
                ? StarCraftObjectGraphicKind.sprite
                : StarCraftObjectGraphicKind.unit,
            id: sprite.spriteType,
            playerColor: _playerColor(sprite.owner),
          ),
        );
      }
    }
    if (objectKeys.isEmpty) {
      return null;
    }

    final tileset = StarCraftTilesetAssetSet.values.singleWhere(
      (candidate) => candidate.rawValue == knownTileset.rawValue,
    );
    return ObjectSpriteAtlasContext(
      identity: ObjectSpriteAtlasIdentity(
        installationPath: inspection.installationPath,
        storageProduct: storageProduct,
        storageBuildNumber: storageBuildNumber,
        helperVersion: helperVersion,
        cascLibRevision: cascLibRevision,
        tileset: tileset,
        inspectionSnapshot: inspection,
      ),
      objectKeys: objectKeys.toList(growable: false),
    );
  }

  Future<ObjectSpriteAtlasBatchResult> loadBatch({
    required ObjectSpriteAtlasContext context,
    required String operationId,
    required List<StarCraftObjectGraphicKey> objectKeys,
  }) async {
    _validateBatch(context, objectKeys);
    final request = StarCraftObjectAtlasRequest(
      operationId: operationId,
      installationPath: context.identity.installationPath,
      tileset: context.identity.tileset,
      objects: objectKeys,
    );

    final StarCraftObjectAtlasResult result;
    try {
      result = await gateway.render(request);
    } catch (error) {
      return ObjectSpriteAtlasBatchResult(
        frames: const {},
        unsupportedObjects: _failedObjects(objectKeys),
        diagnostics: [
          _diagnostic(
            code: ObjectSpriteAtlasDiagnosticCodes.gatewayFailed,
            message: 'The StarCraft object atlas request failed unexpectedly.',
            filePath: context.identity.installationPath,
            remediation: 'Retry or repair the application installation.',
            rawDetails: error.toString(),
          ),
        ],
      );
    }

    if (!_sameRequest(result.request, request) ||
        (result.isSuccess &&
            !_sameIdentityMetadata(result, context.identity))) {
      return ObjectSpriteAtlasBatchResult(
        frames: const {},
        unsupportedObjects: _failedObjects(objectKeys),
        diagnostics: [
          _diagnostic(
            code: ObjectSpriteAtlasDiagnosticCodes.resultMismatch,
            message:
                'The StarCraft object atlas result did not match its batch.',
            filePath: context.identity.installationPath,
            remediation: 'Repair the application or report the helper error.',
          ),
        ],
      );
    }

    return ObjectSpriteAtlasBatchResult(
      frames: {
        for (final entry in result.entries)
          entry.key: ObjectSpriteRgbaFrame.fromEntry(entry),
      },
      unsupportedObjects: result.unsupportedObjects,
      diagnostics: result.diagnostics,
    );
  }

  Future<void> cancel(String operationId) => gateway.cancel(operationId);

  void _validateBatch(
    ObjectSpriteAtlasContext context,
    List<StarCraftObjectGraphicKey> objectKeys,
  ) {
    if (objectKeys.isEmpty ||
        objectKeys.length > StarCraftObjectAtlasRequest.maximumObjects) {
      throw RangeError.range(
        objectKeys.length,
        1,
        StarCraftObjectAtlasRequest.maximumObjects,
        'objectKeys.length',
      );
    }
    final allowed = context.objectKeys.toSet();
    StarCraftObjectGraphicKey? previous;
    for (final key in objectKeys) {
      if (!allowed.contains(key) ||
          (previous != null && previous.compareTo(key) >= 0)) {
        throw ArgumentError.value(
          objectKeys,
          'objectKeys',
          'Must be a sorted unique subset of the object context keys.',
        );
      }
      previous = key;
    }
  }
}

int? _playerColor(int owner) => owner >= 0 && owner <= 7 ? owner : null;

List<StarCraftUnsupportedObjectGraphic> _failedObjects(
  List<StarCraftObjectGraphicKey> keys,
) {
  return [
    for (final key in keys)
      StarCraftUnsupportedObjectGraphic(
        key: key,
        code: StarCraftObjectAtlasDiagnosticCodes.renderFailed,
      ),
  ];
}

bool _sameIdentityMetadata(
  StarCraftObjectAtlasResult result,
  ObjectSpriteAtlasIdentity identity,
) {
  return result.storageProduct == identity.storageProduct &&
      result.storageBuildNumber == identity.storageBuildNumber &&
      result.helperVersion == identity.helperVersion &&
      result.cascLibRevision == identity.cascLibRevision;
}

bool _sameRequest(
  StarCraftObjectAtlasRequest left,
  StarCraftObjectAtlasRequest right,
) {
  return left.operationId == right.operationId &&
      _normalizeWindowsPath(left.installationPath) ==
          _normalizeWindowsPath(right.installationPath) &&
      left.tileset == right.tileset &&
      _sameKeys(left.objects, right.objects);
}

bool _sameKeys(
  List<StarCraftObjectGraphicKey> left,
  List<StarCraftObjectGraphicKey> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _normalizeWindowsPath(String path) {
  var normalized = path.replaceAll('/', r'\');
  while (normalized.length > 3 && normalized.endsWith(r'\')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized.toLowerCase();
}

EditorDiagnostic _diagnostic({
  required String code,
  required String message,
  required String filePath,
  required String remediation,
  String? rawDetails,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
    filePath: filePath,
    remediation: remediation,
    rawDetails: rawDetails,
  );
}
