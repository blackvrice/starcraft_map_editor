import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/presentation/settings/eud_build_preparation_dialog.dart';
import '../application/eud_build_preparation_controller_test.dart'
    show PreparationHarness;

void main() {
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
