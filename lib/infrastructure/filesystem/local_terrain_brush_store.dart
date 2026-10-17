import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../application/ports/terrain_brush_store.dart';
import '../../application/terrain/terrain_brush_library.dart';
import '../../domain/terrain/user_terrain_brush.dart';

/// Immutable files: a failed add cannot replace an existing brush.
final class LocalTerrainBrushStore implements TerrainBrushStore {
  LocalTerrainBrushStore(this.directory);
  factory LocalTerrainBrushStore.forCurrentUser() {
    final root = Platform.environment['LOCALAPPDATA'];
    if (!Platform.isWindows || root == null || root.isEmpty) {
      throw UnsupportedError('Windows LOCALAPPDATA is required for brushes.');
    }
    return LocalTerrainBrushStore(
      Directory('$root/blackvrice/StarCraftMapEditor/brushes'),
    );
  }
  final Directory directory;
  static String _pathKey(String path) =>
      path.replaceAll('\\', '/').toLowerCase();
  File _file(String name) => File(
    '${directory.path}/'
    '${sha256.convert(utf8.encode(UserTerrainBrush.checkedName(name).toLowerCase()))}.json',
  );

  Future<void> _check({bool create = false}) async {
    var ancestor = directory.absolute;
    while (await FileSystemEntity.type(ancestor.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      if (ancestor.path == ancestor.parent.path) break;
      ancestor = ancestor.parent;
    }
    if (await FileSystemEntity.type(ancestor.path, followLinks: false) !=
            FileSystemEntityType.directory ||
        _pathKey(await ancestor.resolveSymbolicLinks()) !=
            _pathKey(ancestor.path)) {
      throw const FileSystemException('BRUSH_STORE_LINK');
    }
    if (create) await directory.create(recursive: true);
    if (await directory.exists() &&
        _pathKey(await directory.resolveSymbolicLinks()) !=
            _pathKey(directory.absolute.path)) {
      throw const FileSystemException('BRUSH_STORE_LINK');
    }
  }

  Future<String> _read(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FileSystemException('BRUSH_STORE_LINK');
    }
    final input = await file.open();
    try {
      final size = await input.length();
      if (size > UserTerrainBrush.maxBytes) {
        throw const FormatException('BRUSH_SIZE');
      }
      final bytes = await input.read(size);
      if (bytes.length != size || await input.length() != size) {
        throw const FormatException('BRUSH_STORE_CHANGED');
      }
      return utf8.decode(bytes);
    } finally {
      await input.close();
    }
  }

  @override
  Future<List<String>> readAll() async {
    await _check();
    if (!await directory.exists()) return [];
    final result = <String>[];
    var total = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (!entity.path.endsWith('.json')) continue;
      final file = File(entity.path), content = await _read(file);
      final brush = UserTerrainBrush.decode(content);
      if (_pathKey(_file(brush.name).absolute.path) !=
          _pathKey(file.absolute.path)) {
        throw const FormatException('BRUSH_STORE_NAME');
      }
      total += utf8.encode(content).length;
      result.add(content);
      if (result.length > TerrainBrushLibrary.maxBrushes ||
          total > TerrainBrushLibrary.maxTotalBytes) {
        throw const FormatException('BRUSH_LIBRARY_LIMIT');
      }
    }
    return result;
  }

  Future<void> _locked(Future<void> Function() action) async {
    await _check(create: true);
    final file = File('${directory.path}/.lock');
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.notFound) {
      throw const FileSystemException('BRUSH_STORE_LINK');
    }
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.blockingExclusive);
      try {
        await action();
      } finally {
        await handle.unlock();
      }
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> add(String name, String content) => _locked(() async {
    final brush = UserTerrainBrush.decode(content);
    if (brush.name != name) throw const FormatException('BRUSH_STORE_NAME');
    final prior = await readAll();
    if (prior.length >= TerrainBrushLibrary.maxBrushes ||
        prior.fold<int>(
              utf8.encode(content).length,
              (n, s) => n + utf8.encode(s).length,
            ) >
            TerrainBrushLibrary.maxTotalBytes) {
      throw const FormatException('BRUSH_LIBRARY_LIMIT');
    }
    final target = _file(name);
    if (await FileSystemEntity.type(target.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('BRUSH_DUPLICATE_NAME');
    }
    final temp = await directory.createTemp('.brush-');
    try {
      final file = File('${temp.path}/brush.partial');
      await file.writeAsString(content, flush: true);
      if (await _read(file) != content) {
        throw const FormatException('BRUSH_WRITE_VERIFY');
      }
      await file.rename(target.path);
    } finally {
      await temp.delete(recursive: true);
    }
  });

  @override
  Future<void> remove(String name) => _locked(() async {
    final target = _file(name);
    final brush = UserTerrainBrush.decode(await _read(target));
    if (brush.name.toLowerCase() != name.toLowerCase()) {
      throw const FormatException('BRUSH_STORE_NAME');
    }
    await target.delete();
  });
}
