import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_state_gateway.dart';
import 'package:starcraft_map_editor/application/ports/unit_creep_capture_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_capture_input.dart';
import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/creep_capture_fixture.dart';

void main() {
  test('capture payload rejects invalid bytes instead of truncating to u8', () {
    final valid = UnitCreepCaptureInput.prepare(
      syntheticCaptureStateRequest(),
      syntheticCaptureConfiguration(),
    );
    for (final bad in [-1, 256]) {
      for (final badSetup in [false, true]) {
        expect(
          () => UnitCreepCaptureRequest(
            stateRequest: valid.stateRequest,
            inputRevision: valid.inputRevision,
            scenarioChkSha256: valid.scenarioChkSha256,
            baseArchiveSha256: null,
            setupRevision: valid.setupRevision,
            setupSchema: valid.setupSchema,
            scenarioChkBytes: badSetup ? valid.scenarioChkBytes : [bad],
            setupBytes: badSetup ? [bad] : valid.setupBytes,
            resourceEdits: {},
          ),
          throwsArgumentError,
        );
      }
    }
  });
  final config = syntheticCaptureConfiguration();
  String identity({Map<String, List<int>?> resources = const {}}) =>
      UnitCreepCaptureInput.prepare(
        syntheticCaptureStateRequest(resources: resources),
        config,
      ).inputRevision;
  test(
    'current CHK, duplicate/unknown sections and raw strings remain byte-exact',
    () {
      final baseline = basicDocument();
      final doc = baseline.appendSection(basicSection('ZZZZ', [255, 0, 128]));
      final request = syntheticCaptureStateRequest(
        document: doc,
        baseline: baseline,
      );
      final before = const RawChkEncoder().encode(doc);
      final input = UnitCreepCaptureInput.prepare(request, config);
      expect(input.scenarioChkBytes, before);
      expect(input.scenarioChkSha256, sha256.convert(before).toString());
      expect(
        input.scenarioChkBytes,
        isNot(request.session.extractedMap.scenarioChkBytes),
      );
      expect(() => input.scenarioChkBytes[0] = 0, throwsUnsupportedError);
      expect(() => input.setupBytes[0] = 0, throwsUnsupportedError);
      expect(const RawChkEncoder().encode(doc), before);
    },
  );
  test('content identity excludes lifecycle, file paths and modified time', () {
    final first = UnitCreepCaptureInput.prepare(
      syntheticCaptureStateRequest(archiveHash: 'a' * 64),
      config,
    );
    final moved = UnitCreepCaptureInput.prepare(
      syntheticCaptureStateRequest(
        archiveHash: 'a' * 64,
        sourcePath: r'D:\elsewhere\renamed.scx',
        modified: DateTime.utc(2030),
        operationId: 'other',
        documentRevision: 9,
        installationPath: r'D:\StarCraft',
      ),
      config,
    );
    expect(first.inputRevision, moved.inputRevision);
    expect(first.baseArchiveSha256, 'a' * 64);
    expect(
      UnitCreepCaptureInput.prepare(
        syntheticCaptureStateRequest(archiveHash: 'b' * 64),
        config,
      ).inputRevision,
      isNot(first.inputRevision),
    );
    expect(
      UnitCreepCaptureInput.prepare(
        syntheticCaptureStateRequest(archiveHash: 'a' * 64, archiveSize: 101),
        config,
      ).inputRevision,
      isNot(first.inputRevision),
    );
    expect(identity(), isNot(first.inputRevision));
  });
  test(
    'resource insertion order is irrelevant; tombstone, empty and absent differ',
    () {
      final first = identity(
        resources: {
          r'sound\b.wav': [1, 2],
          r'sound\a.wav': null,
        },
      );
      expect(
        identity(
          resources: {
            r'sound\a.wav': null,
            r'sound\b.wav': [1, 2],
          },
        ),
        first,
      );
      expect(
        identity(
          resources: {
            r'sound\a.wav': null,
            r'sound\b.wav': [1, 3],
          },
        ),
        isNot(first),
      );
      expect(
        identity(
          resources: {
            r'sound\a.wav': [],
            r'sound\b.wav': [1, 2],
          },
        ),
        isNot(first),
      );
      expect(
        identity(
          resources: {
            r'sound\b.wav': [1, 2],
          },
        ),
        isNot(first),
      );
    },
  );
  test('resource and setup payloads are defensive immutable snapshots', () {
    final bytes = [1, 2];
    final setup = [1, 2, 3];
    final request = syntheticCaptureStateRequest(
      resources: {r'sound\a.wav': bytes},
    );
    final configuration = syntheticCaptureConfiguration(setupBytes: setup);
    bytes[0] = 9;
    setup[0] = 9;
    final input = UnitCreepCaptureInput.prepare(request, configuration);
    expect(input.resourceEdits[r'sound\a.wav'], [1, 2]);
    expect(input.setupBytes, [1, 2, 3]);
    expect(() => input.resourceEdits.clear(), throwsUnsupportedError);
    expect(
      () => input.resourceEdits[r'sound\a.wav']![0] = 0,
      throwsUnsupportedError,
    );
    expect(
      () => configuration.supportedGameVersions.clear(),
      throwsUnsupportedError,
    );
  });
  test(
    'setup bytes/schema and each numeric data source component bind identity',
    () {
      final request = syntheticCaptureStateRequest();
      final first = UnitCreepCaptureInput.prepare(request, config);
      for (final configuration in [
        syntheticCaptureConfiguration(setupBytes: [1, 2, 4]),
        syntheticCaptureConfiguration(setupSchema: 'other'),
      ]) {
        final changed = UnitCreepCaptureInput.prepare(request, configuration);
        expect(changed.inputRevision, isNot(first.inputRevision));
        expect(changed.setupRevision, isNot(first.setupRevision));
      }
      for (final source in [
        ('other', 13515, 'helper', 'CascLib'),
        ('s1', 1, 'helper', 'CascLib'),
        ('s1', 13515, 'other', 'CascLib'),
        ('s1', 13515, 'helper', 'other'),
      ]) {
        expect(
          UnitCreepCaptureInput.prepare(
            syntheticCaptureStateRequest(dataIdentity: source),
            config,
          ).inputRevision,
          isNot(first.inputRevision),
        );
      }
    },
  );
  for (final path in [
    r'..\escape.wav',
    'sound/a.wav',
    r'C:\bad.wav',
    'sound\\a.txt',
    'a\u0000.wav',
  ]) {
    test('rejects unsupported resource path $path without normalization', () {
      expect(
        () => identity(
          resources: {
            path: [1],
          },
        ),
        throwsFormatException,
      );
    });
  }
  test('rejects ambiguous case aliases and invalid byte values', () {
    expect(
      () => identity(resources: {'a.wav': [], 'A.wav': null}),
      throwsFormatException,
    );
    for (final value in [-1, 256]) {
      expect(
        () => identity(
          resources: {
            'a.wav': [value],
          },
        ),
        throwsFormatException,
      );
    }
  });
  test('resource count and CHK size budgets fail closed before encoding', () {
    expect(
      () => identity(resources: {for (var i = 0; i < 513; i++) '$i.wav': null}),
      throwsFormatException,
    );
    final request = syntheticCaptureStateRequest();
    final size = const RawChkEncoder()
        .encode(request.session.rawDocument)
        .length;
    expect(
      UnitCreepCaptureInput.prepare(
        request,
        syntheticCaptureConfiguration(maximumChkBytes: size),
      ).scenarioChkBytes,
      hasLength(size),
    );
    expect(
      () => UnitCreepCaptureInput.prepare(
        request,
        syntheticCaptureConfiguration(maximumChkBytes: size - 1),
      ),
      throwsFormatException,
    );
  });
  test(
    'per-entry and total resource budgets are inclusive and independent',
    () {
      final limited = syntheticCaptureConfiguration(
        maximumResourceBytes: 3,
        maximumResourceEntryBytes: 2,
      );
      expect(
        UnitCreepCaptureInput.prepare(
          syntheticCaptureStateRequest(
            resources: {
              'a.wav': [1, 2],
            },
          ),
          limited,
        ).resourceEdits,
        hasLength(1),
      );
      expect(
        () => UnitCreepCaptureInput.prepare(
          syntheticCaptureStateRequest(
            resources: {
              'a.wav': [1, 2, 3],
            },
          ),
          limited,
        ),
        throwsFormatException,
      );
      expect(
        () => UnitCreepCaptureInput.prepare(
          syntheticCaptureStateRequest(
            resources: {
              'a.wav': [1, 2],
              'b.wav': [3, 4],
            },
          ),
          limited,
        ),
        throwsFormatException,
      );
    },
  );
  for (final copies in [0, 2]) {
    test('missing/duplicate DIM is not a capture input $copies', () {
      final doc = basicDocument();
      final dim = doc.sections.singleWhere((s) => s.name == 'DIM ');
      final changed = RawChkDocument(
        sourceLength: doc.sourceLength,
        sections: [
          for (final s in doc.sections)
            if (s.name != 'DIM ') s,
          for (var i = 0; i < copies; i++) dim,
        ],
      );
      expect(
        () => UnitCreepCaptureInput.prepare(
          syntheticCaptureStateRequest(document: changed),
          config,
        ),
        throwsFormatException,
      );
    });
  }
  final invalidBudgets = <String, UnitCreepCaptureConfiguration Function()>{
    'CHK zero': () => syntheticCaptureConfiguration(maximumChkBytes: 0),
    'CHK hard ceiling': () => syntheticCaptureConfiguration(
      maximumChkBytes: UnitCreepCaptureInput.maximumChkBytes + 1,
    ),
    'resource zero': () =>
        syntheticCaptureConfiguration(maximumResourceBytes: 0),
    'resource hard ceiling': () => syntheticCaptureConfiguration(
      maximumResourceBytes: UnitCreepCaptureInput.maximumResourceBytes + 1,
    ),
    'entry zero': () =>
        syntheticCaptureConfiguration(maximumResourceEntryBytes: 0),
    'entry hard ceiling': () => syntheticCaptureConfiguration(
      maximumResourceEntryBytes: 16 * 1024 * 1024 + 1,
    ),
  };
  for (final entry in invalidBudgets.entries) {
    test(
      'rejects configuration budget ${entry.key}',
      () => expect(entry.value, throwsArgumentError),
    );
  }
  final invalidConfigurations =
      <String, UnitCreepCaptureConfiguration Function()>{
        for (final games in [
          <String>{},
          {for (var i = 0; i < 33; i++) 'game-$i'},
          {'\u0000'},
        ])
          'game versions $games': () => UnitCreepCaptureConfiguration(
            providerId: 'synthetic',
            collectorVersion: 'v1',
            gameSessionId: 'game',
            setupSchema: 'v1',
            supportedGameVersions: games,
            setupBytes: [1],
          ),
        'provider': () => UnitCreepCaptureConfiguration(
          providerId: '',
          collectorVersion: 'v1',
          gameSessionId: 'game',
          setupSchema: 'v1',
          supportedGameVersions: {'synthetic'},
          setupBytes: [1],
        ),
        'collector': () => UnitCreepCaptureConfiguration(
          providerId: 'synthetic',
          collectorVersion: 'x' * 257,
          gameSessionId: 'game',
          setupSchema: 'v1',
          supportedGameVersions: {'synthetic'},
          setupBytes: [1],
        ),
        'session': () => UnitCreepCaptureConfiguration(
          providerId: 'synthetic',
          collectorVersion: 'v1',
          gameSessionId: ' ',
          setupSchema: 'v1',
          supportedGameVersions: {'synthetic'},
          setupBytes: [1],
        ),
        'schema': () => syntheticCaptureConfiguration(setupSchema: '\u0080'),
      };
  for (final entry in invalidConfigurations.entries) {
    test(
      'rejects configuration identity ${entry.key}',
      () => expect(entry.value, throwsArgumentError),
    );
  }
  for (final request in [
    syntheticCaptureStateRequest(operationId: ''),
    syntheticCaptureStateRequest(documentRevision: -1),
    syntheticCaptureStateRequest(installationPath: 'relative'),
    syntheticCaptureStateRequest(model: UnitCreepStateModel.live),
    syntheticCaptureStateRequest(restricted: true),
    syntheticCaptureStateRequest(dataIdentity: ('', 1, 'h', 'c')),
    syntheticCaptureStateRequest(dataIdentity: ('s1', -1, 'h', 'c')),
  ].indexed) {
    test('rejects incomplete/unsupported capture request ${request.$1}', () {
      expect(
        () => UnitCreepCaptureInput.prepare(request.$2, config),
        throwsFormatException,
      );
    });
  }
  for (final bytes in [
    <int>[],
    [-1],
    [256],
    List.filled(65537, 0),
  ]) {
    test(
      'rejects invalid setup byte payload length ${bytes.length} value ${bytes.firstOrNull}',
      () {
        expect(
          () => syntheticCaptureConfiguration(setupBytes: bytes),
          throwsArgumentError,
        );
      },
    );
  }
  test(
    'inclusive setup and resource count ceilings remain bounded and usable',
    () {
      final configuration = syntheticCaptureConfiguration(
        setupBytes: List.filled(65536, 0),
      );
      final request = syntheticCaptureStateRequest(
        resources: {for (var i = 0; i < 512; i++) '$i.wav': null},
      );
      final input = UnitCreepCaptureInput.prepare(request, configuration);
      expect(input.setupBytes, hasLength(65536));
      expect(input.resourceEdits, hasLength(512));
    },
  );
}
