import 'dart:async';

import '../ports/settings_store.dart';

/// The display language the user chose for menus, guidance and messages.
///
/// [system] follows the operating system language and falls back to English
/// when the system language is not one the editor ships.
enum AppLanguagePreference {
  system(storageValue: 'system', languageCode: null),
  korean(storageValue: 'ko', languageCode: 'ko'),
  english(storageValue: 'en', languageCode: 'en');

  const AppLanguagePreference({
    required this.storageValue,
    required this.languageCode,
  });

  /// The value written to the settings store.
  final String storageValue;

  /// The fixed language code, or `null` when the system language is used.
  final String? languageCode;

  static AppLanguagePreference fromStorageValue(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }
    return system;
  }
}

/// Loads, changes and persists the editor display language.
///
/// The controller never blocks the UI on the settings store: a chosen language
/// applies immediately and a failed write only sets [lastSaveFailed].
final class AppLanguageController {
  AppLanguageController({required this.store});

  static const settingsKey = 'uiLanguage';

  final SettingsStore store;
  final _changes = StreamController<AppLanguagePreference>.broadcast();
  AppLanguagePreference _preference = AppLanguagePreference.system;
  bool _changedBeforeLoad = false;
  bool _lastSaveFailed = false;
  bool _disposed = false;

  AppLanguagePreference get preference => _preference;

  /// Whether the most recent attempt to persist the preference failed.
  bool get lastSaveFailed => _lastSaveFailed;

  Stream<AppLanguagePreference> get changes => _changes.stream;

  /// Reads the stored preference. Unknown or unreadable values fall back to
  /// [AppLanguagePreference.system]. A choice made while loading wins.
  Future<void> load() async {
    String? stored;
    try {
      stored = await store.readString(settingsKey);
    } catch (_) {
      stored = null;
    }
    if (_disposed || _changedBeforeLoad) {
      return;
    }
    _emit(AppLanguagePreference.fromStorageValue(stored));
  }

  Future<void> setPreference(AppLanguagePreference preference) async {
    if (_disposed) {
      return;
    }
    _changedBeforeLoad = true;
    _emit(preference);
    try {
      if (preference == AppLanguagePreference.system) {
        await store.remove(settingsKey);
      } else {
        await store.writeString(settingsKey, preference.storageValue);
      }
      _lastSaveFailed = false;
    } catch (_) {
      _lastSaveFailed = true;
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_changes.close());
  }

  void _emit(AppLanguagePreference preference) {
    if (_disposed || preference == _preference) {
      return;
    }
    _preference = preference;
    _changes.add(preference);
  }
}
