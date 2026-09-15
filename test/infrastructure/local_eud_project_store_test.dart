import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/eud/eud_project.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_project_store.dart';
import 'package:starcraft_map_editor/application/ports/eud_project_store.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';

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
    'project saving does not require its linked map to be installed',
    () async {
      final offline = EudProject(
        mapPath: '${directory.path}/missing/map.scx',
        mapSha256: 'b' * 64,
      );
      final store = LocalEudProjectStore();
      final path = '${directory.path}/offline.eud.json';
      final initial = await store.saveAs(path, offline);
      final saved = await store.save(
        path,
        offline,
        expectedRevision: initial.revision,
      );
      expect(saved.project.mapPath, offline.mapPath);
      expect(await File(saved.backupPath!).exists(), isTrue);
      expect(await Directory('${directory.path}/missing').exists(), isFalse);
    },
  );

  test(
    'change immediately after promotion reports the recoverable original',
    () async {
      final path = '${directory.path}/post-write.eud.json';
      final original = project.encode();
      await File(path).writeAsString(original);
      final store = LocalEudProjectStore(
        fileMover: (source, destination) async {
          final isOutput = source.path.endsWith('temporary-map.scx');
          await source.rename(destination);
          if (isOutput) await File(path).writeAsString('external replacement');
        },
      );
      final initial = await store.read(path);
      try {
        await store.save(
          path,
          project.withOverrides([]),
          expectedRevision: initial.revision,
        );
        fail('expected verification failure');
      } on EudProjectSaveVerificationFailure catch (error) {
        expect(await File(error.backupPath!).readAsString(), original);
        expect(await File(path).readAsString(), 'external replacement');
      }
    },
  );

  test(
    'existing Save preserves exact original bytes in a backup and advances revision',
    () async {
      final store = LocalEudProjectStore();
      final path = '${directory.path}/existing.eud.json';
      final original = '  ${project.encode()}\n';
      await File(path).writeAsString(original);
      final opened = await store.read(path);
      final updated = project.withOverrides([]);
      final saved = await store.save(
        path,
        updated,
        expectedRevision: opened.revision,
      );
      expect(saved.revision, isNot(opened.revision));
      expect(await File(saved.backupPath!).readAsString(), original);
      expect((await store.read(path)).project.encode(), updated.encode());
      expect(await map.readAsBytes(), [1, 2, 3, 4]);
      final again = await store.save(
        path,
        project,
        expectedRevision: saved.revision,
      );
      expect(again.backupPath, isNot(saved.backupPath));
      expect(await File(again.backupPath!).readAsString(), updated.encode());
    },
  );

  test(
    'external whitespace edit and deleted file are never overwritten',
    () async {
      final store = LocalEudProjectStore();
      final path = '${directory.path}/external.eud.json';
      final initial = await store.saveAs(path, project);
      final external = '${project.encode()} ';
      await File(path).writeAsString(external);
      await expectLater(
        store.save(
          path,
          project.withOverrides([]),
          expectedRevision: initial.revision,
        ),
        throwsA(isA<EudProjectConflict>()),
      );
      expect(await File(path).readAsString(), external);
      expect(await directory.list().length, 2);
      await File(path).delete();
      await expectLater(
        store.save(path, project, expectedRevision: initial.revision),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).exists(), isFalse);
    },
  );

  test('independent readers cannot silently save over each other', () async {
    final first = LocalEudProjectStore();
    final second = LocalEudProjectStore();
    final path = '${directory.path}/shared.eud.json';
    await first.saveAs(path, project);
    final a = await first.read(path);
    final b = await second.read(path);
    await first.save(
      path,
      project.withOverrides([]),
      expectedRevision: a.revision,
    );
    await expectLater(
      second.save(path, project, expectedRevision: b.revision),
      throwsA(isA<EudProjectConflict>()),
    );
    expect((await first.read(path)).project.overrides, isEmpty);
  });

  test(
    'change during backup is detected and external bytes are restored',
    () async {
      final path = '${directory.path}/late.eud.json';
      await File(path).writeAsString(project.encode());
      final external = '${project.encode()} ';
      final store = LocalEudProjectStore(
        fileMover: (source, destination) async {
          if (source.path == File(path).absolute.path) {
            await source.writeAsString(external);
          }
          await source.rename(destination);
        },
      );
      final initial = await store.read(path);
      await expectLater(
        store.save(
          path,
          project.withOverrides([]),
          expectedRevision: initial.revision,
        ),
        throwsA(isA<EudProjectConflict>()),
      );
      expect(await File(path).readAsString(), external);
      expect(await directory.list().length, 2);
    },
  );

  test(
    'promotion failure restores original and rollback failure exposes recovery backup',
    () async {
      final path = '${directory.path}/restore.eud.json';
      final original = project.encode();
      await File(path).writeAsString(original);
      var failRestore = false;
      final store = LocalEudProjectStore(
        fileMover: (source, destination) async {
          if (source.path.endsWith('temporary-map.scx') ||
              (failRestore && source.path.endsWith('.bak'))) {
            throw const FileSystemException('injected move failure');
          }
          await source.rename(destination);
        },
      );
      final initial = await store.read(path);
      await expectLater(
        store.save(
          path,
          project.withOverrides([]),
          expectedRevision: initial.revision,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).readAsString(), original);
      failRestore = true;
      try {
        await store.save(
          path,
          project.withOverrides([]),
          expectedRevision: initial.revision,
        );
        fail('expected recovery exception');
      } on MapSavePromotionRecoveryException catch (error) {
        expect(await File(error.backupPath).readAsString(), original);
        expect(await File(path).exists(), isFalse);
      }
      expect(await map.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test('unexpected destination created during backup is preserved', () async {
    final path = '${directory.path}/appeared.eud.json';
    await File(path).writeAsString(project.encode());
    final store = LocalEudProjectStore(
      fileMover: (source, destination) async {
        final isOriginal = source.path == File(path).absolute.path;
        await source.rename(destination);
        if (isOriginal) await File(path).writeAsString('external replacement');
      },
    );
    final initial = await store.read(path);
    await expectLater(
      store.save(
        path,
        project.withOverrides([]),
        expectedRevision: initial.revision,
      ),
      throwsA(isA<MapSavePromotionRecoveryException>()),
    );
    expect(await File(path).readAsString(), 'external replacement');
  });

  test(
    'Save As round trip preserves source and refuses existing destination',
    () async {
      final store = LocalEudProjectStore();
      final path = '${directory.path}/설정.eud.json';
      await store.saveAs(path, project);
      expect((await store.read(path)).project.encode(), project.encode());
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
      fileMover: (_, _) async =>
          throw const FileSystemException('injected failure'),
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
      expect((await store.read(path)).project.encode(), unknown.encode());
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
