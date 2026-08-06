import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/terrain_tile_texture_controller.dart';

void main() {
  testWidgets('renders map bounds, grid, visible range, and terrain mode', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            rawTileValues: [1, 2, 3, 4, 5, 6, 7, 8],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('map-canvas')), findsOneWidget);
    expect(find.byKey(const Key('map-canvas-paint')), findsOneWidget);
    expect(
      find.byKey(const Key('map-canvas-repaint-boundary')),
      findsOneWidget,
    );
    expect(find.text('Visible 0,0–4,2'), findsOneWidget);
    expect(find.text('Grid 1 tile'), findsOneWidget);
    expect(find.text('Raw fallback'), findsOneWidget);
    expect(find.text('Tile — · Pixel —'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('map-canvas-paint')),
    );
    final painter = customPaint.painter! as MapCanvasPainter;
    expect(painter.layout.mapRect, const Rect.fromLTWH(176, 128, 128, 64));
    expect(painter.layout.tileExtent, 32);
    expect(painter.layout.visibleTiles.left, 0);
    expect(painter.layout.visibleTiles.top, 0);
    expect(painter.layout.visibleTiles.rightExclusive, 4);
    expect(painter.layout.visibleTiles.bottomExclusive, 2);
  });

  testWidgets('reports helper-rejected raw values as unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 2,
            mapHeight: 2,
            rawTileValues: [0, 0x3fff, 0x4000, 0xffff],
            terrainTextureState: TerrainTileTextureState(
              status: TerrainTileTextureStatus.unavailable,
              requestedRawValueCount: 4,
              unsupportedRawValues: [0x4000, 0xffff],
              fallbackRawValues: [0x4000, 0xffff],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Raw fallback · 2 unsupported'), findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('map-canvas-paint')),
    );
    final painter = customPaint.painter! as MapCanvasPainter;
    expect(painter.rawTileValues, [0, 0x3fff, 0x4000, 0xffff]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints extended CV5 images before per-tile fallback', (
    tester,
  ) async {
    final rgba = Uint8List(32 * 32 * 4);
    for (var offset = 0; offset < rgba.length; offset += 4) {
      rgba[offset] = 255;
      rgba[offset + 3] = 255;
    }
    final texture = await tester.runAsync(
      () => const UiTerrainTileTextureFactory().create(rgba),
    );
    expect(texture, isNotNull);
    final resolvedTexture = texture!;
    addTearDown(resolvedTexture.dispose);
    final textureState = TerrainTileTextureState(
      status: TerrainTileTextureStatus.partial,
      requestedRawValueCount: 2,
      textures: {1: resolvedTexture},
      unsupportedRawValues: const [0x4000],
      fallbackRawValues: const [0x4000],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 2,
            mapHeight: 1,
            rawTileValues: const [1, 0x4000],
            terrainTextureState: textureState,
          ),
        ),
      ),
    );

    expect(find.text('StarCraft tiles · 1 fallback'), findsOneWidget);
    final widgetPainter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(widgetPainter.terrainTextures[1], same(resolvedTexture));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final layout = MapCanvasLayout.fit(
      viewportSize: const Size(64, 32),
      mapWidth: 2,
      mapHeight: 1,
      contentPadding: 0,
    );
    MapCanvasPainter(
      layout: layout,
      rawTileValues: const [1, 0x4000],
      terrainTextures: {1: resolvedTexture, 0x4000: resolvedTexture},
    ).paint(canvas, const Size(64, 32));
    final rendered = await tester.runAsync(
      () => recorder.endRecording().toImage(64, 32),
    );
    expect(rendered, isNotNull);
    final resolvedRendered = rendered!;
    addTearDown(resolvedRendered.dispose);
    final pixels = await tester.runAsync(
      () => resolvedRendered.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(pixels, isNotNull);

    final imagePixel = (16 * 64 + 16) * 4;
    expect(pixels!.getUint8(imagePixel), 255);
    expect(pixels.getUint8(imagePixel + 1), 0);
    expect(pixels.getUint8(imagePixel + 2), 0);
    expect(pixels.getUint8(imagePixel + 3), 255);
    final extendedImagePixel = (8 * 64 + 48) * 4;
    expect(pixels.getUint8(extendedImagePixel), 255);
    expect(pixels.getUint8(extendedImagePixel + 1), 0);
    expect(pixels.getUint8(extendedImagePixel + 2), 0);
    expect(pixels.getUint8(extendedImagePixel + 3), 255);
  });

  testWidgets('shows loading mode before the first StarCraft tile is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 1,
            mapHeight: 1,
            rawTileValues: const [1],
            terrainTextureState: TerrainTileTextureState(
              status: TerrainTileTextureStatus.loading,
              requestedRawValueCount: 1,
              fallbackRawValues: const [1],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Loading StarCraft tiles'), findsOneWidget);
  });

  testWidgets('falls back to geometry when tile data is missing or invalid', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(mapWidth: 2, mapHeight: 2, rawTileValues: [1, 2]),
        ),
      ),
    );

    expect(find.text('Geometry only'), findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('map-canvas-paint')),
    );
    final painter = customPaint.painter! as MapCanvasPainter;
    expect(painter.rawTileValues, isNull);
  });

  testWidgets('zooms from controls and returns to fit', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: MapCanvas(mapWidth: 256, mapHeight: 256),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.pump();

    expect(find.text('125%'), findsOneWidget);
    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.layout.zoom, 1.25);
    expect(painter.layout.visibleTiles.bottomExclusive, lessThan(256));

    await tester.tap(find.byKey(const Key('map-canvas-fit')));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.layout.zoom, 1);
    expect(painter.layout.panOffset, Offset.zero);
    expect(painter.layout.visibleTiles.rightExclusive, 256);
  });

  testWidgets('wheel zoom keeps the map coordinate under the pointer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 300,
          height: 300,
          child: MapCanvas(mapWidth: 64, mapHeight: 64),
        ),
      ),
    );

    final canvasTopLeft = tester.getTopLeft(
      find.byKey(const Key('map-canvas')),
    );
    final focalPoint = canvasTopLeft + const Offset(90, 100);
    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    final before = painter.layout.coordinateAt(focalPoint - canvasTopLeft)!;

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: focalPoint,
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.pump();

    expect(find.text('125%'), findsOneWidget);
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    final after = painter.layout.coordinateAt(focalPoint - canvasTopLeft)!;
    expect(after.tileX, before.tileX);
    expect(after.tileY, before.tileY);
    expect(after.pixelX, before.pixelX);
    expect(after.pixelY, before.pixelY);
  });

  testWidgets('space drag pans a zoomed map', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: MapCanvas(mapWidth: 256, mapHeight: 256),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.pump();

    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    final before = painter.layout.mapRect;
    final center = tester.getCenter(find.byKey(const Key('map-canvas')));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveBy(const Offset(30, 20));
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.layout.mapRect.left, greaterThan(before.left));
    expect(painter.layout.mapRect.top, greaterThan(before.top));
  });

  testWidgets('middle-button drag pans without a keyboard modifier', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: MapCanvas(mapWidth: 256, mapHeight: 256)),
    );
    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.tap(find.byKey(const Key('map-canvas-zoom-in')));
    await tester.pump();

    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    final before = painter.layout.mapRect;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('map-canvas'))),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await gesture.moveBy(const Offset(-25, -15));
    await gesture.up();
    await tester.pump();

    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.layout.mapRect.left, lessThan(before.left));
    expect(painter.layout.mapRect.top, lessThan(before.top));
  });

  testWidgets('hover reports zero-based tile and StarCraft pixel coordinates', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MapCanvas(mapWidth: 4, mapHeight: 2)),
      ),
    );

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    final canvasTopLeft = tester.getTopLeft(
      find.byKey(const Key('map-canvas')),
    );
    final pointer =
        canvasTopLeft +
        painter.layout.mapRect.topLeft +
        Offset(
          painter.layout.tileExtent * 1.5,
          painter.layout.tileExtent * 0.5,
        );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: canvasTopLeft);
    await gesture.moveTo(pointer);
    await tester.pump();

    expect(find.text('Tile 1,0 · Pixel 48,16'), findsOneWidget);

    await gesture.moveTo(canvasTopLeft + const Offset(4, 4));
    await tester.pump();
    expect(find.text('Tile — · Pixel —'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('select tool reports the clicked terrain tile', (tester) async {
    TerrainTileCoordinate? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            rawTileValues: const [1, 2, 3, 4, 5, 6, 7, 8],
            onTileSelected: (coordinate) => selected = coordinate,
          ),
        ),
      ),
    );

    final pointer = _tileCenter(tester, x: 2, y: 1);
    await tester.tapAt(pointer);
    await tester.pump();

    expect(selected, const TerrainTileCoordinate(x: 2, y: 1));
  });

  testWidgets('brush fills every crossed tile without gaps', (tester) async {
    final painted = <TerrainTileCoordinate>[];
    var started = 0;
    var ended = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            rawTileValues: const [1, 2, 3, 4, 5, 6, 7, 8],
            editingTool: TerrainEditingTool.brush,
            onBrushStrokeStarted: () => started++,
            onBrushStroke: painted.addAll,
            onBrushStrokeEnded: () => ended++,
            onBrushStrokeCancelled: () => cancelled++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      _tileCenter(tester, x: 0, y: 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(_tileCenter(tester, x: 3, y: 1));
    await gesture.up();
    await tester.pump();

    expect(painted, const [
      TerrainTileCoordinate(x: 0, y: 0),
      TerrainTileCoordinate(x: 1, y: 0),
      TerrainTileCoordinate(x: 2, y: 1),
      TerrainTileCoordinate(x: 3, y: 1),
    ]);
    expect(started, 1);
    expect(ended, 1);
    expect(cancelled, 0);
  });

  testWidgets('escape cancels one active brush gesture', (tester) async {
    var started = 0;
    var ended = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            editingTool: TerrainEditingTool.brush,
            onBrushStrokeStarted: () => started++,
            onBrushStroke: (_) {},
            onBrushStrokeEnded: () => ended++,
            onBrushStrokeCancelled: () => cancelled++,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      _tileCenter(tester, x: 0, y: 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await gesture.up();
    await tester.pump();

    expect(started, 1);
    expect(ended, 0);
    expect(cancelled, 1);
  });

  testWidgets('rectangle previews normalized bounds and commits on release', (
    tester,
  ) async {
    TerrainTileRegion? filled;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            rawTileValues: const [1, 2, 3, 4, 5, 6, 7, 8],
            editingTool: TerrainEditingTool.rectangle,
            selectedTile: const TerrainTileCoordinate(x: 1, y: 0),
            onRectangleFilled: (region) => filled = region,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      _tileCenter(tester, x: 3, y: 1),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(_tileCenter(tester, x: 1, y: 0));
    await tester.pump();

    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.selectedTile, const TerrainTileCoordinate(x: 1, y: 0));
    expect(painter.rectanglePreview?.left, 1);
    expect(painter.rectanglePreview?.top, 0);
    expect(painter.rectanglePreview?.right, 3);
    expect(painter.rectanglePreview?.bottom, 1);

    await gesture.up();
    await tester.pump();

    expect(filled?.left, 1);
    expect(filled?.top, 0);
    expect(filled?.right, 3);
    expect(filled?.bottom, 1);
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.rectanglePreview, isNull);
  });

  testWidgets('escape cancels a rectangle without committing it', (
    tester,
  ) async {
    TerrainTileRegion? filled;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: MapCanvas(
            mapWidth: 4,
            mapHeight: 2,
            editingTool: TerrainEditingTool.rectangle,
            onRectangleFilled: (region) => filled = region,
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      _tileCenter(tester, x: 0, y: 0),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(_tileCenter(tester, x: 2, y: 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await gesture.up();
    await tester.pump();

    expect(filled, isNull);
    final painter =
        tester
                .widget<CustomPaint>(find.byKey(const Key('map-canvas-paint')))
                .painter!
            as MapCanvasPainter;
    expect(painter.rectanglePreview, isNull);
  });

  test('fit layout centers a small map and caps tile extent', () {
    final layout = MapCanvasLayout.fit(
      viewportSize: const Size(400, 300),
      mapWidth: 4,
      mapHeight: 2,
    );

    expect(layout.tileExtent, 32);
    expect(layout.mapRect, const Rect.fromLTWH(136, 118, 128, 64));
    expect(layout.visibleTiles.isEmpty, isFalse);
    expect(layout.gridStep, 1);
  });

  test('fit layout coarsens the grid for a 256 by 256 map', () {
    final layout = MapCanvasLayout.fit(
      viewportSize: const Size(400, 300),
      mapWidth: 256,
      mapHeight: 256,
    );

    expect(layout.mapRect.left, greaterThanOrEqualTo(0));
    expect(layout.mapRect.top, greaterThanOrEqualTo(0));
    expect(layout.mapRect.right, lessThanOrEqualTo(400));
    expect(layout.mapRect.bottom, lessThanOrEqualTo(300));
    expect(layout.visibleTiles.left, 0);
    expect(layout.visibleTiles.top, 0);
    expect(layout.visibleTiles.rightExclusive, 256);
    expect(layout.visibleTiles.bottomExclusive, 256);
    expect(layout.gridStep, 16);
  });

  test('view layout constrains pan and computes map coordinates', () {
    final fitted = MapCanvasLayout.view(
      viewportSize: const Size(200, 200),
      mapWidth: 10,
      mapHeight: 10,
      panOffset: const Offset(100, -100),
    );
    expect(fitted.panOffset, Offset.zero);

    final zoomed = MapCanvasLayout.view(
      viewportSize: const Size(200, 200),
      mapWidth: 10,
      mapHeight: 10,
      zoom: 2,
      panOffset: const Offset(1000, -1000),
    );
    expect(zoomed.panOffset, const Offset(228, -228));
    expect(zoomed.mapRect.left, 176);
    expect(zoomed.mapRect.bottom, 24);

    final coordinate = zoomed.coordinateAt(
      zoomed.mapRect.topLeft + Offset(zoomed.tileExtent * 2.5, 10),
    )!;
    expect(coordinate.tileX, 2);
    expect(coordinate.tileY, 0);
    expect(coordinate.pixelX, 80);
    expect(coordinate.pixelY, 10);
    expect(zoomed.coordinateAt(const Offset(10, 100)), isNull);
  });

  test('fit layout rejects invalid dimensions and viewport values', () {
    expect(
      () => MapCanvasLayout.fit(
        viewportSize: const Size(100, 100),
        mapWidth: 0,
        mapHeight: 1,
      ),
      throwsRangeError,
    );
    expect(
      () => MapCanvasLayout.fit(
        viewportSize: Size.zero,
        mapWidth: 1,
        mapHeight: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => MapCanvasLayout.fit(
        viewportSize: const Size(100, 100),
        mapWidth: 1,
        mapHeight: 1,
        contentPadding: -1,
      ),
      throwsRangeError,
    );
    expect(
      () => MapCanvasLayout.view(
        viewportSize: const Size(100, 100),
        mapWidth: 1,
        mapHeight: 1,
        zoom: 0,
      ),
      throwsRangeError,
    );
    expect(
      () => MapCanvasLayout.view(
        viewportSize: const Size(100, 100),
        mapWidth: 1,
        mapHeight: 1,
        panOffset: const Offset(double.infinity, 0),
      ),
      throwsArgumentError,
    );
  });

  test('painter repaints only when geometry or terrain identity changes', () {
    final values = <int>[1, 2, 3, 4];
    final layout = MapCanvasLayout.fit(
      viewportSize: const Size(200, 200),
      mapWidth: 2,
      mapHeight: 2,
    );
    final original = MapCanvasPainter(layout: layout, rawTileValues: values);
    final unchanged = MapCanvasPainter(layout: layout, rawTileValues: values);
    final changedTerrain = MapCanvasPainter(
      layout: layout,
      rawTileValues: List<int>.from(values),
    );
    final changedGeometry = MapCanvasPainter(
      layout: MapCanvasLayout.fit(
        viewportSize: const Size(240, 200),
        mapWidth: 2,
        mapHeight: 2,
      ),
      rawTileValues: values,
    );

    expect(unchanged.shouldRepaint(original), isFalse);
    expect(changedTerrain.shouldRepaint(original), isTrue);
    expect(changedGeometry.shouldRepaint(original), isTrue);
    final changedSelection = MapCanvasPainter(
      layout: layout,
      rawTileValues: values,
      selectedTile: const TerrainTileCoordinate(x: 0, y: 0),
    );
    expect(changedSelection.shouldRepaint(original), isTrue);
    final changedTextures = MapCanvasPainter(
      layout: layout,
      rawTileValues: values,
      terrainTextures: Map<int, TerrainTileTexture>.unmodifiable(const {}),
    );
    expect(changedTextures.shouldRepaint(original), isTrue);
    final changedObserver = MapCanvasPainter(
      layout: layout,
      rawTileValues: values,
      onPaintMeasured: (_) {},
    );
    expect(changedObserver.shouldRepaint(original), isTrue);
  });
}

Offset _tileCenter(WidgetTester tester, {required int x, required int y}) {
  final paintFinder = find.byKey(const Key('map-canvas-paint'));
  final painter =
      tester.widget<CustomPaint>(paintFinder).painter! as MapCanvasPainter;
  return tester.getTopLeft(find.byKey(const Key('map-canvas'))) +
      painter.layout.mapRect.topLeft +
      Offset(
        (x + 0.5) * painter.layout.tileExtent,
        (y + 0.5) * painter.layout.tileExtent,
      );
}
