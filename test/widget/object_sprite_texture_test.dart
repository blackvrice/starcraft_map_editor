import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/objects/object_sprite_atlas_loader.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_document.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_parser.dart';
import 'package:starcraft_map_editor/domain/chk/raw_chk_section.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_metadata_views.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_object_views.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/object_sprite_texture.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/object_sprite_texture_cache.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/object_sprite_texture_controller.dart';

void main() {
  test('variable-size LRU cache disposes evictions and replacements', () {
    final identity = _identity(Object());
    final cache = ObjectSpriteTextureCache(maximumBytes: 2 * 3 * 4 * 2);
    final firstKey = _cacheKey(identity, 1);
    final secondKey = _cacheKey(identity, 2);
    final thirdKey = _cacheKey(identity, 3);
    final first = _FakeTexture(id: 1);
    final second = _FakeTexture(id: 2);
    final third = _FakeTexture(id: 3);

    expect(cache.put(firstKey, first), isTrue);
    expect(cache.put(secondKey, second), isTrue);
    expect(cache.get(firstKey), same(first));
    expect(cache.put(thirdKey, third), isTrue);

    expect(cache.containsKey(firstKey), isTrue);
    expect(cache.containsKey(secondKey), isFalse);
    expect(cache.containsKey(thirdKey), isTrue);
    expect(second.disposed, isTrue);

    final replacement = _FakeTexture(id: 1);
    expect(cache.put(firstKey, replacement), isTrue);
    expect(first.disposed, isTrue);
    cache.dispose();
    expect(replacement.disposed, isTrue);
    expect(third.disposed, isTrue);
  });

  test(
    'controller batches 257 keys as 256 and 1 and reuses its cache',
    () async {
      final views = _views(List<int>.generate(257, (index) => index));
      final inspection = _inspection();
      final gateway = _RenderingGateway();
      final factory = _FakeTextureFactory();
      final controller = ObjectSpriteTextureController(
        loader: ObjectSpriteAtlasLoader(gateway: gateway),
        textureFactory: factory,
      );

      final state = await controller.synchronize(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(inspection),
      );
      final reused = await controller.synchronize(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(inspection),
      );

      expect(gateway.requests.map((request) => request.objects.length), [
        256,
        1,
      ]);
      expect(gateway.requests.first.objects.first.id, 0);
      expect(gateway.requests.last.objects.single.id, 256);
      expect(state.status, ObjectSpriteTextureStatus.ready);
      expect(state.requestedObjectCount, 257);
      expect(state.textures, hasLength(257));
      expect(reused.textures.values.first, same(state.textures.values.first));
      expect(factory.created, 257);
      controller.dispose();
      expect(factory.textures, everyElement(_isDisposed));
    },
  );

  test('new inspection invalidates cached object textures', () async {
    final views = _views([0, 1]);
    final gateway = _RenderingGateway();
    final factory = _FakeTextureFactory();
    final controller = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: gateway),
      textureFactory: factory,
    );

    final first = await controller.synchronize(
      metadataViews: views.metadata,
      objectViews: views.objects,
      assetState: _readyState(_inspection()),
    );
    final oldTextures = first.textures.values.cast<_FakeTexture>().toList();
    await controller.synchronize(
      metadataViews: views.metadata,
      objectViews: views.objects,
      assetState: _readyState(_inspection()),
    );

    expect(gateway.requests, hasLength(2));
    expect(oldTextures, everyElement(_isDisposed));
    controller.dispose();
  });

  test(
    'clear cancels the active request and ignores its stale result',
    () async {
      final views = _views([0]);
      final gateway = _DelayedGateway();
      final factory = _FakeTextureFactory();
      final controller = ObjectSpriteTextureController(
        loader: ObjectSpriteAtlasLoader(gateway: gateway),
        textureFactory: factory,
      );

      final staleLoad = controller.synchronize(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyState(_inspection()),
      );
      await gateway.started.future;
      final operationId = gateway.request!.operationId;

      final cleared = controller.clear();
      await Future<void>.delayed(Duration.zero);
      gateway.complete();
      await staleLoad;

      expect(cleared.status, ObjectSpriteTextureStatus.idle);
      expect(controller.state.status, ObjectSpriteTextureStatus.idle);
      expect(gateway.cancelled, [operationId]);
      expect(factory.created, 0);
      expect(controller.cache.length, 0);
      controller.dispose();
    },
  );

  test('unsupported and image failures remain marker fallback', () async {
    final views = _views([0, 1, 2]);
    final gateway = _RenderingGateway(unsupportedIds: const {1});
    final factory = _FakeTextureFactory(failIds: const {2});
    final controller = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: gateway),
      textureFactory: factory,
    );

    final state = await controller.synchronize(
      metadataViews: views.metadata,
      objectViews: views.objects,
      assetState: _readyState(_inspection()),
    );

    expect(state.status, ObjectSpriteTextureStatus.partial);
    expect(state.textures.keys.map((key) => key.id), [0]);
    expect(state.unsupportedObjects.single.key.id, 1);
    expect(state.fallbackObjects.map((key) => key.id), [1, 2]);
    expect(state.diagnostics.map((diagnostic) => diagnostic.code), [
      'SC_CASC_OBJECT_GRP_MISSING',
      ObjectSpriteTextureDiagnosticCodes.imageDecodeFailed,
    ]);
    controller.dispose();
  });

  test('cache budget keeps only the newest variable-size object', () async {
    final views = _views([0, 1]);
    final factory = _FakeTextureFactory();
    final controller = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: _RenderingGateway()),
      textureFactory: factory,
      cache: ObjectSpriteTextureCache(maximumBytes: 2 * 3 * 4),
    );

    final state = await controller.synchronize(
      metadataViews: views.metadata,
      objectViews: views.objects,
      assetState: _readyState(_inspection()),
    );

    expect(state.status, ObjectSpriteTextureStatus.partial);
    expect(state.textures.keys.single.id, 1);
    expect(state.fallbackObjects.single.id, 0);
    expect(state.diagnostics.map((diagnostic) => diagnostic.code), [
      ObjectSpriteTextureDiagnosticCodes.cacheBudgetExceeded,
    ]);
    expect(factory.textures.first.disposed, isTrue);
    controller.dispose();
  });
}

