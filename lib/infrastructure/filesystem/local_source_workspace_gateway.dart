import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../../application/ports/source_workspace_gateway.dart';
import '../../domain/eud/source_workspace_index.dart';
import 'local_map_save_file_gateway.dart';

final class LocalSourceWorkspaceGateway implements SourceWorkspaceGateway {
  const LocalSourceWorkspaceGateway({
    this.channel = const MethodChannel('starcraft_map_editor/file_dialog'),
  });
  final MethodChannel channel;
  @override
  Future<String?> chooseRoot() =>
      channel.invokeMethod<String>('pickSourceRoot');
  static const _ignored = {
    '.git',
    '.dart_tool',
    '__pycache__',
    '__epspy__',
    '.venv',
    'node_modules',
    'build',
  };
  static String _key(String path) => Platform.isWindows
      ? SourcePaths.key(path)
      : path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  Future<Directory> _directory(String root) async {
    final dir = Directory(root);
    if (!dir.isAbsolute ||
        await FileSystemEntity.type(root, followLinks: false) !=
            FileSystemEntityType.directory ||
        _key(await dir.resolveSymbolicLinks()) != _key(dir.absolute.path)) {
      throw const FileSystemException('SOURCE_ROOT_OR_LINK');
    }
    return dir.absolute;
  }

  Future<File> _file(String root, String relative) async {
    SourcePaths.relative(relative);
    final dir = await _directory(root);
    final file = File.fromUri(dir.uri.resolve(relative));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        _key(await file.resolveSymbolicLinks()) != _key(file.absolute.path)) {
      throw const FileSystemException('SOURCE_FILE_OR_LINK');
    }
    return file;
  }

  @override
  Future<SourceWorkspaceFile> read(String root, String relativePath) async {
    final file = await _file(root, relativePath);
    final before = await file.stat(), input = await file.open();
    late final List<int> bytes;
    try {
      final length = await input.length();
      if (length > 4 * 1024 * 1024) throw const FormatException('SOURCE_SIZE');
      bytes = await input.read(length + 1);
      if (bytes.length != length || await input.length() != length) {
        throw const FileSystemException('SOURCE_FILE_CHANGED');
      }
    } finally {
      await input.close();
    }
    final after = await file.stat();
    await _file(root, relativePath);
    if (before.size != after.size || before.modified != after.modified) {
      throw const FileSystemException('SOURCE_FILE_CHANGED');
    }
    final text = utf8.decode(bytes);
    if (text.length > 1024 * 1024) throw const FormatException('SOURCE_SIZE');
    return SourceWorkspaceFile(
      relativePath: relativePath,
      path: file.path,
      text: text,
      revision: sha256.convert(bytes).toString(),
    );
  }

  @override
  Future<SourceWorkspaceScan> scan(String root) async {
    final dir = await _directory(root), files = <SourceWorkspaceFile>[];
    var visited = 0, total = 0;
    Future<void> visit(Directory folder, int depth) async {
      if (depth > 12) throw const FormatException('SOURCE_DEPTH_LIMIT');
      if (_key(await folder.resolveSymbolicLinks()) !=
          _key(folder.absolute.path)) {
        throw const FileSystemException('SOURCE_LINK');
      }
      final entries = <FileSystemEntity>[];
      await for (final entry in folder.list(followLinks: false)) {
        if (++visited > 4096) throw const FormatException('SOURCE_ENTRY_LIMIT');
        entries.add(entry);
      }
      entries.sort((a, b) => a.path.compareTo(b.path));
      for (final entry in entries) {
        final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (_ignored.contains(name)) continue;
        final type = await FileSystemEntity.type(
          entry.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw const FileSystemException('SOURCE_LINK');
        }
        if (type == FileSystemEntityType.directory) {
          await visit(Directory(entry.path), depth + 1);
        } else if (type == FileSystemEntityType.file &&
            const [
              '.eps',
              '.py',
              '.lua',
            ].any(entry.path.toLowerCase().endsWith)) {
          if (files.length >= 256) {
            throw const FormatException('SOURCE_FILE_LIMIT');
          }
          final relative = entry.absolute.path
              .substring(dir.path.length)
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'^/'), '');
          final value = await read(dir.path, relative);
          total += utf8.encode(value.text).length;
          if (total > 8 * 1024 * 1024) {
            throw const FormatException('SOURCE_TOTAL_LIMIT');
          }
          if (files.any(
            (f) => SourcePaths.key(f.relativePath) == SourcePaths.key(relative),
          )) {
            throw const FormatException('SOURCE_AMBIGUOUS_CASE');
          }
          files.add(value);
        }
      }
    }

    await visit(dir, 0);
    await _directory(root);
    return SourceWorkspaceScan(dir.path, files);
  }

  @override
  Future<SourceWorkspaceFile> save(
    String root,
    String relativePath,
    String text,
    String expectedRevision,
  ) async {
    if (text.length > 1024 * 1024) throw const FormatException('SOURCE_SIZE');
    final original = await read(root, relativePath);
    if (original.revision != expectedRevision) {
      throw const FileSystemException('SOURCE_EXTERNAL_CHANGE');
    }
    final files = LocalMapSaveFileGateway(
      backupValidator: (backup) async {
        if (sha256.convert(await backup.readAsBytes()).toString() !=
            expectedRevision) {
          throw const FileSystemException('SOURCE_EXTERNAL_CHANGE');
        }
      },
    );
    final workspace = await files.createWorkspace(original.path);
    try {
      await File(
        workspace.temporaryOutputPath,
      ).writeAsString(text, encoding: utf8, flush: true);
      if (await File(
            workspace.temporaryOutputPath,
          ).readAsString(encoding: utf8) !=
          text) {
        throw const FormatException('SOURCE_WRITE_VERIFY');
      }
      final current = await read(root, relativePath);
      if (current.revision != expectedRevision) {
        throw const FileSystemException('SOURCE_EXTERNAL_CHANGE');
      }
      final promoted = await files.promote(
        workspace: workspace,
        destinationPath: original.path,
        replaceExisting: true,
      );
      final saved = await read(root, relativePath);
      if (saved.text != text) {
        throw const FormatException('SOURCE_WRITE_VERIFY');
      }
      return SourceWorkspaceFile(
        relativePath: saved.relativePath,
        path: saved.path,
        text: saved.text,
        revision: saved.revision,
        backupPath: promoted.backupPath,
      );
    } finally {
      await files.cleanup(workspace);
    }
  }
}
