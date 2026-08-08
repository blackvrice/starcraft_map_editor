import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/documents/open_map_controller.dart';
import 'package:starcraft_map_editor/application/documents/save_map_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_editing_controller.dart';
import 'package:starcraft_map_editor/application/editing/object_properties.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/application/operations/operation_progress_controller.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/application/ports/map_file_picker.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
import 'package:starcraft_map_editor/application/recent_projects/recent_projects_service.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test(
    'edits every M6 object kind and reopens a verified byte-safe Save As',
    () async {
      const sourcePath = r'C:\Maps\Object Roundtrip Source.scx';
      const outputPath = r'C:\Maps\Object Roundtrip Saved.scx';
      const temporaryPath =
          r'C:\Maps\.starcraft_map_editor_object_roundtrip\temporary.scx';
      final sourceChk = _sourceChkBytes();
      final sourceMap = _extractedMap(sourcePath, sourceChk);
      final archiveGateway = _RoundtripArchiveGateway(sourceMap);
      final filePicker = _RoundtripFilePicker(
        openPath: sourcePath,
        savePath: outputPath,
      );
      final fingerprintGateway = _RoundtripFingerprintGateway(
        sourcePath: sourcePath,
        temporaryPath: temporaryPath,
        outputPath: outputPath,
      );
      final saveFileGateway = _RoundtripSaveFileGateway(temporaryPath);
      final progressController = OperationProgressController();
      final recentProjects = RecentProjectsService(InMemorySettingsStore());
      final openController = OpenMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        fingerprintGateway: fingerprintGateway,
        recentProjectsService: recentProjects,
        operationProgressController: progressController,
      );
      final saveController = SaveMapController(
        archiveGateway: archiveGateway,
        filePicker: filePicker,
        fingerprintGateway: fingerprintGateway,
        saveFileGateway: saveFileGateway,
        openMapController: openController,
        operationProgressController: progressController,
      );
      final layerController = MapLayerController();
      final editingController = ObjectEditingController(
        openMapController: openController,
        mapLayerController: layerController,
      );
      addTearDown(editingController.dispose);
      addTearDown(layerController.dispose);
      addTearDown(saveController.dispose);
      addTearDown(openController.dispose);
      addTearDown(progressController.dispose);

      final opened = await openController.open();
      expect(opened.status, OpenMapStatus.opened);
      expect(opened.diagnostics, isEmpty);
      layerController.synchronizeSession(opened.session);
      editingController.synchronizeSession(opened.session);
      final originalDocument = opened.session!.rawDocument;
      final originalSectionNames = originalDocument.sections
          .map((section) => section.name)
          .toList(growable: false);
      final originalUnitPayload = _sectionNamed(
        originalDocument,
        'UNIT',
      ).payload;
      final originalDoodadPayload = _sectionNamed(
        originalDocument,
        'DD2 ',
      ).payload;
      final originalSpritePayload = _sectionNamed(
        originalDocument,
        'THG2',
      ).payload;
      final originalLocationPayload = _sectionNamed(
        originalDocument,
        'MRGN',
      ).payload;
      final originalUnknownPayload = _sectionNamed(
        originalDocument,
        'XTRA',
      ).payload;

      final unitObject = _select(
        openController: openController,
        layerController: layerController,
        layer: MapLayerType.units,
        recordIndex: 0,
      );
      expect(
        editingController
            .updateProperties(
              UnitObjectPropertyUpdate(
                object: unitObject,
                typeId: 42,
                x: 72,
                y: 80,
                owner: 6,
                hitpointPercent: 100,
                shieldPercent: 75,
                energyPercent: 50,
                resourceAmount: 1234,
                hangarAmount: 7,
              ),
            )
            .didApply,
        isTrue,
      );
      expect(
        editingController.duplicateTemplate(
          template: unitObject,
          pixelX: 200,
          pixelY: 208,
        ),
        isTrue,
      );

      final doodadObject = _select(
        openController: openController,
        layerController: layerController,
        layer: MapLayerType.doodads,
        recordIndex: 0,
      );
      expect(
        editingController
            .updateProperties(
              DoodadObjectPropertyUpdate(
                object: doodadObject,
                typeId: 20,
                x: 88,
                y: 96,
                owner: 5,
                enabledValue: 0,
              ),
            )
            .didApply,
        isTrue,
      );

      final spriteObject = _select(
        openController: openController,
        layerController: layerController,
        layer: MapLayerType.sprites,
        recordIndex: 0,
      );
      expect(
        editingController
            .updateProperties(
              SpriteObjectPropertyUpdate(
                object: spriteObject,
                typeId: 30,
                x: 104,
                y: 112,
                owner: 7,
              ),
            )
            .didApply,
        isTrue,
      );

      final locationObject = _select(
        openController: openController,
        layerController: layerController,
        layer: MapLayerType.locations,
        recordIndex: 0,
      );
      expect(
        editingController
            .updateProperties(
              LocationObjectPropertyUpdate(
                object: locationObject,
                left: 40,
                top: 48,
                right: 176,
                bottom: 184,
                name: '왕복 위치',
              ),
            )
            .didApply,
        isTrue,
      );
      expect(openController.state.session!.isDirty, isTrue);
      expect(editingController.undo(), isTrue);
      expect(
        openController
            .state
            .session!
            .objectViews
            .locationSections
            .single
            .locations
            .first
            .stringId,
        1,
      );
      expect(
        openController
            .state
            .session!
            .stringViews
            .legacyTables
            .single
            .declaredStringCount,
        2,
      );
      expect(editingController.redo(), isTrue);
      expect(
        openController
            .state
            .session!
            .objectViews
            .locationSections
            .single
            .locations
            .first
            .stringId,
        3,
      );
      expect(
        openController
            .state
            .session!
            .stringViews
            .legacyTables
            .single
            .declaredStringCount,
        3,
      );

      final saved = await saveController.saveAs();
      expect(saved.status, SaveMapStatus.saved);
      expect(saved.outputPath, outputPath);
      expect(archiveGateway.writeRequests, hasLength(1));
      expect(saveFileGateway.promotedDestination, outputPath);
      expect(openController.state.session!.sourcePath, outputPath);
      expect(openController.state.session!.isDirty, isFalse);
      expect(sourceMap.scenarioChkBytes, sourceChk);

      final writtenBytes = Uint8List.fromList(
        archiveGateway.writeRequests.single.scenarioChkBytes,
      );
      final writtenDocument = const RawChkParser()
          .parse(writtenBytes)
          .document!;
      expect(
        writtenDocument.sections.map((section) => section.name),
        originalSectionNames,
      );
      expect(
        _sectionNamed(writtenDocument, 'XTRA').payload,
        originalUnknownPayload,
      );

      final expectedUnitPayload = Uint8List.fromList(originalUnitPayload);
      _writeUnitProperties(
        expectedUnitPayload,
        recordOffset: 0,
        typeId: 42,
        x: 72,
        y: 80,
        owner: 6,
        hitpointPercent: 100,
        shieldPercent: 75,
        energyPercent: 50,
        resourceAmount: 1234,
        hangarAmount: 7,
      );
      final duplicatedUnit = Uint8List.fromList(
        expectedUnitPayload.sublist(0, ChkUnitPlacement.recordLength),
      );
      ByteData.sublistView(duplicatedUnit)
        ..setUint16(4, 200, Endian.little)
        ..setUint16(6, 208, Endian.little);
      final expectedUnits = BytesBuilder(copy: false)
        ..add(expectedUnitPayload)
        ..add(duplicatedUnit);
      expect(
        _sectionNamed(writtenDocument, 'UNIT').payload,
        expectedUnits.takeBytes(),
      );

      final expectedDoodad = Uint8List.fromList(originalDoodadPayload);
      ByteData.sublistView(expectedDoodad)
        ..setUint16(0, 20, Endian.little)
        ..setUint16(2, 88, Endian.little)
        ..setUint16(4, 96, Endian.little)
        ..setUint8(6, 5)
        ..setUint8(7, 0);
      expect(_sectionNamed(writtenDocument, 'DD2 ').payload, expectedDoodad);

      final expectedSprite = Uint8List.fromList(originalSpritePayload);
      ByteData.sublistView(expectedSprite)
        ..setUint16(0, 30, Endian.little)
        ..setUint16(2, 104, Endian.little)
        ..setUint16(4, 112, Endian.little)
        ..setUint8(6, 7);
      expect(_sectionNamed(writtenDocument, 'THG2').payload, expectedSprite);
      expect(expectedSprite[7], originalSpritePayload[7]);
      expect(
        expectedSprite.sublist(8, 10),
        originalSpritePayload.sublist(8, 10),
      );

      final expectedLocations = Uint8List.fromList(originalLocationPayload);
      ByteData.sublistView(expectedLocations)
        ..setUint32(0, 40, Endian.little)
        ..setUint32(4, 48, Endian.little)
        ..setUint32(8, 176, Endian.little)
        ..setUint32(12, 184, Endian.little)
        ..setUint16(16, 3, Endian.little);
      expect(_sectionNamed(writtenDocument, 'MRGN').payload, expectedLocations);

      final writtenStrings = const ChkStringViewDecoder()
          .decode(writtenDocument)
          .legacyTables
          .single;
      expect(writtenStrings.declaredStringCount, 3);
      expect(writtenStrings.entries[0].rawBytes, utf8.encode('Existing'));
      expect(writtenStrings.entries[1].rawBytes, utf8.encode('Shared'));
      expect(writtenStrings.entries[2].rawBytes, utf8.encode('왕복 위치'));
      expect(
        writtenStrings.rawSection.payload.sublist(24, 26),
        const [0xde, 0xad],
        reason: 'Unreferenced string-table tail bytes must survive the append.',
      );

      final reopened = await openController.open(sourcePath: outputPath);
      expect(reopened.status, OpenMapStatus.opened);
      expect(reopened.diagnostics, isEmpty);
      expect(reopened.session!.sourcePath, outputPath);
      expect(reopened.session!.isDirty, isFalse);
      final objectViews = reopened.session!.objectViews;
      expect(objectViews.unitSections.single.units, hasLength(3));
      expect(
        objectViews.unitSections.single.units.map((unit) => unit.classId),
        [0x11111111, 0x22222222, 0x11111111],
      );
      expect(
        objectViews.unitSections.single.units.map((unit) => (unit.x, unit.y)),
        [(72, 80), (128, 136), (200, 208)],
      );
      expect(objectViews.locationSections.single.locations.first.stringId, 3);
      expect(
        utf8.decode(
          reopened
              .session!
              .stringViews
              .legacyTables
              .single
              .entries[2]
              .rawBytes!,
        ),
        '왕복 위치',
      );
      expect(archiveGateway.openRequests.map((request) => request.sourcePath), [
        sourcePath,
        temporaryPath,
        outputPath,
      ]);
    },
  );
}

