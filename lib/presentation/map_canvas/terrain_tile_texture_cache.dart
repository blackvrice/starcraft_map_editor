import 'dart:collection';

import '../../application/terrain/terrain_tile_atlas_loader.dart';
import 'terrain_tile_texture.dart';

final class TerrainTileTextureKey {
  const TerrainTileTextureKey({required this.identity, required this.rawValue});

  final TerrainTileAtlasIdentity identity;
  final int rawValue;

  @override
  bool operator ==(Object other) {
    return other is TerrainTileTextureKey &&
        other.identity == identity &&
        other.rawValue == rawValue;
  }

  @override
  int get hashCode => Object.hash(identity, rawValue);
}

final class TerrainTileTextureCache {
  TerrainTileTextureCache({this.maximumBytes = defaultMaximumBytes}) {
    if (maximumBytes <= 0) {
      throw RangeError.value(maximumBytes, 'maximumBytes', 'Must be positive.');
    }
  }

  static const defaultMaximumBytes = 128 * 1024 * 1024;
  static const bytesPerPixel = 4;

  final int maximumBytes;
  final LinkedHashMap<TerrainTileTextureKey, TerrainTileTexture> _entries =
      LinkedHashMap();

  int _currentBytes = 0;
  bool _disposed = false;

  int get currentBytes => _currentBytes;

  int get length => _entries.length;

  bool containsKey(TerrainTileTextureKey key) => _entries.containsKey(key);

  TerrainTileTexture? get(TerrainTileTextureKey key) {
    _ensureUsable();
    final texture = _entries.remove(key);
    if (texture == null) {
      return null;
    }
    _entries[key] = texture;
    return texture;
  }

  TerrainTileTexture? peek(TerrainTileTextureKey key) {
    _ensureUsable();
    return _entries[key];
  }

  bool put(TerrainTileTextureKey key, TerrainTileTexture texture) {
    _ensureUsable();
    if (texture.width <= 0 || texture.height <= 0) {
      texture.dispose();
      throw ArgumentError('Texture dimensions must be positive.');
    }

    final existing = _entries.remove(key);
    if (identical(existing, texture)) {
      _entries[key] = texture;
      return true;
    }
    if (existing != null) {
      _currentBytes -= _byteCost(existing);
      existing.dispose();
    }

    final byteCost = _byteCost(texture);
    if (byteCost > maximumBytes) {
      texture.dispose();
      return false;
    }

    _entries[key] = texture;
    _currentBytes += byteCost;
    while (_currentBytes > maximumBytes) {
      final oldestKey = _entries.keys.first;
      final oldest = _entries.remove(oldestKey)!;
      _currentBytes -= _byteCost(oldest);
      oldest.dispose();
    }
    return _entries.containsKey(key);
  }

  void clear() {
    _ensureUsable();
    for (final texture in _entries.values) {
      texture.dispose();
    }
    _entries.clear();
    _currentBytes = 0;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    for (final texture in _entries.values) {
      texture.dispose();
    }
    _entries.clear();
    _currentBytes = 0;
    _disposed = true;
  }

  int _byteCost(TerrainTileTexture texture) {
    return texture.width * texture.height * bytesPerPixel;
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('The terrain tile texture cache is disposed.');
    }
  }
}
