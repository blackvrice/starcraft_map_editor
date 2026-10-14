import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/terrain_placement_snapshot.dart';
import 'package:starcraft_map_editor/domain/placement/unit_collision_profile.dart';

void main() {
  test(
    'vertical and diagonal tile crossings include the closed bottom/right corner',
    () {
      final snapshot = _snapshot(masks: [65535, 65534]);
      for (final width in [1, 2]) {
        final terrain = _terrain(
          width == 1 ? [0, 16] : [0, 0, 0, 16],
          width: width,
        );
        final profile = UnitCollisionProfile(
          left: 0,
          up: 0,
          right: width == 1 ? 0 : 1,
          down: 1,
          isFlyer: false,
        );
        expect(
          snapshot.check(
            terrain: terrain,
            mapTileset: 0,
            bounds: profile.boundsAt(width == 1 ? 0 : 30, 30),
            requireBuildable: false,
          ),
          TerrainFootprintCheck.clear,
        );
        expect(
          snapshot.check(
            terrain: terrain,
            mapTileset: 0,
            bounds: profile.boundsAt(width == 1 ? 0 : 31, 31),
            requireBuildable: false,
          ),
          TerrainFootprintCheck.unwalkable,
        );
      }
    },
  );
  test(
    'oversized synchronous footprint fails closed before a full terrain scan',
    () {
      final terrain = _terrain(List.filled(65 * 65, 0), width: 65);
      final profile = UnitCollisionProfile(
        left: 0,
        up: 0,
        right: 2048,
        down: 2048,
        isFlyer: false,
      );
      expect(
        _snapshot().check(
          terrain: terrain,
          mapTileset: 0,
          bounds: profile.boundsAt(0, 0),
          requireBuildable: false,
        ),
        TerrainFootprintCheck.unavailable,
      );
      final supported = UnitCollisionProfile(
        left: 0,
        up: 0,
        right: 2047,
        down: 2047,
        isFlyer: false,
      );
      expect(
        _snapshot().check(
          terrain: terrain,
          mapTileset: 0,
          bounds: supported.boundsAt(0, 0),
          requireBuildable: false,
        ),
        TerrainFootprintCheck.clear,
      );
    },
  );
  for (var mini = 0; mini < 16; mini++) {
    test(
      'VF4 mini $mini uses row-major 8px coordinates only within footprint',
      () {
        final snapshot = _snapshot(masks: [65535 ^ (1 << mini), 65535]);
        final x = mini % 4 * 8, y = mini ~/ 4 * 8;
        expect(
          _check(snapshot, _terrain([0]), x, y),
          TerrainFootprintCheck.unwalkable,
        );
        expect(
          _check(snapshot, _terrain([0]), x + 7, y + 7),
          TerrainFootprintCheck.unwalkable,
        );
        final other = (mini + 1) % 16;
        expect(
          _check(snapshot, _terrain([0]), other % 4 * 8, other ~/ 4 * 8),
          TerrainFootprintCheck.clear,
        );
      },
    );
  }
  for (final buildable in [false, true]) {
    test('buildability is independent of walking require=$buildable', () {
      final snapshot = _snapshot(buildable: [false, true]);
      expect(
        _check(snapshot, _terrain([0]), 0, 0, buildable: buildable),
        buildable
            ? TerrainFootprintCheck.unbuildable
            : TerrainFootprintCheck.clear,
      );
    });
  }
  test('cross-tile closed footprint visits only overlapping mini-tiles', () {
    final terrain = _terrain([0, 16], width: 2);
    final snapshot = _snapshot(masks: [65535, 65534]);
    final profile = UnitCollisionProfile(
      left: 0,
      up: 0,
      right: 1,
      down: 0,
      isFlyer: false,
    );
    expect(
      snapshot.check(
        terrain: terrain,
        mapTileset: 0,
        bounds: profile.boundsAt(30, 0),
        requireBuildable: false,
      ),
      TerrainFootprintCheck.clear,
    );
    expect(
      snapshot.check(
        terrain: terrain,
        mapTileset: 0,
        bounds: profile.boundsAt(31, 0),
        requireBuildable: false,
      ),
      TerrainFootprintCheck.unwalkable,
    );
    expect(_check(snapshot, terrain, 32, 8), TerrainFootprintCheck.clear);
  });
  for (final point in [(-1, 0), (0, -1), (32, 0), (0, 32)]) {
    test('entire closed footprint rejects outside pixel $point', () {
      expect(
        _check(_snapshot(), _terrain([0]), point.$1, point.$2),
        TerrainFootprintCheck.outOfBounds,
      );
    });
  }
  test(
    'last legal pixel is 31,31; no rounding, edge clamping or tile-box inference',
    () {
      expect(
        _check(_snapshot(), _terrain([0]), 31, 31),
        TerrainFootprintCheck.clear,
      );
      final profile = UnitCollisionProfile(
        left: 1,
        up: 0,
        right: 0,
        down: 0,
        isFlyer: false,
      );
      expect(
        _snapshot().check(
          terrain: _terrain([0]),
          mapTileset: 0,
          bounds: profile.boundsAt(0, 0),
          requireBuildable: false,
        ),
        TerrainFootprintCheck.outOfBounds,
      );
    },
  );
  test(
    'unknown group or mega beats known blocked terrain and tileset mismatch stays unknown',
    () {
      final snapshot = _snapshot(buildable: [false, true], masks: [0, 65535]);
      final terrain = _terrain([0, 65535], width: 2);
      final profile = UnitCollisionProfile(
        left: 0,
        up: 0,
        right: 32,
        down: 0,
        isFlyer: false,
      );
      expect(
        snapshot.check(
          terrain: terrain,
          mapTileset: 0,
          bounds: profile.boundsAt(0, 0),
          requireBuildable: true,
        ),
        TerrainFootprintCheck.unavailable,
      );
      expect(
        snapshot.check(
          terrain: _terrain([0]),
          mapTileset: 1,
          bounds: profile.boundsAt(0, 0),
          requireBuildable: true,
        ),
        TerrainFootprintCheck.unavailable,
      );
      final refs = [List.filled(16, 65535), List.filled(16, 1)];
      expect(_snapshot(references: refs).tile(0), isNull);
    },
  );
  test(
    'raw member reference determines walkability; zero mask is known blocked',
    () {
      final refs = [List.filled(16, 0), List.filled(16, 1)];
      refs[0][15] = 1;
      final snapshot = _snapshot(references: refs, masks: [65535, 0]);
      expect(
        _check(snapshot, _terrain([15]), 0, 0),
        TerrainFootprintCheck.unwalkable,
      );
      expect(snapshot.tile(-1), isNull);
      expect(snapshot.tile(65536), isNull);
    },
  );
  test(
    'ambiguous dimensions and missing dimensions are unavailable without exceptions',
    () {
      for (final dims in [0, 2]) {
        final terrain = _terrain([0], dimensions: dims);
        expect(
          _check(_snapshot(), terrain, 0, 0),
          TerrainFootprintCheck.unavailable,
        );
      }
    },
  );
  test('query preserves source CHK bytes', () {
    final terrain = _terrain([0]);
    final before = terrain.rawSection.payload.toList();
    _check(_snapshot(), terrain, 0, 0);
    expect(terrain.rawSection.payload, before);
  });
  test('domain validates shape and integer ranges and freezes its lists', () {
    for (final masks in [
      <int>[],
      [-1],
      [65536],
    ]) {
      expect(() => _snapshot(masks: masks), throwsArgumentError);
    }
    expect(() => _snapshot(buildable: []), throwsArgumentError);
    expect(
      () => _snapshot(references: [List.filled(15, 0), List.filled(16, 1)]),
      throwsArgumentError,
    );
    expect(
      () => _snapshot(references: [List.filled(16, -1), List.filled(16, 1)]),
      throwsArgumentError,
    );
    final masks = [65535, 0];
    final snapshot = _snapshot(masks: masks);
    masks.clear();
    expect(snapshot.walkableMasks, [65535, 0]);
    expect(() => snapshot.walkableMasks.clear(), throwsUnsupportedError);
  });
}

