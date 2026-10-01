import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/basic_editing_tools_dialog.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  for (final initialTab in [0, 1, 2, 3, 4, 5, 6]) {
    testWidgets(
      'Korean basic tools tab $initialTab applies edits or leaves cancellation unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = NewMapHarness();
        addTearDown(h.dispose);
        final layers = MapLayerController();
        addTearDown(layers.dispose);
        h.maps.createNew(
          NewMapOptions(width: 32, height: 32, rawTileValue: 1),
          expectedSession: null,
        );
        layers.synchronizeSession(h.maps.state.session);
        final c = BasicEditingController(maps: h.maps, layers: layers);
        addTearDown(c.dispose);
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        if (initialTab == 1 || initialTab == 4) {
          var doc = basicDocument(units: [basicUnit(id: 1)]);
          if (initialTab == 4) {
            doc = doc.replaceSection(
              doc.sections.indexWhere((s) => s.name == 'THG2'),
              basicSection('THG2', [0, 0, 128, 0, 128, 0, 0, 0, 0, 0]),
            );
          }
          c.apply(c.source.rawDocument, doc, 'Fixture');
          layers.setActiveLayer(
            initialTab == 1 ? MapLayerType.units : MapLayerType.sprites,
          );
          layers.selectAt(session: c.source, pixelX: 128, pixelY: 128);
        }
        final before = c.source;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => BasicEditingToolsDialog(
                    controller: c,
                    initialTab: initialTab,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('기본 편집 도구'), findsOneWidget);
        if (initialTab == 0) {
          final painter =
              tester
                      .widget<CustomPaint>(
                        find.byKey(const Key('map-canvas-paint')),
                      )
                      .painter!
                  as MapCanvasPainter;
          final origin = tester.getTopLeft(
            find.byKey(const Key('map-canvas-input')),
          );
          await tester.tapAt(
            origin +
                painter.layout.mapRect.topLeft +
                Offset(
                  painter.layout.tileExtent * 2.5,
                  painter.layout.tileExtent * 2.5,
                ),
          );
          await tester.pumpAndSettle();
          expect(c.fog[66], 254);
          expect(h.maps.editHistory.undoDepth, 1);
          final committed = c.source;
          final gesture = await tester.startGesture(
            origin +
                painter.layout.mapRect.topLeft +
                Offset(
                  painter.layout.tileExtent * 3.5,
                  painter.layout.tileExtent * 2.5,
                ),
          );
          await tester.pump();
          expect(c.fog[67], 254);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          await gesture.up();
          await tester.pumpAndSettle();
          expect(c.source, same(committed));
          expect(c.fog[67], 255);
          expect(h.maps.editHistory.undoDepth, 1);
          c.beginFogStroke();
          c.paintFog(
            [const TerrainTileCoordinate(x: 3, y: 2)],
            player: 0,
            hidden: false,
          );
          await tester.pump();
          await tester.tap(find.widgetWithText(Tab, '선택 유닛'));
          await tester.pumpAndSettle();
          expect(c.source, same(committed));
          expect(c.fog[67], 255);
        } else if (initialTab == 1) {
          await tester.enterText(find.byKey(const ValueKey('basic-hp')), '50');
          await tester.ensureVisible(
            find.byKey(const Key('basic-units-apply')),
          );
          await tester.tap(find.byKey(const Key('basic-units-apply')));
          await tester.pumpAndSettle();
          expect(
            c
                .source
                .objectViews
                .unitSections
                .single
                .units
                .single
                .hitpointPercent,
            50,
          );
        } else if (initialTab == 2) {
          await tester.enterText(find.byKey(const ValueKey('basic-x')), '60');
          await tester.enterText(find.byKey(const ValueKey('basic-y')), '70');
          await tester.tap(find.byKey(const Key('basic-start-apply')));
          await tester.pumpAndSettle();
          expect(c.source.objectViews.unitSections.single.units.single.x, 60);
        } else if (initialTab == 3) {
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('basic-location-apply')),
                )
                .onPressed,
            isNull,
          );
          await tester.enterText(
            find.byKey(const Key('basic-location-search')),
            'Anywhere',
          );
          await tester.pumpAndSettle();
          expect(find.text('64: Anywhere'), findsOneWidget);
        } else if (initialTab == 4) {
          await tester.enterText(
            find.byKey(const ValueKey('basic-spriteOwner')),
            '2',
          );
          await tester.tap(find.byKey(const Key('basic-sprites-apply')));
          await tester.pumpAndSettle();
          expect(
            c.source.objectViews.spriteSections.single.sprites.single.owner,
            1,
          );
        } else if (initialTab == 5) {
          expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('basic-paste')))
                .onPressed,
            isNull,
          );
        } else {
          expect(find.byKey(const Key('basic-terrain-copy')), findsOneWidget);
          await tester.tap(find.byKey(const Key('basic-terrain-copy')));
          await tester.pumpAndSettle();
          expect(c.hasTerrainClipboard, isTrue);
        }
        await tester.tap(find.byKey(const Key('basic-tools-close')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (initialTab == 3 || initialTab == 5 || initialTab == 6) {
          expect(c.source, same(before));
        }
      },
    );
  }
}
