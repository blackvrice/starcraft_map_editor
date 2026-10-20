import 'dart:typed_data';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_deletion_plan.dart';
import 'basic_editing_fixture.dart';

RawChkDocument doodadLocationDeletionDocument({
  DoodadOverlaySemantic? overlay,
  bool batch = false,
  bool units = false,
}) {
  final doc = units
      ? doodadUnitDeletionDocument(overlay: overlay, batch: batch)
      : batch
      ? batchDeletionDocument(overlay: overlay)
      : deletionDocument(overlay: overlay);
  final at = doc.sections.indexWhere((s) => s.name == 'MRGN');
  final bytes = doc.sections[at].payload;
  final data = ByteData.sublistView(bytes);
  for (final index in [0, 1, 254]) {
    data
      ..setUint32(index * 20, 32, Endian.little)
      ..setUint32(index * 20 + 4, 64, Endian.little)
      ..setUint32(index * 20 + 8, 96, Endian.little)
      ..setUint32(index * 20 + 12, 128, Endian.little)
      ..setUint16(index * 20 + 16, 4, Endian.little)
      ..setUint16(index * 20 + 18, 0x23, Endian.little);
  }
  return const RawChkParser()
      .parse(
        const RawChkEncoder().encode(
          doc.replaceSection(at, doc.sections[at].withPayload(bytes)),
        ),
      )
      .document!;
}

RawChkDocument doodadUnitDeletionDocument({
  DoodadOverlaySemantic? overlay,
  bool batch = false,
  bool nydus = false,
}) {
  var doc = batch
      ? batchDeletionDocument(overlay: overlay)
      : deletionDocument(overlay: overlay);
  final at = doc.sections.indexWhere((s) => s.name == 'UNIT');
  final first = basicUnit(type: nydus ? 134 : 106, owner: 3, id: 11);
  final second = basicUnit(type: nydus ? 134 : 107, owner: 3, id: 12);
  second[29] = 0xab;
  doc = doc.replaceSection(
    at,
    doc.sections[at].withPayload([
      ...first,
      ...second,
      ...basicUnit(type: 37, id: 13, owner: 7),
    ]),
  );
  doc = const ChkBasicEditing().linkUnits(doc, 0, 1, addon: !nydus);
  return const RawChkParser()
      .parse(const RawChkEncoder().encode(doc))
      .document!;
}

DoodadPlacementRecipe deletionRecipe({
  DoodadOverlaySemantic? overlay,
  int doodadType = 7,
  int startTileGroup = 200,
  int overlayId = 100,
}) => DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.badlands,
  startTileGroup: startTileGroup,
  doodadType: doodadType,
  width: 1,
  height: 1,
  centerOffsetX: 16,
  centerOffsetY: 16,
  footprint: [
    DoodadFootprintCell(
      x: 0,
      y: 0,
      rawTileValue: startTileGroup * 16,
      requiredTileGroup: 0,
    ),
  ],
  overlay: overlay == null
      ? null
      : DoodadOverlayRecipe(semantic: overlay, id: overlayId),
);

RawChkDocument differentTypeNeighborDocument({
  bool batch = false,
  DoodadOverlaySemantic? overlay,
}) {
  var doc = batchDeletionDocument(count: batch ? 3 : 2, overlay: overlay);
  for (final name in ['DD2 ', 'MTXM', if (overlay != null) 'THG2']) {
    final at = doc.sections.indexWhere((s) => s.name == name);
    final bytes = doc.sections[at].payload;
    final data = ByteData.sublistView(bytes);
    switch (name) {
      case 'DD2 ':
        data.setUint16(bytes.length - 8, 9, Endian.little);
      case 'MTXM':
        data.setUint16((batch ? 35 : 34) * 2, 3216, Endian.little);
      case 'THG2':
        data.setUint16(bytes.length - 10, 101, Endian.little);
    }
    doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
  }
  return doc;
}

