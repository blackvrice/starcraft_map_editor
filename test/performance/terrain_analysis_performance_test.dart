import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/terrain_analysis_fixture.dart';

void main() {
  test(
    '256x256 visible overlay projection is bounded and warm paints reuse cache',
    () {
      final view = TerrainAnalysisView(
        width: 256,
        height: 256,
        rawValues: List.generate(65536, (i) => i % 32),
        source: analysisSource().snapshot,
        revision: 'synthetic',
      );
      for (final zoom in [1.0, 8.0]) {
        final layout = MapCanvasLayout.view(
          viewportSize: const Size(800, 600),
          mapWidth: 256,
          mapHeight: 256,
          contentPadding: 0,
          zoom: zoom,
        );
        for (final mode in [
          TerrainAnalysisMode.elevation,
          TerrainAnalysisMode.walkable,
        ]) {
          final samples = <MapCanvasPaintMetrics>[];
          for (var frame = 0; frame < 3; frame++) {
            final recorder = ui.PictureRecorder();
            MapCanvasPainter(
              layout: layout,
              rawTileValues: null,
              analysisView: view,
              analysisMode: mode,
              onPaintMeasured: samples.add,
            ).paint(Canvas(recorder), const Size(800, 600));
            recorder.endRecording().dispose();
          }
          expect(
            samples.every(
              (s) => s.analysisTileCount == layout.visibleTiles.tileCount,
            ),
            isTrue,
          );
          expect(
            samples.every((s) => s.paintDuration < const Duration(seconds: 1)),
            isTrue,
            reason: 'Debug smoke ceiling only; not a release frame budget.',
          );
          debugPrint(
            'TERRAIN_ANALYSIS_SMOKE mode=${mode.name} zoom=$zoom '
            'visible=${layout.visibleTiles.tileCount} '
            'paintUs=${samples.map((s) => s.paintDuration.inMicroseconds).join(",")} '
            'cached=${view.cachedValueCount} projections=${view.projectionCount}',
          );
        }
      }
      expect(view.cachedValueCount, lessThanOrEqualTo(32));
      expect(view.projectionCount, 32);
    },
  );
}
