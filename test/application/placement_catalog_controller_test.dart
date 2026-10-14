import 'package:flutter/material.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_catalog_pane.dart';
import 'package:starcraft_map_editor/presentation/settings/weapon_impact_panel.dart';
import 'package:starcraft_map_editor/application/placement/catalog_thumbnail_pixels.dart';
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
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
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
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_resource_distance_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_policy.dart';
import 'package:starcraft_map_editor/application/placement/placement_policy_support.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import 'package:starcraft_map_editor/application/ports/terrain_placement_snapshot_gateway.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_alignment_toolbar.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

const _installationPath = r'C:\StarCraft';

final _terrainProfile = UnitCollisionProfile(
  left: 0,
  up: 0,
  right: 0,
  down: 0,
  isFlyer: false,
);

final class _TerrainPlacementGateway
    implements TerrainPlacementSnapshotGateway {
  _TerrainPlacementGateway({
    this.failure,
    this.hold = false,
    this.mask = 65535,
  });
  String? failure;
  final bool hold;
  final int mask;
  int calls = 0;
  final release = Completer<void>();
  final cancelled = <String>[];
  @override
  Future<TerrainPlacementReadResult> readPlacement({
    required String operationId,
    required String installationPath,
    required int tileset,
  }) {
    calls++;
    if (failure == 'sync') throw StateError('Synthetic synchronous failure');
    return () async {
      if (hold) await release.future;
      if (failure == 'throw') throw StateError('Synthetic failure');
      return TerrainPlacementReadResult(
        source: TerrainPlacementSource(
          snapshot: TerrainPlacementSnapshot(
            tileset: failure == 'tileset' ? 0 : tileset,
            groupBuildable: [true],
            megaTileReferences: [List.filled(16, 0)],
            walkableMasks: [failure == 'walk' ? 0 : mask],
          ),
          revision: 'synthetic-v1',
          helperVersion: '0.7.0',
          cascLibRevision: 'abc',
          storageProduct: 's1',
          storageBuildNumber: failure == 'source' ? 9 : 13515,
          assets: [],
        ),
      );
    }();
  }

  @override
  void cancel(String operationId) => cancelled.add(operationId);
}

