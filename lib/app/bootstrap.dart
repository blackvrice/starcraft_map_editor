import 'package:flutter/widgets.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/documents/open_map_controller.dart';
import '../application/documents/save_map_controller.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../infrastructure/archive/process_map_archive_gateway.dart';
import '../infrastructure/filesystem/local_map_save_file_gateway.dart';
import '../infrastructure/filesystem/method_channel_map_file_picker.dart';
import '../infrastructure/settings/json_file_settings_store.dart';
import 'app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsStore = JsonFileSettingsStore.forCurrentUser();
  final commandDispatcher = EditorCommandDispatcher();
  final operationProgressController = OperationProgressController();
  final recentProjectsService = RecentProjectsService(settingsStore);
  final archiveGateway = ProcessMapArchiveGateway.bundled();
  const filePicker = MethodChannelMapFilePicker();
  final openMapController = OpenMapController(
    archiveGateway: archiveGateway,
    filePicker: filePicker,
    recentProjectsService: recentProjectsService,
    operationProgressController: operationProgressController,
  );
  final saveMapController = SaveMapController(
    archiveGateway: archiveGateway,
    filePicker: filePicker,
    saveFileGateway: LocalMapSaveFileGateway(),
    openMapController: openMapController,
    operationProgressController: operationProgressController,
  );
  commandDispatcher.register(EditorCommandId.openMap, (argument) async {
    await openMapController.open(
      sourcePath: argument is String ? argument : null,
    );
  });
  commandDispatcher.register(EditorCommandId.saveAs, (_) async {
    await saveMapController.saveAs();
  });

  final dependencies = EditorAppDependencies(
    commandDispatcher: commandDispatcher,
    openMapController: openMapController,
    saveMapController: saveMapController,
    operationProgressController: operationProgressController,
    recentProjectsService: recentProjectsService,
    settingsStore: settingsStore,
  );

  runApp(StarCraftMapEditorApp(dependencies: dependencies));
}
