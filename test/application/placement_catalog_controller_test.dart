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
import 'package:starcraft_map_editor/domain/placement/unit_environment_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_power_unit_state.dart';
import 'package:starcraft_map_editor/application/ports/unit_power_state_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_state_gateway.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_catalog.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';
import 'package:starcraft_map_editor/domain/placement/cv5_creep_candidate_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_observation.dart';
import 'package:starcraft_map_editor/infrastructure/placement/preplaced_unit_power_state_gateway.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_policy.dart';
import 'package:starcraft_map_editor/application/placement/placement_policy_support.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import 'package:starcraft_map_editor/application/ports/terrain_placement_snapshot_gateway.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/presentation/placement/placement_alignment_toolbar.dart';
import 'package:starcraft_map_editor/l10n/app_localizations.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';
import '../fixtures/creep_observation_fixture.dart';
import '../fixtures/creep_capture_fixture.dart';
import 'package:starcraft_map_editor/infrastructure/placement/validated_unit_creep_state_gateway.dart';

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
    this.cv5Flags,
  });
  String? failure;
  final bool hold;
  final int mask;
  final int? cv5Flags;
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
            creepCandidateProfile: cv5Flags == null
                ? null
                : Cv5CreepCandidateProfile(groupFlags: [cv5Flags!]),
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
  _unitCreepInspectionTests();
  _preplacedPowerPolicyTests();
  _preplacedPowerTests();
  _unitPowerInspectionTests();
  for (final alignment in ['point', 'building']) {
    test(
      'resource policy blocks final $alignment point, free mode preserves Undo bytes',
      () async {
        final gateway = _ResourceGateway(building: alignment == 'building');
        final f = await _openFixture(
          catalogGateway: gateway,
          chkBytesOverride: Uint8List.fromList([
            ..._chkBytes(),
            ..._section('XTRA', [255, 0, 128]),
            ..._section(
              'UNIT',
              const UnitPlacementFactory()
                  .create(
                    capability: gateway.capability(1),
                    unitId: 1,
                    owner: 11,
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
        c.setContinuous(true);
        expect(c.state.checkResourceDistance, isFalse);
        c.setCheckResourceDistance(true);
        await c.loadCollisionMetadata();
        expect(
          c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
          PlacementPolicySupportStatus.enabled,
        );
        expect(c.previewAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2), isNull);
        c.setPointSnap(enabled: true, step: 32);
        c.setBuildingTileAlignment(alignment == 'building');
        final before = f.openMapController.state.session!;
        final raw = const RawChkEncoder().encode(before.rawDocument);
        final state = c.state;
        expect(
          c.previewAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2),
          ObjectPlacementDiagnosticCodes.resourceDistanceTooClose,
        );
        expect(c.state, same(state));
        expect(
          c.placeAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2).issueCode,
          ObjectPlacementDiagnosticCodes.resourceDistanceTooClose,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
        expect(c.state.selection, same(state.selection));
        c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
        expect(c.state.checkResourceDistance, isFalse);
        expect(
          c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
          PlacementPolicySupportStatus.skipped,
        );
        expect(
          c.placeAt(pixelX: 63, pixelY: 64, tileX: 1, tileY: 2).isPlaced,
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
            .last;
        expect((unit.x, unit.y), (64, 64));
        expect(f.objectEditingController.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          raw,
        );
        expect(f.objectEditingController.redo(), isTrue);
        expect(gateway.metadataRequests, 1);
      },
    );
  }
  for (final failure in ['source', 'coverage', 'geometry', 'role']) {
    test(
      'resource policy rejects $failure without edits and reload recovers',
      () async {
        final gateway = _ResourceGateway(failure: failure);
        final f = await _openFixture(catalogGateway: gateway);
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        c.setCheckResourceDistance(true);
        await c.loadCollisionMetadata();
        final before = f.openMapController.state.session;
        expect(
          c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
          ObjectPlacementDiagnosticCodes.resourceDistanceUnavailable,
        );
        expect(
          c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
          ObjectPlacementDiagnosticCodes.resourceDistanceUnavailable,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
        gateway.failure = null;
        await c.loadCollisionMetadata(reload: true);
        expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
        expect(
          c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
          isTrue,
        );
      },
    );
  }
  for (final kind in ['unknown', 'flight', 'outside']) {
    test(
      'resource policy preserves aggregate refusal $kind priority',
      () async {
        final gateway = _ResourceGateway();
        final record = Uint8List.fromList(
          const UnitPlacementFactory()
              .create(
                capability: gateway.capability(1),
                unitId: 1,
                owner: 11,
                x: 64,
                y: 64,
                classId: 1,
              )
              .bytes,
        );
        final data = ByteData.sublistView(record);
        if (kind == 'unknown') data.setUint16(8, 300, Endian.little);
        if (kind == 'flight') data.setUint16(26, 4, Endian.little);
        if (kind == 'outside') data.setUint16(4, 256, Endian.little);
        final f = await _openFixture(
          catalogGateway: gateway,
          chkBytesOverride: Uint8List.fromList([
            ..._chkBytes(),
            ..._section('UNIT', record),
          ]),
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(StarCraftPlacementKind.unit);
        c.confirm(c.state.items.single.key);
        c.setCheckResourceDistance(true);
        await c.loadCollisionMetadata();
        final expected = switch (kind) {
          'unknown' =>
            ObjectPlacementDiagnosticCodes.resourceDistanceUnavailable,
          'flight' =>
            ObjectPlacementDiagnosticCodes.resourceDistanceStateUnsupported,
          _ => ObjectPlacementDiagnosticCodes.outOfBounds,
        };
        final before = f.openMapController.state.session;
        expect(
          c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2),
          expected,
        );
        expect(
          c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
          expected,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  test(
    'resource policy loading blocks and cancelling preset never restores checks',
    () async {
      final gateway = _ResourceGateway(hold: true);
      final f = await _openFixture(catalogGateway: gateway);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setCheckResourceDistance(true);
      final pending = c.loadCollisionMetadata();
      expect(
        c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
        PlacementPolicySupportStatus.loading,
      );
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).issueCode,
        ObjectPlacementDiagnosticCodes.resourceDistanceUnavailable,
      );
      c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
      gateway.release.complete();
      await pending;
      expect(c.state.checkResourceDistance, isFalse);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.free);
      expect(f.objectEditingController.state.undoDepth, 0);
    },
  );
  for (final kind in [
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test('$kind bypasses UNIT resource policy without metadata', () async {
      final f = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      c.setCheckResourceDistance(true);
      await c.load(kind);
      c.confirm(c.state.items.first.key);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
        PlacementPolicySupportStatus.notApplicable,
      );
      expect(c.previewAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2), isNull);
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
    });
  }
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
        PlacementPolicySupportStatus.skipped,
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
        states.every(
          (s) =>
              s.checkUnitTerrain &&
              !s.allowUnitOverlap &&
              s.checkResourceDistance,
        ),
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
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
      c.setCheckResourceDistance(false);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.free);
      c.setAllowUnitOverlap(false);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
      c.setCheckUnitTerrain(true);
      expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
      c.setCheckResourceDistance(true);
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
        await tester.tap(
          find.byKey(const Key('placement-check-resource-distance')),
        );
        await tester.pumpAndSettle();
        expect(fixture.controller.state.checkResourceDistance, isTrue);
        expect(
          find.byKey(const Key('placement-reload-resource-distance')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('placement-reload-resource-distance')),
        );
        await tester.pumpAndSettle();
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
    'local DAT Gateway and Pylon use the preplaced policy without a state packet',
    () async {
      final gateway = ProcessStarCraftPlacementCatalogGateway(
        helperExecutablePath: realHelper!,
      );
      final metadata = await gateway.list(
        StarCraftPlacementCatalogRequest(
          operationId: 'preplaced-power-local-fixture',
          installationPath: realInstallation!,
          kind: StarCraftPlacementKind.unit,
          tileset: StarCraftTilesetAssetSet.jungle,
          unitMetadataOnly: true,
          limit: 228,
        ),
      );
      expect(metadata.isSuccess, isTrue, reason: '${metadata.diagnostics}');
      final pylon = metadata.entries[156].unitCapability!;
      final f = await _openFixture(
        catalogGateway: gateway,
        pageSize: 128,
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: realHelper,
        ),
        chkBytesOverride: Uint8List.fromList([
          ..._chkBytes(mapSize: 64),
          ..._section('XTRA', [255, 0, 128]),
          ..._section(
            'UNIT',
            const UnitPlacementFactory()
                .create(
                  capability: pylon,
                  unitId: 156,
                  owner: 0,
                  x: 1024,
                  y: 1024,
                  classId: 1,
                )
                .bytes,
          ),
        ]),
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(realInstallation);
      expect(await c.load(StarCraftPlacementKind.unit), isTrue);
      expect(await c.loadMore(), isTrue);
      expect(
        c.confirm(c.state.items.firstWhere((item) => item.key.id == 160).key),
        isTrue,
      );
      c.setCheckPreplacedPower(true);
      c.setContinuous(true);
      expect(await c.loadCollisionMetadata(), isTrue);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
        PlacementPolicySupportStatus.enabled,
      );
      final before = const RawChkEncoder().encode(
        f.openMapController.state.session!.rawDocument,
      );
      expect(
        c.previewAt(pixelX: 512, pixelY: 512, tileX: 16, tileY: 16),
        ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
      );
      expect(
        c.placeAt(pixelX: 512, pixelY: 512, tileX: 16, tileY: 16).issueCode,
        ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
      );
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        isNull,
      );
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).isPlaced,
        isTrue,
      );
      expect(f.objectEditingController.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        ),
        before,
      );
      expect(f.objectEditingController.redo(), isTrue);
      expect(c.lastUnitPowerStateRead, isNull);
    },
    skip: !Platform.isWindows || realInstallation == null || realHelper == null,
  );
  test(
    'local DAT resource policy rejects near, accepts far and preserves Undo',
    () async {
      final gateway = ProcessStarCraftPlacementCatalogGateway(
        helperExecutablePath: realHelper!,
      );
      final metadata = await gateway.list(
        StarCraftPlacementCatalogRequest(
          operationId: 'resource-policy-local-fixture',
          installationPath: realInstallation!,
          kind: StarCraftPlacementKind.unit,
          tileset: StarCraftTilesetAssetSet.jungle,
          unitMetadataOnly: true,
          limit: 228,
        ),
      );
      expect(metadata.isSuccess, isTrue, reason: '${metadata.diagnostics}');
      final resource = metadata.entries[188].unitCapability!;
      final f = await _openFixture(
        catalogGateway: gateway,
        pageSize: 128,
        objectAtlasGateway: ProcessStarCraftObjectAtlasGateway(
          helperExecutablePath: realHelper,
        ),
        chkBytesOverride: Uint8List.fromList([
          ..._chkBytes(mapSize: 64),
          ..._section('XTRA', [255, 0, 128]),
          ..._section(
            'UNIT',
            const UnitPlacementFactory()
                .create(
                  capability: resource,
                  unitId: 188,
                  owner: 11,
                  x: 1024,
                  y: 1024,
                  classId: 1,
                )
                .bytes,
          ),
        ]),
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(realInstallation);
      expect(await c.load(StarCraftPlacementKind.unit), isTrue);
      expect(
        c.confirm(c.state.items.firstWhere((item) => item.key.id == 106).key),
        isTrue,
      );
      c.setCheckResourceDistance(true);
      c.setContinuous(true);
      expect(await c.loadCollisionMetadata(), isTrue);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.resourceDistance],
        PlacementPolicySupportStatus.enabled,
      );
      final before = f.openMapController.state.session!;
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        ObjectPlacementDiagnosticCodes.resourceDistanceTooClose,
      );
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
        ObjectPlacementDiagnosticCodes.resourceDistanceTooClose,
      );
      expect(f.openMapController.state.session, same(before));
      expect(f.objectEditingController.state.undoDepth, 0);
      expect(
        c.previewAt(pixelX: 512, pixelY: 512, tileX: 16, tileY: 16),
        isNull,
      );
      expect(
        c.placeAt(pixelX: 512, pixelY: 512, tileX: 16, tileY: 16).isPlaced,
        isTrue,
      );
      expect(f.objectEditingController.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(
          f.openMapController.state.session!.rawDocument,
        ),
        const RawChkEncoder().encode(before.rawDocument),
      );
      expect(f.objectEditingController.redo(), isTrue);
    },
    skip: !Platform.isWindows || realInstallation == null || realHelper == null,
  );
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

