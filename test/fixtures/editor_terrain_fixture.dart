import 'package:starcraft_map_editor/domain/chk/chk.dart';

RawChkSection part(String name, List<int> bytes) => RawChkSection(
  nameBytes: name.codeUnits,
  declaredLength: bytes.length,
  payload: bytes,
  sourceOffset: 0,
);
RawChkDocument document(List<RawChkSection> sections) =>
    RawChkDocument(sections: sections, sourceLength: 0);
