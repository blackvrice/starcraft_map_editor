import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_source_editor.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/ep_script_text_controller.dart';

void main() {
  testWidgets('named completion accepts Tab and updates dirty source only', (
    tester,
  ) async {
    final sources = EudSourceController()..createUntitled(initialText: '');
    addTearDown(sources.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EudSourceEditor(
            document: sources.state.document!,
            sourceController: sources,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('eud-source-editor')), 'Dis');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ep-script-complete-DisplayText')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(sources.state.document!.text, 'DisplayText');
    expect(sources.state.document!.isDirty, isTrue);
    expect(find.byKey(const Key('ep-script-completions')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Korean help explains use and example does not erase selected user source',
    (tester) async {
      tester.view.physicalSize = const Size(600, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sources = EudSourceController()
        ..createUntitled(initialText: '// Keep my source');
      addTearDown(sources.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: EudSourceEditor(
              document: sources.state.document!,
              sourceController: sources,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ep-script-help')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(sources.state.document!.text, '// Keep my source');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<TextField>(find.byKey(const Key('eud-source-editor')))
          .controller!;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.tap(find.byKey(const Key('ep-script-example')));
      await tester.pumpAndSettle();
      expect(
        sources.state.document!.text,
        '// Keep my source\n$epScriptStarter',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