RawChkDocument deletionDocument({
  int state = 1,
  DoodadOverlaySemantic? overlay,
  int? flags,
}) {
  var doc = basicDocument();
  final dd = ByteData(16)
    ..setUint16(0, 7, Endian.little)
    ..setUint16(2, 48, Endian.little)
    ..setUint16(4, 48, Endian.little)
    ..setUint8(6, 3)
    ..setUint8(7, state)
    ..setUint16(8, 8, Endian.little)
    ..setUint16(10, 900, Endian.little)
    ..setUint16(12, 900, Endian.little)
    ..setUint8(14, 7)
    ..setUint8(15, 255);
  final sprite = ByteData(30)
    ..setUint16(0, 99, Endian.little)
    ..setUint16(2, 333, Endian.little)
    ..setUint16(4, 222, Endian.little)
    ..setUint8(6, 8)
    ..setUint8(7, 0x39)
    ..setUint16(8, 0x2345, Endian.little);
  final expected = overlay == DoodadOverlaySemantic.pureSprite
      ? 0x1000
      : state == 1
      ? 0x8000
      : 0;
  for (final offset in [10, 20]) {
    sprite
      ..setUint16(offset, 100, Endian.little)
      ..setUint16(offset + 2, 48, Endian.little)
      ..setUint16(offset + 4, 48, Endian.little)
      ..setUint8(offset + 6, 3)
      ..setUint16(offset + 8, flags ?? expected, Endian.little);
  }
  final tiles = doc.sections.singleWhere((s) => s.name == 'MTXM').payload;
  ByteData.sublistView(tiles).setUint16(66, 3200, Endian.little);
  for (final (name, bytes) in [
    ('DD2 ', dd.buffer.asUint8List()),
    ('THG2', sprite.buffer.asUint8List()),
    ('MTXM', tiles),
  ]) {
    final at = doc.sections.indexWhere((s) => s.name == name);
    doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
  }
  return const RawChkParser()
      .parse(const RawChkEncoder().encode(doc))
      .document!;
}

RawChkDocument batchDeletionDocument({
  int count = 2,
  DoodadOverlaySemantic? overlay,
  bool overlap = false,
}) {
  var doc = deletionDocument(overlay: overlay);
  final dd = doc.sections.singleWhere((s) => s.name == 'DD2 ').payload.toList(),
      sprites = doc.sections
          .singleWhere((s) => s.name == 'THG2')
          .payload
          .toList(),
      tiles = doc.sections.singleWhere((s) => s.name == 'MTXM').payload;
  for (var i = 1; i < count; i++) {
    final x = overlap ? 1 : 1 + i % 16, y = 1 + i ~/ 16;
    final d = ByteData(8)
      ..setUint16(0, 7, Endian.little)
      ..setUint16(2, x * 32 + 16, Endian.little)
      ..setUint16(4, y * 32 + 16, Endian.little)
      ..setUint8(6, 3);
    dd.addAll(d.buffer.asUint8List());
    ByteData.sublistView(
      tiles,
    ).setUint16((y * 32 + x) * 2, 3200, Endian.little);
    if (overlay != null) {
      final s = ByteData(10)
        ..setUint16(0, 100, Endian.little)
        ..setUint16(2, x * 32 + 16, Endian.little)
        ..setUint16(4, y * 32 + 16, Endian.little)
        ..setUint8(6, 3)
        ..setUint16(
          8,
          overlay == DoodadOverlaySemantic.pureSprite ? 0x1000 : 0,
          Endian.little,
        );
      sprites.addAll(s.buffer.asUint8List());
    }
  }
  for (final (name, bytes) in [
    ('DD2 ', dd),
    ('THG2', sprites),
    ('MTXM', tiles),
  ]) {
    final at = doc.sections.indexWhere((s) => s.name == name);
    doc = doc.replaceSection(at, doc.sections[at].withPayload(bytes));
  }
  return const RawChkParser()
      .parse(const RawChkEncoder().encode(doc))
      .document!;
}

List<DoodadDeletionRequest> batchDeletionRequests({
  int count = 2,
  DoodadOverlaySemantic? overlay,
}) => [
  for (var i = 0; i < count; i++)
    DoodadDeletionRequest(
      recipe: deletionRecipe(overlay: overlay),
      recordIndex: i == 0 ? 0 : i + 1,
      confirmedOverlayRecordIndex: overlay == null
          ? null
          : i == 0
          ? 1
          : i + 2,
    ),
];
