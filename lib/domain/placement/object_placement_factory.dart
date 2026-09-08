import 'dart:typed_data';

import '../chk/typed/chk_object_views.dart';
import 'doodad_placement_recipe.dart';
import 'unit_placement_capability.dart';

/// Stable reasons a validated default record cannot be synthesized.
abstract final class ObjectPlacementFactoryCodes {
  static const unitRelationRequired = 'CHK_PLACEMENT_UNIT_RELATION_REQUIRED';
  static const unitCapabilityMismatch =
      'CHK_PLACEMENT_UNIT_CAPABILITY_MISMATCH';
  static const spriteUnitUnsupported = 'CHK_PLACEMENT_SPRITE_UNIT_UNSUPPORTED';
  static const doodadCenterOutOfRange = 'CHK_PLACEMENT_DOODAD_CENTER_RANGE';
}

/// The outcome of synthesizing one CHK placement record.
///
/// A rejected result never carries partial bytes: the caller must not write
/// anything to the document.
final class ObjectPlacementRecord {
  ObjectPlacementRecord._(this._bytes, this.issueCode);

  factory ObjectPlacementRecord.synthesized(Uint8List bytes) =>
      ObjectPlacementRecord._(Uint8List.fromList(bytes), null);

  factory ObjectPlacementRecord.rejected(String issueCode) =>
      ObjectPlacementRecord._(null, issueCode);

  final Uint8List? _bytes;
  final String? issueCode;

  bool get isSynthesized => _bytes != null;

  /// The synthesized record bytes. Throws when the record was rejected.
  Uint8List get bytes {
    final synthesized = _bytes;
    if (synthesized == null) {
      throw StateError('A rejected placement record has no bytes.');
    }
    return Uint8List.fromList(synthesized);
  }
}

/// Builds a validated default 36 byte `UNIT` record for a unit that the
/// current map does not contain.
///
/// The defaults reproduce the Chkdraft selection values recorded in
/// `docs/research/VISUAL_PLACEMENT_AND_CHK_RULES.md` section 3.2. Fields the
/// research did not confirm stay zero, and the class instance is supplied by
/// the placement command so it can be allocated against the open document.
class UnitPlacementFactory {
  const UnitPlacementFactory();

  static const defaultHitpointPercent = 100;
  static const defaultShieldPercent = 100;
  static const defaultEnergyPercent = 100;

  ObjectPlacementRecord create({
    required UnitPlacementCapability capability,
    required int unitId,
    required int owner,
    required int x,
    required int y,
    required int classId,
  }) {
    if (unitId < 0 || unitId > UnitPlacementCapability.maximumUnitId) {
      throw RangeError.range(
        unitId,
        0,
        UnitPlacementCapability.maximumUnitId,
        'unitId',
      );
    }
    RangeError.checkValueInInterval(owner, 0, 0xff, 'owner');
    RangeError.checkValueInInterval(x, 0, 0xffff, 'x');
    RangeError.checkValueInInterval(y, 0, 0xffff, 'y');
    RangeError.checkValueInInterval(classId, 0, 0xffffffff, 'classId');
    if (capability.unitId != unitId) {
      return ObjectPlacementRecord.rejected(
        ObjectPlacementFactoryCodes.unitCapabilityMismatch,
      );
    }
    if (capability.requiresRelationLink) {
      return ObjectPlacementRecord.rejected(
        ObjectPlacementFactoryCodes.unitRelationRequired,
      );
    }

    final record = Uint8List(ChkUnitPlacement.recordLength);
    ByteData.sublistView(record)
      ..setUint32(0, classId, Endian.little)
      ..setUint16(4, x, Endian.little)
      ..setUint16(6, y, Endian.little)
      ..setUint16(8, unitId, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, validStateFlagsFor(capability), Endian.little)
      ..setUint16(14, validFieldFlagsFor(capability), Endian.little)
      ..setUint8(16, owner)
      ..setUint8(17, defaultHitpointPercent)
      ..setUint8(18, defaultShieldPercent)
      ..setUint8(19, defaultEnergyPercent)
      ..setUint32(20, capability.defaultResourceAmount, Endian.little)
      ..setUint16(24, 0, Endian.little)
      ..setUint16(26, 0, Endian.little)
      ..setUint32(28, 0, Endian.little)
      ..setUint32(32, 0, Endian.little);
    return ObjectPlacementRecord.synthesized(record);
  }

