import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/presentation/settings/weapon_impact_panel.dart';
import 'package:starcraft_map_editor/domain/placement/unit_weapon_references.dart';
import 'dart:async';
import 'dart:io';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_starcraft_tile_atlas_gateway.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_placement.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_object_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_tile_atlas_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

const _installationPath = r'C:\StarCraft';

void main() {
  final realInstallation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final realHelper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  test(
    'profiles complete local object catalogs and clears retained thumbnails',
    () async {
      final fixture = await _openFixture(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: realHelper!,
        ),
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: realHelper,
        ),
        pageSize: 32,
      );
      addTearDown(fixture.dispose);
      final controller = fixture.controller;
      controller.setInstallationPath(realInstallation);
      final before = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      for (final kind in [
        StarCraftPlacementKind.unit,
        StarCraftPlacementKind.pureSprite,
      ]) {
        final watch = Stopwatch()..start();
        expect(
          await controller.load(kind),
          isTrue,
          reason: controller.state.diagnostics.map((d) => d.message).join('; '),
        );
        final firstPageMs = watch.elapsedMilliseconds;
        var pages = 1;
        while (controller.state.hasMore) {
          final previousCount = controller.state.items.length;
          expect(
            await controller.loadMore(),
            isTrue,
            reason: controller.state.diagnostics
                .map((d) => d.message)
                .join('; '),
          );
          expect(controller.state.items.length, greaterThan(previousCount));
          pages++;
        }
        watch.stop();
        final state = controller.state;
        expect(
          state.items.length,
          kind == StarCraftPlacementKind.unit ? 228 : 517,
        );
        expect(
          state.items.map((item) => item.key).toSet().length,
          state.items.length,
        );
        final thumbnails = state.items
            .where((item) => item.hasThumbnail)
            .toList();
        expect(thumbnails, isNotEmpty);
        var retainedBytes = 0;
        var largestThumbnailBytes = 0;
        for (final item in thumbnails) {
          final bytes = item.thumbnailRgba!.lengthInBytes;
          expect(bytes, item.thumbnailWidth * item.thumbnailHeight * 4);
          retainedBytes += bytes;
          if (bytes > largestThumbnailBytes) largestThumbnailBytes = bytes;
        }
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        debugPrint(
          'local catalog memory: kind=${kind.wireName} entries=${state.items.length} '
          'thumbnails=${thumbnails.length} pages=$pages rawBytes=$retainedBytes '
          'largestThumbnailBytes=$largestThumbnailBytes firstPageMs=$firstPageMs totalMs=${watch.elapsedMilliseconds}',
        );
      }
      controller.setInstallationPath(null);
      expect(controller.state.items, isEmpty);
      expect(controller.state.totalEntries, 0);
      expect(controller.state.selection, isNull);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !Platform.isWindows || realInstallation == null || realHelper == null
        ? 'Set local StarCraft installation and helper paths.'
        : false,
  );
  test(
    'local Doodad recipe updates terrain and overlay atomically',
    () async {
      final gateway = ProcessStarCraftPlacementCatalogGateway(
        helperExecutablePath: realHelper!,
      );
      final page = await gateway.list(
        StarCraftPlacementCatalogRequest(
          operationId: 'real-doodad-placement',
          installationPath: realInstallation!,
          kind: StarCraftPlacementKind.doodad,
          tileset: StarCraftTilesetAssetSet.jungle,
          limit: StarCraftPlacementCatalogRequest.maximumLimit,
        ),
      );
      expect(page.isSuccess, isTrue);
      final entry = page.entries.firstWhere(
        (entry) => entry.doodadRecipe?.overlay != null,
      );
      final recipe = entry.doodadRecipe!;
      const size = 32;
      const origin = 2;
      final terrainBytes = Uint8List(size * size * 2);
      final terrainData = ByteData.sublistView(terrainBytes);
      for (final cell in recipe.footprint) {
        terrainData.setUint16(
          ((origin + cell.y) * size + origin + cell.x) * 2,
          cell.requiredTileGroup << 4,
          Endian.little,
        );
      }
      final fixture = await _openFixture(
        catalogGateway: gateway,
        chkBytesOverride: _chkBytes(mapSize: size, terrainBytes: terrainBytes),
        pageSize: StarCraftPlacementCatalogRequest.maximumLimit,
      );
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(realInstallation);
      Uint8List bytes() => const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      final before = bytes();
      expect(
        await fixture.controller.load(StarCraftPlacementKind.doodad),
        isTrue,
      );
      expect(fixture.controller.confirm(entry.key), isTrue);
      expect(bytes(), before);
      final refused = fixture.controller.placeAt(
        pixelX: 0,
        pixelY: 0,
        tileX: -1,
        tileY: -1,
      );
      expect(refused.isPlaced, isFalse);
      expect(
        bytes(),
        before,
        reason: 'refused placement must not partially edit any section',
      );
      expect(fixture.objectEditingController.state.undoDepth, 0);
      expect(fixture.controller.confirm(entry.key), isTrue);
      final placed = fixture.controller.placeAt(
        pixelX: 0,
        pixelY: 0,
        tileX: origin + recipe.width ~/ 2,
        tileY: origin + recipe.height ~/ 2,
      );
      expect(placed.isPlaced, isTrue, reason: placed.issueCode);
      final session = fixture.openMapController.state.session!;
      final doodads = session.objectViews.doodadSections.single.doodads;
      expect(doodads, hasLength(2));
      final doodad = doodads.last;
      expect(doodad.doodadType, recipe.doodadType);
      expect(
        (doodad.x, doodad.y),
        (
          origin * 32 + recipe.centerOffsetX,
          origin * 32 + recipe.centerOffsetY,
        ),
      );
      final sprite = session.objectViews.spriteSections.single.sprites.single;
      expect(sprite.spriteType, recipe.overlay!.id);
      expect((sprite.x, sprite.y), (doodad.x, doodad.y));
      expect(
        sprite.drawsAsSprite,
        recipe.overlay!.semantic == DoodadOverlaySemantic.pureSprite,
      );
      final expectedTiles = List<int>.generate(
        size * size,
        (i) => terrainData.getUint16(i * 2, Endian.little),
      );
      for (final cell in recipe.footprint) {
        if (cell.writesTerrain) {
          expectedTiles[(origin + cell.y) * size + origin + cell.x] =
              cell.rawTileValue!;
        }
      }
      expect(session.terrainViews.tileMaps.single.rawTileValues, expectedTiles);
      expect(fixture.objectEditingController.state.undoDepth, 1);
      final after = bytes();
      expect(after, isNot(equals(before)));
      expect(fixture.objectEditingController.undo(), isTrue);
      expect(bytes(), before);
      expect(
        fixture.openMapController.state.session!.objectViews.spriteSections,
        isEmpty,
      );
      expect(fixture.objectEditingController.redo(), isTrue);
      expect(bytes(), after);
    },
    skip: !Platform.isWindows || realInstallation == null || realHelper == null
        ? 'Set local StarCraft installation and helper paths.'
        : false,
  );
  test(
    'local Tile catalog paints and restores exact CHK bytes',
    () async {
      final fixture = await _openFixture(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: realHelper!,
        ),
        tileAtlasGateway: ProcessStarCraftTileAtlasGateway(
          helperExecutablePath: realHelper,
        ),
      );
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(realInstallation);
      Uint8List bytes() => const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      final before = bytes();
      expect(
        await fixture.controller.load(StarCraftPlacementKind.tile),
        isTrue,
      );
      final item = fixture.controller.state.items.firstWhere(
        (item) => item.isPlaceable && item.key.id != 0,
      );
      expect(item.hasThumbnail, isTrue);
      expect(fixture.controller.confirm(item.key), isTrue);
      expect(bytes(), before);
      final terrain = fixture.terrainEditingController;
      expect(terrain.state.selectedRawTileValue, item.key.id);
      expect(terrain.beginBrushStroke(), isTrue);
      expect(
        terrain.paintTiles([const TerrainTileCoordinate(x: 3, y: 2)]),
        isTrue,
      );
      expect(terrain.commitBrushStroke(), isTrue);
      final after = bytes();
      expect(after, isNot(equals(before)));
      expect(terrain.undo(), isTrue);
      expect(bytes(), before);
      expect(terrain.redo(), isTrue);
      expect(bytes(), after);
    },
    skip: !Platform.isWindows || realInstallation == null || realHelper == null
        ? 'Set local StarCraft installation and helper paths.'
        : false,
  );
  for (final kind in [
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.pureSprite,
  ]) {
    test(
      'local $kind catalog places and restores exact CHK bytes',
      () async {
        final fixture = await _openFixture(
          catalogGateway: ProcessStarCraftPlacementCatalogGateway(
            helperExecutablePath: realHelper!,
          ),
          objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
            helperExecutablePath: realHelper,
          ),
        );
        addTearDown(fixture.dispose);
        fixture.controller.setInstallationPath(realInstallation);
        Uint8List bytes() => const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        );
        final before = bytes();
        expect(await fixture.controller.load(kind), isTrue);
        final item = fixture.controller.state.items.firstWhere(
          (item) => item.isPlaceable,
        );
        expect(item.hasThumbnail, isTrue);
        expect(
          item.thumbnailRgba!.length,
          item.thumbnailWidth * item.thumbnailHeight * 4,
        );
        expect(fixture.controller.confirm(item.key), isTrue);
        expect(
          bytes(),
          before,
          reason: 'catalog browsing must not edit the map',
        );
        final placed = fixture.controller.placeAt(
          pixelX: 96,
          pixelY: 64,
          tileX: 3,
          tileY: 2,
        );
        expect(placed.isPlaced, isTrue, reason: placed.issueCode);
        final session = fixture.openMapController.state.session!;
        if (kind == StarCraftPlacementKind.unit) {
          final unit = session.objectViews.unitSections.single.units.single;
          expect(unit.unitType, item.key.id);
          expect((unit.x, unit.y), (96, 64));
          expect(unit.hitpointPercent, 100);
        } else {
          final sprite =
              session.objectViews.spriteSections.single.sprites.single;
          expect(sprite.spriteType, item.key.id);
          expect((sprite.x, sprite.y), (96, 64));
          expect(sprite.drawsAsSprite, isTrue);
        }
        final after = bytes();
        expect(after, isNot(equals(before)));
        expect(fixture.objectEditingController.undo(), isTrue);
        expect(bytes(), before);
        expect(fixture.objectEditingController.redo(), isTrue);
        expect(bytes(), after);
        expect(fixture.objectEditingController.undo(), isTrue);
        expect(bytes(), before);
      },
      skip:
          !Platform.isWindows || realInstallation == null || realHelper == null
          ? 'Set local StarCraft installation and helper paths.'
          : false,
    );
  }
  test(
    'local installation supplies a unit preview and linked weapons',
    () async {
      final fixture = await _openFixture(
        catalogGateway: ProcessStarCraftPlacementCatalogGateway(
          helperExecutablePath: realHelper!,
        ),
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: realHelper,
        ),
      );
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(realInstallation);
      final preview = await fixture.controller.loadUnitPreview(0);
      expect(preview?.hasThumbnail, isTrue);
      final references = await fixture.controller.loadWeaponReferences();
      expect(references.index.preferredWeapon(0), isNotNull);
    },
    skip: realInstallation == null || realHelper == null
        ? 'Set local StarCraft installation and helper paths.'
        : false,
  );
  test(
    'unit preview does not change the placement catalog selection',
    () async {
      final fixture = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      final before = fixture.controller.state;
      final item = await fixture.controller.loadUnitPreview(0);
      expect(item?.key.id, 0);
      expect(item?.hasThumbnail, isTrue);
      expect(identical(fixture.controller.state, before), isTrue);
      fixture.controller.setInstallationPath(null);
      expect(await fixture.controller.loadUnitPreview(0), isNull);
    },
  );
  test(
    'loads complete local weapon references and rejects missing coverage',
    () async {
      final fixture = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      final snapshot = await fixture.controller.loadWeaponReferences();
      expect(snapshot.index.directUsers(7), [0]);
      expect(snapshot.index.subunitUsers(7), [1]);
      expect(snapshot.source, contains('13515'));
      final absent = await _openFixture();
      addTearDown(absent.dispose);
      absent.controller.setInstallationPath(_installationPath);
      await expectLater(
        absent.controller.loadWeaponReferences(),
        throwsStateError,
      );
    },
  );
  test(
    'discards weapon references after installation changes or disposal',
    () async {
      for (final dispose in [false, true]) {
        final gateway = _DeferredCatalogGateway();
        final fixture = await _openFixture(catalogGateway: gateway);
        fixture.controller.setInstallationPath(_installationPath);
        final pending = fixture.controller.loadWeaponReferences();
        final expectation = expectLater(pending, throwsStateError);
        if (dispose) {
          await fixture.dispose();
        } else {
          fixture.controller.setInstallationPath(r'C:\Other');
        }
        gateway.complete();
        await expectation;
        if (!dispose) await fixture.dispose();
      }
    },
  );
  testWidgets(
    'weapon panel updates selection and invalidates old installation results',
    (tester) async {
      final fixture = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      Widget panel(int weapon) => MaterialApp(
        home: Scaffold(
          body: WeaponImpactPanel(
            controller: fixture.controller,
            weapon: weapon,
          ),
        ),
      );
      await tester.pumpWidget(panel(7));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('weapon-direct-users'))).data,
        contains('Unit #0'),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('weapon-subunit-users'))).data,
        contains('Unit #1'),
      );
      await tester.pumpWidget(panel(8));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('weapon-direct-users'))).data,
        contains('None in this DAT snapshot'),
      );
      fixture.controller.setInstallationPath(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weapon-direct-users')), findsNothing);
      expect(
        find.textContaining('Choose a StarCraft installation'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('invalidates cached choices when the installation changes', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller.confirm(fixture.controller.state.items.first.key);
    fixture.controller.setInstallationPath(r'C:\OtherStarCraft');
    expect(fixture.controller.state.items, isEmpty);
    expect(fixture.controller.state.selection, isNull);
    expect(await fixture.controller.loadMore(), isFalse);
  });

  test('reopening even the same map invalidates a pending catalog', () async {
    final gateway = _DeferredCatalogGateway();
    final fixture = await _openFixture(catalogGateway: gateway);
    addTearDown(fixture.dispose);
    fixture.controller.synchronizeSession(
      fixture.openMapController.state.session,
    );
    fixture.controller.setInstallationPath(_installationPath);
    final pending = fixture.controller.load(StarCraftPlacementKind.doodad);
    final state = await fixture.openMapController.open(
      sourcePath: r'C:\Maps\Catalog.scx',
    );
    // A newly opened map has its own extracted snapshot, even at the same path.
    fixture.controller.synchronizeSession(state.session);
    gateway.complete();
    expect(await pending, isFalse);
    expect(fixture.controller.state.items, isEmpty);
    expect(fixture.controller.state.isLoading, isFalse);
  });

  test('pending catalog completion after disposal is ignored', () async {
    final gateway = _DeferredCatalogGateway();
    final fixture = await _openFixture(catalogGateway: gateway);
    fixture.controller.setInstallationPath(_installationPath);
    final pending = fixture.controller.load(StarCraftPlacementKind.doodad);
    await fixture.dispose();
    gateway.complete();
    expect(await pending, isFalse);
  });

  test('refuses to browse without an installation path', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);

    expect(
      await fixture.controller.load(StarCraftPlacementKind.doodad),
      isFalse,
    );
    expect(
      fixture.controller.state.diagnostics.single.code,
      PlacementCatalogDiagnosticCodes.installationMissing,
    );
    expect(fixture.controller.state.items, isEmpty);
  });

  test(
    'loads a Doodad page and keeps browsing free of document changes',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      expect(
        await fixture.controller.load(StarCraftPlacementKind.doodad),
        isTrue,
      );

      final state = fixture.controller.state;
      expect(state.kind, StarCraftPlacementKind.doodad);
      expect(state.items, hasLength(2));
      expect(state.tileset, StarCraftTilesetAssetSet.jungle);
      expect(state.items.first.isPlaceable, isTrue);
      expect(state.items.last.isPlaceable, isFalse);
      expect(
        state.items.last.issueCode,
        'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
      );

      fixture.controller.preview(state.items.first.key);
      expect(fixture.controller.state.previewItem?.key, state.items.first.key);
      expect(fixture.openMapController.state.session!.isDirty, isFalse);
      expect(fixture.objectEditingController.state.undoDepth, 0);
    },
  );

  test('filters by display name and numeric id', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);

    fixture.controller.setQuery('#7');
    expect(fixture.controller.state.visibleItems, hasLength(1));
    expect(fixture.controller.state.visibleItems.single.key.id, 7);

    fixture.controller.setQuery('jungle tree');
    expect(fixture.controller.state.visibleItems, hasLength(1));
    expect(fixture.controller.state.visibleItems.single.key.id, 7);

    fixture.controller.setQuery('');
    expect(fixture.controller.state.visibleItems, hasLength(2));
  });

  test('refuses to confirm an unplaceable entry', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    final broken = fixture.controller.state.items.last;

    expect(fixture.controller.confirm(broken.key), isFalse);
    expect(fixture.controller.state.selection, isNull);
    expect(
      fixture.controller.state.lastPlacementIssueCode,
      'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
    );
  });

  test('places a confirmed Doodad centred on the clicked tile', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    final entry = fixture.controller.state.items.first;

    expect(fixture.controller.confirm(entry.key), isTrue);
    expect(fixture.controller.state.isPlacementActive, isTrue);
    expect(fixture.controller.state.recentKeys, [entry.key]);

    final result = fixture.controller.placeAt(
      pixelX: 3 * 32 + 16,
      pixelY: 2 * 32 + 16,
      tileX: 3,
      tileY: 2,
    );

    expect(result.isPlaced, isTrue);
    final session = fixture.openMapController.state.session!;
    expect(
      session.objectViews.doodadSections.single.doodads.last.doodadType,
      7,
    );
    final tiles = session.terrainViews.tileMaps.single.rawTileValues;
    // A two tile wide footprint centred on tile 3 starts at tile 2.
    expect(tiles[2 * 8 + 2], 200 * 16);
    expect(tiles[2 * 8 + 3], 200 * 16 + 1);
    expect(fixture.controller.state.selection, isNull, reason: 'single place');
  });

  test('keeps the selection while continuous placement is on', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller
      ..setContinuous(true)
      ..confirm(fixture.controller.state.items.first.key);

    expect(
      fixture.controller
          .placeAt(pixelX: 112, pixelY: 80, tileX: 3, tileY: 2)
          .isPlaced,
      isTrue,
    );
    expect(fixture.controller.state.selection, isNotNull);

    expect(
      fixture.controller
          .placeAt(pixelX: 176, pixelY: 144, tileX: 5, tileY: 4)
          .isPlaced,
      isTrue,
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
      hasLength(3),
    );

    fixture.controller.cancelSelection();
    expect(fixture.controller.state.selection, isNull);
  });

  test('reports a refusal without changing the document', () async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    fixture.controller.confirm(fixture.controller.state.items.first.key);

    final result = fixture.controller.placeAt(
      pixelX: 0,
      pixelY: 0,
      tileX: 0,
      tileY: 0,
    );

    expect(result.isPlaced, isFalse);
    expect(result.issueCode, ObjectPlacementDiagnosticCodes.outOfBounds);
    expect(
      fixture.controller.state.lastPlacementIssueCode,
      ObjectPlacementDiagnosticCodes.outOfBounds,
    );
    expect(fixture.openMapController.state.session!.isDirty, isFalse);
  });

  test(
    'confirming a Tile arms the terrain brush instead of the cursor',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      expect(
        await fixture.controller.load(StarCraftPlacementKind.tile),
        isTrue,
      );
      final tile = fixture.controller.state.items.single;
      expect(tile.hasThumbnail, isTrue);

      expect(fixture.controller.confirm(tile.key), isTrue);
      expect(fixture.controller.state.isPlacementActive, isFalse);
      expect(
        fixture.terrainEditingController.state.selectedRawTileValue,
        tile.key.id,
      );
      expect(
        fixture.terrainEditingController.state.tool,
        TerrainEditingTool.brush,
      );
    },
  );

  test('places a Unit once the helper reports its capability', () async {
    final fixture = await _openFixture(unitCapabilityAvailable: true);
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.unit);

    final unit = fixture.controller.state.items.single;
    expect(unit.isPlaceable, isTrue);
    expect(unit.displayName, 'Terran Marine');
    expect(fixture.controller.confirm(unit.key), isTrue);

    final result = fixture.controller.placeAt(
      pixelX: 96,
      pixelY: 64,
      tileX: 3,
      tileY: 2,
    );

    expect(result.isPlaced, isTrue);
    final placed = fixture
        .openMapController
        .state
        .session!
        .objectViews
        .unitSections
        .single
        .units
        .single;
    expect(placed.unitType, unit.key.id);
    expect(placed.x, 96);
    expect(placed.y, 64);
    expect(placed.hitpointPercent, 100);
  });

  test(
    'keeps Unit entries visible but unplaceable until capability lands',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);

      await fixture.controller.load(StarCraftPlacementKind.unit);
      final unit = fixture.controller.state.items.single;

      expect(unit.isPlaceable, isFalse);
      expect(unit.issueCode, 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE');
      expect(fixture.controller.confirm(unit.key), isFalse);
    },
  );

  test('appends the next page when the grid asks for more', () async {
    final fixture = await _openFixture(doodadTotal: 4);
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    await fixture.controller.load(StarCraftPlacementKind.doodad);

    expect(fixture.controller.state.items, hasLength(2));
    expect(fixture.controller.state.hasMore, isTrue);

    expect(await fixture.controller.loadMore(), isTrue);
    expect(fixture.controller.state.items, hasLength(4));
    expect(fixture.controller.state.hasMore, isFalse);
    expect(await fixture.controller.loadMore(), isFalse);
  });
}

