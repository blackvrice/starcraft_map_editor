import 'package:flutter/widgets.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../infrastructure/archive/process_map_archive_gateway.dart';
import '../infrastructure/filesystem/method_channel_map_file_picker.dart';
import '../infrastructure/settings/json_file_settings_store.dart';
import 'app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = JsonFileSettingsStore.forCurrentUser();
  final commandDispatcher = EditorCommandDispatcher();
  final operationProgressController = OperationProgressController();
  final recentProjectsService = RecentProjectsService(settingsStore);
  final openMapController = OpenMapController(
    archiveGateway: ProcessMapArchiveGateway.bundled(),
    filePicker: const MethodChannelMapFilePicker(),
    recentProjectsService: recentProjectsService,
    operationProgressController: operationProgressController,
  );
  commandDispatcher.register(EditorCommandId.openMap, (argument) async {
    await openMapController.open(
      sourcePath: argument is String ? argument : null,
    );
  });

  final dependencies = EditorAppDependencies(
    commandDispatcher: commandDispatcher,
    openMapController: openMapController,
    operationProgressController: operationProgressController,
    recentProjectsService: recentProjectsService,
    settingsStore: settingsStore,
  );

  runApp(StarCraftMapEditorApp(dependencies: dependencies));
}