  /// Owner is always valid. Every other field is valid only when the verified
  /// capability says the unit actually uses it.
  int validFieldFlagsFor(UnitPlacementCapability capability) {
    var flags = ChkUnitPlacement.validFieldOwnerFlag;
    if (capability.isSpellcaster) {
      flags |= ChkUnitPlacement.validFieldEnergyFlag;
    }
    if (capability.hasShields) {
      flags |= ChkUnitPlacement.validFieldShieldsFlag;
    }
    if (capability.isResourceContainer) {
      flags |= ChkUnitPlacement.validFieldResourcesFlag;
    }
    if (capability.hasHangar) {
      flags |= ChkUnitPlacement.validFieldHangarFlag;
    }
    return flags;
  }

  /// Invincible is valid by default and removed for a unit that `units.dat`
  /// already marks invincible. Hallucinated is valid only for a unit that is
  /// neither invincible nor a building.
  int validStateFlagsFor(UnitPlacementCapability capability) {
    var flags = ChkUnitPlacement.stateInvincibleFlag;
    if (capability.isFlyingBuilding) {
      flags |= ChkUnitPlacement.stateInTransitFlag;
    }
    if (capability.isBurrowable) {
      flags |= ChkUnitPlacement.stateBurrowFlag;
    }
    if (capability.isCloakable) {
      flags |= ChkUnitPlacement.stateCloakFlag;
    }
    if (capability.isInvincible) {
      flags &= ~ChkUnitPlacement.stateInvincibleFlag;
    } else if (!capability.isBuilding) {
      flags |= ChkUnitPlacement.stateHallucinatedFlag;
    }
    return flags;
  }
}

/// Builds a validated default 10 byte `THG2` record.
///
/// Only pure sprites are supported. A sprite-unit needs verified `units.dat`
/// relations that the placement research has not confirmed, and Doodad overlay
/// records are produced by [DoodadPlacementRecipe] instead of this factory.
class SpritePlacementFactory {
  const SpritePlacementFactory();

  static const maximumSpriteId = DoodadOverlayRecipe.maximumSpriteId;

  ObjectPlacementRecord createPureSprite({
    required int spriteId,
    required int owner,
    required int x,
    required int y,
  }) {
    if (spriteId < 0 || spriteId > maximumSpriteId) {
      throw RangeError.range(spriteId, 0, maximumSpriteId, 'spriteId');
    }
    RangeError.checkValueInInterval(owner, 0, 0xff, 'owner');
    RangeError.checkValueInInterval(x, 0, 0xffff, 'x');
    RangeError.checkValueInInterval(y, 0, 0xffff, 'y');

    final record = Uint8List(ChkSpritePlacement.recordLength);
    ByteData.sublistView(record)
      ..setUint16(0, spriteId, Endian.little)
      ..setUint16(2, x, Endian.little)
      ..setUint16(4, y, Endian.little)
      ..setUint8(6, owner)
      ..setUint8(7, 0)
      ..setUint16(8, ChkSpritePlacement.drawAsSpriteFlag, Endian.little);
    return ObjectPlacementRecord.synthesized(record);
  }

  /// Sprite-unit placement stays disabled until the unit relation rules are
  /// verified. The catalog shows the entry with this reason instead of hiding
  /// it.
  ObjectPlacementRecord createSpriteUnit() => ObjectPlacementRecord.rejected(
    ObjectPlacementFactoryCodes.spriteUnitUnsupported,
  );
}

/// One `MTXM` cell a Doodad placement writes.
final class DoodadTileWrite {
  DoodadTileWrite({
    required this.tileX,
    required this.tileY,
    required this.rawTileValue,
    required this.requiredTileGroup,
  });

  final int tileX;
  final int tileY;
  final int rawTileValue;
  final int requiredTileGroup;

  /// A required group of zero means the DDData entry allows any terrain.
  bool get acceptsAnyTerrain => requiredTileGroup == 0;

  /// The CV5 group of a raw tile value, as recorded in the placement research.
  static int groupOf(int rawTileValue) => rawTileValue >> 4;
}

