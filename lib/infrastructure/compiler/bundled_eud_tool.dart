import 'dart:io';

import '../../domain/eud/eud_tool_manifest.dart';
import 'bundled_eud_manifest.dart';
import 'local_eud_tool_inspector.dart';

/// Trust inventory is compiled into the app, never loaded from the tool folder.
abstract final class BundledEudTool {
  static const packageDirectory = '0.10.2.5-editor.1';
  static final manifest = EudToolManifest.decode(bundledEudManifestJson);

  static String pathForExecutable(String executable) => File(executable)
      .absolute
      .parent
      .uri
      .resolve('tools/euddraft/$packageDirectory/')
      .toFilePath();

  static String get installationPath =>
      pathForExecutable(Platform.resolvedExecutable);

  static LocalEudToolInspector inspector() =>
      LocalEudToolInspector(bundledManifest: manifest);
}