void _preplacedPowerPolicyTests() {
  for (final locale in ['ko', 'en']) {
    for (final width in [300.0, 1000.0]) {
      testWidgets(
        'layout policy $locale checkbox and separate support at width $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width + 40, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final f = await _openFixture(
            catalogGateway: _PowerCatalogGateway(),
            chkBytesOverride: _layoutChkBytes(),
          );
          addTearDown(f.dispose);
          await _selectPowerUnit(f);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: StreamBuilder(
                      stream: f.controller.changes,
                      builder: (_, _) =>
                          PlacementAlignmentToolbar(controller: f.controller),
                    ),
                  ),
                ),
              ),
            ),
          );
          final tile = find.byKey(const Key('placement-check-preplaced-power'));
          expect(tester.widget<CheckboxListTile>(tile).value, isFalse);
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(f.controller.state.checkPreplacedPower, isTrue);
          expect(tester.widget<CheckboxListTile>(tile).value, isTrue);
          final l10n = AppLocalizations.of(tester.element(tile))!;
          expect(find.text(l10n.placementPreplacedPowerScope), findsOneWidget);
          final titleRect = tester.getRect(
            find.text(l10n.placementCheckPreplacedPower),
          );
          final tileRect = tester.getRect(tile);
          expect(titleRect.left, greaterThanOrEqualTo(tileRect.left));
          expect(titleRect.right, lessThanOrEqualTo(tileRect.right));
          expect(
            find.byTooltip(l10n.placementReloadPreplacedPower),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const Key('placement-reload-preplaced-power')),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const Key('placement-policy-support')),
          );
          await tester.tap(find.byKey(const Key('placement-policy-support')));
          await tester.pumpAndSettle();
          final projectedRow = find.byKey(
            const ValueKey('placement-policy-preplacedPower'),
          );
          final actualRow = find.byKey(
            const ValueKey('placement-policy-power'),
          );
          expect(
            find.descendant(
              of: projectedRow,
              matching: find.text(l10n.placementPolicyEnabled),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: actualRow,
              matching: find.text(l10n.placementPolicyNotImplemented),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.editorClose));
          await tester.pumpAndSettle();
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(f.controller.state.checkPreplacedPower, isFalse);
          expect(f.objectEditingController.state.undoDepth, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final alignment in ['point', 'building']) {
    test(
      'layout policy blocks final $alignment coordinates and preserves refusal bytes',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          chkBytesOverride: _layoutChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        final c = f.controller..setContinuous(true);
        expect(c.state.checkPreplacedPower, isFalse);
        c.setCheckPreplacedPower(true);
        expect(c.state.unitPlacementPolicy.mode, UnitPlacementMode.custom);
        expect(
          c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
          PlacementPolicySupportStatus.enabled,
        );
        expect(
          c.previewAt(pixelX: 769, pixelY: 1024, tileX: 24, tileY: 32),
          isNull,
        );
        c.setPointSnap(enabled: true, step: 32);
        c.setBuildingTileAlignment(alignment == 'building');
        final session = f.openMapController.state.session!;
        final before = const RawChkEncoder().encode(session.rawDocument);
        final selection = c.state.selection;
        expect(
          c.previewAt(pixelX: 769, pixelY: 1024, tileX: 24, tileY: 32),
          ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
        );
        expect(
          c.placeAt(pixelX: 769, pixelY: 1024, tileX: 24, tileY: 32).issueCode,
          ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
        );
        expect(f.openMapController.state.session, same(session));
        expect(f.objectEditingController.state.undoDepth, 0);
        expect(c.state.selection, same(selection));
        c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
        expect(c.state.checkPreplacedPower, isFalse);
        expect(
          c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
          PlacementPolicySupportStatus.skipped,
        );
        expect(
          c.placeAt(pixelX: 769, pixelY: 1024, tileX: 24, tileY: 32).isPlaced,
          isTrue,
        );
        expect(f.objectEditingController.undo(), isTrue);
        expect(
          const RawChkEncoder().encode(
            f.openMapController.state.session!.rawDocument,
          ),
          before,
        );
        expect(f.objectEditingController.redo(), isTrue);
      },
    );
  }
  for (final failure in ['source', 'coverage', 'role', 'geometry', 'box']) {
    test(
      'layout policy rejects $failure metadata until explicit reload',
      () async {
        final catalog = _PowerCatalogGateway(failure: failure);
        final f = await _openFixture(
          catalogGateway: catalog,
          chkBytesOverride: _layoutChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        final c = f.controller..setCheckPreplacedPower(true);
        await c.loadCollisionMetadata();
        final before = f.openMapController.state.session;
        expect(
          c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
          ObjectPlacementDiagnosticCodes.preplacedPowerUnavailable,
        );
        expect(
          c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
          ObjectPlacementDiagnosticCodes.preplacedPowerUnavailable,
        );
        expect(
          c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
          PlacementPolicySupportStatus.unavailable,
        );
        expect(f.openMapController.state.session, same(before));
        expect(f.objectEditingController.state.undoDepth, 0);
        catalog.failure = null;
        expect(await c.loadCollisionMetadata(reload: true), isTrue);
        expect(
          c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).isPlaced,
          isTrue,
        );
      },
    );
  }
  for (final scenario in ['unknown', 'neutral', 'outside', 'customDat']) {
    test(
      'layout policy keeps $scenario refusal distinct from missing power',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(
            failure: scenario == 'customDat' ? 'pylonRole' : null,
          ),
          chkBytesOverride: _layoutChkBytes(
            flags: scenario == 'unknown' ? 8 : 0,
            owner: scenario == 'neutral' ? 11 : 0,
            x: scenario == 'outside' ? 0 : 1024,
          ),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        final c = f.controller..setCheckPreplacedPower(true);
        final expected = scenario == 'unknown'
            ? ObjectPlacementDiagnosticCodes.preplacedPowerUnavailable
            : scenario == 'outside'
            ? ObjectPlacementDiagnosticCodes.outOfBounds
            : ObjectPlacementDiagnosticCodes.preplacedPowerStateUnsupported;
        expect(
          c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
          expected,
        );
        expect(
          c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
          expected,
        );
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  test(
    'layout policy reads current owner and UNITs after hover, delete, Undo and Redo',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        chkBytesOverride: _layoutChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller
        ..setCheckPreplacedPower(true)
        ..setContinuous(true);
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        isNull,
      );
      c.setOwner(1);
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
        ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
      );
      c.setOwner(0);
      final session = f.openMapController.state.session!;
      f.mapLayerController.selectObject(
        session: session,
        object: MapLayerObjectRef(
          layer: MapLayerType.units,
          sectionIndex: session.objectViews.unitSections.single.sectionIndex,
          recordIndex: 0,
        ),
      );
      expect(f.objectEditingController.deleteSelection(), isTrue);
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
        ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
      );
      expect(f.objectEditingController.state.undoDepth, 1);
      expect(f.objectEditingController.undo(), isTrue);
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        isNull,
      );
      expect(f.objectEditingController.redo(), isTrue);
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        ObjectPlacementDiagnosticCodes.preplacedPowerRequired,
      );
      expect(f.objectEditingController.undo(), isTrue);
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).isPlaced,
        isTrue,
      );
    },
  );
  test(
    'layout policy pending data cannot bypass Apply and never restores policy after free preset',
    () async {
      final gateway = _PowerCatalogGateway(hold: true);
      final f = await _openFixture(
        catalogGateway: gateway,
        chkBytesOverride: _layoutChkBytes(),
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(StarCraftPlacementKind.unit);
      c.confirm(c.state.items.single.key);
      c.setCheckPreplacedPower(true);
      final pending = c.loadCollisionMetadata();
      expect(
        c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
        PlacementPolicySupportStatus.loading,
      );
      expect(
        c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
        ObjectPlacementDiagnosticCodes.preplacedPowerUnavailable,
      );
      c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
      gateway.release.complete();
      expect(await pending, isTrue);
      expect(c.state.checkPreplacedPower, isFalse);
      expect(gateway.metadataRequests, 1);
      expect(f.objectEditingController.state.undoDepth, 0);
    },
  );
  test('layout policy respects raw/final bounds, locks and history', () async {
    final f = await _openFixture(
      catalogGateway: _PowerCatalogGateway(),
      chkBytesOverride: _layoutChkBytes(),
    );
    addTearDown(f.dispose);
    await _selectPowerUnit(f);
    final c = f.controller
      ..setCheckPreplacedPower(true)
      ..setPointSnap(enabled: true, step: 32);
    for (final x in [-1, 2047, 2048]) {
      expect(
        c.placeAt(pixelX: x, pixelY: 1024, tileX: x ~/ 32, tileY: 32).issueCode,
        ObjectPlacementDiagnosticCodes.outOfBounds,
      );
    }
    f.mapLayerController.setLocked(MapLayerType.units, true);
    expect(
      c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
      ObjectPlacementDiagnosticCodes.layerLocked,
    );
    f.mapLayerController.setLocked(MapLayerType.units, false);
    final owner = Object();
    f.openMapController.editHistory.beginTransaction(owner);
    expect(
      c.placeAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32).issueCode,
      ObjectPlacementDiagnosticCodes.historyBlocked,
    );
    f.openMapController.editHistory.endTransaction(owner);
    expect(f.objectEditingController.state.undoDepth, 0);
  });
  test(
    'layout policy confirmed no-psi is N/A and presets never enable projection',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresPsi: false),
        chkBytesOverride: _chkBytes(mapSize: 64),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller..setCheckPreplacedPower(true);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
        PlacementPolicySupportStatus.notApplicable,
      );
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        isNull,
      );
      c.setUnitPlacementPolicy(UnitPlacementPolicy.checked);
      expect(c.state.checkPreplacedPower, isFalse);
      c.setCheckPreplacedPower(true);
      c.setUnitPlacementPolicy(UnitPlacementPolicy.free);
      expect(c.state.checkPreplacedPower, isFalse);
    },
  );
  for (final kind in [
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test('$kind ignores UNIT layout power policy', () async {
      final f = await _openFixture(unitCapabilityAvailable: true);
      addTearDown(f.dispose);
      final c = f.controller
        ..setInstallationPath(_installationPath)
        ..setCheckPreplacedPower(true);
      await c.load(kind);
      c.confirm(c.state.items.first.key);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.preplacedPower],
        PlacementPolicySupportStatus.notApplicable,
      );
      expect(
        c.placeAt(pixelX: 64, pixelY: 64, tileX: 2, tileY: 2).isPlaced,
        isTrue,
      );
    });
  }
}

