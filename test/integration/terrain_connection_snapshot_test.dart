import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/process_terrain_connection_snapshot_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/starcraft_data_helper_protocol.dart';

void main() {
  final helper = Platform.environment['STARCRAFT_DATA_HELPER_PATH'];
  final installation = Platform.environment['STARCRAFT_TEST_INSTALLATION'];
  final canRun = Platform.isWindows && helper != null && installation != null;

  test(
    'Dart gateway validates all local tilesets and stable snapshot revisions',
    () async {
      final gateway = ProcessTerrainConnectionSnapshotGateway(
        helperExecutablePath: helper!,
      );
      for (var tileset = 0; tileset < 8; tileset++) {
        final first = await gateway.read(
          operationId: 'adapter-$tileset',
          installationPath: installation!,
          tileset: tileset,
        );
        expect(
          first.isSuccess,
          isTrue,
          reason: '${first.errorCode}: ${first.stderr}',
        );
        final second = await gateway.read(
          operationId: 'repeat-$tileset',
          installationPath: installation,
          tileset: tileset,
        );
        expect(second.isSuccess, isTrue, reason: second.errorCode);
        expect(second.snapshot!.revision, first.snapshot!.revision);
        expect(first.snapshot!.groups, isNotEmpty);
        expect(first.snapshot!.assets, hasLength(4));
        expect(first.stdout, contains('"helperVersion":"0.10.0"'));
      }
    },
    skip: canRun ? false : 'Requires local Windows CASC helper/installation.',
  );

  Future<(int, Map<String, dynamic>)> read(Object? tileset) async {
    final process = await Process.start(helper!, const []);
    addTearDown(() => process.kill());
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    process.stdin.writeln(
      jsonEncode({
        'protocolVersion': StarCraftDataHelperProtocol.version,
        'requestId': 'terrain-snapshot-test',
        'operation': 'readTerrainConnections',
        'installationPath': installation,
        'tileset': tileset,
      }),
    );
    await process.stdin.close();
    final exit = await process.exitCode.timeout(
      const Duration(seconds: 40),
      onTimeout: () {
        process.kill();
        throw TimeoutException('Terrain snapshot helper did not finish.');
      },
    );
    await stderr;
    return (exit, jsonDecode(await stdout) as Map<String, dynamic>);
  }

  test(
    'terrain snapshot rejects invalid tilesets before asset access',
    () async {
      for (final value in [null, -1, 8, 1.5, true, '0']) {
        final (exit, json) = await read(value);
        expect(exit, 2);
        expect(json['error']['code'], 'SC_CASC_PROTOCOL_INVALID_TILESET');
        expect(json.containsKey('groups'), isFalse);
      }
    },
    skip: canRun ? false : 'Requires local Windows CASC helper/installation.',
  );

  test(
    'local terrain snapshots cover eight tilesets without resolving shapes',
    () async {
      for (var tileset = 0; tileset < 8; tileset++) {
        final (exit, json) = await read(tileset);
        expect(exit, 0, reason: '$json');
        expect(json['status'], 'success');
        expect(json['requestId'], 'terrain-snapshot-test');
        expect(
          json['helperVersion'],
          StarCraftDataHelperProtocol.helperVersion,
        );
        expect(
          json['cascLibRevision'],
          StarCraftDataHelperProtocol.cascLibRevision,
        );
        expect(json['snapshotVersion'], 2);
        expect(json['tileset'], tileset);
        expect(json['isomShapesResolved'], isFalse);
        final assets = json['assets'] as List;
        expect(assets, hasLength(4));
        for (final asset in assets) {
          expect(asset['bytes'], greaterThan(0));
          expect(asset['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        }
        final groups = json['groups'] as List;
        expect(groups.length, assets.first['bytes'] ~/ 52);
        expect(groups.length, inInclusiveRange(1, 4096));
        for (var i = 0; i < groups.length; i++) {
          final group = groups[i];
          expect(group['group'], i);
          expect(group['terrainTypeWord'], inInclusiveRange(0, 65535));
          expect(group['flagsWord'], inInclusiveRange(0, 65535));
          for (final field in ['linkWords', 'stackWords']) {
            expect(group[field], hasLength(4));
            expect(group[field], everyElement(inInclusiveRange(0, 65535)));
          }
          final members = (group['renderableMembers'] as List).cast<int>();
          expect(members, everyElement(inInclusiveRange(0, 15)));
          expect(members.toSet().length, members.length);
        }
        final (repeatExit, repeat) = await read(tileset);
        expect(repeatExit, 0);
        expect(repeat, json);
      }
    },
    skip: canRun ? false : 'Requires local Windows CASC helper/installation.',
  );
}
