import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_colors.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_player_settings_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_resource_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_search.dart';
import 'package:starcraft_map_editor/presentation/triggers/trigger_pane.dart';
import 'package:starcraft_map_editor/presentation/triggers/trigger_replace_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/player_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/settings_defaults_panel.dart';
import 'package:starcraft_map_editor/presentation/settings/unit_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/upgrade_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/settings/tech_settings_dialog.dart';
import 'package:starcraft_map_editor/presentation/resources/resources_pane.dart';
import '../fixtures/eud_dat_fixture.dart';
import '../fixtures/localization_fixture.dart';
import '../fixtures/settings_trigger_editing_fixture.dart';

Future<void> viewport(
  WidgetTester tester, [
  Size size = const Size(1100, 1000),
]) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets(
    'malformed string mutation is blocked and resources remain usable',
    (tester) async {
      await viewport(tester);
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      final doc = f.workspace.maps.state.session!.rawDocument;
      final index = doc.sections.indexWhere((s) => s.name == 'STR ');
      final malformed = doc.replaceSection(
        index,
        doc.sections[index].withPayload([1, 0, 4, 0, 65]),
      );
      expect(
        () => f.editing.applyTriggerResources(
          expectedDocument: doc,
          updatedDocument: malformed,
        ),
        throwsStateError,
      );
      expect(f.workspace.maps.state.session!.rawDocument, same(doc));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourcesPane(controller: f.editing, active: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(('resource-string', 1))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-string-text')), findsOneWidget);
      expect(f.workspace.maps.state.session!.rawDocument, same(doc));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('trigger search controls fit a narrow viewport without editing', (
    tester,
  ) async {
    await viewport(tester, const Size(600, 900));
    final f = LocalizationFixture();
    addTearDown(f.dispose);
    final before = f.workspace.maps.state.session!.rawDocument;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TriggerPane(controller: f.editing)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('trigger-reference-id')),
      'bad',
    );
    await tester.pump();
    expect(f.workspace.maps.state.session!.rawDocument, same(before));
    expect(tester.takeException(), isNull);
  });
  test(
    'colors owner atomic Undo Redo stale guard and scene invalidation',
    () async {
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      final before = f.workspace.maps.state.session!.rawDocument;
      final originalScene = f.layers.sceneFor(f.workspace.maps.state.session!);
      f.editing.applyPlayerSettings(
        expectedDocument: before,
        changes: [const ChkPlayerChange(0, ChkPlayerField.owner, 5)],
        colorChanges: {0: const ChkPlayerColor(2, 12, 34, 56)},
      );
      final updated = f.workspace.maps.state.session!.rawDocument;
      expect(ChkPlayerColors.preview(updated, 0), 0xff0c2238);
      final updatedScene = f.layers.sceneFor(f.workspace.maps.state.session!);
      expect(updatedScene, isNot(same(originalScene)));
      expect(updatedScene.points.single.ownerArgb, 0xff0c2238);
      expect(f.editing.playerSettings.first.values![0], 5);
      expect(
        () => f.editing.applyPlayerSettings(
          expectedDocument: before,
          changes: [],
          colorChanges: {0: const ChkPlayerColor(2, 1, 2, 3)},
        ),
        throwsStateError,
      );
      expect(f.editing.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          f.workspace.maps.state.session!.rawDocument,
        ),
        const RawChkEncoder().encode(before),
      );
      expect(f.editing.redo(), isTrue);
      expect(
        ChkPlayerColors.preview(f.workspace.maps.state.session!.rawDocument, 0),
        0xff0c2238,
      );
    },
  );
  testWidgets(
    'filtered trigger selection changes source index not display position',
    (tester) async {
      await viewport(tester);
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      final doc = f.workspace.maps.state.session!.rawDocument;
      f.editing.applyTriggers(
        expectedDocument: doc,
        records: [triggerAction(doc, 9), triggerAction(doc, 10)],
      );
      final before = f.workspace.maps.state.session!.rawDocument;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TriggerPane(controller: f.editing)),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('trigger-search')),
        'center view',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(('trigger', 0))), findsNothing);
      expect(find.byKey(const ValueKey(('trigger', 1))), findsOneWidget);
      expect(
        identical(f.workspace.maps.state.session!.rawDocument, before),
        isTrue,
      );
      await tester.tap(find.text('Select visible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable selected'));
      await tester.pumpAndSettle();
      expect(f.editing.triggers.records.map((r) => r.enabled), [true, false]);
      f.editing.undo();
      await tester.pumpAndSettle();
      expect(f.editing.triggers.records.every((r) => r.enabled), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  for (final stale in [false, true]) {
    testWidgets('reference replace preview Apply Undo stale=$stale', (
      tester,
    ) async {
      await viewport(tester);
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      var doc = f.workspace.maps.state.session!.rawDocument;
      final record = triggerAction(doc, 10);
      f.editing.applyTriggers(expectedDocument: doc, records: [record]);
      doc = f.workspace.maps.state.session!.rawDocument;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TriggerPane(controller: f.editing)),
        ),
      );
      await tester.tap(find.text('Select all / none'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trigger-replace')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('trigger-replace-from')),
        '64',
      );
      await tester.enterText(find.byKey(const Key('trigger-replace-to')), '2');
      await tester.tap(find.byKey(const Key('trigger-replace-preview')));
      await tester.pumpAndSettle();
      expect(f.workspace.maps.state.session!.rawDocument, same(doc));
      expect(find.text('1 / 1 / 0'), findsOneWidget);
      if (stale) {
        f.editing.applyTriggers(
          expectedDocument: doc,
          records: [record, record],
        );
      }
      await tester.tap(find.byKey(const Key('trigger-replace-apply')));
      await tester.pumpAndSettle();
      if (stale) {
        expect(f.editing.triggers.records, hasLength(2));
        expect(find.textContaining('Map changed.'), findsOneWidget);
      } else {
        expect(f.editing.triggers.records.single.slot(true, 0)[0], 2);
        f.editing.undo();
        await tester.pumpAndSettle();
        expect(f.editing.triggers.records.single.bytes, record.bytes);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('changing replacement after preview disables Apply', (
    tester,
  ) async {
    final doc = editingDocument();
    final search = ChkTriggerSearch(withRecords(doc, [triggerAction(doc, 10)]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TriggerReplaceDialog(search: search, selected: {0}),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('trigger-replace-from')), '64');
    await tester.enterText(find.byKey(const Key('trigger-replace-to')), '2');
    await tester.tap(find.byKey(const Key('trigger-replace-preview')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('trigger-replace-apply')))
          .onPressed,
      isNotNull,
    );
    await tester.enterText(find.byKey(const Key('trigger-replace-to')), '3');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('trigger-replace-apply')))
          .onPressed,
      isNull,
    );
  });
  testWidgets('CRGB preview cancel is read only and explicit Apply has Undo', (
    tester,
  ) async {
    await viewport(tester);
    final f = LocalizationFixture();
    addTearDown(f.dispose);
    final before = f.workspace.maps.state.session!.rawDocument;
    Future<void> open() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlayerSettingsDialog(controller: f.editing)),
      ),
    );
    await open();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('player-advanced-color')));
    await tester.tap(find.byKey(const Key('player-advanced-color')));
    await tester.pumpAndSettle();
    expect(f.workspace.maps.state.session!.rawDocument, same(before));
    expect(
      find.text(
        'Applying Remastered colors changes VER to 206 and preserves legacy COLR.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('player-settings-apply')));
    await tester.tap(find.byKey(const Key('player-settings-apply')));
    await tester.pumpAndSettle();
    expect(
      f.workspace.maps.state.session!.rawDocument.sections.any(
        (s) => s.name == 'CRGB',
      ),
      isTrue,
    );
    f.editing.undo();
    expect(
      const RawChkEncoder().encode(f.workspace.maps.state.session!.rawDocument),
      const RawChkEncoder().encode(before),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid raw string opens reversible tokens, cancel preserves and Apply Undo works',
    (tester) async {
      await viewport(tester);
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      var doc = f.workspace.maps.state.session!.rawDocument;
      f.editing.applyTriggerResources(
        expectedDocument: doc,
        updatedDocument: ChkResourceEditor.editRaw(doc, 1, [6, 65, 255]),
      );
      doc = f.workspace.maps.state.session!.rawDocument;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourcesPane(controller: f.editing, active: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey(('resource-string', 1))));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('resource-string-text')))
            .controller!
            .text,
        '<06>A<FF>',
      );
      await tester.tap(find.byKey(const Key('settings-cancel')));
      await tester.pumpAndSettle();
      expect(f.workspace.maps.state.session!.rawDocument, same(doc));
      await tester.tap(find.byKey(const ValueKey(('resource-string', 1))));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resource-string-text')),
        '<07>B<FE>',
      );
      await tester.tap(find.byKey(const Key('resource-string-apply')));
      await tester.pumpAndSettle();
      expect(
        ChkResourceEditor.table(
          f.workspace.maps.state.session!.rawDocument,
        ).entryForId(1)!.rawBytes,
        [7, 66, 254],
      );
      f.editing.undo();
      expect(
        ChkResourceEditor.table(
          f.workspace.maps.state.session!.rawDocument,
        ).entryForId(1)!.rawBytes,
        [6, 65, 255],
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final screen in ['unit', 'upgrade', 'tech']) {
    testWidgets('$screen defaults load is read only and shows source', (
      tester,
    ) async {
      await viewport(tester);
      final f = LocalizationFixture();
      addTearDown(f.dispose);
      final terrain = TerrainEditingController(
        openMapController: f.workspace.maps,
      );
      addTearDown(terrain.dispose);
      final catalog = PlacementCatalogController(
        openMapController: f.workspace.maps,
        objectEditingController: f.editing,
        terrainEditingController: terrain,
        eudDatGateway: _Dat(),
      );
      addTearDown(catalog.dispose);
      catalog.setInstallationPath('C:\\synthetic');
      catalog.synchronizeSession(f.workspace.maps.state.session);
      final before = f.workspace.maps.state.session!.rawDocument;
      final child = switch (screen) {
        'unit' => UnitSettingsDialog(
          controller: f.editing,
          catalogController: catalog,
        ),
        'upgrade' => UpgradeSettingsDialog(
          controller: f.editing,
          catalogController: catalog,
        ),
        _ => TechSettingsDialog(
          controller: f.editing,
          catalogController: catalog,
        ),
      };
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();
      final load = find.byKey(const Key('settings-load-defaults')).first;
      await tester.ensureVisible(load);
      await tester.tap(load);
      await tester.pumpAndSettle();
      expect(catalog.eudData, isNotNull);
      expect(find.textContaining('synthetic build 1'), findsWidgets);
      if (screen == 'unit') {
        expect(find.textContaining('synthetic build 1'), findsNWidgets(2));
      }
      expect(find.byType(SettingsDefaultsPanel), findsWidgets);
      expect(f.workspace.maps.state.session!.rawDocument, same(before));
      expect(f.editing.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Dat implements EudDatGateway {
  @override
  Future<void> cancel(String operationId) async {}
  @override
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  }) async => EudDatReadResult(source: syntheticDatSource());
}
