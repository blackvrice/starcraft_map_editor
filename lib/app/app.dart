import 'package:flutter/material.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/operations/operation_progress_controller.dart';
import '../application/ports/settings_store.dart';
import '../application/recent_projects/recent_projects_service.dart';
import '../presentation/shell/editor_shell.dart';

class EditorAppDependencies {
  const EditorAppDependencies({
    required this.commandDispatcher,
    required this.operationProgressController,
    required this.recentProjectsService,
    required this.settingsStore,
  });

  final EditorCommandDispatcher commandDispatcher;
  final OperationProgressController operationProgressController;
  final RecentProjectsService recentProjectsService;
  final SettingsStore settingsStore;
}

class StarCraftMapEditorApp extends StatelessWidget {
  const StarCraftMapEditorApp({required this.dependencies, super.key});

  final EditorAppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3D7EFF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'StarCraft Map Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11141A),
        useMaterial3: true,
      ),
      home: EditorShell(
        commandDispatcher: dependencies.commandDispatcher,
        operationProgressController: dependencies.operationProgressController,
        recentProjectsService: dependencies.recentProjectsService,
      ),
    );
  }
}
