enum TerrainTileDisplaySupport { standard, unsupported }

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
  static const int maximumTileGroupCount = 1024;
  static const int maximumStandardRawValue =
      rawValuesPerGroup * maximumTileGroupCount - 1;
  static const int maximumRawValue = 0xffff;

  final int rawValue;

  int get groupIndex => rawValue ~/ rawValuesPerGroup;

  int get groupMember => rawValue % rawValuesPerGroup;

  TerrainTileDisplaySupport get support => rawValue <= maximumStandardRawValue
      ? TerrainTileDisplaySupport.standard
      : TerrainTileDisplaySupport.unsupported;

  bool get isUnsupported => support == TerrainTileDisplaySupport.unsupported;

  static bool isStandardRawValue(int rawValue) =>
      rawValue >= 0 && rawValue <= maximumStandardRawValue;
}

final class TerrainTileDisplaySummary {
  const TerrainTileDisplaySummary({
    required this.tileCount,
    required this.unsupportedTileCount,
  });

  factory TerrainTileDisplaySummary.fromRawValues(Iterable<int> rawTileValues) {
    var tileCount = 0;
    var unsupportedTileCount = 0;
    for (final rawValue in rawTileValues) {
      final displayValue = TerrainTileDisplayValue.fromRawValue(rawValue);
      tileCount++;
      if (displayValue.isUnsupported) {
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

  int get standardTileCount => tileCount - unsupportedTileCount;

  bool get hasUnsupportedTiles => unsupportedTileCount > 0;
}
