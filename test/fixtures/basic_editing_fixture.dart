import 'dart:typed_data';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';

RawChkSection basicSection(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument basicDocument({List<List<int>> units = const []}) {
  final doc = const NewMapFactory().create(
    NewMapOptions(width: 32, height: 32, rawTileValue: 1),
  );
  final at = doc.sections.indexWhere((s) => s.name == 'UNIT');
  return doc
      .replaceSection(at, basicSection('UNIT', [for (final u in units) ...u]))
      .appendSection(basicSection('ZZZZ', [255, 0, 17]));
}

Uint8List basicUnit({
  int type = 0,
  int owner = 0,
  int id = 0,
  int x = 128,
  int y = 128,
}) {
  final d = ByteData(36)
    ..setUint32(0, id, Endian.little)
    ..setUint16(4, x, Endian.little)
    ..setUint16(6, y, Endian.little)
    ..setUint16(8, type, Endian.little)
    ..setUint8(16, owner);
  return d.buffer.asUint8List();
}

ByteData basicData(RawChkDocument doc, String name) => ByteData.sublistView(
  doc.sections.singleWhere((s) => s.name == name).payload,
);
