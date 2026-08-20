import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/objects/object_sprite_atlas_loader.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/object_sprite_texture_controller.dart';

const _mapSize = 256;
const _placementGridSize = 64;
const _placementCount = _placementGridSize * _placementGridSize;
const _uniqueObjectCount = 256;
const _unsupportedObjectCount = 16;
const _textureDimension = 32;
const _textureBytes = _textureDimension * _textureDimension * 4;

void main() {
  testWidgets('profiles 4096 object placements on a 256x256 map', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final gateway = _PerformanceObjectGateway();
    final controller = ObjectSpriteTextureController(
      loader: ObjectSpriteAtlasLoader(gateway: gateway),
    );
    addTearDown(controller.dispose);

    final views = _objectViews();
    final rssBeforeLoad = ProcessInfo.currentRss;
    final loadingStopwatch = Stopwatch()..start();
    final loadedState = await tester.runAsync(
      () => controller.synchronize(
        metadataViews: views.metadata,
        objectViews: views.objects,
        assetState: _readyAssetState(),
      ),
    );
    loadingStopwatch.stop();
    final rssAfterLoad = ProcessInfo.currentRss;
    expect(loadedState, isNotNull);
    final state = loadedState!;

    expect(gateway.requests, hasLength(1));
    expect(gateway.requests.single.objects, hasLength(_uniqueObjectCount));
    expect(state.status, ObjectSpriteTextureStatus.partial);
    expect(
      state.textures,
      hasLength(_uniqueObjectCount - _unsupportedObjectCount),
    );
    expect(state.fallbackObjects, hasLength(_unsupportedObjectCount));
    expect(
      controller.cache.currentBytes,
      (_uniqueObjectCount - _unsupportedObjectCount) * _textureBytes,
    );
    expect(
      controller.cache.currentBytes,
      lessThanOrEqualTo(controller.cache.maximumBytes),
    );
    expect(loadingStopwatch.elapsed, lessThan(const Duration(seconds: 2)));

    final measurements = <MapCanvasPaintMetrics>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: MapCanvas(
            mapWidth: _mapSize,
            mapHeight: _mapSize,
            layerScene: _layerScene(),
            objectSpriteTextureState: state,
            onPaintMeasured: measurements.add,
          ),
        ),
      ),
    );

    final fitted = measurements.last;
    expect(fitted.visitedObjectCount, _placementCount);
    expect(
      fitted.objectTextureCount,
      _placementCount ~/
          _uniqueObjectCount *
          (_uniqueObjectCount - _unsupportedObjectCount),
    );
    expect(
      fitted.objectMarkerCount,
      _placementCount ~/ _uniqueObjectCount * _unsupportedObjectCount,
    );
    expect(fitted.culledObjectCount, 0);
    _expectWithinSmokeCeiling(fitted);

    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.pump();

    final zoomed = measurements.last;
    expect(zoomed.visitedObjectCount, _placementCount);
    expect(zoomed.paintedObjectCount, lessThan(fitted.paintedObjectCount));
    expect(zoomed.culledObjectCount, greaterThan(0));
    _expectWithinSmokeCeiling(zoomed);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('map-canvas'))),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.moveBy(const Offset(80, 50));
    await gesture.up();
    await tester.pump();

    final panned = measurements.last;
    expect(panned.visitedObjectCount, _placementCount);
    expect(panned.paintedObjectCount, greaterThan(0));
    expect(panned.culledObjectCount, greaterThan(0));
    _expectWithinSmokeCeiling(panned);

    debugPrint(
      'OBJECT_SPRITE_256_SMOKE '
      'os=${Platform.operatingSystem} '
      'mode=${kDebugMode ? 'debug' : 'profile-or-release'} '
      'map=${_mapSize}x$_mapSize placements=$_placementCount '
      'unique=$_uniqueObjectCount textures=${state.textures.length} '
      'fallback=${state.fallbackObjects.length} '
      'loadUs=${loadingStopwatch.elapsedMicroseconds} '
      'cacheBytes=${controller.cache.currentBytes} '
      'rssDeltaBytes=${rssAfterLoad - rssBeforeLoad} '
      'fitUs=${fitted.paintDuration.inMicroseconds} '
      'zoomUs=${zoomed.paintDuration.inMicroseconds} '
      'panUs=${panned.paintDuration.inMicroseconds} '
      'fitPainted=${fitted.paintedObjectCount} '
      'zoomPainted=${zoomed.paintedObjectCount} '
      'panPainted=${panned.paintedObjectCount}',
    );

    controller.clear();
    expect(controller.cache.currentBytes, 0);
  });
}

