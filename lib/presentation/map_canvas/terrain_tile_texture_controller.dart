import 'dart:async';
import 'dart:collection';

import '../../application/settings/starcraft_data_asset_settings_controller.dart';
import '../../application/terrain/terrain_tile_atlas_loader.dart';
import '../../domain/chk/typed/chk_metadata_views.dart';
import '../../domain/chk/typed/chk_terrain_views.dart';
import '../../domain/diagnostics/editor_diagnostic.dart';
import 'terrain_tile_texture.dart';
import 'terrain_tile_texture_cache.dart';

abstract final class TerrainTileTextureDiagnosticCodes {
  static const imageDecodeFailed = 'SC_CASC_TILE_IMAGE_DECODE_FAILED';
  static const invalidImageSize = 'SC_CASC_TILE_IMAGE_SIZE_INVALID';
  static const cacheBudgetExceeded = 'SC_CASC_TILE_TEXTURE_CACHE_BUDGET';
}

enum TerrainTileTextureStatus { idle, loading, ready, partial, unavailable }

final class TerrainTileTextureState {
  TerrainTileTextureState({
    required this.status,
    this.identity,
    this.requestedRawValueCount = 0,
    Map<int, TerrainTileTexture> textures = const {},
    List<int> unsupportedRawValues = const [],
    List<int> fallbackRawValues = const [],
    List<EditorDiagnostic> diagnostics = const [],
  }) : textures = Map.unmodifiable(textures),
       unsupportedRawValues = List.unmodifiable(unsupportedRawValues),
       fallbackRawValues = List.unmodifiable(fallbackRawValues),
       diagnostics = List.unmodifiable(diagnostics);

  const TerrainTileTextureState.idle()
    : status = TerrainTileTextureStatus.idle,
      identity = null,
      requestedRawValueCount = 0,
      textures = const {},
      unsupportedRawValues = const [],
      fallbackRawValues = const [],
      diagnostics = const [];

  final TerrainTileTextureStatus status;
  final TerrainTileAtlasIdentity? identity;
  final int requestedRawValueCount;
  final Map<int, TerrainTileTexture> textures;
  final List<int> unsupportedRawValues;
  final List<int> fallbackRawValues;
  final List<EditorDiagnostic> diagnostics;

  bool get isLoading => status == TerrainTileTextureStatus.loading;
}

final class TerrainTileTextureController {
  TerrainTileTextureController({
    required this.loader,
    this.textureFactory = const UiTerrainTileTextureFactory(),
    TerrainTileTextureCache? cache,
  }) : cache = cache ?? TerrainTileTextureCache();

  static const batchSize = 4096;
  static const tileSize = 32;

  final TerrainTileAtlasLoader loader;
  final TerrainTileTextureFactory textureFactory;
  final TerrainTileTextureCache cache;
  final StreamController<TerrainTileTextureState> _changes =
      StreamController.broadcast(sync: true);

  TerrainTileTextureState _state = const TerrainTileTextureState.idle();
  TerrainTileAtlasIdentity? _activeIdentity;
  int _generation = 0;
  bool _disposed = false;

  TerrainTileTextureState get state => _state;

  Stream<TerrainTileTextureState> get changes => _changes.stream;