final class _RenderingGateway implements StarCraftObjectAtlasGateway {
  _RenderingGateway({this.unsupportedIds = const {}});

  final Set<int> unsupportedIds;
  final List<StarCraftObjectAtlasRequest> requests = [];
  final List<String> cancelled = [];

  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
  }

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    requests.add(request);
    return _resultFor(request, unsupportedIds: unsupportedIds);
  }
}

final class _DelayedGateway implements StarCraftObjectAtlasGateway {
  final Completer<void> started = Completer<void>();
  final Completer<StarCraftObjectAtlasResult> result =
      Completer<StarCraftObjectAtlasResult>();
  final List<String> cancelled = [];
  StarCraftObjectAtlasRequest? request;

  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
  }

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) {
    this.request = request;
    started.complete();
    return result.future;
  }

  void complete() {
    result.complete(_resultFor(request!));
  }
}

StarCraftObjectAtlasResult _resultFor(
  StarCraftObjectAtlasRequest request, {
  Set<int> unsupportedIds = const {},
}) {
  return StarCraftObjectAtlasResult(
    request: request,
    entries: [
      for (final key in request.objects)
        if (!unsupportedIds.contains(key.id))
          StarCraftObjectAtlasEntry(
            key: key,
            spriteId: key.id,
            imageId: key.id,
            width: 2,
            height: 3,
            anchorX: 1,
            anchorY: 2,
            frameIndex: 0,
            rgbaBytes: Uint8List(2 * 3 * 4),
          ),
    ],
    unsupportedObjects: [
      for (final key in request.objects)
        if (unsupportedIds.contains(key.id))
          StarCraftUnsupportedObjectGraphic(
            key: key,
            code: 'SC_CASC_OBJECT_GRP_MISSING',
          ),
    ],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.4.0',
    cascLibRevision: 'pinned-casc',
    totalAssetBytes: 4096,
  );
}

final class _FakeTextureFactory implements ObjectSpriteTextureFactory {
  _FakeTextureFactory({this.failIds = const {}});

  final Set<int> failIds;
  final List<_FakeTexture> textures = [];
  int created = 0;

  @override
  Future<ObjectSpriteTexture> create(ObjectSpriteRgbaFrame frame) async {
    created++;
    if (failIds.contains(frame.key.id)) {
      throw StateError('decode failed');
    }
    final texture = _FakeTexture(
      id: frame.key.id,
      width: frame.width,
      height: frame.height,
      anchorX: frame.anchorX,
      anchorY: frame.anchorY,
    );
    textures.add(texture);
    return texture;
  }
}

final class _FakeTexture implements ObjectSpriteTexture {
  _FakeTexture({
    required this.id,
    this.width = 2,
    this.height = 3,
    this.anchorX = 1,
    this.anchorY = 2,
  });

  final int id;
  bool disposed = false;

  @override
  int get spriteId => id;

  @override
  int get imageId => id;

  @override
  final int width;

  @override
  final int height;

  @override
  final int anchorX;

  @override
  final int anchorY;

  @override
  int get frameIndex => 0;

  @override
  ui.Image get image => throw UnsupportedError('Fake texture has no image.');

  @override
  void dispose() {
    disposed = true;
  }
}

Matcher get _isDisposed =>
    predicate<_FakeTexture>((texture) => texture.disposed);

ObjectSpriteTextureCacheKey _cacheKey(
  ObjectSpriteAtlasIdentity identity,
  int id,
) {
  return ObjectSpriteTextureCacheKey(
    identity: identity,
    objectKey: StarCraftObjectGraphicKey(
      kind: StarCraftObjectGraphicKind.unit,
      id: id,
      playerColor: 0,
    ),
  );
}

ObjectSpriteAtlasIdentity _identity(Object snapshot) {
  return ObjectSpriteAtlasIdentity(
    installationPath: r'C:\Games\StarCraft',
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.4.0',
    cascLibRevision: 'pinned-casc',
    tileset: StarCraftTilesetAssetSet.jungle,
    inspectionSnapshot: snapshot,
  );
}

({ChkMetadataViews metadata, ChkObjectViews objects}) _views(
  List<int> unitTypes,
) {
  final unitPayload = Uint8List(
    unitTypes.length * ChkUnitPlacement.recordLength,
  );
  final data = ByteData.sublistView(unitPayload);
  for (var index = 0; index < unitTypes.length; index++) {
    final offset = index * ChkUnitPlacement.recordLength;
    data
      ..setUint16(offset + 8, unitTypes[index], Endian.little)
      ..setUint8(offset + 16, 0);
  }
  final document = _documentFromSections([
    _section('ERA ', [4, 0]),
    _section('UNIT', unitPayload),
  ]);
  return (
    metadata: const ChkMetadataViewDecoder().decode(document),
    objects: const ChkObjectViewDecoder().decode(document),
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
    helperVersion: '0.4.0',
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
