import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_brush_library.dart';
import '../fixtures/user_terrain_brush_fixture.dart';

void main() {
  test(
    'library persists, sorts, rejects duplicate names and explicitly deletes',
    () async {
      final store = MemoryTerrainBrushStore(),
          library = TerrainBrushLibrary(store);
      expect(await library.load(), isEmpty);
      await library.add(rawUserBrush(name: 'Z'));
      expect((await library.add(rawUserBrush(name: 'A'))).map((v) => v.name), [
        'A',
        'Z',
      ]);
      expect((await TerrainBrushLibrary(store).load()).length, 2);
      await expectLater(library.add(rawUserBrush(name: 'a')), throwsStateError);
      expect(store.values.length, 2);
      final result = await library.remove(rawUserBrush(name: 'Z'));
      expect(result.single.name, 'A');
      await expectLater(
        library.remove(rawUserBrush(name: 'Z')),
        throwsStateError,
      );
    },
  );
  test(
    'serialized writes survive failures without masking malformed/future data',
    () async {
      final store = MemoryTerrainBrushStore(),
          library = TerrainBrushLibrary(store);
      final a = library.add(rawUserBrush(name: 'A')),
          b = library.add(rawUserBrush(name: 'B'));
      await a;
      await b;
      expect(store.values.length, 2);
      store.failWrites = true;
      await expectLater(library.add(rawUserBrush(name: 'C')), throwsStateError);
      store.failWrites = false;
      expect((await library.add(rawUserBrush(name: 'C'))).length, 3);
      store.values['bad'] = jsonEncode({'version': 99});
      final before = Map.of(store.values);
      await expectLater(library.load(), throwsFormatException);
      await expectLater(
        library.add(rawUserBrush(name: 'D')),
        throwsFormatException,
      );
      expect(store.values, before);
    },
  );
  test('count and total metadata budgets reject rather than evict', () async {
    final store = MemoryTerrainBrushStore(),
        library = TerrainBrushLibrary(store);
    for (var i = 0; i < TerrainBrushLibrary.maxBrushes; i++) {
      final b = rawUserBrush(name: 'B$i');
      store.values[b.name] = b.encode();
    }
    await expectLater(library.add(rawUserBrush()), throwsStateError);
    expect(store.values.length, TerrainBrushLibrary.maxBrushes);
    store.values['huge'] = 'x' * TerrainBrushLibrary.maxTotalBytes;
    await expectLater(library.load(), throwsFormatException);
  });
}
