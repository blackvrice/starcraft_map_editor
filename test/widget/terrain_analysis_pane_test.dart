import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/basic_editing_tools_dialog.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/terrain_analysis_fixture.dart';

void main() {
  for (final width in [600.0, 1200.0]) {
    testWidgets('analysis modes/load/distance stay read-only at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = NewMapHarness(),
          layers = MapLayerController(),
          gateway = AnalysisGateway();
      addTearDown(h.dispose);
      addTearDown(layers.dispose);
      h.maps.createNew(
        NewMapOptions(width: 32, height: 32, rawTileValue: 0),
        expectedSession: null,
      );
      final editing = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(editing.dispose);
      final before = editing.source, depth = h.maps.editHistory.undoDepth;
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BasicEditingToolsDialog(
              controller: editing,
              initialTab: 9,
              isomController: IsomFillController(
                maps: h.maps,
                assets: () => h.assets,
                gateway: gateway,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.requests, isEmpty);
      Future<void> mode(String label) async {
        await tester.ensureVisible(find.byKey(const Key('analysis-mode')));
        await tester.tap(find.byKey(const Key('analysis-mode')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await mode('지형 높이');
      expect(gateway.requests, isEmpty);
      await tester.tap(find.byKey(const Key('analysis-load')));
      await tester.pumpAndSettle();
      expect(gateway.requests.length, 1);
      final canvas = tester.widget<MapCanvas>(
        find.byKey(const Key('analysis-canvas')),
      );
      expect(canvas.analysisView!.tileAt(0, 0)!.elevation(1), 1);
      expect(canvas.analysisMode, TerrainAnalysisMode.elevation);
      await mode('실제 크립 (미지원)');
      expect(find.textContaining('모든 영역은 미확인'), findsOneWidget);
      await mode('거리 측정');
      await tester.ensureVisible(find.byKey(const Key('analysis-radius')));
      await tester.enterText(find.byKey(const Key('analysis-radius')), '192');
      await tester.ensureVisible(find.byKey(const Key('analysis-measure')));
      await tester.tap(find.byKey(const Key('analysis-measure')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MapCanvas>(find.byKey(const Key('analysis-canvas')))
            .distanceMeasurement!
            .radius,
        192,
      );
      expect(editing.source, same(before));
      expect(h.maps.editHistory.undoDepth, depth);
      expect(tester.takeException(), isNull);
    });
  }
}
