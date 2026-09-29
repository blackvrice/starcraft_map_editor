import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/settings_store.dart';
import 'package:starcraft_map_editor/application/settings/app_language_controller.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test('follows the system language when nothing is stored', () async {
    final controller = AppLanguageController(store: InMemorySettingsStore());
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.preference, AppLanguagePreference.system);
    expect(controller.preference.languageCode, isNull);
  });

  test('restores a stored language and ignores unknown values', () async {
    final korean = AppLanguageController(
      store: InMemorySettingsStore({AppLanguageController.settingsKey: 'ko'}),
    );
    final unknown = AppLanguageController(
      store: InMemorySettingsStore({AppLanguageController.settingsKey: 'xx'}),
    );
    addTearDown(korean.dispose);
    addTearDown(unknown.dispose);

    await korean.load();
    await unknown.load();

    expect(korean.preference, AppLanguagePreference.korean);
    expect(korean.preference.languageCode, 'ko');
    expect(unknown.preference, AppLanguagePreference.system);
  });

  test('persists a fixed language and clears it for system', () async {
    final store = InMemorySettingsStore();
    final controller = AppLanguageController(store: store);
    addTearDown(controller.dispose);
    final changes = <AppLanguagePreference>[];
    controller.changes.listen(changes.add);

    await controller.setPreference(AppLanguagePreference.english);
    expect(await store.readString(AppLanguageController.settingsKey), 'en');

    await controller.setPreference(AppLanguagePreference.system);
    expect(await store.readString(AppLanguageController.settingsKey), isNull);
    await pumpEventQueue();
    expect(changes, [
      AppLanguagePreference.english,
      AppLanguagePreference.system,
    ]);
  });

  test('a choice made while loading is not overwritten by the load', () async {
    final store = _DelayedStore('en');
    final controller = AppLanguageController(store: store);
    addTearDown(controller.dispose);

    final loading = controller.load();
    await controller.setPreference(AppLanguagePreference.korean);
    store.release();
    await loading;

    expect(controller.preference, AppLanguagePreference.korean);
  });

  test('applies the language even when it cannot be saved', () async {
    final controller = AppLanguageController(store: _FailingStore());
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setPreference(AppLanguagePreference.korean);

    expect(controller.preference, AppLanguagePreference.korean);
    expect(controller.lastSaveFailed, isTrue);
  });
}

final class _DelayedStore implements SettingsStore {
  _DelayedStore(this.value);

  final String value;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<String?> readString(String key) async {
    await _gate.future;
    return value;
  }

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> writeString(String key, String value) async {}
}

final class _FailingStore implements SettingsStore {
  @override
  Future<String?> readString(String key) =>
      Future.error(StateError('unreadable'));

  @override
  Future<void> remove(String key) => Future.error(StateError('read-only'));

  @override
  Future<void> writeString(String key, String value) =>
      Future.error(StateError('read-only'));
}
