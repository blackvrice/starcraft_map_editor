import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_project_pane.dart';
import '../fixtures/eud_project_workspace_fixture.dart';

Future<EudWorkspaceFixture> setup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1600);
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
  return fixture;
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text('Edit weapon EUD settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'atomic range and damage edit preserves other fields, saves and undoes',
    (tester) async {
      final f = await setup(tester);
      f.projects.replaceOverrides([
        EudOverride(field: 'unit.hasShield', targetId: 0, value: true),
      ]);
      await tester.pumpAndSettle();
      await open(tester);
      await tester.enterText(find.byKey(const Key('eud-min-range')), '32');
      await tester.enterText(find.byKey(const Key('eud-max-range')), '128');
      await tester.tap(find.byKey(const Key('eud-damage-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explosive').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, hasLength(4));
      expect(f.projects.project!.overrides.last.value, 'Explosive');
      expect(f.workspace.hasUnbuiltOverrides, isTrue);
      await f.workspace.save();
      expect(f.files[f.savePath!]!.overrides, hasLength(4));
      f.projects.undo();
      expect(f.projects.project!.overrides.single.field, 'unit.hasShield');
      f.projects.redo();
      expect(f.projects.project!.overrides, hasLength(4));
    },
  );
  testWidgets(
    'invalid ranges keep draft and cancel or exit cannot mutate project',
    (tester) async {
      final f = await setup(tester);
      final base = f.projects.project;
      await open(tester);
      expect(
        await tester.binding.handleRequestAppExit(),
        AppExitResponse.cancel,
      );
      for (final value in ['-1', '1.5', '4294967296']) {
        await tester.enterText(find.byKey(const Key('eud-min-range')), value);
        await tester.tap(find.text('Apply to project'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(identical(f.projects.project, base), isTrue);
      }
      await tester.enterText(find.byKey(const Key('eud-min-range')), '100');
      await tester.enterText(find.byKey(const Key('eud-max-range')), '50');
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('minimumExceedsMaximum'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.projects.isDirty, isFalse);
      expect(f.projects.canUndo, isFalse);
    },
  );
  testWidgets(
    'blank removes selected weapon overrides and stale project is rejected',
    (tester) async {
      final f = await setup(tester);
      f.projects.replaceOverrides([
        EudOverride(field: 'weapon.minRange', targetId: 0, value: 0),
        EudOverride(field: 'weapon.maxRange', targetId: 1, value: 64),
      ]);
      await tester.pumpAndSettle();
      await open(tester);
      await tester.enterText(find.byKey(const Key('eud-min-range')), '');
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides.single.targetId, 1);
      await open(tester);
      f.projects.undo();
      await tester.enterText(find.byKey(const Key('eud-max-range')), '256');
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Project changed.'), findsOneWidget);
      expect(f.projects.project!.overrides, hasLength(2));
    },
  );
}
