import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/basic_editing_tools_dialog.dart';
import '../fixtures/new_map_harness.dart';
import '../fixtures/mixed_clipboard_fixture.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  testWidgets(
    'multiple doodad overlays require explicit confirmation before copy and preview',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
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
      final c = BasicEditingController(maps: h.maps, layers: layers);
      addTearDown(c.dispose);
      c.apply(c.source.rawDocument, mixedDocument(), 'Fixture');
      final loader = IsomFillController(
        maps: h.maps,
        assets: () => h.assets,
        gateway: SolidSnapshotGateway(),
        placementGateway: MixedDoodadGateway(),
      );
      final before = c.source;
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BasicEditingToolsDialog(
              controller: c,
              isomController: loader,
              initialTab: 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('mixed-bottom')), '5');
      await tester.tap(find.byKey(const Key('mixed-load')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mixed-scan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mixed-copy')));
      await tester.pumpAndSettle();
      expect(c.mixedClipboard.clipboard, isNull);
      expect(c.source, same(before));
      final dropdowns = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(dropdowns.at(0));
      await tester.tap(dropdowns.at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('THG2 #3 · 96, 80').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(dropdowns.at(1));
      await tester.tap(dropdowns.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('THG2 #2 · 192, 80').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('mixed-copy')),
        -200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('mixed-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const Key('mixed-copy')));
      await tester.pumpAndSettle();
      expect(c.mixedClipboard.clipboard?.objectCount, 8);
      await tester.ensureVisible(find.byKey(const Key('mixed-preview-paste')));
      await tester.tap(find.byKey(const Key('mixed-preview-paste')));
      await tester.pumpAndSettle();
      expect(c.source, same(before));
      expect(c.mixedClipboard.preview, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [1200.0, 600.0]) {
    testWidgets(
      'Korean mixed region UI copy/preview/apply/undo at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
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
        final c = BasicEditingController(maps: h.maps, layers: layers);
        addTearDown(c.dispose);
        c.apply(
          c.source.rawDocument,
          mixedPut(c.source.rawDocument, 'THG2', [
            130,
            0,
            32,
            0,
            32,
            0,
            0,
            0,
            0,
            16,
          ]),
          'Sprite',
        );
        final before = c.source,
            bytes = const RawChkEncoder().encode(c.source.rawDocument),
            depth = h.maps.editHistory.undoDepth;
        addTearDown(() => tester.pumpWidget(const SizedBox()));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ko'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BasicEditingToolsDialog(controller: c, initialTab: 7),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('혼합 영역 복사'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('mixed-copy')));
        await tester.tap(find.byKey(const Key('mixed-copy')));
        await tester.pumpAndSettle();
        expect(c.mixedClipboard.clipboard?.objectCount, 1);
        expect(c.source, same(before));
        await tester.ensureVisible(
          find.byKey(const Key('mixed-preview-paste')),
        );
        await tester.tap(find.byKey(const Key('mixed-preview-paste')));
        await tester.pumpAndSettle();
        expect(c.source, same(before));
        expect(h.maps.editHistory.undoDepth, depth);
        await tester.ensureVisible(find.byKey(const Key('mixed-apply')));
        await tester.tap(find.byKey(const Key('mixed-apply')));
        await tester.pumpAndSettle();
        expect(c.source.objectViews.spriteSections.single.sprites.length, 2);
        expect(h.maps.editHistory.undoDepth, depth + 1);
        await tester.tap(find.byTooltip('실행 취소'));
        await tester.pumpAndSettle();
        expect(const RawChkEncoder().encode(c.source.rawDocument), bytes);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
