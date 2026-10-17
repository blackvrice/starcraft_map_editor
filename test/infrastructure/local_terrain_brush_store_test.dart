import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_terrain_brush_store.dart';
import 'package:starcraft_map_editor/application/terrain/terrain_brush_library.dart';
import '../fixtures/user_terrain_brush_fixture.dart';

void main() {
  late Directory root;
  late LocalTerrainBrushStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('user-brush-test-');
    store = LocalTerrainBrushStore(Directory('${root.path}/brushes'));
  });
  tearDown(() => root.delete(recursive: true));
  test(
    'atomic verified add/reopen, case collision and explicit delete',
    () async {
      final b = rawUserBrush(name: '한글 / .. brush');
      expect(await store.readAll(), isEmpty);
      await store.add(b.name, b.encode());
      expect(
        (await TerrainBrushLibrary(store).load()).single.encode(),
        b.encode(),
      );
      await expectLater(store.add(b.name, b.encode()), throwsStateError);
      expect((await store.readAll()).single, b.encode());
      expect(await root.list().length, 1);
      await store.remove(b.name);
      expect(await store.readAll(), isEmpty);
    },
  );
  test(
    'malformed, future, oversized and misnamed files are not silently discarded',
    () async {
      await store.add('Cliff', rawUserBrush().encode());
      final file = (await store.directory.list().toList())
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.json'));
      await file.writeAsString('{"version":99}');
      final before = await file.readAsString();
      await expectLater(store.readAll(), throwsFormatException);
      await expectLater(
        store.add('New', rawUserBrush(name: 'New').encode()),
        throwsFormatException,
      );
      expect(await file.readAsString(), before);
      await file.writeAsString(rawUserBrush(name: 'Different').encode());
      await expectLater(store.readAll(), throwsFormatException);
      await file.writeAsString('x' * (512 * 1024 + 1));
      await expectLater(store.readAll(), throwsFormatException);
    },
  );
  test(
    'incomplete temp directories are ignored; bad payload never creates brush',
    () async {
      await store.directory.create();
      await Directory('${store.directory.path}/.brush-interrupted').create();
      await expectLater(store.add('bad', '{}'), throwsFormatException);
      expect(await store.readAll(), isEmpty);
      final brush = rawUserBrush();
      await expectLater(
        store.add('../other', brush.encode()),
        throwsFormatException,
      );
      expect(await store.readAll(), isEmpty);
    },
  );
  test('a brush library directory cannot traverse a symbolic link', () async {
    final actual = Directory('${root.path}/actual');
    await actual.create();
    final link = Link('${root.path}/link');
    try {
      await link.create(actual.path);
    } on FileSystemException {
      markTestSkipped(
        'Creating links needs Windows Developer Mode or privilege.',
      );
      return;
    } // Windows without Developer Mode.
    final linked = LocalTerrainBrushStore(Directory(link.path));
    await expectLater(linked.readAll(), throwsA(isA<FileSystemException>()));
    expect(await actual.list().length, 0);
  });
}
