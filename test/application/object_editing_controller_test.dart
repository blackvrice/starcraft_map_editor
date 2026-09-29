import 'dart:convert';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'dart:typed_data';
import 'package:starcraft_map_editor/application/ports/map_resource_gateway.dart';
import 'package:starcraft_map_editor/presentation/resources/resources_pane.dart';
import '../fixtures/pcm_sound_fixture.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_resources.dart';
import 'package:starcraft_map_editor/presentation/triggers/trigger_pane.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_palette_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_properties.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test(
    'map history undoes terrain, objects, briefing and sounds chronologically',
    () async {
      final fixture = await _openFixture(resourceGateway: _SoundGateway());
      final open = fixture.openMapController;
      final objects = fixture.objectEditingController;
      final terrain = TerrainEditingController(openMapController: open)
        ..synchronizeSession(open.state.session);
      addTearDown(() async {
        await terrain.dispose();
        await fixture.dispose();
      });
      final original = open.state.session!;
      terrain.selectCatalogTile(7);
      terrain.beginBrushStroke();
      terrain.paintTiles(const [TerrainTileCoordinate(x: 0, y: 0)]);
      terrain.paintTiles(const [TerrainTileCoordinate(x: 1, y: 0)]);
      terrain.commitBrushStroke();
      final painted = open.state.session!;
      fixture.selectAllObjects();
      objects.moveSelection(dx: 10, dy: 20);
      final moved = open.state.session!;
      objects.applyTriggers(
        expectedDocument: moved.rawDocument,
        records: [ChkTrigger.create(briefing: true)],
        briefing: true,
      );
      final briefing = open.state.session!;
      await objects.importSound();
      final sound = open.state.session!;
      expect(objects.state.undoDepth, 4);
      expect(terrain.state.undoDepth, 4);
      void sameDocument(OpenedMapSession expected) {
        expect(
          open.state.session!.rawDocument.sections,
          orderedEquals(expected.rawDocument.sections),
        );
        expect(open.state.session!.resourceEdits, same(expected.resourceEdits));
      }

      // Both entry points always traverse the same document timeline.
      for (final expected in [briefing, moved, painted, original]) {
        expect(terrain.undo(), isTrue);
        sameDocument(expected);
      }
      expect(open.state.session!.isDirty, isFalse);
      for (final expected in [painted, moved, briefing, sound]) {
        expect(objects.redo(), isTrue);
        sameDocument(expected);
      }
      expect(objects.undo(), isTrue);
      terrain.selectCatalogTile(9);
      terrain.paintTiles(const [TerrainTileCoordinate(x: 2, y: 0)]);
      expect(objects.canRedo, isFalse);
      expect(terrain.canRedo, isFalse);
    },
  );

  test(
    'active brush blocks object edits and shared undo; cancel preserves redo',
    () async {
      final fixture = await _openFixture();
      final open = fixture.openMapController;
      final objects = fixture.objectEditingController;
      final terrain = TerrainEditingController(openMapController: open)
        ..synchronizeSession(open.state.session);
      addTearDown(() async {
        await terrain.dispose();
        await fixture.dispose();
      });
      fixture.selectAllObjects();
      objects.moveSelection(dx: 10, dy: 0);
      objects.undo();
      final before = open.state.session!;
      terrain.selectCatalogTile(7);
      terrain.beginBrushStroke();
      terrain.paintTiles(const [TerrainTileCoordinate(x: 0, y: 0)]);
      fixture.selectAllObjects();
      final preview = open.state.session!;
      expect(() => objects.moveSelection(dx: 1, dy: 0), throwsStateError);
      expect(open.state.session, same(preview));
      expect(objects.undo(), isFalse);
      expect(objects.redo(), isFalse);
      expect(objects.state.canRedo, isFalse);
      terrain.cancelBrushStroke();
      expect(
        open.state.session!.rawDocument.sections,
        orderedEquals(before.rawDocument.sections),
      );
      expect(objects.redo(), isTrue);
    },
  );

  test(
    'stale whole-document history rejection preserves the command and document',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final open = fixture.openMapController;
      final objects = fixture.objectEditingController;
      fixture.selectAllObjects();
      objects.moveSelection(dx: 10, dy: 0);
      final expected = open.state.session!;
      // An unrecorded resource mutation must reject even a UNIT-only undo.
      final foreign = OpenedMapSession(
        extractedMap: expected.extractedMap,
        rawDocument: expected.rawDocument,
        metadataViews: expected.metadataViews,
        stringViews: expected.stringViews,
        terrainViews: expected.terrainViews,
        objectViews: expected.objectViews,
        sourceFingerprint: expected.sourceFingerprint,
        diagnostics: expected.diagnostics,
        resourceEdits: {
          'staredit\\wav\\foreign.wav': [1, 2],
        },
      );
      open.adoptEditedSession(foreign);
      expect(objects.undo, throwsStateError);
      expect(open.state.session, same(foreign));
      expect(objects.state.undoDepth, 1);
      expect(objects.state.redoDepth, 0);
      open.adoptEditedSession(expected);
      expect(objects.undo(), isTrue);
      open.adoptEditedSession(foreign);
      expect(objects.redo, throwsStateError);
      expect(objects.state.redoDepth, 1);
      // A new document clears shared history without presentation listeners.
      final terrain = TerrainEditingController(openMapController: open);
      addTearDown(terrain.dispose);
      terrain.selectCatalogTile(7);
      terrain.beginBrushStroke();
      terrain.paintTiles(const [TerrainTileCoordinate(x: 0, y: 0)]);
      final second = await _openFixture();
      addTearDown(second.dispose);
      await open.adoptSavedSession(second.openMapController.state.session!);
      expect(terrain.state.isBrushStrokeActive, isFalse);
      expect(terrain.commitBrushStroke(), isFalse);
      expect(terrain.state.selectedRawTileValue, isNull);
      expect(objects.canUndo, isFalse);
      expect(objects.canRedo, isFalse);
    },
  );

  testWidgets(
    'briefing draft edits action duration and owners, cancel, duplicate and undo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final controller = fixture.objectEditingController;
      final original = fixture.openMapController.state.session!.rawDocument;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TriggerPane(controller: controller, briefing: true),
          ),
        ),
      );
      await tester.tap(find.text('Add briefing'));
      await tester.pumpAndSettle();
      expect(controller.triggers.records, isEmpty);
      expect(
        controller.readTriggers(briefing: true).records.single.bytes[15],
        13,
      );
      await tester.tap(find.byKey(const ValueKey(('trigger', 0))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trigger-add-condition')), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Player 2'));
      await tester.tap(find.byKey(const Key('trigger-add-action')));
      await tester.pumpAndSettle();
      final chooser = tester.widget<DropdownButton<TriggerOpcode>>(
        find.byKey(const Key('trigger-opcode')),
      );
      expect(
        chooser.items!.map((e) => e.value!.id),
        List.generate(9, (i) => i + 1),
      );
      await tester.enterText(find.byType(TextFormField), '1500');
      await tester.tap(find.byKey(const Key('trigger-slot-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trigger-apply')));
      await tester.pumpAndSettle();
      final record = controller.readTriggers(briefing: true).records.single;
      expect(record.bytes[2373], 1);
      expect(
        ChkTrigger.argument(
          record.slot(true, 0),
          TriggerOpcodes.briefingDuration,
        ),
        1500,
      );
      await tester.tap(find.byKey(const ValueKey(('trigger', 0))));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Player 2'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        controller.readTriggers(briefing: true).records.single.bytes,
        record.bytes,
      );
      await tester.tap(find.byTooltip('Duplicate briefing'));
      await tester.pumpAndSettle();
      expect(controller.readTriggers(briefing: true).records, hasLength(2));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(controller.readTriggers(briefing: true).records, hasLength(1));
      expect(
        () => controller.applyTriggers(
          expectedDocument: original,
          records: [],
          briefing: true,
        ),
        throwsStateError,
      );
      controller.undo();
      controller.undo();
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        const RawChkEncoder().encode(original),
      );
      controller.redo();
      expect(controller.readTriggers(briefing: true).records, hasLength(1));
      final current = fixture.openMapController.state.session!.rawDocument;
      expect(
        () => controller.applyTriggers(
          expectedDocument: current,
          records: [ChkTrigger.create()],
          briefing: true,
        ),
        throwsStateError,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'resource tab edits strings and imports, previews, exports and undoes sounds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final resources = _SoundGateway();
      final fixture = await _openFixture(resourceGateway: resources);
      addTearDown(fixture.dispose);
      final controller = fixture.objectEditingController;
      final original = fixture.openMapController.state.session!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourcesPane(controller: controller, active: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey(('resource-string', 2))));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('resource-string-text')),
        'Edited text',
      );
      await tester.tap(find.byKey(const Key('resource-string-apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Edited text'), findsOneWidget);
      controller.undo();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import PCM WAV'));
      await tester.pumpAndSettle();
      final imported = fixture.openMapController.state.session!;
      expect(
        imported.resourceEdits[r'staredit\wav\own.wav'],
        pcmSoundFixture(),
      );
      expect(() => imported.resourceEdits.clear(), throwsUnsupportedError);
      expect(
        () => imported.resourceEdits.values.single![0] = 0,
        throwsUnsupportedError,
      );
      await tester.tap(find.text('Sounds'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview sound'));
      await tester.pumpAndSettle();
      expect(resources.previewed, pcmSoundFixture());
      await tester.tap(find.byTooltip('Export sound'));
      await tester.pumpAndSettle();
      expect(resources.exported, pcmSoundFixture());
      await expectLater(controller.importSound(), throwsStateError);
      controller.deleteSound(r'STAREDIT\WAV\OWN.WAV');
      expect(fixture.openMapController.state.session!.resourceEdits, isEmpty);
      controller.undo();
      expect(
        fixture
            .openMapController
            .state
            .session!
            .resourceEdits[r'staredit\wav\own.wav'],
        pcmSoundFixture(),
      );
      controller.undo();
      expect(fixture.openMapController.state.session!.resourceEdits, isEmpty);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        const RawChkEncoder().encode(original.rawDocument),
      );
      controller.redo();
      expect(
        await controller.soundBytes(r'STAREDIT\WAV\OWN.WAV'),
        pcmSoundFixture(),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'cancelled or invalid sound import leaves document and history unchanged',
    () async {
      final resources = _SoundGateway()..cancel = true;
      final fixture = await _openFixture(resourceGateway: resources);
      addTearDown(fixture.dispose);
      final original = fixture.openMapController.state.session;
      await fixture.objectEditingController.importSound();
      expect(fixture.openMapController.state.session, same(original));
      resources.cancel = false;
      resources.invalid = true;
      await expectLater(
        fixture.objectEditingController.importSound(),
        throwsFormatException,
      );
      expect(fixture.openMapController.state.session, same(original));
      expect(fixture.objectEditingController.canUndo, isFalse);
    },
  );
  test(
    'trigger resources append atomically and undo with stale draft protection',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final before = fixture.openMapController.state.session!.rawDocument;
      final updated = ChkTriggerResources.renameSwitch(
        ChkTriggerResources.editProperty(before, 1, {
          'Hitpoints %': 25,
        }, List.filled(5, null)),
        3,
        'Spawn enabled',
      );
      fixture.objectEditingController.applyTriggerResources(
        expectedDocument: before,
        updatedDocument: updated,
      );
      expect(
        ChkTriggerResources.switchName(
          fixture.openMapController.state.session!.rawDocument,
          3,
        ),
        'Spawn enabled',
      );
      expect(
        () => fixture.objectEditingController.applyTriggerResources(
          expectedDocument: before,
          updatedDocument: updated,
        ),
        throwsStateError,
      );
      fixture.objectEditingController.undo();
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        const RawChkEncoder().encode(before),
      );
      fixture.objectEditingController.redo();
      expect(
        ChkTriggerResources.propertyValues(
          fixture.openMapController.state.session!.rawDocument,
          1,
        )['Hitpoints %'],
        25,
      );
    },
  );
  testWidgets('switch names prepare apply and undo plus bulk disable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TriggerPane(controller: fixture.objectEditingController),
        ),
      ),
    );
    await tester.tap(find.text('Switch names…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Start');
    await tester.tap(find.byKey(const Key('trigger-resource-prepare')));
    await tester.pumpAndSettle();
    expect(fixture.openMapController.state.session!.isDirty, isFalse);
    await tester.tap(find.byKey(const Key('trigger-resource-apply')));
    await tester.pumpAndSettle();
    expect(
      ChkTriggerResources.switchName(
        fixture.openMapController.state.session!.rawDocument,
        0,
      ),
      'Start',
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      fixture.openMapController.state.session!.rawDocument.sections.any(
        (s) => s.name == 'SWNM',
      ),
      isFalse,
    );
    await tester.tap(find.byKey(const Key('trigger-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all / none'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable selected'));
    await tester.pumpAndSettle();
    expect(
      fixture.objectEditingController.triggers.records.single.enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'trigger changes preserve sections and reject stale drafts with undo redo',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final controller = fixture.objectEditingController;
      final before = fixture.openMapController.state.session!.rawDocument;
      final encoded = const RawChkEncoder().encode(before);
      controller.applyTriggers(
        expectedDocument: before,
        records: [ChkTrigger.create()],
      );
      expect(controller.triggers.records.single.bytes[15], 23);
      expect(fixture.openMapController.state.session!.isDirty, isTrue);
      expect(
        () => controller.applyTriggers(expectedDocument: before, records: []),
        throwsStateError,
      );
      expect(controller.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        encoded,
      );
      expect(controller.redo(), isTrue);
      expect(controller.triggers.records, hasLength(1));
      final after = fixture.openMapController.state.session!.rawDocument;
      for (var i = 0; i < before.sections.length - 1; i++) {
        expect(after.sections[i].payload, before.sections[i].payload);
      }
    },
  );

  testWidgets('trigger draft cancel, apply, duplicate and undo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    final controller = fixture.objectEditingController;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TriggerPane(controller: controller)),
      ),
    );
    await tester.tap(find.byKey(const Key('trigger-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(('trigger', 0))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Player 2'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.triggers.records.single.bytes[2373], 0);
    await tester.tap(find.byKey(const ValueKey(('trigger', 0))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Player 2'));
    await tester.tap(find.byKey(const Key('trigger-add-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trigger-slot-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trigger-apply')));
    await tester.pumpAndSettle();
    expect(controller.triggers.records.single.bytes[2373], 1);
    expect(controller.triggers.records.single.slot(true, 0)[26], 3);
    await tester.tap(find.byTooltip('Duplicate trigger'));
    await tester.pumpAndSettle();
    expect(controller.triggers.records, hasLength(2));
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(controller.triggers.records, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('moves a multi-layer selection and supports undo and redo', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.selectAllObjects();
    final original = fixture.openMapController.state.session!;
    final originalUnitPayload =
        original.objectViews.unitSections.single.rawSection.payload;

    expect(
      fixture.objectEditingController.moveSelection(dx: 10, dy: 20),
      isTrue,
    );

    var session = fixture.openMapController.state.session!;
    expect(session.isDirty, isTrue);
    expect(
      session.objectViews.unitSections.single.units.map(
        (unit) => (unit.x, unit.y),
      ),
      [(74, 84), (106, 116)],
    );
    expect(session.objectViews.spriteSections.single.sprites.single.x, 74);
    expect(session.objectViews.doodadSections.single.doodads.single.y, 84);
    final location =
        session.objectViews.locationSections.single.locations.first;
    expect(
      [location.left, location.top, location.right, location.bottom],
      [42, 52, 138, 148],
    );
    final movedUnitPayload =
        session.objectViews.unitSections.single.rawSection.payload;
    for (var index = 0; index < movedUnitPayload.length; index++) {
      if ({4, 5, 6, 7, 40, 41, 42, 43}.contains(index)) {
        continue;
      }
      expect(movedUnitPayload[index], originalUnitPayload[index]);
    }
    expect(fixture.mapLayerController.state.selections, hasLength(5));
    expect(fixture.mapLayerController.state.selections.first.pixelX, 74);
    expect(fixture.objectEditingController.state.undoDepth, 1);

    expect(fixture.objectEditingController.undo(), isTrue);
    session = fixture.openMapController.state.session!;
    expect(session.objectViews.unitSections.single.units.first.x, 64);
    expect(fixture.mapLayerController.state.selections, isEmpty);
    expect(fixture.objectEditingController.state.redoDepth, 1);

    expect(fixture.objectEditingController.redo(), isTrue);
    session = fixture.openMapController.state.session!;
    expect(session.objectViews.unitSections.single.units.first.x, 74);
  });

  test(
    'deletes records, blanks locations, and restores them on undo',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.selectAllObjects();

      final original = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      expect(fixture.objectEditingController.deleteSelection(), isFalse);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        original,
      );
      fixture.mapLayerController.setVisible(MapLayerType.doodads, false);
      expect(fixture.objectEditingController.deleteSelection(), isTrue);

      var objects = fixture.openMapController.state.session!.objectViews;
      expect(objects.unitSections.single.units, isEmpty);
      expect(objects.spriteSections.single.sprites, isEmpty);
      expect(objects.doodadSections.single.doodads, hasLength(1));
      expect(objects.locationSections.single.locations.first.isBlank, isTrue);
      expect(objects.locationSections.single.locations, hasLength(64));
      expect(fixture.mapLayerController.state.selections, isEmpty);

      expect(fixture.objectEditingController.undo(), isTrue);
      objects = fixture.openMapController.state.session!.objectViews;
      expect(objects.unitSections.single.units, hasLength(2));
      expect(objects.spriteSections.single.sprites, hasLength(1));
      expect(objects.doodadSections.single.doodads, hasLength(1));
      expect(objects.locationSections.single.locations.first.isBlank, isFalse);
    },
  );

  test('rejects locked selections and moves outside the map', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    final session = fixture.openMapController.state.session!;
    fixture.mapLayerController.setActiveLayer(MapLayerType.units);
    fixture.mapLayerController.selectAt(
      session: session,
      pixelX: 64,
      pixelY: 64,
    );

    fixture.mapLayerController.setLocked(MapLayerType.units, true);
    expect(fixture.objectEditingController.deleteSelection(), isFalse);
    fixture.mapLayerController.setLocked(MapLayerType.units, false);
    fixture.mapLayerController.selectAt(
      session: session,
      pixelX: 64,
      pixelY: 64,
    );
    expect(
      fixture.objectEditingController.moveSelection(dx: -100, dy: 0),
      isFalse,
    );
    expect(fixture.openMapController.state.session!.isDirty, isFalse);
  });

  test('places a copied template, selects it, and records undo', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    final original = fixture.openMapController.state.session!;
    final template = MapLayerObjectRef(
      layer: MapLayerType.units,
      sectionIndex: original.objectViews.unitSections.single.sectionIndex,
      recordIndex: 0,
    );
    final templatePayload =
        original.objectViews.unitSections.single.rawSection.payload;

    expect(
      fixture.objectEditingController.duplicateTemplate(
        template: template,
        pixelX: 64,
        pixelY: 64,
      ),
      isTrue,
    );

    var units = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units;
    expect(units, hasLength(3));
    expect((units.last.x, units.last.y), (64, 64));
    expect(fixture.mapLayerController.state.selection?.object.recordIndex, 2);
    expect(fixture.objectEditingController.undoLabel, 'Place Unit');
    final placedPayload = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .rawSection
        .payload;
    for (var index = 0; index < ChkUnitPlacement.recordLength; index++) {
      if ({4, 5, 6, 7}.contains(index)) {
        continue;
      }
      expect(
        placedPayload[ChkUnitPlacement.recordLength * 2 + index],
        templatePayload[index],
      );
    }

    expect(fixture.objectEditingController.undo(), isTrue);
    units = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units;
    expect(units, hasLength(2));
    expect(fixture.objectEditingController.redo(), isTrue);
    expect(
      fixture
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units,
      hasLength(3),
    );
  });

  test('validates and applies selected unit properties as one edit', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    final original = fixture.openMapController.state.session!;
    final object = MapLayerObjectRef(
      layer: MapLayerType.units,
      sectionIndex: original.objectViews.unitSections.single.sectionIndex,
      recordIndex: 0,
    );
    fixture.mapLayerController
      ..setActiveLayer(MapLayerType.units)
      ..selectObject(session: original, object: object);
    final properties = fixture.objectEditingController.selectedProperties;
    expect(properties, isA<UnitObjectProperties>());
    expect(
      original.diagnostics
          .where(
            (diagnostic) =>
                diagnostic.code ==
                ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
          )
          .length,
      2,
    );

    final invalid = fixture.objectEditingController.updateProperties(
      UnitObjectPropertyUpdate(
        object: object,
        typeId: 42,
        x: 999,
        y: 80,
        owner: 6,
        hitpointPercent: 101,
        shieldPercent: 75,
        energyPercent: 50,
        resourceAmount: 1000,
        hangarAmount: 4,
      ),
    );
    expect(invalid.status, ObjectPropertyEditStatus.invalid);
    expect(invalid.errors, contains(ObjectPropertyFields.x));
    expect(invalid.errors, contains(ObjectPropertyFields.hitpointPercent));
    expect(fixture.openMapController.state.session, same(original));

    final result = fixture.objectEditingController.updateProperties(
      UnitObjectPropertyUpdate(
        object: object,
        typeId: 42,
        x: 72,
        y: 80,
        owner: 6,
        hitpointPercent: 100,
        shieldPercent: 75,
        energyPercent: 50,
        resourceAmount: 1000,
        hangarAmount: 4,
      ),
    );
    expect(result.didApply, isTrue);
    expect(
      fixture.openMapController.state.session!.diagnostics
          .where(
            (diagnostic) =>
                diagnostic.code ==
                ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
          )
          .length,
      1,
    );
    final edited = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units
        .first;
    expect(
      (
        edited.unitType,
        edited.x,
        edited.y,
        edited.owner,
        edited.hitpointPercent,
        edited.shieldPercent,
        edited.energyPercent,
        edited.resourceAmount,
        edited.hangarAmount,
      ),
      (42, 72, 80, 6, 100, 75, 50, 1000, 4),
    );
    expect(fixture.mapLayerController.state.selection?.object, object);
    expect(fixture.objectEditingController.undoLabel, 'Edit Unit properties');
    expect(fixture.objectEditingController.undo(), isTrue);
    expect(
      fixture.openMapController.state.session!.diagnostics
          .where(
            (diagnostic) =>
                diagnostic.code ==
                ChkObjectReferenceDiagnosticCodes.playerOutOfRange,
          )
          .length,
      2,
    );
    expect(
      fixture
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units
          .first
          .unitType,
      (properties as UnitObjectProperties).typeId,
    );
  });

  test(
    'applies doodad and sprite properties through their typed paths',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      var session = fixture.openMapController.state.session!;
      final doodadObject = MapLayerObjectRef(
        layer: MapLayerType.doodads,
        sectionIndex: session.objectViews.doodadSections.single.sectionIndex,
        recordIndex: 0,
      );
      fixture.mapLayerController
        ..setActiveLayer(MapLayerType.doodads)
        ..selectObject(session: session, object: doodadObject);
      expect(
        fixture.objectEditingController
            .updateProperties(
              DoodadObjectPropertyUpdate(
                object: doodadObject,
                typeId: 20,
                x: 70,
                y: 80,
                owner: 5,
                enabledValue: 0,
              ),
            )
            .didApply,
        isTrue,
      );
      var doodad = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .doodadSections
          .single
          .doodads
          .single;
      expect(
        (
          doodad.doodadType,
          doodad.x,
          doodad.y,
          doodad.owner,
          doodad.enabledValue,
        ),
        (20, 70, 80, 5, 0),
      );

      session = fixture.openMapController.state.session!;
      final spriteObject = MapLayerObjectRef(
        layer: MapLayerType.sprites,
        sectionIndex: session.objectViews.spriteSections.single.sectionIndex,
        recordIndex: 0,
      );
      final originalFlags =
          session.objectViews.spriteSections.single.sprites.single.flags;
      fixture.mapLayerController
        ..setActiveLayer(MapLayerType.sprites)
        ..selectObject(session: session, object: spriteObject);
      expect(
        fixture.objectEditingController
            .updateProperties(
              SpriteObjectPropertyUpdate(
                object: spriteObject,
                typeId: 30,
                x: 90,
                y: 100,
                owner: 6,
              ),
            )
            .didApply,
        isTrue,
      );
      final sprite = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .spriteSections
          .single
          .sprites
          .single;
      expect(
        (sprite.spriteType, sprite.x, sprite.y, sprite.owner, sprite.flags),
        (30, 90, 100, 6, originalFlags),
      );
    },
  );

  test('creates a location in the first blank stable slot', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);

    expect(fixture.objectEditingController.canCreateLocation, isTrue);
    expect(fixture.objectEditingController.startLocationCreation(), isTrue);
    expect(fixture.objectEditingController.state.isCreatingLocation, isTrue);
    expect(
      fixture.objectEditingController.createLocation(
        MapLayerPixelRegion.fromCorners(
          firstX: 32,
          firstY: 64,
          secondX: 96,
          secondY: 128,
        ),
      ),
      isTrue,
    );

    var locations = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .locationSections
        .single
        .locations;
    expect(
      (
        locations[1].locationId,
        locations[1].left,
        locations[1].top,
        locations[1].right,
        locations[1].bottom,
        locations[1].stringId,
        locations[1].elevationFlags,
      ),
      (2, 32, 64, 96, 128, 0, ChkLocation.allElevations),
    );
    expect(fixture.objectEditingController.state.isCreatingLocation, isFalse);
    expect(fixture.mapLayerController.state.selection?.object.recordIndex, 1);
    expect(fixture.objectEditingController.undoLabel, 'Create Location 2');

    expect(fixture.objectEditingController.undo(), isTrue);
    locations = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .locationSections
        .single
        .locations;
    expect(locations[1].isBlank, isTrue);
  });

  test('resizes and copy-on-write renames a location in one edit', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    final original = fixture.openMapController.state.session!;
    final object = MapLayerObjectRef(
      layer: MapLayerType.locations,
      sectionIndex: original.objectViews.locationSections.single.sectionIndex,
      recordIndex: 0,
    );
    fixture.mapLayerController
      ..setActiveLayer(MapLayerType.locations)
      ..selectObject(session: original, object: object);
    final properties = fixture.objectEditingController.selectedProperties;
    expect(properties, isA<LocationObjectProperties>());
    expect((properties as LocationObjectProperties).name, 'Existing');
    expect(properties.canRename, isTrue);

    final result = fixture.objectEditingController.updateProperties(
      LocationObjectPropertyUpdate(
        object: object,
        left: 40,
        top: 48,
        right: 144,
        bottom: 152,
        name: '새 위치',
      ),
    );
    expect(result.didApply, isTrue);
    final editedSession = fixture.openMapController.state.session!;
    final location =
        editedSession.objectViews.locationSections.single.locations.first;
    expect(
      (location.left, location.top, location.right, location.bottom),
      (40, 48, 144, 152),
    );
    expect(location.stringId, 3);
    final strings = const ChkStringViewDecoder()
        .decode(editedSession.rawDocument)
        .legacyTables
        .single;
    expect(strings.entries[0].rawBytes, utf8.encode('Existing'));
    expect(strings.entries[1].rawBytes, utf8.encode('Other'));
    expect(strings.entries[2].rawBytes, utf8.encode('새 위치'));
    expect(
      fixture.objectEditingController.undoLabel,
      'Edit Location properties',
    );

    expect(fixture.objectEditingController.undo(), isTrue);
    final restored = fixture.openMapController.state.session!;
    expect(
      restored.objectViews.locationSections.single.locations.first.stringId,
      1,
    );
    expect(
      const ChkStringViewDecoder()
          .decode(restored.rawDocument)
          .legacyTables
          .single
          .declaredStringCount,
      2,
    );
  });

  test(
    'builds, searches, and repeatedly places map-local palette entries',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final palette = ObjectPaletteController(
        objectEditingController: fixture.objectEditingController,
        mapLayerController: fixture.mapLayerController,
      )..synchronizeSession(fixture.openMapController.state.session);
      addTearDown(palette.dispose);

      expect(palette.state.entries, hasLength(4));
      expect(palette.state.entries.map((entry) => entry.label), [
        'Unit type 2569',
        'Unit type 25442',
        'Doodad type 1',
        'Sprite type 1',
      ]);
      palette.setQuery('unit #2569');
      expect(palette.state.visibleEntries.single.label, 'Unit type 2569');

      final entry = palette.state.visibleEntries.single;
      expect(palette.selectEntry(entry), isTrue);
      expect(palette.state.isPlacementActive, isTrue);
      expect(fixture.mapLayerController.state.activeLayer, MapLayerType.units);
      expect(palette.placeSelected(pixelX: 144, pixelY: 176), isTrue);
      expect(palette.state.selectedEntry?.count, 2);
      expect(
        fixture
            .openMapController
            .state
            .session!
            .objectViews
            .unitSections
            .single
            .units
            .last
            .x,
        144,
      );

      palette.cancelPlacement();
      expect(palette.state.isPlacementActive, isFalse);
      fixture.mapLayerController.setLocked(MapLayerType.units, true);
      expect(palette.selectEntry(palette.state.visibleEntries.single), isFalse);
    },
  );
}

