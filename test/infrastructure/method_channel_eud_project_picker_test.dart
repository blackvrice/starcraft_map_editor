import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/filesystem/method_channel_eud_project_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = MethodChannelEudProjectPicker();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      MethodChannelEudProjectPicker.channel,
      null,
    ),
  );
  test(
    'project dialogs use dedicated methods and cancellation returns null',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        MethodChannelEudProjectPicker.channel,
        (call) async {
          calls.add(call);
          return call.method == 'openEudProject'
              ? r'C:\maps\settings.eud.json'
              : null;
        },
      );
      expect(await picker.openProject(), r'C:\maps\settings.eud.json');
      expect(await picker.saveProjectAs(), isNull);
      expect(calls.map((call) => call.method), [
        'openEudProject',
        'saveEudProject',
      ]);
      expect(calls.last.arguments, {'suggestedName': 'settings.eud.json'});
    },
  );
}
