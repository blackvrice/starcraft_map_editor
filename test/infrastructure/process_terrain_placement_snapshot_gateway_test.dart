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
    'reads maximum derived CV5/VF4 coverage and keeps bounded source logs',
    () async {
      final result = await gateway().readPlacement(
        operationId: 'placement',
        installationPath: r'C:\fixture',
        tileset: 0,
      );
      expect(result.isSuccess, isTrue, reason: result.errorCode);
      final snapshot = result.source!.snapshot;
      expect(snapshot.groupBuildable, hasLength(4096));
      expect(snapshot.walkableMasks, hasLength(65536));
      expect(snapshot.midElevationMasks, hasLength(65536));
      expect(snapshot.highElevationMasks, hasLength(65536));
      expect(snapshot.elevation(65535), (mid: 65535, high: 65535));
      expect(snapshot.creepCandidateProfile!.groupFlags, hasLength(4096));
      expect(snapshot.creepCandidateProfile!.flagsForGroup(4095), 0x5040);
      expect(snapshot.tile(65535), (buildable: false, walkableMask: 65535));
      expect(result.stdout.length, greaterThan(256 * 1024));
      expect(result.stderr, contains('synthetic placement snapshot log'));
      expect(result.exitCode, 0);
    },
    skip: !Platform.isWindows,
  );

  test(
    'legacy helper response stays usable without candidate metadata',
    () async {
      final result = await gateway().readPlacement(
        operationId: 'placement',
        installationPath: r'C:\legacy',
        tileset: 0,
      );
      expect(result.isSuccess, isTrue, reason: result.errorCode);
      expect(result.source!.snapshot.creepCandidateProfile, isNull);
      expect(result.source!.snapshot.elevation(0), isNull);
      expect(result.source!.snapshot.tile(0), (
        buildable: true,
        walkableMask: 0,
      ));
    },
    skip: !Platform.isWindows,
  );

  for (final (path, code, limit) in [
    ('invalid', 'SC_TERRAIN_RESPONSE_INVALID', 1024),
    ('failure', 'SC_TERRAIN_HELPER_FAILED', 1024),
    ('overflow', 'SC_TERRAIN_OUTPUT_LIMIT', 1024),
    ('mismatch', 'SC_TERRAIN_RESPONSE_INVALID', 2 * 1024 * 1024),
    ('bad-profile', 'SC_TERRAIN_RESPONSE_INVALID', 2 * 1024 * 1024),
    ('bad-elevation', 'SC_TERRAIN_RESPONSE_INVALID', 2 * 1024 * 1024),
  ]) {
    test('placement transport rejects $path without a usable source', () async {
      final result = await gateway(limit: limit).readPlacement(
        operationId: 'placement',
        installationPath: 'C:\\$path',
        tileset: 0,
      );
      expect(result.errorCode, code);
      expect(result.source, isNull);
      expect(result.stdout.length, lessThanOrEqualTo(limit));
    }, skip: !Platform.isWindows);
  }
  test(
    'placement timeout can be retried and operations share cancellation ownership',
    () async {
      final g = gateway(timeout: const Duration(seconds: 1));
      for (var i = 0; i < 2; i++) {
        final result = await g.readPlacement(
          operationId: 'placement',
          installationPath: r'C:\hang',
          tileset: 0,
        );
        expect(result.errorCode, 'SC_TERRAIN_TIMED_OUT');
      }
      final pending = g.readPlacement(
        operationId: 'placement',
        installationPath: r'C:\hang',
        tileset: 0,
      );
      final duplicate = await g.read(
        operationId: 'placement',
        installationPath: r'C:\fixture',
        tileset: 0,
      );
      expect(duplicate.errorCode, 'SC_TERRAIN_OPERATION_ACTIVE');
      g.cancel('placement');
      expect((await pending).errorCode, 'SC_TERRAIN_CANCELLED');
    },
    skip: !Platform.isWindows,
  );
  test(
    'placement request validation and helper start failure preserve the boundary',
    () async {
      expect(
        (await gateway().readPlacement(
          operationId: 'placement',
          installationPath: 'relative',
          tileset: 0,
        )).errorCode,
        'SC_TERRAIN_REQUEST_INVALID',
      );
      expect(
        (await gateway().readPlacement(
          operationId: 'placement',
          installationPath: r'C:\fixture',
          tileset: 8,
        )).errorCode,
        'SC_TERRAIN_REQUEST_INVALID',
      );
      final missing = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: r'C:\missing-terrain-placement.exe',
      );
      expect(
        (await missing.readPlacement(
          operationId: 'placement',
          installationPath: r'C:\fixture',
          tileset: 0,
        )).errorCode,
        'SC_TERRAIN_HELPER_START_FAILED',
      );
    },
    skip: !Platform.isWindows,
  );
}
