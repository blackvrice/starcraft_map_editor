import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_project_store.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';

void main() {
  late Directory directory;
  late File map;
  late EudProject project;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('eud-project-test-');
    map = File('${directory.path}/base.scx');
    await map.writeAsBytes([1, 2, 3, 4]);
    project = EudProject(
      mapPath: map.path,
      mapSha256: 'a' * 64,
      overrides: [
        EudOverride(field: 'unit.hasShield', targetId: 0, value: true),
      ],
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test(
    'Save As round trip preserves source and refuses existing destination',
    () async {
      final store = LocalEudProjectStore();
      final path = '${directory.path}/설정.eud.json';
      await store.saveAs(path, project);
      expect((await store.read(path)).encode(), project.encode());
      expect(await map.readAsBytes(), [1, 2, 3, 4]);
      final original = await File(path).readAsBytes();
      await expectLater(
        store.saveAs(path, project.withOverrides([])),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).readAsBytes(), original);
      await expectLater(store.saveAs(map.path, project), throwsFormatException);
      expect(await directory.list().length, 2);
    },
  );

  test('promotion failure cleans temporary output and preserves map', () async {
    final store = LocalEudProjectStore(
      files: LocalMapSaveFileGateway(
        fileMover: (_, _) async =>
            throw const FileSystemException('injected failure'),
      ),
    );
    final path = '${directory.path}/failed.eud.json';
    await expectLater(
      store.saveAs(path, project),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File(path).exists(), isFalse);
    expect(await map.readAsBytes(), [1, 2, 3, 4]);
    expect(await directory.list().length, 1);
  });

  test(
    'unknown settings round trip but future schema file remains untouched',
    () async {
      final store = LocalEudProjectStore();
      final path = '${directory.path}/unknown.eud.json';
      final unknown = project.withOverrides([
        EudOverride(field: 'weapon.future', targetId: 0, value: 'keep'),
      ]);
      await store.saveAs(path, unknown);
      expect((await store.read(path)).encode(), unknown.encode());
      final future = File('${directory.path}/future.eud.json');
      final text = project.encode().replaceFirst(
        '"schemaVersion": 1',
        '"schemaVersion": 2',
      );
      await future.writeAsString(text);
      await expectLater(store.read(future.path), throwsFormatException);
      expect(await future.readAsString(), text);
    },
  );
}
