import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_creep_capture_workspace_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_file_fingerprint_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_capture_input.dart';
import 'package:starcraft_map_editor/infrastructure/placement/unit_creep_map_preparer.dart';

import '../fixtures/basic_editing_fixture.dart';
import '../fixtures/creep_capture_fixture.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  final skipReason = !Platform.isWindows
      ? 'Windows helper required.'
      : helper == null || helper.isEmpty
      ? 'Set MAP_ARCHIVE_HELPER_PATH.'
      : false;

  for (final saved in [false, true]) {
    test(
      'native MPQ prepares ${saved ? 'saved' : 'new'} self-authored capture input',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'creep_native_test_',
        );
        addTearDown(() => root.delete(recursive: true));
        final helperRoot = await Directory('${root.path}/helper').create();
        final gateway = ProcessMapArchiveGateway(
          helperExecutablePath: helper!,
          temporaryRoot: helperRoot,
        );
        final fingerprints = LocalMapFileFingerprintGateway();
        final config = syntheticCaptureConfiguration();
        final baseline = basicDocument();
        final current = baseline.appendSection(
          basicSection('ZZZZ', [0, 255, 4]),
        );
        final original = File('${root.path}/original.scx');
        final sound = pcmSoundFixture();
        final replacement = pcmSoundFixture()..[44] = 129;
        if (saved) {
          final write = await gateway.writeTemporary(
            MapArchiveWriteRequest(
              operationId: 'creep-source',
              sourcePath: null,
              temporaryOutputPath: original.path,
              scenarioChkBytes: const RawChkEncoder().encode(baseline),
              resourceEdits: {
                'old.wav': sound,
                'keep.wav': sound,
                'remove.wav': sound,
              },
              timeout: const Duration(seconds: 30),
            ),
          );
          expect(write.isSuccess, isTrue, reason: '${write.diagnostics}');
        }
        final sourceFingerprint = saved
            ? await fingerprints.fingerprint(original.path)
            : null;
        final sourceBytes = saved ? await original.readAsBytes() : null;
        final state = syntheticCaptureStateRequest(
          document: current,
          baseline: baseline,
          sourcePath: original.path,
          archiveHash: sourceFingerprint?.sha256Digest,
          archiveSize: sourceFingerprint?.sizeBytes ?? 0,
          modified: sourceFingerprint?.modifiedAtUtc,
          resources: {
            if (!saved) 'old.wav': replacement,
            'new.wav': sound,
            if (saved) 'remove.wav': null,
          },
        );
        final request = UnitCreepCaptureInput.prepare(state, config);
        final preparer = UnitCreepMapPreparer(
          archiveGateway: gateway,
          resourceReader: gateway,
          fingerprintGateway: fingerprints,
          workspaceGateway: LocalCreepCaptureWorkspaceGateway(
            temporaryRoot: root.path,
          ),
          configuration: config,
        );
        final result = await preparer.prepare(request);
        expect(
          result.isSuccess,
          isTrue,
          reason:
              '${result.errorCode}: ${result.errorDetails} '
              '${result.diagnostics.map((d) => '${d.code}: ${d.message} ${d.rawDetails}').join('\n')}',
        );
        final prepared = result.prepared!;
        final reopened = await gateway.open(
          MapArchiveOpenRequest(
            operationId: 'creep-check',
            sourcePath: prepared.path,
            timeout: const Duration(seconds: 30),
          ),
        );
        expect(
          reopened.extractedMap!.scenarioChkBytes,
          const RawChkEncoder().encode(current),
        );
        expect(
          await gateway.readResource(prepared.path, 'old.wav'),
          saved ? sound : replacement,
        );
        expect(await gateway.readResource(prepared.path, 'new.wav'), sound);
        final names = reopened.extractedMap!.metadata.entries
            .map((e) => e.path)
            .toSet();
        expect(names, isNot(contains('remove.wav')));
        if (saved) {
          expect(await gateway.readResource(prepared.path, 'keep.wav'), sound);
          expect(await original.readAsBytes(), sourceBytes);
          expect(
            await fingerprints.fingerprint(original.path),
            sourceFingerprint,
          );
        } else {
          expect(await original.exists(), isFalse);
        }
        expect(await preparer.revalidate(prepared), isTrue);
        await File(prepared.path).writeAsBytes([1], mode: FileMode.append);
        expect(await preparer.revalidate(prepared), isFalse);
        expect(await preparer.release(request), isTrue);
        expect(await File(prepared.path).exists(), isFalse);
        expect(await helperRoot.exists(), isTrue);
        if (saved) {
          expect(await original.readAsBytes(), sourceBytes);
          // The bundled writer intentionally rejects existing sound collisions.
          final collision = UnitCreepCaptureInput.prepare(
            syntheticCaptureStateRequest(
              document: current,
              baseline: baseline,
              sourcePath: original.path,
              archiveHash: sourceFingerprint!.sha256Digest,
              archiveSize: sourceFingerprint.sizeBytes,
              modified: sourceFingerprint.modifiedAtUtc,
              resources: {'old.wav': replacement},
            ),
            config,
          );
          final rejected = await preparer.prepare(collision);
          expect(rejected.errorCode, 'UNIT_CREEP_PREPARE_WRITE_FAILED');
          expect(rejected.prepared, isNull);
          expect(rejected.cleanupPending, isFalse);
          expect(
            rejected.diagnostics.map((d) => d.code),
            contains('ARCHIVE_RESOURCE_WRITE_FAILED'),
          );
          expect(await original.readAsBytes(), sourceBytes);
          expect(
            await fingerprints.fingerprint(original.path),
            sourceFingerprint,
          );
          expect(
            await root
                .list()
                .where((e) => e.path.contains('starcraft_creep_capture_'))
                .toList(),
            isEmpty,
          );
        }
      },
      skip: skipReason,
    );
  }
}
