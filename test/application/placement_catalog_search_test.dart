import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/placement/placement_catalog_controller.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_placement_catalog_gateway.dart';

void main() {
  PlacementCatalogItem item(int id, {String? name}) => PlacementCatalogItem(
    entry: StarCraftPlacementCatalogEntry(
      key: StarCraftPlacementCatalogKey.unit(id),
      source: StarCraftPlacementCatalogSource.localData,
      availability: StarCraftPlacementAvailability.placeable,
      verifiedName: name,
      categoryPath: ['Terran', 'Ground'],
    ),
  );

  test('search preserves case, whitespace, category, ID and AND matching', () {
    final marine = item(0, name: 'Marine');
    final medic = item(34, name: 'Medic');
    final items = [marine, medic];
    expect(
      PlacementCatalogState(
        items: items,
        query: '  MARINE\tTerran\n#0 ',
      ).visibleItems,
      [marine],
    );
    expect(
      PlacementCatalogState(items: items, query: 'ground').visibleItems,
      items,
    );
    expect(
      PlacementCatalogState(items: items, query: 'marine #34').visibleItems,
      isEmpty,
    );
    expect(
      PlacementCatalogState(items: [item(7)], query: 'unit #7').visibleItems,
      hasLength(1),
    );
  });

  test(
    'empty search reuses immutable items instead of allocating a result',
    () {
      final state = PlacementCatalogState(items: [item(0)], query: ' \t ');
      expect(identical(state.visibleItems, state.items), isTrue);
      expect(() => state.visibleItems.clear(), throwsUnsupportedError);
    },
  );

  test(
    'repeated reads of 2000 entries reuse one immutable filtered result',
    () {
      final state = PlacementCatalogState(
        items: List.generate(2000, (i) => item(i)),
        query: '#1999',
      );
      final result = state.visibleItems;
      expect(result.single.key.id, 1999);
      for (var i = 0; i < 100; i++) {
        expect(identical(state.visibleItems, result), isTrue);
      }
      expect(() => result.clear(), throwsUnsupportedError);
    },
  );

  test('new query and appended page cannot reuse an obsolete result', () {
    final first = item(0, name: 'Marine');
    final second = item(1, name: 'Marine Hero');
    final input = [first];
    final old = PlacementCatalogState(items: input, query: 'marine');
    expect(old.visibleItems, [first]);
    input.add(second);
    final page = PlacementCatalogState(items: input, query: 'marine');
    expect(page.visibleItems, [first, second]);
    expect(old.visibleItems, [first]);
    final changed = PlacementCatalogState(items: page.items, query: 'hero');
    expect(changed.visibleItems, [second]);
    expect(page.visibleItems, [first, second]);
  });
}
