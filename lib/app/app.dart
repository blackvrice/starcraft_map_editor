import 'package:flutter/material.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../application/ports/settings_store.dart';
import '../presentation/shell/editor_shell.dart';

class EditorAppDependencies {
  const EditorAppDependencies({
    required this.commandDispatcher,
    required this.settingsStore,
  });

  final EditorCommandDispatcher commandDispatcher;
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
      home: EditorShell(commandDispatcher: dependencies.commandDispatcher),
    );
  }
}
