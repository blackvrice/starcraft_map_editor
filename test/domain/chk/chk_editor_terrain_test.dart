import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/typed/chk_editor_terrain.dart';

import '../../fixtures/editor_terrain_fixture.dart';

void main() {
  test(
    'reads independent little endian sides, includes right/bottom border and preserves every byte',
    () {
      final bytes = Uint8List(3 * 4 * 8);
      ByteData.sublistView(bytes)
        ..setUint16(88, 0x8001, Endian.little)
        ..setUint16(90, 0xffff, Endian.little)
        ..setUint16(92, 0x1234, Endian.little)
        ..setUint16(94, 0xabcd, Endian.little);
      final doc = document([
        part('DIM ', [4, 0, 3, 0]),
        part('ISOM', bytes),
        part('TILE', List.filled(24, 0)),
        part('MTXM', List.filled(24, 0)),
      ]);
      final before = const RawChkEncoder().encode(doc);
      final r = const ChkEditorTerrainDecoder().decode(doc);
      final isom = r.sections.first;
      expect(isom.columns, 3);
      expect(isom.rows, 4);
      expect(isom.expectedBytes, 96);
      final rect = isom.isomAt(2, 3);
      expect(
        [rect.left, rect.top, rect.right, rect.bottom],
        [0x8001, 0xffff, 0x1234, 0xabcd],
      );
      expect(() => isom.isomAt(3, 0), throwsRangeError);
      expect(() => isom.tileAt(0, 0), throwsStateError);
      expect(r.differentTileCount, 0);
      expect(const RawChkEncoder().encode(doc), before);
      expect(doc.isDirty, isFalse);
    },
  );
  test(
    'comparison reports differences without inferring corruption or hiding doodads',
    () {
      final doc = document([
        part('DIM ', [2, 0, 1, 0]),
        part('MTXM', [1, 0, 2, 0]),
        part('TILE', [1, 0, 255, 255]),
        part('DD2 ', List.filled(8, 0)),
      ]);
      final r = const ChkEditorTerrainDecoder().decode(doc);
      expect(r.differentTileCount, 1);
      expect(r.hasDoodads, isTrue);
      expect(r.hasIsom, isFalse);
      expect(r.sections.last.tileAt(1, 0), 65535);
    },
  );
  test(
    'duplicate, missing, malformed dimensions and truncated grids never select or repair a copy',
    () {
      final dim = part('DIM ', [2, 0, 1, 0]);
      final tile = part('TILE', [1, 0, 2, 0]);
      final decoder = const ChkEditorTerrainDecoder();
      final duplicate = decoder.decode(
        document([
          dim,
          tile,
          tile,
          part('MTXM', [1, 0, 2, 0]),
        ]),
      );
      expect(duplicate.duplicateNames, ['TILE']);
      expect(duplicate.sections.length, 3);
      expect(duplicate.differentTileCount, isNull);
      for (final dims in [
        <RawChkSection>[],
        [
          dim,
          part('DIM ', [0]),
        ],
        [
          part('DIM ', [0, 0, 1, 0]),
        ],
      ]) {
        final r = decoder.decode(document([...dims, tile]));
        expect(
          r.sections.single.state,
          EditorTerrainSectionState.unknownDimensions,
        );
        expect(() => r.sections.single.tileAt(0, 0), throwsStateError);
      }
      final r = decoder.decode(
        document([
          dim,
          part('ISOM', [0, 0, 0]),
          part('TILE', [0]),
        ]),
      );
      expect(
        r.sections.every(
          (s) => s.state == EditorTerrainSectionState.invalidSize,
        ),
        isTrue,
      );
      expect(r.sections.first.expectedBytes, 32);
    },
  );
  test('EUD protection marker is distinct from a truncated ISOM grid', () {
    final marker = RawChkSection.euddraftProtectionMarker(
      declaredLength: 0x80000000,
      sourceOffset: 0,
    );
    final doc = document([
      part('DIM ', [32, 0, 32, 0]),
      marker,
    ]);
    final before = const RawChkEncoder().encode(doc);
    final r = const ChkEditorTerrainDecoder().decode(doc);
    expect(r.hasProtectionMarker, isTrue);
    expect(r.sections.single.state, EditorTerrainSectionState.protectionMarker);
    expect(() => r.sections.single.isomAt(0, 0), throwsStateError);
    expect(const RawChkEncoder().encode(doc), before);
  });
  test(
    'odd widths use integer division and maximal dimensions do not allocate a guessed grid',
    () {
      final decoder = const ChkEditorTerrainDecoder();
      final odd = decoder.decode(
        document([
          part('DIM ', [3, 0, 1, 0]),
          part('ISOM', List.filled(32, 0)),
        ]),
      );
      expect(odd.sections.single.hasValidStructure, isTrue);
      final huge = decoder.decode(
        document([
          part('DIM ', [255, 255, 255, 255]),
          part('ISOM', []),
        ]),
      );
      expect(huge.sections.single.state, EditorTerrainSectionState.invalidSize);
    },
  );
}