MapLayerObjectRef _select({
  required OpenMapController openController,
  required MapLayerController layerController,
  required MapLayerType layer,
  required int recordIndex,
}) {
  final session = openController.state.session!;
  final sectionIndex = switch (layer) {
    MapLayerType.units => session.objectViews.unitSections.single.sectionIndex,
    MapLayerType.doodads =>
      session.objectViews.doodadSections.single.sectionIndex,
    MapLayerType.sprites =>
      session.objectViews.spriteSections.single.sectionIndex,
    MapLayerType.locations =>
      session.objectViews.locationSections.single.sectionIndex,
    MapLayerType.terrain => throw ArgumentError('Terrain is not an object.'),
  };
  final object = MapLayerObjectRef(
    layer: layer,
    sectionIndex: sectionIndex,
    recordIndex: recordIndex,
  );
  layerController
    ..setActiveLayer(layer)
    ..selectObject(session: session, object: object);
  return object;
}

RawChkSection _sectionNamed(RawChkDocument document, String name) =>
    document.sections.singleWhere((section) => section.name == name);

void _writeUnitProperties(
  Uint8List payload, {
  required int recordOffset,
  required int typeId,
  required int x,
  required int y,
  required int owner,
  required int hitpointPercent,
  required int shieldPercent,
  required int energyPercent,
  required int resourceAmount,
  required int hangarAmount,
}) {
  ByteData.sublistView(payload)
    ..setUint16(recordOffset + 4, x, Endian.little)
    ..setUint16(recordOffset + 6, y, Endian.little)
    ..setUint16(recordOffset + 8, typeId, Endian.little)
    ..setUint8(recordOffset + 16, owner)
    ..setUint8(recordOffset + 17, hitpointPercent)
    ..setUint8(recordOffset + 18, shieldPercent)
    ..setUint8(recordOffset + 19, energyPercent)
    ..setUint32(recordOffset + 20, resourceAmount, Endian.little)
    ..setUint16(recordOffset + 24, hangarAmount, Endian.little);
}

