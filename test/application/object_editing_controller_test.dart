import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
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

      expect(fixture.objectEditingController.deleteSelection(), isTrue);

      var objects = fixture.openMapController.state.session!.objectViews;
      expect(objects.unitSections.single.units, isEmpty);
      expect(objects.spriteSections.single.sprites, isEmpty);
      expect(objects.doodadSections.single.doodads, isEmpty);
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

Future<_Fixture> _openFixture() async {
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
  ]) {
    builder.add(section);
  }
  return builder.takeBytes();
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
