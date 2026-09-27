import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_archive_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/archive/process_map_archive_gateway.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  final helper = Platform.environment['MAP_ARCHIVE_HELPER_PATH'];
  test(
    'real helper adds, verifies, rejects collision and removes self-authored PCM',
    () async {
      final source = File(
        Platform.environment['MAP_ARCHIVE_TEST_MAP'] ??
            'test/fixtures/maps/generated/minimal-self-authored.scx',
      ).absolute;
      final original = await source.readAsBytes();
      final workspace = await Directory.systemTemp.createTemp(
        'map_sound_roundtrip_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final gateway = ProcessMapArchiveGateway(helperExecutablePath: helper!);
      final opened = await gateway.open(
        MapArchiveOpenRequest(
          timeout: const Duration(seconds: 30),
          operationId: 'sound-open',
          sourcePath: source.path,
        ),
      );
      expect(opened.isSuccess, isTrue);
      final bytes = opened.extractedMap!.scenarioChkBytes;
      final output = '${workspace.path}/added.scx';
      const sound = r'staredit\wav\own.wav';
      final imported = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          timeout: const Duration(seconds: 30),
          operationId: 'sound-add',
          sourcePath: source.path,
          temporaryOutputPath: output,
          scenarioChkBytes: bytes,
          resourceEdits: {sound: pcmSoundFixture()},
        ),
      );
      expect(
        imported.isSuccess,
        isTrue,
        reason: imported.diagnostics
            .map((d) => '${d.code} ${d.rawDetails}')
            .join('\n'),
      );
      expect(await gateway.readResource(output, sound), pcmSoundFixture());
      final reopened = await gateway.open(
        MapArchiveOpenRequest(
          timeout: const Duration(seconds: 30),
          operationId: 'sound-reopen',
          sourcePath: output,
        ),
      );
      expect(reopened.extractedMap!.scenarioChkBytes, bytes);
      expect(
        reopened.extractedMap!.metadata.entries.any((e) => e.path == sound),
        isTrue,
      );
      final collision = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          timeout: const Duration(seconds: 30),
          operationId: 'sound-collision',
          sourcePath: output,
          temporaryOutputPath: '${workspace.path}/collision.scx',
          scenarioChkBytes: bytes,
          resourceEdits: {sound: pcmSoundFixture()},
        ),
      );
      expect(collision.isSuccess, isFalse);
      expect(await File('${workspace.path}/collision.scx').exists(), isFalse);
      final removed = await gateway.writeTemporary(
        MapArchiveWriteRequest(
          timeout: const Duration(seconds: 30),
          operationId: 'sound-remove',
          sourcePath: output,
          temporaryOutputPath: '${workspace.path}/removed.scx',
          scenarioChkBytes: bytes,
          resourceEdits: {sound: null},
        ),
      );
      expect(
        removed.isSuccess,
        isTrue,
        reason: removed.diagnostics
            .map((d) => '${d.code} ${d.rawDetails}')
            .join('\n'),
      );
      expect(
        await gateway.readResource('${workspace.path}/removed.scx', sound),
        isNull,
      );
      expect(await source.readAsBytes(), original);
      expect(await gateway.readResource(output, sound), pcmSoundFixture());
    },
    skip: helper == null
        ? 'Set MAP_ARCHIVE_HELPER_PATH to the built native helper.'
        : false,
  );
}
