import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/presentation/placement/doodad_delete_dialog.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_placement.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_trigger_editor.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import '../fixtures/doodad_deletion_fixture.dart';
import '../fixtures/basic_editing_fixture.dart';

void main() {
  _retainedDoodadNeighborTests();
  _locationMixedDoodadDeletionTests();
  _unitMixedDoodadDeletionTests();
  _mixedDoodadSpriteDeletionTests();
  for (final available in [true, false]) {
    testWidgets(
      'batch review resolves distinct types once, available=$available',
      (tester) async {
        var document = batchDeletionDocument();
        final at = document.sections.indexWhere((s) => s.name == 'DD2 ');
        final bytes = document.sections[at].payload;
        ByteData.sublistView(bytes).setUint16(16, 9, Endian.little);
        document = document.replaceSection(
          at,
          document.sections[at].withPayload(bytes),
        );
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(document),
        );
        addTearDown(f.dispose);
        final session = f.openMapController.state.session!;
        f.mapLayerController.selectObjects(
          session: session,
          objects: [
            for (final index in [0, 2])
              MapLayerObjectRef(
                layer: MapLayerType.doodads,
                sectionIndex:
                    session.objectViews.doodadSections.single.sectionIndex,
                recordIndex: index,
              ),
          ],
        );
        final recipe = deletionRecipe();
        final other = DoodadPlacementRecipe(
          tileset: recipe.tileset,
          startTileGroup: recipe.startTileGroup,
          doodadType: 9,
          width: recipe.width,
          height: recipe.height,
          centerOffsetX: recipe.centerOffsetX,
          centerOffsetY: recipe.centerOffsetY,
          footprint: recipe.footprint,
        );
        final catalog = _DeletionCatalog(recipe)
          ..byType = {
            7: [recipe],
            if (available) 9: [other],
          };
        final before = const RawChkEncoder().encode(session.rawDocument);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => deleteObjectsWithDoodadReview(
                    context,
                    f.controller,
                    catalog,
                  ),
                  child: const Text('Delete selection'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        expect(catalog.calls, 1);
        expect(catalog.requestedTypes, [7, 9]);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.openMapController.editHistory.undoDepth, 0);
        if (available) {
          expect(find.byType(AlertDialog), findsOneWidget);
          await tester.tap(find.byKey(const Key('doodad-delete-apply')));
          await tester.pumpAndSettle();
          expect(
            f
                .openMapController
                .state
                .session!
                .objectViews
                .doodadSections
                .single
                .doodads
                .length,
            1,
          );
          expect(f.openMapController.editHistory.undoDepth, 1);
          expect(f.controller.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
        } else {
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(SnackBar), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final kind in ['mixed', 'oversized', 'stale']) {
    testWidgets('batch review rejects $kind selection/context before editing', (
      tester,
    ) async {
      final count = kind == 'oversized' ? 33 : 2;
      final doc = batchDeletionDocument(
        count: count,
        overlay: DoodadOverlaySemantic.spriteUnit,
      );
      final f = await _openFixture(mapBytes: const RawChkEncoder().encode(doc));
      addTearDown(f.dispose);
      final session = f.openMapController.state.session!,
          section = session.objectViews.doodadSections.single;
      f.mapLayerController.selectObjects(
        session: session,
        objects: [
          for (var i = 0; i < (kind == 'mixed' ? 1 : count); i++)
            MapLayerObjectRef(
              layer: MapLayerType.doodads,
              sectionIndex: section.sectionIndex,
              recordIndex: i == 0 ? 0 : i + 1,
            ),
          if (kind == 'mixed')
            MapLayerObjectRef(
              layer: MapLayerType.locations,
              sectionIndex:
                  session.objectViews.locationSections.single.sectionIndex,
              recordIndex: 63,
            ),
        ],
      );
      final before = const RawChkEncoder().encode(session.rawDocument),
          catalog = _DeletionCatalog(
            deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit),
          );
      if (kind == 'stale') {
        catalog.beforeList = () async {
          await f.openMapController.open(sourcePath: r'C:\Maps\Placement.scx');
        };
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => deleteObjectsWithDoodadReview(
                  context,
                  f.controller,
                  catalog,
                ),
                child: const Text('Delete selection'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete selection'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(catalog.calls, kind == 'stale' ? 1 : 0);
      expect(f.openMapController.editHistory.undoDepth, 0);
      expect(
        const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'batch Doodad $overlay is one Undo and every failure preserves all records',
      () async {
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(
            batchDeletionDocument(overlay: overlay),
          ),
        );
        addTearDown(f.dispose);
        final before = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final requests = batchDeletionRequests(overlay: overlay),
            plan = f.controller.prepareDoodadDeletions(
              batchDeletionRequests(overlay: overlay),
            );
        for (final layer in [
          MapLayerType.doodads,
          MapLayerType.terrain,
          if (overlay != null) MapLayerType.sprites,
        ]) {
          f.mapLayerController.setLocked(layer, true);
          expect(() => f.controller.deleteDoodad(plan), throwsStateError);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(f.openMapController.editHistory.undoDepth, 0);
          f.mapLayerController.setLocked(layer, false);
        }
        expect(
          () => f.controller.prepareDoodadDeletions([
            requests.first,
            requests.first,
          ]),
          throwsStateError,
        );
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        f.controller.deleteDoodad(plan);
        expect(f.openMapController.editHistory.undoDepth, 1);
        final after = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.controller.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          after,
        );
        expect(() => f.controller.deleteDoodad(plan), throwsStateError);
      },
    );
  }
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets(
      'batch review requires every overlay and cancellation is read-only at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(
            batchDeletionDocument(overlay: DoodadOverlaySemantic.spriteUnit),
          ),
        );
        addTearDown(f.dispose);
        final session = f.openMapController.state.session!,
            section = session.objectViews.doodadSections.single;
        f.mapLayerController.selectObjects(
          session: session,
          objects: [
            for (final index in [0, 2])
              MapLayerObjectRef(
                layer: MapLayerType.doodads,
                sectionIndex: section.sectionIndex,
                recordIndex: index,
              ),
          ],
        );
        final before = const RawChkEncoder().encode(session.rawDocument),
            catalog = _DeletionCatalog(
              deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit),
            );
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => deleteObjectsWithDoodadReview(
                    context,
                    f.controller,
                    catalog,
                  ),
                  child: const Text('Delete selection'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'ko'
                ? '두다드 2개 삭제 및 지형 복원'
                : 'Delete 2 Doodads and restore terrain',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('doodad-delete-apply')),
              )
              .onPressed,
          isNull,
        );
        expect(catalog.calls, 1);
        await tester.tap(find.byKey(const Key('doodad-delete-overlay-0')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                locale.languageCode == 'ko'
                    ? 'THG2 레코드 #1 · 종류 100'
                    : 'THG2 record #1 · type 100',
              )
              .last,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('doodad-delete-apply')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
        await tester.pumpAndSettle();
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        for (final (record, overlay) in [(0, 1), (2, 3)]) {
          await tester.ensureVisible(
            find.byKey(Key('doodad-delete-overlay-$record')),
          );
          await tester.tap(find.byKey(Key('doodad-delete-overlay-$record')));
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text(
                  locale.languageCode == 'ko'
                      ? 'THG2 레코드 #$overlay · 종류 100'
                      : 'THG2 record #$overlay · type 100',
                )
                .last,
          );
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('doodad-delete-apply')));
        await tester.pumpAndSettle();
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .doodadSections
              .single
              .doodads,
          hasLength(1),
        );
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .spriteSections
              .single
              .sprites,
          hasLength(2),
        );
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'disabled Doodad $overlay deletes in one reversible command and respects every required layer',
      () async {
        final fixture = await _openFixture(
          mapBytes: const RawChkEncoder().encode(
            deletionDocument(overlay: overlay),
          ),
        );
        addTearDown(fixture.dispose);
        final c = fixture.controller, maps = fixture.openMapController;
        final before = const RawChkEncoder().encode(
          maps.state.session!.rawDocument,
        );
        final plan = c.prepareDoodadDeletion(
          recipe: deletionRecipe(overlay: overlay),
          recordIndex: 0,
          overlayRecordIndex: overlay == null ? null : 1,
        );
        for (final layer in [
          MapLayerType.terrain,
          MapLayerType.doodads,
          if (overlay != null) MapLayerType.sprites,
        ]) {
          fixture.mapLayerController.setLocked(layer, true);
          expect(() => c.deleteDoodad(plan), throwsStateError);
          expect(
            const RawChkEncoder().encode(maps.state.session!.rawDocument),
            before,
          );
          expect(maps.editHistory.undoDepth, 0);
          fixture.mapLayerController.setLocked(layer, false);
        }
        c.deleteDoodad(plan);
        expect(maps.editHistory.undoDepth, 1);
        final after = const RawChkEncoder().encode(
          maps.state.session!.rawDocument,
        );
        expect(c.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(maps.state.session!.rawDocument),
          before,
        );
        expect(c.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(maps.state.session!.rawDocument),
          after,
        );
        expect(() => c.deleteDoodad(plan), throwsStateError);
      },
    );
  }
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    testWidgets(
      'disabled sprite-unit delete review keeps explicit ownership at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await _openFixture(
          mapBytes: const RawChkEncoder().encode(
            deletionDocument(overlay: DoodadOverlaySemantic.spriteUnit),
          ),
        );
        addTearDown(fixture.dispose);
        final session = fixture.openMapController.state.session!;
        fixture.mapLayerController.selectObject(
          session: session,
          object: MapLayerObjectRef(
            layer: MapLayerType.doodads,
            sectionIndex:
                session.objectViews.doodadSections.single.sectionIndex,
            recordIndex: 0,
          ),
        );
        final before = const RawChkEncoder().encode(session.rawDocument);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => deleteObjectsWithDoodadReview(
                    context,
                    fixture.controller,
                    _DeletionCatalog(
                      deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit),
                    ),
                  ),
                  child: const Text('Delete selection'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('doodad-delete-apply')),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.text(
            locale.languageCode == 'ko'
                ? '두다드 삭제 및 지형 복원'
                : 'Delete Doodad and restore terrain',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
        await tester.pumpAndSettle();
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('doodad-delete-overlay')));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .text(
                locale.languageCode == 'ko'
                    ? 'THG2 레코드 #1 · 종류 100'
                    : 'THG2 record #1 · type 100',
              )
              .last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('doodad-delete-apply')));
        await tester.pumpAndSettle();
        expect(
          fixture
              .openMapController
              .state
              .session!
              .objectViews
              .doodadSections
              .single
              .doodads,
          hasLength(1),
        );
        expect(
          fixture
              .openMapController
              .state
              .session!
              .objectViews
              .spriteSections
              .single
              .sprites,
          hasLength(2),
        );
        expect(tester.takeException(), isNull);
        fixture.controller.undo();
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          before,
        );
      },
    );
  }
  for (final kind in [
    'clear',
    'walk',
    'build',
    'ground-unbuildable',
    'missing',
    'profile',
    'tileset',
    'reference',
    'edge',
    'air',
    'air-building',
    'aligned',
    'duplicate-terrain',
    'missing-terrain',
  ]) {
    test('UNIT terrain shared preview/Apply $kind is atomic', () async {
      var bytes = _chkBytes(
        includeUnits: false,
        includeSprites: true,
        includeDoodads: true,
        duplicateUnits: false,
      );
      if (kind == 'missing-terrain') {
        bytes = Uint8List.fromList(
          const RawChkParser()
              .parse(bytes)
              .document!
              .sections
              .where((s) => s.name != 'MTXM')
              .expand((s) => _section(s.name, s.payload))
              .toList(),
        );
      }
      if (kind == 'duplicate-terrain') {
        bytes = Uint8List.fromList([
          ...bytes,
          ..._section('MTXM', List.filled(128, 0)),
        ]);
      }
      final f = await _openFixture(mapBytes: bytes);
      addTearDown(f.dispose);
      final before = f.openMapController.state.session!;
      final building = ['build', 'air-building', 'aligned'].contains(kind);
      final cap = _capability(
        37,
        isBuilding: building,
        placementBox: building
            ? BuildingPlacementBox(width: 64, height: 32)
            : null,
        collisionProfile: kind == 'profile'
            ? null
            : UnitCollisionProfile(
                left: 1,
                up: 1,
                right: 1,
                down: 1,
                isFlyer: kind.startsWith('air'),
              ),
      );
      final snapshot = kind == 'missing'
          ? null
          : TerrainPlacementSnapshot(
              tileset: kind == 'tileset' ? 0 : 4,
              groupBuildable: [
                !['build', 'ground-unbuildable'].contains(kind),
              ],
              megaTileReferences: [
                List.filled(16, kind == 'reference' ? 9 : 0),
              ],
              walkableMasks: [
                kind == 'walk' || kind.startsWith('air') ? 0 : 65535,
              ],
            );
      final expected = switch (kind) {
        'missing' ||
        'profile' ||
        'tileset' ||
        'reference' ||
        'missing-terrain' ||
        'duplicate-terrain' =>
          ObjectPlacementDiagnosticCodes.unitTerrainUnavailable,
        'walk' ||
        'air-building' => ObjectPlacementDiagnosticCodes.unitTerrainUnwalkable,
        'build' => ObjectPlacementDiagnosticCodes.unitTerrainUnbuildable,
        'edge' => ObjectPlacementDiagnosticCodes.outOfBounds,
        _ => null,
      };
      final x = kind == 'edge' ? 0 : 63;
      expect(
        f.controller.previewCatalogUnit(
          capability: cap,
          unitId: 37,
          owner: 0,
          pixelX: x,
          pixelY: 47,
          checkTerrain: true,
          terrainSnapshot: snapshot,
          alignBuildingToTiles: kind == 'aligned',
        ),
        expected,
      );
      expect(identical(f.openMapController.state.session, before), isTrue);
      expect(f.controller.state.undoDepth, 0);
      final result = f.controller.placeCatalogUnit(
        capability: cap,
        unitId: 37,
        owner: 0,
        pixelX: x,
        pixelY: 47,
        checkTerrain: true,
        terrainSnapshot: snapshot,
        alignBuildingToTiles: kind == 'aligned',
      );
      expect(result.issueCode, expected);
      if (expected == null) {
        expect(result.isPlaced, isTrue);
        expect(f.controller.state.undoDepth, 1);
        if (kind == 'aligned') {
          final unit = f
              .openMapController
              .state
              .session!
              .objectViews
              .unitSections
              .single
              .units
              .single;
          expect((unit.x, unit.y), (64, 48));
        }
        expect(f.controller.undo(), isTrue);
        expect(
          f.openMapController.state.session!.objectViews.unitSections,
          isEmpty,
        );
        expect(f.controller.redo(), isTrue);
      } else {
        expect(identical(f.openMapController.state.session, before), isTrue);
        expect(f.controller.state.undoDepth, 0);
      }
    });
  }
  for (final kind in [
    'overlap',
    'clear',
    'missing',
    'unknown-unit',
    'flight-state',
    'hidden',
  ]) {
    test(
      'shared UNIT collision preview/Apply $kind preserves rejected documents',
      () async {
        final profile = UnitCollisionProfile(
          left: 3,
          up: 5,
          right: 8,
          down: 9,
          isFlyer: false,
        );
        final cap = _capability(37, collisionProfile: profile);
        final occupant = const UnitPlacementFactory()
            .create(
              capability: cap,
              unitId: 37,
              owner: 0,
              x: 64,
              y: 64,
              classId: 1,
            )
            .bytes;
        if (kind == 'unknown-unit') {
          ByteData.sublistView(occupant).setUint16(8, 300, Endian.little);
        }
        if (kind == 'flight-state') {
          ByteData.sublistView(occupant).setUint16(26, 4, Endian.little);
        }
        final f = await _openFixture(
          mapBytes: Uint8List.fromList([
            ..._chkBytes(
              includeUnits: false,
              includeSprites: true,
              includeDoodads: true,
              duplicateUnits: false,
            ),
            ..._section('UNIT', occupant),
            ..._section('XTRA', [1, 255, 0, 47]),
          ]),
        );
        addTearDown(f.dispose);
        if (kind == 'hidden') {
          f.mapLayerController.setVisible(MapLayerType.units, false);
        }
        final before = f.openMapController.state.session!;
        final catalog = kind == 'missing'
            ? null
            : UnitCollisionCatalog({37: cap});
        final expected = switch (kind) {
          'clear' => null,
          'missing' ||
          'unknown-unit' => ObjectPlacementDiagnosticCodes.collisionUnavailable,
          'flight-state' =>
            ObjectPlacementDiagnosticCodes.collisionStateUnsupported,
          'hidden' => ObjectPlacementDiagnosticCodes.layerLocked,
          _ => ObjectPlacementDiagnosticCodes.unitOverlap,
        };
        final x = kind == 'clear' ? 100 : 64;
        expect(
          f.controller.previewCatalogUnit(
            capability: cap,
            unitId: 37,
            owner: 0,
            pixelX: x,
            pixelY: 64,
            allowUnitOverlap: false,
            collisionCatalog: catalog,
          ),
          expected,
        );
        expect(f.openMapController.state.session, same(before));
        expect(
          f.controller
              .placeCatalogUnit(
                capability: cap,
                unitId: 37,
                owner: 0,
                pixelX: x,
                pixelY: 64,
                allowUnitOverlap: false,
                collisionCatalog: catalog,
              )
              .issueCode,
          expected,
        );
        if (expected != null) {
          expect(f.openMapController.state.session, same(before));
          expect(f.controller.state.undoDepth, 0);
        } else {
          expect(f.controller.state.undoDepth, 1);
          expect(f.controller.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            const RawChkEncoder().encode(before.rawDocument),
          );
          expect(f.controller.redo(), isTrue);
        }
      },
    );
  }

  for (final occupantX in [63, 64]) {
    test(
      'building collision uses aligned center rather than raw x=$occupantX',
      () async {
        final profile = UnitCollisionProfile(
          left: 0,
          up: 0,
          right: 0,
          down: 0,
          isFlyer: false,
        );
        final building = _capability(
          106,
          isBuilding: true,
          collisionProfile: profile,
          placementBox: BuildingPlacementBox(width: 128, height: 96),
        );
        final cap = _capability(37, collisionProfile: profile);
        final f = await _openFixture(
          mapBytes: Uint8List.fromList([
            ..._chkBytes(
              includeUnits: false,
              includeSprites: true,
              includeDoodads: true,
              duplicateUnits: false,
            ),
            ..._section(
              'UNIT',
              const UnitPlacementFactory()
                  .create(
                    capability: cap,
                    unitId: 37,
                    owner: 0,
                    x: occupantX,
                    y: 48,
                    classId: 1,
                  )
                  .bytes,
            ),
          ]),
        );
        addTearDown(f.dispose);
        final catalog = UnitCollisionCatalog({37: cap, 106: building});
        final expected = occupantX == 64
            ? ObjectPlacementDiagnosticCodes.unitOverlap
            : null;
        expect(
          f.controller.previewCatalogUnit(
            capability: building,
            unitId: 106,
            owner: 0,
            pixelX: 63,
            pixelY: 47,
            alignBuildingToTiles: true,
            allowUnitOverlap: false,
            collisionCatalog: catalog,
          ),
          expected,
        );
        expect(
          f.controller
              .placeCatalogUnit(
                capability: building,
                unitId: 106,
                owner: 0,
                pixelX: 63,
                pixelY: 47,
                alignBuildingToTiles: true,
                allowUnitOverlap: false,
                collisionCatalog: catalog,
              )
              .issueCode,
          expected,
        );
      },
    );
  }
  for (final vertical in [false, true]) {
    test(
      'building alignment refuses u16 output overflow vertical=$vertical',
      () async {
        final document = const RawChkParser()
            .parse(
              _chkBytes(
                includeUnits: true,
                includeSprites: true,
                includeDoodads: true,
                duplicateUnits: false,
              ),
            )
            .document!;
        final bytes = Uint8List.fromList([
          ...const RawChkEncoder().encode(
            RawChkDocument(
              sourceLength: document.sourceLength,
              sections: document.sections
                  .where((s) => s.name != 'DIM ' && s.name != 'MTXM')
                  .toList(),
            ),
          ),
          ..._section('DIM ', vertical ? [8, 0, 1, 8] : [1, 8, 8, 0]),
          ..._section('MTXM', List.filled(2049 * 8 * 2, 0)),
        ]);
        final f = await _openFixture(mapBytes: bytes);
        addTearDown(f.dispose);
        final before = f.openMapController.state.session!;
        final cap = _capability(
          106,
          isBuilding: true,
          placementBox: BuildingPlacementBox(width: 64, height: 64),
        );
        final x = vertical ? 64 : 65535;
        final y = vertical ? 65535 : 64;
        expect(
          f.controller.previewCatalogUnit(
            capability: cap,
            unitId: 106,
            owner: 0,
            pixelX: x,
            pixelY: y,
            alignBuildingToTiles: true,
          ),
          ObjectPlacementDiagnosticCodes.outOfBounds,
        );
        expect(
          f.controller
              .placeCatalogUnit(
                capability: cap,
                unitId: 106,
                owner: 0,
                pixelX: x,
                pixelY: y,
                alignBuildingToTiles: true,
              )
              .issueCode,
          ObjectPlacementDiagnosticCodes.outOfBounds,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.controller.state.undoDepth, 0);
      },
    );
  }
  for (final point in [
    (0, 96),
    (32, 96),
    (96, 0),
    (96, 15),
    (255, 96),
    (96, 255),
    (-1, 96),
    (256, 96),
  ]) {
    test('aligned building refuses entire box outside map at $point', () async {
      final f = await _openFixture();
      addTearDown(f.dispose);
      final cap = _capability(
        106,
        isBuilding: true,
        placementBox: BuildingPlacementBox(width: 128, height: 96),
      );
      final before = f.openMapController.state.session!;
      final issue = f.controller.previewCatalogUnit(
        capability: cap,
        unitId: 106,
        owner: 0,
        pixelX: point.$1,
        pixelY: point.$2,
        alignBuildingToTiles: true,
      );
      expect(issue, ObjectPlacementDiagnosticCodes.outOfBounds);
      expect(
        f.controller
            .placeCatalogUnit(
              capability: cap,
              unitId: 106,
              owner: 0,
              pixelX: point.$1,
              pixelY: point.$2,
              alignBuildingToTiles: true,
            )
            .issueCode,
        issue,
      );
      expect(f.openMapController.state.session, same(before));
      expect(f.controller.state.undoDepth, 0);
    });
  }
  for (final point in [(63, 47), (64, 48), (176, 192)]) {
    test(
      'building $point preview is read-only, align Apply Undo Redo is exact',
      () async {
        final f = await _openFixture();
        addTearDown(f.dispose);
        final box = BuildingPlacementBox(width: 128, height: 96);
        final cap = _capability(106, isBuilding: true, placementBox: box);
        final before = f.openMapController.state.session!;
        expect(
          f.controller.previewCatalogUnit(
            capability: cap,
            unitId: 106,
            owner: 1,
            pixelX: point.$1,
            pixelY: point.$2,
            alignBuildingToTiles: true,
          ),
          isNull,
        );
        expect(f.openMapController.state.session, same(before));
        expect(
          f.controller
              .placeCatalogUnit(
                capability: cap,
                unitId: 106,
                owner: 1,
                pixelX: point.$1,
                pixelY: point.$2,
                alignBuildingToTiles: true,
              )
              .isPlaced,
          isTrue,
        );
        final after = f.openMapController.state.session!;
        final actual = after.objectViews.unitSections.single.units.last;
        expect((x: actual.x, y: actual.y), box.align(point.$1, point.$2));
        expect(actual.unitType, 106);
        expect(actual.owner, 1);
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          const RawChkEncoder().encode(before.rawDocument),
        );
        expect(f.controller.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          const RawChkEncoder().encode(after.rawDocument),
        );
      },
    );
  }
  test(
    'missing building size refuses alignment, exact legacy placement remains available',
    () async {
      final f = await _openFixture();
      addTearDown(f.dispose);
      final cap = _capability(106, isBuilding: true);
      final before = f.openMapController.state.session!;
      expect(
        f.controller.previewCatalogUnit(
          capability: cap,
          unitId: 106,
          owner: 0,
          pixelX: 63,
          pixelY: 47,
          alignBuildingToTiles: true,
        ),
        ObjectPlacementDiagnosticCodes.buildingBoxUnavailable,
      );
      expect(
        f.controller
            .placeCatalogUnit(
              capability: cap,
              unitId: 106,
              owner: 0,
              pixelX: 63,
              pixelY: 47,
              alignBuildingToTiles: true,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.buildingBoxUnavailable,
      );
      expect(f.openMapController.state.session, same(before));
      expect(
        f.controller
            .placeCatalogUnit(
              capability: cap,
              unitId: 106,
              owner: 0,
              pixelX: 63,
              pixelY: 47,
            )
            .isPlaced,
        isTrue,
      );
      final placed = f
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units
          .last;
      expect((placed.x, placed.y), (63, 47));
    },
  );
  for (final scenario in [
    'lock',
    'history',
    'relation',
    'subunit',
    'mismatch',
  ]) {
    test('building alignment retains $scenario safety refusal', () async {
      final f = await _openFixture();
      addTearDown(f.dispose);
      if (scenario == 'lock') {
        f.mapLayerController.setLocked(MapLayerType.units, true);
      }
      if (scenario == 'history') {
        f.openMapController.editHistory.beginTransaction(Object());
      }
      final cap = _capability(
        scenario == 'mismatch' ? 107 : 106,
        isBuilding: true,
        placementBox: BuildingPlacementBox(width: 128, height: 96),
        requiresRelationLink: scenario == 'relation',
        isSubunit: scenario == 'subunit',
      );
      final expected = switch (scenario) {
        'lock' => ObjectPlacementDiagnosticCodes.layerLocked,
        'history' => ObjectPlacementDiagnosticCodes.historyBlocked,
        'relation' => ObjectPlacementFactoryCodes.unitRelationRequired,
        'subunit' => ObjectPlacementFactoryCodes.unitSubunit,
        _ => ObjectPlacementFactoryCodes.unitCapabilityMismatch,
      };
      final before = f.openMapController.state.session!;
      expect(
        f.controller.previewCatalogUnit(
          capability: cap,
          unitId: 106,
          owner: 0,
          pixelX: 80,
          pixelY: 80,
          alignBuildingToTiles: true,
        ),
        expected,
      );
      expect(
        f.controller
            .placeCatalogUnit(
              capability: cap,
              unitId: 106,
              owner: 0,
              pixelX: 80,
              pixelY: 80,
              alignBuildingToTiles: true,
            )
            .issueCode,
        expected,
      );
      expect(f.openMapController.state.session, same(before));
    });
  }
  for (final kind in ['unit', 'sprite', 'spriteUnit']) {
    for (final scenario in [
      'locked',
      'hidden',
      'negative',
      'right',
      'bottom',
      'duplicate',
      'malformed',
      'missingDim',
      'duplicateDim',
      'protected',
      'history',
      'id',
      'owner',
    ]) {
      test(
        '$kind hover and Apply agree on $scenario without changing data',
        () async {
          final name = kind == 'unit' ? 'UNIT' : 'THG2';
          final base = _chkBytes(
            includeUnits: kind != 'unit' || scenario != 'malformed',
            includeSprites: kind == 'unit' || scenario != 'malformed',
            includeDoodads: true,
            duplicateUnits: false,
          );
          final document = const RawChkParser().parse(base).document!;
          final bytes = Uint8List.fromList([
            ...const RawChkEncoder().encode(
              RawChkDocument(
                sourceLength: document.sourceLength,
                sections: document.sections
                    .where((s) => scenario != 'missingDim' || s.name != 'DIM ')
                    .toList(),
              ),
            ),
            if (scenario == 'duplicate') ..._section(name, []),
            if (scenario == 'malformed') ..._section(name, [0]),
            if (scenario == 'duplicateDim') ..._section('DIM ', [8, 0, 8, 0]),
            if (scenario == 'protected') ...[...'ISOM'.codeUnits, 0, 0, 0, 128],
          ]);
          final fixture = await _openFixture(mapBytes: bytes);
          addTearDown(fixture.dispose);
          final layer = kind == 'unit'
              ? MapLayerType.units
              : MapLayerType.sprites;
          if (scenario == 'locked') {
            fixture.mapLayerController.setLocked(layer, true);
          }
          if (scenario == 'hidden') {
            fixture.mapLayerController.setVisible(layer, false);
          }
          final owner = Object();
          if (scenario == 'history') {
            fixture.openMapController.editHistory.beginTransaction(owner);
          }
          final before = fixture.openMapController.state.session!;
          final oldSelection = fixture.mapLayerController.state.selection;
          final x = scenario == 'negative'
              ? -1
              : scenario == 'right'
              ? 256
              : 31;
          final y = scenario == 'bottom' ? 256 : 63;
          final id = scenario == 'id' ? 999 : 37;
          final player = scenario == 'owner' ? 256 : 0;
          final expected = switch (scenario) {
            'locked' || 'hidden' => ObjectPlacementDiagnosticCodes.layerLocked,
            'negative' ||
            'right' ||
            'bottom' => ObjectPlacementDiagnosticCodes.outOfBounds,
            'duplicate' => ObjectPlacementDiagnosticCodes.sectionAmbiguous,
            'missingDim' || 'duplicateDim' =>
              ObjectPlacementDiagnosticCodes.dimensionsUnavailable,
            'protected' ||
            'malformed' => ObjectPlacementDiagnosticCodes.sessionNotEditable,
            'history' => ObjectPlacementDiagnosticCodes.historyBlocked,
            'id' => ObjectPlacementDiagnosticCodes.invalidId,
            _ => ObjectPlacementDiagnosticCodes.invalidOwner,
          };
          expect(
            _pointPreview(
              fixture.controller,
              kind,
              x: x,
              y: y,
              id: id,
              owner: player,
            ),
            expected,
          );
          expect(
            _pointApply(
              fixture.controller,
              kind,
              x: x,
              y: y,
              id: id,
              owner: player,
            ).issueCode,
            expected,
          );
          expect(fixture.openMapController.state.session, same(before));
          expect(
            fixture.mapLayerController.state.selection,
            same(oldSelection),
          );
          expect(fixture.controller.state.undoDepth, 0);
          expect(fixture.controller.state.redoDepth, 0);
          if (scenario == 'history') {
            fixture.openMapController.editHistory.endTransaction(owner);
          }
        },
      );
    }
    test(
      '$kind allowed hover preserves Redo and missing sections until Apply',
      () async {
        final fixture = await _openFixture(
          includeUnits: false,
          includeSprites: false,
        );
        addTearDown(fixture.dispose);
        expect(
          _pointApply(fixture.controller, kind, x: 31, y: 63).isPlaced,
          isTrue,
        );
        expect(fixture.controller.undo(), isTrue);
        final before = fixture.openMapController.state.session!;
        final selection = fixture.mapLayerController.state.selection;
        for (final point in [(0, 0), (31, 63), (255, 255)]) {
          expect(
            _pointPreview(fixture.controller, kind, x: point.$1, y: point.$2),
            isNull,
          );
        }
        expect(fixture.openMapController.state.session, same(before));
        expect(fixture.mapLayerController.state.selection, same(selection));
        expect(fixture.controller.state.undoDepth, 0);
        expect(fixture.controller.state.redoDepth, 1);
        expect(fixture.controller.redo(), isTrue);
      },
    );
    test(
      '$kind Apply rechecks layers changed after an allowed hover',
      () async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        expect(_pointPreview(fixture.controller, kind, x: 31, y: 63), isNull);
        final before = fixture.openMapController.state.session!;
        final layer = kind == 'unit'
            ? MapLayerType.units
            : MapLayerType.sprites;
        fixture.mapLayerController.setLocked(layer, true);
        expect(
          _pointApply(fixture.controller, kind, x: 31, y: 63).issueCode,
          ObjectPlacementDiagnosticCodes.layerLocked,
        );
        expect(fixture.openMapController.state.session, same(before));
        fixture.mapLayerController.setLocked(layer, false);
        expect(_pointPreview(fixture.controller, kind, x: 31, y: 63), isNull);
        expect(
          _pointApply(fixture.controller, kind, x: 31, y: 63).isPlaced,
          isTrue,
        );
        final view = fixture.openMapController.state.session!.objectViews;
        if (kind == 'unit') {
          expect(
            (
              view.unitSections.single.units.last.x,
              view.unitSections.single.units.last.y,
            ),
            (31, 63),
          );
        } else {
          expect(
            (
              view.spriteSections.single.sprites.last.x,
              view.spriteSections.single.sprites.last.y,
            ),
            (31, 63),
          );
        }
      },
    );
  }
  for (final kind in ['unit', 'spriteUnit']) {
    for (final failure in ['mismatch', 'subunit', 'relation']) {
      test(
        '$kind capability $failure has identical preview/Apply refusal',
        () async {
          final fixture = await _openFixture();
          addTearDown(fixture.dispose);
          final capability = _capability(
            failure == 'mismatch' ? 36 : 37,
            isSubunit: failure == 'subunit',
            requiresRelationLink: failure == 'relation',
          );
          final before = fixture.openMapController.state.session!;
          final code = switch (failure) {
            'mismatch' => ObjectPlacementFactoryCodes.unitCapabilityMismatch,
            'subunit' => ObjectPlacementFactoryCodes.unitSubunit,
            _ => ObjectPlacementFactoryCodes.unitRelationRequired,
          };
          expect(
            _pointPreview(fixture.controller, kind, capability: capability),
            code,
          );
          expect(
            _pointApply(
              fixture.controller,
              kind,
              capability: capability,
            ).issueCode,
            code,
          );
          expect(fixture.openMapController.state.session, same(before));
        },
      );
    }
  }
  test(
    'Unit class allocation cache follows Apply Undo Redo and exhaustion',
    () async {
      final fixture = await _openFixture(includeUnits: false);
      addTearDown(fixture.dispose);
      for (var i = 0; i < 4; i++) {
        expect(_pointPreview(fixture.controller, 'unit'), isNull);
        expect(_pointApply(fixture.controller, 'unit').isPlaced, isTrue);
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
              .classId,
          i,
        );
      }
      expect(fixture.controller.undo(), isTrue);
      expect(_pointPreview(fixture.controller, 'unit'), isNull);
      expect(fixture.controller.redo(), isTrue);
      expect(_pointApply(fixture.controller, 'unit').isPlaced, isTrue);
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
            .classId,
        4,
      );
      final record = _unit(32, 32, 1);
      ByteData.sublistView(record).setUint32(0, 0xffffffff, Endian.little);
      final exhausted = await _openFixture(
        mapBytes: Uint8List.fromList([
          ..._chkBytes(
            includeUnits: false,
            includeSprites: true,
            includeDoodads: true,
            duplicateUnits: false,
          ),
          ..._section('UNIT', record),
        ]),
      );
      addTearDown(exhausted.dispose);
      final before = exhausted.openMapController.state.session!;
      for (var i = 0; i < 3; i++) {
        expect(
          _pointPreview(exhausted.controller, 'unit'),
          ObjectPlacementDiagnosticCodes.classIdExhausted,
        );
        expect(
          _pointApply(exhausted.controller, 'unit').issueCode,
          ObjectPlacementDiagnosticCodes.classIdExhausted,
        );
      }
      expect(_pointPreview(exhausted.controller, 'spriteUnit'), isNull);
      expect(exhausted.openMapController.state.session, same(before));
    },
  );
  test(
    'Doodad preview also refuses invalid owner and active transactions',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final owner = Object();
      for (final blocked in [false, true]) {
        if (blocked) {
          fixture.openMapController.editHistory.beginTransaction(owner);
        }
        final expected = blocked
            ? ObjectPlacementDiagnosticCodes.historyBlocked
            : ObjectPlacementDiagnosticCodes.invalidOwner;
        expect(
          fixture.controller.previewCatalogDoodad(
            recipe: _recipe(overlay: true),
            owner: 256,
            originTileX: 2,
            originTileY: 2,
          ),
          expected,
        );
        expect(
          fixture.controller
              .placeCatalogDoodad(
                recipe: _recipe(overlay: true),
                owner: 256,
                originTileX: 2,
                originTileY: 2,
              )
              .issueCode,
          expected,
        );
        if (blocked) {
          fixture.openMapController.editHistory.endTransaction(owner);
        }
      }
    },
  );
  testWidgets(
    'Doodad delete dialog requires overlay confirmation and cancellation preserves map',
    (tester) async {
      final fixture = await _openFixture(
        includeDoodads: false,
        includeUnderlying: true,
      );
      addTearDown(fixture.dispose);
      final recipe = _recipe(overlay: true);
      fixture.controller.placeCatalogDoodad(
        recipe: recipe,
        owner: 0,
        originTileX: 2,
        originTileY: 3,
      );
      final before = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => deleteObjectsWithDoodadReview(
                  context,
                  fixture.controller,
                  _DeletionCatalog(recipe),
                ),
                child: const Text('Delete selection'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete selection'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Delete together'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      await tester.tap(find.text('Delete selection'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('THG2 record #1 · type 42').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete together'));
      await tester.pumpAndSettle();
      expect(
        fixture
            .openMapController
            .state
            .session!
            .objectViews
            .doodadSections
            .single
            .doodads,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      fixture.controller.undo();
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
    },
  );
  test(
    'reopened Doodad deletion restores TILE and explicitly selected overlay atomically',
    () async {
      final initial = await _openFixture(
        includeDoodads: false,
        includeUnderlying: true,
      );
      addTearDown(initial.dispose);
      final recipe = _recipe(overlay: true);
      expect(
        initial.controller
            .placeCatalogDoodad(
              recipe: recipe,
              owner: 0,
              originTileX: 2,
              originTileY: 3,
            )
            .isPlaced,
        isTrue,
      );
      final before = const RawChkEncoder().encode(
        initial.openMapController.state.session!.rawDocument,
      );
      final fixture = await _openFixture(mapBytes: before);
      addTearDown(fixture.dispose);
      final controller = fixture.controller;
      expect(
        () => controller.prepareDoodadDeletion(recipe: recipe, recordIndex: 0),
        throwsStateError,
      );
      final plan = controller.prepareDoodadDeletion(
        recipe: recipe,
        recordIndex: 0,
        overlayRecordIndex: 1,
      );
      expect(
        () => controller.prepareDoodadDeletion(
          recipe: recipe,
          recordIndex: 0,
          overlayRecordIndex: 0,
        ),
        throwsStateError,
      );
      final document = plan.document;
      final tileIndex = document.sections.indexWhere(
        (s) => s.hasNameBytes('TILE'.codeUnits),
      );
      final terrainIndex = document.sections.indexWhere(
        (s) => s.hasNameBytes('MTXM'.codeUnits),
      );
      for (final invalid in [
        document.appendSection(document.sections[tileIndex]),
        document.replaceSection(
          tileIndex,
          document.sections[tileIndex].withPayload([0]),
        ),
        document.replaceSection(
          tileIndex,
          document.sections[tileIndex].withPayload(
            document.sections[terrainIndex].payload,
          ),
        ),
        document.replaceSection(
          terrainIndex,
          document.sections[terrainIndex].withPayload(Uint8List(128)),
        ),
      ]) {
        expect(
          () => DoodadDeletionPlan.create(
            document: invalid,
            recipe: recipe,
            recordIndex: 0,
            confirmedOverlayRecordIndex: 1,
          ),
          throwsStateError,
        );
      }
      fixture.mapLayerController.setLocked(MapLayerType.sprites, true);
      expect(() => controller.deleteDoodad(plan), throwsStateError);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      fixture.mapLayerController.setLocked(MapLayerType.sprites, false);
      controller.deleteDoodad(plan);
      final after = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      expect(
        fixture
            .openMapController
            .state
            .session!
            .objectViews
            .doodadSections
            .single
            .doodads,
        isEmpty,
      );
      expect(
        fixture
            .openMapController
            .state
            .session!
            .objectViews
            .spriteSections
            .single
            .sprites,
        hasLength(1),
      );
      expect(
        fixture
            .openMapController
            .state
            .session!
            .terrainViews
            .tileMaps
            .single
            .rawTileValues,
        everyElement(0),
      );
      expect(controller.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(controller.redo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        after,
      );
      expect(() => controller.deleteDoodad(plan), throwsStateError);
    },
  );

  test(
    'Doodad composite deletion refuses absent TILE without partial edits',
    () async {
      final fixture = await _openFixture(includeDoodads: false);
      addTearDown(fixture.dispose);
      final recipe = _recipe(overlay: true);
      fixture.controller.placeCatalogDoodad(
        recipe: recipe,
        owner: 0,
        originTileX: 2,
        originTileY: 3,
      );
      final before = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      expect(
        () => fixture.controller.prepareDoodadDeletion(
          recipe: recipe,
          recordIndex: 0,
          overlayRecordIndex: 1,
        ),
        throwsStateError,
      );
      expect(fixture.controller.deleteSelection(), isFalse);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
    },
  );

  group('catalog Unit placement', () {
    test(
      'appends into the single UNIT section and allocates a class id',
      () async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        final before = fixture
            .openMapController
            .state
            .session!
            .rawDocument
            .sections
            .length;

        final result = fixture.controller.placeCatalogUnit(
          capability: _capability(37),
          unitId: 37,
          owner: 2,
          pixelX: 128,
          pixelY: 96,
        );

        expect(result.isPlaced, isTrue);
        expect(result.issueCode, isNull);
        var session = fixture.openMapController.state.session!;
        expect(session.rawDocument.sections, hasLength(before));
        final units = session.objectViews.unitSections.single.units;
        expect(units, hasLength(3));
        final placed = units.last;
        expect(placed.unitType, 37);
        expect(placed.owner, 2);
        expect(placed.x, 128);
        expect(placed.y, 96);
        expect(placed.classId, _existingMaximumClassId + 1);
        expect(placed.hitpointPercent, 100);
        expect(session.isDirty, isTrue);
        expect(
          fixture.mapLayerController.state.selection?.object.recordIndex,
          2,
        );

        expect(fixture.controller.undo(), isTrue);
        session = fixture.openMapController.state.session!;
        expect(session.objectViews.unitSections.single.units, hasLength(2));

        expect(fixture.controller.redo(), isTrue);
        session = fixture.openMapController.state.session!;
        expect(session.objectViews.unitSections.single.units, hasLength(3));
        expect(session.objectViews.unitSections.single.units.last.unitType, 37);
      },
    );

    test('keeps every existing record byte unchanged', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final original = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .rawSection
          .payload;

      expect(
        fixture.controller
            .placeCatalogUnit(
              capability: _capability(1),
              unitId: 1,
              owner: 0,
              pixelX: 32,
              pixelY: 32,
            )
            .isPlaced,
        isTrue,
      );

      final updated = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .rawSection
          .payload;
      expect(updated.sublist(0, original.length), orderedEquals(original));
      expect(updated.length, original.length + ChkUnitPlacement.recordLength);
    });

    test('appends a new UNIT section when the map has none', () async {
      final fixture = await _openFixture(includeUnits: false);
      addTearDown(fixture.dispose);
      final before =
          fixture.openMapController.state.session!.rawDocument.sections.length;

      final result = fixture.controller.placeCatalogUnit(
        capability: _capability(7),
        unitId: 7,
        owner: 0,
        pixelX: 64,
        pixelY: 64,
      );

      expect(result.isPlaced, isTrue);
      var session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before + 1));
      expect(session.rawDocument.sections.last.name, 'UNIT');
      expect(session.rawDocument.sections.last.isDirty, isTrue);
      final section = session.objectViews.unitSections.single;
      expect(section.sectionIndex, before);
      expect(section.units.single.unitType, 7);
      expect(section.units.single.classId, 0);
      expect(result.placedObject?.sectionIndex, before);

      expect(fixture.controller.undo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before));
      expect(session.objectViews.unitSections, isEmpty);

      expect(fixture.controller.redo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before + 1));
      expect(session.objectViews.unitSections.single.units, hasLength(1));
    });

    test('refuses a duplicate UNIT section instead of guessing', () async {
      final fixture = await _openFixture(duplicateUnits: true);
      addTearDown(fixture.dispose);

      final result = fixture.controller.placeCatalogUnit(
        capability: _capability(7),
        unitId: 7,
        owner: 0,
        pixelX: 64,
        pixelY: 64,
      );

      expect(result.isPlaced, isFalse);
      expect(result.issueCode, ObjectPlacementDiagnosticCodes.sectionAmbiguous);
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
      expect(fixture.controller.state.undoDepth, 0);
    });

    test('refuses a locked layer and a point outside the map', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);

      fixture.mapLayerController.setLocked(MapLayerType.units, true);
      expect(
        fixture.controller
            .placeCatalogUnit(
              capability: _capability(7),
              unitId: 7,
              owner: 0,
              pixelX: 64,
              pixelY: 64,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.layerLocked,
      );

      fixture.mapLayerController.setLocked(MapLayerType.units, false);
      expect(
        fixture.controller
            .placeCatalogUnit(
              capability: _capability(7),
              unitId: 7,
              owner: 0,
              pixelX: 256,
              pixelY: 0,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.outOfBounds,
      );
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
    });

    test('passes a domain refusal through unchanged', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);

      final result = fixture.controller.placeCatalogUnit(
        capability: _capability(106, requiresRelationLink: true),
        unitId: 106,
        owner: 0,
        pixelX: 64,
        pixelY: 64,
      );

      expect(
        result.issueCode,
        ObjectPlacementFactoryCodes.unitRelationRequired,
      );
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
    });
  });

  group('catalog Sprite placement', () {
    for (final exists in [true, false]) {
      test(
        'unit-sprite appends THG2 (exists=$exists) and restores exact bytes',
        () async {
          final fixture = await _openFixture(includeSprites: exists);
          addTearDown(fixture.dispose);
          final before = const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          );
          final result = fixture.controller.placeCatalogSpriteUnit(
            capability: _capability(37),
            unitId: 37,
            owner: 3,
            pixelX: 80,
            pixelY: 48,
          );
          expect(result.isPlaced, isTrue);
          expect(result.placedObject!.layer, MapLayerType.sprites);
          final session = fixture.openMapController.state.session!;
          final sprite = session.objectViews.spriteSections.single.sprites.last;
          expect(
            (sprite.spriteType, sprite.owner, sprite.x, sprite.y),
            (37, 3, 80, 48),
          );
          expect(sprite.flags, ChkSpritePlacement.isUnitFlag);
          expect(sprite.isSpriteUnitDisabled, isFalse);
          expect(session.objectViews.unitSections.single.units, hasLength(2));
          expect(fixture.controller.state.undoDepth, 1);
          final after = const RawChkEncoder().encode(session.rawDocument);
          expect(fixture.controller.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              fixture.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(fixture.controller.redo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              fixture.openMapController.state.session!.rawDocument,
            ),
            after,
          );
        },
      );
    }
    for (final scenario in ['duplicate', 'locked', 'outside', 'relation']) {
      test('unit-sprite refuses $scenario without partial writes', () async {
        final fixture = await _openFixture(
          mapBytes: Uint8List.fromList([
            ..._chkBytes(
              includeUnits: true,
              includeSprites: true,
              includeDoodads: true,
              duplicateUnits: false,
            ),
            if (scenario == 'duplicate') ..._section('THG2', []),
          ]),
        );
        addTearDown(fixture.dispose);
        if (scenario == 'locked') {
          fixture.mapLayerController.setLocked(MapLayerType.sprites, true);
        }
        final before = fixture.openMapController.state.session!;
        final result = fixture.controller.placeCatalogSpriteUnit(
          capability: _capability(
            37,
            requiresRelationLink: scenario == 'relation',
          ),
          unitId: 37,
          owner: 0,
          pixelX: scenario == 'outside' ? 256 : 32,
          pixelY: 32,
        );
        expect(result.issueCode, switch (scenario) {
          'duplicate' => ObjectPlacementDiagnosticCodes.sectionAmbiguous,
          'locked' => ObjectPlacementDiagnosticCodes.layerLocked,
          'outside' => ObjectPlacementDiagnosticCodes.outOfBounds,
          _ => ObjectPlacementFactoryCodes.unitRelationRequired,
        });
        expect(fixture.openMapController.state.session, same(before));
        expect(fixture.controller.state.undoDepth, 0);
      });
    }
    test('appends a pure sprite and a new THG2 section when missing', () async {
      final fixture = await _openFixture(includeSprites: false);
      addTearDown(fixture.dispose);
      final before =
          fixture.openMapController.state.session!.rawDocument.sections.length;

      final result = fixture.controller.placeCatalogPureSprite(
        spriteId: 130,
        owner: 5,
        pixelX: 80,
        pixelY: 48,
      );

      expect(result.isPlaced, isTrue);
      var session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before + 1));
      final sprite = session.objectViews.spriteSections.single.sprites.single;
      expect(sprite.spriteType, 130);
      expect(sprite.owner, 5);
      expect(sprite.drawsAsSprite, isTrue);
      expect(sprite.hasUnitFlag, isFalse);

      expect(fixture.controller.undo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before));
      expect(session.objectViews.spriteSections, isEmpty);
    });
  });

  group('catalog Doodad placement', () {
    test(
      'Doodad preview preserves the session, selection and redo history',
      () async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        fixture.controller.placeCatalogPureSprite(
          spriteId: 1,
          owner: 0,
          pixelX: 32,
          pixelY: 32,
        );
        expect(fixture.controller.undo(), isTrue);
        final before = fixture.openMapController.state.session!;
        final bytes = const RawChkEncoder().encode(before.rawDocument);
        final selections = fixture.mapLayerController.state.selections;
        final history = fixture.controller.state;
        for (var x = 0; x < 7; x++) {
          expect(
            fixture.controller.previewCatalogDoodad(
              recipe: _recipe(overlay: true),
              owner: 3,
              originTileX: x,
              originTileY: 1,
            ),
            isNull,
          );
        }
        expect(fixture.openMapController.state.session, same(before));
        expect(const RawChkEncoder().encode(before.rawDocument), bytes);
        expect(fixture.mapLayerController.state.selections, same(selections));
        expect(fixture.controller.state, same(history));
        expect(history.undoDepth, 0);
        expect(history.redoDepth, 1);
        expect(fixture.controller.redo(), isTrue);
      },
    );

    for (final scenario in [
      (
        name: 'terrain mismatch',
        x: 1,
        y: 1,
        group: 5,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.doodadTerrainMismatch,
      ),
      (
        name: 'tileset mismatch',
        x: 1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.badlands,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.doodadTilesetMismatch,
      ),
      (
        name: 'negative x',
        x: -1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.outOfBounds,
      ),
      (
        name: 'negative y',
        x: 1,
        y: -1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.outOfBounds,
      ),
      (
        name: 'right boundary',
        x: 7,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.outOfBounds,
      ),
      (
        name: 'bottom boundary',
        x: 1,
        y: 8,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.outOfBounds,
      ),
      (
        name: 'duplicate DD2',
        x: 1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: 'DD2 ',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.sectionAmbiguous,
      ),
      (
        name: 'duplicate overlay THG2',
        x: 1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: 'THG2',
        locked: null,
        code: ObjectPlacementDiagnosticCodes.sectionAmbiguous,
      ),
      (
        name: 'locked doodads',
        x: 1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: MapLayerType.doodads,
        code: ObjectPlacementDiagnosticCodes.layerLocked,
      ),
      (
        name: 'locked terrain',
        x: 1,
        y: 1,
        group: 0,
        tileset: StarCraftTilesetAssetSet.jungle,
        extra: '',
        locked: MapLayerType.terrain,
        code: ObjectPlacementDiagnosticCodes.layerLocked,
      ),
    ]) {
      test('preview and Apply agree on ${scenario.name}', () async {
        final base = _chkBytes(
          includeUnits: true,
          includeSprites: true,
          includeDoodads: true,
          duplicateUnits: false,
        );
        final fixture = await _openFixture(
          mapBytes: Uint8List.fromList([
            ...base,
            if (scenario.extra.isNotEmpty) ..._section(scenario.extra, []),
          ]),
        );
        addTearDown(fixture.dispose);
        if (scenario.locked case final layer?) {
          fixture.mapLayerController.setLocked(layer, true);
        }
        final before = fixture.openMapController.state.session!;
        final recipe = _recipe(
          overlay: true,
          requiredTileGroup: scenario.group,
          tileset: scenario.tileset,
        );
        final preview = fixture.controller.previewCatalogDoodad(
          recipe: recipe,
          owner: 0,
          originTileX: scenario.x,
          originTileY: scenario.y,
        );
        expect(preview, scenario.code);
        expect(
          fixture.controller
              .placeCatalogDoodad(
                recipe: recipe,
                owner: 0,
                originTileX: scenario.x,
                originTileY: scenario.y,
              )
              .issueCode,
          preview,
        );
        expect(fixture.openMapController.state.session, same(before));
        expect(fixture.controller.state.undoDepth, 0);
        expect(before.isDirty, isFalse);
      });
    }

    test(
      'refuses an off-map sparse footprint even when written cells and center fit',
      () async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        final before = fixture.openMapController.state.session!;
        final recipe = DoodadPlacementRecipe(
          tileset: StarCraftTilesetAssetSet.jungle,
          startTileGroup: 200,
          doodadType: 7,
          width: 3,
          height: 1,
          centerOffsetX: 48,
          centerOffsetY: 16,
          footprint: [
            for (var x = 0; x < 3; x++)
              DoodadFootprintCell(
                x: x,
                y: 0,
                rawTileValue: x == 0 ? 200 * 16 : null,
                requiredTileGroup: 0,
              ),
          ],
        );
        expect(
          fixture.controller.previewCatalogDoodad(
            recipe: recipe,
            owner: 0,
            originTileX: 6,
            originTileY: 1,
          ),
          ObjectPlacementDiagnosticCodes.outOfBounds,
        );
        expect(
          fixture.controller
              .placeCatalogDoodad(
                recipe: recipe,
                owner: 0,
                originTileX: 6,
                originTileY: 1,
              )
              .issueCode,
          ObjectPlacementDiagnosticCodes.outOfBounds,
        );
        expect(fixture.openMapController.state.session, same(before));
        expect(fixture.controller.state.undoDepth, 0);
      },
    );

    test(
      'preview rechecks locks and terrain after an earlier allowed hover',
      () async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        final recipe = _recipe(overlay: true, requiredTileGroup: 0);
        expect(
          fixture.controller.previewCatalogDoodad(
            recipe: recipe,
            owner: 0,
            originTileX: 1,
            originTileY: 1,
          ),
          isNull,
        );
        fixture.mapLayerController.setLocked(MapLayerType.terrain, true);
        expect(
          fixture.controller
              .placeCatalogDoodad(
                recipe: recipe,
                owner: 0,
                originTileX: 1,
                originTileY: 1,
              )
              .issueCode,
          ObjectPlacementDiagnosticCodes.layerLocked,
        );
        fixture.mapLayerController.setLocked(MapLayerType.terrain, false);
        expect(
          fixture.controller
              .placeCatalogDoodad(
                recipe: recipe,
                owner: 0,
                originTileX: 1,
                originTileY: 1,
              )
              .isPlaced,
          isTrue,
        );
        expect(
          fixture.controller.previewCatalogDoodad(
            recipe: _recipe(overlay: false, requiredTileGroup: 5),
            owner: 0,
            originTileX: 1,
            originTileY: 1,
          ),
          ObjectPlacementDiagnosticCodes.doodadTerrainMismatch,
        );
      },
    );

    test('applies DD2, MTXM and THG2 as one undo entry', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final original = fixture.openMapController.state.session!;
      final originalTiles = original.terrainViews.tileMaps.single.rawTileValues;
      final originalSprites =
          original.objectViews.spriteSections.single.sprites.length;

      final result = fixture.controller.placeCatalogDoodad(
        recipe: _recipe(overlay: true),
        owner: 3,
        originTileX: 1,
        originTileY: 1,
      );

      expect(result.isPlaced, isTrue);
      var session = fixture.openMapController.state.session!;
      final doodad = session.objectViews.doodadSections.single.doodads.last;
      expect(doodad.doodadType, 7);
      expect(doodad.owner, 3);
      expect(doodad.x, 1 * 32 + 32);
      expect(doodad.y, 1 * 32 + 16);
      expect(doodad.enabledValue, DoodadPlacementRecipe.enabled);

      final tiles = session.terrainViews.tileMaps.single.rawTileValues;
      expect(tiles[1 * 8 + 1], 200 * 16 + 0);
      expect(tiles[1 * 8 + 2], 200 * 16 + 1);
      expect(tiles[0], originalTiles[0]);

      final sprites = session.objectViews.spriteSections.single.sprites;
      expect(sprites, hasLength(originalSprites + 1));
      expect(sprites.last.spriteType, 42);
      expect(sprites.last.drawsAsSprite, isTrue);
      expect(sprites.last.x, doodad.x);
      expect(sprites.last.y, doodad.y);

      expect(fixture.controller.state.undoDepth, 1);
      expect(fixture.controller.undo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(session.objectViews.doodadSections.single.doodads, hasLength(1));
      expect(
        session.objectViews.spriteSections.single.sprites,
        hasLength(originalSprites),
      );
      expect(
        session.terrainViews.tileMaps.single.rawTileValues,
        orderedEquals(originalTiles),
      );

      expect(fixture.controller.redo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(
        session.terrainViews.tileMaps.single.rawTileValues[1 * 8 + 1],
        200 * 16,
      );
    });

    test('creates the missing DD2 and THG2 sections together', () async {
      final fixture = await _openFixture(
        includeDoodads: false,
        includeSprites: false,
      );
      addTearDown(fixture.dispose);
      final before =
          fixture.openMapController.state.session!.rawDocument.sections.length;

      expect(
        fixture.controller
            .placeCatalogDoodad(
              recipe: _recipe(overlay: true),
              owner: 0,
              originTileX: 0,
              originTileY: 0,
            )
            .isPlaced,
        isTrue,
      );

      var session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before + 2));
      expect(session.rawDocument.sections[before].name, 'DD2 ');
      expect(session.rawDocument.sections[before + 1].name, 'THG2');

      expect(fixture.controller.undo(), isTrue);
      session = fixture.openMapController.state.session!;
      expect(session.rawDocument.sections, hasLength(before));
      expect(session.objectViews.doodadSections, isEmpty);
      expect(session.objectViews.spriteSections, isEmpty);
    });

    test('does not touch THG2 when the recipe has no overlay', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final originalSprites = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .spriteSections
          .single
          .rawSection
          .payload;

      expect(
        fixture.controller
            .placeCatalogDoodad(
              recipe: _recipe(overlay: false),
              owner: 0,
              originTileX: 2,
              originTileY: 2,
            )
            .isPlaced,
        isTrue,
      );

      expect(
        fixture
            .openMapController
            .state
            .session!
            .objectViews
            .spriteSections
            .single
            .rawSection
            .payload,
        orderedEquals(originalSprites),
      );
    });

    test('refuses a footprint whose terrain group does not match', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);

      final result = fixture.controller.placeCatalogDoodad(
        recipe: _recipe(overlay: true, requiredTileGroup: 5),
        owner: 0,
        originTileX: 1,
        originTileY: 1,
      );

      expect(
        result.issueCode,
        ObjectPlacementDiagnosticCodes.doodadTerrainMismatch,
      );
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
      expect(fixture.controller.state.undoDepth, 0);
    });

    test('refuses a footprint outside the map', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);

      expect(
        fixture.controller
            .placeCatalogDoodad(
              recipe: _recipe(overlay: false),
              owner: 0,
              originTileX: 7,
              originTileY: 0,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.outOfBounds,
      );
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
    });

    test('refuses a recipe from another tileset', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);

      expect(
        fixture.controller
            .placeCatalogDoodad(
              recipe: _recipe(
                overlay: false,
                tileset: StarCraftTilesetAssetSet.badlands,
              ),
              owner: 0,
              originTileX: 1,
              originTileY: 1,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.doodadTilesetMismatch,
      );
    });

    test('refuses when the terrain layer is locked', () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.mapLayerController.setLocked(MapLayerType.terrain, true);

      expect(
        fixture.controller
            .placeCatalogDoodad(
              recipe: _recipe(overlay: false),
              owner: 0,
              originTileX: 1,
              originTileY: 1,
            )
            .issueCode,
        ObjectPlacementDiagnosticCodes.layerLocked,
      );
    });
  });
}