final class _Fixture {
  const _Fixture({
    required this.openMapController,
    required this.mapLayerController,
    required this.objectEditingController,
    required this.terrainEditingController,
    required this.controller,
    required this.progressController,
  });

  final OpenMapController openMapController;
  final MapLayerController mapLayerController;
  final ObjectEditingController objectEditingController;
  final TerrainEditingController terrainEditingController;
  final PlacementCatalogController controller;
  final OperationProgressController progressController;

  Future<void> dispose() async {
    await controller.dispose();
    await objectEditingController.dispose();
    await terrainEditingController.dispose();
    await mapLayerController.dispose();
    await openMapController.dispose();
    await progressController.dispose();
  }
}

Future<_Fixture> _openFixture({
  int doodadTotal = 2,
  bool unitCapabilityAvailable = false,
  StarCraftPlacementCatalogGateway? catalogGateway,
  StarCraftObjectAtlasGateway? objectAtlasGateway,
  StarCraftTileAtlasGateway? tileAtlasGateway,
  Uint8List? chkBytesOverride,
  int pageSize = 2,
}) async {
  final chkBytes = chkBytesOverride ?? _chkBytes();
  final map = ExtractedMap(
    sourcePath: r'C:\Maps\Catalog.scx',
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
    openMapController: openMapController,
    mapLayerController: mapLayerController,
  )..synchronizeSession(state.session);
  final terrainEditingController = TerrainEditingController(
    openMapController: openMapController,
  )..synchronizeSession(state.session);
  final gateway = _FakeCatalogGateway(
    doodadTotal: doodadTotal,
    unitCapabilityAvailable: unitCapabilityAvailable,
  );
  final controller = PlacementCatalogController(
    openMapController: openMapController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    catalogGateway: catalogGateway ?? gateway,
    tileAtlasGateway: tileAtlasGateway ?? const _FakeTileAtlasGateway(),
    objectAtlasGateway: objectAtlasGateway ?? const _FakeObjectAtlasGateway(),
    pageSize: pageSize,
  );
  return _Fixture(
    openMapController: openMapController,
    mapLayerController: mapLayerController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    controller: controller,
    progressController: progressController,
  );
}

