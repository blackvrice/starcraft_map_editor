import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_tile_atlas_loader.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture_cache.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture_controller.dart';

void main() {
  testWidgets('creates a disposable 32x32 ui.Image from RGBA bytes', (
    tester,
  ) async {
    final bytes = Uint8List(32 * 32 * 4);
    for (var index = 0; index < bytes.length; index += 4) {
      bytes[index] = 10;
      bytes[index + 1] = 20;
      bytes[index + 2] = 30;
      bytes[index + 3] = 255;
    }

    final texture = await tester.runAsync(
      () => const UiTerrainTileTextureFactory().create(bytes),
    );

    expect(texture, isNotNull);
    expect(texture, isA<UiTerrainTileTexture>());
    final resolvedTexture = texture!;
    expect(resolvedTexture.width, 32);
    expect(resolvedTexture.height, 32);
    resolvedTexture.dispose();
  });

  test('rejects RGBA buffers with the wrong byte length', () async {
    await expectLater(
      const UiTerrainTileTextureFactory().create(Uint8List(12)),
      throwsArgumentError,
    );
  });

  test('LRU cache promotes hits and disposes evicted and cleared textures', () {
    final cache = TerrainTileTextureCache(maximumBytes: 2 * 32 * 32 * 4);
    final identity = _identity(Object());
    final first = _FakeTexture();
    final second = _FakeTexture();
    final third = _FakeTexture();
    final firstKey = TerrainTileTextureKey(identity: identity, rawValue: 1);
    final secondKey = TerrainTileTextureKey(identity: identity, rawValue: 2);
    final thirdKey = TerrainTileTextureKey(identity: identity, rawValue: 3);

    expect(cache.put(firstKey, first), isTrue);
    expect(cache.put(secondKey, second), isTrue);
    expect(cache.currentBytes, 2 * 32 * 32 * 4);
    expect(cache.get(firstKey), same(first));
    expect(cache.put(thirdKey, third), isTrue);

    expect(cache.containsKey(firstKey), isTrue);
    expect(cache.containsKey(secondKey), isFalse);
    expect(cache.containsKey(thirdKey), isTrue);
    expect(first.disposed, isFalse);
    expect(second.disposed, isTrue);
    expect(third.disposed, isFalse);

    cache.clear();
    expect(first.disposed, isTrue);
    expect(third.disposed, isTrue);
    expect(cache.length, 0);
    expect(cache.currentBytes, 0);
    cache.dispose();
  });

  test(
    'LRU cache disposes replacements and entries larger than its budget',
    () {
      final cache = TerrainTileTextureCache(maximumBytes: 32 * 32 * 4);
      final key = TerrainTileTextureKey(
        identity: _identity(Object()),
        rawValue: 7,
      );
      final first = _FakeTexture();
      final replacement = _FakeTexture();
      final tooLarge = _FakeTexture(width: 64, height: 64);

      expect(cache.put(key, first), isTrue);
      expect(cache.put(key, replacement), isTrue);
      expect(first.disposed, isTrue);
      expect(replacement.disposed, isFalse);
      expect(
        cache.put(
          TerrainTileTextureKey(identity: key.identity, rawValue: 8),
          tooLarge,
        ),
        isFalse,
      );
      expect(tooLarge.disposed, isTrue);
      expect(cache.peek(key), same(replacement));

      cache.dispose();
      expect(replacement.disposed, isTrue);
      expect(() => cache.get(key), throwsStateError);
    },
  );

  test(
    'controller batches 4097 sorted unique MTXM values as 4096 and 1',
    () async {
      final rawValues = List<int>.generate(4097, (index) => index);
      final views = _decodeViews(rawValues);
      final gateway = _RenderingGateway();
      final factory = _FakeTextureFactory();
      final controller = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: gateway),
        textureFactory: factory,
      );

      final state = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      );

      expect(gateway.requests.map((request) => request.rawValues.length), [
        4096,
        1,
      ]);
      expect(gateway.requests.first.rawValues.first, 0);
      expect(gateway.requests.first.rawValues.last, 4095);
      expect(gateway.requests.last.rawValues, [4096]);
      expect(factory.created, 4097);
      expect(state.status, TerrainTileTextureStatus.ready);
      expect(state.requestedRawValueCount, 4097);
      expect(state.textures, hasLength(4097));
      expect(state.fallbackRawValues, isEmpty);
      expect(state.diagnostics, isEmpty);

      controller.dispose();
      expect(factory.textures, everyElement(_isDisposed));
    },
  );

  test(
    'controller reuses one snapshot and invalidates a refreshed snapshot',
    () async {
      final views = _decodeViews([0, 1]);
      final inspection = _inspection();
      final gateway = _RenderingGateway();
      final factory = _FakeTextureFactory();
      final controller = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: gateway),
        textureFactory: factory,
      );

      final first = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(inspection),
      );
      final firstTextures = first.textures.values.cast<_FakeTexture>().toList();
      final reused = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(inspection),
      );

      expect(gateway.requests, hasLength(1));
      expect(factory.created, 2);
      expect(reused.textures[0], same(first.textures[0]));
      expect(firstTextures, everyElement(_isNotDisposed));

      final refreshed = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      );
      expect(gateway.requests, hasLength(2));
      expect(factory.created, 4);
      expect(firstTextures, everyElement(_isDisposed));
      expect(refreshed.textures[0], isNot(same(first.textures[0])));

      controller.dispose();
    },
  );

  test(
    'controller disposes a stale texture after the generation changes',
    () async {
      final views = _decodeViews([0]);
      final delayedFactory = _DelayedTextureFactory();
      final controller = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: _RenderingGateway()),
        textureFactory: delayedFactory,
      );

      final staleLoad = controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      );
      await delayedFactory.started.future;

      final idle = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.unavailable,
        ),
      );
      final staleTexture = _FakeTexture();
      delayedFactory.completer.complete(staleTexture);
      await staleLoad;

      expect(idle.status, TerrainTileTextureStatus.idle);
      expect(controller.state.status, TerrainTileTextureStatus.idle);
      expect(staleTexture.disposed, isTrue);
      expect(controller.cache.length, 0);
      controller.dispose();
    },
  );

  test(
    'controller isolates unsupported and image decode failures as fallback',
    () async {
      final views = _decodeViews([0, 1, 2, 0x4000]);
      final gateway = _RenderingGateway(unsupported: const {1});
      final factory = _FakeTextureFactory(failOnCreate: 1);
      final controller = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: gateway),
        textureFactory: factory,
      );

      final state = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      );

      expect(state.status, TerrainTileTextureStatus.partial);
      expect(state.textures.keys, [0]);
      expect(state.unsupportedRawValues, [1, 0x4000]);
      expect(state.fallbackRawValues, [1, 2, 0x4000]);
      expect(state.diagnostics.map((diagnostic) => diagnostic.code), [
        TerrainTileTextureDiagnosticCodes.imageDecodeFailed,
      ]);
      controller.dispose();
    },
  );

  test(
    'controller reports cache eviction and retains only the newest tile',
    () async {
      final views = _decodeViews([0, 1]);
      final factory = _FakeTextureFactory();
      final controller = TerrainTileTextureController(
        loader: TerrainTileAtlasLoader(gateway: _RenderingGateway()),
        textureFactory: factory,
        cache: TerrainTileTextureCache(maximumBytes: 32 * 32 * 4),
      );

      final state = await controller.synchronize(
        metadataViews: views.metadata,
        terrainViews: views.terrain,
        assetState: _readyState(_inspection()),
      );

      expect(state.status, TerrainTileTextureStatus.partial);
      expect(state.textures.keys, [1]);
      expect(state.fallbackRawValues, [0]);
      expect(factory.textures.first.disposed, isTrue);
      expect(state.diagnostics.map((diagnostic) => diagnostic.code), [
        TerrainTileTextureDiagnosticCodes.cacheBudgetExceeded,
      ]);
      controller.dispose();
    },
  );
}

