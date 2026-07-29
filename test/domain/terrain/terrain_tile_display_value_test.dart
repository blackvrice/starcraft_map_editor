import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_tile_display_value.dart';

void main() {
  test('decomposes standard MTXM values into CV5 group and member', () {
    final first = TerrainTileDisplayValue.fromRawValue(0);
    final last = TerrainTileDisplayValue.fromRawValue(0x3fff);

    expect(first.groupIndex, 0);
    expect(first.groupMember, 0);
    expect(first.support, TerrainTileDisplaySupport.standard);
    expect(last.groupIndex, 1023);
    expect(last.groupMember, 15);
    expect(last.support, TerrainTileDisplaySupport.standard);
  });

  test('marks raw values beyond the standard CV5 group range unsupported', () {
    final firstUnsupported = TerrainTileDisplayValue.fromRawValue(0x4000);
    final maximumRaw = TerrainTileDisplayValue.fromRawValue(0xffff);

    expect(firstUnsupported.groupIndex, 1024);
    expect(firstUnsupported.groupMember, 0);
    expect(firstUnsupported.isUnsupported, isTrue);
    expect(maximumRaw.groupIndex, 4095);
    expect(maximumRaw.groupMember, 15);
    expect(maximumRaw.isUnsupported, isTrue);
  });

  test('summarizes standard and unsupported tile occurrences', () {
    final summary = TerrainTileDisplaySummary.fromRawValues([
      0,
      0x3fff,
      0x4000,
      0xffff,
    ]);

    expect(summary.tileCount, 4);
    expect(summary.standardTileCount, 2);
    expect(summary.unsupportedTileCount, 2);
    expect(summary.hasUnsupportedTiles, isTrue);
  });

  test('rejects values outside the MTXM unsigned 16-bit range', () {
    expect(() => TerrainTileDisplayValue.fromRawValue(-1), throwsRangeError);
    expect(
      () => TerrainTileDisplayValue.fromRawValue(0x10000),
      throwsRangeError,
    );
  });
}
