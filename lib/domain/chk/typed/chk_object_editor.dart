import 'dart:typed_data';

import '../raw_chk_section.dart';
import 'chk_object_views.dart';

final class ChkObjectCoordinateDelta {
  const ChkObjectCoordinateDelta({required this.dx, required this.dy});

  final int dx;
  final int dy;

  bool get isZero => dx == 0 && dy == 0;
}

class ChkObjectSectionEditor {
  const ChkObjectSectionEditor();

  RawChkSection moveUnits(
    ChkUnitSectionView view,
    Map<int, ChkObjectCoordinateDelta> deltas,
  ) => _movePointRecords(
    section: view.rawSection,
    recordCount: view.units.length,
    recordLength: ChkUnitPlacement.recordLength,
    xOffset: 4,
    yOffset: 6,
    deltas: deltas,
  );

  RawChkSection moveDoodads(
    ChkDoodadSectionView view,
    Map<int, ChkObjectCoordinateDelta> deltas,
  ) => _movePointRecords(
    section: view.rawSection,
    recordCount: view.doodads.length,
    recordLength: ChkDoodadPlacement.recordLength,
    xOffset: 2,
    yOffset: 4,
    deltas: deltas,
  );

  RawChkSection moveSprites(
    ChkSpriteSectionView view,
    Map<int, ChkObjectCoordinateDelta> deltas,
  ) => _movePointRecords(
    section: view.rawSection,
    recordCount: view.sprites.length,
    recordLength: ChkSpritePlacement.recordLength,
    xOffset: 2,
    yOffset: 4,
    deltas: deltas,
  );

  RawChkSection moveLocations(
    ChkLocationSectionView view,
    Map<int, ChkObjectCoordinateDelta> deltas,
  ) {
    if (deltas.isEmpty || deltas.values.every((delta) => delta.isZero)) {
      return view.rawSection;
    }
    final payload = view.rawSection.payload;
    final data = ByteData.sublistView(payload);
    for (final entry in deltas.entries) {
      RangeError.checkValidIndex(entry.key, view.locations, 'recordIndex');
      final offset = entry.key * ChkLocation.recordLength;
      for (final coordinateOffset in const [0, 8]) {
        data.setUint32(
          offset + coordinateOffset,
          _checkedUnsigned(
            data.getUint32(offset + coordinateOffset, Endian.little),
            entry.value.dx,
            0xffffffff,
            'location x',
          ),
          Endian.little,
        );
      }
      for (final coordinateOffset in const [4, 12]) {
        data.setUint32(
          offset + coordinateOffset,
          _checkedUnsigned(
            data.getUint32(offset + coordinateOffset, Endian.little),
            entry.value.dy,
            0xffffffff,
            'location y',
          ),
          Endian.little,
        );
      }
    }
    return view.rawSection.withPayload(payload);
  }

  RawChkSection duplicateUnit(
    ChkUnitSectionView view, {
    required int templateRecordIndex,
    required int x,
    required int y,
  }) => _appendPointRecord(
    section: view.rawSection,
    recordCount: view.units.length,
    recordLength: ChkUnitPlacement.recordLength,
    xOffset: 4,
    yOffset: 6,
    templateRecordIndex: templateRecordIndex,
    x: x,
    y: y,
  );

  RawChkSection duplicateDoodad(
    ChkDoodadSectionView view, {
    required int templateRecordIndex,
    required int x,
    required int y,
  }) => _appendPointRecord(
    section: view.rawSection,
    recordCount: view.doodads.length,
    recordLength: ChkDoodadPlacement.recordLength,
    xOffset: 2,
    yOffset: 4,
    templateRecordIndex: templateRecordIndex,
    x: x,
    y: y,
  );

  RawChkSection duplicateSprite(
    ChkSpriteSectionView view, {
    required int templateRecordIndex,
    required int x,
    required int y,
  }) => _appendPointRecord(
    section: view.rawSection,
    recordCount: view.sprites.length,
    recordLength: ChkSpritePlacement.recordLength,
    xOffset: 2,
    yOffset: 4,
    templateRecordIndex: templateRecordIndex,
    x: x,
    y: y,
  );

  RawChkSection deleteUnits(
    ChkUnitSectionView view,
    Iterable<int> recordIndices,
  ) => _removeRecords(
    section: view.rawSection,
    recordCount: view.units.length,
    recordLength: ChkUnitPlacement.recordLength,
    recordIndices: recordIndices,
  );

