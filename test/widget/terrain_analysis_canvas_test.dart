import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/terrain_analysis_fixture.dart';

void main() {
  testWidgets(
    'height and walkability render exact mini-tiles; unknown stays distinct',
    (tester) async {
      final source = analysisSource();
      final view = TerrainAnalysisView(
        width: 4,
        height: 4,
        rawValues: List.filled(16, 0),
        source: source.snapshot,
        revision: source.revision,
      );
      final layout = MapCanvasLayout.view(
        viewportSize: const Size(128, 128),
        mapWidth: 4,
        mapHeight: 4,
        contentPadding: 0,
      );
      Future<ByteData> render(
        TerrainAnalysisMode mode, {
        TerrainAnalysisView? data,
      }) async {
        final recorder = ui.PictureRecorder();
        MapCanvasPainter(
          layout: layout,
          rawTileValues: null,
          gridVisible: false,
          analysisView: data ?? view,
          analysisMode: mode,
        ).paint(Canvas(recorder), const Size(128, 128));
        final picture = recorder.endRecording();
        final image = await tester.runAsync(() => picture.toImage(128, 128));
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        image!.dispose();
        picture.dispose();
        return bytes!;
      }

      List<int> pixel(ByteData b, int x, int y) => [
        for (var c = 0; c < 3; c++) b.getUint8((y * 128 + x) * 4 + c),
      ];
      final height = await render(TerrainAnalysisMode.elevation);
      final low = pixel(height, 4, 4),
          mid = pixel(height, 12, 4),
          high = pixel(height, 20, 4);
      expect(low[1], greaterThan(low[0]));
      expect(mid[2], greaterThan(mid[1]));
      expect(high[0], greaterThan(high[1]));
      expect(pixel(height, 28, 4), high); // Both source bits still render high.
      final power = await render(TerrainAnalysisMode.power);
      final creep = await render(TerrainAnalysisMode.creep);
      expect(pixel(power, 12, 4), pixel(creep, 12, 4));
      expect(pixel(power, 12, 4), isNot(mid));
      final unknown = TerrainAnalysisView(
        width: 4,
        height: 4,
        rawValues: List.filled(16, 0),
        source: null,
        revision: null,
      );
      expect(
        pixel(await render(TerrainAnalysisMode.walkable, data: unknown), 12, 4),
        pixel(power, 12, 4),
      );
    },
  );
  testWidgets(
    'only visible tiles are projected, cached, and counted across paints',
    (tester) async {
      final view = TerrainAnalysisView(
        width: 256,
        height: 256,
        rawValues: List.generate(65536, (i) => i),
        source: analysisSource().snapshot,
        revision: 'r1',
      );
      final layout = MapCanvasLayout.view(
        viewportSize: const Size(128, 128),
        mapWidth: 256,
        mapHeight: 256,
        contentPadding: 0,
        zoom: 32,
      );
      MapCanvasPaintMetrics? metrics;
      final painter = MapCanvasPainter(
        layout: layout,
        rawTileValues: null,
        analysisView: view,
        analysisMode: TerrainAnalysisMode.walkable,
        onPaintMeasured: (m) => metrics = m,
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(128, 128));
      recorder.endRecording().dispose();
      expect(metrics!.analysisTileCount, layout.visibleTiles.tileCount);
      expect(metrics!.analysisTileCount, lessThan(65536));
      expect(view.projectionCount, metrics!.analysisTileCount);
      final count = view.projectionCount;
      final next = ui.PictureRecorder();
      painter.paint(Canvas(next), const Size(128, 128));
      next.endRecording().dispose();
      expect(view.projectionCount, count);
      expect(
        painter.shouldRepaint(
          MapCanvasPainter(layout: layout, rawTileValues: null),
        ),
        isTrue,
      );
    },
  );
  testWidgets(
    'distance measurement changes pixels without projecting terrain facts',
    (tester) async {
      final layout = MapCanvasLayout.fit(
        viewportSize: const Size(128, 128),
        mapWidth: 4,
        mapHeight: 4,
        contentPadding: 0,
      );
      final recorder = ui.PictureRecorder();
      MapCanvasPainter(
        layout: layout,
        rawTileValues: null,
        gridVisible: false,
        analysisMode: TerrainAnalysisMode.distance,
        distanceMeasurement: MapDistanceMeasurement(x: 64, y: 64, radius: 32),
      ).paint(Canvas(recorder), const Size(128, 128));
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(128, 128));
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      image!.dispose();
      picture.dispose();
      expect(data!.getUint8((64 * 128 + 96) * 4), greaterThan(150));
      expect(data.getUint8((64 * 128 + 110) * 4), lessThan(150));
    },
  );
}
