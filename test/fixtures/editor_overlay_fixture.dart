import 'dart:async';
import 'package:starcraft_map_editor/application/editing/basic_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';
import 'package:starcraft_map_editor/application/terrain/editor_overlay_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/placement/building_placement_box.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_environment_profile.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';
import 'basic_editing_fixture.dart';
import 'eud_dat_fixture.dart';
import 'new_map_harness.dart';
import 'terrain_analysis_fixture.dart';

final class OverlayHarness {
  OverlayHarness() {
    h.maps.createNew(
      NewMapOptions(width: 32, height: 32, rawTileValue: 0),
      expectedSession: null,
    );
    catalog.synchronizeSession(h.maps.state.session);
    catalog.setInstallationPath(r'C:\StarCraft');
    _maps = h.maps.changes.listen(
      (state) => catalog.synchronizeSession(state.session),
    );
  }
  final h = NewMapHarness();
  final layers = MapLayerController();
  final terrainGateway = AnalysisGateway();
  final datGateway = OverlayDatGateway();
  final metadata = OverlayMetadataGateway();
  late final terrain = TerrainEditingController(openMapController: h.maps);
  late final objects = ObjectEditingController(
    openMapController: h.maps,
    mapLayerController: layers,
  );
  late final editing = BasicEditingController(maps: h.maps, layers: layers);
  late final catalog = PlacementCatalogController(
    openMapController: h.maps,
    objectEditingController: objects,
    terrainEditingController: terrain,
    catalogGateway: metadata,
    terrainPlacementGateway: terrainGateway,
    eudDatGateway: datGateway,
  );
  late final overlays = EditorOverlayController(catalog);
  late final StreamSubscription<Object?> _maps;
  void units(List<List<int>> records) => editing.apply(
    editing.source.rawDocument,
    basicDocument(units: records),
    'Fixture units',
  );
  MapLayerState selection({int index = 0}) => MapLayerState(
    selections: [
      MapLayerSelection(
        object: MapLayerObjectRef(
          layer: MapLayerType.units,
          sectionIndex: h
              .maps
              .state
              .session!
              .objectViews
              .unitSections
              .single
              .sectionIndex,
          recordIndex: index,
        ),
        pixelX: 999,
        pixelY: 999,
      ),
    ],
  );
  Future<void> dispose() async {
    await overlays.dispose();
    await _maps.cancel();
    await catalog.dispose();
    await editing.dispose();
    await objects.dispose();
    await terrain.dispose();
    await layers.dispose();
    await h.dispose();
  }
}

class OverlayDatGateway implements EudDatGateway {
  int calls = 0;
  bool fail = false;
  Completer<EudDatReadResult>? pending;
  final cancelled = <String>[];
  @override
  void cancel(String operationId) => cancelled.add(operationId);
  @override
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) return const EudDatReadResult(errorCode: 'fixture');
    final columns = syntheticDatColumns();
    columns['unit.sightRange']![0] = 7;
    columns['unit.groundWeapon']![0] = 1;
    columns['weapon.maxRange']![1] = 128;
    return EudDatReadResult(source: syntheticDatSource(columns));
  }
}

class OverlayMetadataGateway implements StarCraftPlacementCatalogGateway {
  int calls = 0;
  bool fail = false;
  @override
  Future<void> cancel(String operationId) async {}
  @override
  Future<StarCraftPlacementCatalogPage> list(
    StarCraftPlacementCatalogRequest r,
  ) async {
    calls++;
    if (fail) throw StateError('metadata-failed');
    return StarCraftPlacementCatalogPage(
      request: r,
      totalEntries: 228,
      entries: [
        for (var i = 0; i < 228; i++)
          StarCraftPlacementCatalogEntry(
            key: StarCraftPlacementCatalogKey.unit(i),
            source: StarCraftPlacementCatalogSource.localData,
            availability: StarCraftPlacementAvailability.placeable,
            unitCapability: overlayCapability(i),
          ),
      ],
      storageProduct: 'synthetic',
      storageBuildNumber: 1,
      helperVersion: '0.13.0',
      cascLibRevision: 'test',
    );
  }
}

UnitPlacementCapability overlayCapability(int id) => UnitPlacementCapability(
  unitId: id,
  environmentProfile: UnitEnvironmentProfile(
    requiresPsi: false,
    requiresCreep: false,
  ),
  placementBox: BuildingPlacementBox(width: 64, height: 64),
  collisionProfile: UnitCollisionProfile(
    left: 0,
    up: 0,
    right: 0,
    down: 0,
    isFlyer: false,
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
  isBuilding: id == 156,
  requiresRelationLink: false,
);
