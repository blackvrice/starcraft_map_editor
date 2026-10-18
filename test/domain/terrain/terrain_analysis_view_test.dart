import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import '../../fixtures/terrain_analysis_fixture.dart';

void main() {
  test(
    'VF4 elevation is per mini-tile and high wins over simultaneous mid',
    () {
      final source = analysisSource();
      final view = TerrainAnalysisView(
        width: 2,
        height: 2,
        rawValues: [0, 16, 0, 65535],
        source: source.snapshot,
        revision: source.revision,
      );
      final cell = view.tileAt(0, 0)!;
      expect(cell.buildable, isTrue);
      expect(cell.walkableMask, 65535);
      expect([for (var i = 0; i < 4; i++) cell.elevation(i)], [0, 1, 2, 2]);
      expect(view.tileAt(1, 0)!.buildable, isFalse);
      expect(view.tileAt(1, 0)!.elevation(0), 0);
      expect(view.tileAt(1, 1), isNull);
      expect(() => view.tileAt(2, 0), throwsRangeError);
      expect(() => cell.elevation(16), throwsRangeError);
      expect(() => view.rawValues[0] = 1, throwsUnsupportedError);
    },
  );
  test('legacy or missing assets stay unknown, not low/blocked', () {
    final legacy = analysisSource(elevation: false);
    final view = TerrainAnalysisView(
      width: 1,
      height: 1,
      rawValues: [0],
      source: legacy.snapshot,
      revision: legacy.revision,
    );
    expect(view.tileAt(0, 0)!.elevation(0), isNull);
    final unknown = TerrainAnalysisView(
      width: 1,
      height: 1,
      rawValues: [0],
      source: null,
      revision: null,
    );
    expect(unknown.tileAt(0, 0), isNull);
    expect(unknown.tileAt(0, 0), isNull);
    expect(unknown.projectionCount, 1);
  });
  test(
    'projection is lazy, cached by raw value and bounded with LRU eviction',
    () {
      final view = TerrainAnalysisView(
        width: 256,
        height: 256,
        rawValues: List.generate(65536, (i) => i),
        source: analysisSource().snapshot,
        revision: 'first',
      );
      expect(view.cachedValueCount, 0);
      for (var i = 0; i < 5000; i++) {
        view.tileAt(i % 256, i ~/ 256);
      }
      expect(view.cachedValueCount, TerrainAnalysisView.maximumCachedValues);
      expect(view.projectionCount, 5000);
      view.tileAt(4999 % 256, 4999 ~/ 256);
      expect(view.projectionCount, 5000);
      view.tileAt(0, 0);
      expect(view.projectionCount, 5001);
      expect(view.rawValues.first, 0);
    },
  );
  test(
    'elevation mask size/range must exactly cover VF4; distance has numeric bounds',
    () {
      for (final (mid, high) in [
        (<int>[0], null),
        (<int>[0], <int>[]),
        (<int>[-1], <int>[0]),
        (<int>[0], <int>[65536]),
      ]) {
        expect(
          () => TerrainPlacementSnapshot(
            tileset: 0,
            groupBuildable: [true],
            megaTileReferences: [List.filled(16, 0)],
            walkableMasks: [65535],
            midElevationMasks: mid,
            highElevationMasks: high,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => MapDistanceMeasurement(x: -1, y: 0, radius: 1),
        throwsArgumentError,
      );
      expect(
        () => MapDistanceMeasurement(x: 0, y: 0, radius: 0),
        throwsArgumentError,
      );
      expect(
        () => MapDistanceMeasurement(x: 8192, y: 0, radius: 1),
        throwsArgumentError,
      );
      expect(
        MapDistanceMeasurement(x: 8191, y: 8191, radius: 8192).radius,
        8192,
      );
    },
  );
}
