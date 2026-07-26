import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_save_file_gateway.dart';

void main() {
  group('LocalMapSaveFileGateway', () {
    late Directory root;
    late LocalMapSaveFileGateway gateway;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'starcraft_map_editor_save_file_test_',
      );
      gateway = LocalMapSaveFileGateway();
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('creates a sibling workspace and promotes a new output', () async {
      final destination = File(
        '${root.path}${Platform.pathSeparator}Saved Map.scx',
      );
      final workspace = await gateway.createWorkspace(destination.path);
      final temporaryOutput = File(workspace.temporaryOutputPath);
      await temporaryOutput.writeAsBytes(const [1, 2, 3, 4]);

      expect(
        Directory(workspace.directoryPath).parent.absolute.path.toLowerCase(),
        root.absolute.path.toLowerCase(),
      );

      await gateway.promote(
        workspace: workspace,
        destinationPath: destination.path,
      );
      await gateway.cleanup(workspace);

      expect(await destination.readAsBytes(), [1, 2, 3, 4]);
      expect(await Directory(workspace.directoryPath).exists(), isFalse);
    });

    test('refuses to replace an existing destination', () async {
      final destination = File(
        '${root.path}${Platform.pathSeparator}Existing.scx',
      );
      await destination.writeAsBytes(const [9, 8, 7]);
      final workspace = await gateway.createWorkspace(destination.path);
      await File(workspace.temporaryOutputPath).writeAsBytes(const [1, 2, 3]);

      await expectLater(
        gateway.promote(
          workspace: workspace,
          destinationPath: destination.path,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await destination.readAsBytes(), [9, 8, 7]);
      await gateway.cleanup(workspace);
    });

    test(
      'detects equivalent paths case-insensitively on Windows',
      () async {
        final source = File('${root.path}${Platform.pathSeparator}Arena.scx');
        await source.writeAsBytes(const [1]);

        final equivalent = await gateway.refersToSameLocation(
          source.path,
          source.path.toUpperCase(),
        );

        expect(equivalent, isTrue);
      },
      skip: !Platform.isWindows,
    );
  });
}