  Future<TerrainTileTextureState> synchronize({
    required ChkMetadataViews metadataViews,
    required ChkTerrainViews terrainViews,
    required StarCraftDataAssetSettingsState assetState,
  }) async {
    _ensureUsable();
    final generation = ++_generation;
    final context = loader.createContext(
      metadataViews: metadataViews,
      terrainViews: terrainViews,
      assetState: assetState,
    );
    if (context == null) {
      _activeIdentity = null;
      cache.clear();
      return _emit(const TerrainTileTextureState.idle());
    }

    if (_activeIdentity != context.identity) {
      cache.clear();
      _activeIdentity = context.identity;
    }

    final unsupported = SplayTreeSet<int>.of(context.unsupportedRawValues);
    final failed = SplayTreeSet<int>();
    final diagnostics = <EditorDiagnostic>[];
    _emit(
      _snapshot(
        status: TerrainTileTextureStatus.loading,
        context: context,
        unsupported: unsupported,
        failed: failed,
        diagnostics: diagnostics,
      ),
    );

    final missingRawValues = [
      for (final rawValue in context.renderableRawValues)
        if (!cache.containsKey(_key(context.identity, rawValue))) rawValue,
    ];
    for (
      var offset = 0;
      offset < missingRawValues.length;
      offset += batchSize
    ) {
      final end = (offset + batchSize).clamp(0, missingRawValues.length);
      final rawBatch = missingRawValues.sublist(offset, end);
      final result = await loader.loadBatch(
        context: context,
        rawValues: rawBatch,
      );
      if (!_isCurrent(generation)) {
        return _state;
      }

      diagnostics.addAll(result.diagnostics);
      unsupported.addAll(result.unsupportedRawValues);
      final created = <int, TerrainTileTexture>{};
      for (final entry in result.rgbaTiles.entries) {
        try {
          final texture = await textureFactory.create(entry.value);
          if (!_isCurrent(generation)) {
            texture.dispose();
            _disposeTextures(created.values);
            return _state;
          }
          if (texture.width != tileSize || texture.height != tileSize) {
            texture.dispose();
            failed.add(entry.key);
            diagnostics.add(
              _diagnostic(
                code: TerrainTileTextureDiagnosticCodes.invalidImageSize,
                message:
                    'Decoded terrain tile ${entry.key} was not 32x32 pixels.',
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
              code: TerrainTileTextureDiagnosticCodes.imageDecodeFailed,
              message: 'Terrain tile ${entry.key} could not be decoded.',
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
          status: TerrainTileTextureStatus.loading,
          context: context,
          unsupported: unsupported,
          failed: failed,
          diagnostics: diagnostics,
        ),
      );
    }

    if (!_isCurrent(generation)) {
      return _state;
    }
    final finalState = _snapshot(
      status: TerrainTileTextureStatus.ready,
      context: context,
      unsupported: unsupported,
      failed: failed,
      diagnostics: diagnostics,
      includeCacheDiagnostic: true,
    );
    final status =
        finalState.fallbackRawValues.isEmpty && finalState.diagnostics.isEmpty
        ? TerrainTileTextureStatus.ready
        : finalState.textures.isNotEmpty
        ? TerrainTileTextureStatus.partial
        : TerrainTileTextureStatus.unavailable;
    return _emit(
      TerrainTileTextureState(
        status: status,
        identity: finalState.identity,
        requestedRawValueCount: finalState.requestedRawValueCount,
        textures: finalState.textures,
        unsupportedRawValues: finalState.unsupportedRawValues,
        fallbackRawValues: finalState.fallbackRawValues,
        diagnostics: finalState.diagnostics,
      ),
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _activeIdentity = null;
    cache.dispose();
    _changes.close();
  }

  TerrainTileTextureState _snapshot({
    required TerrainTileTextureStatus status,
    required TerrainTileAtlasContext context,
    required Set<int> unsupported,
    required Set<int> failed,
    required List<EditorDiagnostic> diagnostics,
    bool includeCacheDiagnostic = false,
  }) {
    final textures = <int, TerrainTileTexture>{};
    final fallback = SplayTreeSet<int>.of(unsupported)..addAll(failed);
    var hasCacheMiss = false;
    for (final rawValue in context.renderableRawValues) {
      final texture = cache.peek(_key(context.identity, rawValue));
      if (texture == null) {
        fallback.add(rawValue);
        if (!unsupported.contains(rawValue) && !failed.contains(rawValue)) {
          hasCacheMiss = true;
        }
      } else {
        textures[rawValue] = texture;
      }
    }
    final snapshotDiagnostics = List<EditorDiagnostic>.of(diagnostics);
    if (includeCacheDiagnostic && hasCacheMiss) {
      snapshotDiagnostics.add(
        _diagnostic(
          code: TerrainTileTextureDiagnosticCodes.cacheBudgetExceeded,
          message: 'Some terrain textures do not fit in the texture cache.',
          filePath: context.identity.installationPath,
          remediation:
              'Use fallback rendering or reduce the number of unique tiles.',
        ),
      );
    }
    return TerrainTileTextureState(
      status: status,
      identity: context.identity,
      requestedRawValueCount:
          context.renderableRawValues.length +
          context.unsupportedRawValues.length,
      textures: textures,
      unsupportedRawValues: unsupported.toList(growable: false),
      fallbackRawValues: fallback.toList(growable: false),
      diagnostics: snapshotDiagnostics,
    );
  }

  TerrainTileTextureState _emit(TerrainTileTextureState state) {
    if (_disposed) {
      return _state;
    }
    _state = state;
    _changes.add(state);
    return state;
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('The terrain tile texture controller is disposed.');
    }
  }
}

TerrainTileTextureKey _key(TerrainTileAtlasIdentity identity, int rawValue) {
  return TerrainTileTextureKey(identity: identity, rawValue: rawValue);
}

void _disposeTextures(Iterable<TerrainTileTexture> textures) {
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
