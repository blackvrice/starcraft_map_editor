final class TerrainTileDisplayValue {
  TerrainTileDisplayValue.fromRawValue(this.rawValue) {
    if (rawValue < 0 || rawValue > maximumRawValue) {
      throw RangeError.range(
        rawValue,
        0,
        maximumRawValue,
        'rawValue',
        'MTXM tile values must fit in an unsigned 16-bit integer.',
      );
    }
  }

  static const int rawValuesPerGroup = 16;
  static const int maximumTileGroupCount = 4096;
  static const int maximumRawValue = 0xffff;

  final int rawValue;

  int get groupIndex => rawValue ~/ rawValuesPerGroup;

  int get groupMember => rawValue % rawValuesPerGroup;
}

final class TerrainTileDisplaySummary {
  const TerrainTileDisplaySummary({
    required this.tileCount,
    required this.unsupportedTileCount,
  });

  factory TerrainTileDisplaySummary.fromRawValues(
    Iterable<int> rawTileValues, {
    Iterable<int> unsupportedRawValues = const [],
  }) {
    final unsupported = unsupportedRawValues.toSet();
    var tileCount = 0;
    var unsupportedTileCount = 0;
    for (final rawValue in rawTileValues) {
      TerrainTileDisplayValue.fromRawValue(rawValue);
      tileCount++;
      if (unsupported.contains(rawValue)) {
        unsupportedTileCount++;
      }
    }
    return TerrainTileDisplaySummary(
      tileCount: tileCount,
      unsupportedTileCount: unsupportedTileCount,
    );
  }

  final int tileCount;
  final int unsupportedTileCount;

  int get supportedTileCount => tileCount - unsupportedTileCount;

  bool get hasUnsupportedTiles => unsupportedTileCount > 0;
}
