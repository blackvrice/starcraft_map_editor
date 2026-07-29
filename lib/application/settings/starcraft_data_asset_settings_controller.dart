import 'dart:async';

import '../../domain/diagnostics/editor_diagnostic.dart';
import '../ports/directory_picker.dart';
import '../ports/settings_store.dart';
import '../ports/starcraft_data_asset_inspector.dart';

enum StarCraftDataAssetSettingsStatus {
  loading,
  unconfigured,
  inspecting,
  ready,
  unavailable,
}

final class StarCraftDataAssetSettingsState {
  StarCraftDataAssetSettingsState({
    required this.status,
    this.configuredPath,
    this.inspection,
    List<EditorDiagnostic> diagnostics = const [],
  }) : diagnostics = List.unmodifiable(diagnostics);

  const StarCraftDataAssetSettingsState.loading()
    : status = StarCraftDataAssetSettingsStatus.loading,
      configuredPath = null,
      inspection = null,
      diagnostics = const [];

  final StarCraftDataAssetSettingsStatus status;
  final String? configuredPath;
  final StarCraftDataAssetInspection? inspection;
  final List<EditorDiagnostic> diagnostics;

  bool get isBusy =>
      status == StarCraftDataAssetSettingsStatus.loading ||
      status == StarCraftDataAssetSettingsStatus.inspecting;

  bool get isReady => status == StarCraftDataAssetSettingsStatus.ready;
}

final class StarCraftDataAssetSettingsController {
  StarCraftDataAssetSettingsController({
    required this.settingsStore,
    required this.directoryPicker,
    required this.inspector,
  });

  static const settingsKey = 'starcraftDataAssetRoot';

  final SettingsStore settingsStore;
  final DirectoryPicker directoryPicker;
  final StarCraftDataAssetInspector inspector;
  final StreamController<StarCraftDataAssetSettingsState> _changes =
      StreamController.broadcast(sync: true);

  StarCraftDataAssetSettingsState _state =
      const StarCraftDataAssetSettingsState.loading();
  int _revision = 0;
  bool _disposed = false;

  StarCraftDataAssetSettingsState get state => _state;

  Stream<StarCraftDataAssetSettingsState> get changes => _changes.stream;

  Future<StarCraftDataAssetSettingsState> load() async {
    final revision = ++_revision;
    _emit(const StarCraftDataAssetSettingsState.loading());

    final String? configuredPath;
    try {
      configuredPath = await settingsStore.readString(settingsKey);
    } catch (error) {
      return _emitIfCurrent(
        revision,
        StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.unavailable,
          diagnostics: [
            _diagnostic(
              code: StarCraftDataAssetDiagnosticCodes.settingsReadFailed,
              message: 'StarCraft data asset settings could not be loaded.',
              remediation:
                  'Check access to the application settings folder and retry.',
              rawDetails: error.toString(),
            ),
          ],
        ),
      );
    }

