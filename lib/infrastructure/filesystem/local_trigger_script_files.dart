import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../application/ports/trigger_script_gateway.dart';
import '../../domain/triggers/trigger_script.dart';
import 'local_map_save_file_gateway.dart';

final class LocalTriggerScriptFiles implements TriggerScriptFiles {
  const LocalTriggerScriptFiles({
    this.channel = const MethodChannel('starcraft_map_editor/file_dialog'),
  });
  final MethodChannel channel;
  static String _pathKey(String path) {
    final normalized = Uri.file(path, windows: Platform.isWindows)
        .normalizePath()
        .toFilePath(windows: Platform.isWindows)
        .replaceAll('\\', '/');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static TriggerScriptLanguage languageFor(String path) {
    for (final language in TriggerScriptLanguage.values) {
      if (path.toLowerCase().endsWith('.${language.extension}')) {
        return language;
      }
    }
    throw const FormatException('SCRIPT_FILE_EXTENSION');
  }

  static Future<String> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        _pathKey(await file.resolveSymbolicLinks()) !=
            _pathKey(file.absolute.path)) {
      throw const FileSystemException('SCRIPT_FILE_LINK');
    }
    final handle = await file.open();
    try {
      final count = await handle.length();
      if (count > TriggerScriptSyntax.maximumCharacters * 4) {
        throw const FormatException('SCRIPT_SIZE');
      }
      final bytes = await handle.read(count + 1);
      if (bytes.length != count || await handle.length() != count) {
        throw const FileSystemException('SCRIPT_FILE_CHANGED');
      }
      final text = utf8.decode(bytes);
      if (text.length > TriggerScriptSyntax.maximumCharacters) {
        throw const FormatException('SCRIPT_SIZE');
      }
      return text;
    } finally {
      await handle.close();
    }
  }

  @override
  Future<TriggerScriptFile?> open() async {
    final path = await channel.invokeMethod<String>('openTriggerScript');
    if (path == null) return null;
    if (!File(path).isAbsolute) throw const FormatException('SCRIPT_FILE_PATH');
    return TriggerScriptFile(path, await _read(File(path)), languageFor(path));
  }

  @override
  Future<String?> saveNew(String text, TriggerScriptLanguage language) async {
    if (text.length > TriggerScriptSyntax.maximumCharacters) {
      throw const FormatException('SCRIPT_SIZE');
    }
    final path = await channel.invokeMethod<String>('saveTriggerScript', {
      'suggestedName': 'triggers.${language.extension}',
    });
    if (path == null) return null;
    if (!File(path).isAbsolute || languageFor(path) != language) {
      throw const FormatException('SCRIPT_FILE_EXTENSION');
    }
    final files = LocalMapSaveFileGateway();
    if (await files.destinationExists(path)) {
      throw const FileSystemException('SCRIPT_CHOOSE_NEW_FILE');
    }
    final workspace = await files.createWorkspace(path);
    try {
      final output = File(workspace.temporaryOutputPath);
      await output.writeAsString(text, encoding: utf8, flush: true);
      if (await _read(output) != text) {
        throw const FormatException('SCRIPT_WRITE_VERIFY');
      }
      await files.promote(
        workspace: workspace,
        destinationPath: path,
        replaceExisting: false,
      );
      if (await _read(File(path)) != text) {
        throw const FormatException('SCRIPT_WRITE_VERIFY');
      }
      return path;
    } finally {
      await files.cleanup(workspace);
    }
  }
}
