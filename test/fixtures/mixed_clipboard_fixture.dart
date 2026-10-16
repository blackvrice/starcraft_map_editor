import 'dart:typed_data';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/chk_basic_editing.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'basic_editing_fixture.dart';
import 'isom_ramp_fixture.dart';

class MixedDoodadGateway extends IsomRampGateway {
  @override
  DoodadPlacementRecipe get recipe => mixedRecipe;
}

final mixedRecipe = DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.badlands,
  startTileGroup: 200,
  doodadType: 7,
  width: 2,
  height: 1,
  centerOffsetX: 32,
  centerOffsetY: 16,
  footprint: [
    for (var x = 0; x < 2; x++)
      DoodadFootprintCell(
        x: x,
        y: 0,
        rawTileValue: 3200 + x,
        requiredTileGroup: 0,
      ),
  ],
  overlay: DoodadOverlayRecipe(
    semantic: DoodadOverlaySemantic.spriteUnit,
    id: 100,
  ),
);
RawChkDocument mixedPut(RawChkDocument d, String name, List<int> bytes) {
  final old = const ChkBasicEditing().section(d, name);
  return old == null
      ? d.appendSection(basicSection(name, bytes))
      : d.replaceSection(d.sections.indexOf(old), old.withPayload(bytes));
}

RawChkDocument mixedDocument({RawChkDocument? base}) {
  var doc = base ?? basicDocument();
  final units = [
    basicUnit(type: 134, id: 11, x: 96, y: 128),
    basicUnit(type: 134, id: 12, x: 160, y: 128),
  ];
  for (var i = 0; i < 2; i++) {
    ByteData.sublistView(units[i])
      ..setUint16(10, 0x200, Endian.little)
      ..setUint32(32, i == 0 ? 12 : 11, Endian.little);
  }
  doc = mixedPut(doc, 'UNIT', [
    ...units[0],
    ...units[1],
    ...basicUnit(type: 214, id: 13, x: 32, y: 32),
  ]);
  final dd = ByteData(16);
  for (var i = 0; i < 2; i++) {
    dd
      ..setUint16(i * 8, 7, Endian.little)
      ..setUint16(i * 8 + 2, (i == 0 ? 2 : 5) * 32 + 32, Endian.little)
      ..setUint16(i * 8 + 4, 80, Endian.little)
      ..setUint8(i * 8 + 6, 3)
      ..setUint8(i * 8 + 7, i);
  }
  doc = mixedPut(doc, 'DD2 ', dd.buffer.asUint8List());
  final sp = ByteData(30);
  for (var i = 0; i < 3; i++) {
    sp
      ..setUint16(i * 10, i == 0 ? 130 : 100, Endian.little)
      ..setUint16(i * 10 + 2, i == 0 ? 120 : (i == 1 ? 192 : 96), Endian.little)
      ..setUint16(i * 10 + 4, i == 0 ? 140 : 80, Endian.little)
      ..setUint8(i * 10 + 6, 3)
      ..setUint16(
        i * 10 + 8,
        i == 0 ? 0x1000 : (i == 1 ? 0x8000 : 0),
        Endian.little,
      );
  }
  doc = mixedPut(doc, 'THG2', sp.buffer.asUint8List());
  final m = basicData(doc, 'MTXM');
  for (final x in [2, 5]) {
    for (var c = 0; c < 2; c++) {
      m.setUint16((2 * 32 + x + c) * 2, 3200 + c, Endian.little);
    }
  }
  doc = mixedPut(doc, 'MTXM', m.buffer.asUint8List());
  final loc = basicData(doc, 'MRGN');
  loc
    ..setUint32(0, 160, Endian.little)
    ..setUint32(4, 96, Endian.little)
    ..setUint32(8, 96, Endian.little)
    ..setUint32(12, 160, Endian.little)
    ..setUint16(18, 19, Endian.little);
  return mixedPut(doc, 'MRGN', loc.buffer.asUint8List());
}
