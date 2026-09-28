import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_project_controller.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/presentation/eud_editor/eud_rules_editor.dart';
import '../application/eud_project_controller_test.dart' show MemoryStore;
import '../domain/eud/eud_execution_rule_test.dart' show rule;

void main() {
  testWidgets('extended form applies typed values and ordering is undoable', (
    tester,
  ) async {
    final controller = EudProjectController(MemoryStore());
    addTearDown(controller.dispose);
    controller.create(
      EudProject(
        mapPath: 'base.scx',
        mapSha256: 'a' * 64,
        rules: [rule(id: 'existing')],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreamBuilder<void>(
            stream: controller.changes,
            builder: (_, _) =>
                EudRulesEditor(controller: controller, enabled: true),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('eud-rule-add')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Extended execution rule'));
    await tester.tap(find.text('Extended execution rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eud-rule-apply')));
    await tester.pumpAndSettle();
    expect(controller.project!.rules.last.extension, isNotNull);
    final added = controller.project!.rules.last.id;
    await tester.tap(find.byTooltip('Move rule up').last);
    await tester.pump();
    expect(controller.project!.rules.first.id, added);
    controller.undo();
    await tester.pump();
    expect(controller.project!.rules.first.id, 'existing');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rule form applies, cancels, validates duplicate writes and supports undo',
    (tester) async {
      final controller = EudProjectController(MemoryStore());
      addTearDown(controller.dispose);
      controller.create(EudProject(mapPath: 'base.scx', mapSha256: 'a' * 64));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamBuilder<void>(
              stream: controller.changes,
              builder: (_, _) =>
                  EudRulesEditor(controller: controller, enabled: true),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('eud-rule-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.project!.rules, isEmpty);
      await tester.tap(find.byKey(const Key('eud-rule-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-rule-apply')));
      await tester.pumpAndSettle();
      expect(controller.project!.rules, hasLength(1));
      await tester.tap(find.byKey(const Key('eud-rule-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('eud-rule-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('duplicateResourceWrite'), findsOneWidget);
      expect(controller.project!.rules, hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      controller.undo();
      await tester.pump();
      expect(controller.project!.rules, isEmpty);
      controller.redo();
      await tester.pump();
      expect(controller.project!.rules, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'rules survive save/open, field edits and rebind; stale drafts are rejected',
    () async {
      final controller = EudProjectController(MemoryStore());
      addTearDown(controller.dispose);
      controller.create(EudProject(mapPath: 'base.scx', mapSha256: 'a' * 64));
      final before = controller.project!;
      controller.replaceRules([rule()], expectedProject: before);
      expect(
        () => controller.replaceRules([], expectedProject: before),
        throwsStateError,
      );
      controller.replaceOverrides([
        EudOverride(field: 'weapon.maxRange', targetId: 0, value: 200),
      ]);
      controller.rebindMap(mapPath: 'other.scx', mapSha256: 'b' * 64);
      await controller.saveAs('project.json');
      controller.close();
      await controller.open('project.json');
      expect(controller.project!.rules.single.id, 'income');
      expect(controller.project!.overrides.single.value, 200);
      expect(controller.project!.mapPath, 'other.scx');
      expect(controller.isDirty, isFalse);
    },
  );
}
