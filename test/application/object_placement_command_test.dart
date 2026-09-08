import 'dart:convert';
import 'dart:typed_data';

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
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
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

UnitPlacementCapability _capability(
  int unitId, {
  bool requiresRelationLink = false,
}) => UnitPlacementCapability(
  unitId: unitId,
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

Future<_Fixture> _openFixture({
  bool includeUnits = true,
  bool includeSprites = true,
  bool includeDoodads = true,
  bool duplicateUnits = false,
}) async {
  final chkBytes = _chkBytes(
    includeUnits: includeUnits,
    includeSprites: includeSprites,
    includeDoodads: includeDoodads,
    duplicateUnits: duplicateUnits,
  );
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