void _expectWithinSmokeCeiling(MapCanvasPaintMetrics metrics) {
  expect(
    metrics.paintDuration,
    lessThan(const Duration(seconds: 1)),
    reason:
        'The debug ceiling catches pathological object painting; '
        'profile-mode frame timing remains the FPS release gate.',
  );
}

({ChkMetadataViews metadata, ChkObjectViews objects}) _objectViews() {
  final payload = Uint8List(_placementCount * ChkUnitPlacement.recordLength);
  final data = ByteData.sublistView(payload);
  for (var index = 0; index < _placementCount; index++) {
    final objectId = index % _uniqueObjectCount;
    final offset = index * ChkUnitPlacement.recordLength;
    data
      ..setUint16(offset + 4, _pixelX(index), Endian.little)
      ..setUint16(offset + 6, _pixelY(index), Endian.little)
      ..setUint16(offset + 8, objectId, Endian.little)
      ..setUint8(offset + 16, objectId % 8);
  }
  final document = _documentFromSections([
    _section('ERA ', const [4, 0]),
    _section('UNIT', payload),
  ]);
  return (
    metadata: const ChkMetadataViewDecoder().decode(document),
    objects: const ChkObjectViewDecoder().decode(document),
  );
}

MapLayerScene _layerScene() {
  return MapLayerScene(
    points: [
      for (var index = 0; index < _placementCount; index++)
        MapLayerPointObject(
          object: MapLayerObjectRef(
            layer: MapLayerType.units,
            sectionIndex: 1,
            recordIndex: index,
          ),
          pixelX: _pixelX(index),
          pixelY: _pixelY(index),
          graphicKey: StarCraftObjectGraphicKey(
            kind: StarCraftObjectGraphicKind.unit,
            id: index % _uniqueObjectCount,
            playerColor: index % _uniqueObjectCount % 8,
          ),
        ),
    ],
    regions: const [],
    objectCounts: const {MapLayerType.units: _placementCount},
  );
}

int _pixelX(int index) =>
    (index % _placementGridSize) * (_mapSize ~/ _placementGridSize) * 32 + 16;

int _pixelY(int index) =>
    (index ~/ _placementGridSize) * (_mapSize ~/ _placementGridSize) * 32 + 16;

StarCraftDataAssetSettingsState _readyAssetState() {
  final inspection = StarCraftDataAssetInspection(
    installationPath: r'C:\Games\StarCraft',
    requiredAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    foundAssetCount: StarCraftDataAssetManifest.requiredTilesetAssets.length,
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.4.0',
    cascLibRevision: 'pinned-casc',
  );
  return StarCraftDataAssetSettingsState(
    status: StarCraftDataAssetSettingsStatus.ready,
    configuredPath: inspection.installationPath,
    inspection: inspection,
  );
}

final class _PerformanceObjectGateway implements StarCraftObjectAtlasGateway {
  final List<StarCraftObjectAtlasRequest> requests = [];

  @override
  Future<void> cancel(String operationId) async {}

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async {
    requests.add(request);
    return StarCraftObjectAtlasResult(
      request: request,
      entries: [
        for (final key in request.objects)
          if (key.id < _uniqueObjectCount - _unsupportedObjectCount)
            StarCraftObjectAtlasEntry(
              key: key,
              spriteId: key.id,
              imageId: key.id,
              width: _textureDimension,
              height: _textureDimension,
              anchorX: _textureDimension ~/ 2,
              anchorY: _textureDimension ~/ 2,
              frameIndex: 0,
              rgbaBytes: Uint8List(_textureBytes),
            ),
      ],
      unsupportedObjects: [
        for (final key in request.objects)
          if (key.id >= _uniqueObjectCount - _unsupportedObjectCount)
            StarCraftUnsupportedObjectGraphic(
              key: key,
              code: 'SC_CASC_OBJECT_GRP_MISSING',
            ),
      ],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.4.0',
      cascLibRevision: 'pinned-casc',
      totalAssetBytes: _uniqueObjectCount * _textureBytes,
    );
  }
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
