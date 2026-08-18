import 'dart:collection';

import '../../application/objects/object_sprite_atlas_loader.dart';
import '../../application/ports/starcraft_object_atlas_gateway.dart';
import 'object_sprite_texture.dart';

final class ObjectSpriteTextureCacheKey {
  const ObjectSpriteTextureCacheKey({
    required this.identity,
    required this.objectKey,
  });

  final ObjectSpriteAtlasIdentity identity;
  final StarCraftObjectGraphicKey objectKey;

  @override
  bool operator ==(Object other) {
    return other is ObjectSpriteTextureCacheKey &&
        other.identity == identity &&
        other.objectKey == objectKey;
  }

  @override
  int get hashCode => Object.hash(identity, objectKey);
}

final class ObjectSpriteTextureCache {
  ObjectSpriteTextureCache({this.maximumBytes = defaultMaximumBytes}) {
    if (maximumBytes <= 0) {
      throw RangeError.value(maximumBytes, 'maximumBytes', 'Must be positive.');
    }
  }

  static const defaultMaximumBytes = 64 * 1024 * 1024;
  static const bytesPerPixel = 4;

  final int maximumBytes;
  final LinkedHashMap<ObjectSpriteTextureCacheKey, ObjectSpriteTexture>
  _entries = LinkedHashMap();

  int _currentBytes = 0;
  bool _disposed = false;

  int get currentBytes => _currentBytes;

  int get length => _entries.length;

  bool containsKey(ObjectSpriteTextureCacheKey key) {
    _ensureUsable();
    return _entries.containsKey(key);
  }

  ObjectSpriteTexture? get(ObjectSpriteTextureCacheKey key) {
    _ensureUsable();
    final texture = _entries.remove(key);
    if (texture == null) {
      return null;
    }
    _entries[key] = texture;
    return texture;
  }

  ObjectSpriteTexture? peek(ObjectSpriteTextureCacheKey key) {
    _ensureUsable();
    return _entries[key];
  }

  bool put(ObjectSpriteTextureCacheKey key, ObjectSpriteTexture texture) {
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

  int _byteCost(ObjectSpriteTexture texture) {
    return texture.width * texture.height * bytesPerPixel;
  }

  void _ensureUsable() {
    if (_disposed) {
      throw StateError('The object sprite texture cache is disposed.');
    }
  }
}
