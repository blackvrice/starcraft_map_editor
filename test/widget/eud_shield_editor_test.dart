import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_project_pane.dart';
import '../fixtures/eud_project_workspace_fixture.dart';

Future<EudWorkspaceFixture> setup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final f = EudWorkspaceFixture();
  addTearDown(f.dispose);
  await f.maps.open();
  await f.workspace.createFromMap();
  await f.workspace.saveAs();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: EudProjectPane(workspace: f.workspace)),
    ),
  );
  return f;
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text('Edit unit EUD shields'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'selected unit shields require explicit CHK override and preserve other settings and map',
    (tester) async {
      final f = await setup(tester);
      final document = f.maps.state.session!.rawDocument;
      f.projects.replaceOverrides([
        EudOverride(field: 'weapon.maxRange', targetId: 0, value: 64),
      ]);
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('eud-reference-unit')),
          )
          .onChanged!(227);
      await tester.pumpAndSettle();
      await open(tester);
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('eud-shield-enabled')),
          )
          .onChanged!('true');
      await tester.enterText(
        find.byKey(const Key('eud-shield-maximum')),
        '65535',
      );
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('explicitChkOverrideRequired'),
        findsOneWidget,
      );
      expect(f.projects.project!.overrides, hasLength(1));
      await tester.tap(find.byKey(const Key('eud-shield-override-chk')));
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, hasLength(3));
      expect(f.projects.project!.overrides.last.targetId, 227);
      expect(f.projects.project!.overrides.last.overrideChk, isTrue);
      expect(identical(f.maps.state.session!.rawDocument, document), isTrue);
      await f.workspace.save();
      expect(f.files[f.savePath!]!.overrides.last.value, 65535);
      f.projects.undo();
      expect(f.projects.project!.overrides.single.field, 'weapon.maxRange');
      f.projects.redo();
      expect(f.projects.project!.overrides, hasLength(3));
    },
  );
  testWidgets(
    'invalid maximum preserves draft, exit is blocked and cancel stays clean',
    (tester) async {
      final f = await setup(tester);
      await open(tester);
      expect(
        await tester.binding.handleRequestAppExit(),
        AppExitResponse.cancel,
      );
      await tester.tap(find.byKey(const Key('eud-shield-override-chk')));
      for (final value in ['-1', '1.5', '65536']) {
        await tester.enterText(
          find.byKey(const Key('eud-shield-maximum')),
          value,
        );
        await tester.tap(find.text('Apply to project'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(f.projects.project!.overrides, isEmpty);
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.projects.isDirty, isFalse);
    },
  );
  testWidgets(
    'disabled differs from removed and stale drafts cannot overwrite project',
    (tester) async {
      final f = await setup(tester);
      await open(tester);
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('eud-shield-enabled')),
          )
          .onChanged!('false');
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides.single.value, false);
      await open(tester);
      tester
          .widget<DropdownButton<String>>(
            find.byKey(const Key('eud-shield-enabled')),
          )
          .onChanged!('');
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, isEmpty);
      await open(tester);
      f.projects.undo();
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Project changed.'), findsOneWidget);
      expect(f.projects.project!.overrides.single.value, false);
    },
  );
}
