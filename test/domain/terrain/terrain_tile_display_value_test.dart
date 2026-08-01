import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/terrain/terrain_tile_display_value.dart';

void main() {
  test('decomposes the full MTXM u16 range into CV5 group and member', () {
    final first = TerrainTileDisplayValue.fromRawValue(0);
    final extended = TerrainTileDisplayValue.fromRawValue(0x4000);
    final last = TerrainTileDisplayValue.fromRawValue(0xffff);

    expect(first.groupIndex, 0);
    expect(first.groupMember, 0);
    expect(extended.groupIndex, 1024);
    expect(extended.groupMember, 0);
    expect(last.groupIndex, 4095);
    expect(last.groupMember, 15);
  });

  test('summarizes helper-reported unsupported tile occurrences', () {
    final summary = TerrainTileDisplaySummary.fromRawValues(
      [0, 0x4000, 0x4000, 0xffff],
      unsupportedRawValues: const [0xffff],
    );

    expect(summary.tileCount, 4);
    expect(summary.supportedTileCount, 3);
    expect(summary.unsupportedTileCount, 1);
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
