import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/solid_isom_catalog_builder.dart';
import '../fixtures/solid_isom_fixture.dart';

void main() {
  test('eight flat shape tables and valid nonzero paired members', () {
    for (var t = 0; t < 8; t++) {
      final c = const SolidIsomCatalogBuilder().build(
        solidSnapshot(tileset: t),
      );
      expect(c.shapes[2], t == 3 ? 2 : 1);
      expect(c.catalog.pairs.first.members, [0, 1]);
      expect(c.catalog.edges.length, 16);
      expect(c.catalog.revision, 'solid-isom-v1:synthetic-solid');
    }
  });
  test(
    'Platform Space uses only member zero while ordinary empty slots are excluded',
    () {
      final c = const SolidIsomCatalogBuilder().build(
        solidSnapshot(
          tileset: 1,
          groups: [
            solidGroup(2, references: List.filled(16, 0)),
            solidGroup(3, references: List.filled(16, 0)),
          ],
        ),
      );
      expect(c.shapes[2], 1);
      expect(c.catalog.pairs.single.members, [0]);
    },
  );
  test('rejects empty slots, stacks, missing partner and doodad records', () {
    for (final groups in [
      [solidGroup(2)],
      [solidGroup(2, references: List.filled(16, 0)), solidGroup(3)],
      [
        solidGroup(2),
        solidGroup(3, stacks: [0, 0, 1, 0]),
      ],
      [solidGroup(1024), solidGroup(1025)],
      [solidGroup(2), solidGroup(3, link: 48)],
      [solidGroup(2), solidGroup(3, members: [])],
    ]) {
      expect(
        () => const SolidIsomCatalogBuilder().build(
          solidSnapshot(groups: groups),
        ),
        throwsStateError,
      );
    }
  });
  test(
    'ambiguous cross-type links fail rather than choosing another terrain',
    () {
      expect(
        () => const SolidIsomCatalogBuilder().build(
          solidSnapshot(
            groups: [
              solidGroup(2),
              solidGroup(3),
              solidGroup(4, type: 3),
              solidGroup(5, type: 3),
            ],
          ),
        ),
        throwsStateError,
      );
    },
  );
}
