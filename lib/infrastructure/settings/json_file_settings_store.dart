import 'dart:convert';
import 'dart:io';

import '../../application/ports/settings_store.dart';

class JsonFileSettingsStore implements SettingsStore {
  JsonFileSettingsStore(this.file);

  factory JsonFileSettingsStore.forCurrentUser() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (!Platform.isWindows || localAppData == null || localAppData.isEmpty) {
      throw UnsupportedError(
        'A Windows LOCALAPPDATA directory is required for persistent settings.',
      );
    }

    final separator = Platform.pathSeparator;
    return JsonFileSettingsStore(
      File(
        '$localAppData${separator}blackvrice$separator'
        'StarCraftMapEditor${separator}settings.json',
      ),
    );
  }

  final File file;

  @override
  Future<String?> readString(String key) async {
    final values = await _readValues();
    return values[key];
  }

  @override
  Future<void> remove(String key) async {
    final values = await _readValues();
    if (values.remove(key) != null) {
      await _writeValues(values);
    }
  }

  @override
  Future<void> writeString(String key, String value) async {
    final values = await _readValues();
    values[key] = value;
    await _writeValues(values);
  }

  Future<Map<String, String>> _readValues() async {
    if (!await file.exists()) {
      return {};
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return {};
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return {};
    }

    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    return {
      for (final entry in decoded.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }

  Future<void> _writeValues(Map<String, String> values) async {
    await file.parent.create(recursive: true);

    final temporaryFile = File('${file.path}.${pid.toString()}.tmp');
    await temporaryFile.writeAsString(jsonEncode(values), flush: true);

    if (await file.exists()) {
      await file.delete();
    }
    await temporaryFile.rename(file.path);
  }
}
