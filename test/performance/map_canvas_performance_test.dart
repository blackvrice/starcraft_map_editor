import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';

void main() {
  testWidgets('profiles 256x256 terrain while fitting, zooming, and panning', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final rawTileValues = List<int>.generate(
      256 * 256,
      (index) => index % 64,
      growable: false,
    );
    final measurements = <MapCanvasPaintMetrics>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 600,
          child: MapCanvas(
            mapWidth: 256,
            mapHeight: 256,
            rawTileValues: rawTileValues,
            onPaintMeasured: measurements.add,
          ),
        ),
      ),
    );

    final fitted = measurements.last;
    expect(fitted.mapWidth, 256);
    expect(fitted.mapHeight, 256);
    expect(fitted.zoom, 1);
    expect(fitted.gridStep, greaterThan(1));
    expect(fitted.visibleTiles.tileCount, 256 * 256);
    expect(fitted.fallbackTileCount, 256 * 256);
    expect(fitted.textureTileCount, 0);
    expect(fitted.unsupportedTileCount, 0);
    expect(fitted.paintedTerrainTileCount, 256 * 256);
    _expectWithinSmokeCeiling(fitted);

    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.pump();

    final zoomed = measurements.last;
    expect(zoomed.zoom, 1.5625);
    expect(
      zoomed.visibleTiles.tileCount,
      lessThan(fitted.visibleTiles.tileCount),
    );
    expect(zoomed.paintedTerrainTileCount, zoomed.visibleTiles.tileCount);
    _expectWithinSmokeCeiling(zoomed);

    final zoomedBounds = zoomed.visibleTiles;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('map-canvas'))),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.moveBy(const Offset(80, 50));
    await gesture.up();
    await tester.pump();

    final panned = measurements.last;
    expect(panned.zoom, zoomed.zoom);
    expect((
      panned.visibleTiles.left,
      panned.visibleTiles.top,
    ), isNot((zoomedBounds.left, zoomedBounds.top)));
    expect(panned.paintedTerrainTileCount, panned.visibleTiles.tileCount);
    _expectWithinSmokeCeiling(panned);

    debugPrint(
      'MAP_CANVAS_256_SMOKE '
      'os=${Platform.operatingSystem} '
      'mode=${kDebugMode ? 'debug' : 'profile-or-release'} '
      'viewport=800x600 map=256x256 '
      'fitUs=${fitted.paintDuration.inMicroseconds} '
      'zoomUs=${zoomed.paintDuration.inMicroseconds} '
      'panUs=${panned.paintDuration.inMicroseconds} '
      'fitVisible=${fitted.visibleTiles.tileCount} '
      'zoomVisible=${zoomed.visibleTiles.tileCount} '
      'panVisible=${panned.visibleTiles.tileCount}',
    );
  });
}

void _expectWithinSmokeCeiling(MapCanvasPaintMetrics metrics) {
  expect(
    metrics.paintDuration,
    lessThan(const Duration(seconds: 1)),
    reason:
        'The debug smoke ceiling catches pathological synchronous painting; '
        'profile-mode frame timing remains the FPS release gate.',
  );
}