    if (configuredPath == null || configuredPath.trim().isEmpty) {
      return _emitIfCurrent(revision, _unconfiguredState());
    }
    return _inspect(configuredPath, revision);
  }

  Future<StarCraftDataAssetSettingsState> chooseDirectory() async {
    final String? selectedPath;
    try {
      selectedPath = await directoryPicker.pickStarCraftDataDirectory();
    } catch (error) {
      final nextState = StarCraftDataAssetSettingsState(
        status: _state.status,
        configuredPath: _state.configuredPath,
        inspection: _state.inspection,
        diagnostics: [
          ..._state.diagnostics,
          _diagnostic(
            code: StarCraftDataAssetDiagnosticCodes.directoryPickerFailed,
            message: 'The StarCraft data folder picker could not be opened.',
            remediation: 'Retry or check Windows dialog permissions.',
            rawDetails: error.toString(),
          ),
        ],
      );
      _emit(nextState);
      return nextState;
    }

    if (selectedPath == null) {
      return _state;
    }
    return setDirectory(selectedPath);
  }

  Future<StarCraftDataAssetSettingsState> setDirectory(String path) async {
    final revision = ++_revision;
    _emit(
      StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.inspecting,
        configuredPath: path,
      ),
    );

    try {
      await settingsStore.writeString(settingsKey, path);
    } catch (error) {
      return _emitIfCurrent(
        revision,
        StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.unavailable,
          configuredPath: path,
          diagnostics: [
            _diagnostic(
              code: StarCraftDataAssetDiagnosticCodes.settingsWriteFailed,
              message: 'The StarCraft data asset path could not be saved.',
              filePath: path,
              remediation:
                  'Check access to the application settings folder and retry.',
              rawDetails: error.toString(),
            ),
          ],
        ),
      );
    }

    return _inspect(path, revision);
  }

  Future<StarCraftDataAssetSettingsState> refresh() {
    final configuredPath = _state.configuredPath;
    if (configuredPath == null || configuredPath.trim().isEmpty) {
      final state = _unconfiguredState();
      _emit(state);
      return Future.value(state);
    }

    final revision = ++_revision;
    _emit(
      StarCraftDataAssetSettingsState(
        status: StarCraftDataAssetSettingsStatus.inspecting,
        configuredPath: configuredPath,
      ),
    );
    return _inspect(configuredPath, revision);
  }

  Future<StarCraftDataAssetSettingsState> clear() async {
    final revision = ++_revision;
    final previousPath = _state.configuredPath;
    _emit(const StarCraftDataAssetSettingsState.loading());
    try {
      await settingsStore.remove(settingsKey);
    } catch (error) {
      return _emitIfCurrent(
        revision,
        StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.unavailable,
          configuredPath: previousPath,
          diagnostics: [
            _diagnostic(
              code: StarCraftDataAssetDiagnosticCodes.settingsWriteFailed,
              message: 'The StarCraft data asset path could not be cleared.',
              remediation:
                  'Check access to the application settings folder and retry.',
              rawDetails: error.toString(),
            ),
          ],
        ),
      );
    }
    return _emitIfCurrent(revision, _unconfiguredState());
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _changes.close();
  }

  Future<StarCraftDataAssetSettingsState> _inspect(
    String path,
    int revision,
  ) async {
    final StarCraftDataAssetInspection inspection;
    try {
      inspection = await inspector.inspect(path);
    } catch (error) {
      return _emitIfCurrent(
        revision,
        StarCraftDataAssetSettingsState(
          status: StarCraftDataAssetSettingsStatus.unavailable,
          configuredPath: path,
          diagnostics: [
            _diagnostic(
              code: StarCraftDataAssetDiagnosticCodes.inspectionFailed,
              message: 'StarCraft data assets could not be inspected.',
              filePath: path,
              remediation: 'Check directory access and retry.',
              rawDetails: error.toString(),
            ),
          ],
        ),
      );
    }

    return _emitIfCurrent(
      revision,
      StarCraftDataAssetSettingsState(
        status: inspection.isReady
            ? StarCraftDataAssetSettingsStatus.ready
            : StarCraftDataAssetSettingsStatus.unavailable,
        configuredPath: path,
        inspection: inspection,
        diagnostics: inspection.diagnostics,
      ),
    );
  }

  StarCraftDataAssetSettingsState _emitIfCurrent(
    int revision,
    StarCraftDataAssetSettingsState state,
  ) {
    if (revision != _revision || _disposed) {
      return _state;
    }
    _emit(state);
    return state;
  }

  void _emit(StarCraftDataAssetSettingsState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    _changes.add(state);
  }
}

StarCraftDataAssetSettingsState _unconfiguredState() {
  return StarCraftDataAssetSettingsState(
    status: StarCraftDataAssetSettingsStatus.unconfigured,
    diagnostics: [
      _diagnostic(
        code: StarCraftDataAssetDiagnosticCodes.rootNotConfigured,
        message: 'StarCraft tileset data assets are not configured.',
        remediation:
            'Open Settings and choose an asset root or tileset directory.',
      ),
    ],
  );
}

EditorDiagnostic _diagnostic({
  required String code,
  required String message,
  String? filePath,
  String? remediation,
  String? rawDetails,
}) {
  return EditorDiagnostic(
    code: code,
    message: message,
    severity: DiagnosticSeverity.warning,
    stage: DiagnosticStage.validate,
    filePath: filePath,
    remediation: remediation,
    rawDetails: rawDetails,
  );
}
