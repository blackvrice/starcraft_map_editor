import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/layers/selection_navigation_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/selection_navigation_dialog.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  for (final lang in ['en', 'ko']) {
    testWidgets(
      '$lang object finder searches defaults and filters without losing selection or editing map',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = NewMapHarness(), layers = MapLayerController();
        addTearDown(h.dispose);
        addTearDown(layers.dispose);
        h.maps.createNew(
          NewMapOptions(width: 32, height: 32, rawTileValue: 1),
          expectedSession: null,
        );
        final edit = BasicEditingController(maps: h.maps, layers: layers);
        addTearDown(edit.dispose);
        edit.apply(
          edit.source.rawDocument,
          basicDocument(
            units: [basicUnit(id: 1), basicUnit(id: 2, owner: 1, x: 300)],
          ),
          'Fixture',
        );
        final c = SelectionNavigationController(maps: h.maps, layers: layers),
            before = edit.source,
            depth = h.maps.editHistory.undoDepth;
        MapNavigationTarget? target;
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SelectionNavigationDialog(
                    controller: c,
                    onNavigate: (v) => target = v,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('selection-search')),
          'Terran Marine',
        );
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const Key('selection-list')),
            matching: find.textContaining('Terran Marine'),
          ),
          findsNWidgets(2),
        );
        await tester.tap(find.byKey(const Key('selection-results')));
        await tester.pump();
        expect(layers.state.selections.length, 2);
        await tester.enterText(
          find.byKey(const Key('selection-search')),
          'missing',
        );
        await tester.pump();
        expect(layers.state.selections.length, 2);
        await tester.enterText(find.byKey(const Key('selection-search')), '#0');
        await tester.pump();
        await tester.tap(find.byKey(const Key('selection-owner')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(lang == 'ko' ? '플레이어 2' : 'Player 2').last);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('selection-list')),
            matching: find.textContaining('Terran Marine'),
          ),
          findsOneWidget,
        );
        expect(layers.state.selections.length, 2);
        await tester.tap(find.byKey(const Key('selection-results')));
        await tester.pump();
        expect(layers.state.selections.single.pixelX, 300);
        await tester.enterText(find.byKey(const Key('selection-x')), '-1');
        await tester.tap(find.byKey(const Key('selection-goto')));
        await tester.pump();
        expect(target, isNull);
        await tester.enterText(find.byKey(const Key('selection-x')), '600');
        await tester.enterText(find.byKey(const Key('selection-y')), '700');
        await tester.tap(find.byKey(const Key('selection-goto')));
        await tester.pumpAndSettle();
        expect((target!.left, target!.top), (600, 700));
        expect(edit.source, same(before));
        expect(h.maps.editHistory.undoDepth, depth);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