void _preplacedPowerTests() {
  const layout = UnitPowerStateModel.preplacedLayout;
  test(
    'layout adapter requires explicit model and preserves actual-state unknown',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
        chkBytesOverride: _layoutChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitPowerState(), isFalse);
      expect(
        c.lastUnitPowerStateRead!.errorCode,
        PreplacedUnitPowerStateGateway.modelUnavailable,
      );
      expect(_powerAt(f), UnitPowerCheck.unavailable);
      expect(await c.loadUnitPowerState(model: layout), isTrue);
      final session = f.openMapController.state.session!;
      final bytes = const RawChkEncoder().encode(session.rawDocument);
      final state = c.state;
      for (var i = 0; i < 5; i++) {
        final result = c.inspectUnitPowerAt(
          pixelX: 1024,
          pixelY: 1024,
          model: layout,
        );
        expect(result.check, UnitPowerCheck.powered);
        expect(result.model, layout);
        expect(result.providerId, PreplacedUnitPowerStateGateway.providerId);
        expect(result.stateRevision, PreplacedUnitPowerStateGateway.revision);
        final actual = c.inspectUnitPowerAt(pixelX: 1024, pixelY: 1024);
        expect(actual.check, UnitPowerCheck.unavailable);
        expect(actual.model, UnitPowerStateModel.initialMap);
        expect(actual.providerId, isNull);
        expect(actual.stateRevision, isNull);
      }
      expect(c.state, same(state));
      expect(f.openMapController.state.session, same(session));
      expect(const RawChkEncoder().encode(session.rawDocument), bytes);
      expect(f.objectEditingController.state.undoDepth, 0);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.power],
        PlacementPolicySupportStatus.notImplemented,
      );
      expect(
        await c.loadUnitPowerState(model: UnitPowerStateModel.live),
        isFalse,
      );
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
      expect(await c.loadUnitPowerState(model: layout), isTrue);
      expect(await c.loadUnitPowerState(), isFalse);
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
    },
  );
  for (final model in [
    UnitPowerStateModel.initialMap,
    UnitPowerStateModel.live,
  ]) {
    test('layout adapter does not provide actual $model facts', () async {
      final f = await _openFixture();
      addTearDown(f.dispose);
      final result = await const PreplacedUnitPowerStateGateway().read(
        UnitPowerStateRequest(
          operationId: 'unsupported-model',
          session: f.openMapController.state.session!,
          documentRevision: 0,
          installationPath: _installationPath,
          dataIdentity: ('s1', 13515, '0.7.0', 'abc'),
          model: model,
        ),
      );
      expect(result.isSuccess, isFalse);
      expect(result.snapshot, isNull);
      expect(result.errorCode, PreplacedUnitPowerStateGateway.modelUnavailable);
    });
  }
  for (final value in [0, 1, 100, 255]) {
    test(
      'layout completion is a declared convention, not HP $value inference',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
          chkBytesOverride: _layoutChkBytes(hp: value, validFields: 3),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(model: layout), isTrue);
        expect(_layoutPowerAt(f), UnitPowerCheck.powered);
        expect(_powerAt(f), UnitPowerCheck.unavailable);
      },
    );
  }
  final unknownCases = <String, Uint8List>{
    for (final flag in [1, 2, 4, 8, 32])
      'state-$flag': _layoutChkBytes(flags: flag),
    'valid-state': _layoutChkBytes(validStates: 32),
    'valid-fields': _layoutChkBytes(validFields: 65),
    'owner-valid': _layoutChkBytes(validFields: 0),
    'neutral-owner': _layoutChkBytes(owner: 11),
    'relation': _layoutChkBytes(relation: 1),
    'relation-id': _layoutChkBytes(relationId: 1),
    'unused': _layoutChkBytes(unused: 1),
    'invincible-without-valid': _layoutChkBytes(flags: 16),
  };
  for (final entry in unknownCases.entries) {
    test(
      'layout leaves ${entry.key} facts unknown, never assumes absence',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
          chkBytesOverride: entry.value,
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(model: layout), isTrue);
        final facts =
            f.controller.lastUnitPowerStateRead!.snapshot!.units.single;
        expect(facts.exists, isNull);
        expect(facts.isCompleted, isNull);
        expect(facts.isEnabled, isNull);
        expect(
          _layoutPowerAt(f),
          entry.key == 'owner-valid' || entry.key == 'neutral-owner'
              ? UnitPowerCheck.stateUnsupported
              : UnitPowerCheck.unavailable,
        );
      },
    );
  }
  test(
    'layout supports valid invincibility and preserves record identity',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
        chkBytesOverride: _layoutChkBytes(flags: 16, validStates: 16),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(await f.controller.loadUnitPowerState(model: layout), isTrue);
      expect(_layoutPowerAt(f), UnitPowerCheck.powered);
      final packet = f.controller.lastUnitPowerStateRead!.snapshot!;
      expect(packet.units.single.unit, same(packet.request.units.single));
      expect(() => packet.units.clear(), throwsUnsupportedError);
    },
  );
  for (final unitId in [null, 0]) {
    test(
      'layout without a Pylon $unitId is unpowered only in layout model',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
          chkBytesOverride: unitId == null
              ? _chkBytes(mapSize: 64)
              : _layoutChkBytes(unitId: unitId),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(model: layout), isTrue);
        expect(_layoutPowerAt(f), UnitPowerCheck.unpowered);
        expect(_powerAt(f), UnitPowerCheck.unavailable);
      },
    );
  }
  test(
    'layout invalidation survives Undo and Redo and requires explicit reload',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
        chkBytesOverride: _layoutChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitPowerState(model: layout), isTrue);
      expect(
        f.objectEditingController
            .placeCatalogUnit(
              capability: _PowerCatalogGateway().capability(0),
              unitId: 0,
              owner: 0,
              pixelX: 1800,
              pixelY: 1800,
            )
            .isPlaced,
        isTrue,
      );
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
      expect(f.objectEditingController.undo(), isTrue);
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
      expect(await c.loadUnitPowerState(model: layout), isTrue);
      expect(_layoutPowerAt(f), UnitPowerCheck.powered);
      expect(f.objectEditingController.redo(), isTrue);
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
    },
  );
  test('layout cannot authorize a modified Pylon DAT role', () async {
    final f = await _openFixture(
      catalogGateway: _PowerCatalogGateway(failure: 'pylonRole'),
      unitPowerStateGateway: const PreplacedUnitPowerStateGateway(),
      chkBytesOverride: _layoutChkBytes(),
    );
    addTearDown(f.dispose);
    await _selectPowerUnit(f);
    expect(await f.controller.loadUnitPowerState(model: layout), isTrue);
    expect(_layoutPowerAt(f), UnitPowerCheck.stateUnsupported);
  });
  for (final model in [UnitPowerStateModel.initialMap, layout]) {
    test(
      'power response must match explicitly requested $model model',
      () async {
        final gateway = _PowerStateGateway(
          modelOverride: model == layout
              ? UnitPowerStateModel.initialMap
              : layout,
        );
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: gateway,
          chkBytesOverride: _layoutChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(model: model), isFalse);
        expect(
          f.controller
              .inspectUnitPowerAt(pixelX: 1024, pixelY: 1024, model: model)
              .check,
          UnitPowerCheck.unavailable,
        );
      },
    );
  }
  test(
    'pending layout state cannot overwrite a newer actual-model request',
    () async {
      final gateway = _PowerStateGateway(hold: true);
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: gateway,
        chkBytesOverride: _layoutChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final first = f.controller.loadUnitPowerState(model: layout);
      final second = f.controller.loadUnitPowerState();
      expect(gateway.cancelled, contains(gateway.requests.first.operationId));
      gateway.release(gateway.requests.last);
      expect(await second, isTrue);
      gateway.release(gateway.requests.first);
      expect(await first, isFalse);
      expect(_layoutPowerAt(f), UnitPowerCheck.unavailable);
      expect(_powerAt(f), UnitPowerCheck.powered);
      expect(
        f.controller.lastUnitPowerStateRead!.snapshot!.model,
        UnitPowerStateModel.initialMap,
      );
    },
  );
}

