import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/assets/terrain_connection_snapshot_decoder.dart';
import '../fixtures/terrain_snapshot_fixture.dart';

void main() {
  const decoder = TerrainConnectionSnapshotDecoder();
  dynamic decode(Map<String, dynamic> json) => decoder.decode(
    json,
    operationId: 'fixture',
    installationPath: r'C:\StarCraft',
    tileset: 0,
  );

  test('snapshot preserves unknown words and immutable collections', () {
    final json = terrainSnapshotJson();
    final snapshot = decode(json);
    expect(snapshot.groups.first.linkWords, [0, 48, 64, 65535]);
    expect(snapshot.groups.first.terrainTypeWord, 65535);
    json['groups'][0]['linkWords'][0] = 42;
    expect(snapshot.groups.first.linkWords.first, 0);
    expect(() => snapshot.groups.clear(), throwsUnsupportedError);
    expect(() => snapshot.assets.clear(), throwsUnsupportedError);
    expect(
      () => snapshot.groups.first.linkWords.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.groups.first.renderableMembers.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'revision is stable across transport and changes with snapshot identity',
    () {
      final first = decode(terrainSnapshotJson());
      final reordered = Map<String, dynamic>.fromEntries(
        terrainSnapshotJson().entries.toList().reversed,
      );
      expect(decode(reordered).revision, first.revision);
      final transport = terrainSnapshotJson()..['requestId'] = 'other';
      transport['installation']['path'] = r'D:\Another';
      expect(
        decoder
            .decode(
              transport,
              operationId: 'other',
              installationPath: r'D:\Another',
              tileset: 0,
            )
            .revision,
        first.revision,
      );
      for (final change in <void Function(Map<String, dynamic>)>[
        (j) => j['assets'][0]['sha256'] = 'b' * 64,
        (j) => j['installation']['storageBuildNumber']++,
        (j) => j['groups'][0]['flagsWord']++,
        (j) => j['groups'][0]['megaTileReferences'][0]++,
      ]) {
        final json = terrainSnapshotJson();
        change(json);
        expect(decode(json).revision, isNot(first.revision));
      }
    },
  );

  test('rejects mismatched identity and malformed or incomplete metadata', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (j) => j['protocolVersion'] = 2,
      (j) => j['protocolVersion'] = 3.0,
      (j) => j['snapshotVersion'] = 1.0,
      (j) => j['tileset'] = 0.0,
      (j) => j['helperVersion'] = '0.8.0',
      (j) => j['cascLibRevision'] = 'other',
      (j) => j['requestId'] = 'other',
      (j) => j['operation'] = 'other',
      (j) => j['status'] = 'error',
      (j) => j['snapshotVersion'] = 1,
      (j) => j['tileset'] = 1,
      (j) => j['isomShapesResolved'] = true,
      (j) => j['installation']['path'] = r'C:\Elsewhere',
      (j) => j['installation']['storageBuildNumber'] = 1.5,
      (j) => j['assets'].removeLast(),
      (j) => j['assets'][0]['path'] = r'tileset\jungle.cv5',
      (j) => j['assets'][0]['sha256'] = 'x' * 64,
      (j) => j['assets'][0]['bytes'] = 53,
      (j) => j['assets'][1]['bytes'] = 63,
      (j) => j['assets'][3]['bytes'] = 1023,
      (j) => j['groups'].removeLast(),
      (j) => j['groups'][1]['group'] = 0,
      (j) => j['groups'][0]['linkWords'] = [0, 0, 0],
      (j) => j['groups'][0]['stackWords'][0] = -1,
      (j) => j['groups'][0]['flagsWord'] = 65536,
      (j) => j['groups'][0]['megaTileReferences'] = [1],
      (j) => j['groups'][0]['megaTileReferences'][0] = 65536,
      (j) => j['groups'][0]['megaTileReferences'][0] = 1.5,
      (j) => j['groups'][0]['renderableMembers'] = [0, 0],
      (j) => j['groups'][0]['renderableMembers'] = [3, 0],
      (j) => j['groups'][0]['renderableMembers'] = [16],
    ]) {
      final json = terrainSnapshotJson();
      change(json);
      expect(() => decode(json), throwsFormatException);
    }
  });
}
