import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/eud/eud_build_configuration.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_source_workspace_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_eud_build_file_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  const gateway = LocalSourceWorkspaceGateway();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('source_workspace_');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  Future<File> put(String relative, String text) async {
    final file = File('${root.path}/$relative');
    await file.parent.create(recursive: true);
    return file.writeAsString(text, encoding: utf8, flush: true);
  }

  test(
    'bounded recursive scan preserves UTF8, CRLF, excludes caches and never executes',
    () async {
      await put('main.eps', 'import util;\r\n');
      await put('pkg/util.py', 'raise Exception("DO NOT EXECUTE") # 한글\r\n');
      await put('data.lua', '-- data\n');
      await put('.git/ignored.py', 'ignored');
      await put('__epspy__/generated.py', 'compiler cache');
      await put('notes.txt', 'ignored');
      final scan = await gateway.scan(root.path);
      expect(scan.files.map((f) => f.relativePath), [
        'data.lua',
        'main.eps',
        'pkg/util.py',
      ]);
      expect(scan.files.last.text, contains('한글\r\n'));
      expect(scan.files.last.revision, matches(RegExp(r'^[0-9a-f]{64}$')));
    },
  );
  test(
    'explicit save retains original byte backup and rejects changed originals',
    () async {
      final file = await put('main.py', 'old 한글\r\n');
      final before = await file.readAsBytes();
      final original = await gateway.read(root.path, 'main.py');
      final saved = await gateway.save(
        root.path,
        'main.py',
        'new\n',
        original.revision,
      );
      expect(saved.text, 'new\n');
      expect(saved.backupPath, isNotNull);
      expect(await File(saved.backupPath!).readAsBytes(), before);
      await file.writeAsString('external', flush: true);
      await expectLater(
        gateway.save(root.path, 'main.py', 'overwrite', saved.revision),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'external');
      expect(await File(saved.backupPath!).readAsBytes(), before);
    },
  );
  test('invalid UTF8/traversal/oversized files fail without writes', () async {
    final file = await put('bad.py', '');
    await file.writeAsBytes([0xff, 0xfe]);
    await expectLater(gateway.scan(root.path), throwsFormatException);
    await expectLater(
      gateway.read(root.path, '../outside.py'),
      throwsFormatException,
    );
    await file.writeAsString('x' * (1024 * 1024 + 1));
    await expectLater(gateway.scan(root.path), throwsFormatException);
  });
  test(
    'nested depth budget rejects scanning and leaves files unchanged',
    () async {
      final path = '${List.filled(13, 'nested').join('/')}/file.py';
      final file = await put(path, 'original');
      await expectLater(gateway.scan(root.path), throwsFormatException);
      expect(await file.readAsString(), 'original');
    },
  );
  test('directory junctions cannot make sources escape their root', () async {
    final outside = await Directory.systemTemp.createTemp('source_outside_');
    addTearDown(() => outside.delete(recursive: true));
    await File('${outside.path}/escape.py').writeAsString('original');
    final link = Link('${root.path}/linked');
    try {
      await link.create(outside.path);
    } on FileSystemException catch (e) {
      markTestSkipped('Creating a directory link requires OS permission: $e');
      return;
    }
    addTearDown(() async {
      if (await link.exists()) await link.delete();
    });
    await expectLater(
      gateway.scan(root.path),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      gateway.read(root.path, 'linked/escape.py'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await File('${outside.path}/escape.py').readAsString(), 'original');
  });
  test(
    'build dependency set detects edited, added and removed source files',
    () async {
      final src = await Directory('${root.path}/src').create();
      await put('base.scx', 'fixture');
      await put('src/main.eps', 'function onPluginStart() {}');
      await put('src/util.eps', 'const X=1;');
      final scan = await gateway.scan(src.path);
      final config = EudBuildConfiguration(
        baseMapPath: '${root.path}/base.scx',
        sourceRootPath: src.path,
        entrySourcePath: '${src.path}/main.eps',
        outputMapPath: '${root.path}/out.scx',
        sourceRevisions: {
          for (final f in scan.files) f.relativePath: f.revision,
        },
      );
      final build = LocalEudBuildFileGateway();
      await build.validateInputs(config);
      await put('src/util.eps', 'const X=2;');
      await expectLater(
        build.validateInputs(config),
        throwsA(isA<FileSystemException>()),
      );
      await put('src/util.eps', 'const X=1;');
      final added = await put('src/shadow.py', 'x=1');
      await expectLater(
        build.validateInputs(config),
        throwsA(isA<FileSystemException>()),
      );
      await added.delete();
      await File('${src.path}/util.eps').delete();
      await expectLater(
        build.validateInputs(config),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: !Platform.isWindows ? 'EUD build profiles use Windows paths' : false,
  );
}
