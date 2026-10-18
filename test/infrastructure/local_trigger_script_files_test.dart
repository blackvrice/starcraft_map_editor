import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/triggers/trigger_script.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/local_trigger_script_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  String? pick;
  final calls = <MethodCall>[];
  const channel = MethodChannel('test/trigger-script-files');
  const files = LocalTriggerScriptFiles(channel: channel);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trigger-script-files-');
    calls.clear();
    pick = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return pick;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });
  test(
    'new files preserve Unicode and line endings; originals are never overwritten',
    () async {
      const text = '# 원문 😀\r\nMapScript(1, "draft");\r\n';
      for (final language in TriggerScriptLanguage.values) {
        pick = '${directory.path}/source.${language.extension}';
        expect(await files.saveNew(text, language), pick);
        expect(await File(pick!).readAsString(), text);
        final read = await files.open();
        expect(read!.text, text);
        expect(read.language, language);
        await expectLater(
          files.saveNew('new', language),
          throwsA(isA<FileSystemException>()),
        );
        expect(await File(pick!).readAsString(), text);
      }
      expect(calls.map((c) => c.method), contains('saveTriggerScript'));
    },
  );
  test(
    'cancel, wrong extension, mismatched language and oversized input are rejected safely',
    () async {
      expect(await files.open(), isNull);
      expect(await files.saveNew('text', TriggerScriptLanguage.lua), isNull);
      pick = '${directory.path}/map.scx';
      await expectLater(
        files.saveNew('text', TriggerScriptLanguage.lua),
        throwsFormatException,
      );
      pick = '${directory.path}/source.py';
      await expectLater(
        files.saveNew('text', TriggerScriptLanguage.epScript),
        throwsFormatException,
      );
      await expectLater(
        files.saveNew(
          ' ' * (TriggerScriptSyntax.maximumCharacters + 1),
          TriggerScriptLanguage.python,
        ),
        throwsFormatException,
      );
      await File(pick!).writeAsBytes([0xff]);
      await expectLater(files.open(), throwsFormatException);
      expect(await File(pick!).readAsBytes(), [255]);
    },
  );
  test('file links are not accepted as script input', () async {
    final source = File('${directory.path}/source.py');
    await source.writeAsString('source');
    final link = Link('${directory.path}/link.py');
    try {
      await link.create(source.path);
    } on FileSystemException {
      markTestSkipped('This Windows account cannot create symbolic links.');
      return;
    }
    pick = link.path;
    await expectLater(files.open(), throwsA(isA<FileSystemException>()));
    expect(await source.readAsString(), 'source');
  });
}
