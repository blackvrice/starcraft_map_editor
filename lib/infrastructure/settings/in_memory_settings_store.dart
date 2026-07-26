import '../../application/ports/settings_store.dart';

class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([Map<String, String>? initialValues])
    : _values = {...?initialValues};

  final Map<String, String> _values;

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}