Matcher get _isDisposed =>
    predicate<_FakeTexture>((texture) => texture.disposed);

Matcher get _isNotDisposed =>
    predicate<_FakeTexture>((texture) => !texture.disposed);

final class _FakeTexture implements TerrainTileTexture {
  _FakeTexture({this.width = 32, this.height = 32});

  @override
  final int width;

  @override
  final int height;

  bool disposed = false;

  @override
  ui.Image get image => throw UnsupportedError('Fake texture has no image.');

  @override
  void dispose() {
    disposed = true;
  }
}

final class _FakeTextureFactory implements TerrainTileTextureFactory {
  _FakeTextureFactory({this.failOnCreate});

  final int? failOnCreate;
  final List<_FakeTexture> textures = [];
  int created = 0;

  @override
  Future<TerrainTileTexture> create(Uint8List rgbaBytes) async {
    final createIndex = created++;
    if (createIndex == failOnCreate) {
      throw StateError('decode failed');
    }
    final texture = _FakeTexture();
    textures.add(texture);
    return texture;
  }
}

final class _DelayedTextureFactory implements TerrainTileTextureFactory {
  final Completer<void> started = Completer<void>();
  final Completer<TerrainTileTexture> completer =
      Completer<TerrainTileTexture>();

  @override
  Future<TerrainTileTexture> create(Uint8List rgbaBytes) {
    if (!started.isCompleted) {
      started.complete();
    }
    return completer.future;
  }
}