final class _Fixture {
  const _Fixture({
    required this.openMapController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.progressController,
  });

  final OpenMapController openMapController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final OperationProgressController progressController;

  void selectAllObjects() {
    final session = openMapController.state.session!;
    mapLayerController.selectRegion(
      session: session,
      region: MapLayerPixelRegion.fromCorners(
        firstX: 0,
        firstY: 0,
        secondX: 200,
        secondY: 200,
      ),
    );
    expect(mapLayerController.state.selections, hasLength(5));
  }

  Future<void> dispose() async {
    await objectEditingController.dispose();
    await mapLayerController.dispose();
    await openMapController.dispose();
    await progressController.dispose();
  }
}

Future<_Fixture> _openFixture({MapResourceGateway? resourceGateway}) async {
  final chkBytes = _chkBytes();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Objects.scx',
    scenarioChkBytes: chkBytes,
    metadata: MapArchiveMetadata(
      archiveSizeBytes: chkBytes.length,
      formatVersion: 1,
      totalEntryCount: 1,
      listingComplete: true,
      entries: [
        MapArchiveEntryMetadata(
          path: MapArchiveEntryPaths.scenarioChk,
          uncompressedSizeBytes: chkBytes.length,
          compressedSizeBytes: chkBytes.length,
          flags: 0,
          locale: 0,
          nameIsSynthetic: false,
        ),
      ],
    ),
  );
  final progressController = OperationProgressController();
  final openMapController = OpenMapController(
    archiveGateway: _FixtureArchiveGateway(map),
    filePicker: const _NoMapFilePicker(),
    fingerprintGateway: const _FixtureFingerprintGateway(),
    recentProjectsService: RecentProjectsService(InMemorySettingsStore()),
    operationProgressController: progressController,
  );
  final state = await openMapController.open(sourcePath: map.sourcePath);
  expect(state.status, OpenMapStatus.opened);
  final mapLayerController = MapLayerController()
    ..synchronizeSession(state.session);
  final objectEditingController = ObjectEditingController(
    resourceGateway: resourceGateway,
    openMapController: openMapController,
    mapLayerController: mapLayerController,
  )..synchronizeSession(state.session);
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    objectEditingController: objectEditingController,
    progressController: progressController,
  );
}

