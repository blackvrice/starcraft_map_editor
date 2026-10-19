import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/source_workspace_pane.dart';
import '../fixtures/source_workspace_fixture.dart';

void main() {
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets('tabs, project tree, search and conflict controls at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = MemorySourceWorkspace();
      final controller = EudSourceController(workspaceGateway: files);
      addTearDown(controller.dispose);
      await tester.runAsync(() async {
        await controller.chooseWorkspace();
        await controller.openRelative('main.eps');
        await controller.openRelative('util.eps');
        await controller.rebuildIndex();
      });
      final first = controller.documents.first.documentId,
          second = controller.state.document!.documentId;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: StreamBuilder(
              stream: controller.changes,
              builder: (context, _) => Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: SourceWorkspaceNavigator(
                      controller: controller,
                      onSelected: () {},
                    ),
                  ),
                  Expanded(child: SourceWorkspacePane(controller: controller)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(Key('source-tab-$first')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('eud-source-editor')),
        'const MyDraft=123;',
      );
      await tester.runAsync(controller.rebuildIndex);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('source-tab-$second')));
      await tester.pumpAndSettle();
      expect(controller.state.document!.text, 'function Work() {}');
      await tester.tap(find.byKey(Key('source-tab-$first')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eud-source-editor')))
            .controller!
            .text,
        'const MyDraft=123;',
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('source-project-search')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('source-project-query')),
        'Work',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source-search-hit-0')));
      await tester.pumpAndSettle();
      expect(controller.state.document!.documentId, second);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('eud-source-editor')))
            .controller!
            .selection
            .baseOffset,
        9,
      );
      files.text['main.eps'] = 'external';
      await tester.runAsync(controller.refreshWorkspace);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('source-conflict-banner')), findsOneWidget);
      await tester.tap(find.byKey(Key('source-tab-$first')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('source-save-active')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(Key('source-close-$first')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.text(locale.languageCode == 'ko' ? '취소' : 'Cancel').last,
      );
      await tester.pumpAndSettle();
      expect(controller.documents, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