const _existingMaximumClassId = 0x5d5c5b5a;

String? _pointPreview(
  ObjectEditingController c,
  String kind, {
  int x = 31,
  int y = 63,
  int id = 37,
  int owner = 0,
  UnitPlacementCapability? capability,
}) => switch (kind) {
  'unit' => c.previewCatalogUnit(
    capability: capability ?? _capability(37),
    unitId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
  'spriteUnit' => c.previewCatalogSpriteUnit(
    capability: capability ?? _capability(37),
    unitId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
  _ => c.previewCatalogPureSprite(
    spriteId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
};
ObjectPlacementResult _pointApply(
  ObjectEditingController c,
  String kind, {
  int x = 31,
  int y = 63,
  int id = 37,
  int owner = 0,
  UnitPlacementCapability? capability,
}) => switch (kind) {
  'unit' => c.placeCatalogUnit(
    capability: capability ?? _capability(37),
    unitId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
  'spriteUnit' => c.placeCatalogSpriteUnit(
    capability: capability ?? _capability(37),
    unitId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
  _ => c.placeCatalogPureSprite(
    spriteId: id,
    owner: owner,
    pixelX: x,
    pixelY: y,
  ),
};

UnitPlacementCapability _capability(
  int unitId, {
  bool requiresRelationLink = false,
  bool isSubunit = false,
  bool isBuilding = false,
  BuildingPlacementBox? placementBox,
  UnitCollisionProfile? collisionProfile,
}) => UnitPlacementCapability(
  unitId: unitId,
  placementBox: placementBox,
  collisionProfile: collisionProfile,
  isSubunit: isSubunit,
  isSpellcaster: false,
  hasShields: false,
  isResourceContainer: false,
  isGasResourceContainer: false,
  hasHangar: false,
  isFlyingBuilding: false,
  isBurrowable: false,
  isCloakable: false,
  isInvincible: false,
  isBuilding: isBuilding,
  requiresRelationLink: requiresRelationLink,
);

DoodadPlacementRecipe _recipe({
  required bool overlay,
  int requiredTileGroup = 0,
  StarCraftTilesetAssetSet tileset = StarCraftTilesetAssetSet.jungle,
}) => DoodadPlacementRecipe(
  tileset: tileset,
  startTileGroup: 200,
  doodadType: 7,
  width: 2,
  height: 1,
  centerOffsetX: 32,
  centerOffsetY: 16,
  footprint: [
    DoodadFootprintCell(
      x: 0,
      y: 0,
      rawTileValue: 200 * 16,
      requiredTileGroup: requiredTileGroup,
    ),
    DoodadFootprintCell(
      x: 1,
      y: 0,
      rawTileValue: 200 * 16 + 1,
      requiredTileGroup: requiredTileGroup,
    ),
  ],
  overlay: overlay
      ? DoodadOverlayRecipe(semantic: DoodadOverlaySemantic.pureSprite, id: 42)
      : null,
);

final class _Fixture {
  const _Fixture({
    required this.openMapController,
    required this.mapLayerController,
    required this.controller,
    required this.progressController,
  });

  final OpenMapController openMapController;
  final MapLayerController mapLayerController;
  final ObjectEditingController controller;
  final OperationProgressController progressController;

  Future<void> dispose() async {
    await controller.dispose();
    await mapLayerController.dispose();
    await openMapController.dispose();
    await progressController.dispose();
  }
}

void _locationMixedDoodadDeletionTests() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'Location mixed $overlay clears slots and all five layers undo atomically',
      () async {
        final doc = doodadLocationDeletionDocument(
          overlay: overlay,
          batch: true,
          units: true,
        );
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(doc),
        );
        addTearDown(f.dispose);
        final before = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final plan = f.controller.prepareDoodadDeletions(
          batchDeletionRequests(overlay: overlay),
          selectedLocationRecordIndices: [0, 254],
          confirmedLocationRecordIndices: [254, 0],
          selectedUnitRecordIndices: [0],
          confirmedUnitPeerRecordIndices: [1],
          selectedSpriteRecordIndices: [0, 1],
        );
        for (final layer in MapLayerType.values) {
          f.mapLayerController.setLocked(layer, true);
          expect(() => f.controller.deleteDoodad(plan), throwsStateError);
          expect(f.openMapController.editHistory.undoDepth, 0);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          f.mapLayerController.setLocked(layer, false);
        }
        f.controller.deleteDoodad(plan);
        final after = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final locations = f
            .openMapController
            .state
            .session!
            .objectViews
            .locationSections
            .single
            .locations;
        expect(locations.length, 255);
        expect(locations[0].isBlank, isTrue);
        expect(locations[254].isBlank, isTrue);
        expect(locations[1].isBlank, isFalse);
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.controller.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          after,
        );
        expect(() => f.controller.deleteDoodad(plan), throwsStateError);
      },
    );
  }
  for (final mode in ['referenced', 'stale', '254', '255']) {
    testWidgets('Location mixed review handles $mode without partial editing', (
      tester,
    ) async {
      var doc = doodadLocationDeletionDocument();
      final limit = mode == '254' || mode == '255';
      if (limit) {
        final at = doc.sections.indexWhere((s) => s.name == 'MRGN');
        final bytes = doc.sections[at].payload;
        for (var i = 0; i < 255; i++) {
          if (i != 63) {
            bytes[i * 20] = 1;
          }
        }
        doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
      }
      if (mode == 'referenced') {
        final op = TriggerOpcodes.actions.singleWhere((o) => o.id == 10);
        final trigger = ChkTrigger.create().withSlot(
          true,
          0,
          ChkTrigger.makeSlot(true, op, {'Location ID': 1}, doc),
        );
        final at = doc.sections.indexWhere((s) => s.name == 'TRIG');
        doc = doc.replaceSection(
          at,
          doc.sections[at].withPayload(trigger.bytes),
        );
      }
      final f = await _openFixture(mapBytes: const RawChkEncoder().encode(doc));
      addTearDown(f.dispose);
      final session = f.openMapController.state.session!;
      final before = const RawChkEncoder().encode(session.rawDocument);
      f.mapLayerController.selectObjects(
        session: session,
        objects: [
          MapLayerObjectRef(
            layer: MapLayerType.doodads,
            sectionIndex:
                session.objectViews.doodadSections.single.sectionIndex,
            recordIndex: 0,
          ),
          for (final i
              in limit
                  ? [
                      for (var i = 0; i < 255; i++)
                        if (mode == '255' || i != 63) i,
                    ]
                  : [0])
            MapLayerObjectRef(
              layer: MapLayerType.locations,
              sectionIndex:
                  session.objectViews.locationSections.single.sectionIndex,
              recordIndex: i,
            ),
        ],
      );
      final catalog = _DeletionCatalog(deletionRecipe());
      if (mode == 'stale') {
        catalog.beforeList = () async {
          await f.openMapController.open(sourcePath: r'C:\Maps\Placement.scx');
        };
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => deleteObjectsWithDoodadReview(
                  context,
                  f.controller,
                  catalog,
                ),
                child: const Text('Delete selection'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete selection'));
      await tester.pumpAndSettle();
      expect(
        const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(f.openMapController.editHistory.undoDepth, 0);
      expect(catalog.calls, mode == 'stale' || mode == '254' ? 1 : 0);
      if (mode == '254') {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('doodad-delete-apply')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(const Key('doodad-delete-location-confirm')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('doodad-delete-apply')));
        await tester.pumpAndSettle();
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .locationSections
              .single
              .locations
              .where((l) => !l.isBlank)
              .length,
          1,
        );
      } else {
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    for (final units in [false, true]) {
      testWidgets(
        'Location mixed confirms all effects at $width units=$units',
        (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const overlay = DoodadOverlaySemantic.spriteUnit;
          final doc = doodadLocationDeletionDocument(
            overlay: overlay,
            units: units,
          );
          final f = await _openFixture(
            mapBytes: const RawChkEncoder().encode(doc),
          );
          addTearDown(f.dispose);
          final session = f.openMapController.state.session!;
          final before = const RawChkEncoder().encode(session.rawDocument);
          f.mapLayerController.selectObjects(
            session: session,
            objects: [
              MapLayerObjectRef(
                layer: MapLayerType.doodads,
                sectionIndex:
                    session.objectViews.doodadSections.single.sectionIndex,
                recordIndex: 0,
              ),
              MapLayerObjectRef(
                layer: MapLayerType.locations,
                sectionIndex:
                    session.objectViews.locationSections.single.sectionIndex,
                recordIndex: 0,
              ),
              if (units)
                MapLayerObjectRef(
                  layer: MapLayerType.units,
                  sectionIndex:
                      session.objectViews.unitSections.single.sectionIndex,
                  recordIndex: 0,
                ),
              for (final i in [0, 1])
                MapLayerObjectRef(
                  layer: MapLayerType.sprites,
                  sectionIndex:
                      session.objectViews.spriteSections.single.sectionIndex,
                  recordIndex: i,
                ),
            ],
          );
          final catalog = _DeletionCatalog(deletionRecipe(overlay: overlay));
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => deleteObjectsWithDoodadReview(
                      context,
                      f.controller,
                      catalog,
                    ),
                    child: const Text('Delete selection'),
                  ),
                ),
              ),
            ),
          );
          final scrollable = find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first;
          for (final apply in [false, true]) {
            await tester.tap(find.text('Delete selection'));
            await tester.pumpAndSettle();
            expect(
              find.text(
                locale.languageCode == 'ko'
                    ? '선택 객체 함께 삭제'
                    : 'Delete selected objects',
              ),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('doodad-delete-apply')),
                  )
                  .onPressed,
              isNull,
            );
            if (!apply) {
              await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
              await tester.pumpAndSettle();
              expect(
                const RawChkEncoder().encode(
                  f.openMapController.state.session!.rawDocument,
                ),
                before,
              );
              expect(f.openMapController.editHistory.undoDepth, 0);
              continue;
            }
            await tester.scrollUntilVisible(
              find.byKey(const Key('doodad-delete-overlay-0')),
              150,
              scrollable: scrollable,
            );
            await tester.tap(find.byKey(const Key('doodad-delete-overlay-0')));
            await tester.pumpAndSettle();
            await tester.tap(
              find
                  .text(
                    locale.languageCode == 'ko'
                        ? 'THG2 레코드 #1 · 종류 100'
                        : 'THG2 record #1 · type 100',
                  )
                  .last,
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('doodad-delete-apply')),
                  )
                  .onPressed,
              isNull,
            );
            if (units) {
              await tester.scrollUntilVisible(
                find.byKey(const Key('doodad-delete-unit-unlink')),
                -150,
                scrollable: scrollable,
              );
              await tester.tap(
                find.byKey(const Key('doodad-delete-unit-unlink')),
              );
              await tester.pumpAndSettle();
            }
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('doodad-delete-apply')),
                  )
                  .onPressed,
              isNull,
            );
            await tester.scrollUntilVisible(
              find.byKey(const Key('doodad-delete-location-confirm')),
              -150,
              scrollable: scrollable,
            );
            await tester.tap(
              find.byKey(const Key('doodad-delete-location-confirm')),
            );
            await tester.pumpAndSettle();
            f.mapLayerController.setLocked(MapLayerType.locations, true);
            await tester.tap(find.byKey(const Key('doodad-delete-apply')));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(f.openMapController.editHistory.undoDepth, 0);
            expect(
              const RawChkEncoder().encode(
                f.openMapController.state.session!.rawDocument,
              ),
              before,
            );
            f.mapLayerController.setLocked(MapLayerType.locations, false);
            await tester.tap(find.byKey(const Key('doodad-delete-apply')));
            await tester.pumpAndSettle();
          }
          expect(find.byType(AlertDialog), findsNothing);
          expect(f.openMapController.editHistory.undoDepth, 1);
          expect(
            f
                .openMapController
                .state
                .session!
                .objectViews
                .locationSections
                .single
                .locations[0]
                .isBlank,
            isTrue,
          );
          expect(f.controller.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

void _unitMixedDoodadDeletionTests() {
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'unit mixed $overlay deletes atomically with mutual peer and layer checks',
      () async {
        final doc = doodadUnitDeletionDocument(overlay: overlay, batch: true);
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(doc),
        );
        addTearDown(f.dispose);
        final before = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final plan = f.controller.prepareDoodadDeletions(
          batchDeletionRequests(overlay: overlay),
          selectedSpriteRecordIndices: [0, 1],
          selectedUnitRecordIndices: [0],
          confirmedUnitPeerRecordIndices: [1],
        );
        expect(plan.unitDeletion!.unlinkedPeerRecordIndices, {1});
        for (final layer in [
          MapLayerType.units,
          MapLayerType.terrain,
          MapLayerType.doodads,
          MapLayerType.sprites,
        ]) {
          f.mapLayerController.setLocked(layer, true);
          expect(() => f.controller.deleteDoodad(plan), throwsStateError);
          expect(f.openMapController.editHistory.undoDepth, 0);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          f.mapLayerController.setLocked(layer, false);
        }
        expect(
          () => f.controller.prepareDoodadDeletions(
            batchDeletionRequests(overlay: overlay),
            selectedUnitRecordIndices: [999],
          ),
          throwsStateError,
        );
        f.controller.deleteDoodad(plan);
        final after = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final units = f
            .openMapController
            .state
            .session!
            .objectViews
            .unitSections
            .single
            .units;
        expect(units.length, 2);
        expect(units.first.classId, 12);
        expect(units.first.relationFlags, 0);
        expect(units.first.relationClassId, 0);
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.controller.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          after,
        );
        expect(() => f.controller.deleteDoodad(plan), throwsStateError);
      },
    );
  }
  for (final count in [256, 257]) {
    testWidgets(
      'unit mixed selection is bounded at $count before catalog lookup',
      (tester) async {
        var doc = deletionDocument();
        final at = doc.sections.indexWhere((s) => s.name == 'UNIT');
        doc = doc.replaceSection(
          at,
          doc.sections[at].withPayload([
            for (var i = 0; i < count; i++) ...basicUnit(id: i + 1),
          ]),
        );
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(doc),
        );
        addTearDown(f.dispose);
        final session = f.openMapController.state.session!;
        f.mapLayerController.selectObjects(
          session: session,
          objects: [
            MapLayerObjectRef(
              layer: MapLayerType.doodads,
              sectionIndex:
                  session.objectViews.doodadSections.single.sectionIndex,
              recordIndex: 0,
            ),
            for (var i = 0; i < count; i++)
              MapLayerObjectRef(
                layer: MapLayerType.units,
                sectionIndex:
                    session.objectViews.unitSections.single.sectionIndex,
                recordIndex: i,
              ),
          ],
        );
        final catalog = _DeletionCatalog(deletionRecipe());
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => deleteObjectsWithDoodadReview(
                    context,
                    f.controller,
                    catalog,
                  ),
                  child: const Text('Delete selection'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Delete selection'));
        await tester.pumpAndSettle();
        expect(catalog.calls, count == 256 ? 1 : 0);
        expect(
          f.openMapController.state.session!.rawDocument,
          same(session.rawDocument),
        );
        if (count == 256) {
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.byKey(const Key('doodad-delete-unit-unlink')),
            findsNothing,
          );
          await tester.tap(find.byKey(const Key('doodad-delete-apply')));
          await tester.pumpAndSettle();
          expect(
            f
                .openMapController
                .state
                .session!
                .objectViews
                .unitSections
                .single
                .units,
            isEmpty,
          );
          expect(f.openMapController.editHistory.undoDepth, 1);
        } else {
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.byType(SnackBar), findsOneWidget);
          expect(f.openMapController.editHistory.undoDepth, 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    for (final both in [false, true]) {
      testWidgets('unit mixed confirmation and cancel at $width both=$both', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const overlay = DoodadOverlaySemantic.spriteUnit;
        final doc = doodadUnitDeletionDocument(
          overlay: overlay,
          nydus: width == 1200,
        );
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(doc),
        );
        addTearDown(f.dispose);
        final session = f.openMapController.state.session!;
        final before = const RawChkEncoder().encode(session.rawDocument);
        f.mapLayerController.selectObjects(
          session: session,
          objects: [
            MapLayerObjectRef(
              layer: MapLayerType.doodads,
              sectionIndex:
                  session.objectViews.doodadSections.single.sectionIndex,
              recordIndex: 0,
            ),
            for (final i in [0, if (both) 1])
              MapLayerObjectRef(
                layer: MapLayerType.units,
                sectionIndex:
                    session.objectViews.unitSections.single.sectionIndex,
                recordIndex: i,
              ),
            for (final i in [0, 1])
              MapLayerObjectRef(
                layer: MapLayerType.sprites,
                sectionIndex:
                    session.objectViews.spriteSections.single.sectionIndex,
                recordIndex: i,
              ),
          ],
        );
        final catalog = _DeletionCatalog(deletionRecipe(overlay: overlay));
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => deleteObjectsWithDoodadReview(
                    context,
                    f.controller,
                    catalog,
                  ),
                  child: const Text('Delete selection'),
                ),
              ),
            ),
          ),
        );
        for (final apply in [false, true]) {
          await tester.tap(find.text('Delete selection'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale.languageCode == 'ko'
                  ? '선택 객체 함께 삭제'
                  : 'Delete selected objects',
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('doodad-delete-unit-unlink')),
            both ? findsNothing : findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('doodad-delete-apply')),
                )
                .onPressed,
            isNull,
          );
          if (!apply) {
            await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
            await tester.pumpAndSettle();
            expect(f.openMapController.editHistory.undoDepth, 0);
            expect(
              const RawChkEncoder().encode(
                f.openMapController.state.session!.rawDocument,
              ),
              before,
            );
            continue;
          }
          await tester.scrollUntilVisible(
            find.byKey(const Key('doodad-delete-overlay-0')),
            150,
            scrollable: find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.byKey(const Key('doodad-delete-overlay-0')));
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .text(
                  locale.languageCode == 'ko'
                      ? 'THG2 레코드 #1 · 종류 100'
                      : 'THG2 record #1 · type 100',
                )
                .last,
          );
          await tester.pumpAndSettle();
          if (!both) {
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('doodad-delete-apply')),
                  )
                  .onPressed,
              isNull,
            );
            await tester.scrollUntilVisible(
              find.byKey(const Key('doodad-delete-unit-unlink')),
              -150,
              scrollable: find
                  .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.tap(
              find.byKey(const Key('doodad-delete-unit-unlink')),
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(const Key('doodad-delete-apply')));
          await tester.pumpAndSettle();
        }
        expect(find.byType(AlertDialog), findsNothing);
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .unitSections
              .single
              .units
              .length,
          both ? 1 : 2,
        );
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