UnitPowerCheck? _layoutPowerAt(_Fixture f) => f.controller
    .inspectUnitPowerAt(
      pixelX: 1024,
      pixelY: 1024,
      model: UnitPowerStateModel.preplacedLayout,
    )
    .check;

Uint8List _layoutChkBytes({
  int x = 1024,
  int flags = 0,
  int validStates = 0,
  int validFields = 1,
  int owner = 0,
  int hp = 100,
  int relation = 0,
  int relationId = 0,
  int unused = 0,
  int unitId = 156,
}) {
  final record = Uint8List.fromList(
    const UnitPlacementFactory()
        .create(
          capability: _PowerCatalogGateway().capability(unitId),
          unitId: unitId,
          owner: owner,
          x: x,
          y: 1024,
          classId: 1,
        )
        .bytes,
  );
  ByteData.sublistView(record)
    ..setUint16(10, relation, Endian.little)
    ..setUint16(12, validStates, Endian.little)
    ..setUint16(14, validFields, Endian.little)
    ..setUint8(17, hp)
    ..setUint16(26, flags, Endian.little)
    ..setUint32(28, unused, Endian.little)
    ..setUint32(32, relationId, Endian.little);
  return Uint8List.fromList([
    ..._chkBytes(mapSize: 64),
    ..._section('XTRA', [255, 0, 128]),
    ..._section('UNIT', record),
  ]);
}

