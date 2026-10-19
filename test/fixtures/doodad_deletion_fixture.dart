import 'dart:typed_data';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'basic_editing_fixture.dart';

DoodadPlacementRecipe deletionRecipe({DoodadOverlaySemantic? overlay}) =>
    DoodadPlacementRecipe(
      tileset: StarCraftTilesetAssetSet.badlands,
      startTileGroup: 200,
      doodadType: 7,
      width: 1,
      height: 1,
      centerOffsetX: 16,
      centerOffsetY: 16,
      footprint: [
        DoodadFootprintCell(
          x: 0,
          y: 0,
          rawTileValue: 3200,
          requiredTileGroup: 0,
        ),
      ],
      overlay: overlay == null
          ? null
          : DoodadOverlayRecipe(semantic: overlay, id: 100),
    );

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
