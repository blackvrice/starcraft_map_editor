import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/map_resize_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/presentation/documents/map_resize_dialog.dart';
import '../fixtures/new_map_harness.dart';
import 'package:starcraft_map_editor/application/documents/isom_fill_controller.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import '../fixtures/solid_isom_fixture.dart';
import '../fixtures/isom_ramp_fixture.dart';

void main() {
  for (final locale in ['ko', 'en']) {
    testWidgets(
      'ISOM resize loads data and previews doodad impact in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = NewMapHarness();
        addTearDown(h.dispose);
        h.maps.createNew(
          NewMapOptions(width: 32, height: 32, rawTileValue: 0),
          expectedSession: null,
        );
        final loader = IsomFillController(
          maps: h.maps,
          assets: () => h.assets,
          gateway: SolidSnapshotGateway(),
          placementGateway: IsomRampGateway(),
        );
        await loader.load();
        loader.apply(loader.preview(terrainType: 2));
        await loader.load();
        loader.apply(
          loader.previewRamp(recipe: loader.ramps.single, x: 4, y: 8),
        );
        final before = h.maps.state.session!;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MapResizeDialog(
                    controller: MapResizeController(
                      h.maps,
                      terrainLoader: loader,
                    ),
                  ),
                ),
                child: const Text('Resize'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Resize'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('resize-width')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('64').last);
        await tester.pumpAndSettle();
        expect(h.maps.state.session, same(before));
        expect(
          find.textContaining(locale == 'ko' ? '이동할 두다드:' : 'Doodads moved:'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('resize-apply')))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const Key('resize-apply')));
        await tester.pumpAndSettle();
        expect(h.maps.state.session!.terrainViews.tileMaps.single.width, 64);
        h.maps.editHistory.undo();
        expect(h.maps.state.session, same(before));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'preview changes do not mutate the map; cancel and explicit apply work',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 64, height: 64, rawTileValue: 1),
        expectedSession: null,
      );
      final before = h.maps.state.session;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    MapResizeDialog(controller: MapResizeController(h.maps)),
              ),
              child: const Text('Resize'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Resize'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('resize-apply')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('resize-width')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('96').last);
      await tester.pumpAndSettle();
      expect(h.maps.state.session, same(before));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.maps.state.session, same(before));
      await tester.tap(find.text('Resize'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resize-width')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('96').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resize-apply')));
      await tester.pumpAndSettle();
      expect(h.maps.state.session!.terrainViews.tileMaps.single.width, 96);
      expect(find.text('Resize Map'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cropping needs explicit confirmation and changing options clears it',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = NewMapHarness();
      addTearDown(h.dispose);
      h.maps.createNew(
        NewMapOptions(width: 96, height: 64, rawTileValue: 1),
        expectedSession: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapResizeDialog(controller: MapResizeController(h.maps)),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('resize-width')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('64').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('resize-apply')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('resize-confirm-crop')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('resize-apply')))
            .onPressed,
        isNotNull,
      );
      await tester.enterText(find.byKey(const Key('resize-fill-x')), '1');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('resize-apply')))
            .onPressed,
        isNull,
      );
      expect(h.maps.state.session!.terrainViews.tileMaps.single.width, 96);
    },
  );
}
