import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/terrain_placement_snapshot_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/assets/terrain_placement_snapshot_decoder.dart';
import '../fixtures/terrain_placement_fixture.dart';

void main() {
  const decoder = TerrainPlacementSnapshotDecoder();
  TerrainPlacementSource decode(
    Map<String, dynamic> json, {
    String operation = 'fixture',
    String path = r'C:\StarCraft',
    int tileset = 0,
  }) => decoder.decode(
    json,
    operationId: operation,
    installationPath: path,
    tileset: tileset,
  );

  test(
    'optional elevation profile is immutable and participates in identity',
    () {
      final original = decode(terrainPlacementJson());
      expect(original.snapshot.elevation(0), isNull);
      final json = terrainPlacementJson()
        ..['elevationProfile'] = {
          'version': 1,
          'midMasks': [0xaaaa, 0],
          'highMasks': [0xcccc, 0],
        };
      final current = decode(json);
      expect(current.snapshot.elevation(0), (mid: 0xaaaa, high: 0xcccc));
      expect(current.revision, isNot(original.revision));
      json['elevationProfile']['midMasks'][0] = 0;
      expect(current.snapshot.elevation(0)!.mid, 0xaaaa);
      expect(decode(json).revision, isNot(current.revision));
      expect(
        () => current.snapshot.midElevationMasks!.clear(),
        throwsUnsupportedError,
      );
      json['elevationProfile'] = null;
      expect(decode(json).revision, original.revision);
    },
  );
  test(
    'invalid elevation versions, coverage and mask types reject the packet',
    () {
      for (final profile in <Object?>[
        [],
        {'version': 2},
        {
          'version': 1.0,
          'midMasks': [0, 0],
          'highMasks': [0, 0],
        },
        {
          'version': 1,
          'midMasks': [0],
          'highMasks': [0, 0],
        },
        {
          'version': 1,
          'midMasks': [0, 0],
          'highMasks': [0, 65536],
        },
        {
          'version': 1,
          'midMasks': [0, 0],
          'highMasks': [0, 1.0],
        },
        {
          'version': 1,
          'midMasks': [0, 0],
        },
      ]) {
        expect(
          () => decode(terrainPlacementJson()..['elevationProfile'] = profile),
          throwsFormatException,
        );
      }
    },
  );
  for (var tileset = 0; tileset < 8; tileset++) {
    test('optional CV5 profile is source-bound for tileset $tileset', () {
      final json = terrainPlacementJson(tileset: tileset);
      json['creepCandidateProfile'] = {
        'version': 1,
        'groupFlags': [0, 0x5040],
      };
      final source = decode(json, tileset: tileset);
      expect(source.snapshot.creepCandidateProfile!.groupFlags, [0, 0x5040]);
      expect(source.assets.first.path, endsWith('.cv5'));
      json['creepCandidateProfile']['groupFlags'][0] = 0x40;
      expect(source.snapshot.creepCandidateProfile!.groupFlags, [0, 0x5040]);
      expect(
        () => source.snapshot.creepCandidateProfile!.groupFlags.clear(),
        throwsUnsupportedError,
      );
    });
    test('reads derived facts and source identity for tileset $tileset', () {
      final source = decode(
        terrainPlacementJson(tileset: tileset),
        tileset: tileset,
      );
      expect(source.snapshot.tile(0), (buildable: true, walkableMask: 65535));
      expect(source.snapshot.tile(16), (buildable: false, walkableMask: 1));
      expect(source.assets.length, 2);
      expect(source.revision, startsWith('terrain-placement-v1:'));
    });
  }
  test(
    'missing and null profiles preserve legacy unknown state and revision',
    () {
      final missing = decode(terrainPlacementJson());
      final json = terrainPlacementJson()..['creepCandidateProfile'] = null;
      final explicitNull = decode(json);
      expect(missing.snapshot.creepCandidateProfile, isNull);
      expect(explicitNull.snapshot.creepCandidateProfile, isNull);
      expect(explicitNull.revision, missing.revision);
    },
  );
  test(
    'profile presence and every independent bit participate in revision',
    () {
      final missing = decode(terrainPlacementJson()).revision;
      final revisions = <String>{missing};
      for (final flags in [
        0,
        0x40,
        0x1000,
        0x1040,
        0x4000,
        0x4040,
        0x5000,
        0x5040,
      ]) {
        final json = terrainPlacementJson()
          ..['creepCandidateProfile'] = {
            'version': 1,
            'groupFlags': [flags, 0],
          };
        final source = decode(json);
        expect(source.snapshot.creepCandidateProfile!.flagsForGroup(0), flags);
        expect(revisions.add(source.revision), isTrue);
        expect(decode(json).revision, source.revision);
        json['requestId'] = 'moved';
        json['installation']['path'] = r'C:\Other';
        expect(
          decode(json, operation: 'moved', path: r'C:\Other').revision,
          source.revision,
        );
        json['assets'][0]['sha256'] = 'c' * 64;
        expect(
          decode(json, operation: 'moved', path: r'C:\Other').revision,
          isNot(source.revision),
        );
      }
    },
  );
  final invalidProfiles = <String, Object?>{
    'non-object': [],
    'missing version': {
      'groupFlags': [0, 0],
    },
    'unknown version': {
      'version': 2,
      'groupFlags': [0, 0],
    },
    'floating version': {
      'version': 1.0,
      'groupFlags': [0, 0],
    },
    'missing flags': {'version': 1},
    'null flags': {'version': 1, 'groupFlags': null},
    'short flags': {
      'version': 1,
      'groupFlags': [0],
    },
    'extra flags': {
      'version': 1,
      'groupFlags': [0, 0, 0],
    },
    for (final flag in [
      -1,
      1,
      0x80,
      0x8000,
      0x5041,
      65536,
      1.0,
      '0',
      false,
      null,
    ])
      'flag $flag': {
        'version': 1,
        'groupFlags': [0, flag],
      },
  };
  for (final entry in invalidProfiles.entries) {
    test(
      'rejects malformed CV5 profile ${entry.key}, not silent legacy fallback',
      () {
        final json = terrainPlacementJson()
          ..['creepCandidateProfile'] = entry.value;
        expect(() => decode(json), throwsFormatException);
      },
    );
  }
  test(
    'canonical revision ignores transport location but tracks facts and sources',
    () {
      final first = decode(terrainPlacementJson()).revision;
      final moved = terrainPlacementJson();
      moved['requestId'] = 'other';
      moved['installation']['path'] = r'C:\Other';
      expect(
        decode(moved, operation: 'other', path: r'C:\Other').revision,
        first,
      );
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['walkableMasks'][0] = 65534,
        (j) => j['megaTileReferences'][0][0] = 1,
        (j) => j['groupBuildable'][0] = false,
        (j) => j['assets'][1]['sha256'] = 'c' * 64,
        (j) => j['installation']['storageBuildNumber'] = 1,
      ]) {
        final changed = terrainPlacementJson();
        mutate(changed);
        expect(decode(changed).revision, isNot(first));
      }
    },
  );
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'protocol': (j) => j['protocolVersion'] = 2,
    'helper': (j) => j['helperVersion'] = 'old',
    'casc': (j) => j['cascLibRevision'] = 'other',
    'operation': (j) => j['operation'] = 'readTerrainConnections',
    'id': (j) => j['requestId'] = 'other',
    'version': (j) => j['snapshotVersion'] = 2,
    'version type': (j) => j['snapshotVersion'] = 1.0,
    'tileset': (j) => j['tileset'] = 1,
    'tileset type': (j) => j['tileset'] = 0.0,
    'path': (j) => j['installation']['path'] = r'C:\Other',
    'product': (j) => j['installation']['storageProduct'] = '\u0000',
    'build': (j) => j['installation']['storageBuildNumber'] = -1,
    'assets coverage': (j) => j['assets'].removeLast(),
    'asset path': (j) => j['assets'][1]['path'] = 'tileset\\badlands.vx4ex',
    'hash': (j) => j['assets'][0]['sha256'] = 'invalid',
    'cv5 empty': (j) => j['assets'][0]['bytes'] = 0,
    'cv5 stride': (j) => j['assets'][0]['bytes'] = 53,
    'cv5 limit': (j) => j['assets'][0]['bytes'] = 4097 * 52,
    'vf4 stride': (j) => j['assets'][1]['bytes'] = 33,
    'vf4 limit': (j) => j['assets'][1]['bytes'] = 65537 * 32,
    'bool': (j) => j['groupBuildable'][0] = 1,
    'group coverage': (j) => j['groupBuildable'].removeLast(),
    'member coverage': (j) => j['megaTileReferences'][0].removeLast(),
    'reference type': (j) => j['megaTileReferences'][0][0] = '0',
    'reference limit': (j) => j['megaTileReferences'][0][0] = 65536,
    'mask coverage': (j) => j['walkableMasks'].removeLast(),
    'mask type': (j) => j['walkableMasks'][0] = 1.0,
    'mask negative': (j) => j['walkableMasks'][0] = -1,
    'mask limit': (j) => j['walkableMasks'][0] = 65536,
  };
  for (final entry in mutations.entries) {
    test('rejects malformed terrain placement ${entry.key}', () {
      final json = terrainPlacementJson();
      entry.value(json);
      expect(() => decode(json), throwsFormatException);
    });
  }
  test(
    'missing references stay unknown and decoded nested lists are immutable',
    () {
      final json = terrainPlacementJson();
      json['megaTileReferences'][0][0] = 65535;
      final source = decode(json);
      expect(source.snapshot.tile(0), isNull);
      json['walkableMasks'][0] = 0;
      expect(source.snapshot.tile(1)!.walkableMask, 65535);
      expect(
        () => source.snapshot.megaTileReferences[0].clear(),
        throwsUnsupportedError,
      );
      expect(() => source.assets.clear(), throwsUnsupportedError);
    },
  );
}