class _SoundGateway implements MapResourceGateway {
  bool cancel = false, invalid = false;
  List<int>? previewed, exported;
  @override
  Future<({String name, List<int> bytes})?> importSound() async => cancel
      ? null
      : (name: 'own.wav', bytes: invalid ? [0] : pcmSoundFixture());
  @override
  Future<void> exportSound(String name, List<int> bytes) async {
    exported = bytes;
  }

  @override
  Future<void> preview(List<int> bytes) async {
    previewed = bytes;
  }

  @override
  Future<void> stopPreview() async {}
  @override
  Future<List<int>?> readSound(String archive, String path) async => null;
}

Uint8List _chkBytes() {
  final locations = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  ByteData.sublistView(locations)
    ..setUint32(0, 32, Endian.little)
    ..setUint32(4, 32, Endian.little)
    ..setUint32(8, 128, Endian.little)
    ..setUint32(12, 128, Endian.little)
    ..setUint16(16, 1, Endian.little)
    ..setUint16(18, 0x3f, Endian.little);
  final builder = BytesBuilder(copy: false);
  for (final section in [
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [8, 0, 8, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', Uint8List(8 * 8 * 2)),
    _section('UNIT', [..._unit(64, 64, 1), ..._unit(96, 96, 90)]),
    _section('DD2 ', _doodad(64, 64)),
    _section('THG2', _sprite(64, 64)),
    _section('MRGN', locations),
    _section('STR ', _legacyStringTable(['Existing', 'Other'])),
    _section('TRIG', []),
  ]) {
    builder.add(section);
  }
  return builder.takeBytes();
}

Uint8List _legacyStringTable(List<String> strings) {
  final encoded = strings.map(utf8.encode).toList(growable: false);
  final headerLength = 2 + strings.length * 2;
  final payloadLength =
      headerLength +
      encoded.fold<int>(0, (sum, bytes) => sum + bytes.length + 1);
  final payload = Uint8List(payloadLength);
  final data = ByteData.sublistView(payload)
    ..setUint16(0, strings.length, Endian.little);
  var offset = headerLength;
  for (var index = 0; index < encoded.length; index++) {
    data.setUint16(2 + index * 2, offset, Endian.little);
    payload.setAll(offset, encoded[index]);
    offset += encoded[index].length + 1;
  }
  return payload;
}

Uint8List _unit(int x, int y, int seed) {
  final bytes = Uint8List.fromList(
    List<int>.generate(ChkUnitPlacement.recordLength, (index) => seed + index),
  );
  ByteData.sublistView(bytes)
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little);
  return bytes;
}