Uint8List _sourceChkBytes() {
  final locations = Uint8List(
    ChkLocationSectionView.originalLocationCount * ChkLocation.recordLength,
  );
  ByteData.sublistView(locations)
    ..setUint32(0, 32, Endian.little)
    ..setUint32(4, 32, Endian.little)
    ..setUint32(8, 160, Endian.little)
    ..setUint32(12, 160, Endian.little)
    ..setUint16(16, 1, Endian.little)
    ..setUint16(18, ChkLocation.allElevations, Endian.little);
  return _chkBytes([
    _section('TYPE', const [0x52, 0x41, 0x57, 0x53]),
    _section('VER ', const [206, 0]),
    _section('IVER', const [10, 0]),
    _section('DIM ', const [8, 0, 8, 0]),
    _section('ERA ', const [4, 0]),
    _section('MTXM', Uint8List(8 * 8 * 2)),
    _section('UNIT', [
      ..._unitRecord(classId: 0x11111111, x: 64, y: 72, owner: 1, seed: 3),
      ..._unitRecord(classId: 0x22222222, x: 128, y: 136, owner: 2, seed: 67),
    ]),
    _section('XTRA', const [0xde, 0xad, 0xbe, 0xef, 0x00]),
    _section('DD2 ', _doodadRecord()),
    _section('THG2', _spriteRecord()),
    _section('MRGN', locations),
    _section('STR ', _legacyStringTableWithTail()),
  ]);
}

