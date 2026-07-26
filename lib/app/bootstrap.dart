import 'package:flutter/widgets.dart';

import '../application/commands/editor_command_dispatcher.dart';
import '../infrastructure/settings/in_memory_settings_store.dart';
import 'app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = EditorAppDependencies(
    commandDispatcher: EditorCommandDispatcher(),
    settingsStore: InMemorySettingsStore(),
  );

  runApp(StarCraftMapEditorApp(dependencies: dependencies));
}
