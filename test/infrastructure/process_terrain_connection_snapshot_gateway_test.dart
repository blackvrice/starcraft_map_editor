import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';

void main() {
  ProcessTerrainConnectionSnapshotGateway gateway({
    Duration timeout = const Duration(seconds: 15),
    int limit = 2 * 1024 * 1024,
  }) => ProcessTerrainConnectionSnapshotGateway(
    helperExecutablePath:
        '${Platform.environment['SystemRoot']}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    helperArguments: [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      File(
        'test/fixtures/helpers/fake_terrain_snapshot_helper.ps1',
      ).absolute.path,
    ],
    environment: Platform.environment,
    timeout: timeout,
    maximumOutputBytes: limit,
  );
  test(
    'accepts snapshot larger than old catalog limit and retains raw logs',
    () async {
      final result = await gateway().read(
        operationId: 'test',
        installationPath: r'C:\fixture',
        tileset: 0,
      );
      expect(result.isSuccess, isTrue, reason: result.errorCode);
      expect(result.snapshot!.groups, hasLength(2048));
      expect(result.stdout.length, greaterThan(256 * 1024));
      expect(result.stderr, contains('synthetic snapshot log'));
      expect(result.exitCode, 0);
    },
  );
  test('bounds malformed output, helper failure and output overflow', () async {
    for (final (path, code) in [
      ('invalid', 'SC_TERRAIN_RESPONSE_INVALID'),
      ('failure', 'SC_TERRAIN_HELPER_FAILED'),
      ('overflow', 'SC_TERRAIN_OUTPUT_LIMIT'),
    ]) {
      final result = await gateway(
        limit: 1024,
      ).read(operationId: 'test', installationPath: 'C:\\$path', tileset: 0);
      expect(result.errorCode, code);
      expect(result.snapshot, isNull);
      expect(result.stdout.length, lessThanOrEqualTo(1024));
      if (path == 'failure') {
        expect(result.stderr, contains('SC_CASC_STORAGE_OPEN_FAILED'));
      }
    }
  });
  test('timeout kills hung helper and operation can be reused', () async {
    final g = gateway(timeout: const Duration(seconds: 1));
    final result = await g.read(
      operationId: 'test',
      installationPath: r'C:\hang',
      tileset: 0,
    );
    expect(result.errorCode, 'SC_TERRAIN_TIMED_OUT');
    final again = await g.read(
      operationId: 'test',
      installationPath: r'C:\hang',
      tileset: 0,
    );
    expect(again.errorCode, 'SC_TERRAIN_TIMED_OUT');
  });
  test(
    'cancels pending startup and rejects simultaneous duplicate ID',
    () async {
      final g = gateway();
      final pending = g.read(
        operationId: 'test',
        installationPath: r'C:\hang',
        tileset: 0,
      );
      final duplicate = await g.read(
        operationId: 'test',
        installationPath: r'C:\fixture',
        tileset: 0,
      );
      expect(duplicate.errorCode, 'SC_TERRAIN_OPERATION_ACTIVE');
      g.cancel('test');
      expect((await pending).errorCode, 'SC_TERRAIN_CANCELLED');
      g.cancel('unknown');
    },
  );
  test(
    'rejects invalid request and missing executable without a snapshot',
    () async {
      expect(
        (await gateway().read(
          operationId: 'test',
          installationPath: 'relative',
          tileset: 0,
        )).errorCode,
        'SC_TERRAIN_REQUEST_INVALID',
      );
      final missing = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: r'C:\missing-snapshot-helper.exe',
      );
      expect(
        (await missing.read(
          operationId: 'test',
          installationPath: r'C:\fixture',
          tileset: 0,
        )).errorCode,
        'SC_TERRAIN_HELPER_START_FAILED',
      );
    },
  );
}
