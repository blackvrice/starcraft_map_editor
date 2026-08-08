import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/opened_map_session.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';

void main() {
  test(
    'uses the active selectable layer before the default top-down order',
    () {
      final controller = MapLayerController();
      final session = _session();
      addTearDown(controller.dispose);

      expect(controller.state.activeLayer, MapLayerType.terrain);
      expect(controller.state.selectionPriority, [
        MapLayerType.terrain,
        MapLayerType.units,
        MapLayerType.sprites,
        MapLayerType.doodads,
        MapLayerType.locations,
      ]);

      controller.setActiveLayer(MapLayerType.units);
      var hits = controller.orderedHitsAt(
        session: session,
        pixelX: 64,
        pixelY: 64,
      );
      expect(hits.first.object.layer, MapLayerType.units);
      expect(hits.first.object.recordIndex, 1);
      expect(hits.map((hit) => hit.object.layer).toSet(), {
        MapLayerType.units,
        MapLayerType.sprites,
        MapLayerType.doodads,
        MapLayerType.locations,
        MapLayerType.terrain,
      });

      controller.setActiveLayer(MapLayerType.sprites);
      hits = controller.orderedHitsAt(session: session, pixelX: 64, pixelY: 64);
      expect(hits.first.object.layer, MapLayerType.sprites);

      controller.setLocked(MapLayerType.sprites, true);
      hits = controller.orderedHitsAt(session: session, pixelX: 64, pixelY: 64);
      expect(hits.first.object.layer, MapLayerType.units);
      expect(
        hits.where((hit) => hit.object.layer == MapLayerType.sprites),
        isEmpty,
      );
    },
  );

  test('hidden layers leave rendering and hit testing but keep counts', () {
    final controller = MapLayerController();
    final session = _session();
    addTearDown(controller.dispose);

    controller.setActiveLayer(MapLayerType.units);
    final selected = controller.selectAt(
      session: session,
      pixelX: 64,
      pixelY: 64,
    );
    expect(selected!.object.layer, MapLayerType.units);
    expect(controller.state.selection, isNotNull);

    controller.setVisible(MapLayerType.units, false);
    final scene = controller.sceneFor(session);

    expect(controller.state.selection, isNull);
    expect(scene.objectCounts[MapLayerType.units], 2);
    expect(
      scene.points.where((point) => point.object.layer == MapLayerType.units),
      isEmpty,
    );
    expect(
      controller
          .orderedHitsAt(session: session, pixelX: 64, pixelY: 64)
          .where((hit) => hit.object.layer == MapLayerType.units),
      isEmpty,
    );
  });

  test('prefers the smallest overlapping location within one layer', () {
    final controller = MapLayerController();
    final session = _session();
    addTearDown(controller.dispose);
    controller.setActiveLayer(MapLayerType.locations);

    final hits = controller.orderedHitsAt(
      session: session,
      pixelX: 64,
      pixelY: 64,
    );

    expect(hits[0].object.layer, MapLayerType.locations);
    expect(hits[0].object.recordIndex, 1);
    expect(hits[1].object.recordIndex, 0);
  });

  test(
    'session synchronization clears selection but preserves layer settings',
    () {
      final controller = MapLayerController();
      final firstSession = _session(sourcePath: r'C:\Maps\First.scx');
      final secondSession = _session(sourcePath: r'C:\Maps\Second.scx');
      addTearDown(controller.dispose);

      controller.synchronizeSession(firstSession);
      controller.setActiveLayer(MapLayerType.units);
      controller.setLocked(MapLayerType.locations, true);
      controller.selectAt(session: firstSession, pixelX: 64, pixelY: 64);
      expect(controller.state.selection, isNotNull);

      controller.synchronizeSession(secondSession);

      expect(controller.state.selection, isNull);
      expect(controller.state.activeLayer, MapLayerType.units);
      expect(
        controller.state.statusOf(MapLayerType.locations).isLocked,
        isTrue,
      );
    },
  );

  test('exposes immutable layer state and scene collections', () {
    final controller = MapLayerController();
    final scene = controller.sceneFor(_session());
    addTearDown(controller.dispose);

    expect(() => controller.state.layers.clear(), throwsUnsupportedError);
    expect(
      () => controller.state.selectionPriority.add(MapLayerType.units),
      throwsUnsupportedError,
    );
    expect(() => scene.points.clear(), throwsUnsupportedError);
    expect(() => scene.regions.clear(), throwsUnsupportedError);
    expect(
      () => scene.objectCounts[MapLayerType.units] = 99,
      throwsUnsupportedError,
    );
    expect(scene.objectCounts[MapLayerType.locations], 2);
  });

  test('supports additive click toggles and active-layer box selection', () {
    final controller = MapLayerController();
    final session = _session();
    addTearDown(controller.dispose);

    controller.setActiveLayer(MapLayerType.units);
    controller.selectAt(session: session, pixelX: 64, pixelY: 64);
    expect(controller.state.selections, hasLength(1));
    controller.selectAt(
      session: session,
      pixelX: 64,
      pixelY: 64,
      additive: true,
    );
    expect(controller.state.selections, isEmpty);

    final selected = controller.selectRegion(
      session: session,
      region: MapLayerPixelRegion.fromCorners(
        firstX: 48,
        firstY: 48,
        secondX: 80,
        secondY: 80,
      ),
    );
    expect(selected, hasLength(2));
    expect(selected.map((selection) => selection.object.layer).toSet(), {
      MapLayerType.units,
    });

    controller.setActiveLayer(MapLayerType.terrain);
    controller.selectRegion(
      session: session,
      region: MapLayerPixelRegion.fromCorners(
        firstX: 48,
        firstY: 48,
        secondX: 80,
        secondY: 80,
      ),
      additive: true,
    );
    expect(
      controller.state.selections.map((selection) => selection.object.layer),
      containsAll([
        MapLayerType.units,
        MapLayerType.doodads,
        MapLayerType.sprites,
        MapLayerType.locations,
      ]),
    );
  });
}