Uint8List _unitRecord({
  required int classId,
  required int x,
  required int y,
  required int owner,
  required int seed,
}) {
  final payload = Uint8List.fromList(
    List<int>.generate(
      ChkUnitPlacement.recordLength,
      (index) => (seed + index) & 0xff,
    ),
  );
  ByteData.sublistView(payload)
    ..setUint32(0, classId, Endian.little)
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little)
    ..setUint8(16, owner);
  return payload;
}

Uint8List _doodadRecord() {
  final payload = Uint8List.fromList(const [9, 0, 64, 0, 72, 0, 3, 1]);
  return payload;
}

Uint8List _spriteRecord() {
  final payload = Uint8List(ChkSpritePlacement.recordLength);
  ByteData.sublistView(payload)
    ..setUint16(0, 10, Endian.little)
    ..setUint16(2, 80, Endian.little)
    ..setUint16(4, 88, Endian.little)
    ..setUint8(6, 4)
    ..setUint8(7, 0xa5)
    ..setUint16(8, 0xb123, Endian.little);
  return payload;
}

Uint8List _legacyStringTableWithTail() {
  final existing = utf8.encode('Existing');
  final shared = utf8.encode('Shared');
  final payload = Uint8List(6 + existing.length + 1 + shared.length + 1 + 2);
  ByteData.sublistView(payload)
    ..setUint16(0, 2, Endian.little)
    ..setUint16(2, 6, Endian.little)
    ..setUint16(4, 6 + existing.length + 1, Endian.little);
  payload.setAll(6, existing);
  final sharedOffset = 6 + existing.length + 1;
  payload.setAll(sharedOffset, shared);
  payload[payload.length - 2] = 0xde;
  payload[payload.length - 1] = 0xad;
  return payload;
}

Uint8List _section(String name, List<int> payload) {
  final result = Uint8List(RawChkParser.headerLength + payload.length);
  result.setRange(0, 4, name.codeUnits);
  ByteData.sublistView(result).setUint32(4, payload.length, Endian.little);
  result.setRange(RawChkParser.headerLength, result.length, payload);
  return result;
}