void main() {
  test(
    'resource inspection coalesces metadata and reads latest UNIT/Undo without writes',
    () async {
      final gateway = _ResourceGateway(hold: true);
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.metadataUnavailable,
      );
      final pending = c.loadCollisionMetadata();
      expect(c.loadCollisionMetadata(), same(pending));
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.metadataUnavailable,
      );
      gateway.release.complete();
      expect(await pending, isTrue);
      for (var i = 0; i < 10; i++) {
        final before = f.openMapController.state.session!;
        final state = c.state;
        final result = c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64);
        expect(result.check, UnitResourceDistanceCatalogCheck.clear);
        expect(result.point, (x: 64, y: 64));
        expect(result.issueCode, isNull);
        expect(f.openMapController.state.session, same(before));
        expect(c.state, same(state));
        expect(f.objectEditingController.state.undoDepth, 0);
      }
      expect(
        f.objectEditingController
            .placeCatalogUnit(
              capability: gateway.capability(1),
              unitId: 1,
              owner: 0,
              pixelX: 96,
              pixelY: 64,
            )
            .isPlaced,
        isTrue,
      );
      final placed = f.openMapController.state.session!;
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.tooClose,
      );
      expect(f.openMapController.state.session, same(placed));
      expect(f.objectEditingController.state.undoDepth, 1);
      expect(f.objectEditingController.undo(), isTrue);
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.clear,
      );
      expect(f.objectEditingController.redo(), isTrue);
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.tooClose,
      );
      expect(gateway.metadataRequests, 1);
      // No checkbox or placement enforcement is silently enabled in this stage.
      expect(c.state.allowUnitOverlap, isTrue);
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
        PlacementPolicySupportStatus.notImplemented,
      );
    },
  );
  for (final alignment in ['point', 'building']) {
    test('resource inspection uses final $alignment position', () async {
      final gateway = _ResourceGateway(building: alignment == 'building');
      final f = await _openFixture(
        catalogGateway: gateway,
        chkBytesOverride: Uint8List.fromList([
          ..._chkBytes(),
          ..._section(
            'UNIT',
            const UnitPlacementFactory()
                .create(
                  capability: gateway.capability(1),
                  unitId: 1,
                  owner: 0,
                  x: 191,
                  y: 64,
                  classId: 1,
                )
                .bytes,
          ),
        ]),
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      await c.loadCollisionMetadata();
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 63, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.clear,
      );
      c.setPointSnap(enabled: true, step: 32);
      c.setBuildingTileAlignment(alignment == 'building');
      final result = c.inspectUnitResourceDistanceAt(pixelX: 63, pixelY: 64);
      expect(result.point, (x: 64, y: 64));
      expect(result.check, UnitResourceDistanceCatalogCheck.tooClose);
      expect(f.objectEditingController.state.undoDepth, 0);
    });
  }
  test(
    'resource inspection retains raw/final bounds and locked-layer guards',
    () async {
      final gateway = _ResourceGateway();
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      await c.loadCollisionMetadata();
      c.setPointSnap(enabled: true, step: 32);
      final before = f.openMapController.state.session!;
      for (final x in [-1, 255, 256]) {
        final result = c.inspectUnitResourceDistanceAt(pixelX: x, pixelY: 64);
        expect(result.issueCode, ObjectPlacementDiagnosticCodes.outOfBounds);
        expect(result.check, isNull);
        expect(result.point, isNull);
      }
      f.mapLayerController.setLocked(MapLayerType.units, true);
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).issueCode,
        ObjectPlacementDiagnosticCodes.layerLocked,
      );
      expect(f.openMapController.state.session, same(before));
      expect(f.objectEditingController.state.undoDepth, 0);
    },
  );
  test(
    'resource inspection does not inherit optional terrain or overlap refusal',
    () async {
      final gateway = _ResourceGateway();
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      await c.loadCollisionMetadata();
      c.setAllowUnitOverlap(false);
      c.setCheckUnitTerrain(true);
      expect(
        c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
        ObjectPlacementDiagnosticCodes.unitTerrainUnavailable,
      );
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.clear,
      );
    },
  );
  for (final failure in ['source', 'coverage', 'geometry', 'role']) {
    test(
      'resource metadata $failure remains unknown and explicit reload recovers',
      () async {
        final gateway = _ResourceGateway(failure: failure);
        final f = await _openFixture(catalogGateway: gateway);
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        await c.loadCollisionMetadata();
        expect(
          c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
          UnitResourceDistanceCatalogCheck.metadataUnavailable,
        );
        gateway.failure = null;
        expect(await c.loadCollisionMetadata(reload: true), isTrue);
        expect(
          c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
          UnitResourceDistanceCatalogCheck.clear,
        );
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  for (final change in ['installation', 'session', 'dispose']) {
    test('resource snapshot discards pending data after $change', () async {
      final gateway = _ResourceGateway(hold: true);
      final f = await _openFixture(catalogGateway: gateway);
      final c = f.controller..setInstallationPath(_installationPath);
      c.synchronizeSession(f.openMapController.state.session);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      final pending = c.loadCollisionMetadata();
      if (change == 'installation') c.setInstallationPath(r'C:\Other');
      if (change == 'session') c.synchronizeSession(null);
      if (change == 'dispose') await f.dispose();
      gateway.release.complete();
      expect(await pending, isFalse);
      expect(gateway.cancelled, hasLength(1));
      expect(c.lastCollisionMetadataPage, isNull);
      if (change != 'dispose') {
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        expect(
          c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
          UnitResourceDistanceCatalogCheck.metadataUnavailable,
        );
        await f.dispose();
      }
    });
  }
  test(
    'legacy helper without resource roles is unknown, never nonparticipant',
    () async {
      final f = await _openFixture(catalogGateway: _CollisionGateway());
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      await c.loadCollisionMetadata();
      expect(
        c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
        UnitResourceDistanceCatalogCheck.metadataUnavailable,
      );
    },
  );
  for (final kind in [
    StarCraftPlacementKind.tile,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test(
      '$kind resource inspection is not applicable and starts no process',
      () async {
        final f = await _openFixture(unitCapabilityAvailable: true);
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        expect(
          c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64).check,
          UnitResourceDistanceCatalogCheck.notApplicable,
        );
        await c.load(kind);
        c.confirm(c.state.items.first.key);
        final state = c.state;
        final result = c.inspectUnitResourceDistanceAt(pixelX: 64, pixelY: 64);
        expect(result.check, UnitResourceDistanceCatalogCheck.notApplicable);
        expect(result.point, isNull);
        expect(result.issueCode, isNull);
        expect(c.state, same(state));
        expect(c.lastCollisionMetadataPage, isNull);
      },
    );
  }
  test(
    'UNIT presets atomically configure checks and preserve document and unrelated preferences',
    () async {
      final terrain = _TerrainPlacementGateway(hold: true);
      final collision = _CollisionGateway(hold: true);
      final f = await _openFixture(
        terrainPlacementGateway: terrain,
        catalogGateway: collision,
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setBuildingTileAlignment(true);
      c.setPointSnap(enabled: true, step: 17);
      c.setGridVisible(false);
      c.setGridSpacing(128);
      c.setOwner(4);
      c.setContinuous(true);
      final before = f.openMapController.state.session;
      final selection = c.state.selection;
      final states = <PlacementCatalogState>[];
      final sub = c.changes.listen(states.add);
      addTearDown(sub.cancel);
      c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
      c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.checked);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.terrain],
        PlacementPolicySupportStatus.loading,
      );
      expect(
        c.placementPolicySupport[PlacementPolicyRule.unitOverlap],
        PlacementPolicySupportStatus.loading,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        states.every((s) => s.checkUnitTerrain && !s.allowUnitOverlap),
        isTrue,
      );
      expect(terrain.calls, 1);
      expect(collision.metadataRequests, 1);
      c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.terrain],
        PlacementPolicySupportStatus.skipped,
      );
      expect(
        c.placementPolicySupport[PlacementPolicyRule.unitOverlap],
        PlacementPolicySupportStatus.skipped,
      );
      terrain.release.complete();
      collision.release.complete();
      await c.loadTerrainPlacement();
      await c.loadCollisionMetadata();
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.free);
      c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.terrain],
        PlacementPolicySupportStatus.enabled,
      );
      expect(
        c.placementPolicySupport[PlacementPolicyRule.unitOverlap],
        PlacementPolicySupportStatus.enabled,
      );
      expect((terrain.calls, collision.metadataRequests), (1, 1));
      expect(identical(f.openMapController.state.session, before), isTrue);
      expect(c.state.selection, same(selection));
      expect(f.objectEditingController.state.undoDepth, 0);
      expect(c.state.alignBuildingsToTiles, isTrue);
      expect(c.state.pointSnap.step, 17);
      expect(c.state.gridVisible, isFalse);
      expect(c.state.gridSpacingPixels, 128);
      expect(c.state.owner, 4);
      expect(c.state.isContinuous, isTrue);
      c.setAllowUnitOverlap(true);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
      c.setCheckUnitTerrain(false);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.free);
      c.setAllowUnitOverlap(false);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
      c.setCheckUnitTerrain(true);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.checked);
    },
  );
  for (final kind in [
    'ground',
    'air',
    'building',
    'building-missing-box',
    'missing-profile',
    'terrain-source',
    'collision-source',
    'no-selection',
    'pure-sprite',
    'unit-sprite',
    'doodad',
  ]) {
    test(
      'UNIT policy support reports $kind without authorizing or mutating a coordinate',
      () async {
        final building = kind.startsWith('building');
        final terrain = _TerrainPlacementGateway(
          failure: kind == 'terrain-source' ? 'source' : null,
        );
        final collision = kind == 'collision-source'
            ? _CollisionGateway(failure: 'changed-source')
            : null;
        final f = await _openFixture(
          terrainPlacementGateway: terrain,
          catalogGateway: collision,
          unitCapabilityAvailable: true,
          unitIsBuilding: building,
          placementBox: kind == 'building'
              ? BuildingPlacementBox(width: 64, height: 32)
              : null,
          collisionProfile: kind == 'missing-profile'
              ? null
              : UnitCollisionProfile(
                  left: 0,
                  up: 0,
                  right: 0,
                  down: 0,
                  isFlyer: kind == 'air',
                ),
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        final selectedKind = switch (kind) {
          'pure-sprite' => StarCraftPlacementKind.pureSprite,
          'unit-sprite' => StarCraftPlacementKind.spriteUnit,
          'doodad' => StarCraftPlacementKind.doodad,
          _ => StarCraftPlacementKind.unit,
        };
        await c.load(selectedKind);
        if (kind != 'no-selection') c.confirm(c.state.items.first.key);
        c.setBuildingTileAlignment(true);
        c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
        await c.loadTerrainPlacement();
        await c.loadCollisionMetadata();
        final before = f.openMapController.state.session;
        final support = c.placementPolicySupport;
        final notUnit = [
          'no-selection',
          'pure-sprite',
          'unit-sprite',
          'doodad',
        ].contains(kind);
        expect(support, hasLength(PlacementPolicyRule.values.length));
        expect(() => support.clear(), throwsUnsupportedError);
        expect(
          support[PlacementPolicyRule.recordSafety],
          PlacementPolicySupportStatus.enforced,
        );
        expect(
          support[PlacementPolicyRule.terrain],
          notUnit || kind == 'air'
              ? PlacementPolicySupportStatus.notApplicable
              : ['missing-profile', 'terrain-source'].contains(kind)
              ? PlacementPolicySupportStatus.unavailable
              : PlacementPolicySupportStatus.enabled,
        );
        expect(
          support[PlacementPolicyRule.unitOverlap],
          notUnit
              ? PlacementPolicySupportStatus.notApplicable
              : ['missing-profile', 'collision-source'].contains(kind)
              ? PlacementPolicySupportStatus.unavailable
              : PlacementPolicySupportStatus.enabled,
        );
        expect(
          support[PlacementPolicyRule.buildingAlignment],
          !building
              ? PlacementPolicySupportStatus.notApplicable
              : kind == 'building-missing-box'
              ? PlacementPolicySupportStatus.unavailable
              : PlacementPolicySupportStatus.enabled,
        );
        expect(
          support[PlacementPolicyRule.power],
          building
              ? PlacementPolicySupportStatus.notImplemented
              : PlacementPolicySupportStatus.notApplicable,
        );
        expect(
          support[PlacementPolicyRule.creep],
          support[PlacementPolicyRule.power],
        );
        expect(
          support[PlacementPolicyRule.eudRuntime],
          notUnit
              ? PlacementPolicySupportStatus.notApplicable
              : PlacementPolicySupportStatus.notImplemented,
        );
        expect(
          support[PlacementPolicyRule.gameAcceptance],
          PlacementPolicySupportStatus.acceptancePending,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  test(
    'same map ERA change invalidates terrain cache and reloads selected UNIT',
    () async {
      final gateway = _TerrainPlacementGateway();
      final f = await _openFixture(
        terrainPlacementGateway: gateway,
        unitCapabilityAvailable: true,
        collisionProfile: _terrainProfile,
      );
      addTearDown(f.dispose);
      final c = f.controller;
      c.synchronizeSession(f.openMapController.state.session);
      c.setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setCheckUnitTerrain(true);
      await c.loadTerrainPlacement();
      final before = f.openMapController.state.session!;
      final document = const RawChkParser()
          .parse(
            Uint8List.fromList(
              before.rawDocument.sections
                  .expand(
                    (s) =>
                        _section(s.name, s.name == 'ERA ' ? [0, 0] : s.payload),
                  )
                  .toList(),
            ),
          )
          .document!;
      final edited = OpenedMapSession(
        extractedMap: before.extractedMap,
        rawDocument: document,
        metadataViews: const ChkMetadataViewDecoder().decode(document),
        terrainViews: before.terrainViews,
        objectViews: before.objectViews,
        stringViews: before.stringViews,
        sourceFingerprint: before.sourceFingerprint,
        diagnostics: before.diagnostics,
      );
      f.openMapController.adoptEditedSession(edited);
      expect(
        c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
        ObjectPlacementDiagnosticCodes.unitTerrainUnavailable,
      );
      c.synchronizeSession(edited);
      await c.loadTerrainPlacement();
      expect(gateway.calls, 2);
      expect(c.state.selection, isNotNull);
      expect(c.lastTerrainPlacementRead!.source!.snapshot.tileset, 0);
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
    },
  );
  test(
    'UNIT terrain reads current MTXM after paint and shared Undo/Redo without reread',
    () async {
      final gateway = _TerrainPlacementGateway();
      final f = await _openFixture(
        terrainPlacementGateway: gateway,
        unitCapabilityAvailable: true,
        collisionProfile: _terrainProfile,
      );
      addTearDown(f.dispose);
      final c = f.controller;
      c.synchronizeSession(f.openMapController.state.session);
      c.setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setCheckUnitTerrain(true);
      await c.loadTerrainPlacement();
      String? preview() =>
          c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2);
      expect(preview(), isNull);
      final terrain = f.terrainEditingController;
      expect(terrain.selectCatalogTile(16), isTrue);
      expect(terrain.beginBrushStroke(), isTrue);
      expect(
        terrain.paintTiles([const TerrainTileCoordinate(x: 2, y: 2)]),
        isTrue,
      );
      expect(terrain.commitBrushStroke(), isTrue);
      c.synchronizeSession(f.openMapController.state.session);
      expect(preview(), ObjectPlacementDiagnosticCodes.unitTerrainUnavailable);
      expect(terrain.undo(), isTrue);
      c.synchronizeSession(f.openMapController.state.session);
      expect(preview(), isNull);
      expect(terrain.redo(), isTrue);
      expect(preview(), ObjectPlacementDiagnosticCodes.unitTerrainUnavailable);
      expect(gateway.calls, 1);
    },
  );
  for (final failure in [null, 'walk', 'source', 'tileset', 'throw', 'sync']) {
    test('UNIT terrain checkbox preview/click/retry $failure', () async {
      final gateway = _TerrainPlacementGateway(failure: failure);
      final f = await _openFixture(
        terrainPlacementGateway: gateway,
        unitCapabilityAvailable: true,
        collisionProfile: _terrainProfile,
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setContinuous(true);
      expect(c.state.checkUnitTerrain, isFalse);
      expect(gateway.calls, 0);
      c.setCheckUnitTerrain(true);
      await c.loadTerrainPlacement();
      final before = f.openMapController.state.session;
      final expected = failure == null
          ? null
          : failure == 'walk'
          ? ObjectPlacementDiagnosticCodes.unitTerrainUnwalkable
          : ObjectPlacementDiagnosticCodes.unitTerrainUnavailable;
      for (var i = 0; i < 10; i++) {
        expect(
          c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
          expected,
        );
      }
      expect(gateway.calls, 1);
      expect(identical(f.openMapController.state.session, before), isTrue);
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
        expected,
      );
      if (failure == null) {
        expect(f.objectEditingController.undo(), isTrue);
        expect(f.objectEditingController.redo(), isTrue);
      } else {
        expect(f.objectEditingController.state.undoDepth, 0);
        gateway.failure = null;
        expect(await c.loadTerrainPlacement(reload: true), isTrue);
        expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      }
      c.setCheckUnitTerrain(false);
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
    });
  }
  for (final action in ['reload', 'installation', 'session', 'dispose']) {
    test(
      'terrain read coalesces and rejects obsolete $action completion',
      () async {
        final gateway = _TerrainPlacementGateway(hold: true);
        final f = await _openFixture(terrainPlacementGateway: gateway);
        addTearDown(f.dispose);
        final c = f.controller;
        c.synchronizeSession(f.openMapController.state.session);
        c.setInstallationPath(_installationPath);
        final first = c.loadTerrainPlacement();
        expect(identical(first, c.loadTerrainPlacement()), isTrue);
        expect(c.state.isTerrainPlacementLoading, isTrue);
        if (action == 'reload') {
          unawaited(c.loadTerrainPlacement(reload: true));
        } else if (action == 'installation') {
          c.setInstallationPath(r'C:\Other');
        } else if (action == 'session') {
          c.synchronizeSession(null);
        } else {
          await c.dispose();
        }
        gateway.release.complete();
        expect(await first, isFalse);
        await Future<void>.delayed(Duration.zero);
        expect(gateway.cancelled, hasLength(1));
        expect(c.state.isTerrainPlacementLoading, isFalse);
        expect(
          c.lastTerrainPlacementRead,
          action == 'reload' ? isNotNull : isNull,
        );
      },
    );
  }
  test(
    'terrain policy checks final snapped coordinate, not raw terrain',
    () async {
      final gateway = _TerrainPlacementGateway(mask: 1);
      final f = await _openFixture(
        terrainPlacementGateway: gateway,
        unitCapabilityAvailable: true,
        collisionProfile: _terrainProfile,
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setCheckUnitTerrain(true);
      await c.loadTerrainPlacement();
      c.setPointSnap(enabled: true, step: 32);
      expect(c.previewAt(pixelX: 60, pixelY: 60, tileX: 1, tileY: 1), isNull);
      expect(
        c.placeAt(pixelX: 60, pixelY: 60, tileX: 1, tileY: 1).isPlaced,
        isTrue,
      );
      final unit = f
          .openMapController
          .state
          .session!
          .objectViews
          .unitSections
          .single
          .units
          .single;
      expect((unit.x, unit.y), (64, 64));
    },
  );
  test(
    'synchronous collision gateway failure clears pending state and remains retryable',
    () async {
      final gateway = _SynchronousCollisionFailure();
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      expect(await c.loadCollisionMetadata(), isFalse);
      expect(c.state.isCollisionMetadataLoading, isFalse);
      expect(await c.loadCollisionMetadata(), isFalse);
      expect(gateway.calls, 2);
    },
  );
  test(
    'UNIT overlap checkbox loads one snapshot, refuses current overlap and preserves Undo',
    () async {
      final gateway = _CollisionGateway();
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setContinuous(true);
      c.setAllowUnitOverlap(false);
      expect(await c.loadCollisionMetadata(), isTrue);
      expect(gateway.metadataRequests, 1);
      final before = f.openMapController.state.session!;
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      expect(f.openMapController.state.session, same(before));
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
      final placed = f.openMapController.state.session!;
      expect(
        c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
        ObjectPlacementDiagnosticCodes.unitOverlap,
      );
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
        ObjectPlacementDiagnosticCodes.unitOverlap,
      );
      expect(f.openMapController.state.session, same(placed));
      expect(f.objectEditingController.state.undoDepth, 1);
      expect(f.objectEditingController.undo(), isTrue);
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      expect(f.objectEditingController.redo(), isTrue);
      expect(
        c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
        ObjectPlacementDiagnosticCodes.unitOverlap,
      );
      c.setAllowUnitOverlap(true);
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
      expect(gateway.metadataRequests, 1);
    },
  );

  for (final existingX in [63, 64]) {
    test(
      'point snap checks only final saved center with occupant at $existingX',
      () async {
        final gateway = _CollisionGateway();
        final f = await _openFixture(
          catalogGateway: gateway,
          chkBytesOverride: Uint8List.fromList([
            ..._chkBytes(),
            ..._section(
              'UNIT',
              const UnitPlacementFactory()
                  .create(
                    capability: gateway.capability,
                    unitId: 0,
                    owner: 0,
                    x: existingX,
                    y: 64,
                    classId: 1,
                  )
                  .bytes,
            ),
          ]),
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        c.setAllowUnitOverlap(false);
        await c.loadCollisionMetadata();
        c.setPointSnap(enabled: true, step: 32);
        final before = f.openMapController.state.session!;
        final expected = existingX == 64
            ? ObjectPlacementDiagnosticCodes.unitOverlap
            : null;
        expect(
          c.previewAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2),
          expected,
        );
        expect(
          c.placeAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2).issueCode,
          expected,
        );
        if (expected == null) {
          final unit = f
              .openMapController
              .state
              .session!
              .objectViews
              .unitSections
              .single
              .units
              .last;
          expect((unit.x, unit.y), (64, 64));
        } else {
          expect(f.openMapController.state.session, same(before));
        }
      },
    );
  }

  for (final failure in [
    'coverage',
    'source',
    'changed-source',
    'exception',
    'profile',
  ]) {
    test(
      'collision metadata $failure refuses without mutation and retry is safe',
      () async {
        final gateway = _CollisionGateway(failure: failure);
        final f = await _openFixture(catalogGateway: gateway);
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        final before = f.openMapController.state.session!;
        c.setAllowUnitOverlap(false);
        await c.loadCollisionMetadata();
        expect(c.state.isCollisionMetadataLoading, isFalse);
        expect(
          c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
          ObjectPlacementDiagnosticCodes.collisionUnavailable,
        );
        expect(
          c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
          ObjectPlacementDiagnosticCodes.collisionUnavailable,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
        gateway.failure = null;
        expect(await c.loadCollisionMetadata(reload: true), isTrue);
        // A missing graphic-page profile also requires a fresh catalog selection.
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        await c.loadCollisionMetadata();
        expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      },
    );
  }

  for (final change in ['installation', 'session', 'dispose']) {
    test(
      'pending collision metadata is cancelled and discarded on $change',
      () async {
        final gateway = _CollisionGateway(hold: true);
        final f = await _openFixture(catalogGateway: gateway);
        final c = f.controller..setInstallationPath(_installationPath);
        c.synchronizeSession(f.openMapController.state.session);
        c.setAllowUnitOverlap(false);
        final pending = c.loadCollisionMetadata();
        expect(c.state.isCollisionMetadataLoading, isTrue);
        if (change == 'installation') c.setInstallationPath(r'C:\Other');
        if (change == 'session') c.synchronizeSession(null);
        if (change == 'dispose') await f.dispose();
        gateway.release.complete();
        expect(await pending, isFalse);
        expect(gateway.cancelled, hasLength(1));
        expect(c.lastCollisionMetadataPage, isNull);
        if (change != 'dispose') {
          expect(c.state.allowUnitOverlap, isFalse);
          expect(c.state.isCollisionMetadataLoading, isFalse);
          await f.dispose();
        }
      },
    );
  }

  for (final kind in [
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test('$kind does not inherit UNIT overlap refusal', () async {
      final f = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      c.setAllowUnitOverlap(false);
      await c.loadCollisionMetadata();
      await c.load(kind);
      c.confirm(c.state.items.first.key);
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
    });
  }
  for (final kind in [
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.pureSprite,
  ]) {
    test(
      '$kind tile alignment takes priority only for UNIT buildings',
      () async {
        final f = await _openFixture(
          unitCapabilityAvailable: true,
          unitIsBuilding: true,
          placementBox: BuildingPlacementBox(width: 128, height: 96),
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(kind);
        c.confirm(c.state.items.single.key);
        final before = f.openMapController.state.session!;
        c.setPointSnap(enabled: true, step: 17);
        c.setBuildingTileAlignment(true);
        final expected = kind == StarCraftPlacementKind.unit
            ? (x: 64, y: 48)
            : (x: 68, y: 51);
        expect(c.resolvePoint(63, 47), expected);
        expect(c.previewAt(pixelX: 63, pixelY: 47, tileX: 1, tileY: 1), isNull);
        expect(f.openMapController.state.session, same(before));
        expect(
          c.placeAt(pixelX: 63, pixelY: 47, tileX: 1, tileY: 1).isPlaced,
          isTrue,
        );
        final session = f.openMapController.state.session!;
        final point = kind == StarCraftPlacementKind.unit
            ? (
                x: session.objectViews.unitSections.single.units.last.x,
                y: session.objectViews.unitSections.single.units.last.y,
              )
            : (
                x: session.objectViews.spriteSections.single.sprites.last.x,
                y: session.objectViews.spriteSections.single.sprites.last.y,
              );
        expect(point, expected);
        expect(f.objectEditingController.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          const RawChkEncoder().encode(before.rawDocument),
        );
        await c.load(StarCraftPlacementKind.doodad);
        expect(c.state.alignBuildingsToTiles, isTrue);
        c.setInstallationPath(r'C:\OtherStarCraft');
        expect(c.state.alignBuildingsToTiles, isTrue);
      },
    );
  }
  test(
    'building catalog missing size explains refusal and permits explicit alignment off',
    () async {
      final f = await _openFixture(
        unitCapabilityAvailable: true,
        unitIsBuilding: true,
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      final before = f.openMapController.state.session!;
      c.setBuildingTileAlignment(true);
      expect(
        c.previewAt(pixelX: 63, pixelY: 47, tileX: 1, tileY: 1),
        ObjectPlacementDiagnosticCodes.buildingBoxUnavailable,
      );
      expect(
        c.placeAt(pixelX: 63, pixelY: 47, tileX: 1, tileY: 1).issueCode,
        ObjectPlacementDiagnosticCodes.buildingBoxUnavailable,
      );
      expect(f.openMapController.state.session, same(before));
      expect(c.state.isPlacementActive, isTrue);
      c.setBuildingTileAlignment(false);
      expect(
        c.placeAt(pixelX: 63, pixelY: 47, tileX: 1, tileY: 1).isPlaced,
        isTrue,
      );
    },
  );
  for (final kind in [
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
  ]) {
    test(
      '$kind snap aligns preview and Apply without normalizing the map',
      () async {
        final fixture = await _openFixture(unitCapabilityAvailable: true);
        addTearDown(fixture.dispose);
        final controller = fixture.controller
          ..setInstallationPath(_installationPath);
        await controller.load(kind);
        controller.confirm(controller.state.items.single.key);
        final before = fixture.openMapController.state.session!;
        controller.setPointSnap(enabled: true, step: 16);
        controller.setGridVisible(false);
        controller.setGridSpacing(128);
        expect(fixture.openMapController.state.session, same(before));
        expect(fixture.objectEditingController.state.undoDepth, 0);
        expect(controller.resolvePoint(31, 63), (x: 32, y: 64));
        expect(
          controller.previewAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1),
          isNull,
        );
        expect(fixture.openMapController.state.session, same(before));
        controller.setPointSnap(enabled: true, step: 17);
        expect(controller.resolvePoint(31, 63), (x: 34, y: 68));
        expect(
          controller
              .placeAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1)
              .isPlaced,
          isTrue,
        );
        final session = fixture.openMapController.state.session!;
        final actual = kind == StarCraftPlacementKind.unit
            ? (
                x: session.objectViews.unitSections.single.units.last.x,
                y: session.objectViews.unitSections.single.units.last.y,
              )
            : (
                x: session.objectViews.spriteSections.single.sprites.last.x,
                y: session.objectViews.spriteSections.single.sprites.last.y,
              );
        expect(actual, (x: 34, y: 68));
        expect(fixture.objectEditingController.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          const RawChkEncoder().encode(before.rawDocument),
        );
        expect(fixture.objectEditingController.redo(), isTrue);
        expect(controller.state.pointSnap.step, 17);
        final restored = fixture.openMapController.state.session!;
        controller.confirm(controller.state.items.single.key);
        controller.setPointSnap(enabled: false, step: 17);
        expect(controller.resolvePoint(31, 63), (x: 31, y: 63));
        expect(fixture.openMapController.state.session, same(restored));
      },
    );
    for (final input in [(255, 63), (-1, 63), (256, 63)]) {
      test('$kind snap refuses edge/input $input without changes', () async {
        final fixture = await _openFixture(unitCapabilityAvailable: true);
        addTearDown(fixture.dispose);
        final controller = fixture.controller
          ..setInstallationPath(_installationPath);
        await controller.load(kind);
        controller.confirm(controller.state.items.single.key);
        controller.setPointSnap(enabled: true, step: 32);
        final before = fixture.openMapController.state.session!;
        final issue = controller.previewAt(
          pixelX: input.$1,
          pixelY: input.$2,
          tileX: 0,
          tileY: 1,
        );
        expect(issue, ObjectPlacementDiagnosticCodes.outOfBounds);
        expect(
          controller
              .placeAt(pixelX: input.$1, pixelY: input.$2, tileX: 0, tileY: 1)
              .issueCode,
          issue,
        );
        expect(fixture.openMapController.state.session, same(before));
        expect(controller.state.isPlacementActive, isTrue);
        expect(fixture.objectEditingController.state.undoDepth, 0);
      });
    }
  }
  test(
    'alignment settings validate atomically and survive catalog changes',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final c = fixture.controller..setInstallationPath(_installationPath);
      c.setPointSnap(enabled: true, step: 17);
      c.setGridSpacing(8);
      final before = c.state;
      expect(() => c.setPointSnap(enabled: true, step: 0), throwsRangeError);
      expect(() => c.setGridSpacing(7), throwsArgumentError);
      expect(c.state, same(before));
      await c.load(StarCraftPlacementKind.doodad);
      c.confirm(c.state.items.first.key);
      expect(c.resolvePoint(31, 63), (x: 31, y: 63));
      expect(c.state.pointSnap.step, 17);
      expect(c.state.gridSpacingPixels, 8);
      c.setGridSpacing(null);
      c.setInstallationPath(r'C:\OtherStarCraft');
      c.cancelSelection();
      expect(c.state.gridSpacingPixels, isNull);
      expect(c.state.pointSnap.step, 17);
      expect(c.resolvePoint(31, 63), (x: 31, y: 63));
    },
  );
  for (final locale in ['en', 'ko']) {
    testWidgets(
      'UNIT policy presets and live support dialog $locale at narrow width',
      (tester) async {
        tester.view.physicalSize = const Size(500, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final terrain = _TerrainPlacementGateway(hold: true, failure: 'throw');
        final f = await _openFixture(
          terrainPlacementGateway: terrain,
          unitCapabilityAvailable: true,
          collisionProfile: _terrainProfile,
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        final before = f.openMapController.state.session;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: StreamBuilder(
                    stream: c.changes,
                    builder: (_, _) => PlacementAlignmentToolbar(controller: c),
                  ),
                ),
              ),
            ),
          ),
        );
        final presets = find.byKey(const Key('placement-policy-presets'));
        final checkedLabel = locale == 'ko' ? '검사 배치' : 'Checked';
        final freeLabel = locale == 'ko' ? '자유 배치' : 'Free';
        expect(
          tester.widget<SegmentedButton<UnitPlacementMode>>(presets).selected,
          {UnitPlacementMode.free},
        );
        await tester.tap(
          find.descendant(of: presets, matching: find.text(checkedLabel)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.checked);
        expect(c.state.checkUnitTerrain, isTrue);
        expect(c.state.allowUnitOverlap, isFalse);
        await tester.tap(find.byKey(const Key('placement-policy-support')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final dialog = find.byKey(const Key('placement-policy-dialog'));
        expect(dialog, findsOneWidget);
        final l10n = AppLocalizations.of(tester.element(dialog))!;
        Finder rowText(PlacementPolicyRule rule, String label) =>
            find.descendant(
              of: find.byKey(ValueKey('placement-policy-${rule.name}')),
              matching: find.text(label),
            );
        expect(
          rowText(PlacementPolicyRule.terrain, l10n.placementPolicyLoading),
          findsOneWidget,
        );
        expect(
          rowText(
            PlacementPolicyRule.recordSafety,
            l10n.placementPolicyEnforced,
          ),
          findsOneWidget,
        );
        expect(
          rowText(
            PlacementPolicyRule.eudRuntime,
            l10n.placementPolicyNotImplemented,
          ),
          findsOneWidget,
        );
        expect(
          rowText(
            PlacementPolicyRule.gameAcceptance,
            l10n.placementPolicyAcceptancePending,
          ),
          findsOneWidget,
        );
        terrain.release.complete();
        await c.loadTerrainPlacement();
        await c.loadCollisionMetadata();
        await tester.pumpAndSettle();
        expect(
          rowText(PlacementPolicyRule.terrain, l10n.placementPolicyUnavailable),
          findsOneWidget,
        );
        expect(
          rowText(PlacementPolicyRule.unitOverlap, l10n.placementPolicyEnabled),
          findsOneWidget,
        );
        c.setAllowUnitOverlap(true);
        await tester.pumpAndSettle();
        expect(
          rowText(PlacementPolicyRule.unitOverlap, l10n.placementPolicySkipped),
          findsOneWidget,
        );
        expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
        terrain.failure = null;
        await c.loadTerrainPlacement(reload: true);
        await tester.pumpAndSettle();
        expect(
          rowText(PlacementPolicyRule.terrain, l10n.placementPolicyEnabled),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.editorClose));
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(
          tester.widget<SegmentedButton<UnitPlacementMode>>(presets).selected,
          isEmpty,
        );
        expect(
          find.textContaining(locale == 'ko' ? '사용자 설정' : 'Custom'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: presets, matching: find.text(freeLabel)),
        );
        await tester.pumpAndSettle();
        expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.free);
        expect(c.state.checkUnitTerrain, isFalse);
        expect(c.state.allowUnitOverlap, isTrue);
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'alignment toolbar $locale validates custom spacing at narrow width',
      (tester) async {
        final fixture = await _openFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: StreamBuilder(
                    stream: fixture.controller.changes,
                    builder: (_, _) => PlacementAlignmentToolbar(
                      controller: fixture.controller,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('placement-check-unit-terrain')));
        await tester.pumpAndSettle();
        expect(fixture.controller.state.checkUnitTerrain, isTrue);
        expect(
          find.byKey(const Key('placement-reload-unit-terrain')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('placement-reload-unit-terrain')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('placement-allow-unit-overlap')));
        await tester.pumpAndSettle();
        expect(fixture.controller.state.allowUnitOverlap, isFalse);
        expect(
          find.byKey(const Key('placement-reload-collision')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('placement-building-tile-alignment')),
        );
        await tester.pumpAndSettle();
        expect(fixture.controller.state.alignBuildingsToTiles, isTrue);
        await tester.tap(find.byKey(const Key('placement-grid-visible')));
        await tester.pumpAndSettle();
        expect(fixture.controller.state.gridVisible, isFalse);
        expect(
          tester
              .widget<DropdownButton<int>>(
                find.byKey(const Key('placement-grid-spacing')),
              )
              .onChanged,
          isNull,
        );
        await tester.tap(find.byKey(const Key('placement-point-snap')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('placement-snap-spacing')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(locale == 'ko' ? '직접 간격 입력' : 'Custom spacing').last,
        );
        await tester.pumpAndSettle();
        final input = find.byKey(const Key('placement-custom-snap-input'));
        await tester.enterText(input, '129');
        await tester.tap(find.byKey(const Key('placement-custom-snap-apply')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(fixture.controller.state.pointSnap.step, 32);
        await tester.enterText(input, '17');
        await tester.tap(find.byKey(const Key('placement-custom-snap-apply')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.controller.state.pointSnap.step, 17);
        expect(fixture.openMapController.state.session!.isDirty, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final kind in [
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
  ]) {
    test(
      '$kind catalog hover is read-only and agrees with click after lock changes',
      () async {
        final fixture = await _openFixture(unitCapabilityAvailable: true);
        addTearDown(fixture.dispose);
        final controller = fixture.controller
          ..setInstallationPath(_installationPath);
        await controller.load(kind);
        expect(controller.confirm(controller.state.items.single.key), isTrue);
        final state = controller.state;
        final before = fixture.openMapController.state.session!;
        expect(
          controller.previewAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1),
          isNull,
        );
        expect(controller.state, same(state));
        expect(fixture.openMapController.state.session, same(before));
        expect(
          controller.previewAt(pixelX: 256, pixelY: 63, tileX: 8, tileY: 1),
          ObjectPlacementDiagnosticCodes.outOfBounds,
        );
        final layer = kind == StarCraftPlacementKind.unit
            ? MapLayerType.units
            : MapLayerType.sprites;
        fixture.mapLayerController.setLocked(layer, true);
        final issue = controller.previewAt(
          pixelX: 31,
          pixelY: 63,
          tileX: 0,
          tileY: 1,
        );
        expect(issue, ObjectPlacementDiagnosticCodes.layerLocked);
        expect(
          controller
              .placeAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1)
              .issueCode,
          issue,
        );
        expect(fixture.openMapController.state.session, same(before));
        fixture.mapLayerController.setLocked(layer, false);
        expect(
          controller.previewAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1),
          isNull,
        );
        expect(
          controller
              .placeAt(pixelX: 31, pixelY: 63, tileX: 0, tileY: 1)
              .isPlaced,
          isTrue,
        );
        expect(fixture.objectEditingController.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          const RawChkEncoder().encode(before.rawDocument),
        );
      },
    );
  }
  test(
    'unconfirmed catalog preview and click use a selection reason without changing state',
    () async {
      final fixture = await _openFixture();
      addTearDown(fixture.dispose);
      final before = fixture.controller.state;
      expect(
        fixture.controller.previewAt(pixelX: 0, pixelY: 0, tileX: 0, tileY: 0),
        PlacementCatalogDiagnosticCodes.unsupportedSelection,
      );
      expect(
        fixture.controller
            .placeAt(pixelX: 0, pixelY: 0, tileX: 0, tileY: 0)
            .issueCode,
        PlacementCatalogDiagnosticCodes.unsupportedSelection,
      );
      expect(fixture.controller.state, same(before));
    },
  );
  testWidgets(
    'Doodad graphic helper failure is nonblocking and is cleared on tab change',
    (tester) async {
      final fixture = await _openFixture(
        tileAtlasGateway: _FailingTileAtlasGateway(),
      );
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      final before = fixture.openMapController.state.session!;
      expect(
        await fixture.controller.load(StarCraftPlacementKind.doodad),
        isTrue,
      );
      expect(fixture.controller.state.diagnostics, isEmpty);
      expect(
        fixture.controller.state.previewDiagnostics.single.rawDetails,
        contains('preview unavailable'),
      );
      final item = fixture.controller.state.items.first;
      expect(item.hasThumbnail, isFalse);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacementCatalogPane(controller: fixture.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('placement-catalog-grid')), findsOneWidget);
      expect(find.byKey(const Key('placement-catalog-blocked')), findsNothing);
      await tester.tap(
        find.byKey(Key('placement-catalog-item-${item.key.stableId}')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('placement-catalog-preview-issue')),
        findsOneWidget,
      );
      expect(fixture.controller.confirm(item.key), isTrue);
      expect(fixture.openMapController.state.session, same(before));
      expect(fixture.objectEditingController.state.undoDepth, 0);
      expect(
        await fixture.controller.load(StarCraftPlacementKind.unit),
        isTrue,
      );
      expect(fixture.controller.state.previewDiagnostics, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Doodad grid renders composed tiles without changing the map', (
    tester,
  ) async {
    final fixture = await _openFixture();
    addTearDown(fixture.dispose);
    fixture.controller.setInstallationPath(_installationPath);
    final before = fixture.openMapController.state.session!;
    await fixture.controller.load(StarCraftPlacementKind.doodad);
    final item = fixture.controller.state.items.first;
    expect(item.hasThumbnail, isTrue);
    expect([item.thumbnailWidth, item.thumbnailHeight], [64, 32]);
    expect(item.thumbnailIssueCode, isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacementCatalogPane(controller: fixture.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('placement-catalog-item-${item.key.stableId}')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNWidgets(2));
    expect(
      find.byKey(const Key('placement-catalog-preview-issue')),
      findsNothing,
    );
    expect(fixture.openMapController.state.session, same(before));
    expect(fixture.objectEditingController.state.undoDepth, 0);
    expect(fixture.controller.confirm(item.key), isTrue);
    expect(tester.takeException(), isNull);
  });
  test(
    'unit-sprite with missing capability stays read-only before canvas placement',
    () async {
      final fixture = await _openFixture(unitCapabilityAvailable: false);
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      final before = fixture.openMapController.state.session!;
      expect(
        await fixture.controller.load(StarCraftPlacementKind.spriteUnit),
        isTrue,
      );
      final item = fixture.controller.state.items.single;
      expect(item.isPlaceable, isFalse);
      expect(fixture.controller.confirm(item.key), isFalse);
      expect(
        fixture.controller.state.lastPlacementIssueCode,
        'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
      );
      expect(fixture.controller.state.selection, isNull);
      expect(fixture.openMapController.state.session, same(before));
      expect(fixture.objectEditingController.state.undoDepth, 0);
    },
  );
  testWidgets(
    'unit-sprite tab confirms Unit graphics and places only THG2 with Undo',
    (tester) async {
      final fixture = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(fixture.dispose);
      fixture.controller.setInstallationPath(_installationPath);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacementCatalogPane(controller: fixture.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('placement-catalog-tab-spriteUnit')),
      );
      await tester.pumpAndSettle();
      final item = fixture.controller.state.items.single;
      expect(item.key.kind, StarCraftPlacementKind.spriteUnit);
      expect(item.hasThumbnail, isTrue);
      await tester.tap(
        find.byKey(const Key('placement-catalog-item-spriteUnit:0')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('placement-catalog-place')));
      await tester.pumpAndSettle();
      expect(
        fixture.controller.state.selection!.kind,
        StarCraftPlacementKind.spriteUnit,
      );
      final before = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      fixture.controller.setOwner(3);
      final result = fixture.controller.placeAt(
        pixelX: 96,
        pixelY: 64,
        tileX: 3,
        tileY: 2,
      );
      expect(result.isPlaced, isTrue);
      final sprite = fixture
          .openMapController
          .state
          .session!
          .objectViews
          .spriteSections
          .single
          .sprites
          .single;
      expect(sprite.flags, ChkSpritePlacement.isUnitFlag);
      expect(sprite.owner, 3);
      expect(
        fixture.openMapController.state.session!.objectViews.unitSections,
        isEmpty,
      );
      expect(fixture.objectEditingController.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(tester.takeException(), isNull);
    },
  );

  final realInstallation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final realHelper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  test(
    'local CV5 VF4 source drives actual UNIT terrain placement and Undo',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: realHelper!,
      );
      final read = await gateway.readPlacement(
        operationId: 'test-placement-ground',
        installationPath: realInstallation!,
        tileset: 4,
      );
      expect(
        read.isSuccess,
        isTrue,
        reason: '${read.errorCode} ${read.stderr}',
      );
      final snapshot = read.source!.snapshot;
      int tileWhere(
        bool Function(({bool buildable, int walkableMask})) predicate,
      ) {
        for (var raw = 0; raw < snapshot.groupBuildable.length * 16; raw++) {
          final tile = snapshot.tile(raw);
          if (tile != null && predicate(tile)) return raw;
        }
        throw StateError('No verified local test tile found');
      }

      final clear = tileWhere((t) => t.buildable && t.walkableMask == 65535);
      final blocked = tileWhere((t) => t.walkableMask == 0);
      for (final raw in [clear, blocked]) {
        final bytes = Uint8List(128);
        final data = ByteData.sublistView(bytes);
        for (var i = 0; i < 64; i++) {
          data.setUint16(i * 2, raw, Endian.little);
        }
        final f = await _openFixture(
          chkBytesOverride: _chkBytes(terrainBytes: bytes),
          catalogGateway: ProcessStarCraftPlacementCatalogGateway(
            helperExecutablePath: realHelper,
          ),
          objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
            helperExecutablePath: realHelper,
          ),
          terrainPlacementGateway: gateway,
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(realInstallation);
        expect(await c.load(StarCraftPlacementKind.unit), isTrue);
        expect(c.confirm(c.state.items.first.key), isTrue);
        c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
        expect(await c.loadTerrainPlacement(), isTrue);
        expect(await c.loadCollisionMetadata(), isTrue);
        expect(
          c.placementPolicySupport[PlacementPolicyRule.unitOverlap],
          PlacementPolicySupportStatus.enabled,
        );
        final before = f.openMapController.state.session;
        final expected = raw == clear
            ? null
            : ObjectPlacementDiagnosticCodes.unitTerrainUnwalkable;
        expect(
          c.previewAt(pixelX: 100, pixelY: 100, tileX: 3, tileY: 3),
          expected,
        );
        expect(identical(f.openMapController.state.session, before), isTrue);
        expect(
          c.placeAt(pixelX: 100, pixelY: 100, tileX: 3, tileY: 3).issueCode,
          expected,
        );
        if (raw == clear) {
          expect(f.objectEditingController.undo(), isTrue);
          expect(
            f.openMapController.state.session!.objectViews.unitSections,
            isEmpty,
          );
          expect(f.objectEditingController.redo(), isTrue);
        } else {
          expect(f.objectEditingController.state.undoDepth, 0);
          c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
          expect(
            c.previewAt(pixelX: 100, pixelY: 100, tileX: 3, tileY: 3),
            isNull,
          );
          expect(
            c.placeAt(pixelX: 100, pixelY: 100, tileX: 3, tileY: 3).isPlaced,
            isTrue,
          );
          expect(f.objectEditingController.undo(), isTrue);
        }
      }
    },
    skip: !Platform.isWindows || realInstallation == null || realHelper == null
        ? 'Set local StarCraft installation and helper paths.'
        : false,
  );
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
          expect(bytes, lessThanOrEqualTo(CatalogThumbnailPixels.maximumBytes));
          expect(item.thumbnailWidth, lessThanOrEqualTo(64));
          expect(item.thumbnailHeight, lessThanOrEqualTo(64));
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
        tileAtlasGateway: ProcessStarCraftTileAtlasGateway(
          helperExecutablePath: realHelper,
        ),
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: realHelper,
        ),
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
      final preview = fixture.controller.state.items.firstWhere(
        (item) => item.key == entry.key,
      );
      expect(
        preview.hasThumbnail || preview.thumbnailIssueCode != null,
        isTrue,
      );
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
        tileThumbnailBudgetBytes: 4096,
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
      final evicted = fixture.controller.state.items.firstWhere(
        (entry) => entry.thumbnailEvicted,
      );
      final ready = fixture.controller.changes.firstWhere(
        (state) => state.items.any(
          (entry) => entry.key == evicted.key && entry.hasThumbnail,
        ),
      );
      fixture.controller.requestThumbnail(evicted.key);
      await ready.timeout(const Duration(seconds: 30));
      await Future<void>.delayed(Duration.zero);
      expect(fixture.controller.retainedThumbnailBytes, 4096);
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
  for (final invalidate in [false, true]) {
    test(
      'tile rehydration ${invalidate ? 'discards stale replies' : 'does not retry failures endlessly'}',
      () async {
        final atlas = _ReloadTileAtlas(fail: !invalidate);
        final fixture = await _openFixture(
          catalogGateway: _InconsistentPagingGateway(null),
          tileAtlasGateway: atlas,
          tileThumbnailBudgetBytes: 8192,
        );
        addTearDown(fixture.dispose);
        final controller = fixture.controller
          ..setInstallationPath(_installationPath);
        await controller.load(StarCraftPlacementKind.tile);
        await controller.loadMore();
        final key = controller.state.items.first.key;
        controller.requestThumbnail(key);
        await atlas.started.future;
        if (invalidate) controller.setInstallationPath(null);
        atlas.release.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        controller.requestThumbnail(key);
        await Future<void>.delayed(Duration.zero);
        expect(atlas.calls, 3);
        if (invalidate) {
          expect(controller.state.items, isEmpty);
          expect(controller.retainedThumbnailBytes, 0);
        } else {
          expect(controller.retainedThumbnailBytes, 8192);
          expect(controller.state.items.first.thumbnailEvicted, isTrue);
        }
      },
    );
  }

  for (final kind in [
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
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
          expect(
            sprite.drawsAsSprite,
            kind == StarCraftPlacementKind.pureSprite,
          );
          expect(sprite.hasUnitFlag, kind == StarCraftPlacementKind.spriteUnit);
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
      final c = fixture.controller;
      expect(await c.load(StarCraftPlacementKind.unit), isTrue);
      expect(c.confirm(c.state.items.first.key), isTrue);
      c.setContinuous(true);
      c.setAllowUnitOverlap(false);
      expect(await c.loadCollisionMetadata(), isTrue);
      expect(c.lastCollisionMetadataPage!.entries, hasLength(228));
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
      final before = fixture.openMapController.state.session!;
      expect(
        c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
        ObjectPlacementDiagnosticCodes.unitOverlap,
      );
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
        ObjectPlacementDiagnosticCodes.unitOverlap,
      );
      expect(fixture.openMapController.state.session, same(before));
      expect(fixture.objectEditingController.undo(), isTrue);
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
    expect(fixture.controller.state.items, isEmpty);
    expect(fixture.controller.state.isLoading, isFalse);
  });

  test('obsolete Tile catalog never starts atlas work', () async {
    for (final change in ['installation', 'map', 'dispose']) {
      final gateway = _DeferredCatalogGateway();
      final atlas = _CountingTileAtlasGateway();
      final fixture = await _openFixture(
        catalogGateway: gateway,
        tileAtlasGateway: atlas,
      );
      fixture.controller.setInstallationPath(_installationPath);
      final pending = fixture.controller.load(StarCraftPlacementKind.tile);
      switch (change) {
        case 'installation':
          fixture.controller.setInstallationPath(r'C:\Other');
        case 'map':
          fixture.controller.synchronizeSession(
            fixture.openMapController.state.session,
          );
        case 'dispose':
          await fixture.dispose();
      }
      gateway.complete(
        entries: [
          StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.tile(
              tileset: StarCraftTilesetAssetSet.jungle,
              rawValue: 1,
            ),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
          ),
        ],
      );
      expect(await pending, isFalse);
      expect(atlas.calls, 0);
      expect(fixture.controller.state.items, isEmpty);
      expect(fixture.controller.state.diagnostics, isEmpty);
      if (change != 'dispose') await fixture.dispose();
    }
  });

  test('obsolete object catalog does not launch thumbnail rendering', () async {
    for (final close in [false, true]) {
      final gateway = _DeferredCatalogGateway();
      final atlas = _CountingAtlasGateway();
      final fixture = await _openFixture(
        catalogGateway: gateway,
        objectAtlasGateway: atlas,
      );
      fixture.controller.setInstallationPath(_installationPath);
      final pending = fixture.controller.load(
        StarCraftPlacementKind.pureSprite,
      );
      if (close) {
        await fixture.dispose();
      } else {
        fixture.controller.setInstallationPath(r'C:\Other');
      }
      gateway.complete(
        entries: [
          StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.pureSprite(0),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
          ),
        ],
      );
      expect(await pending, isFalse);
      expect(atlas.calls, 0);
      expect(fixture.controller.state.items, isEmpty);
      expect(fixture.controller.state.diagnostics, isEmpty);
      if (!close) await fixture.dispose();
    }
  });

  test(
    'disposal drops thumbnail state and ignores late UI callbacks',
    () async {
      final fixture = await _openFixture(unitCapabilityAvailable: true);
      final controller = fixture.controller;
      controller.setInstallationPath(_installationPath);
      expect(await controller.load(StarCraftPlacementKind.unit), isTrue);
      final item = controller.state.items.single;
      expect(item.hasThumbnail, isTrue);
      controller.preview(item.key);
      expect(controller.confirm(item.key), isTrue);
      expect(controller.state.selection, isNotNull);
      expect(controller.state.recentKeys, isNotEmpty);
      final before = const RawChkEncoder().encode(
        fixture.openMapController.state.session!.rawDocument,
      );
      await controller.dispose();
      expect(controller.state.items, isEmpty);
      expect(controller.state.totalEntries, 0);
      expect(controller.state.previewKey, isNull);
      expect(controller.state.selection, isNull);
      expect(controller.state.recentKeys, isEmpty);
      final closedState = controller.state;
      controller.setQuery('late search');
      controller.setOwner(2);
      controller.setContinuous(true);
      controller.preview(item.key);
      controller.setInstallationPath(r'C:\Other');
      controller.synchronizeSession(fixture.openMapController.state.session);
      expect(await controller.load(StarCraftPlacementKind.unit), isFalse);
      expect(await controller.loadMore(), isFalse);
      expect(controller.state, same(closedState));
      expect(
        const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      await fixture.dispose();
    },
  );

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
    fixture.terrainEditingController.setTool(TerrainEditingTool.brush);
    fixture.objectEditingController.startLocationCreation();
    expect(fixture.controller.confirm(unit.key), isTrue);
    expect(
      fixture.terrainEditingController.state.tool,
      TerrainEditingTool.select,
    );
    expect(fixture.objectEditingController.state.isCreatingLocation, isFalse);

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

  testWidgets('visible evicted Tile is requested by the catalog pane', (
    tester,
  ) async {
    final fixture = await _openFixture(
      catalogGateway: _InconsistentPagingGateway(null),
      tileThumbnailBudgetBytes: 8192,
    );
    addTearDown(fixture.dispose);
    final controller = fixture.controller
      ..setInstallationPath(_installationPath);
    await controller.load(StarCraftPlacementKind.tile);
    await controller.loadMore();
    expect(controller.state.items.first.thumbnailEvicted, isTrue);
    controller.setQuery('#3200');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacementCatalogPane(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.state.items.first.hasThumbnail, isTrue);
    expect(controller.retainedThumbnailBytes, lessThanOrEqualTo(8192));
    expect(find.byType(RawImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'recently visible Tile survives the next page budget eviction',
    () async {
      final fixture = await _openFixture(
        catalogGateway: _InconsistentPagingGateway(null),
        tileThumbnailBudgetBytes: 12288,
      );
      addTearDown(fixture.dispose);
      final controller = fixture.controller
        ..setInstallationPath(_installationPath);
      await controller.load(StarCraftPlacementKind.tile);
      controller.requestThumbnail(controller.state.items.first.key);
      await controller.loadMore();
      expect(controller.state.items.first.hasThumbnail, isTrue);
      expect(controller.state.items[1].thumbnailEvicted, isTrue);
      expect(controller.retainedThumbnailBytes, 12288);
    },
  );

  test(
    'tile budget evicts pixels only and rehydrates a requested tile',
    () async {
      final atlas = _CountingTileAtlasGateway();
      final fixture = await _openFixture(
        catalogGateway: _InconsistentPagingGateway(null),
        tileAtlasGateway: atlas,
        tileThumbnailBudgetBytes: 8192,
      );
      addTearDown(fixture.dispose);
      final controller = fixture.controller
        ..setInstallationPath(_installationPath);
      await controller.load(StarCraftPlacementKind.tile);
      final key = controller.state.items.first.key;
      await controller.loadMore();
      expect(controller.state.items, hasLength(4));
      expect(controller.retainedThumbnailBytes, 8192);
      expect(controller.state.items.first.thumbnailEvicted, isTrue);
      final ready = controller.changes.firstWhere(
        (s) => s.items.first.hasThumbnail,
      );
      controller.requestThumbnail(key);
      controller.requestThumbnail(key);
      await ready.timeout(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(atlas.calls, 3);
      expect(controller.retainedThumbnailBytes, 8192);
      expect(controller.state.items.first.isPlaceable, isTrue);
      expect(controller.confirm(key), isTrue);
      await controller.dispose();
      expect(controller.retainedThumbnailBytes, 0);
      controller.requestThumbnail(key);
      expect(atlas.calls, 3);
    },
  );

  for (final kind in [
    StarCraftPlacementKind.tile,
    StarCraftPlacementKind.doodad,
    StarCraftPlacementKind.unit,
    StarCraftPlacementKind.pureSprite,
  ]) {
    for (final failure in ['overlap', 'changed-total', 'exhausted']) {
      test('$kind rejects $failure paging and can reload cleanly', () async {
        final gateway = _InconsistentPagingGateway(failure);
        final fixture = await _openFixture(catalogGateway: gateway);
        addTearDown(fixture.dispose);
        final controller = fixture.controller;
        controller.setInstallationPath(_installationPath);
        final before = const RawChkEncoder().encode(
          fixture.openMapController.state.session!.rawDocument,
        );
        expect(await controller.load(kind), isTrue);
        final accepted = controller.state.items;
        controller.preview(accepted.first.key);

        expect(await controller.loadMore(), isFalse);
        expect(controller.state.items, accepted);
        expect(controller.state.previewKey, accepted.first.key);
        expect(controller.state.totalEntries, 4);
        expect(controller.state.isLoading, isFalse);
        expect(controller.state.hasMore, isFalse);
        expect(
          controller.state.diagnostics.single.code,
          PlacementCatalogDiagnosticCodes.inconsistentPage,
        );
        expect(await controller.loadMore(), isFalse);
        expect(gateway.calls, 2);

        gateway.failure = null;
        expect(await controller.load(kind), isTrue);
        expect(controller.state.diagnostics, isEmpty);
        expect(controller.state.hasMore, isTrue);
        expect(await controller.loadMore(), isTrue);
        expect(controller.state.items, hasLength(4));
        expect(
          controller.state.items.map((item) => item.key).toSet(),
          hasLength(4),
        );
        expect(controller.state.hasMore, isFalse);
        expect(
          const RawChkEncoder().encode(
            fixture.openMapController.state.session!.rawDocument,
          ),
          before,
        );
      });
    }
  }
}

final class _InconsistentPagingGateway
    implements StarCraftPlacementCatalogGateway {
  _InconsistentPagingGateway(this.failure);

  String? failure;
  int calls = 0;
  final _entries = _FakeCatalogGateway(
    doodadTotal: 4,
    unitCapabilityAvailable: true,
  );

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    calls++;
    final next = request.offset > 0;
    final start = next && failure == 'overlap' ? 1 : request.offset;
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: next && failure == 'changed-total'
          ? 5
          : next && failure == 'exhausted'
          ? 2
          : 4,
      entries: next && failure == 'exhausted'
          ? []
          : [
              for (var i = start; i < start + request.limit; i++)
                _entries._entry(request.kind, request.tileset, i),
            ],
      storageProduct: 's1',
      storageBuildNumber: 13515,
      helperVersion: '0.7.0',
      cascLibRevision: 'abc',
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
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
  bool unitIsBuilding = false,
  BuildingPlacementBox? placementBox,
  UnitCollisionProfile? collisionProfile,
  StarCraftPlacementCatalogGateway? catalogGateway,
  StarCraftObjectAtlasGateway? objectAtlasGateway,
  StarCraftTileAtlasGateway? tileAtlasGateway,
  TerrainPlacementSnapshotGateway? terrainPlacementGateway,
  Uint8List? chkBytesOverride,
  int pageSize = 2,
  int tileThumbnailBudgetBytes = 16 * 1024 * 1024,
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
    unitIsBuilding: unitIsBuilding,
    placementBox: placementBox,
    collisionProfile: collisionProfile,
  );
  final controller = PlacementCatalogController(
    terrainPlacementGateway: terrainPlacementGateway,
    openMapController: openMapController,
    objectEditingController: objectEditingController,
    terrainEditingController: terrainEditingController,
    catalogGateway: catalogGateway ?? gateway,
    tileAtlasGateway: tileAtlasGateway ?? const _FakeTileAtlasGateway(),
    objectAtlasGateway: objectAtlasGateway ?? const _FakeObjectAtlasGateway(),
    pageSize: pageSize,
    tileThumbnailBudgetBytes: tileThumbnailBudgetBytes,
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

  void complete({List<StarCraftPlacementCatalogEntry> entries = const []}) =>
      result.complete(
        StarCraftPlacementCatalogPage(
          request: request,
          totalEntries: entries.length,
          entries: entries,
          storageProduct: 's1',
          storageBuildNumber: 13515,
          helperVersion: '0.12.0',
          cascLibRevision: 'abc',
        ),
      );

  @override
  Future<void> cancel(String operationId) async {}
}

final class _SynchronousCollisionFailure
    implements StarCraftPlacementCatalogGateway {
  int calls = 0;
  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) {
    calls++;
    throw StateError('Synthetic synchronous gateway failure');
  }

  @override
  Future<void> cancel(String operationId) async {}
}

final class _CollisionGateway implements StarCraftPlacementCatalogGateway {
  _CollisionGateway({this.failure, this.hold = false});
  String? failure;
  final bool hold;
  final release = Completer<void>();
  final cancelled = <String>[];
  int metadataRequests = 0;

  _FakeCatalogGateway get delegate => _FakeCatalogGateway(
    doodadTotal: 2,
    unitCapabilityAvailable: true,
    collisionProfile: failure == 'profile'
        ? null
        : UnitCollisionProfile(
            left: 0,
            up: 0,
            right: 0,
            down: 0,
            isFlyer: false,
          ),
  );

  UnitPlacementCapability get capability => delegate
      ._entry(StarCraftPlacementKind.unit, StarCraftTilesetAssetSet.jungle, 0)
      .unitCapability!;

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.unitMetadataOnly) {
      metadataRequests++;
      if (hold) await release.future;
      if (failure == 'exception') throw StateError('Synthetic process failure');
    }
    final page = await delegate.list(request);
    if (!request.unitMetadataOnly) return page;
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: 228,
      entries: failure == 'coverage' ? page.entries.take(227) : page.entries,
      storageProduct: failure == 'source' ? null : page.storageProduct,
      storageBuildNumber: failure == 'changed-source'
          ? 123
          : page.storageBuildNumber,
      helperVersion: page.helperVersion,
      cascLibRevision: page.cascLibRevision,
    );
  }

  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
  }
}

final class _ResourceGateway implements StarCraftPlacementCatalogGateway {
  _ResourceGateway({this.failure, this.hold = false, this.building = false});
  String? failure;
  final bool hold;
  final bool building;
  final release = Completer<void>();
  final cancelled = <String>[];
  int metadataRequests = 0;

  UnitPlacementCapability capability(int id, {bool numeric = false}) =>
      UnitPlacementCapability(
        unitId: id,
        resourceProfile: UnitResourceProfile(
          isDepot: id == 0 && !(numeric && failure == 'role'),
          isResource: id == 1,
        ),
        collisionProfile: UnitCollisionProfile(
          left: numeric && failure == 'geometry' ? 1 : 0,
          up: 0,
          right: 0,
          down: 0,
          isFlyer: false,
        ),
        placementBox: building
            ? BuildingPlacementBox(width: 64, height: 64)
            : null,
        isBuilding: building,
        isFlyingBuilding: false,
        isSpellcaster: false,
        hasShields: false,
        isResourceContainer: id == 1,
        isGasResourceContainer: false,
        hasHangar: false,
        isBurrowable: false,
        isCloakable: false,
        isInvincible: false,
        requiresRelationLink: false,
      );

  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest request,
  ) async {
    if (request.unitMetadataOnly) {
      metadataRequests++;
      if (hold) await release.future;
    }
    final page = await _FakeCatalogGateway(
      doodadTotal: 2,
      unitCapabilityAvailable: true,
      unitCapabilityForId: (id) =>
          capability(id, numeric: request.unitMetadataOnly),
    ).list(request);
    return StarCraftPlacementCatalogPage(
      request: request,
      totalEntries: page.totalEntries,
      entries: request.unitMetadataOnly && failure == 'coverage'
          ? page.entries.take(227)
          : page.entries,
      storageProduct: page.storageProduct,
      storageBuildNumber: request.unitMetadataOnly && failure == 'source'
          ? 123
          : page.storageBuildNumber,
      helperVersion: page.helperVersion,
      cascLibRevision: page.cascLibRevision,
    );
  }

  @override
  Future<void> cancel(String operationId) async => cancelled.add(operationId);
}