void _unitCreepInspectionTests() {
  for (final failure in [null, 'input', 'setup']) {
    test(
      'creep validated intake $failure binds current CHK without editing',
      () async {
        final capture = SyntheticCreepCaptureGateway()..failure = failure;
        final gateway = ValidatedUnitCreepStateGateway(
          captureGateway: capture,
          configuration: syntheticCaptureConfiguration(),
        );
        final bytes = _powerChkBytes();
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(requiresCreep: true),
          unitCreepStateGateway: gateway,
          chkBytesOverride: bytes,
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        final session = f.openMapController.state.session!;
        expect(await f.controller.loadUnitCreepState(), failure == null);
        expect(
          _creepAt(f),
          failure == null ? UnitCreepCheck.covered : UnitCreepCheck.unavailable,
        );
        expect(capture.requests.single.scenarioChkBytes, bytes);
        expect(const RawChkEncoder().encode(session.rawDocument), bytes);
        expect(f.openMapController.state.session, same(session));
        expect(f.objectEditingController.state.undoDepth, 0);
        if (failure != null) {
          capture.failure = null;
          expect(await f.controller.loadUnitCreepState(), isTrue);
          expect(_creepAt(f), UnitCreepCheck.covered);
        }
      },
    );
  }
  Future<void> verifyUnobservedSource(
    Uint8List bytes, {
    bool loadTerrain = false,
    int? cv5Flags,
  }) async {
    final f = await _openFixture(
      catalogGateway: _PowerCatalogGateway(requiresCreep: true),
      terrainPlacementGateway: loadTerrain
          ? _TerrainPlacementGateway(cv5Flags: cv5Flags)
          : null,
      chkBytesOverride: bytes,
    );
    addTearDown(f.dispose);
    await _selectPowerUnit(f);
    final c = f.controller;
    if (loadTerrain) {
      expect(await c.loadTerrainPlacement(), isTrue);
      expect(c.lastTerrainPlacementRead!.source!.snapshot.tile(0), (
        buildable: true,
        walkableMask: 65535,
      ));
      expect(
        c.lastTerrainPlacementRead!.source!.snapshot.creepCandidateProfile
            ?.flagsForGroup(0),
        cv5Flags,
      );
    }
    final state = c.state;
    final session = f.openMapController.state.session!;
    expect(await c.loadUnitCreepState(), isFalse);
    expect(
      await c.loadUnitCreepState(model: UnitCreepStateModel.live),
      isFalse,
    );
    final result = c.inspectUnitCreepAt(pixelX: 1024, pixelY: 1024);
    expect(result.check, UnitCreepCheck.unavailable);
    expect(result.providerId, isNull);
    expect(result.stateRevision, isNull);
    expect(c.lastUnitCreepStateRead, isNull);
    expect(c.state, same(state));
    expect(f.openMapController.state.session, same(session));
    expect(const RawChkEncoder().encode(session.rawDocument), bytes);
    expect(f.objectEditingController.state.undoDepth, 0);
    expect(f.openMapController.editHistory.redoDepth, 0);
    expect(
      c.placementPolicySupport[PlacementPolicyRule.creep],
      PlacementPolicySupportStatus.notImplemented,
    );
  }

  for (final raw in [0, 0x0040, 0x4000, 0x8000, 0xffff]) {
    test(
      'creep source boundary: raw MTXM $raw is not an observation',
      () async {
        final terrain = ByteData(64 * 64 * 2);
        for (var i = 0; i < 64 * 64; i++) {
          terrain.setUint16(i * 2, raw, Endian.little);
        }
        await verifyUnobservedSource(
          _chkBytes(mapSize: 64, terrainBytes: terrain.buffer.asUint8List()),
        );
      },
    );
  }
  for (final flags in [0x1000, 0x4000, 0x5000]) {
    test(
      'creep source boundary: THG2 flags $flags are not tile coverage',
      () async {
        final sprite = ByteData(ChkSpritePlacement.recordLength)
          ..setUint16(0, 131, Endian.little)
          ..setUint16(2, 1024, Endian.little)
          ..setUint16(4, 1024, Endian.little)
          ..setUint16(8, flags, Endian.little);
        await verifyUnobservedSource(
          Uint8List.fromList([
            ..._chkBytes(mapSize: 64),
            ..._section('THG2', sprite.buffer.asUint8List()),
          ]),
        );
      },
    );
  }
  for (final id in [131, 132, 133, 143]) {
    test(
      'creep source boundary: preplaced producer ID $id is not observed spread',
      () async {
        final record = const UnitPlacementFactory().create(
          capability: _PowerCatalogGateway().capability(id),
          unitId: id,
          owner: 0,
          x: 1024,
          y: 1024,
          classId: 1,
        );
        await verifyUnobservedSource(
          Uint8List.fromList([
            ..._chkBytes(mapSize: 64),
            ..._section('UNIT', record.bytes),
          ]),
        );
      },
    );
  }
  for (final fog in [0, 255]) {
    test(
      'creep source boundary: initial MASK $fog is not observer visibility',
      () async {
        await verifyUnobservedSource(
          Uint8List.fromList([
            ..._chkBytes(mapSize: 64),
            ..._section('MASK', List.filled(64 * 64, fog)),
          ]),
        );
      },
    );
  }
  test(
    'creep source boundary: buildable walkable terrain and empty UNIT remain unknown',
    () async {
      await verifyUnobservedSource(_chkBytes(mapSize: 64), loadTerrain: true);
    },
  );
  for (final flags in [
    0,
    0x40,
    0x1000,
    0x1040,
    0x4000,
    0x4040,
    0x5000,
    0x5040,
  ]) {
    test(
      'creep source boundary: CV5 candidate flags $flags are not coverage',
      () async {
        await verifyUnobservedSource(
          _chkBytes(mapSize: 64),
          loadTerrain: true,
          cv5Flags: flags,
        );
      },
    );
  }
  test(
    'creep requires an explicit collector and never guesses current UNITs',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(await f.controller.loadUnitCreepState(), isFalse);
      final inspection = f.controller.inspectUnitCreepAt(
        pixelX: 1024,
        pixelY: 1024,
      );
      expect(inspection.check, UnitCreepCheck.unavailable);
      expect(inspection.point, (x: 1024, y: 1024));
      expect(inspection.providerId, isNull);
      expect(inspection.stateRevision, isNull);
      expect(f.controller.lastUnitCreepStateRead, isNull);
    },
  );
  test(
    'creep explicit reads coalesce; inspection is read-only and owner independent',
    () async {
      final gateway = _CreepStateGateway(hold: true);
      final catalog = _PowerCatalogGateway(requiresCreep: true);
      final f = await _openFixture(
        catalogGateway: catalog,
        unitCreepStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(_creepAt(f), UnitCreepCheck.unavailable);
      expect(gateway.requests, isEmpty);
      final pending = c.loadUnitCreepState();
      expect(c.loadUnitCreepState(), same(pending));
      expect(_creepAt(f), UnitCreepCheck.unavailable);
      gateway.release(gateway.requests.single);
      expect(await pending, isTrue);
      final session = f.openMapController.state.session!;
      final bytes = const RawChkEncoder().encode(session.rawDocument);
      final state = c.state;
      final dirty = session.isDirty;
      for (var i = 0; i < 10; i++) {
        expect(_creepAt(f), UnitCreepCheck.covered);
        expect(_creepAt(f, x: 1023), UnitCreepCheck.missing);
      }
      expect(c.state, same(state));
      expect(f.openMapController.state.session, same(session));
      expect(session.isDirty, dirty);
      expect(const RawChkEncoder().encode(session.rawDocument), bytes);
      expect(f.objectEditingController.state.undoDepth, 0);
      expect(f.openMapController.editHistory.redoDepth, 0);
      expect(catalog.metadataRequests, 1);
      expect(await c.loadUnitCreepState(), isTrue);
      expect(gateway.requests, hasLength(1));
      c.setOwner(1);
      expect(_creepAt(f), UnitCreepCheck.covered);
      final inspection = c.inspectUnitCreepAt(pixelX: 1024, pixelY: 1024);
      expect(inspection.model, UnitCreepStateModel.initialMap);
      expect(inspection.providerId, 'synthetic-creep');
      expect(inspection.stateRevision, contains('unit-creep-'));
      expect(
        c.placementPolicySupport[PlacementPolicyRule.creep],
        PlacementPolicySupportStatus.notImplemented,
      );
      expect(
        c.previewAt(pixelX: 1023, pixelY: 1024, tileX: 31, tileY: 32),
        isNull,
      );
      expect(
        () => c.lastUnitCreepStateRead!.snapshot!.coverage.tiles.clear(),
        throwsUnsupportedError,
      );
    },
  );
  for (final alignment in ['point', 'building']) {
    test(
      'creep inspection uses final $alignment footprint, not raw hover',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(requiresCreep: true),
          unitCreepStateGateway: _CreepStateGateway(),
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitCreepState(), isTrue);
        expect(_creepAt(f, x: 1023), UnitCreepCheck.missing);
        f.controller.setPointSnap(enabled: alignment == 'point', step: 32);
        f.controller.setBuildingTileAlignment(alignment == 'building');
        final result = f.controller.inspectUnitCreepAt(
          pixelX: 1023,
          pixelY: 1024,
        );
        expect(result.point, (x: 1024, y: 1024));
        expect(result.check, UnitCreepCheck.covered);
      },
    );
  }
  test(
    'creep retains common safety guards and ignores optional placement policies',
    () async {
      final gateway = _CreepStateGateway();
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitCreepState(), isTrue);
      c.setPointSnap(enabled: true, step: 32);
      for (final x in [-1, 2047, 2048, 0x7fffffffffffffff]) {
        final result = c.inspectUnitCreepAt(pixelX: x, pixelY: 1024);
        expect(result.issueCode, ObjectPlacementDiagnosticCodes.outOfBounds);
        expect(result.check, isNull);
        expect(result.point, isNull);
        expect(result.model, isNull);
      }
      for (final hidden in [false, true]) {
        f.mapLayerController.setLocked(MapLayerType.units, !hidden);
        f.mapLayerController.setVisible(MapLayerType.units, !hidden);
        expect(
          c.inspectUnitCreepAt(pixelX: 1024, pixelY: 1024).issueCode,
          ObjectPlacementDiagnosticCodes.layerLocked,
        );
      }
      f.mapLayerController.setVisible(MapLayerType.units, true);
      final owner = Object();
      f.openMapController.editHistory.beginTransaction(owner);
      expect(
        c.inspectUnitCreepAt(pixelX: 1024, pixelY: 1024).issueCode,
        ObjectPlacementDiagnosticCodes.historyBlocked,
      );
      expect(await c.loadUnitCreepState(), isFalse);
      f.openMapController.editHistory.endTransaction(owner);
      expect(await c.loadUnitCreepState(), isTrue);
      c.setCheckUnitTerrain(true);
      c.setAllowUnitOverlap(false);
      c.setCheckResourceDistance(true);
      c.setCheckPreplacedPower(true);
      await c.loadCollisionMetadata();
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        ObjectPlacementDiagnosticCodes.unitTerrainUnavailable,
      );
      expect(_creepAt(f), UnitCreepCheck.covered);
      expect(gateway.requests, hasLength(2));
    },
  );
  test(
    'creep failed reload never revives an older successful observation',
    () async {
      final gateway = _CreepStateGateway();
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitCreepState(), isTrue);
      gateway.failure = 'error';
      expect(await c.loadUnitCreepState(reload: true), isFalse);
      expect(_creepAt(f), UnitCreepCheck.unavailable);
      expect(c.lastUnitCreepStateRead!.errorCode, 'SYNTHETIC_FAILURE');
      expect(
        c.inspectUnitCreepAt(pixelX: 1024, pixelY: 1024).providerId,
        isNull,
      );
      gateway.failure = null;
      expect(await c.loadUnitCreepState(), isTrue);
      expect(_creepAt(f), UnitCreepCheck.covered);
      expect(gateway.requests, hasLength(3));
    },
  );
  test(
    'creep whole-box result is distinct from point preflight refusal',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: _CreepStateGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(await f.controller.loadUnitCreepState(), isTrue);
      final result = f.controller.inspectUnitCreepAt(pixelX: 16, pixelY: 1024);
      expect(result.point, (x: 16, y: 1024));
      expect(result.issueCode, isNull);
      expect(result.check, UnitCreepCheck.outOfBounds);
    },
  );
  for (final failure in [
    'sync',
    'throw',
    'error',
    'nonzeroExit',
    'empty',
    'request',
    'provider',
    'revision',
    'model',
    'rules',
    'width',
    'height',
    'observationMissing',
    'observationPhase',
    'observationFrame',
    'observationAuthority',
    'observationRules',
    'observationSize',
  ]) {
    test(
      'creep rejects $failure response and explicit retry recovers',
      () async {
        final gateway = _CreepStateGateway(failure: failure);
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(requiresCreep: true),
          unitCreepStateGateway: gateway,
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitCreepState(), isFalse);
        expect(_creepAt(f), UnitCreepCheck.unavailable);
        final rejected = f.controller.lastUnitCreepStateRead;
        if (failure != 'sync' && failure != 'throw') {
          expect(rejected!.stdout, contains('not game evidence'));
          expect(rejected.stderr, 'synthetic raw diagnostic');
        }
        gateway.failure = null;
        expect(await f.controller.loadUnitCreepState(), isTrue);
        expect(_creepAt(f), UnitCreepCheck.covered);
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  for (final authority in [
    UnitCreepObservationAuthority.fullMap,
    UnitCreepObservationAuthority.playerVision,
  ]) {
    for (final fill in [UnitCreepTile.present, UnitCreepTile.absent]) {
      test(
        'creep $authority unobserved $fill remains unknown without mutation',
        () async {
          final gateway = _CreepStateGateway(
            fill: fill,
            authority: authority,
            observationsVisible: false,
          );
          final bytes = _powerChkBytes();
          final f = await _openFixture(
            catalogGateway: _PowerCatalogGateway(requiresCreep: true),
            unitCreepStateGateway: gateway,
            chkBytesOverride: bytes,
          );
          addTearDown(f.dispose);
          await _selectPowerUnit(f);
          final session = f.openMapController.state.session!;
          final state = f.controller.state;
          expect(await f.controller.loadUnitCreepState(), isTrue);
          final result = f.controller.inspectUnitCreepAt(
            pixelX: 1024,
            pixelY: 1024,
          );
          expect(result.check, UnitCreepCheck.unavailable);
          expect(result.providerId, 'synthetic-creep');
          expect(gateway.requests, hasLength(1));
          expect(await f.controller.loadUnitCreepState(), isTrue);
          expect(gateway.requests, hasLength(1));
          expect(f.controller.state, same(state));
          expect(f.openMapController.state.session, same(session));
          expect(const RawChkEncoder().encode(session.rawDocument), bytes);
          expect(f.objectEditingController.state.undoDepth, 0);
          expect(f.openMapController.editHistory.redoDepth, 0);
          expect(
            f
                .controller
                .lastUnitCreepStateRead!
                .snapshot!
                .observation!
                .authority,
            authority,
          );
        },
      );
    }
  }
  for (final fill in [UnitCreepTile.absent, UnitCreepTile.unknown]) {
    test(
      'creep successful collection preserves explicit $fill observation',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(requiresCreep: true),
          unitCreepStateGateway: _CreepStateGateway(fill: fill),
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitCreepState(), isTrue);
        final result = f.controller.inspectUnitCreepAt(
          pixelX: 1024,
          pixelY: 1024,
        );
        expect(
          result.check,
          fill == UnitCreepTile.absent
              ? UnitCreepCheck.missing
              : UnitCreepCheck.unavailable,
        );
        expect(result.providerId, 'synthetic-creep');
        expect(result.stateRevision, isNotEmpty);
      },
    );
  }
  for (final failure in ['source', 'coverage', 'role', 'geometry', 'box']) {
    test(
      'creep rejects $failure DAT metadata; explicit reload recovers',
      () async {
        final catalog = _PowerCatalogGateway(
          requiresCreep: true,
          failure: failure,
        );
        final f = await _openFixture(
          catalogGateway: catalog,
          unitCreepStateGateway: _CreepStateGateway(),
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        await f.controller.loadUnitCreepState();
        expect(_creepAt(f), UnitCreepCheck.unavailable);
        catalog.failure = null;
        expect(await f.controller.loadCollisionMetadata(reload: true), isTrue);
        expect(await f.controller.loadUnitCreepState(), isTrue);
        expect(_creepAt(f), UnitCreepCheck.covered);
      },
    );
  }
  test(
    'creep known no-requirement is N/A without collection; legacy stays unknown',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(_creepAt(f), UnitCreepCheck.notApplicable);
      final legacy = await _openFixture(
        catalogGateway: _CollisionGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(legacy.dispose);
      await _selectPowerUnit(legacy);
      expect(_creepAt(legacy), UnitCreepCheck.unavailable);
    },
  );
  for (final pending in [false, true]) {
    for (final change in [
      'editUndo',
      'terrainUndo',
      'history',
      'installation',
      'session',
      'metadata',
      'reopen',
      'dispose',
    ]) {
      test(
        'creep ${pending ? 'pending' : 'cached'} packet is invalidated by $change',
        () async {
          final gateway = _CreepStateGateway(hold: pending);
          final f = await _openFixture(
            catalogGateway: _PowerCatalogGateway(requiresCreep: true),
            unitCreepStateGateway: gateway,
            chkBytesOverride: _powerChkBytes(),
          );
          addTearDown(f.dispose);
          await _selectPowerUnit(f);
          final c = f.controller;
          final read = c.loadUnitCreepState();
          if (!pending) expect(await read, isTrue);
          switch (change) {
            case 'editUndo':
              expect(
                f.objectEditingController
                    .placeCatalogUnit(
                      capability: _PowerCatalogGateway().capability(0),
                      unitId: 0,
                      owner: 0,
                      pixelX: 1800,
                      pixelY: 1800,
                    )
                    .isPlaced,
                isTrue,
              );
              expect(_creepAt(f), UnitCreepCheck.unavailable);
              expect(f.objectEditingController.undo(), isTrue);
            case 'terrainUndo':
              final terrain = f.terrainEditingController;
              expect(terrain.selectCatalogTile(16), isTrue);
              expect(terrain.beginBrushStroke(), isTrue);
              expect(
                terrain.paintTiles([const TerrainTileCoordinate(x: 2, y: 2)]),
                isTrue,
              );
              expect(terrain.commitBrushStroke(), isTrue);
              expect(_creepAt(f), UnitCreepCheck.unavailable);
              expect(terrain.undo(), isTrue);
            case 'history':
              final owner = Object();
              f.openMapController.editHistory.beginTransaction(owner);
              f.openMapController.editHistory.endTransaction(owner);
            case 'installation':
              c.setInstallationPath(r'C:\Other');
              c.setInstallationPath(_installationPath);
            case 'session':
              c.synchronizeSession(null);
            case 'metadata':
              expect(await c.loadCollisionMetadata(reload: true), isTrue);
            case 'reopen':
              await f.openMapController.open(
                sourcePath: r'C:\Maps\Catalog.scx',
              );
            case 'dispose':
              await f.dispose();
          }
          if (pending) {
            expect(
              gateway.cancelled,
              contains(gateway.requests.single.operationId),
            );
            gateway.release(gateway.requests.single);
            expect(await read, isFalse);
          }
          expect(c.lastUnitCreepStateRead, isNull);
          if (change != 'dispose') {
            await _selectPowerUnit(f);
            expect(_creepAt(f), UnitCreepCheck.unavailable);
            gateway.hold = false;
            expect(await c.loadUnitCreepState(), isTrue);
            expect(_creepAt(f), UnitCreepCheck.covered);
          } else {
            expect(await c.loadUnitCreepState(), isFalse);
          }
        },
      );
    }
  }
  for (final failCancel in ['sync', 'async']) {
    test(
      'creep late reply cannot overwrite reload when $failCancel cancel fails',
      () async {
        final gateway = _CreepStateGateway(hold: true, failCancel: failCancel);
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(requiresCreep: true),
          unitCreepStateGateway: gateway,
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        final c = f.controller;
        final first = c.loadUnitCreepState();
        final second = c.loadUnitCreepState(reload: true);
        gateway.release(gateway.requests.last);
        expect(await second, isTrue);
        final latest = c.lastUnitCreepStateRead;
        gateway.failure = 'error';
        gateway.release(gateway.requests.first);
        expect(await first, isFalse);
        expect(c.lastUnitCreepStateRead, same(latest));
        expect(_creepAt(f), UnitCreepCheck.covered);
      },
    );
  }
  test(
    'creep live requests are refused without fallback or retaining initial cache',
    () async {
      final gateway = _CreepStateGateway(hold: true);
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      final read = c.loadUnitCreepState();
      expect(
        await c.loadUnitCreepState(model: UnitCreepStateModel.live),
        isFalse,
      );
      expect(gateway.requests, hasLength(1));
      expect(gateway.cancelled, contains(gateway.requests.single.operationId));
      gateway.release(gateway.requests.single);
      expect(await read, isFalse);
      gateway.hold = false;
      expect(await c.loadUnitCreepState(), isTrue);
      expect(
        c
            .inspectUnitCreepAt(
              pixelX: 1024,
              pixelY: 1024,
              model: UnitCreepStateModel.live,
            )
            .check,
        UnitCreepCheck.unavailable,
      );
      expect(
        await c.loadUnitCreepState(model: UnitCreepStateModel.live),
        isFalse,
      );
      expect(_creepAt(f), UnitCreepCheck.unavailable);
      expect(c.lastUnitCreepStateRead, isNull);
    },
  );
  test(
    'creep and power collection remain separate on explicit reload',
    () async {
      final power = _PowerStateGateway();
      final creep = _CreepStateGateway();
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: creep,
        unitPowerStateGateway: power,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitPowerState(), isTrue);
      expect(await c.loadUnitCreepState(), isTrue);
      final powerRead = c.lastUnitPowerStateRead;
      expect(await c.loadUnitCreepState(reload: true), isTrue);
      expect(c.lastUnitPowerStateRead, same(powerRead));
      expect(power.requests, hasLength(1));
      expect(creep.requests, hasLength(2));
      expect(power.cancelled, isEmpty);
    },
  );
  test(
    'creep reload cancels only its pending operation, not pending power',
    () async {
      final power = _PowerStateGateway(hold: true);
      final creep = _CreepStateGateway(hold: true);
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresCreep: true),
        unitCreepStateGateway: creep,
        unitPowerStateGateway: power,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      final powerRead = c.loadUnitPowerState();
      final oldCreep = c.loadUnitCreepState();
      final newCreep = c.loadUnitCreepState(reload: true);
      expect(c.loadUnitPowerState(), same(powerRead));
      expect(power.cancelled, isEmpty);
      expect(creep.cancelled, [creep.requests.first.operationId]);
      power.release(power.requests.single);
      creep.release(creep.requests.last);
      expect(await powerRead, isTrue);
      expect(await newCreep, isTrue);
      final latestPower = c.lastUnitPowerStateRead;
      final latestCreep = c.lastUnitCreepStateRead;
      creep.release(creep.requests.first);
      expect(await oldCreep, isFalse);
      expect(c.lastUnitPowerStateRead, same(latestPower));
      expect(c.lastUnitCreepStateRead, same(latestCreep));
    },
  );
  for (final kind in [
    StarCraftPlacementKind.tile,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test(
      'creep $kind inspection is not applicable and never collects',
      () async {
        final gateway = _CreepStateGateway();
        final f = await _openFixture(
          unitCapabilityAvailable: true,
          unitCreepStateGateway: gateway,
        );
        addTearDown(f.dispose);
        final c = f.controller..setInstallationPath(_installationPath);
        await c.load(kind);
        c.confirm(c.state.items.first.key);
        final result = c.inspectUnitCreepAt(pixelX: 64, pixelY: 64);
        expect(result.check, UnitCreepCheck.notApplicable);
        expect(result.point, isNull);
        expect(result.model, isNull);
        expect(await c.loadUnitCreepState(), isFalse);
        expect(gateway.requests, isEmpty);
      },
    );
  }
}

