import 'dart:convert';
import '../../domain/terrain/user_terrain_brush.dart';
import '../ports/terrain_brush_store.dart';

/// One application-wide instance serializes mutations across map windows.
final class TerrainBrushLibrary {
  TerrainBrushLibrary(this.store);
  final TerrainBrushStore store;
  static const maxBrushes = 64;
  static const maxTotalBytes = 4 * 1024 * 1024;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<UserTerrainBrush>> load() => _serial(_read);
  Future<List<UserTerrainBrush>> _read() async {
    final contents = await store.readAll();
    if (contents.length > maxBrushes ||
        contents.fold<int>(0, (n, v) => n + utf8.encode(v).length) >
            maxTotalBytes) {
      throw const FormatException('BRUSH_LIBRARY_LIMIT');
    }
    final result = contents.map(UserTerrainBrush.decode).toList();
    if (result.map((v) => v.name.toLowerCase()).toSet().length !=
        result.length) {
      throw const FormatException('BRUSH_DUPLICATE_NAME');
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(result);
  }

  Future<List<UserTerrainBrush>> add(UserTerrainBrush brush) => _serial(
    () async {
      final before = await _read(), content = brush.encode();
      UserTerrainBrush.decode(content);
      if (before.length >= maxBrushes ||
          before.fold<int>(
                utf8.encode(content).length,
                (n, v) => n + utf8.encode(v.encode()).length,
              ) >
              maxTotalBytes) {
        throw StateError('BRUSH_LIBRARY_LIMIT');
      }
      if (before.any((v) => v.name.toLowerCase() == brush.name.toLowerCase())) {
        throw StateError('BRUSH_DUPLICATE_NAME');
      }
      await store.add(brush.name, content);
      return _read();
    },
  );

  Future<List<UserTerrainBrush>> remove(UserTerrainBrush brush) =>
      _serial(() async {
        final before = await _read();
        if (!before.any((v) => v.encode() == brush.encode())) {
          throw StateError('BRUSH_LIBRARY_STALE');
        }
        await store.remove(brush.name);
        return _read();
      });
}
