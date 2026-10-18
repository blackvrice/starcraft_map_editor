import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/preplaced_unit_power_layout.dart';
import 'package:starcraft_map_editor/domain/placement/unit_range_projection.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_analysis_view.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/editor_overlay_host.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/editor_overlay_toolbar.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/eud_dat_fixture.dart';
import '../fixtures/multi_map_fixture.dart';

void main() {
  testWidgets(
    'main editing canvas keeps its state and document while overlays toggle',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = MultiMapFixture(), doc = f.addMap();
      await tester.pumpWidget(
        StarCraftMapEditorApp(dependencies: doc.value, workspace: f.workspace),
      );
      await tester.pumpAndSettle();
      final beforeCanvas = tester.state(find.byType(MapCanvas)),
          before = doc.maps.state.session,
          depth = doc.maps.editHistory.undoDepth;
      await tester.ensureVisible(
        find.byKey(const Key('editor-overlay-ranges')),
      );
      await tester.tap(find.byKey(const Key('editor-overlay-ranges')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-overlay-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terrain elevation').last);
      await tester.pumpAndSettle();
      final canvas = tester.widget<MapCanvas>(find.byType(MapCanvas));
      expect(canvas.analysisMode, TerrainAnalysisMode.elevation);
      expect(canvas.onSelectionRequested, isNotNull);
      expect(canvas.onSelectionRegionRequested, isNotNull);
      expect(tester.state(find.byType(MapCanvas)), same(beforeCanvas));
      expect(doc.maps.state.session, same(before));
      expect(doc.maps.editHistory.undoDepth, depth);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      var done = false;
      final disposal = f.dispose().whenComplete(() => done = true);
      for (var i = 0; i < 200 && !done; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(
        done,
        isTrue,
        reason: 'All document resources must finish disposal.',
      );
      await disposal;
    },
  );

  for (final locale in [const Locale('en'), const Locale('ko')]) {
    testWidgets('overlay toolbar fits 320px in $locale and loads explicitly', (
      tester,
    ) async {
      final h = OverlayHarness();
      h.overlays.configure(ranges: true, power: true);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: EditorOverlayHost(
                    catalog: h.catalog,
                    builder: (context, c) => EditorOverlayToolbar(
                      controller: c,
                      layers: MapLayerState(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // The host owns its own controller and does not inherit placement modes.
      await tester.tap(find.byKey(const Key('editor-overlay-ranges')));
      await tester.pumpAndSettle();
      expect(h.datGateway.calls, 0);
      await tester.tap(find.byKey(const Key('editor-overlay-load')));
      await tester.pumpAndSettle();
      expect(h.datGateway.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(h.dispose);
    });
  }

  testWidgets(
    'power mask, unknown and weapon/sight circles render distinct pixels',
    (tester) async {
      final unitBytes = basicUnit(type: 156, x: 512, y: 512);
      ByteData.sublistView(unitBytes).setUint16(14, 1, Endian.little);
      final units = const ChkObjectViewDecoder()
          .decode(basicDocument(units: [unitBytes]))
          .unitSections
          .single
          .units;
      final field = UnitPowerCatalog({156: overlayCapability(156)}).project(
        owner: 0,
        mapWidthTiles: 32,
        mapHeightTiles: 32,
        existing: PreplacedUnitPowerLayout.project(units),
      );
      final columns = syntheticDatColumns();
      columns['unit.sightRange']![156] = 4;
      final ranges = UnitRangeProjection.fromDat(
        dat: syntheticDatSource(columns).snapshot,
        selected: units,
        mapWidth: 32,
        mapHeight: 32,
      );
      final layout = MapCanvasLayout.view(
        viewportSize: const Size(1024, 1024),
        mapWidth: 32,
        mapHeight: 32,
        contentPadding: 0,
      );
      Future<ByteData> render({
        UnitPowerField? power,
        bool show = true,
        UnitRangeProjection? projection,
      }) async {
        final recorder = ui.PictureRecorder();
        MapCanvasPainter(
          layout: layout,
          rawTileValues: null,
          gridVisible: false,
          powerField: power,
          showLayoutPower: show,
          rangeProjection: projection,
        ).paint(Canvas(recorder), const Size(1024, 1024));
        final picture = recorder.endRecording();
        final image = await tester.runAsync(() => picture.toImage(1024, 1024));
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        image!.dispose();
        picture.dispose();
        return bytes!;
      }

      List<int> pixel(ByteData b, int x, int y) => [
        for (var c = 0; c < 3; c++) b.getUint8((y * 1024 + x) * 4 + c),
      ];
      final power = await render(power: field),
          unknown = await render(),
          off = await render(show: false),
          ring = await render(show: false, projection: ranges);
      expect(pixel(power, 512, 512)[1], greaterThan(pixel(power, 512, 512)[0]));
      expect(pixel(power, 100, 100)[0], greaterThan(pixel(power, 100, 100)[1]));
      expect(pixel(unknown, 512, 512), isNot(pixel(power, 512, 512)));
      expect(pixel(ring, 640, 512), isNot(pixel(off, 640, 512)));
      expect(pixel(ring, 512, 512), pixel(off, 512, 512));
    },
  );
}
