import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/method_channel_directory_picker.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/method_channel_map_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/map_file_picker');
  final picker = MethodChannelMapFilePicker(channel: channel);
  final directoryPicker = MethodChannelDirectoryPicker(channel: channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the path selected by the native dialog', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return r'C:\Maps\Arena.scx';
        });

    final path = await picker.pickMapPath();

    expect(receivedCall!.method, MethodChannelMapFilePicker.openMapMethod);
    expect(receivedCall!.arguments, isNull);
    expect(path, r'C:\Maps\Arena.scx');
  });

  test('returns null when the native dialog is cancelled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await picker.pickMapPath(), isNull);
  });

  test('passes a suggested name to the native save dialog', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return r'C:\Maps\Arena Copy.scx';
        });

    final path = await picker.pickSaveMapPath(suggestedName: 'Arena Copy.scx');

    expect(receivedCall!.method, MethodChannelMapFilePicker.saveMapMethod);
    expect(receivedCall!.arguments, {'suggestedName': 'Arena Copy.scx'});
    expect(path, r'C:\Maps\Arena Copy.scx');
  });

  test(
    'returns the StarCraft data directory selected by native dialog',
    () async {
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return r'C:\StarCraftAssets';
          });

      final path = await directoryPicker.pickStarCraftDataDirectory();

      expect(
        receivedCall!.method,
        MethodChannelDirectoryPicker.pickStarCraftDataDirectoryMethod,
      );
      expect(receivedCall!.arguments, isNull);
      expect(path, r'C:\StarCraftAssets');
    },
  );
}
