import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/application/ports/directory_picker.dart';
import 'package:starcraft_map_editor/application/ports/starcraft_data_asset_inspector.dart';
import 'package:starcraft_map_editor/application/settings/starcraft_data_asset_settings_controller.dart';
import 'package:starcraft_map_editor/domain/diagnostics/editor_diagnostic.dart';
import 'package:starcraft_map_editor/infrastructure/settings/in_memory_settings_store.dart';

void main() {
  test('loads an unconfigured state with a nonblocking diagnostic', () async {
    final controller = StarCraftDataAssetSettingsController(
      settingsStore: InMemorySettingsStore(),
      directoryPicker: const _FakeDirectoryPicker(),
      inspector: _FakeInspector(_readyInspection),
    );
    addTearDown(controller.dispose);

    final state = await controller.load();

    expect(state.status, StarCraftDataAssetSettingsStatus.unconfigured);
    expect(state.configuredPath, isNull);
    expect(
      state.diagnostics.single.code,
      StarCraftDataAssetDiagnosticCodes.installationNotConfigured,
    );
    expect(state.diagnostics.single.blocksOperation, isFalse);
  });

  test('chooses, persists, inspects, refreshes, and clears a path', () async {
    const selectedPath = r'C:\Program Files (x86)\StarCraft';
    final settings = InMemorySettingsStore();
    final inspector = _FakeInspector(_readyInspection);
    final controller = StarCraftDataAssetSettingsController(
      settingsStore: settings,
      directoryPicker: const _FakeDirectoryPicker(selectedPath),
      inspector: inspector,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final selected = await controller.chooseDirectory();

    expect(selected.status, StarCraftDataAssetSettingsStatus.ready);
    expect(selected.configuredPath, selectedPath);
    expect(selected.inspection?.foundAssetCount, 40);
    expect(
      await settings.readString(
        StarCraftDataAssetSettingsController.settingsKey,
      ),
      selectedPath,
    );
    expect(inspector.paths, [selectedPath]);

    await controller.refresh();
    expect(inspector.paths, [selectedPath, selectedPath]);

    final cleared = await controller.clear();
    expect(cleared.status, StarCraftDataAssetSettingsStatus.unconfigured);
    expect(
      await settings.readString(
        StarCraftDataAssetSettingsController.settingsKey,
      ),
      isNull,
    );
  });

  test('loads and exposes diagnostics for an incomplete stored path', () async {
    const storedPath = r'C:\Games\IncompleteStarCraft';
    final settings = InMemorySettingsStore({
      StarCraftDataAssetSettingsController.settingsKey: storedPath,
    });
    final controller = StarCraftDataAssetSettingsController(
      settingsStore: settings,
      directoryPicker: const _FakeDirectoryPicker(),
      inspector: _FakeInspector(_incompleteInspection),
    );
    addTearDown(controller.dispose);

    final state = await controller.load();

    expect(state.status, StarCraftDataAssetSettingsStatus.unavailable);
    expect(state.configuredPath, storedPath);
    expect(state.inspection?.missingRelativePaths, [r'tileset\badlands.cv5']);
    expect(
      state.diagnostics.single.code,
      StarCraftDataAssetDiagnosticCodes.filesMissing,
    );
  });

  test('keeps state unchanged when directory selection is cancelled', () async {
    final controller = StarCraftDataAssetSettingsController(
      settingsStore: InMemorySettingsStore(),
      directoryPicker: const _FakeDirectoryPicker(),
      inspector: _FakeInspector(_readyInspection),
    );
    addTearDown(controller.dispose);
    final before = await controller.load();

    final after = await controller.chooseDirectory();

    expect(identical(after, before), isTrue);
  });
}

final class _FakeDirectoryPicker implements DirectoryPicker {
  const _FakeDirectoryPicker([this.path]);

  final String? path;

  @override
  Future<String?> pickStarCraftInstallationDirectory() async => path;
}

typedef _InspectionFactory =
    StarCraftDataAssetInspection Function(String installationPath);

final class _FakeInspector implements StarCraftDataAssetInspector {
  _FakeInspector(this.factory);

  final _InspectionFactory factory;
  final List<String> paths = [];

  @override
  Future<StarCraftDataAssetInspection> inspect(String installationPath) async {
    paths.add(installationPath);
    return factory(installationPath);
  }
}

StarCraftDataAssetInspection _readyInspection(String installationPath) {
  return StarCraftDataAssetInspection(
    installationPath: installationPath,
    requiredAssetCount: 40,
    foundAssetCount: 40,
    storageProduct: 's1',
    storageBuildNumber: 13515,
    helperVersion: '0.1.0',
    cascLibRevision: '4971d363e665551ac4142f541e5f2d71f1cda653',
    totalAssetBytes: 1024,
  );
}

StarCraftDataAssetInspection _incompleteInspection(String installationPath) {
  return StarCraftDataAssetInspection(
    installationPath: installationPath,
    requiredAssetCount: 40,
    foundAssetCount: 39,
    missingRelativePaths: const [r'tileset\badlands.cv5'],
    diagnostics: const [
      EditorDiagnostic(
        code: StarCraftDataAssetDiagnosticCodes.filesMissing,
        message: 'One required file is missing.',
        severity: DiagnosticSeverity.warning,
        stage: DiagnosticStage.validate,
      ),
    ],
  );
}
