import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/map_resource_gateway.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_map_resource_gateway.dart';
import '../fixtures/pcm_sound_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/sound_dialog');
  test(
    'native dialog cancel, validated import and exact-byte export',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'sound_gateway_test_',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final source = File('${workspace.path}/own.wav');
      await source.writeAsBytes(pcmSoundFixture());
      String? pick;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, anyOf('openSound', 'saveSound'));
        return pick;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final gateway = LocalMapResourceGateway(_Reader(), channel: channel);
      expect(await gateway.importSound(), isNull);
      pick = source.path;
      final imported = await gateway.importSound();
      expect(imported!.name, 'own.wav');
      expect(imported.bytes, pcmSoundFixture());
      pick = '${workspace.path}/export.wav';
      await gateway.exportSound(r'staredit\wav\own.wav', imported.bytes);
      expect(await File(pick).readAsBytes(), pcmSoundFixture());
      pick = '${workspace.path}/map.scx';
      await expectLater(
        gateway.exportSound('own.wav', imported.bytes),
        throwsFormatException,
      );
      expect(await File(pick).exists(), isFalse);
      await source.writeAsBytes([1, 2]);
      pick = source.path;
      await expectLater(gateway.importSound(), throwsFormatException);
      await gateway.stopPreview();
    },
  );
}

class _Reader implements MapArchiveResourceReader {
  @override
  Future<List<int>?> readResource(String archive, String path) async => null;
}