final class _RenderingGateway implements StarCraftTileAtlasGateway {
  _RenderingGateway({this.unsupported = const {}});

  final Set<int> unsupported;
  final List<StarCraftTileAtlasRequest> requests = [];

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    requests.add(request);
    final rendered = [
      for (final rawValue in request.rawValues)
        if (!unsupported.contains(rawValue)) rawValue,
    ];
    final rejected = [
      for (final rawValue in request.rawValues)
        if (unsupported.contains(rawValue)) rawValue,
    ];
    final columns = rendered.isEmpty ? 0 : rendered.length.clamp(1, 64);
    final rows = rendered.isEmpty
        ? 0
        : (rendered.length + columns - 1) ~/ columns;
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: 32,
      columns: columns,
      rows: rows,
      rawValues: rendered,
      rgbaBytes: Uint8List(columns * rows * 32 * 32 * 4),
      unsupportedRawValues: rejected,
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.3.0',
      cascLibRevision: 'pinned-casc',
    );
  }
}

TerrainTileAtlasIdentity _identity(Object snapshot) {
  return TerrainTileAtlasIdentity(
    installationPath: r'C:\Games\StarCraft',
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.3.0',
    cascLibRevision: 'pinned-casc',
    tileset: StarCraftTilesetAssetSet.jungle,
    inspectionSnapshot: snapshot,
  );
}

({ChkMetadataViews metadata, ChkTerrainViews terrain}) _decodeViews(
  List<int> rawValues,
) {
  final dimensions = Uint8List(4);
  ByteData.sublistView(dimensions)
    ..setUint16(0, rawValues.length, Endian.little)
    ..setUint16(2, 1, Endian.little);
  final mtxm = Uint8List(rawValues.length * 2);
  final mtxmData = ByteData.sublistView(mtxm);
  for (var index = 0; index < rawValues.length; index++) {
    mtxmData.setUint16(index * 2, rawValues[index], Endian.little);
  }
  final document = _documentFromSections([
    _section('DIM ', dimensions),
    _section('ERA ', [4, 0]),
    _section('MTXM', mtxm),
  ]);
  return (
    metadata: const ChkMetadataViewDecoder().decode(document),
    terrain: const ChkTerrainViewDecoder().decode(document),
  );
}

StarCraftDataAssetSettingsState _readyState(
  StarCraftDataAssetInspection inspection,
) {
  return StarCraftDataAssetSettingsState(
    status: StarCraftDataAssetSettingsStatus.ready,
    configuredPath: inspection.installationPath,
    inspection: inspection,
  );
}

StarCraftDataAssetInspection _inspection() {
  return StarCraftDataAssetInspection(
    installationPath: r'C:\Games\StarCraft',
    requiredAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    foundAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.3.0',
    cascLibRevision: 'pinned-casc',
  );
}

RawChkDocument _documentFromSections(List<RawChkSection> sections) {
  var sourceOffset = 0;
  final positioned = <RawChkSection>[];
  for (final section in sections) {
    positioned.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: sourceOffset,
      ),
    );
    sourceOffset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(sections: positioned, sourceLength: sourceOffset);
}

RawChkSection _section(String name, List<int> payload) {
  return RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: payload.length,
    payload: payload,
    sourceOffset: 0,
  );
}
