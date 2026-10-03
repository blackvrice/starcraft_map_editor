import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/autosave_controller.dart';
import 'package:starcraft_map_editor/application/documents/recovery_snapshot.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_controller.dart';
import 'package:starcraft_map_editor/application/eud/eud_source_document.dart';
import 'package:starcraft_map_editor/application/ports/recovery_store.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/presentation/documents/recovery_dialog.dart';

import '../fixtures/eud_project_workspace_fixture.dart';

class _Store implements RecoveryStore {
  final values = <String, String>{};
  @override
  Future<List<RecoveryEntry>> list() async => [
    for (final entry in values.entries)
      RecoveryEntry(id: entry.key, content: entry.value),
  ];
  @override
  Future<void> write(String id, String content) async {
    values[id] = content;
  }

  @override
  Future<void> remove(String id) async {
    values.remove(id);
  }
}

void main() {
  testWidgets(
    'Korean recovery restores source, confirms deletion, and fits a narrow dialog',
    (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = EudWorkspaceFixture(),
          sources = EudSourceController(),
          store = _Store();
      final controller = AutosaveController(
        maps: fixture.maps,
        projects: fixture.projects,
        sources: sources,
        store: store,
        settings: InMemorySettingsStore(),
      );
      addTearDown(fixture.dispose);
      addTearDown(sources.dispose);
      addTearDown(controller.dispose);
      store.values['checkpoint-valid'] = RecoverySnapshot(
        savedAt: DateTime.utc(2026),
        source: EudSourceDocument.untitled(
          documentId: 'test',
          initialText: 'recovered',
        ),
      ).encode();
      store.values['checkpoint-bad'] = '{';
      await tester.runAsync(controller.refresh);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RecoveryDialog(controller: controller),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('미저장 작업 복구'), findsOneWidget);
      expect(find.text('읽을 수 없거나 손상된 복구본'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('복구본 삭제').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(store.values.containsKey('checkpoint-bad'), isTrue);
      await tester.runAsync(() async {
        await tester.tap(find.text('복구본 열기').first);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(sources.state.document!.text, 'recovered');
      expect(find.text('미저장 작업 복구'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('autosave interval, retention and enabled preference persist', (
    tester,
  ) async {
    final fixture = EudWorkspaceFixture(),
        sources = EudSourceController(),
        settings = InMemorySettingsStore();
    final controller = AutosaveController(
      maps: fixture.maps,
      projects: fixture.projects,
      sources: sources,
      store: _Store(),
      settings: settings,
    );
    addTearDown(fixture.dispose);
    addTearDown(sources.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AutosaveSettingsDialog(controller: controller)),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(await settings.readString('autosaveEnabled'), 'false');
    expect(await settings.readString('autosaveIntervalSeconds'), '30');
    expect(await settings.readString('autosaveRetention'), '5');
  });
}
