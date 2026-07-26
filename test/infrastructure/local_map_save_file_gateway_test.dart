import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_save_file_gateway.dart';
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
        replaceExisting: false,
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
          replaceExisting: false,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await destination.readAsBytes(), [9, 8, 7]);
      await gateway.cleanup(workspace);
    });

    test('backs up and replaces an existing destination', () async {
      final destination = File(
        '${root.path}${Platform.pathSeparator}Existing.scx',
      );
      await destination.writeAsBytes(const [9, 8, 7], flush: true);
      final workspace = await gateway.createWorkspace(destination.path);
      await File(
        workspace.temporaryOutputPath,
      ).writeAsBytes(const [1, 2, 3], flush: true);

      final result = await gateway.promote(
        workspace: workspace,
        destinationPath: destination.path,
        replaceExisting: true,
      );
      await gateway.cleanup(workspace);

      expect(result.replacedExistingDestination, isTrue);
      expect(result.backupPath, isNotNull);
      expect(result.backupPath, startsWith('${destination.path}.backup-'));
      expect(result.backupPath, endsWith('.bak'));
      expect(await destination.readAsBytes(), [1, 2, 3]);
      expect(await File(result.backupPath!).readAsBytes(), [9, 8, 7]);
      expect(await Directory(workspace.directoryPath).exists(), isFalse);
    });

    test('never overwrites an existing recovery backup', () async {
      final destination = File(
        '${root.path}${Platform.pathSeparator}Existing.scx',
      );
      await destination.writeAsBytes(const [9, 8, 7], flush: true);
      final workspace = await gateway.createWorkspace(destination.path);
      final temporaryOutput = File(workspace.temporaryOutputPath);
      await temporaryOutput.writeAsBytes(const [1, 2, 3], flush: true);
      const workspacePrefix = '.starcraft_map_editor_save_';
      final workspaceName = workspace.directoryPath
          .split(Platform.pathSeparator)
          .last;
      final token = workspaceName.substring(workspacePrefix.length);
      final backup = File('${destination.path}.backup-$token.bak');
      await backup.writeAsBytes(const [5, 5, 5], flush: true);

      await expectLater(
        gateway.promote(
          workspace: workspace,
          destinationPath: destination.path,
          replaceExisting: true,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await destination.readAsBytes(), [9, 8, 7]);
      expect(await backup.readAsBytes(), [5, 5, 5]);
      expect(await temporaryOutput.readAsBytes(), [1, 2, 3]);
      await gateway.cleanup(workspace);
    });

    test('restores an existing destination when promotion fails', () async {
      var moveCount = 0;
      gateway = LocalMapSaveFileGateway(
        fileMover: (source, destinationPath) async {
          moveCount++;
          if (moveCount == 2) {
            throw FileSystemException(
              'simulated promotion failure',
              destinationPath,
            );
          }
          await source.rename(destinationPath);
        },
      );
      final destination = File(
        '${root.path}${Platform.pathSeparator}Existing.scx',
      );
      await destination.writeAsBytes(const [9, 8, 7], flush: true);
      final workspace = await gateway.createWorkspace(destination.path);
      final temporaryOutput = File(workspace.temporaryOutputPath);
      await temporaryOutput.writeAsBytes(const [1, 2, 3], flush: true);

      await expectLater(
        gateway.promote(
          workspace: workspace,
          destinationPath: destination.path,
          replaceExisting: true,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(moveCount, 3);
      expect(await destination.readAsBytes(), [9, 8, 7]);
      expect(await temporaryOutput.readAsBytes(), [1, 2, 3]);
      expect(
        await root
            .list()
            .where(
              (entity) => entity is File && entity.path.contains('.backup-'),
            )
            .toList(),
        isEmpty,
      );
      await gateway.cleanup(workspace);
    });

    test('preserves the backup when automatic restoration fails', () async {
      var moveCount = 0;
      gateway = LocalMapSaveFileGateway(
        fileMover: (source, destinationPath) async {
          moveCount++;
          if (moveCount >= 2) {
            throw FileSystemException(
              'simulated move failure',
              destinationPath,
            );
          }
          await source.rename(destinationPath);
        },
      );
      final destination = File(
        '${root.path}${Platform.pathSeparator}Existing.scx',
      );
      await destination.writeAsBytes(const [9, 8, 7], flush: true);
      final workspace = await gateway.createWorkspace(destination.path);
      await File(
        workspace.temporaryOutputPath,
      ).writeAsBytes(const [1, 2, 3], flush: true);

      late MapSavePromotionRecoveryException recoveryError;
      try {
        await gateway.promote(
          workspace: workspace,
          destinationPath: destination.path,
          replaceExisting: true,
        );
        fail('Expected promotion and restoration to fail.');
      } on MapSavePromotionRecoveryException catch (error) {
        recoveryError = error;
      }

      expect(moveCount, 3);
      expect(await destination.exists(), isFalse);
      expect(await File(recoveryError.backupPath).readAsBytes(), [9, 8, 7]);
      expect(recoveryError.destinationPath, destination.absolute.path);
      await gateway.cleanup(workspace);
      expect(await File(recoveryError.backupPath).exists(), isTrue);
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