UnitCreepCheck? _creepAt(_Fixture f, {int x = 1024}) =>
    f.controller.inspectUnitCreepAt(pixelX: x, pixelY: 1024).check;

final class _CreepStateGateway implements UnitCreepStateGateway {
  _CreepStateGateway({
    this.failure,
    this.hold = false,
    this.failCancel,
    this.fill = UnitCreepTile.present,
    this.observationsVisible = true,
    this.authority = UnitCreepObservationAuthority.fullMap,
  });
  String? failure;
  bool hold;
  final String? failCancel;
  final UnitCreepTile fill;
  final bool observationsVisible;
  final UnitCreepObservationAuthority authority;
  final requests = <UnitCreepStateRequest>[];
  final cancelled = <String>[];
  final _pending = <String, Completer<void>>{};
  void release(UnitCreepStateRequest request) =>
      _pending[request.operationId]!.complete();
  @override
  Future<UnitCreepStateReadResult> read(UnitCreepStateRequest request) {
    requests.add(request);
    if (failure == 'sync') throw StateError('Synthetic synchronous failure');
    return () async {
      if (hold) {
        await (_pending[request.operationId] = Completer<void>()).future;
      }
      if (failure == 'throw') {
        throw StateError('Synthetic asynchronous failure');
      }
      final dim = request.session.metadataViews.dimensions.single;
      final width = failure == 'width' ? dim.width - 1 : dim.width;
      final height = failure == 'height' ? dim.height - 1 : dim.height;
      final tiles = List.filled(width * height, fill);
      tiles[32 * width + 30] = UnitCreepTile.absent;
      return UnitCreepStateReadResult(
        snapshot: failure == 'empty'
            ? null
            : UnitCreepStateSnapshot(
                request: failure == 'request'
                    ? UnitCreepStateRequest(
                        operationId: request.operationId,
                        session: request.session,
                        documentRevision: request.documentRevision,
                        installationPath: request.installationPath,
                        dataIdentity: request.dataIdentity,
                        model: request.model,
                      )
                    : request,
                providerId: failure == 'provider' ? ' ' : 'synthetic-creep',
                revision: failure == 'revision'
                    ? ''
                    : 'synthetic-${request.operationId}',
                model: failure == 'model'
                    ? UnitCreepStateModel.live
                    : request.model,
                creepModelRevision: failure == 'rules'
                    ? 'other'
                    : UnitCreepCatalog.revision,
                observation: failure == 'observationMissing'
                    ? null
                    : syntheticCreepObservation(
                        width: failure == 'observationSize'
                            ? dim.width - 1
                            : dim.width,
                        height: dim.height,
                        contractRevision: failure == 'observationRules'
                            ? 'unsupported-contract'
                            : UnitCreepObservation.revision,
                        phase: failure == 'observationPhase'
                            ? UnitCreepObservationPhase.running
                            : UnitCreepObservationPhase
                                  .initializedBeforeFirstTriggerCycle,
                        simulationFrame: failure == 'observationFrame' ? 1 : 0,
                        authority: failure == 'observationAuthority'
                            ? UnitCreepObservationAuthority.unverified
                            : authority,
                        observerPlayer:
                            authority ==
                                UnitCreepObservationAuthority.playerVision
                            ? 0
                            : null,
                        observedTiles: failure == 'observationSize'
                            ? null
                            : List.filled(
                                dim.width * dim.height,
                                observationsVisible,
                              ),
                      ),
                coverage: UnitCreepCoverage(
                  width: width,
                  height: height,
                  tiles: tiles,
                ),
              ),
        errorCode: failure == 'error' ? 'SYNTHETIC_FAILURE' : null,
        exitCode: failure == 'nonzeroExit' ? 1 : 0,
        stdout: 'synthetic observation, not game evidence',
        stderr: 'synthetic raw diagnostic',
      );
    }();
  }

