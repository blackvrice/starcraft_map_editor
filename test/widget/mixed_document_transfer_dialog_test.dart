import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/multi_map_fixture.dart';

void main() {
  for (final width in [600.0, 1200.0]) {
    testWidgets(
      'mixed cross-map copy is read-only until Apply and has no source Cut/Undo at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = MultiMapFixture(),
            a = f.addMap(tile: 9),
            b = f.addMap(tile: 2);
        await f.settings.writeString('uiLanguage', 'ko');
        f.workspace.activate(a.id);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          var done = false;
          final task = f.dispose().whenComplete(() => done = true);
          for (var i = 0; i < 50 && !done; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(done, isTrue);
          await task;
        });
        await tester.pumpWidget(
          StarCraftMapEditorApp(dependencies: a.value, workspace: f.workspace),
        );
        await tester.pumpAndSettle();
        final beforeA = a.maps.state.session, beforeB = b.maps.state.session;
        await tester.tap(find.byKey(const Key('workspace-transfer-region')));
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byKey(const Key('mixed-list')),
              matching: find.byType(Scrollable),
            )
            .first;
        Future<void> tap(String key) async {
          final finder = find.byKey(Key(key));
          await tester.scrollUntilVisible(finder, 150, scrollable: scrollable);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        await tap('mixed-copy');
        await tap('mixed-preview-paste');
        expect(a.maps.state.session, same(beforeA));
        expect(b.maps.state.session, same(beforeB));
        expect(find.byKey(const Key('mixed-preview-cut')), findsNothing);
        await tap('mixed-apply');
        expect(a.maps.state.session, same(beforeA));
        expect(a.maps.editHistory.undoDepth, 0);
        expect(b.maps.editHistory.undoDepth, 1);
        expect(
          basicData(
            b.maps.state.session!.rawDocument,
            'MTXM',
          ).getUint16((8 * 32 + 8) * 2, Endian.little),
          9,
        );
        late Future<bool> closing;
        await tester.runAsync(() async {
          closing = f.workspace.close(
            b,
            expectedRevision: b.revision,
            discardChanges: true,
          );
        });
        await tester.pumpAndSettle();
        final closeResult = await tester.runAsync(
          () => closing.timeout(const Duration(seconds: 3)),
        );
        expect(closeResult, isTrue);
        await tester.pumpAndSettle();
        expect(find.text('WORKSPACE_DOCUMENT_STALE'), findsOneWidget);
      },
    );
  }
}
