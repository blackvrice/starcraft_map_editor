import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/new_map_dialog.dart';
import '../fixtures/new_map_harness.dart';

void main() {
  for (final discard in [false, true]) {
    testWidgets(
      'new map requires a tile and confirms dirty replacement ($discard)',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = NewMapHarness();
        addTearDown(h.dispose);
        final original = h.maps
            .createNew(NewMapOptions(rawTileValue: 0), expectedSession: null)
            .session!;
        final c = h.controller();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => NewMapDialog(controller: c),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('create-new-map')))
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const ValueKey('new-map-tile-1')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('create-new-map')));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved map changes?'), findsOneWidget);
        await tester.tap(
          find.text(discard ? 'Discard and create' : 'Keep current map'),
        );
        await tester.pumpAndSettle();
        if (discard) {
          expect(h.maps.state.session, isNot(same(original)));
          expect(find.byType(NewMapDialog), findsNothing);
        } else {
          expect(h.maps.state.session, same(original));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(h.maps.state.session, same(original));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('guides through size, players and review in Korean', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = NewMapHarness();
    addTearDown(h.dispose);
    final c = h.controller();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: NewMapDialog(controller: c)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('크기와 지형'), findsWidgets);
    await tester.tap(find.byKey(const Key('new-map-size-64')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('new-map-tile-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-map-next')));
    await tester.pumpAndSettle();
    expect(find.text('몇 명이 플레이하나요?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-map-players-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('new-map-next')));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 만들어요'), findsOneWidget);
    expect(find.text('64 × 64'), findsOneWidget);
    expect(find.text('4명'), findsOneWidget);
    expect(find.text('처음 타일 #1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-new-map')));
    await tester.pumpAndSettle();
    final session = h.maps.state.session!;
    expect(session, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