/// Everything one Doodad placement must apply in a single command.
///
/// A Doodad is never partially applied: the `DD2 ` metadata, every footprint
/// `MTXM` cell and the optional `THG2` overlay belong to the same command and
/// the same Undo entry.
final class DoodadPlacementPlan {
  DoodadPlacementPlan._({
    required this.doodadRecord,
    required this.overlayRecord,
    required List<DoodadTileWrite> tileWrites,
    required this.centerPixelX,
    required this.centerPixelY,
  }) : tileWrites = List.unmodifiable(tileWrites);

  final Uint8List doodadRecord;
  final Uint8List? overlayRecord;
  final List<DoodadTileWrite> tileWrites;
  final int centerPixelX;
  final int centerPixelY;

  bool get hasOverlay => overlayRecord != null;
}

/// The outcome of planning one Doodad placement.
final class DoodadPlacementResult {
  DoodadPlacementResult._(this._plan, this.issueCode);

  factory DoodadPlacementResult.planned(DoodadPlacementPlan plan) =>
      DoodadPlacementResult._(plan, null);

  factory DoodadPlacementResult.rejected(String issueCode) =>
      DoodadPlacementResult._(null, issueCode);

  final DoodadPlacementPlan? _plan;
  final String? issueCode;

  bool get isPlanned => _plan != null;

  DoodadPlacementPlan get plan {
    final planned = _plan;
    if (planned == null) {
      throw StateError('A rejected Doodad placement has no plan.');
    }
    return planned;
  }
}

/// Turns a validated [DoodadPlacementRecipe] into the exact bytes and tile
/// writes one placement applies.
///
/// Terrain bounds and DDData placibility are checked by the placement command
/// because they depend on the open document, not on the recipe.
class DoodadPlacementFactory {
  const DoodadPlacementFactory();

  static const tilePixels = 32;

  DoodadPlacementResult create({
    required DoodadPlacementRecipe recipe,
    required int owner,
    required int originTileX,
    required int originTileY,
  }) {
    RangeError.checkValueInInterval(owner, 0, 0xff, 'owner');
    if (originTileX < 0) {
      throw RangeError.value(
        originTileX,
        'originTileX',
        'Must not be negative',
      );
    }
    if (originTileY < 0) {
      throw RangeError.value(
        originTileY,
        'originTileY',
        'Must not be negative',
      );
    }

    final centerPixelX = originTileX * tilePixels + recipe.centerOffsetX;
    final centerPixelY = originTileY * tilePixels + recipe.centerOffsetY;
    if (centerPixelX > 0xffff || centerPixelY > 0xffff) {
      return DoodadPlacementResult.rejected(
        ObjectPlacementFactoryCodes.doodadCenterOutOfRange,
      );
    }

    final doodadRecord = Uint8List(ChkDoodadPlacement.recordLength);
    ByteData.sublistView(doodadRecord)
      ..setUint16(0, recipe.doodadType, Endian.little)
      ..setUint16(2, centerPixelX, Endian.little)
      ..setUint16(4, centerPixelY, Endian.little)
      ..setUint8(6, owner)
      ..setUint8(7, recipe.enabledValue);

    Uint8List? overlayRecord;
    final overlay = recipe.overlay;
    if (overlay != null) {
      overlayRecord = Uint8List(ChkSpritePlacement.recordLength);
      ByteData.sublistView(overlayRecord)
        ..setUint16(0, overlay.id, Endian.little)
        ..setUint16(2, centerPixelX, Endian.little)
        ..setUint16(4, centerPixelY, Endian.little)
        ..setUint8(6, owner)
        ..setUint8(7, 0)
        ..setUint16(8, overlay.thg2Flags, Endian.little);
    }

    final tileWrites = <DoodadTileWrite>[];
    for (final cell in recipe.footprint) {
      final rawValue = cell.rawTileValue;
      if (rawValue == null) {
        continue;
      }
      tileWrites.add(
        DoodadTileWrite(
          tileX: originTileX + cell.x,
          tileY: originTileY + cell.y,
          rawTileValue: rawValue,
          requiredTileGroup: cell.requiredTileGroup,
        ),
      );
    }

    return DoodadPlacementResult.planned(
      DoodadPlacementPlan._(
        doodadRecord: doodadRecord,
        overlayRecord: overlayRecord,
        tileWrites: tileWrites,
        centerPixelX: centerPixelX,
        centerPixelY: centerPixelY,
      ),
    );
  }
}