Uint8List _chkBytes(List<Uint8List> sections) {
  final builder = BytesBuilder(copy: false);
  for (final section in sections) {
    builder.add(section);
  }
  return builder.takeBytes();
}

ExtractedMap _extractedMap(String sourcePath, Uint8List chkBytes) =>
    ExtractedMap(
      sourcePath: sourcePath,
      scenarioChkBytes: chkBytes,
      metadata: MapArchiveMetadata(
        archiveSizeBytes: chkBytes.length + 128,
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

final class _RoundtripArchiveGateway implements MapArchiveGateway {
  _RoundtripArchiveGateway(this.sourceMap);

  final ExtractedMap sourceMap;
  final List<MapArchiveOpenRequest> openRequests = [];
  final List<MapArchiveWriteRequest> writeRequests = [];

  @override
  Future<MapArchiveOpenResult> open(MapArchiveOpenRequest request) async {
    openRequests.add(request);
    if (request.sourcePath == sourceMap.sourcePath) {
      return MapArchiveOpenResult.success(map: sourceMap);
    }
    return MapArchiveOpenResult.success(
      map: _extractedMap(
        request.sourcePath,
        Uint8List.fromList(writeRequests.single.scenarioChkBytes),
      ),
    );
  }

  @override
  Future<MapArchiveWriteResult> writeTemporary(
    MapArchiveWriteRequest request,
  ) async {
    writeRequests.add(request);
    return MapArchiveWriteResult.success(
      temporaryOutputPath: request.temporaryOutputPath,
    );
  }

  @override
  Future<bool> cancel(String operationId) async => false;
}

final class _RoundtripFilePicker implements MapFilePicker {
  const _RoundtripFilePicker({required this.openPath, required this.savePath});

  final String openPath;
  final String savePath;

  @override
  Future<String?> pickMapPath() async => openPath;

  @override
  Future<String?> pickSaveMapPath({required String suggestedName}) async =>
      savePath;
}

final class _RoundtripFingerprintGateway implements MapFileFingerprintGateway {
  _RoundtripFingerprintGateway({
    required this.sourcePath,
    required this.temporaryPath,
    required this.outputPath,
  });

  final String sourcePath;
  final String temporaryPath;
  final String outputPath;

  @override
  Future<MapFileFingerprint> fingerprint(String path) async {
    if (path == sourcePath) {
      return _fingerprint('1', DateTime.utc(2026, 8, 8, 12));
    }
    if (path == temporaryPath || path == outputPath) {
      return _fingerprint('2', DateTime.utc(2026, 8, 8, 13));
    }
    throw StateError('Unexpected fingerprint path: $path');
  }
}

MapFileFingerprint _fingerprint(String digit, DateTime modifiedAt) =>
    MapFileFingerprint(
      sizeBytes: 4096,
      modifiedAt: modifiedAt,
      sha256Digest: digit * 64,
    );

final class _RoundtripSaveFileGateway implements MapSaveFileGateway {
  _RoundtripSaveFileGateway(String temporaryPath)
    : workspace = MapSaveWorkspace(
        directoryPath: r'C:\Maps\.starcraft_map_editor_object_roundtrip',
        temporaryOutputPath: temporaryPath,
      );

  final MapSaveWorkspace workspace;
  String? promotedDestination;

  @override
  Future<void> cleanup(MapSaveWorkspace workspace) async {}

  @override
  Future<MapSaveWorkspace> createWorkspace(String destinationPath) async =>
      workspace;

  @override
  Future<bool> destinationExists(String path) async => false;

  @override
  Future<MapSavePromotionResult> promote({
    required MapSaveWorkspace workspace,
    required String destinationPath,
    required bool replaceExisting,
  }) async {
    promotedDestination = destinationPath;
    return MapSavePromotionResult();
  }

  @override
  Future<bool> refersToSameLocation(String leftPath, String rightPath) async =>
      leftPath.replaceAll('/', r'\').toLowerCase() ==
      rightPath.replaceAll('/', r'\').toLowerCase();
}