  @override
  Future<void> cancel(String operationId) {
    cancelled.add(operationId);
    if (failCancel == 'sync') {
      throw StateError('Synthetic synchronous cancel failure');
    }
    return failCancel == 'async'
        ? Future.error(StateError('Synthetic asynchronous cancel failure'))
        : Future.value();
  }
}

void _unitPowerInspectionTests() {
  test(
    'power without a state adapter stays unknown and never guesses CHK',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(await f.controller.loadUnitPowerState(), isFalse);
      expect(_powerAt(f), UnitPowerCheck.unavailable);
      expect(f.controller.lastUnitPowerStateRead, isNull);
    },
  );
  test(
    'power explicit collection coalesces; hover is read-only and uses current owner',
    () async {
      final gateway = _PowerStateGateway(hold: true);
      final catalog = _PowerCatalogGateway();
      final f = await _openFixture(
        catalogGateway: catalog,
        unitPowerStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(_powerAt(f), UnitPowerCheck.unavailable);
      expect(gateway.requests, isEmpty);
      final pending = c.loadUnitPowerState();
      expect(c.loadUnitPowerState(), same(pending));
      expect(_powerAt(f), UnitPowerCheck.unavailable);
      gateway.release(gateway.requests.single);
      expect(await pending, isTrue);
      final session = f.openMapController.state.session!;
      final bytes = const RawChkEncoder().encode(session.rawDocument);
      final state = c.state;
      for (var i = 0; i < 10; i++) {
        expect(_powerAt(f), UnitPowerCheck.powered);
        expect(_powerAt(f, x: 768), UnitPowerCheck.unpowered);
      }
      expect(c.state, same(state));
      expect(f.openMapController.state.session, same(session));
      expect(const RawChkEncoder().encode(session.rawDocument), bytes);
      expect(f.objectEditingController.state.undoDepth, 0);
      expect(f.openMapController.editHistory.redoDepth, 0);
      expect(gateway.requests, hasLength(1));
      expect(catalog.metadataRequests, 1);
      expect(await c.loadUnitPowerState(), isTrue);
      expect(gateway.requests, hasLength(1));
      c.setOwner(1);
      expect(_powerAt(f), UnitPowerCheck.unpowered);
      c.setOwner(0);
      expect(_powerAt(f), UnitPowerCheck.powered);
      expect(
        c.placementPolicySupport[PlacementPolicyRule.power],
        PlacementPolicySupportStatus.notImplemented,
      );
      expect(
        c.previewAt(pixelX: 768, pixelY: 1024, tileX: 24, tileY: 32),
        isNull,
      );
      final request = gateway.requests.single;
      expect(() => request.units.clear(), throwsUnsupportedError);
      expect(
        () => c.lastUnitPowerStateRead!.snapshot!.units.clear(),
        throwsUnsupportedError,
      );
    },
  );
  for (final alignment in ['point', 'building']) {
    test('power inspection uses final $alignment coordinate', () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: _PowerStateGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(await f.controller.loadUnitPowerState(), isTrue);
      expect(_powerAt(f, x: 769), UnitPowerCheck.powered);
      f.controller.setPointSnap(enabled: true, step: 32);
      f.controller.setBuildingTileAlignment(alignment == 'building');
      final result = f.controller.inspectUnitPowerAt(pixelX: 769, pixelY: 1024);
      expect(result.point, (x: 768, y: 1024));
      expect(result.check, UnitPowerCheck.unpowered);
    });
  }
  test(
    'power retains raw/final bounds, layer and history guards, not optional policy refusals',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: _PowerStateGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      expect(await c.loadUnitPowerState(), isTrue);
      c.setPointSnap(enabled: true, step: 32);
      for (final x in [-1, 2047, 2048, 0x7fffffffffffffff]) {
        final result = c.inspectUnitPowerAt(pixelX: x, pixelY: 1024);
        expect(result.issueCode, ObjectPlacementDiagnosticCodes.outOfBounds);
        expect(result.check, isNull);
        expect(result.point, isNull);
      }
      f.mapLayerController.setLocked(MapLayerType.units, true);
      expect(
        c.inspectUnitPowerAt(pixelX: 1024, pixelY: 1024).issueCode,
        ObjectPlacementDiagnosticCodes.layerLocked,
      );
      f.mapLayerController.setLocked(MapLayerType.units, false);
      final owner = Object();
      f.openMapController.editHistory.beginTransaction(owner);
      expect(
        c.inspectUnitPowerAt(pixelX: 1024, pixelY: 1024).issueCode,
        ObjectPlacementDiagnosticCodes.historyBlocked,
      );
      expect(await c.loadUnitPowerState(), isFalse);
      f.openMapController.editHistory.endTransaction(owner);
      expect(await c.loadUnitPowerState(), isTrue);
      c.setCheckUnitTerrain(true);
      c.setAllowUnitOverlap(false);
      expect(
        c.previewAt(pixelX: 1024, pixelY: 1024, tileX: 32, tileY: 32),
        ObjectPlacementDiagnosticCodes.unitTerrainUnavailable,
      );
      expect(_powerAt(f), UnitPowerCheck.powered);
    },
  );
  for (final failure in [
    'sync',
    'throw',
    'error',
    'nonzeroExit',
    'request',
    'provider',
    'revision',
    'model',
    'powerModel',
    'coverage',
    'record',
    'order',
    'duplicate',
  ]) {
    test(
      'power rejects $failure packets and explicit retry recovers',
      () async {
        final gateway = _PowerStateGateway(failure: failure);
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: gateway,
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(), isFalse);
        expect(_powerAt(f), UnitPowerCheck.unavailable);
        gateway.failure = null;
        expect(await f.controller.loadUnitPowerState(), isTrue);
        expect(_powerAt(f), UnitPowerCheck.powered);
        expect(f.objectEditingController.state.undoDepth, 0);
      },
    );
  }
  for (final failure in ['unknown', 'disabled']) {
    test(
      'power accepts explicit $failure facts without upgrading them to supply',
      () async {
        final f = await _openFixture(
          catalogGateway: _PowerCatalogGateway(),
          unitPowerStateGateway: _PowerStateGateway(failure: failure),
          chkBytesOverride: _powerChkBytes(),
        );
        addTearDown(f.dispose);
        await _selectPowerUnit(f);
        expect(await f.controller.loadUnitPowerState(), isTrue);
        expect(
          _powerAt(f),
          failure == 'unknown'
              ? UnitPowerCheck.unavailable
              : UnitPowerCheck.stateUnsupported,
        );
      },
    );
  }
  for (final failure in ['source', 'coverage', 'role']) {
    test('power rejects $failure metadata and reload recovers', () async {
      final catalog = _PowerCatalogGateway(failure: failure);
      final f = await _openFixture(
        catalogGateway: catalog,
        unitPowerStateGateway: _PowerStateGateway(),
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      await f.controller.loadUnitPowerState();
      expect(_powerAt(f), UnitPowerCheck.unavailable);
      catalog.failure = null;
      expect(await f.controller.loadCollisionMetadata(reload: true), isTrue);
      expect(await f.controller.loadUnitPowerState(), isTrue);
      expect(_powerAt(f), UnitPowerCheck.powered);
    });
  }
  test(
    'power known no-psi needs no state packet, legacy unknown does',
    () async {
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(requiresPsi: false),
        chkBytesOverride: _chkBytes(mapSize: 64),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      expect(_powerAt(f), UnitPowerCheck.notApplicable);
      final legacy = await _openFixture(
        catalogGateway: _CollisionGateway(),
        chkBytesOverride: _chkBytes(mapSize: 64),
      );
      addTearDown(legacy.dispose);
      await _selectPowerUnit(legacy);
      expect(_powerAt(legacy), UnitPowerCheck.unavailable);
    },
  );
  for (final pending in [false, true]) {
    for (final change in [
      'editUndo',
      'history',
      'installation',
      'session',
      'metadata',
      'reopen',
      'dispose',
    ]) {
      test(
        'power ${pending ? 'pending' : 'cached'} state is discarded after $change',
        () async {
          final gateway = _PowerStateGateway(hold: pending);
          final f = await _openFixture(
            catalogGateway: _PowerCatalogGateway(),
            unitPowerStateGateway: gateway,
            chkBytesOverride: _powerChkBytes(),
          );
          await _selectPowerUnit(f);
          final c = f.controller;
          final read = c.loadUnitPowerState();
          if (!pending) expect(await read, isTrue);
          switch (change) {
            case 'editUndo':
              expect(
                f.objectEditingController
                    .placeCatalogUnit(
                      capability: _PowerCatalogGateway().capability(0),
                      unitId: 0,
                      owner: 0,
                      pixelX: 1800,
                      pixelY: 1800,
                    )
                    .isPlaced,
                isTrue,
              );
              expect(_powerAt(f), UnitPowerCheck.unavailable);
              expect(f.objectEditingController.undo(), isTrue);
            case 'history':
              final owner = Object();
              f.openMapController.editHistory.beginTransaction(owner);
              f.openMapController.editHistory.endTransaction(owner);
            case 'installation':
              c.setInstallationPath(r'C:\Other');
              c.setInstallationPath(_installationPath);
            case 'session':
              c.synchronizeSession(null);
            case 'metadata':
              expect(await c.loadCollisionMetadata(reload: true), isTrue);
            case 'reopen':
              await f.openMapController.open(
                sourcePath: r'C:\Maps\Catalog.scx',
              );
            case 'dispose':
              await f.dispose();
          }
          if (pending) {
            expect(
              gateway.cancelled,
              contains(gateway.requests.single.operationId),
            );
            gateway.release(gateway.requests.single);
            expect(await read, isFalse);
          }
          expect(c.lastUnitPowerStateRead, isNull);
          if (change != 'dispose') {
            await _selectPowerUnit(f);
            expect(_powerAt(f), UnitPowerCheck.unavailable);
            gateway.hold = false;
            expect(await c.loadUnitPowerState(), isTrue);
            expect(_powerAt(f), UnitPowerCheck.powered);
            await f.dispose();
          } else {
            expect(await c.loadUnitPowerState(), isFalse);
          }
        },
      );
    }
  }
  test(
    'power older response cannot replace a newer reload, even when cancel fails',
    () async {
      final gateway = _PowerStateGateway(hold: true, failCancel: true);
      final f = await _openFixture(
        catalogGateway: _PowerCatalogGateway(),
        unitPowerStateGateway: gateway,
        chkBytesOverride: _powerChkBytes(),
      );
      addTearDown(f.dispose);
      await _selectPowerUnit(f);
      final c = f.controller;
      final first = c.loadUnitPowerState();
      final second = c.loadUnitPowerState(reload: true);
      gateway.release(gateway.requests.last);
      expect(await second, isTrue);
      final latest = c.lastUnitPowerStateRead;
      gateway.release(gateway.requests.first);
      expect(await first, isFalse);
      expect(c.lastUnitPowerStateRead, same(latest));
      expect(_powerAt(f), UnitPowerCheck.powered);
    },
  );
  for (final kind in [
    StarCraftPlacementKind.tile,
    StarCraftPlacementKind.pureSprite,
    StarCraftPlacementKind.spriteUnit,
    StarCraftPlacementKind.doodad,
  ]) {
    test('$kind power query is not applicable and collects no state', () async {
      final gateway = _PowerStateGateway();
      final f = await _openFixture(
        unitCapabilityAvailable: true,
        unitPowerStateGateway: gateway,
      );
      addTearDown(f.dispose);
      final c = f.controller..setInstallationPath(_installationPath);
      await c.load(kind);
      c.confirm(c.state.items.first.key);
      final result = c.inspectUnitPowerAt(pixelX: 64, pixelY: 64);
      expect(result.check, UnitPowerCheck.notApplicable);
      expect(result.point, isNull);
      expect(gateway.requests, isEmpty);
    });
  }
}

