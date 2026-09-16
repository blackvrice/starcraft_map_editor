import 'dart:async';
import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/application/ports/eud_tool_directory_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/settings/eud_tool_settings_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/presentation/settings/eud_tool_settings_dialog.dart';
import '../application/eud_tool_settings_controller_test.dart'
    show TestInspector;

void main() {
  for (final outcome in ['selected', 'cancelled', 'failed', 'closed']) {
    testWidgets(
      'directory browsing $outcome preserves saved choice until Save',
      (tester) async {
        final picker = _Picker();
        final store = InMemorySettingsStore({
          EudToolSettingsController.settingsKey: r'C:\old',
        });
        final inspector = TestInspector();
        final controller = EudToolSettingsController(
          store: store,
          inspector: inspector,
          directoryPicker: picker,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: EudToolSettingsDialog(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), r'C:\draft');
        final before = inspector.requests.length;
        await tester.tap(find.text('Browse installation folder'));
        await tester.pump();
        expect(controller.state.busy, isTrue);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save and inspect'),
              )
              .onPressed,
          isNull,
        );
        if (outcome == 'closed') await tester.pumpWidget(const SizedBox());
        if (outcome == 'failed') {
          picker.result.completeError(StateError('dialog failed'));
        } else {
          picker.result.complete(outcome == 'cancelled' ? null : r'C:\도구 폴더');
        }
        await tester.pumpAndSettle();
        expect(controller.state.busy, isFalse);
        expect(controller.state.path, r'C:\old');
        expect(inspector.requests.length, before);
        expect(
          await store.readString(EudToolSettingsController.settingsKey),
          r'C:\old',
        );
        if (outcome != 'closed') {
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            outcome == 'selected' ? r'C:\도구 폴더' : r'C:\draft',
          );
        }
        if (outcome == 'failed') {
          expect(find.textContaining('dialog failed'), findsOneWidget);
        }
        if (outcome == 'selected') {
          await tester.tap(find.text('Save and inspect'));
          await tester.pumpAndSettle();
          expect(controller.state.path, r'C:\도구 폴더');
          expect(inspector.requests.length, before + 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
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

class _Picker implements EudToolDirectoryPicker {
  final result = Completer<String?>();
  @override
  Future<String?> pickEudToolDirectory() => result.future;
}
