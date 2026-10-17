import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/layers/map_layer_controller.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import '../fixtures/document_transfer_fixture.dart';
import '../fixtures/multi_map_fixture.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  late MultiMapFixture f;
  setUp(() => f = MultiMapFixture());
  tearDown(() => f.dispose());
  test(
    'preview is read-only and Apply includes CHK and sound in exactly one target Undo',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      final beforeA = a.maps.state.session!, beforeB = b.maps.state.session!;
      final controller = transferController(f);
      addTearDown(controller.dispose);
      final preview = await controller.prepare(
        source: a,
        target: b,
        selected: {
          'UNIT': {0, 1},
        },
        triggers: {0},
        briefings: {0},
      );
      expect(a.maps.state.session, same(beforeA));
      expect(b.maps.state.session, same(beforeB));
      expect(b.maps.editHistory.undoDepth, 0);
      controller.apply(preview);
      expect(a.maps.state.session, same(beforeA));
      expect(a.maps.editHistory.undoDepth, 0);
      final afterB = b.maps.state.session!;
      final bytes = const RawChkEncoder().encode(afterB.rawDocument);
      expect(afterB.resourceEdits[transferSoundPath], pcmSoundFixture());
      expect(b.maps.editHistory.undoDepth, 1);
      expect(() => controller.apply(preview), throwsStateError);
      expect(b.maps.editHistory.undo(), isTrue);
      expect(
        const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
        const RawChkEncoder().encode(beforeB.rawDocument),
      );
      expect(b.maps.state.session!.resourceEdits, isEmpty);
      expect(b.maps.editHistory.redo(), isTrue);
      expect(
        const RawChkEncoder().encode(b.maps.state.session!.rawDocument),
        bytes,
      );
      expect(
        b.maps.state.session!.resourceEdits[transferSoundPath],
        pcmSoundFixture(),
      );
    },
  );
  test(
    'source or target changes invalidate approval, even with the same CHK identity',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(a.maps, transferSource());
      final controller = transferController(f);
      addTearDown(controller.dispose);
      for (final changed in [a, b]) {
        final preview = await controller.prepare(
          source: a,
          target: b,
          selected: {
            'UNIT': {0, 1},
          },
        );
        adoptTransferDocument(
          changed.maps,
          changed.maps.state.session!.rawDocument,
        );
        expect(() => controller.apply(preview), throwsStateError);
        expect(b.maps.editHistory.undoDepth, 0);
      }
    },
  );
  test(
    'closing source after preview prevents importing detached data',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(a.maps, transferSource());
      final controller = transferController(f);
      final preview = await controller.prepare(
        source: a,
        target: b,
        selected: {
          'UNIT': {0, 1},
        },
      );
      expect(
        await f.workspace.close(
          a,
          expectedRevision: a.revision,
          discardChanges: true,
        ),
        isTrue,
      );
      expect(() => controller.apply(preview), throwsStateError);
      expect(b.maps.editHistory.undoDepth, 0);
    },
  );
  test(
    'both layer locks and newly locked dependency locations block the whole transfer',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      final controller = transferController(f);
      b.value.mapLayerController.setLocked(MapLayerType.units, true);
      await expectLater(
        controller.prepare(
          source: a,
          target: b,
          selected: {
            'UNIT': {0, 1},
          },
        ),
        throwsStateError,
      );
      b.value.mapLayerController.setLocked(MapLayerType.units, false);
      final preview = await controller.prepare(
        source: a,
        target: b,
        triggers: {0},
      );
      a.value.mapLayerController.setLocked(MapLayerType.locations, true);
      expect(() => controller.apply(preview), throwsStateError);
      expect(b.maps.editHistory.undoDepth, 0);
    },
  );
  test(
    'case-insensitive pending sound path conflicts never overwrite the target',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      adoptTransferDocument(
        b.maps,
        b.maps.state.session!.rawDocument,
        resources: {r'STAREDIT\WAV\TRANSFER.WAV': pcmSoundFixture()},
      );
      final before = b.maps.state.session;
      await expectLater(
        transferController(f).prepare(source: a, target: b, triggers: {0}),
        throwsStateError,
      );
      expect(b.maps.state.session, same(before));
      expect(b.maps.editHistory.undoDepth, 0);
    },
  );
  test(
    'malformed or missing source sound is rejected before any map mutation',
    () async {
      final a = f.addMap(), b = f.addMap();
      final controller = transferController(f);
      for (final resources in <Map<String, List<int>?>>[
        {},
        {
          transferSoundPath: [1, 2, 3],
        },
      ]) {
        adoptTransferDocument(a.maps, transferSource(), resources: resources);
        final before = b.maps.state.session;
        await expectLater(
          controller.prepare(source: a, target: b, triggers: {0}),
          throwsA(anything),
        );
        expect(b.maps.state.session, same(before));
        expect(b.maps.editHistory.undoDepth, 0);
      }
    },
  );
  test(
    'late sound read cannot install preview after target changes or dialog cancellation',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      for (final cancel in [false, true]) {
        final controller = transferController(f);
        final task = controller.prepare(source: a, target: b, triggers: {0});
        if (cancel) {
          controller.dispose();
        } else {
          adoptTransferDocument(b.maps, b.maps.state.session!.rawDocument);
        }
        await expectLater(task, throwsStateError);
        expect(controller.preview, isNull);
        expect(b.maps.editHistory.undoDepth, 0);
        expect(a.busy, isFalse);
      }
    },
  );
  test('source snapshot and active brush transactions are validated', () async {
    final a = f.addMap(), b = f.addMap();
    final old = a.maps.state.session;
    adoptTransferDocument(a.maps, transferSource());
    final controller = transferController(f);
    await expectLater(
      controller.prepare(
        source: a,
        target: b,
        selected: {
          'UNIT': {0, 1},
        },
        expectedSource: old,
      ),
      throwsStateError,
    );
    b.maps.editHistory.beginTransaction(controller);
    await expectLater(
      controller.prepare(
        source: a,
        target: b,
        selected: {
          'UNIT': {0, 1},
        },
      ),
      throwsStateError,
    );
    b.maps.editHistory.endTransaction(controller);
  });
  test(
    'pending resource count budget includes existing target resources',
    () async {
      final a = f.addMap(), b = f.addMap();
      adoptTransferDocument(
        a.maps,
        transferSource(),
        resources: {transferSoundPath: pcmSoundFixture()},
      );
      adoptTransferDocument(
        b.maps,
        b.maps.state.session!.rawDocument,
        resources: {
          for (var i = 0; i < 64; i++) 'sound$i.wav': pcmSoundFixture(),
        },
      );
      await expectLater(
        transferController(f).prepare(source: a, target: b, triggers: {0}),
        throwsStateError,
      );
      expect(b.maps.editHistory.undoDepth, 0);
    },
  );
}
