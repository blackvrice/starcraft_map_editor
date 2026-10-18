import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/ports/trigger_script_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/triggers/trigger_pane.dart';
import '../fixtures/editor_overlay_fixture.dart';
import '../fixtures/trigger_script_fixture.dart';

class _InlineGateway implements TriggerScriptGateway {
  @override
  void cancel(String operationId) {}
  @override
  Future<TriggerScriptAnalysis> analyze({
    required String operationId,
    required RawChkDocument document,
    required TriggerScriptLanguage language,
    String? source,
    TriggerScriptLanguage? target,
  }) async {
    final snapshot = TriggerScriptSnapshot(document);
    try {
      final program = source == null
          ? snapshot.initial
          : snapshot.parse(source, language);
      return TriggerScriptAnalysis(
        program: program,
        generated: snapshot.format(program, target ?? language),
      );
    } on TriggerScriptDiagnostic catch (e) {
      return TriggerScriptAnalysis(diagnostic: e);
    }
  }
}

void main() {
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets(
      'three-language preview, explicit acceptance and one Undo at width=$width',
      (tester) async {
        tester.view.physicalSize = Size(width, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = OverlayHarness();
        h.editing.apply(
          h.editing.source.rawDocument,
          scriptDocument(),
          'Fixture',
        );
        final editing = ObjectEditingController(
          openMapController: h.h.maps,
          mapLayerController: h.layers,
          triggerScriptGateway: _InlineGateway(),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: TriggerPane(controller: editing)),
          ),
        );
        await tester.tap(find.byKey(const Key('trigger-script')));
        await tester.pumpAndSettle();
        final before = h.h.maps.state.session,
            depth = h.h.maps.editHistory.undoDepth;
        final source = tester
            .widget<TextField>(find.byKey(const Key('script-source')))
            .controller!;
        final original = '${source.text}\n// 원문\n';
        await tester.enterText(
          find.byKey(const Key('script-source')),
          original.replaceFirst(', 1000)', ', 1234)'),
        );
        await tester.tap(find.byKey(const Key('script-convert')));
        await tester.pumpAndSettle();
        expect(source.text, contains('// 원문'));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('script-preview')))
              .controller!
              .text,
          contains('True'),
        );
        expect(h.h.maps.state.session, same(before));
        expect(h.h.maps.editHistory.undoDepth, depth);
        await tester.tap(find.byKey(const Key('script-accept-conversion')));
        await tester.pumpAndSettle();
        expect(source.text, startsWith('#'));
        await tester.tap(find.byKey(const Key('script-language')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('lua').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('script-convert')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('script-accept-conversion')));
        await tester.pumpAndSettle();
        expect(source.text, startsWith('--'));
        expect(h.h.maps.state.session, same(before));
        await tester.tap(find.byKey(const Key('script-validate')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('script-apply')));
        await tester.pumpAndSettle();
        expect(h.h.maps.editHistory.undoDepth, depth + 1);
        final record = ChkTriggers.read(
          h.h.maps.state.session!.rawDocument,
        ).records.single;
        final arg = TriggerOpcodes.find(true, 4)!.arguments.single;
        expect(ChkTrigger.argument(record.slot(true, 4), arg), 1234);
        await tester.tap(find.byKey(const Key('script-close')));
        await tester.pumpAndSettle();
        // Applying TRIG must not silently discard archived source/comments.
        expect(find.byKey(const Key('script-source')), findsOneWidget);
        await tester.tap(find.byKey(const Key('script-discard-close')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('script-source')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          await editing.dispose();
          await h.dispose();
        });
      },
    );
  }
  testWidgets(
    'invalid source cannot apply and closing dirty text requires explicit discard',
    (tester) async {
      final h = OverlayHarness();
      h.editing.apply(
        h.editing.source.rawDocument,
        scriptDocument(),
        'Fixture',
      );
      final editing = ObjectEditingController(
        openMapController: h.h.maps,
        mapLayerController: h.layers,
        triggerScriptGateway: _InlineGateway(),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TriggerPane(controller: editing)),
        ),
      );
      await tester.tap(find.byKey(const Key('trigger-script')));
      await tester.pumpAndSettle();
      final before = h.h.maps.state.session;
      await tester.enterText(
        find.byKey(const Key('script-source')),
        'import os;',
      );
      await tester.tap(find.byKey(const Key('script-validate')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('script-apply')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('script-diagnostic')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const Key('script-source')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('script-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('script-source')), findsOneWidget);
      await tester.tap(find.byKey(const Key('script-discard-close')));
      await tester.pumpAndSettle();
      expect(h.h.maps.state.session, same(before));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await editing.dispose();
        await h.dispose();
      });
    },
  );
}
