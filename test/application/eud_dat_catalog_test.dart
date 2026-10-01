import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/eud_dat_gateway.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_editing_controller.dart';
import '../fixtures/eud_project_workspace_fixture.dart';
import '../fixtures/eud_dat_fixture.dart';

class Gateway implements EudDatGateway {
  Completer<EudDatReadResult>? pending;
  int calls = 0;
  final cancelled = <String>[];
  @override
  void cancel(String operationId) => cancelled.add(operationId);
  @override
  Future<EudDatReadResult> read({
    required String operationId,
    required String installationPath,
  }) {
    calls++;
    return pending?.future ??
        Future.value(
          EudDatReadResult(source: syntheticDatSource(), stdout: 'raw source'),
        );
  }
}

void main() {
  test(
    'deduplicates reads, records provenance/logs and clears data on scope change',
    () async {
      final f = EudWorkspaceFixture();
      await f.maps.open();
      final layers = MapLayerController(), gateway = Gateway();
      final objects = ObjectEditingController(
        openMapController: f.maps,
        mapLayerController: layers,
      );
      final terrain = TerrainEditingController(openMapController: f.maps);
      final catalog = PlacementCatalogController(
        openMapController: f.maps,
        objectEditingController: objects,
        terrainEditingController: terrain,
        eudDatGateway: gateway,
      );
      addTearDown(() async {
        await catalog.dispose();
        await objects.dispose();
        await terrain.dispose();
        layers.dispose();
        f.dispose();
      });
      catalog.setInstallationPath(r'C:\fixture');
      final before = f.maps.state.session!.rawDocument;
      gateway.pending = Completer();
      final first = catalog.loadEudData(), second = catalog.loadEudData();
      expect(identical(first, second), isTrue);
      gateway.pending!.complete(
        EudDatReadResult(source: syntheticDatSource(), stdout: 'raw source'),
      );
      expect(identical(await first, await second), isTrue);
      await catalog.loadEudData();
      expect(gateway.calls, 1);
      expect(catalog.lastEudDatRead!.stdout, 'raw source');
      catalog.setInstallationPath(r'C:\other');
      expect(catalog.eudData, isNull);
      expect(catalog.lastEudDatRead, isNull);
      gateway.pending = Completer();
      final stale = catalog.loadEudData();
      final expected = expectLater(stale, throwsStateError);
      catalog.setInstallationPath(r'C:\third');
      expect(gateway.cancelled, hasLength(1));
      gateway.pending!.complete(EudDatReadResult(source: syntheticDatSource()));
      await expected;
      expect(catalog.eudData, isNull);
      expect(f.maps.state.session!.rawDocument, same(before));
      expect(f.maps.editHistory.canUndo, isFalse);
    },
  );
}