OpenedMapSession _session({String sourcePath = r'C:\Maps\Layers.scx'}) {
  final locationPayload = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  final locations = ByteData.sublistView(locationPayload);
  _writeLocation(
    locations,
    recordIndex: 0,
    left: 32,
    top: 32,
    right: 96,
    bottom: 96,
  );
  _writeLocation(
    locations,
    recordIndex: 1,
    left: 48,
    top: 48,
    right: 80,
    bottom: 80,
  );
  final document = _documentFromSections([
    _section('DIM ', const [4, 0, 4, 0]),
    _section('MTXM', Uint8List(4 * 4 * 2)),
    _section('UNIT', [..._unitRecord(64, 64), ..._unitRecord(64, 64)]),
    _section('DD2 ', _doodadRecord(64, 64)),
    _section('THG2', _spriteRecord(64, 64)),
    _section('MRGN', locationPayload),
  ]);
  const encoder = RawChkEncoder();
  final bytes = encoder.encode(document);
  final archiveMetadata = MapArchiveMetadata(
    archiveSizeBytes: bytes.length,
    formatVersion: 1,
    totalEntryCount: 1,
    listingComplete: true,
    entries: [
      MapArchiveEntryMetadata(
        path: MapArchiveEntryPaths.scenarioChk,
        uncompressedSizeBytes: bytes.length,
        compressedSizeBytes: bytes.length,
        flags: 0,
        locale: 0,
        nameIsSynthetic: false,
      ),
    ],
  );
  return OpenedMapSession(
    extractedMap: ExtractedMap(
      sourcePath: sourcePath,
      scenarioChkBytes: bytes,
      metadata: archiveMetadata,
    ),
    rawDocument: document,
    metadataViews: const ChkMetadataViewDecoder().decode(document),
    stringViews: const ChkStringViewDecoder().decode(document),
    terrainViews: const ChkTerrainViewDecoder().decode(document),
    objectViews: const ChkObjectViewDecoder().decode(document),
    sourceFingerprint: MapFileFingerprint(
      sizeBytes: bytes.length,
      modifiedAt: DateTime.utc(2026, 8, 6),
      sha256Digest: '0' * 64,
    ),
    diagnostics: const [],
  );
}

void _writeLocation(
  ByteData data, {
  required int recordIndex,
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  final offset = recordIndex * ChkLocation.recordLength;
  data
    ..setUint32(offset, left, Endian.little)
    ..setUint32(offset + 4, top, Endian.little)
    ..setUint32(offset + 8, right, Endian.little)
    ..setUint32(offset + 12, bottom, Endian.little)
    ..setUint16(offset + 16, recordIndex + 1, Endian.little)
    ..setUint16(offset + 18, 0x3f, Endian.little);
}

Uint8List _unitRecord(int x, int y) {
  final bytes = Uint8List(ChkUnitPlacement.recordLength);
  final data = ByteData.sublistView(bytes);
  data
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little)
    ..setUint16(8, 1, Endian.little);
  return bytes;
}

Uint8List _doodadRecord(int x, int y) {
  final bytes = Uint8List(ChkDoodadPlacement.recordLength);
  final data = ByteData.sublistView(bytes);
  data
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
}

Uint8List _spriteRecord(int x, int y) {
  final bytes = Uint8List(ChkSpritePlacement.recordLength);
  final data = ByteData.sublistView(bytes);
  data
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, x, Endian.little)
    ..setUint16(4, y, Endian.little);
  return bytes;
}

RawChkDocument _documentFromSections(List<RawChkSection> sections) {
  var sourceOffset = 0;
  final positioned = <RawChkSection>[];
  for (final section in sections) {
    positioned.add(
      RawChkSection(
        nameBytes: section.nameBytes,
        declaredLength: section.declaredLength,
        payload: section.payload,
        sourceOffset: sourceOffset,
      ),
    );
    sourceOffset += RawChkParser.headerLength + section.declaredLength;
  }
  return RawChkDocument(sections: positioned, sourceLength: sourceOffset);
}

RawChkSection _section(String name, List<int> payload) {
  return RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: payload.length,
    payload: payload,
    sourceOffset: 0,
  );
}
