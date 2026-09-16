import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/settings/eud_tool_settings_dialog.dart';
import '../application/eud_tool_settings_controller_test.dart'
    show TestInspector;

void main() {
  testWidgets(
    'external choice exposes failure details and default unavailable state',
    (tester) async {
      final controller = EudToolSettingsController(
        store: InMemorySettingsStore(),
        inspector: TestInspector(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EudToolSettingsDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No bundled tool'), findsOneWidget);
      await tester.enterText(find.byType(TextField), r'C:\Tools\euddraft');
      await tester.tap(find.text('Save and inspect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selection: External'), findsOneWidget);
      expect(find.textContaining('EUD_TOOL_COMPANION_MISSING'), findsOneWidget);
      expect(find.text('missing=lib/freezeMpq.pyd'), findsOneWidget);
      await tester.tap(find.text('Use app default'));
      await tester.pumpAndSettle();
      expect(find.text('Selection: App default'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
