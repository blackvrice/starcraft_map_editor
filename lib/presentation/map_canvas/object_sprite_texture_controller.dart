import 'dart:async';
import 'dart:collection';

import '../../application/objects/object_sprite_atlas_loader.dart';
import '../../application/ports/starcraft_object_atlas_gateway.dart';
import '../../application/settings/starcraft_data_asset_settings_controller.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../../domain/chk/typed/chk_object_views.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'object_sprite_texture.dart';
import 'object_sprite_texture_cache.dart';

abstract final class ObjectSpriteTextureDiagnosticCodes {
  static const imageDecodeFailed = 'SC_CASC_OBJECT_IMAGE_DECODE_FAILED';
  static const invalidImageSize = 'SC_CASC_OBJECT_IMAGE_SIZE_INVALID';
  static const cacheBudgetExceeded = 'SC_CASC_OBJECT_TEXTURE_CACHE_BUDGET';
}

enum ObjectSpriteTextureStatus { idle, loading, ready, partial, unavailable }

final class ObjectSpriteTextureState {
  ObjectSpriteTextureState({
    required this.status,
    this.identity,
    this.requestedObjectCount = 0,
    Map<StarCraftObjectGraphicKey, ObjectSpriteTexture> textures = const {},
    List<StarCraftUnsupportedObjectGraphic> unsupportedObjects = const [],
    List<StarCraftObjectGraphicKey> fallbackObjects = const [],
    List<EditorDiagnostic> diagnostics = const [],
  }) : textures = Map.unmodifiable(textures),
       unsupportedObjects = List.unmodifiable(unsupportedObjects),
       fallbackObjects = List.unmodifiable(fallbackObjects),
       diagnostics = List.unmodifiable(diagnostics);

  const ObjectSpriteTextureState.idle()
    : status = ObjectSpriteTextureStatus.idle,
      identity = null,
      requestedObjectCount = 0,
      textures = const {},
      unsupportedObjects = const [],
      fallbackObjects = const [],
      diagnostics = const [];

  final ObjectSpriteTextureStatus status;
  final ObjectSpriteAtlasIdentity? identity;
  final int requestedObjectCount;
  final Map<StarCraftObjectGraphicKey, ObjectSpriteTexture> textures;
  final List<StarCraftUnsupportedObjectGraphic> unsupportedObjects;
  final List<StarCraftObjectGraphicKey> fallbackObjects;
  final List<EditorDiagnostic> diagnostics;

  bool get isLoading => status == ObjectSpriteTextureStatus.loading;
}

final class ObjectSpriteTextureController {
  ObjectSpriteTextureController({
    required this.loader,
    this.textureFactory = const UiObjectSpriteTextureFactory(),
    ObjectSpriteTextureCache? cache,
  }) : cache = cache ?? ObjectSpriteTextureCache();

  static const batchSize = StarCraftObjectAtlasRequest.maximumObjects;

  final ObjectSpriteAtlasLoader loader;
  final ObjectSpriteTextureFactory textureFactory;
  final ObjectSpriteTextureCache cache;
  final StreamController<ObjectSpriteTextureState> _changes =
      StreamController.broadcast(sync: true);

  ObjectSpriteTextureState _state = const ObjectSpriteTextureState.idle();
  ObjectSpriteAtlasIdentity? _activeIdentity;
  String? _activeOperationId;
  int _generation = 0;
  int _operationSequence = 0;
  bool _disposed = false;

  ObjectSpriteTextureState get state => _state;

  Stream<ObjectSpriteTextureState> get changes => _changes.stream;

