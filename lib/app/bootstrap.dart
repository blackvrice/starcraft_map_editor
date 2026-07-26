import 'package:flutter/widgets.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../infrastructure/settings/json_file_settings_store.dart';
import 'app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = JsonFileSettingsStore.forCurrentUser();
  final dependencies = EditorAppDependencies(
    commandDispatcher: EditorCommandDispatcher(),
    operationProgressController: OperationProgressController(),
    recentProjectsService: RecentProjectsService(settingsStore),
    settingsStore: settingsStore,
  );

  runApp(StarCraftMapEditorApp(dependencies: dependencies));
}
