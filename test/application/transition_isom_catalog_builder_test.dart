import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/transition_isom_catalog_builder.dart';
import '../fixtures/solid_isom_fixture.dart';
import '../fixtures/transition_isom_fixture.dart';

void main() {
  test(
    'independent NW shape edge words and all fourteen transition shapes',
    () {
      final snapshot = transitionSnapshot();
      final c = const TransitionIsomCatalogBuilder().build(snapshot);
      expect(c.catalog.revision, 'transition-isom-v1:synthetic-solid');
      expect(c.shapes, {2: 1, 3: 2});
      final edges = {for (final e in c.catalog.edges) e.value: e};
      expect(
        [for (var i = 0; i < 8; i++) edges[0xd0 + i * 2]!.link],
        [1, 1, 1, 51, 51, 51, 1, 51],
      );
      expect(c.catalog.edges.length, 16 + 14 * 8);
      expect(c.catalog.pairs.every((p) => p.members.length == 2), isTrue);
      final reversed = solidSnapshot(groups: snapshot.groups.reversed.toList());
      final other = const TransitionIsomCatalogBuilder().build(reversed);
      expect(
        [for (final e in other.catalog.edges) (e.value, e.link, e.terrainType)],
        [for (final e in c.catalog.edges) (e.value, e.link, e.terrainType)],
      );
    },
  );
  test(
    'missing quadrant and nonmatching right half never supply guessed edges',
    () {
      final snap = transitionSnapshot();
      for (final groups in [
        snap.groups.take(6).toList(),
        snap.groups.where((g) => g.group != 7).toList(),
      ]) {
        expect(
          () => const TransitionIsomCatalogBuilder().build(
            solidSnapshot(groups: groups),
          ),
          throwsStateError,
        );
      }
    },
  );
}