  Future<ObjectSpriteTextureState> synchronize({
    required ChkMetadataViews metadataViews,
    required ChkObjectViews objectViews,
    required StarCraftDataAssetSettingsState assetState,
  }) async {
    _ensureUsable();
    _cancelActiveOperation();
    final generation = ++_generation;
    final context = loader.createContext(
      metadataViews: metadataViews,
      objectViews: objectViews,
      assetState: assetState,
    );
    if (context == null) {
      return _clearState();
    }

    if (_activeIdentity != context.identity) {
      cache.clear();
      _activeIdentity = context.identity;
    }

    final unsupportedByKey =
        SplayTreeMap<
          StarCraftObjectGraphicKey,
          StarCraftUnsupportedObjectGraphic
        >();
    final failed = SplayTreeSet<StarCraftObjectGraphicKey>();
    final diagnostics = <EditorDiagnostic>[];
    _emit(
      _snapshot(
        status: ObjectSpriteTextureStatus.loading,
        context: context,
        unsupportedByKey: unsupportedByKey,
        failed: failed,
        diagnostics: diagnostics,
      ),
    );

    final missingObjects = [
      for (final objectKey in context.objectKeys)
        if (!cache.containsKey(_key(context.identity, objectKey))) objectKey,
    ];
    for (var offset = 0; offset < missingObjects.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, missingObjects.length);
      final batch = missingObjects.sublist(offset, end);
      final operationId = _nextOperationId(generation);
      _activeOperationId = operationId;
      final result = await loader.loadBatch(
        context: context,
        operationId: operationId,
        objectKeys: batch,
      );
      if (_activeOperationId == operationId) {
        _activeOperationId = null;
      }
      if (!_isCurrent(generation)) {
        return _state;
      }

      diagnostics.addAll(result.diagnostics);
      for (final unsupported in result.unsupportedObjects) {
        unsupportedByKey[unsupported.key] = unsupported;
        if (result.diagnostics.isEmpty) {
          diagnostics.add(
            _diagnostic(
              code: unsupported.code,
              message:
                  '${unsupported.key.kind.wireName} object '
                  '${unsupported.key.id} uses marker fallback.',
              filePath: context.identity.installationPath,
              remediation:
                  'Keep the marker fallback or repair the StarCraft assets.',
            ),
          );
        }
      }
      final created = <StarCraftObjectGraphicKey, ObjectSpriteTexture>{};
      for (final entry in result.frames.entries) {
        try {
          final texture = await textureFactory.create(entry.value);
          if (!_isCurrent(generation)) {
            texture.dispose();
            _disposeTextures(created.values);
            return _state;
          }
          if (texture.width != entry.value.width ||
              texture.height != entry.value.height) {
            texture.dispose();
            failed.add(entry.key);
            diagnostics.add(
              _diagnostic(
                code: ObjectSpriteTextureDiagnosticCodes.invalidImageSize,
                message:
                    'Decoded object ${entry.key.id} image dimensions did not '
                    'match its atlas entry.',
                filePath: context.identity.installationPath,
                remediation: 'Repair the application or report the decoder.',
              ),
            );
            continue;
          }
          created[entry.key] = texture;
        } catch (error) {
          failed.add(entry.key);
          diagnostics.add(
            _diagnostic(
              code: ObjectSpriteTextureDiagnosticCodes.imageDecodeFailed,
              message: 'Object ${entry.key.id} image could not be decoded.',
              filePath: context.identity.installationPath,
              remediation: 'Retry or repair the application installation.',
              rawDetails: error.toString(),
            ),
          );
        }
      }

      if (!_isCurrent(generation)) {
        _disposeTextures(created.values);
        return _state;
      }
      for (final entry in created.entries) {
        cache.put(_key(context.identity, entry.key), entry.value);
      }
      _emit(
        _snapshot(
          status: ObjectSpriteTextureStatus.loading,
          context: context,
          unsupportedByKey: unsupportedByKey,
          failed: failed,
          diagnostics: diagnostics,
        ),
      );
    }

