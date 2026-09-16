import 'dart:async';

import '../ports/eud_tool_inspector.dart';
import '../ports/eud_tool_directory_picker.dart';
import '../ports/settings_store.dart';

final class EudToolSettingsState {
  const EudToolSettingsState({
    this.path,
    this.busy = false,
    this.result,
    this.error,
  });
  final String? path;
  final bool busy;
  final EudToolInspectionResult? result;
  final String? error;
}

final class EudToolSettingsController {
  EudToolSettingsController({
    required this.store,
    required this.inspector,
    this.bundledPath,
    this.directoryPicker,
  });
  static const settingsKey = 'euddraftInstallationPath';
  final SettingsStore store;
  final EudToolInspector inspector;
  final String? bundledPath;
  final EudToolDirectoryPicker? directoryPicker;
  final _changes = StreamController<EudToolSettingsState>.broadcast();
  EudToolSettingsState _state = const EudToolSettingsState();
  EudToolSettingsState get state => _state;
  Stream<EudToolSettingsState> get changes => _changes.stream;
  bool _loaded = false;
  bool _disposed = false;

  Future<String?> pickExternalDirectory() async {
    if (_disposed || state.busy || directoryPicker == null) return null;
    final previous = state;
    _set(
      EudToolSettingsState(
        path: previous.path,
        result: previous.result,
        busy: true,
      ),
    );
    try {
      final path = await directoryPicker!.pickEudToolDirectory();
      _set(previous);
      return _disposed ? null : path;
    } catch (error) {
      _set(
        EudToolSettingsState(
          path: previous.path,
          result: previous.result,
          error: 'The tool directory could not be selected: $error',
        ),
      );
      return null;
    }
  }

  EudToolInspectionRequest inspectionRequest({String? projectProfilePath}) =>
      EudToolInspectionRequest(
        projectProfilePath: projectProfilePath,
        userSettingsPath: state.path,
        bundledPath: bundledPath,
      );

  Future<void> load() async {
    if (_loaded || state.busy || _disposed) return;
    await _run(() async {
      final path = await store.readString(settingsKey);
      _set(EudToolSettingsState(path: _path(path), busy: true));
      _loaded = true;
      await _inspect();
    });
  }

  Future<void> selectExternal(String path) async {
    if (state.busy || _disposed) return;
    final selected = _path(path);
    if (selected == null) {
      _set(
        EudToolSettingsState(
          path: state.path,
          error: 'Enter an absolute euddraft installation path.',
        ),
      );
      return;
    }
    await _run(() async {
      await store.writeString(settingsKey, selected);
      _loaded = true;
      _set(EudToolSettingsState(path: selected, busy: true));
      await _inspect();
    });
  }

  Future<void> useDefault() async {
    if (state.busy || _disposed) return;
    await _run(() async {
      await store.remove(settingsKey);
      _loaded = true;
      _set(const EudToolSettingsState(busy: true));
      await _inspect();
    });
  }

  Future<void> refresh() async {
    if (state.busy || _disposed) return;
    if (!_loaded) return load();
    await _run(_inspect);
  }

  Future<void> _inspect() async {
    final result = await inspector.inspect(inspectionRequest());
    _set(EudToolSettingsState(path: state.path, result: result));
  }

  Future<void> _run(Future<void> Function() action) async {
    _set(EudToolSettingsState(path: state.path, busy: true));
    try {
      await action();
    } catch (error) {
      _set(
        EudToolSettingsState(
          path: state.path,
          error: 'Tool settings could not be updated: $error',
        ),
      );
    }
  }

  void _set(EudToolSettingsState state) {
    if (_disposed) return;
    _state = state;
    _changes.add(state);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
  }

  static String? _path(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