Future<void> _selectPowerUnit(_Fixture f) async {
  f.controller.setInstallationPath(_installationPath);
  await f.controller.load(StarCraftPlacementKind.unit);
  f.controller.confirm(f.controller.state.items.single.key);
  await f.controller.loadCollisionMetadata();
}

UnitPowerCheck? _powerAt(_Fixture f, {int x = 1024}) =>
    f.controller.inspectUnitPowerAt(pixelX: x, pixelY: 1024).check;

Uint8List _powerChkBytes() => Uint8List.fromList([
  ..._chkBytes(mapSize: 64),
  ..._section('XTRA', [255, 0, 128]),
  ..._section('UNIT', [
    for (final owner in [0, 1])
      ...const UnitPlacementFactory()
          .create(
            capability: _PowerCatalogGateway().capability(156),
            unitId: 156,
            owner: owner,
            x: 1024 + owner * 512,
            y: 1024,
            classId: owner + 1,
          )
          .bytes,
  ]),
]);

final class _PowerCatalogGateway implements StarCraftPlacementCatalogGateway {
  _PowerCatalogGateway({
    this.failure,
    this.requiresPsi = true,
    this.requiresCreep = false,
    this.hold = false,
  });
  String? failure;
  final bool requiresPsi;
  final bool requiresCreep;
  final bool hold;
  final release = Completer<void>();
  int metadataRequests = 0;
  UnitPlacementCapability capability(int id, {bool numeric = false}) =>
      UnitPlacementCapability(
        unitId: id,
        environmentProfile: numeric && failure == 'role'
            ? null
            : UnitEnvironmentProfile(
                requiresPsi: id == 0 && requiresPsi,
                requiresCreep: id == 0 && requiresCreep,
              ),
        placementBox: numeric && failure == 'box'
            ? null
            : BuildingPlacementBox(width: 64, height: 64),
        collisionProfile: numeric && failure == 'geometry'
            ? null
            : _terrainProfile,
        isBuilding: true,
        isFlyingBuilding: id == 156 && failure == 'pylonRole',
        isSpellcaster: false,
        hasShields: false,
        isResourceContainer: false,
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
          ? 7
          : page.storageBuildNumber,
      helperVersion: page.helperVersion,
      cascLibRevision: page.cascLibRevision,
    );
  }

  @override
  Future<void> cancel(String operationId) async {}
}

final class _PowerStateGateway implements UnitPowerStateGateway {
  _PowerStateGateway({
    this.failure,
    this.hold = false,
    this.failCancel = false,
    this.modelOverride,
  });
  String? failure;
  bool hold;
  final bool failCancel;
  final UnitPowerStateModel? modelOverride;
  final requests = <UnitPowerStateRequest>[];
  final cancelled = <String>[];
  final _pending = <String, Completer<void>>{};
  void release(UnitPowerStateRequest request) =>
      _pending[request.operationId]!.complete();
  @override
  Future<UnitPowerStateReadResult> read(UnitPowerStateRequest request) {
    requests.add(request);
    if (failure == 'sync') throw StateError('Synthetic synchronous failure');
    return () async {
      if (hold) {
        await (_pending[request.operationId] = Completer<void>()).future;
      }
      if (failure == 'throw') throw StateError('Synthetic async failure');
      var records = request.units;
      if (failure == 'record') {
        records = const ChkObjectViewDecoder()
            .decode(request.session.rawDocument)
            .unitSections
            .single
            .units;
      }
      if (failure == 'coverage') records = [];
      if (failure == 'order') records = records.reversed.toList();
      if (failure == 'duplicate') records = [records.first, records.first];
      return UnitPowerStateReadResult(
        snapshot: UnitPowerStateSnapshot(
          request: failure == 'request'
              ? UnitPowerStateRequest(
                  operationId: request.operationId,
                  session: request.session,
                  documentRevision: request.documentRevision + 1,
                  installationPath: request.installationPath,
                  dataIdentity: request.dataIdentity,
                )
              : request,
          providerId: failure == 'provider' ? '' : 'self-authored-test-state',
          revision: failure == 'revision'
              ? ''
              : 'synthetic-${request.operationId}',
          model:
              modelOverride ??
              (failure == 'model' ? UnitPowerStateModel.live : request.model),
          powerModelRevision: failure == 'powerModel'
              ? 'unsupported'
              : UnitPowerCatalog.revision,
          units: [
            for (final unit in records)
              UnitPowerUnitState(
                unit,
                exists: true,
                isCompleted: failure == 'unknown' ? null : true,
                isEnabled: failure != 'disabled',
              ),
          ],
        ),
        errorCode: failure == 'error' ? 'SYNTHETIC_FAILURE' : null,
        exitCode: failure == 'error' || failure == 'nonzeroExit' ? 1 : 0,
        stdout: 'self-authored state, not game evidence',
      );
    }();
  }

  @override
  Future<void> cancel(String operationId) async {
    cancelled.add(operationId);
    if (failCancel) throw StateError('Synthetic cancellation failure');
  }
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
  UnitPowerStateGateway? unitPowerStateGateway,
  UnitCreepStateGateway? unitCreepStateGateway,
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
    unitPowerStateGateway: unitPowerStateGateway,
    unitCreepStateGateway: unitCreepStateGateway,
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
