import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_project_pane.dart';
import '../fixtures/eud_project_workspace_fixture.dart';

void main() {
  testWidgets(
    'verification enables preview and project edits or disk changes invalidate it',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = EudWorkspaceFixture();
      addTearDown(fixture.dispose);
      await fixture.maps.open();
      await fixture.workspace.createFromMap();
      fixture.projects.replaceOverrides([
        EudOverride(field: 'unit.hasShield', targetId: 0, value: true),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EudProjectPane(workspace: fixture.workspace)),
        ),
      );
      expect(
        find.textContaining('Planned EUD value: Unresolved'),
        findsOneWidget,
      );
      await tester.tap(find.text('Verify current map'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Planned EUD value: true'), findsOneWidget);
      expect(find.textContaining('Not stored in CHK'), findsOneWidget);
      fixture.projects.replaceOverrides([
        EudOverride(field: 'unit.hasShield', targetId: 0, value: false),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Planned EUD value: Unresolved'),
        findsOneWidget,
      );
      fixture.hash = 'b' * 64;
      await tester.tap(find.text('Verify current map'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Planned EUD value: Unresolved'),
        findsOneWidget,
      );
      expect(fixture.writes, 0);
    },
  );
}
