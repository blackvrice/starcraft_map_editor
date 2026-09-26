import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/settings/eud_build_preparation_dialog.dart';
import '../application/eud_build_preparation_controller_test.dart'
    show PreparationHarness, ProjectPreparationFiles;
import '../fixtures/eud_project_workspace_fixture.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_preparation_controller.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';

void main() {
  testWidgets(
    'settings-only test build is explicit and works without an entry file',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = PreparationHarness();
      final f = EudWorkspaceFixture();
      addTearDown(h.dispose);
      addTearDown(f.dispose);
      await f.maps.open();
      await f.workspace.createFromMap();
      f.projects.replaceOverrides([
        EudOverride(field: 'weapon.cooldown', targetId: 15, value: 11),
      ]);
      final controller = EudBuildPreparationController(
        tools: h.tools,
        builds: h.builds,
        files: ProjectPreparationFiles(),
        blockReason: () => null,
        projects: f.workspace,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EudBuildPreparationDialog(
            controller: controller,
            baseMap: f.projects.project!.mapPath,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField).at(3),
        r'C:\out\generated.scx',
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enable the unverified settings'),
        findsOneWidget,
      );
      expect(h.builds.canStart, isFalse);
      await tester.tap(find.byKey(const Key('eud-test-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare'));
      await tester.pumpAndSettle();
      expect(h.builds.state.plan!.configuration.settingsOnly, isTrue);
    },
  );
  testWidgets('saved-file form requires trust and prepares without compiling', (
    tester,
  ) async {
    final h = PreparationHarness();
    addTearDown(h.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    EudBuildPreparationDialog(controller: h.controller),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Prepare'))
          .onPressed,
      isNull,
    );
    final paths = [
      r'C:\maps\base.scx',
      r'C:\src',
      r'C:\src\main.eps',
      r'C:\out\new.scx',
    ];
    for (var i = 0; i < paths.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), paths[i]);
    }
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();
    expect(h.builds.canStart, true);
    expect(find.text('Prepare EUD Build'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