DoodadPlacementRecipe _recipe({int doodadType = 7, int startTileGroup = 200}) =>
    DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.jungle,
      startTileGroup: startTileGroup,
      doodadType: doodadType,
      width: 2,
      height: 1,
      centerOffsetX: 32,
      centerOffsetY: 16,
      footprint: [
        DoodadFootprintCell(
          x: 0,
          y: 0,
          rawTileValue: startTileGroup * 16,
          requiredTileGroup: 0,
        ),
        DoodadFootprintCell(
          x: 1,
          y: 0,
          rawTileValue: startTileGroup * 16 + 1,
          requiredTileGroup: 0,
        ),
      ],
    );

final class _DeferredCatalogGateway
    implements StarCraftPlacementCatalogGateway {
  final result = Completer<StarCraftPlacementCatalogPage>();
  late StarCraftPlacementCatalogRequest request;

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest value,
  ) {
    request = value;
    return result.future;
  }

  void complete() => result.complete(
    StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 0,
      entries: const [],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.8.0',
      cascLibRevision: 'abc',
    ),
  );

  @override
  Future<void> cancel(String operationId) async {}
}

final class _FakeCatalogGateway implements StarCraftPlacementCatalogGateway {
  _FakeCatalogGateway({
    required this.doodadTotal,
    required this.unitCapabilityAvailable,
  });