void _mixedDoodadSpriteDeletionTests() {
  for (final count in [256, 257]) {
    testWidgets('mixed review enforces the selected sprite limit at $count', (
      tester,
    ) async {
      var doc = deletionDocument();
      final at = doc.sections.indexWhere((s) => s.name == 'THG2');
      doc = doc.replaceSection(
        at,
        doc.sections[at].withPayload(Uint8List(count * 10)),
      );
      final f = await _openFixture(mapBytes: const RawChkEncoder().encode(doc));
      addTearDown(f.dispose);
      final session = f.openMapController.state.session!;
      final before = const RawChkEncoder().encode(session.rawDocument);
      f.mapLayerController.selectObjects(
        session: session,
        objects: [
          MapLayerObjectRef(
            layer: MapLayerType.doodads,
            sectionIndex:
                session.objectViews.doodadSections.single.sectionIndex,
            recordIndex: 0,
          ),
          for (var i = 0; i < count; i++)
            MapLayerObjectRef(
              layer: MapLayerType.sprites,
              sectionIndex:
                  session.objectViews.spriteSections.single.sectionIndex,
              recordIndex: i,
            ),
        ],
      );
      final catalog = _DeletionCatalog(deletionRecipe());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => deleteObjectsWithDoodadReview(
                  context,
                  f.controller,
                  catalog,
                ),
                child: const Text('Delete selection'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete selection'));
      await tester.pumpAndSettle();
      expect(catalog.calls, count == 256 ? 1 : 0);
      expect(
        const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(f.openMapController.editHistory.undoDepth, 0);
      if (count == 256) {
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.byKey(const Key('doodad-delete-apply')));
        await tester.pumpAndSettle();
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .spriteSections
              .single
              .sprites,
          isEmpty,
        );
        expect(f.openMapController.editHistory.undoDepth, 1);
      } else {
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
    test(
      'mixed Doodad/Sprite $overlay is atomic and obeys every layer lock',
      () async {
        final f = await _openFixture(
          mapBytes: const RawChkEncoder().encode(
            deletionDocument(overlay: overlay),
          ),
        );
        addTearDown(f.dispose);
        final before = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        final plan = f.controller.prepareDoodadDeletions(
          [
            DoodadDeletionRequest(
              recipe: deletionRecipe(overlay: overlay),
              recordIndex: 0,
              confirmedOverlayRecordIndex: overlay == null ? null : 1,
            ),
          ],
          selectedSpriteRecordIndices: [0, 1],
        );
        expect(plan.spriteCount, 2);
        for (final layer in [
          MapLayerType.doodads,
          MapLayerType.terrain,
          MapLayerType.sprites,
        ]) {
          f.mapLayerController.setLocked(layer, true);
          expect(() => f.controller.deleteDoodad(plan), throwsStateError);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(f.openMapController.editHistory.undoDepth, 0);
          f.mapLayerController.setLocked(layer, false);
        }
        expect(
          () => f.controller.prepareDoodadDeletions(
            [
              DoodadDeletionRequest(
                recipe: deletionRecipe(overlay: overlay),
                recordIndex: 0,
                confirmedOverlayRecordIndex: overlay == null ? null : 1,
              ),
            ],
            selectedSpriteRecordIndices: [999],
          ),
          throwsStateError,
        );
        expect(f.openMapController.editHistory.undoDepth, 0);
        f.controller.deleteDoodad(plan);
        final after = const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        );
        expect(f.openMapController.editHistory.undoDepth, 1);
        expect(
          f
              .openMapController
              .state
              .session!
              .objectViews
              .spriteSections
              .single
              .sprites
              .length,
          1,
        );
        expect(f.controller.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.controller.redo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          after,
        );
        expect(() => f.controller.deleteDoodad(plan), throwsStateError);
      },
    );
  }
  for (final (width, locale) in [
    (600.0, const Locale('ko')),
    (1200.0, const Locale('en')),
  ]) {
    for (final overlay in [null, ...DoodadOverlaySemantic.values]) {
      testWidgets(
        'mixed review $overlay at $width requires confirmation, cancel and one Undo',
        (tester) async {
          tester.view.physicalSize = Size(width, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final f = await _openFixture(
            mapBytes: const RawChkEncoder().encode(
              deletionDocument(overlay: overlay),
            ),
          );
          addTearDown(f.dispose);
          final session = f.openMapController.state.session!;
          void select() => f.mapLayerController.selectObjects(
            session: session,
            objects: [
              MapLayerObjectRef(
                layer: MapLayerType.doodads,
                sectionIndex:
                    session.objectViews.doodadSections.single.sectionIndex,
                recordIndex: 0,
              ),
              for (final index in [0, 1])
                MapLayerObjectRef(
                  layer: MapLayerType.sprites,
                  sectionIndex:
                      session.objectViews.spriteSections.single.sectionIndex,
                  recordIndex: index,
                ),
            ],
          );
          select();
          expect(f.controller.canEditSelection, isTrue);
          final before = const RawChkEncoder().encode(session.rawDocument);
          final catalog = _DeletionCatalog(deletionRecipe(overlay: overlay));
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => deleteObjectsWithDoodadReview(
                      context,
                      f.controller,
                      catalog,
                    ),
                    child: const Text('Delete selection'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Delete selection'));
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale.languageCode == 'ko'
                  ? '두다드 1개와 선택 스프라이트 2개 삭제'
                  : 'Delete 1 Doodads and 2 selected Sprites',
            ),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('doodad-delete-apply')),
                )
                .onPressed,
            overlay == null ? isNotNull : isNull,
          );
          await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
          await tester.pumpAndSettle();
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(f.openMapController.editHistory.undoDepth, 0);
          await tester.tap(find.text('Delete selection'));
          await tester.pumpAndSettle();
          if (overlay != null) {
            await tester.ensureVisible(
              find.byKey(const Key('doodad-delete-overlay-0')),
            );
            await tester.tap(find.byKey(const Key('doodad-delete-overlay-0')));
            await tester.pumpAndSettle();
            await tester.tap(
              find
                  .text(
                    locale.languageCode == 'ko'
                        ? 'THG2 레코드 #1 · 종류 100'
                        : 'THG2 record #1 · type 100',
                  )
                  .last,
            );
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(const Key('doodad-delete-apply')));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(f.openMapController.editHistory.undoDepth, 1);
          expect(
            f
                .openMapController
                .state
                .session!
                .objectViews
                .spriteSections
                .single
                .sprites
                .length,
            1,
          );
          expect(f.controller.undo(), isTrue);
          expect(
            const RawChkEncoder().encode(
              f.openMapController.state.session!.rawDocument,
            ),
            before,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

void _retainedDoodadNeighborTests() {
  for (final batch in [false, true]) {
    for (final ambiguous in [false, true]) {
      for (final locale in [const Locale('ko'), const Locale('en')]) {
        testWidgets(
          'retained neighbor batch=$batch ambiguous=$ambiguous ${locale.languageCode}',
          (tester) async {
            tester.view.physicalSize = Size(
              locale.languageCode == 'ko' ? 600 : 1200,
              900,
            );
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final doc = batchDeletionDocument(
              count: batch ? 3 : 2,
              overlay: DoodadOverlaySemantic.spriteUnit,
            );
            final f = await _openFixture(
              mapBytes: const RawChkEncoder().encode(doc),
            );
            addTearDown(f.dispose);
            final session = f.openMapController.state.session!;
            f.mapLayerController.selectObjects(
              session: session,
              objects: [
                for (final index in [0, if (batch) 2])
                  MapLayerObjectRef(
                    layer: MapLayerType.doodads,
                    sectionIndex:
                        session.objectViews.doodadSections.single.sectionIndex,
                    recordIndex: index,
                  ),
              ],
            );
            final recipe = deletionRecipe(
              overlay: DoodadOverlaySemantic.spriteUnit,
            );
            final catalog = _DeletionCatalog(recipe)
              ..byType = {
                7: [
                  recipe,
                  if (ambiguous)
                    deletionRecipe(overlay: DoodadOverlaySemantic.spriteUnit),
                ],
              };
            final before = const RawChkEncoder().encode(session.rawDocument);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => deleteObjectsWithDoodadReview(
                        context,
                        f.controller,
                        catalog,
                      ),
                      child: const Text('Delete selection'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Delete selection'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const Key('doodad-delete-apply')),
                  )
                  .onPressed,
              isNull,
            );
            await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
            await tester.pumpAndSettle();
            expect(
              f.openMapController.state.session!.rawDocument,
              same(session.rawDocument),
            );
            expect(f.openMapController.editHistory.undoDepth, 0);
            await tester.tap(find.text('Delete selection'));
            await tester.pumpAndSettle();
            for (final index in [0, if (batch) 2]) {
              final key = Key(
                batch
                    ? 'doodad-delete-overlay-$index'
                    : 'doodad-delete-overlay',
              );
              if (batch) {
                await tester.scrollUntilVisible(
                  find.byKey(key),
                  150,
                  scrollable: find
                      .descendant(
                        of: find.byType(AlertDialog),
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
              }
              await tester.tap(find.byKey(key));
              await tester.pumpAndSettle();
              final overlayIndex = index == 0 ? 1 : 3;
              await tester.tap(
                find
                    .text(
                      locale.languageCode == 'ko'
                          ? 'THG2 레코드 #$overlayIndex · 종류 100'
                          : 'THG2 record #$overlayIndex · type 100',
                    )
                    .last,
              );
              await tester.pumpAndSettle();
            }
            await tester.tap(find.byKey(const Key('doodad-delete-apply')));
            await tester.pumpAndSettle();
            // One catalog pass per dialog, including when a neighbor is retained.
            expect(catalog.calls, 2);
            expect(catalog.requiredCompleteTypes, isTrue);
            if (ambiguous) {
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(
                find.textContaining('nearby doodad ownership is ambiguous'),
                findsOneWidget,
              );
              expect(
                f.openMapController.state.session!.rawDocument,
                same(session.rawDocument),
              );
              expect(f.openMapController.editHistory.undoDepth, 0);
              await tester.tap(find.byKey(const Key('doodad-delete-cancel')));
              await tester.pumpAndSettle();
            } else {
              expect(find.byType(AlertDialog), findsNothing);
              expect(f.openMapController.editHistory.undoDepth, 1);
              final after = f.openMapController.state.session!;
              expect(
                after.objectViews.doodadSections.single.doodads,
                hasLength(2),
              );
              expect(
                after.objectViews.spriteSections.single.sprites,
                hasLength(3),
              );
              final originalDD = doc.sections
                  .singleWhere((s) => s.name == 'DD2 ')
                  .payload;
              final retained = batch ? 3 : 2;
              expect(
                after.rawDocument.sections
                    .singleWhere((s) => s.name == 'DD2 ')
                    .payload,
                [
                  ...originalDD.sublist(8, 16),
                  ...originalDD.sublist(retained * 8, retained * 8 + 8),
                ],
              );
              final afterBytes = const RawChkEncoder().encode(
                after.rawDocument,
              );
              expect(f.controller.undo(), isTrue);
              expect(
                const RawChkEncoder().encode(
                  f.openMapController.state.session!.rawDocument,
                ),
                before,
              );
              expect(f.controller.redo(), isTrue);
              expect(
                const RawChkEncoder().encode(
                  f.openMapController.state.session!.rawDocument,
                ),
                afterBytes,
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}

class _DeletionCatalog implements PlacementCatalogController {
  _DeletionCatalog(this.recipe);
  final DoodadPlacementRecipe recipe;
  int calls = 0;
  Map<int, List<DoodadPlacementRecipe>>? byType;
  List<int>? requestedTypes;
  Future<void> Function()? beforeList;
  bool? requiredCompleteTypes;
  @override
  Future<List<DoodadPlacementRecipe>> doodadRecipes(
    int type, {
    bool requireCompleteTypes = false,
  }) async {
    requiredCompleteTypes = requireCompleteTypes;
    calls++;
    await beforeList?.call();
    return byType == null ? [recipe] : byType![type] ?? [];
  }

  @override
  Future<Map<int, List<DoodadPlacementRecipe>>> doodadRecipesForTypes(
    Iterable<int> types, {
    bool requireCompleteTypes = false,
  }) async {
    requiredCompleteTypes = requireCompleteTypes;
    calls++;
    requestedTypes = types.toList();
    await beforeList?.call();
    return byType ??
        {
          for (final type in types) type: [recipe],
        };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Fixture> _openFixture({
  bool includeUnits = true,
  bool includeSprites = true,
  bool includeDoodads = true,
  bool duplicateUnits = false,
  bool includeUnderlying = false,
  Uint8List? mapBytes,
}) async {
  final base = _chkBytes(
    includeUnits: includeUnits,
    includeSprites: includeSprites,
    includeDoodads: includeDoodads,
    duplicateUnits: duplicateUnits,
  );
  final chkBytes =
      mapBytes ??
      Uint8List.fromList([
        ...base,
        if (includeUnderlying) ..._section('TILE', Uint8List(8 * 8 * 2)),
      ]);
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Placement.scx',
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
  final controller = ObjectEditingController(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
  )..synchronizeSession(state.session);
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    controller: controller,
    progressController: progressController,
  );
}

Uint8List _chkBytes({
  required bool includeUnits,
  required bool includeSprites,
  required bool includeDoodads,
  required bool duplicateUnits,
}) {
  final locations = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  final builder = BytesBuilder(copy: false);
  for (final section in [
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [8, 0, 8, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', Uint8List(8 * 8 * 2)),
    if (includeUnits)
      _section('UNIT', [..._unit(64, 64, 1), ..._unit(96, 96, 90)]),
    if (includeUnits && duplicateUnits) _section('UNIT', _unit(32, 32, 5)),
    if (includeDoodads) _section('DD2 ', _doodad(64, 64)),
    if (includeSprites) _section('THG2', _sprite(64, 64)),
    _section('MRGN', locations),
    _section('STR ', _legacyStringTable(['Existing'])),
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
