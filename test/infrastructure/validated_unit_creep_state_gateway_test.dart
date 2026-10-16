import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/unit_creep_coverage.dart';
import 'package:starcraft_map_editor/infrastructure/placement/validated_unit_creep_state_gateway.dart';
import '../fixtures/creep_capture_fixture.dart';

void main() {
  late SyntheticCreepCaptureGateway capture;
  late ValidatedUnitCreepStateGateway gateway;
  setUp(() {
    capture = SyntheticCreepCaptureGateway();
    gateway = ValidatedUnitCreepStateGateway(
      captureGateway: capture,
      configuration: syntheticCaptureConfiguration(),
    );
  });
  tearDown(() => capture.releaseAll());
  test(
    'explicit intake binds input, metadata and logs without changing document',
    () async {
      final request = syntheticCaptureStateRequest();
      final before = const RawChkEncoder().encode(request.session.rawDocument);
      final result = await gateway.read(request);
      expect(result.isSuccess, isTrue, reason: result.errorCode);
      expect(
        result.snapshot!.coverageFor(request)!.tiles.first,
        UnitCreepTile.present,
      );
      expect(
        result.snapshot!.observation!.setupRevision,
        capture.requests.single.setupRevision,
      );
      expect(result.stdout, contains('not game evidence'));
      expect(result.stderr, 'synthetic diagnostic');
      expect(result.snapshot!.revision, startsWith('captured-creep-v1:'));
      expect(const RawChkEncoder().encode(request.session.rawDocument), before);
      expect(request.session.isDirty, isTrue);
    },
  );
  for (final failure in [
    'empty',
    'request',
    'input',
    'provider',
    'revision',
    'collector',
    'game',
    'session',
    'setup',
    'contract',
    'phase',
    'simulation',
    'authority',
    'dimensions',
    'error',
    'exit',
    'output',
    'sync',
    'throw',
  ]) {
    test('rejects $failure and explicit retry recovers', () async {
      capture.failure = failure;
      final request = syntheticCaptureStateRequest();
      final failed = await gateway.read(request);
      expect(failed.isSuccess, isFalse);
      expect(failed.snapshot, isNull);
      final expectedCode = switch (failure) {
        'sync' || 'throw' => 'UNIT_CREEP_CAPTURE_EXCEPTION',
        'error' || 'exit' => 'UNIT_CREEP_CAPTURE_FAILED',
        'output' => 'UNIT_CREEP_CAPTURE_OUTPUT_LIMIT',
        _ => 'UNIT_CREEP_CAPTURE_RESPONSE_INVALID',
      };
      expect(failed.errorCode, expectedCode);
      expect(failed.stdout.length, lessThanOrEqualTo(65536));
      capture.failure = null;
      expect((await gateway.read(request)).isSuccess, isTrue);
    });
  }
  test(
    'unobserved present/absent remain unknown and revisions track sampled state',
    () async {
      final request = syntheticCaptureStateRequest();
      final present = (await gateway.read(request)).snapshot!;
      expect(
        (await gateway.read(request)).snapshot!.revision,
        present.revision,
      );
      capture.frame++;
      expect(
        (await gateway.read(request)).snapshot!.revision,
        isNot(present.revision),
      );
      capture.visible = false;
      for (final fill in [UnitCreepTile.present, UnitCreepTile.absent]) {
        capture.fill = fill;
        final result = await gateway.read(request);
        expect(result.isSuccess, isTrue);
        expect(
          result.snapshot!.coverageFor(request)!.tiles,
          everyElement(UnitCreepTile.unknown),
        );
      }
    },
  );
  test(
    'invalid request does not call capture; timeout must be positive',
    () async {
      final result = await gateway.read(
        syntheticCaptureStateRequest(installationPath: 'relative'),
      );
      expect(result.errorCode, 'UNIT_CREEP_CAPTURE_INPUT_INVALID');
      expect(capture.requests, isEmpty);
      expect(
        () => ValidatedUnitCreepStateGateway(
          captureGateway: capture,
          configuration: syntheticCaptureConfiguration(),
          timeout: Duration.zero,
        ),
        throwsArgumentError,
      );
      await gateway.cancel('unknown');
      expect(capture.cancelled, isEmpty);
    },
  );
  for (final cancelFailure in [null, 'sync', 'async']) {
    test(
      'cancel $cancelFailure owns request and late reply cannot replace retry',
      () async {
        capture
          ..hold = true
          ..cancelFailure = cancelFailure;
        final request = syntheticCaptureStateRequest();
        final first = gateway.read(request);
        expect(capture.requests, hasLength(1));
        expect(
          (await gateway.read(request)).errorCode,
          'UNIT_CREEP_CAPTURE_ACTIVE',
        );
        await gateway.cancel(request.operationId);
        expect((await first).errorCode, 'UNIT_CREEP_CAPTURE_CANCELLED');
        expect(capture.cancelled, [capture.requests.first]);
        final retry = gateway.read(request);
        expect(capture.requests, hasLength(2));
        capture.release(capture.requests.first);
        capture.release(capture.requests.last);
        expect((await retry).isSuccess, isTrue);
      },
    );
  }
  test(
    'timeout cancels only its request and same operation ID can retry',
    () async {
      capture.hold = true;
      gateway = ValidatedUnitCreepStateGateway(
        captureGateway: capture,
        configuration: syntheticCaptureConfiguration(),
        timeout: const Duration(milliseconds: 50),
      );
      final request = syntheticCaptureStateRequest();
      expect(
        (await gateway.read(request)).errorCode,
        'UNIT_CREEP_CAPTURE_TIMED_OUT',
      );
      expect(capture.cancelled, [capture.requests.single]);
      capture.hold = false;
      expect((await gateway.read(request)).isSuccess, isTrue);
    },
  );
}
