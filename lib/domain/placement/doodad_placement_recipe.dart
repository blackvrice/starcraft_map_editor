import '../assets/starcraft_data_asset_manifest.dart';

enum DoodadOverlaySemantic { pureSprite, spriteUnit }

final class DoodadOverlayRecipe {
  DoodadOverlayRecipe({required this.semantic, required this.id}) {
    final maximum = switch (semantic) {
      DoodadOverlaySemantic.pureSprite => maximumSpriteId,
      DoodadOverlaySemantic.spriteUnit => maximumUnitId,
    };
    if (id < 0 || id > maximum) {
      throw RangeError.range(id, 0, maximum, 'id');
    }
  }

  static const maximumSpriteId = 516;
  static const maximumUnitId = 227;
  static const drawAsSpriteFlag = 0x1000;

  final DoodadOverlaySemantic semantic;
  final int id;

  int get thg2Flags =>
      semantic == DoodadOverlaySemantic.pureSprite ? drawAsSpriteFlag : 0;
}

final class DoodadFootprintCell {
  DoodadFootprintCell({
    required this.x,
    required this.y,
    required this.rawTileValue,
    required this.requiredTileGroup,
  }) {
    if (x < 0 || x >= DoodadPlacementRecipe.maximumFootprintAxis) {
      throw RangeError.range(
        x,
        0,
        DoodadPlacementRecipe.maximumFootprintAxis - 1,
        'x',
      );
    }
    if (y < 0 || y >= DoodadPlacementRecipe.maximumFootprintAxis) {
      throw RangeError.range(
        y,
        0,
        DoodadPlacementRecipe.maximumFootprintAxis - 1,
        'y',
      );
    }
    _checkU16(rawTileValue, 'rawTileValue', nullable: true);
    _checkU16(requiredTileGroup, 'requiredTileGroup');
  }

  final int x;
  final int y;
  final int? rawTileValue;
  final int requiredTileGroup;

  bool get writesTerrain => rawTileValue != null;
  bool get isPlaceableAnywhere => requiredTileGroup == 0;
}

final class DoodadPlacementRecipe {
  DoodadPlacementRecipe({
    required this.tileset,
    required this.startTileGroup,
    required this.doodadType,
    required this.width,
    required this.height,
    required this.centerOffsetX,
    required this.centerOffsetY,
    required Iterable<DoodadFootprintCell> footprint,
    this.enabledValue = enabled,
    this.overlay,
  }) : footprint = List.unmodifiable(footprint) {
    _checkU16(startTileGroup, 'startTileGroup');
    _checkU16(doodadType, 'doodadType');
    if (width < 1 || width > maximumFootprintAxis) {
      throw RangeError.range(width, 1, maximumFootprintAxis, 'width');
    }
    if (height < 1 || height > maximumFootprintAxis) {
      throw RangeError.range(height, 1, maximumFootprintAxis, 'height');
    }
    if (width * height > maximumFootprintCells) {
      throw RangeError('The doodad footprint is too large.');
    }
    if (centerOffsetX != width * halfTilePixels ||
        centerOffsetY != height * halfTilePixels) {
      throw ArgumentError(
        'Doodad center offsets must point to the footprint center.',
      );
    }
    if (enabledValue != enabled) {
      throw ArgumentError.value(
        enabledValue,
        'enabledValue',
        'Only the verified enabled DD2 value is supported.',
      );
    }
    if (this.footprint.length != width * height) {
      throw ArgumentError(
        'The doodad footprint size does not match width/height.',
      );
    }
    var writesTerrain = false;
    for (var index = 0; index < this.footprint.length; index++) {
      final cell = this.footprint[index];
      final expectedX = index % width;
      final expectedY = index ~/ width;
      if (cell.x != expectedX || cell.y != expectedY) {
        throw ArgumentError('Doodad footprint cells must be row-major.');
      }
      final expectedRaw = (startTileGroup + expectedY) * 16 + expectedX;
      if (cell.rawTileValue != null && cell.rawTileValue != expectedRaw) {
        throw ArgumentError(
          'Doodad footprint tile values must match their CV5 group/member.',
        );
      }
      writesTerrain = writesTerrain || cell.writesTerrain;
    }
    if (!writesTerrain) {
      throw ArgumentError('A doodad recipe must write at least one MTXM tile.');
    }
  }

  static const maximumFootprintAxis = 16;
  static const maximumFootprintCells = 256;
  static const halfTilePixels = 16;
  static const enabled = 1;

  final StarCraftTilesetAssetSet tileset;
  final int startTileGroup;
  final int doodadType;
  final int width;
  final int height;
  final int centerOffsetX;
  final int centerOffsetY;
  final int enabledValue;
  final List<DoodadFootprintCell> footprint;
  final DoodadOverlayRecipe? overlay;
}

void _checkU16(int? value, String name, {bool nullable = false}) {
  if (value == null && nullable) {
    return;
  }
  if (value == null) {
    throw ArgumentError.notNull(name);
  }
  if (value < 0 || value > 0xffff) {
    throw RangeError.range(value, 0, 0xffff, name);
  }
}
