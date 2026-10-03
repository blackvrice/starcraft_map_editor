import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import '../../application/documents/recovery_snapshot.dart';
import '../../application/ports/recovery_store.dart';

/// Append-only, verified checkpoints. A partial write never replaces a backup.
final class LocalRecoveryStore implements RecoveryStore {
  LocalRecoveryStore(this.directory);

  factory LocalRecoveryStore.forCurrentUser() {
    final root = Platform.environment['LOCALAPPDATA'];
    if (!Platform.isWindows || root == null || root.isEmpty) {
      throw UnsupportedError('Windows LOCALAPPDATA is required for recovery.');
    }
    return LocalRecoveryStore(
      Directory('$root/blackvrice/StarCraftMapEditor/recovery'),
    );
  }

  final Directory directory;
  static final _idPattern = RegExp(r'^checkpoint-[a-zA-Z0-9-]+$');

  File _file(String id) {
    if (!_idPattern.hasMatch(id) || id.length > 150) {
      throw const FormatException('Invalid recovery ID.');
    }
    return File('${directory.path}/$id.json');
  }

  Future<void> _checkDirectory({bool create = false}) async {
    var ancestor = directory.absolute;
    while (await FileSystemEntity.type(ancestor.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      if (ancestor.parent.path == ancestor.path) break;
      ancestor = ancestor.parent;
    }
    if (await FileSystemEntity.type(ancestor.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        (await ancestor.resolveSymbolicLinks())
                .replaceAll('\\', '/')
                .toLowerCase() !=
            ancestor.path.replaceAll('\\', '/').toLowerCase()) {
      throw const FileSystemException(
        'Recovery directory must not traverse links.',
      );
    }
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound && create) {
      await directory.create(recursive: true);
    } else if (type != FileSystemEntityType.directory &&
        type != FileSystemEntityType.notFound) {
      throw const FileSystemException(
        'Recovery directory is not a regular directory.',
      );
    }
    if (await directory.exists()) {
      final actual = await directory.resolveSymbolicLinks();
      if (actual.replaceAll('\\', '/').toLowerCase() !=
          directory.absolute.path.replaceAll('\\', '/').toLowerCase()) {
        throw const FileSystemException(
          'Recovery directory must not traverse links.',
        );
      }
    }
  }

  @override
  Future<List<RecoveryEntry>> list() async {
    await _checkDirectory();
    if (!await directory.exists()) return [];
    final entries = <RecoveryEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final name = entity.uri.pathSegments.last;
      final id = name.substring(0, name.length - 5);
      if (!_idPattern.hasMatch(id)) continue;
      try {
        entries.add(RecoveryEntry(id: id, content: await _read(entity)));
      } on Object {
        // Keep an unreadable checkpoint visible for explicit removal.
        entries.add(RecoveryEntry(id: id, content: ''));
      }
    }
    return entries;
  }

  Future<String> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > RecoverySnapshot.maxBytes + 1024) {
      throw const FormatException('Invalid recovery file or size.');
    }
    final path = file.path;
    return Isolate.run(() {
      final input = File(path).openSync();
      late final List<int> bytes;
      try {
        final size = input.lengthSync();
        if (size > RecoverySnapshot.maxBytes) {
          throw const FormatException('Recovery size limit.');
        }
        bytes = input.readSync(size);
        if (input.lengthSync() != size || bytes.length != size) {
          throw const FormatException('Recovery file changed.');
        }
      } finally {
        input.closeSync();
      }
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final content = envelope['content'] as String;
      if (envelope['sha256'] !=
          sha256.convert(utf8.encode(content)).toString()) {
        throw const FormatException('Recovery checksum mismatch.');
      }
      RecoverySnapshot.decode(content);
      return content;
    });
  }

  @override
  Future<void> write(String id, String content) async {
    await _checkDirectory(create: true);
    final target = _file(id);
    final temp = File('${target.path}.partial');
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
            FileSystemEntityType.notFound ||
        await FileSystemEntity.type(temp.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw const FileSystemException('Recovery checkpoint already exists.');
    }
    final path = temp.path;
    await Isolate.run(() {
      RecoverySnapshot.decode(content);
      final bytes = utf8.encode(
        jsonEncode({
          'sha256': sha256.convert(utf8.encode(content)).toString(),
          'content': content,
        }),
      );
      if (bytes.length > RecoverySnapshot.maxBytes) {
        throw const FormatException(
          'Recovery checkpoint exceeds its size limit.',
        );
      }
      File(path).writeAsBytesSync(bytes, flush: true);
    });
    if (await _read(temp) != content) {
      throw const FormatException('Recovery write verification failed.');
    }
    await temp.rename(target.path);
  }

  @override
  Future<void> remove(String id) async {
    await _checkDirectory();
    final file = _file(id);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.file) {
      throw const FileSystemException('Refusing to remove a recovery link.');
    }
    await file.delete();
  }
}