    if (!_isCurrent(generation)) {
      return _state;
    }
    final finalState = _snapshot(
      status: ObjectSpriteTextureStatus.ready,
      context: context,
      unsupportedByKey: unsupportedByKey,
      failed: failed,
      diagnostics: diagnostics,
      includeCacheDiagnostic: true,
    );
    final status =
        finalState.fallbackObjects.isEmpty && finalState.diagnostics.isEmpty
        ? ObjectSpriteTextureStatus.ready
        : finalState.textures.isNotEmpty
        ? ObjectSpriteTextureStatus.partial
        : ObjectSpriteTextureStatus.unavailable;
    return _emit(
      ObjectSpriteTextureState(
        status: status,
        identity: finalState.identity,
        requestedObjectCount: finalState.requestedObjectCount,
        textures: finalState.textures,
        unsupportedObjects: finalState.unsupportedObjects,
        fallbackObjects: finalState.fallbackObjects,
        diagnostics: finalState.diagnostics,
      ),
    );
  }

  ObjectSpriteTextureState clear() {
    _ensureUsable();
    _cancelActiveOperation();
    _generation++;
    return _clearState();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _cancelActiveOperation();
    _disposed = true;
    _generation++;
    _activeIdentity = null;
    cache.dispose();
    _changes.close();
  }

  ObjectSpriteTextureState _snapshot({
    required ObjectSpriteTextureStatus status,
    required ObjectSpriteAtlasContext context,
    required Map<StarCraftObjectGraphicKey, StarCraftUnsupportedObjectGraphic>
    unsupportedByKey,
    required Set<StarCraftObjectGraphicKey> failed,
    required List<EditorDiagnostic> diagnostics,
    bool includeCacheDiagnostic = false,
  }) {
    final textures = <StarCraftObjectGraphicKey, ObjectSpriteTexture>{};
    final fallback = SplayTreeSet<StarCraftObjectGraphicKey>.of(
      unsupportedByKey.keys,
    )..addAll(failed);
    var hasCacheMiss = false;
    for (final objectKey in context.objectKeys) {
      final texture = cache.get(_key(context.identity, objectKey));
      if (texture == null) {
        fallback.add(objectKey);
        if (!unsupportedByKey.containsKey(objectKey) &&
            !failed.contains(objectKey)) {
          hasCacheMiss = true;
        }
      } else {
        textures[objectKey] = texture;
      }
    }
    final snapshotDiagnostics = List<EditorDiagnostic>.of(diagnostics);
    if (includeCacheDiagnostic && hasCacheMiss) {
      snapshotDiagnostics.add(
        _diagnostic(
          code: ObjectSpriteTextureDiagnosticCodes.cacheBudgetExceeded,
          message: 'Some object textures do not fit in the texture cache.',
          filePath: context.identity.installationPath,
          remediation:
              'Use marker fallback or reduce the number of unique objects.',
        ),
      );
    }
    return ObjectSpriteTextureState(
      status: status,
      identity: context.identity,
      requestedObjectCount: context.objectKeys.length,
      textures: textures,
      unsupportedObjects: unsupportedByKey.values.toList(growable: false),
      fallbackObjects: fallback.toList(growable: false),
      diagnostics: snapshotDiagnostics,
    );
  }

  ObjectSpriteTextureState _emit(ObjectSpriteTextureState state) {
    if (_disposed) {
      return _state;
    }
    _state = state;
    _changes.add(state);
    return state;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  ObjectSpriteTextureState _clearState() {
    _activeIdentity = null;
    cache.clear();
    return _emit(const ObjectSpriteTextureState.idle());
  }

  String _nextOperationId(int generation) {
    return 'object-atlas-$generation-${_operationSequence++}';
  }

  void _cancelActiveOperation() {
    final operationId = _activeOperationId;
    _activeOperationId = null;
    if (operationId == null) {
      return;
    }
    unawaited(loader.cancel(operationId).catchError((Object _) {}));
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('The object sprite texture controller is disposed.');
    }
  }
}

ObjectSpriteTextureCacheKey _key(
  ObjectSpriteAtlasIdentity identity,
  StarCraftObjectGraphicKey objectKey,
) {
  return ObjectSpriteTextureCacheKey(identity: identity, objectKey: objectKey);
}

void _disposeTextures(Iterable<ObjectSpriteTexture> textures) {
  for (final texture in textures) {
    texture.dispose();
  }
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
