import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/app/document_workspace_host.dart';
import 'package:starcraft_map_editor/presentation/map_canvas/map_canvas.dart';
import '../fixtures/multi_map_fixture.dart';

Future<void> _dispose(WidgetTester tester, MultiMapFixture f) async {
  f.beforeDispose = null;
  await tester.pumpWidget(const SizedBox());
  var done = false;
  final task = f.dispose().whenComplete(() => done = true);
  for (var i = 0; i < 50 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(done, isTrue, reason: 'All document resources must finish disposal.');
  await task;
}

void main() {
  testWidgets(
    'switching and closing an earlier map retain B canvas identity and unapplied settings draft',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = MultiMapFixture(), a = f.addMap(), b = f.addMap(tile: 2);
      f.beforeDispose = () => tester.binding.endOfFrame;
      addTearDown(() => _dispose(tester, f));
      await tester.pumpWidget(
        StarCraftMapEditorApp(dependencies: b.value, workspace: f.workspace),
      );
      await tester.pumpAndSettle();
      final beforeCanvas = tester.state(find.byType(MapCanvas).first),
          beforeB = b.maps.state.session;
      await tester.tap(find.byKey(const Key('map-settings-tab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('map-information-title')),
        'B unapplied title',
      );
      await tester.pump();
      final field = tester
          .widget<TextField>(find.byKey(const Key('map-information-title')))
          .controller;
      await tester.tap(find.byKey(ValueKey('workspace-tab-${a.id}')));
      await tester.pumpAndSettle();
      expect(f.workspace.active, same(a));
      await tester.tap(find.byKey(ValueKey('workspace-tab-${b.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('map-information-title')))
            .controller,
        same(field),
      );
      expect(field!.text, 'B unapplied title');
      expect(b.maps.state.session, same(beforeB));
      await tester.tap(find.byKey(ValueKey('workspace-close-${a.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-close-cancel')));
      await tester.pumpAndSettle();
      expect(f.workspace.documents.length, 2);
      await tester.tap(find.byKey(ValueKey('workspace-close-${a.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-close-discard')));
      await tester.pumpAndSettle();
      expect(f.workspace.documents, [b]);
      expect(field.text, 'B unapplied title');
      final canvasFinder = find.descendant(
        of: find.byKey(
          ValueKey('workspace-editor-${b.id}'),
          skipOffstage: false,
        ),
        matching: find.byType(MapCanvas, skipOffstage: false),
        skipOffstage: false,
      );
      expect(tester.state(canvasFinder.first), same(beforeCanvas));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'exit cancellation keeps every tab; later changed revisions cannot reuse old approval',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = MultiMapFixture(), a = f.addMap(), b = f.addMap();
      addTearDown(() => _dispose(tester, f));
      await tester.pumpWidget(
        StarCraftMapEditorApp(dependencies: b.value, workspace: f.workspace),
      );
      await tester.pumpAndSettle();
      final observer =
          tester.state(find.byType(DocumentWorkspaceHost))
              as WidgetsBindingObserver;
      final first = observer.didRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-close-discard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-close-cancel')));
      await tester.pumpAndSettle();
      expect(await first, AppExitResponse.cancel);
      expect(f.workspace.documents, [a, b]);
      final second = observer.didRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-close-discard')));
      await tester.pumpAndSettle();
      a.sources.createUntitled(initialText: 'late A source');
      await tester.pump();
      await tester.tap(find.byKey(const Key('workspace-close-discard')));
      await tester.pumpAndSettle();
      expect(await second, AppExitResponse.cancel);
      expect(f.workspace.documents, [a, b]);
      final approved = observer.didRequestAppExit();
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('workspace-close-discard')));
        await tester.pumpAndSettle();
      }
      expect(await approved, AppExitResponse.exit);
    },
  );
  testWidgets('new map cancellation leaves both source documents unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final f = MultiMapFixture(), a = f.addMap(), b = f.addMap();
    final sa = a.maps.state.session, sb = b.maps.state.session;
    addTearDown(() => _dispose(tester, f));
    await tester.pumpWidget(
      StarCraftMapEditorApp(dependencies: b.value, workspace: f.workspace),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-new')));
    await tester.pumpAndSettle();
    expect(f.workspace.documents, [a, b]);
    // The wizard owns a separate unpublished controller, even before Create.
    final navigator = Navigator.of(tester.element(find.byType(Dialog).last));
    navigator.pop(false);
    await tester.pumpAndSettle();
    expect(a.maps.state.session, same(sa));
    expect(b.maps.state.session, same(sb));
    expect(f.workspace.documents, [a, b]);
    expect(tester.takeException(), isNull);
    await f.settings.writeString('starcraftInstallationPath', r'C:\SC');
    await f.assets.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-new')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('new-map-tile-1')));
    await tester.tap(find.byKey(const ValueKey('new-map-tile-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-new-map')));
    await tester.pumpAndSettle();
    expect(f.workspace.documents.length, 3);
    expect(f.workspace.active!.maps.state.session, isNotNull);
    expect(a.maps.state.session, same(sa));
    expect(b.maps.state.session, same(sb));
  });
}