  RawChkSection deleteDoodads(
    ChkDoodadSectionView view,
    Iterable<int> recordIndices,
  ) => _removeRecords(
    section: view.rawSection,
    recordCount: view.doodads.length,
    recordLength: ChkDoodadPlacement.recordLength,
    recordIndices: recordIndices,
  );

  RawChkSection deleteSprites(
    ChkSpriteSectionView view,
    Iterable<int> recordIndices,
  ) => _removeRecords(
    section: view.rawSection,
    recordCount: view.sprites.length,
    recordLength: ChkSpritePlacement.recordLength,
    recordIndices: recordIndices,
  );

  RawChkSection deleteLocations(
    ChkLocationSectionView view,
    Iterable<int> recordIndices,
  ) {
    final indices = recordIndices.toSet();
    if (indices.isEmpty) {
      return view.rawSection;
    }
    final payload = view.rawSection.payload;
    for (final index in indices) {
      RangeError.checkValidIndex(index, view.locations, 'recordIndex');
      final start = index * ChkLocation.recordLength;
      payload.fillRange(start, start + ChkLocation.recordLength, 0);
    }
    return view.rawSection.withPayload(payload);
  }

  RawChkSection _movePointRecords({
    required RawChkSection section,
    required int recordCount,
    required int recordLength,
    required int xOffset,
    required int yOffset,
    required Map<int, ChkObjectCoordinateDelta> deltas,
  }) {
    if (deltas.isEmpty || deltas.values.every((delta) => delta.isZero)) {
      return section;
    }
    final payload = section.payload;
    final data = ByteData.sublistView(payload);
    for (final entry in deltas.entries) {
      _checkRecordIndex(entry.key, recordCount);
      final offset = entry.key * recordLength;
      data
        ..setUint16(
          offset + xOffset,
          _checkedUnsigned(
            data.getUint16(offset + xOffset, Endian.little),
            entry.value.dx,
            0xffff,
            'object x',
          ),
          Endian.little,
        )
        ..setUint16(
          offset + yOffset,
          _checkedUnsigned(
            data.getUint16(offset + yOffset, Endian.little),
            entry.value.dy,
            0xffff,
            'object y',
          ),
          Endian.little,
        );
    }
    return section.withPayload(payload);
  }

  RawChkSection _appendPointRecord({
    required RawChkSection section,
    required int recordCount,
    required int recordLength,
    required int xOffset,
    required int yOffset,
    required int templateRecordIndex,
    required int x,
    required int y,
  }) {
    _checkRecordIndex(templateRecordIndex, recordCount);
    RangeError.checkValueInInterval(x, 0, 0xffff, 'x');
    RangeError.checkValueInInterval(y, 0, 0xffff, 'y');
    final source = section.payload;
    final templateOffset = templateRecordIndex * recordLength;
    final record = Uint8List.fromList(
      Uint8List.sublistView(
        source,
        templateOffset,
        templateOffset + recordLength,
      ),
    );
    ByteData.sublistView(record)
      ..setUint16(xOffset, x, Endian.little)
      ..setUint16(yOffset, y, Endian.little);
    return section.withPayload([...source, ...record]);
  }

  RawChkSection _removeRecords({
    required RawChkSection section,
    required int recordCount,
    required int recordLength,
    required Iterable<int> recordIndices,
  }) {
    final indices = recordIndices.toSet();
    if (indices.isEmpty) {
      return section;
    }
    for (final index in indices) {
      _checkRecordIndex(index, recordCount);
    }
    final source = section.payload;
    final output = BytesBuilder(copy: false);
    for (var index = 0; index < recordCount; index++) {
      if (!indices.contains(index)) {
        final start = index * recordLength;
        output.add(Uint8List.sublistView(source, start, start + recordLength));
      }
    }
    return section.withPayload(output.takeBytes());
  }
}

int _checkedUnsigned(int value, int delta, int maximum, String name) {
  final result = value + delta;
  if (result < 0 || result > maximum) {
    throw RangeError.range(result, 0, maximum, name);
  }
  return result;
}

void _checkRecordIndex(int index, int recordCount) {
  if (index < 0 || index >= recordCount) {
    throw RangeError.index(
      index,
      List<Object?>.filled(recordCount, null),
      'recordIndex',
    );
  }
}
