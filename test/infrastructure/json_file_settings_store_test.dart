import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/infrastructure/settings/json_file_settings_store.dart';

void main() {
  test('persists values across store instances', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'starcraft_map_editor_settings_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final settingsFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}settings.json',
    );

    final firstStore = JsonFileSettingsStore(settingsFile);
    await firstStore.writeString('starcraftPath', r'C:\Games\StarCraft');

    final secondStore = JsonFileSettingsStore(settingsFile);
    expect(
      await secondStore.readString('starcraftPath'),
      r'C:\Games\StarCraft',
    );

    await secondStore.remove('starcraftPath');
    expect(await firstStore.readString('starcraftPath'), isNull);
  });
}
