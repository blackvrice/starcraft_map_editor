import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_brush_library.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/basic_editing_tools_dialog.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/user_terrain_brush_fixture.dart';

void main() {
  for (final width in [600.0, 1200.0]) {
    testWidgets(
      'Korean brush save/preview/apply/Undo and confirmed delete at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = NewMapHarness(),
            layers = MapLayerController(),
            store = MemoryTerrainBrushStore();
        addTearDown(h.dispose);
        addTearDown(layers.dispose);
        final editing = BasicEditingController(maps: h.maps, layers: layers);
        addTearDown(editing.dispose);
        h.maps.createNew(
          NewMapOptions(width: 32, height: 32, rawTileValue: 2),
          expectedSession: null,
        );
        final library = TerrainBrushLibrary(store);
        await library.add(rawUserBrush());
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BasicEditingToolsDialog(
                controller: editing,
                brushLibrary: library,
                initialTab: 8,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('사용자 지형 브러시'), findsWidgets);
        await tester.enterText(find.byKey(const Key('brush-name')), 'Saved');
        await tester.ensureVisible(find.byKey(const Key('brush-save')));
        await tester.tap(find.byKey(const Key('brush-save')));
        await tester.pumpAndSettle();
        expect(store.values.length, 2);
        // Saved captures the current tile; choose Cliff to produce an actual edit.
        final dropdown = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField &&
              w.key.toString().contains('brush-selection'),
        );
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Cliff').last);
        await tester.pumpAndSettle();
        final before = editing.source, depth = h.maps.editHistory.undoDepth;
        if (find.byKey(const Key('brush-preview')).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('brush-preview')),
            160,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('brush-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(find.byKey(const Key('brush-preview')));
        await tester.tap(find.byKey(const Key('brush-preview')));
        await tester.pumpAndSettle();
        expect(editing.source, same(before));
        expect(h.maps.editHistory.undoDepth, depth);
        await tester.ensureVisible(find.byKey(const Key('brush-apply')));
        await tester.tap(find.byKey(const Key('brush-apply')));
        await tester.pumpAndSettle();
        expect(h.maps.editHistory.undoDepth, depth + 1);
        await tester.tap(find.byTooltip('실행 취소'));
        await tester.pumpAndSettle();
        expect(editing.source, same(before));
        if (find.byKey(const Key('brush-delete')).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('brush-delete')),
            -160,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('brush-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(find.byKey(const Key('brush-delete')));
        await tester.tap(find.byKey(const Key('brush-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(store.values.length, 2);
        await tester.tap(find.byKey(const Key('brush-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('브러시 삭제'));
        await tester.pumpAndSettle();
        expect(store.values.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