TerrainPlacementSnapshot _snapshot({
  List<bool>? buildable,
  List<List<int>>? references,
  List<int>? masks,
}) => TerrainPlacementSnapshot(
  tileset: 0,
  groupBuildable: buildable ?? [true, true],
  megaTileReferences: references ?? [List.filled(16, 0), List.filled(16, 1)],
  walkableMasks: masks ?? [65535, 65535],
);

TerrainFootprintCheck _check(
  TerrainPlacementSnapshot snapshot,
  ChkTerrainTileMapView terrain,
  int x,
  int y, {
  bool buildable = false,
}) => snapshot.check(
  terrain: terrain,
  mapTileset: 0,
  bounds: UnitCollisionProfile(
    left: 0,
    up: 0,
    right: 0,
    down: 0,
    isFlyer: false,
  ).boundsAt(x, y),
  requireBuildable: buildable,
);

ChkTerrainTileMapView _terrain(
  List<int> values, {
  int width = 1,
  int dimensions = 1,
}) {
  Uint8List section(String name, List<int> words) {
    final bytes = Uint8List(8 + words.length * 2)
      ..setRange(0, 4, name.codeUnits);
    final data = ByteData.sublistView(bytes)
      ..setUint32(4, words.length * 2, Endian.little);
    for (var i = 0; i < words.length; i++) {
      data.setUint16(8 + i * 2, words[i], Endian.little);
    }
    return bytes;
  }

  final bytes = Uint8List.fromList([
    for (var i = 0; i < dimensions; i++)
      ...section('DIM ', [width, values.length ~/ width]),
    ...section('MTXM', values),
  ]);
  final document = const RawChkParser().parse(bytes).document!;
  return const ChkTerrainViewDecoder().decode(document).tileMaps.single;
}