final class _FakeCatalogGateway implements StarCraftPlacementCatalogGateway {
  _FakeCatalogGateway({
    required this.doodadTotal,
    required this.unitCapabilityAvailable,
    this.unitIsBuilding = false,
    this.placementBox,
    this.collisionProfile,
    this.unitCapabilityForId,
  });

  final int doodadTotal;
  final bool unitCapabilityAvailable;
  final bool unitIsBuilding;
  final BuildingPlacementBox? placementBox;
  final UnitCollisionProfile? collisionProfile;
  final UnitPlacementCapability Function(int)? unitCapabilityForId;

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
      case StarCraftPlacementKind.spriteUnit:
        if (unitCapabilityAvailable) {
          return StarCraftPlacementCatalogEntry(
            key: kind == StarCraftPlacementKind.unit
                ? StarCraftPlacementCatalogKey.unit(index)
                : StarCraftPlacementCatalogKey.spriteUnit(index),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
            verifiedName: 'Terran Marine',
            unitCapability:
                unitCapabilityForId?.call(index) ??
                UnitPlacementCapability(
                  unitId: index,
                  placementBox: placementBox,
                  collisionProfile: collisionProfile,
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
                  isBuilding: unitIsBuilding,
                  requiresRelationLink: false,
                ),
          );
        }
        return StarCraftPlacementCatalogEntry(
          key: kind == StarCraftPlacementKind.unit
              ? StarCraftPlacementCatalogKey.unit(index)
              : StarCraftPlacementCatalogKey.spriteUnit(index),
          source: StarCraftPlacementCatalogSource.localData,
          availability: StarCraftPlacementAvailability.unsupported,
          issue: StarCraftPlacementCatalogIssue(
            code: 'SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE',
            message: 'Verified unit capability data is unavailable.',
          ),
          previewIssueCode: 'SC_CASC_OBJECT_PREVIEW_UNAVAILABLE',
        );
      case StarCraftPlacementKind.pureSprite:
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

final class _CountingTileAtlasGateway implements StarCraftTileAtlasGateway {
  int calls = 0;
  @override
  Future<StarCraftTileAtlasResult> render(StarCraftTileAtlasRequest request) {
    calls++;
    return const _FakeTileAtlasGateway().render(request);
  }
}

final class _ReloadTileAtlas implements StarCraftTileAtlasGateway {
  _ReloadTileAtlas({required this.fail});
  final bool fail;
  int calls = 0;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async {
    if (++calls == 3) {
      started.complete();
      await release.future;
      if (fail) throw StateError('Synthetic reload failure');
    }
    return const _FakeTileAtlasGateway().render(request);
  }
}

final class _FailingTileAtlasGateway implements StarCraftTileAtlasGateway {
  @override
  Future<StarCraftTileAtlasResult> render(
    StarCraftTileAtlasRequest request,
  ) async => throw StateError('preview unavailable');
}

final class _CountingAtlasGateway implements StarCraftObjectAtlasGateway {
  int calls = 0;
  @override
  Future<StarCraftObjectAtlasResult> render(
    StarCraftObjectAtlasRequest request,
  ) {
    calls++;
    return const _FakeObjectAtlasGateway().render(request);
  }

  @override
  Future<void> cancel(String operationId) async {}
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
