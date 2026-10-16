import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_map_preparation_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_creep_capture_workspace_gateway.dart';

void main() {
  late Directory root;
  late LocalCreepCaptureWorkspaceGateway gateway;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('creep_workspace_test_');
    gateway = LocalCreepCaptureWorkspaceGateway(temporaryRoot: root.path);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'owns unique canonical directories and only deletes known output',
    () async {
      final first = await gateway.create();
      final second = await gateway.create();
      expect(first.directoryPath, isNot(second.directoryPath));
      expect(
        first.directoryPath,
        startsWith(await root.resolveSymbolicLinks()),
      );
      final original = await File(
        '${root.path}/original.scx',
      ).writeAsBytes([9]);
      await File(first.mapPath).writeAsBytes([1, 2]);
      expect(await gateway.sameLocation(first.mapPath, first.mapPath), isTrue);
      expect(await gateway.sameLocation(first.mapPath, original.path), isFalse);
      await gateway.cleanup(first);
      expect(await Directory(first.directoryPath).exists(), isFalse);
      expect(await Directory(second.directoryPath).exists(), isTrue);
      expect(await original.readAsBytes(), [9]);
      await gateway.cleanup(second);
    },
  );

  test('foreign or reconstructed token cannot delete files', () async {
    final workspace = await gateway.create();
    final file = await File(workspace.mapPath).writeAsBytes([1]);
    final clone = CreepCaptureWorkspace(
      directoryPath: workspace.directoryPath,
      mapPath: workspace.mapPath,
    );
    await expectLater(gateway.cleanup(clone), throwsStateError);
    final other = LocalCreepCaptureWorkspaceGateway(temporaryRoot: root.path);
    await expectLater(other.cleanup(workspace), throwsStateError);
    expect(await file.readAsBytes(), [1]);
    await gateway.cleanup(workspace);
    await expectLater(gateway.cleanup(workspace), throwsStateError);
  });

  test(
    'unknown file survives nonrecursive cleanup and ownership can retry',
    () async {
      final workspace = await gateway.create();
      await File(workspace.mapPath).writeAsBytes([1]);
      final foreign = await File(
        '${workspace.directoryPath}/keep.txt',
      ).writeAsString('keep');
      await expectLater(
        gateway.cleanup(workspace),
        throwsA(isA<FileSystemException>()),
      );
      expect(await foreign.readAsString(), 'keep');
      expect(await File(workspace.mapPath).exists(), isFalse);
      await foreign.delete();
      await gateway.cleanup(workspace);
      expect(await Directory(workspace.directoryPath).exists(), isFalse);
    },
  );

  test('directory at expected map path is not deleted', () async {
    final workspace = await gateway.create();
    final replacement = await Directory(workspace.mapPath).create();
    await expectLater(gateway.cleanup(workspace), throwsStateError);
    expect(await replacement.exists(), isTrue);
    await replacement.delete();
    await gateway.cleanup(workspace);
  });

  test('replaced workspace file is not deleted', () async {
    final workspace = await gateway.create();
    await Directory(workspace.directoryPath).delete();
    final replacement = await File(workspace.directoryPath).writeAsBytes([7]);
    await expectLater(gateway.cleanup(workspace), throwsStateError);
    expect(await replacement.readAsBytes(), [7]);
    await replacement.delete();
    await gateway.cleanup(workspace);
  });

  test('already missing owned directory releases ownership', () async {
    final workspace = await gateway.create();
    await Directory(workspace.directoryPath).delete();
    await gateway.cleanup(workspace);
    await expectLater(gateway.cleanup(workspace), throwsStateError);
  });

  test('missing or file temporary root is rejected', () async {
    final missing = LocalCreepCaptureWorkspaceGateway(
      temporaryRoot: '${root.path}/missing',
    );
    await expectLater(missing.create(), throwsA(isA<FileSystemException>()));
    final file = await File('${root.path}/root-file').writeAsBytes([1]);
    final invalid = LocalCreepCaptureWorkspaceGateway(temporaryRoot: file.path);
    await expectLater(invalid.create(), throwsA(isA<FileSystemException>()));
    expect(await file.readAsBytes(), [1]);
  });
}
