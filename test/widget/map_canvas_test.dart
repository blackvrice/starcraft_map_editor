import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';

void main() {
  testWidgets('renders map bounds, grid, visible range, and terrain mode', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(480, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
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
    expect(find.text('Raw MTXM preview'), findsOneWidget);
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
  });
}