  final int doodadTotal;
  final bool unitCapabilityAvailable;

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    final entries = <StarCraftPlacementCatalogEntry>[];
    final total = request.unitMetadataOnly
        ? 228
        : switch (request.kind) {
            StarCraftPlacementKind.doodad => doodadTotal,
            _ => 1,
          };
    for (
      var index = request.offset;
      index < total && entries.length < request.limit;
      index++
    ) {
      entries.add(_entry(request.kind, request.tileset, index));
    }
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: total,
      entries: entries,
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.7.0',
      cascLibRevision: 'abc',
    );
  }

  @override
  Future<void> cancel(String operationId) async {}

  StarCraftPlacementCatalogEntry _entry(
    StarCraftPlacementKind kind,
    StarCraftTilesetAssetSet tileset,
    int index,
  ) {
    switch (kind) {
      case StarCraftPlacementKind.doodad:
        final broken = index == 1;
        final doodadId = index == 0 ? 7 : 100 + index;
        final startTileGroup = 200 + index;
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.doodad(
            tileset: tileset,
            doodadId: doodadId,
            startTileGroup: startTileGroup,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: broken
              ? StarCraftPlacementAvailability.unsupported
              : StarCraftPlacementAvailability.placeable,
          verifiedName: broken ? null : 'Jungle Tree',
          issue: broken
              ? StarCraftPlacementCatalogIssue(
                  code: 'SC_CATALOG_ITEM_DOODAD_RECIPE_INVALID',
                  message: 'The local Doodad recipe is invalid.',
                )
              : null,
          doodadRecipe: broken
              ? null
              : _recipe(doodadType: doodadId, startTileGroup: startTileGroup),
          doodadRecipeIssueCode: broken ? 'SC_CASC_DOODAD_TRUNCATED' : null,
        );
      case StarCraftPlacementKind.tile:
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.tile(
            tileset: tileset,
            rawValue: 3200 + index,
          ),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
        );
      case StarCraftPlacementKind.unit:
        if (unitCapabilityAvailable) {
          return StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.unit(index),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
            verifiedName: 'Terran Marine',
            unitCapability: UnitPlacementCapability(
              unitId: index,
              weaponReferences: UnitWeaponReferences(
                ground: index == 0 ? 7 : 130,
                air: 130,
                subunit1: index == 1 ? 0 : 228,
                subunit2: 228,
              ),
              isSpellcaster: false,
              hasShields: false,
              isResourceContainer: false,
              isGasResourceContainer: false,
              hasHangar: false,
              isFlyingBuilding: false,
              isBurrowable: false,
              isCloakable: false,
              isInvincible: false,
              isBuilding: false,
              requiresRelationLink: false,
            ),
          );
        }
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.unit(index),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
            message: 'Verified unit capability data is unavailable.',
          ),
          previewIssueCode: 'SC_CASC_OBJECT_PREVIEW_UNAVAILABLE',
        );
      case StarCraftPlacementKind.pureSprite:
      case StarCraftPlacementKind.spriteUnit:
        return StarCraftPlacementCatalogEntry(
          key: StarCraftPlacementCatalogKey.pureSprite(index),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.placeable,
        );
    }
  }
}

