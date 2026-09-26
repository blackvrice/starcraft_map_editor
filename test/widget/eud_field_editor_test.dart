import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_field_manifest.dart';
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
  await tester.tap(find.byKey(const Key('eud-all-fields')));
  await tester.pumpAndSettle();
  return f;
}

Future<void> select(WidgetTester tester, String key) async {
  final field = EudFieldManifest.find(key)!;
  await tester.tap(find.byKey(Key('eud-category-${field.table.name}')));
  await tester.pumpAndSettle();
  tester
      .widget<DropdownButton<EudFieldDefinition>>(
        find.byKey(const Key('eud-extension-field')),
      )
      .onChanged!(field);
  await tester.pumpAndSettle();
}

Future<void> stageNumber(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(const Key('eud-extension-number')), value);
  await tester.tap(find.byKey(const Key('eud-extension-stage')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'categories share a draft, apply atomically, save, undo and redo',
    (tester) async {
      final f = await setup(tester);
      final map = f.maps.state.session!.rawDocument;
      for (final key in [
        'unit.sightRange',
        'weapon.cooldown',
        'flingy.topSpeed',
        'player.terranSupplyMax',
        'sprite.image',
      ]) {
        await select(tester, key);
        await stageNumber(tester, '12');
      }
      for (final key in ['upgrade.mineralCostBase', 'tech.energyCost']) {
        await select(tester, key);
        await stageNumber(tester, '42');
        expect(find.text('explicitChkOverrideRequired'), findsOneWidget);
        await tester.tap(find.byKey(const Key('eud-extension-override-chk')));
        await stageNumber(tester, '42');
      }
      await select(tester, 'image.isClickable');
      tester
          .widget<DropdownButton<Object>>(
            find.byKey(const Key('eud-extension-choice')),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-extension-stage')));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, isEmpty);
      await tester.tap(find.byKey(const Key('eud-extension-apply')));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, hasLength(8));
      expect(identical(f.maps.state.session!.rawDocument, map), isTrue);
      final encoded = f.projects.project!.encode();
      f.projects.undo();
      expect(f.projects.project!.overrides, isEmpty);
      f.projects.redo();
      expect(f.projects.project!.encode(), encoded);
      await f.workspace.save();
      expect(f.projects.isDirty, isFalse);
    },
  );
  testWidgets(
    'invalid values, cancel and stale project leave the project intact',
    (tester) async {
      final f = await setup(tester);
      await select(tester, 'sprite.image');
      await stageNumber(tester, '999');
      expect(find.text('outOfRange'), findsOneWidget);
      await stageNumber(tester, '998');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(f.projects.project!.overrides, isEmpty);
      await tester.tap(find.byKey(const Key('eud-all-fields')));
      await tester.pumpAndSettle();
      await stageNumber(tester, '1');
      f.projects.replaceOverrides([
        EudOverride(field: 'weapon.cooldown', targetId: 0, value: 9),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-extension-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Project changed'), findsOneWidget);
      expect(f.projects.project!.overrides.single.value, 9);
    },
  );
  testWidgets('saved values hydrate and removal is explicit and undoable', (
    tester,
  ) async {
    final f = await setup(tester);
    await select(tester, 'player.protossPsiMax');
    await stageNumber(tester, '400');
    await tester.tap(find.byKey(const Key('eud-extension-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eud-all-fields')));
    await tester.pumpAndSettle();
    await select(tester, 'player.protossPsiMax');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('eud-extension-number')))
          .controller!
          .text,
      '400',
    );
    await tester.tap(find.byKey(const Key('eud-extension-remove')));
    await tester.pumpAndSettle();
    expect(f.projects.project!.overrides, hasLength(1));
    await tester.tap(find.byKey(const Key('eud-extension-apply')));
    await tester.pumpAndSettle();
    expect(f.projects.project!.overrides, isEmpty);
    f.projects.undo();
    expect(f.projects.project!.overrides.single.value, 400);
  });
}