Uint8List _doodad(int x, int y) {
  final bytes = Uint8List(ChkDoodadPlacement.recordLength);
  ByteData.sublistView(bytes)
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
}

Uint8List _sprite(int x, int y) {
  final bytes = Uint8List(ChkSpritePlacement.recordLength);
  ByteData.sublistView(bytes)
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
}

Uint8List _section(String name, List<int> payload) {
  final bytes = Uint8List(RawChkParser.headerLength + payload.length);
  bytes.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.little);
  bytes.setRange(RawChkParser.headerLength, bytes.length, payload);
  return bytes;
}

final class _FixtureArchiveGateway implements MapArchiveGateway {
  const _FixtureArchiveGateway(this.map);
  final ExtractedMap map;

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async =>
      MapArchiveOpenResult.success(map: map);

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) => throw StateError('Writing is not used by this test.');

  @override
  Future<bool> cancel(String operationId) async => false;
}

final class _NoMapFilePicker implements MapFilePicker {
  const _NoMapFilePicker();
  @override
  Future<String?> pickMapPath() async => null;
  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      null;
}

final class _FixtureFingerprintGateway implements MapFileFingerprintGateway {
  const _FixtureFingerprintGateway();
  @override
  Future<MapFileFingerprint> fingerprint(String path) async =>
      MapFileFingerprint(
        sizeBytes: 4096,
        modifiedAt: DateTime.utc(2026, 8, 6),
        sha256Digest: 'a' * 64,
      );
}
