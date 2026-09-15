import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_project_pane.dart';
import '../fixtures/eud_project_workspace_fixture.dart';

void main() {
  testWidgets(
    'Save Project updates current file and displays external conflict without discarding edits',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = EudWorkspaceFixture();
      addTearDown(fixture.dispose);
      await fixture.maps.open();
      await fixture.workspace.createFromMap();
      await fixture.workspace.saveAs();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EudProjectPane(workspace: fixture.workspace)),
        ),
      );
      final save = find.widgetWithText(OutlinedButton, 'Save Project');
      expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
      fixture.projects.replaceOverrides([
        EudOverride(field: 'unit.hasShield', targetId: 0, value: true),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(fixture.projects.isDirty, isFalse);
      expect(fixture.writes, 2);
      expect(find.textContaining('Recovery backup:'), findsOneWidget);
      fixture.files[fixture.savePath!] = fixture.projects.project!
          .withOverrides([]);
      fixture.projects.replaceOverrides([
        EudOverride(field: 'unit.hasShield', targetId: 0, value: false),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(fixture.projects.isDirty, isTrue);
      expect(fixture.writes, 2);
      expect(find.textContaining('changed outside the editor'), findsOneWidget);
      expect(fixture.files[fixture.savePath!]!.overrides, isEmpty);
    },
  );
  testWidgets(
    'project create save close cancel and reopen never write the map',
    (tester) async {
      final fixture = EudWorkspaceFixture();
      addTearDown(fixture.dispose);
      await fixture.maps.open();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EudProjectPane(workspace: fixture.workspace)),
        ),
      );
      await tester.tap(find.text('New from current map'));
      await tester.pumpAndSettle();
      expect(find.text('EUD Project • Unsaved'), findsOneWidget);
      await tester.tap(find.text('Close Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fixture.projects.project, isNotNull);
      await tester.tap(find.text('Save Project As'));
      await tester.pumpAndSettle();
      expect(find.text('EUD Project'), findsOneWidget);
      expect(fixture.writes, 1);
      await tester.tap(find.text('Close Project'));
      await tester.pumpAndSettle();
      fixture.openPath = fixture.savePath;
      await tester.tap(find.text('Open Project'));
      await tester.pumpAndSettle();
      expect(fixture.projects.project, isNotNull);
      expect(fixture.projects.isDirty, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'imported overrides show names and exit request protects unsaved project',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = EudWorkspaceFixture();
      addTearDown(fixture.dispose);
      fixture.projects.create(
        EudProject(
          mapPath: r'C:\Maps\base.scx',
          mapSha256: 'a' * 64,
          overrides: [
            EudOverride(field: 'unit.hasShield', targetId: 0, value: true),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EudProjectPane(workspace: fixture.workspace)),
        ),
      );
      expect(find.text('unit.hasShield — Terran Marine (#0)'), findsOneWidget);
      expect(find.textContaining('EUD Build is disabled'), findsOneWidget);
      final exit = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await exit, AppExitResponse.cancel);
      expect(fixture.projects.isDirty, isTrue);
    },
  );
}