final class _FakeTileAtlasGateway implements StarCraftTileAtlasGateway {
  const _FakeTileAtlasGateway();

  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    final count = request.rawValues.length;
    return StarCraftTileAtlasResult(
      request: request,
      tileSize: StarCraftTileAtlasResult.expectedTileSize,
      columns: count,
      rows: count == 0 ? 0 : 1,
      rawValues: request.rawValues,
      rgbaBytes: Uint8List(
        count *
            StarCraftTileAtlasResult.expectedTileSize *
            StarCraftTileAtlasResult.expectedTileSize *
            StarCraftTileAtlasResult.bytesPerPixel,
      ),
      unsupportedRawValues: const [],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.7.0',
      cascLibRevision: 'abc',
    );
  }
}

final class _FakeObjectAtlasGateway implements StarCraftObjectAtlasGateway {
  const _FakeObjectAtlasGateway();

  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) async => StarCraftObjectAtlasResult(
    request: request,
    entries: [
      for (final key in request.objects)
        StarCraftObjectAtlasEntry(
          key: key,
          spriteId: key.id,
          imageId: key.id,
          width: 2,
          height: 2,
          anchorX: 1,
          anchorY: 1,
          frameIndex: StarCraftObjectPreviewPolicy.framePolicy.frameIndex,
          rgbaBytes: Uint8List(2 * 2 * 4),
        ),
    ],
    unsupportedObjects: const [],
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.7.0',
    cascLibRevision: 'abc',
  );

  @override
  Future<void> cancel(String operationId) async {}
}

Uint8List _chkBytes({int mapSize = 8, Uint8List? terrainBytes}) {
  final locations = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  final builder = BytesBuilder(copy: false);
  for (final section in [
    _section('TYPE', [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', [206, 0]),
    _section('IVER', [10, 0]),
    _section('DIM ', [mapSize, 0, mapSize, 0]),
    _section('ERA ', [4, 0]),
    _section('MTXM', terrainBytes ?? Uint8List(mapSize * mapSize * 2)),
    _section('DD2 ', Uint8List(ChkDoodadPlacement.recordLength)),
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
      MapArchiveOpenResult.success(
        map: ExtractedMap(
          sourcePath: request.sourcePath,
          scenarioChkBytes: map.scenarioChkBytes,
          metadata: map.metadata,
        ),
      );

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
