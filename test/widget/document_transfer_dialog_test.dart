import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/app/app.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  for (final width in [600.0, 1200.0]) {
    testWidgets(
      'Korean transfer preview, cancel and atomic apply at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = MultiMapFixture(), a = f.addMap(), b = f.addMap();
        await f.settings.writeString('uiLanguage', 'ko');
        adoptTransferDocument(
          a.maps,
          transferSource(),
          resources: {r'staredit\wav\transfer.wav': pcmSoundFixture()},
        );
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
        final before = b.maps.state.session;
        await tester.tap(find.byKey(const Key('workspace-transfer')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('취소').last);
        await tester.pumpAndSettle();
        expect(b.maps.state.session, same(before));
        await tester.tap(find.byKey(const Key('workspace-transfer')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('트리거 (1)'));
        await tester.pumpAndSettle();
        final trigger = find.byKey(const ValueKey('transfer-trigger-0'));
        await tester.ensureVisible(trigger);
        await tester.tap(trigger);
        await tester.pump();
        await tester.tap(find.byKey(const Key('transfer-preview')));
        await tester.pumpAndSettle();
        expect(b.maps.state.session, same(before));
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('transfer-apply')))
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const Key('transfer-apply')));
        await tester.pumpAndSettle();
        expect(f.workspace.active, same(b));
        expect(
          ChkTriggers.read(b.maps.state.session!.rawDocument).records.length,
          1,
        );
        expect(b.maps.editHistory.undoDepth, 1);
        expect(b.maps.state.session!.resourceEdits.length, 1);
      },
    );
  }
}
