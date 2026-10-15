import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_observation.dart';

import '../../fixtures/creep_observation_fixture.dart';

void main() {
  final textFields = <String, UnitCreepObservation Function(String)>{
    'contract': (v) => syntheticCreepObservation(contractRevision: v),
    'collector version': (v) => syntheticCreepObservation(collectorVersion: v),
    'game version': (v) => syntheticCreepObservation(gameVersion: v),
    'game session': (v) => syntheticCreepObservation(gameSessionId: v),
    'setup': (v) => syntheticCreepObservation(setupRevision: v),
  };
  for (final field in textFields.entries) {
    final invalid = ['', ' ', '\u0000', '\u0080', 'x' * 257];
    for (var i = 0; i < invalid.length; i++) {
      test('rejects invalid ${field.key} case $i', () {
        expect(() => field.value(invalid[i]), throwsArgumentError);
      });
    }
  }
  for (final frame in [-1, 0x100000000]) {
    test('rejects invalid raw frame $frame', () {
      expect(
        () => syntheticCreepObservation(gameFrame: frame),
        throwsArgumentError,
      );
    });
    test('rejects invalid normalized frame $frame', () {
      expect(
        () => syntheticCreepObservation(simulationFrame: frame),
        throwsArgumentError,
      );
    });
  }
  test(
    'frame budget is explicit and raw numbering is not normalized frame zero',
    () {
      final observation = syntheticCreepObservation(gameFrame: 0xffffffff);
      expect(observation.gameFrame, 0xffffffff);
      expect(observation.simulationFrame, 0);
      expect(observation.isInitialMapObservation, isTrue);
      expect(
        syntheticCreepObservation(
          simulationFrame: 0xffffffff,
        ).isInitialMapObservation,
        isFalse,
      );
    },
  );
  for (final phase in UnitCreepObservationPhase.values) {
    for (final frame in [0, 1]) {
      test(
        'initial eligibility requires declared phase $phase and frame $frame',
        () {
          expect(
            syntheticCreepObservation(
              phase: phase,
              simulationFrame: frame,
            ).isInitialMapObservation,
            phase ==
                    UnitCreepObservationPhase
                        .initializedBeforeFirstTriggerCycle &&
                frame == 0,
          );
        },
      );
    }
  }
  test(
    'unsupported observation contract never authorizes initial coverage',
    () {
      expect(
        syntheticCreepObservation(
          contractRevision: 'future-contract',
        ).isInitialMapObservation,
        isFalse,
      );
    },
  );
  for (final (authority, player) in [
    (UnitCreepObservationAuthority.fullMap, 0),
    (UnitCreepObservationAuthority.unverified, 0),
    (UnitCreepObservationAuthority.playerVision, null),
    (UnitCreepObservationAuthority.playerVision, -1),
    (UnitCreepObservationAuthority.playerVision, 12),
  ]) {
    test('rejects inconsistent observer $authority $player', () {
      expect(
        () => syntheticCreepObservation(
          authority: authority,
          observerPlayer: player,
        ),
        throwsArgumentError,
      );
    });
  }
  for (final player in [0, 11]) {
    test('records explicit player observation $player', () {
      final observation = syntheticCreepObservation(
        authority: UnitCreepObservationAuthority.playerVision,
        observerPlayer: player,
      );
      expect(observation.observerPlayer, player);
      expect(observation.isInitialMapObservation, isTrue);
    });
  }
  test('unverified authority never authorizes even declared initial phase', () {
    expect(
      syntheticCreepObservation(
        authority: UnitCreepObservationAuthority.unverified,
      ).isInitialMapObservation,
      isFalse,
    );
  });
  for (final (width, height) in [(0, 1), (257, 1), (1, 0), (1, 257)]) {
    test('rejects observation dimensions $width x $height', () {
      expect(
        () => syntheticCreepObservation(
          width: width,
          height: height,
          observedTiles: [],
        ),
        throwsArgumentError,
      );
    });
  }
  for (final count in [0, 3, 5]) {
    test('rejects incomplete or excess observation mask $count', () {
      expect(
        () => syntheticCreepObservation(
          width: 2,
          height: 2,
          observedTiles: List.filled(count, true),
        ),
        throwsArgumentError,
      );
    });
  }
  test(
    'partial observation is row-major, immutable and does not infer hidden absence',
    () {
      final observed = [true, false, true, false];
      final observation = syntheticCreepObservation(
        width: 2,
        height: 2,
        observedTiles: observed,
      );
      final coverage = UnitCreepCoverage(
        width: 2,
        height: 2,
        tiles: [
          UnitCreepTile.absent,
          UnitCreepTile.present,
          UnitCreepTile.unknown,
          UnitCreepTile.absent,
        ],
      );
      observed[0] = false;
      expect(observation.observedTiles[0], isTrue);
      expect(() => observation.observedTiles.clear(), throwsUnsupportedError);
      expect(observation.restrictCoverage(coverage)!.tiles, [
        UnitCreepTile.absent,
        UnitCreepTile.unknown,
        UnitCreepTile.unknown,
        UnitCreepTile.unknown,
      ]);
      expect(coverage.tiles[1], UnitCreepTile.present);
      expect(coverage.tiles[3], UnitCreepTile.absent);
      expect(
        () => observation.restrictCoverage(coverage)!.tiles.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'all observed coverage reuses its immutable value; mismatched dimensions stay unavailable',
    () {
      final coverage = UnitCreepCoverage(
        width: 1,
        height: 1,
        tiles: [UnitCreepTile.present],
      );
      expect(
        syntheticCreepObservation(
          width: 1,
          height: 1,
        ).restrictCoverage(coverage),
        same(coverage),
      );
      expect(
        syntheticCreepObservation(
          width: 2,
          height: 1,
        ).restrictCoverage(coverage),
        isNull,
      );
    },
  );
  test(
    'maximum mask includes the final tile without treating authority as observation',
    () {
      final flags = List.filled(256 * 256, true)..[65535] = false;
      final observation = syntheticCreepObservation(
        width: 256,
        height: 256,
        observedTiles: flags,
      );
      final coverage = UnitCreepCoverage(
        width: 256,
        height: 256,
        tiles: List.filled(65536, UnitCreepTile.present),
      );
      final restricted = observation.restrictCoverage(coverage)!;
      expect(restricted.tileAt(x: 254, y: 255), UnitCreepTile.present);
      expect(restricted.tileAt(x: 255, y: 255), UnitCreepTile.unknown);
    },
  );
}
