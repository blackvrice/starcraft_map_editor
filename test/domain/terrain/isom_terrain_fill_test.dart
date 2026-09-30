import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/solid_isom_catalog_builder.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/chk/new_map_factory.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_fill.dart';
import '../../fixtures/solid_isom_fixture.dart';
import '../../fixtures/editor_terrain_fixture.dart';

void main() {
  final catalog = const SolidIsomCatalogBuilder()
      .build(solidSnapshot())
      .catalog;
  final source = const NewMapFactory()
      .create(NewMapOptions(width: 32, height: 32, rawTileValue: 0))
      .appendSection(part('XTRA', [0, 255, 1]));
  test(
    'solid fill has known little endian edges, paired tiles and lossless CHK roundtrip',
    () {
      final before = const RawChkEncoder().encode(source);
      final p = const IsomTerrainFill().preview(
        source,
        catalog,
        solidValue: 16,
        seed: 0,
      );
      expect(p.changedTileCount, 1024);
      expect(p.isomChanged, isTrue);
      final iso = p.result.sections.singleWhere((s) => s.name == 'ISOM');
      expect(iso.payload.length, 17 * 33 * 8);
      expect(iso.payload.take(16), [
        16,
        0,
        16,
        0,
        16,
        0,
        16,
        0,
        16,
        0,
        16,
        0,
        16,
        0,
        16,
        0,
      ]);
      final tile = p.result.sections
          .singleWhere((s) => s.name == 'TILE')
          .payload;
      for (var i = 0; i < tile.length; i += 4) {
        expect(tile[i] ~/ 16, 2);
        expect(tile[i + 2] ~/ 16, 3);
        expect(tile[i] & 15, tile[i + 2] & 15);
        expect(tile[i] & 15, inInclusiveRange(0, 1));
      }
      for (var i = 0; i < source.sections.length; i++) {
        if (!['TILE', 'MTXM'].contains(source.sections[i].name)) {
          expect(p.result.sections[i], same(source.sections[i]));
        }
      }
      final bytes = const RawChkEncoder().encode(p.result);
      expect(
        const RawChkEncoder().encode(
          const RawChkParser().parse(bytes).document!,
        ),
        bytes,
      );
      expect(const RawChkEncoder().encode(source), before);
      final again = const IsomTerrainFill().preview(
        p.result,
        catalog,
        solidValue: 16,
        seed: 9,
      );
      expect(again.hasChanges, isFalse);
      expect(again.result, same(p.result));
    },
  );
  test('ISOM-only addition counts as change when the tiles already match', () {
    final filled = const IsomTerrainFill()
        .preview(source, catalog, solidValue: 16, seed: 0)
        .result;
    final noIsom = filled.removeTrailingSections(1);
    final p = const IsomTerrainFill().preview(
      noIsom,
      catalog,
      solidValue: 16,
      seed: 0,
    );
    expect(p.changedTileCount, 0);
    expect(p.hasChanges, isTrue);
  });
  test(
    'raw overrides, damaged/duplicate/unknown ISOM and doodads remain untouched',
    () {
      final filled = const IsomTerrainFill()
          .preview(source, catalog, solidValue: 16, seed: 0)
          .result;
      final tileIndex = source.sections.indexWhere((s) => s.name == 'MTXM');
      final raw = source.sections[tileIndex].payload..[0] = 1;
      final iso = filled.sections.last;
      for (final bad in [
        source.replaceSection(
          tileIndex,
          source.sections[tileIndex].withPayload(raw),
        ),
        source.appendSection(part('ISOM', [16, 0])),
        filled.appendSection(iso),
        filled.replaceSection(
          filled.sections.length - 1,
          iso.withPayload(iso.payload..[0] = 0),
        ),
        source.appendSection(part('DD2 ', List.filled(8, 0))),
        source.appendSection(
          RawChkSection.euddraftProtectionMarker(
            declaredLength: 0x80000000,
            sourceOffset: 0,
          ),
        ),
      ]) {
        final bytes = const RawChkEncoder().encode(bad);
        expect(
          () => const IsomTerrainFill().preview(
            bad,
            catalog,
            solidValue: 16,
            seed: 0,
          ),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(bad), bytes);
      }
    },
  );
}
