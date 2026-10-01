import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/terrain/isom_terrain_conversion.dart';
import '../../fixtures/isom_conversion_fixture.dart';
import '../../fixtures/editor_terrain_fixture.dart';

void main() {
  test(
    'converts known pairs atomically, preserves ISOM flags and unknown sections, and is idempotent',
    () {
      final source = isomFixture().appendSection(part('????', [7, 255]));
      final original = const RawChkEncoder().encode(source);
      final p = const IsomTerrainConverter().preview(
        source,
        isomCatalog(),
        seed: 0,
      );
      expect(p.changedTileCount, 1024);
      final expected = List<int>.generate(
        2048,
        (i) => i.isOdd ? 0 : (i % 4 == 0 ? 32 : 48),
      );
      for (final name in ['TILE', 'MTXM']) {
        expect(
          p.result.sections.singleWhere((s) => s.name == name).payload,
          expected,
        );
      }
      for (final s in source.sections.where(
        (s) => s.name != 'TILE' && s.name != 'MTXM',
      )) {
        expect(p.result.sections[source.sections.indexOf(s)], same(s));
      }
      expect(const RawChkEncoder().encode(source), original);
      final encoded = const RawChkEncoder().encode(p.result);
      expect(
        const RawChkEncoder().encode(
          const RawChkParser().parse(encoded).document!,
        ),
        encoded,
      );
      final again = const IsomTerrainConverter().preview(
        p.result,
        isomCatalog(),
        seed: 99,
      );
      expect(again.result, same(p.result));
      expect(again.changedTileCount, 0);
    },
  );
  test(
    'seeded choices ignore provider ordering and preserve an already valid pair/member',
    () {
      final source = isomFixture();
      final a = isomCatalog(
        pairs: [
          isomPair(6, members: [3, 1]),
          isomPair(2, members: [5, 0]),
        ],
      );
      final b = isomCatalog(
        pairs: [
          isomPair(2, members: [0, 5]),
          isomPair(6, members: [1, 3]),
        ],
      );
      final first = const IsomTerrainConverter().preview(source, a, seed: 7);
      final second = const IsomTerrainConverter().preview(source, b, seed: 7);
      expect(
        const RawChkEncoder().encode(first.result),
        const RawChkEncoder().encode(second.result),
      );
      expect(
        const IsomTerrainConverter()
            .preview(first.result, b, seed: 999)
            .changedTileCount,
        0,
      );
      final old = const RawChkEncoder().encode(source);
      expect(
        () => const IsomTerrainConverter().preview(source, a, seed: -1),
        throwsRangeError,
      );
      expect(const RawChkEncoder().encode(source), old);
    },
  );
  test(
    'unknown border/side, stacks, duplicate sections, doodads and raw overrides are refused without mutation',
    () {
      final source = isomFixture();
      var override = source.replaceSection(
        source.sections.indexWhere((s) => s.name == 'MTXM'),
        source.sections
            .firstWhere((s) => s.name == 'MTXM')
            .withPayload(List.filled(2048, 1)),
      );
      final badIsom = source.sections.last.payload;
      badIsom[badIsom.length - 2] = 0x22;
      for (final doc in [
        source.appendSection(part('DD2 ', List.filled(8, 0))),
        source.appendSection(source.sections.last),
        override,
        source.replaceSection(
          source.sections.length - 1,
          source.sections.last.withPayload(badIsom),
        ),
        source.appendSection(
          RawChkSection.euddraftProtectionMarker(
            declaredLength: 0x80000000,
            sourceOffset: 0,
          ),
        ),
      ]) {
        final before = const RawChkEncoder().encode(doc);
        expect(
          () =>
              const IsomTerrainConverter().preview(doc, isomCatalog(), seed: 0),
          throwsStateError,
        );
        expect(const RawChkEncoder().encode(doc), before);
      }
      expect(
        () => const IsomTerrainConverter().preview(
          source,
          isomCatalog(
            pairs: [
              isomPair(2, stacks: [0, 0, 0, 7]),
            ],
          ),
          seed: 0,
        ),
        throwsStateError,
      );
      expect(
        () => const IsomTerrainConverter().preview(
          source,
          isomCatalog(tileset: 1),
          seed: 0,
        ),
        throwsStateError,
      );
    },
  );
  test('rejects ambiguous catalogs and invalid pairs before conversion', () {
    expect(
      () => isomCatalog(pairs: [isomPair(2), isomPair(2)]),
      throwsArgumentError,
    );
    expect(() => isomPair(3), throwsArgumentError);
    expect(() => isomPair(4096), throwsArgumentError);
    expect(() => isomPair(2, members: [1, 1]), throwsArgumentError);
    expect(
      () => IsomEdgeConnection(value: 0x8010, link: 2, terrainType: 0),
      throwsArgumentError,
    );
  });
  test(
    'hard connections require matching terrain type and cannot fall back to another group',
    () {
      final source = isomFixture();
      IsomTerrainCatalog catalog(int type) => IsomTerrainCatalog(
        tileset: 0,
        revision: 'hard-fixture-v1',
        edges: [IsomEdgeConnection(value: 16, link: 49, terrainType: 3)],
        pairs: [
          IsomTilePair(
            leftGroup: 4094,
            terrainType: type,
            links: [49, 49, 49, 49],
            stackConnections: [0, 0, 0, 0],
            members: [15],
          ),
        ],
      );
      expect(
        () => const IsomTerrainConverter().preview(source, catalog(2), seed: 0),
        throwsStateError,
      );
      final result = const IsomTerrainConverter().preview(
        source,
        catalog(3),
        seed: 0,
      );
      expect(
        result.result.sections
            .firstWhere((s) => s.name == 'TILE')
            .payload
            .take(4),
        [239, 255, 255, 255],
      );
    },
  );
}
