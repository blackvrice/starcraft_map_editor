import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/cv5_creep_candidate_profile.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';

void main() {
  const combinations = [
    0,
    0x40,
    0x1000,
    0x1040,
    0x4000,
    0x4040,
    0x5000,
    0x5040,
  ];
  test(
    'retains all independent bit combinations without interpreting coverage',
    () {
      final input = combinations.toList();
      final profile = Cv5CreepCandidateProfile(groupFlags: input);
      input[0] = 0x5040;
      expect(profile.groupFlags, combinations);
      for (var group = 0; group < combinations.length; group++) {
        expect(profile.flagsForGroup(group), combinations[group]);
      }
      expect(profile.flagsForGroup(-1), isNull);
      expect(profile.flagsForGroup(8), isNull);
      expect(() => profile.groupFlags.clear(), throwsUnsupportedError);
    },
  );
  for (final flags in [-1, 1, 0x80, 0x8000, 0x5041, 65536]) {
    test('rejects non-candidate bits or range $flags', () {
      expect(
        () => Cv5CreepCandidateProfile(groupFlags: [flags]),
        throwsArgumentError,
      );
    });
  }
  for (final length in [0, 4097]) {
    test('rejects group count $length', () {
      expect(
        () => Cv5CreepCandidateProfile(groupFlags: List.filled(length, 0)),
        throwsArgumentError,
      );
    });
  }
  test('maximum profile keeps final group and unknown outside coverage', () {
    final flags = List.filled(4096, 0)..[4095] = 0x5040;
    final profile = Cv5CreepCandidateProfile(groupFlags: flags);
    expect(profile.flagsForGroup(4095), 0x5040);
    expect(profile.flagsForGroup(4096), isNull);
  });
  TerrainPlacementSnapshot snapshot({Cv5CreepCandidateProfile? profile}) =>
      TerrainPlacementSnapshot(
        tileset: 0,
        groupBuildable: [true],
        megaTileReferences: [List.filled(16, 65535)],
        walkableMasks: [65535],
        creepCandidateProfile: profile,
      );
  test('profile is optional but must cover exactly the parent CV5 groups', () {
    expect(snapshot().creepCandidateProfile, isNull);
    expect(
      () => snapshot(profile: Cv5CreepCandidateProfile(groupFlags: [0, 0])),
      throwsArgumentError,
    );
  });
  test('group metadata never repairs missing VF4 references', () {
    final result = snapshot(
      profile: Cv5CreepCandidateProfile(groupFlags: [0x5040]),
    );
    expect(result.creepCandidateProfile!.flagsForGroup(0), 0x5040);
    expect(result.tile(0), isNull);
    expect(result.tile(0x8000), isNull);
  });
}
