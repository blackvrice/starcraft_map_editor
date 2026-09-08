import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starcraft_map_editor/domain/assets/starcraft_data_asset_manifest.dart';
import 'package:starcraft_map_editor/domain/chk/chk.dart';
import 'package:starcraft_map_editor/domain/placement/doodad_placement_recipe.dart';
import 'package:starcraft_map_editor/domain/placement/object_placement_factory.dart';
import 'package:starcraft_map_editor/domain/placement/unit_placement_capability.dart';

void main() {
  const unitFactory = UnitPlacementFactory();
  const spriteFactory = SpritePlacementFactory();
  const decoder = ChkObjectViewDecoder();

  group('UnitPlacementFactory', () {
    test('synthesizes every byte of a plain ground unit record', () {
      final record = unitFactory
          .create(
            capability: _capability(unitId: 37),
            unitId: 37,
            owner: 3,
            x: 0x0140,
            y: 0x00c8,
            classId: 0x11223344,
          )
          .bytes;

      expect(record, hasLength(ChkUnitPlacement.recordLength));
      final data = ByteData.sublistView(record);
      expect(data.getUint32(0, Endian.little), 0x11223344);
      expect(data.getUint16(4, Endian.little), 0x0140);
      expect(data.getUint16(6, Endian.little), 0x00c8);
      expect(data.getUint16(8, Endian.little), 37);
      expect(data.getUint16(10, Endian.little), 0, reason: 'relation flags');
      expect(
        data.getUint16(12, Endian.little),
        ChkUnitPlacement.stateInvincibleFlag |
            ChkUnitPlacement.stateHallucinatedFlag,
      );
      expect(
        data.getUint16(14, Endian.little),
        ChkUnitPlacement.validFieldOwnerFlag,
      );
      expect(data.getUint8(16), 3);
      expect(data.getUint8(17), 100);
      expect(data.getUint8(18), 100);
      expect(data.getUint8(19), 100);
      expect(data.getUint32(20, Endian.little), 0, reason: 'resource amount');
      expect(data.getUint16(24, Endian.little), 0, reason: 'hangar amount');
      expect(data.getUint16(26, Endian.little), 0, reason: 'state flags');
      expect(data.getUint32(28, Endian.little), 0, reason: 'unused');
      expect(data.getUint32(32, Endian.little), 0, reason: 'relation class id');
    });

    test('re-decodes as a single typed UNIT record', () {
      final record = unitFactory
          .create(
            capability: _capability(unitId: 0, hasShields: true),
            unitId: 0,
            owner: 11,
            x: 64,
            y: 96,
            classId: 7,
          )
          .bytes;

      final views = decoder.decode(_documentWith('UNIT', record));

      expect(views.diagnostics, isEmpty);
      final unit = views.unitSections.single.units.single;
      expect(unit.unitType, 0);
      expect(unit.owner, 11);
      expect(unit.x, 64);
      expect(unit.y, 96);
      expect(unit.classId, 7);
      expect(unit.hitpointPercent, 100);
      expect(unit.shieldPercent, 100);
      expect(unit.energyPercent, 100);
      expect(
        unit.validFieldFlags,
        ChkUnitPlacement.validFieldOwnerFlag |
            ChkUnitPlacement.validFieldShieldsFlag,
      );
      expect(unit.relationFlags, 0);
      expect(unit.relationClassId, 0);
    });

    test('marks only the capabilities the unit actually uses as valid', () {
      final flags = unitFactory.validFieldFlagsFor(
        _capability(
          unitId: 12,
          isSpellcaster: true,
          hasShields: true,
          isResourceContainer: true,
          hasHangar: true,
        ),
      );

      expect(
        flags,
        ChkUnitPlacement.validFieldOwnerFlag |
            ChkUnitPlacement.validFieldEnergyFlag |
            ChkUnitPlacement.validFieldShieldsFlag |
            ChkUnitPlacement.validFieldResourcesFlag |
            ChkUnitPlacement.validFieldHangarFlag,
      );
      expect(flags & ChkUnitPlacement.validFieldHitpointsFlag, 0);
    });

    test('keeps the invincible state valid only for a vincible unit', () {
      expect(
        unitFactory.validStateFlagsFor(_capability(unitId: 1)) &
            ChkUnitPlacement.stateInvincibleFlag,
        ChkUnitPlacement.stateInvincibleFlag,
      );
      expect(
        unitFactory.validStateFlagsFor(
          _capability(unitId: 1, isInvincible: true),
        ),
        0,
      );
    });

    test('never marks a building or an invincible unit hallucinated', () {
      expect(
        unitFactory.validStateFlagsFor(
          _capability(unitId: 106, isBuilding: true),
        ),
        ChkUnitPlacement.stateInvincibleFlag,
      );
      expect(
        unitFactory.validStateFlagsFor(
          _capability(unitId: 200, isInvincible: true, isBuilding: true),
        ),
        0,
      );
    });

    test('adds in transit, burrow and cloak from the capability', () {
      expect(
        unitFactory.validStateFlagsFor(
          _capability(unitId: 106, isBuilding: true, isFlyingBuilding: true),
        ),
        ChkUnitPlacement.stateInvincibleFlag |
            ChkUnitPlacement.stateInTransitFlag,
      );
      expect(
        unitFactory.validStateFlagsFor(
          _capability(unitId: 38, isBurrowable: true, isCloakable: true),
        ),
        ChkUnitPlacement.stateInvincibleFlag |
            ChkUnitPlacement.stateHallucinatedFlag |
            ChkUnitPlacement.stateBurrowFlag |
            ChkUnitPlacement.stateCloakFlag,
      );
    });

    test('uses the verified resource default for each container kind', () {
      expect(_capability(unitId: 1).defaultResourceAmount, 0);
      expect(
        _capability(
          unitId: 176,
          isResourceContainer: true,
        ).defaultResourceAmount,
        UnitPlacementCapability.mineralResourceAmount,
      );
      expect(
        _capability(
          unitId: 188,
          isResourceContainer: true,
          isGasResourceContainer: true,
        ).defaultResourceAmount,
        UnitPlacementCapability.gasResourceAmount,
      );
    });

    test('writes the resource default into the record', () {
      final record = unitFactory
          .create(
            capability: _capability(
              unitId: 188,
              isResourceContainer: true,
              isGasResourceContainer: true,
            ),
            unitId: 188,
            owner: 0,
            x: 0,
            y: 0,
            classId: 0,
          )
          .bytes;

      expect(
        ByteData.sublistView(record).getUint32(20, Endian.little),
        UnitPlacementCapability.gasResourceAmount,
      );
    });

    test('rejects a unit that needs an addon or Nydus relation', () {
      final result = unitFactory.create(
        capability: _capability(unitId: 106, requiresRelationLink: true),
        unitId: 106,
        owner: 0,
        x: 0,
        y: 0,
        classId: 0,
      );

      expect(result.isSynthesized, isFalse);
      expect(
        result.issueCode,
        ObjectPlacementFactoryCodes.unitRelationRequired,
      );
      expect(() => result.bytes, throwsStateError);
    });

    test('rejects a capability that belongs to another unit', () {
      final result = unitFactory.create(
        capability: _capability(unitId: 7),
        unitId: 8,
        owner: 0,
        x: 0,
        y: 0,
        classId: 0,
      );

      expect(result.isSynthesized, isFalse);
      expect(
        result.issueCode,
        ObjectPlacementFactoryCodes.unitCapabilityMismatch,
      );
    });

    test('rejects out-of-range identifiers and coordinates', () {
      expect(
        () => unitFactory.create(
          capability: _capability(unitId: 0),
          unitId: UnitPlacementCapability.maximumUnitId + 1,
          owner: 0,
          x: 0,
          y: 0,
          classId: 0,
        ),
        throwsRangeError,
      );
      expect(
        () => unitFactory.create(
          capability: _capability(unitId: 0),
          unitId: 0,
          owner: 0x100,
          x: 0,
          y: 0,
          classId: 0,
        ),
        throwsRangeError,
      );
      expect(
        () => unitFactory.create(
          capability: _capability(unitId: 0),
          unitId: 0,
          owner: 0,
          x: 0x10000,
          y: 0,
          classId: 0,
        ),
        throwsRangeError,
      );
      expect(
        () => unitFactory.create(
          capability: _capability(unitId: 0),
          unitId: 0,
          owner: 0,
          x: 0,
          y: 0,
          classId: 0x100000000,
        ),
        throwsRangeError,
      );
    });
  });

  group('UnitPlacementCapability', () {
    test('rejects a gas container that is not a resource container', () {
      expect(
        () => _capability(unitId: 188, isGasResourceContainer: true),
        throwsArgumentError,
      );
    });

    test('rejects a unit identifier outside the classic range', () {
      expect(
        () => _capability(unitId: UnitPlacementCapability.maximumUnitId + 1),
        throwsRangeError,
      );
    });
  });

  group('SpritePlacementFactory', () {
    test('synthesizes every byte of a pure sprite record', () {
      final record = spriteFactory
          .createPureSprite(spriteId: 130, owner: 4, x: 0x0210, y: 0x0184)
          .bytes;

      expect(record, hasLength(ChkSpritePlacement.recordLength));
      final data = ByteData.sublistView(record);
      expect(data.getUint16(0, Endian.little), 130);
      expect(data.getUint16(2, Endian.little), 0x0210);
      expect(data.getUint16(4, Endian.little), 0x0184);
      expect(data.getUint8(6), 4);
      expect(data.getUint8(7), 0, reason: 'unused');
      expect(
        data.getUint16(8, Endian.little),
        ChkSpritePlacement.drawAsSpriteFlag,
      );
    });

    test('re-decodes as a pure sprite and not as a sprite-unit', () {
      final record = spriteFactory
          .createPureSprite(spriteId: 5, owner: 0, x: 16, y: 16)
          .bytes;

      final views = decoder.decode(_documentWith('THG2', record));

      expect(views.diagnostics, isEmpty);
      final sprite = views.spriteSections.single.sprites.single;
      expect(sprite.spriteType, 5);
      expect(sprite.drawsAsSprite, isTrue);
      expect(sprite.hasUnitFlag, isFalse);
      expect(sprite.isSpriteUnitDisabled, isFalse);
      expect(sprite.unused, 0);
    });

    test('rejects a sprite identifier outside the classic range', () {
      expect(
        () => spriteFactory.createPureSprite(
          spriteId: SpritePlacementFactory.maximumSpriteId + 1,
          owner: 0,
          x: 0,
          y: 0,
        ),
        throwsRangeError,
      );
    });

    test('keeps sprite-unit placement disabled with a stable reason', () {
      final result = spriteFactory.createSpriteUnit();

      expect(result.isSynthesized, isFalse);
      expect(
        result.issueCode,
        ObjectPlacementFactoryCodes.spriteUnitUnsupported,
      );
    });
  });

  group('DoodadPlacementFactory', () {
    const factory = DoodadPlacementFactory();

    test('plans DD2, footprint tiles and the Sprite overlay together', () {
      final plan = factory
          .create(
            recipe: _recipe(overlay: true),
            owner: 3,
            originTileX: 2,
            originTileY: 5,
          )
          .plan;

      expect(plan.centerPixelX, 2 * 32 + 32);
      expect(plan.centerPixelY, 5 * 32 + 16);

      final doodad = ByteData.sublistView(plan.doodadRecord);
      expect(plan.doodadRecord, hasLength(ChkDoodadPlacement.recordLength));
      expect(doodad.getUint16(0, Endian.little), 7);
      expect(doodad.getUint16(2, Endian.little), plan.centerPixelX);
      expect(doodad.getUint16(4, Endian.little), plan.centerPixelY);
      expect(doodad.getUint8(6), 3);
      expect(doodad.getUint8(7), DoodadPlacementRecipe.enabled);

      expect(plan.hasOverlay, isTrue);
      final overlay = ByteData.sublistView(plan.overlayRecord!);
      expect(overlay.getUint16(0, Endian.little), 42);
      expect(overlay.getUint16(2, Endian.little), plan.centerPixelX);
      expect(overlay.getUint8(6), 3);
      expect(overlay.getUint8(7), 0);
      expect(
        overlay.getUint16(8, Endian.little),
        ChkSpritePlacement.drawAsSpriteFlag,
      );

      expect(plan.tileWrites, hasLength(2));
      expect(plan.tileWrites.first.tileX, 2);
      expect(plan.tileWrites.first.tileY, 5);
      expect(plan.tileWrites.first.rawTileValue, 200 * 16);
      expect(plan.tileWrites.last.tileX, 3);
      expect(plan.tileWrites.last.rawTileValue, 200 * 16 + 1);
    });

    test('omits the overlay record when the recipe has none', () {
      final plan = factory
          .create(
            recipe: _recipe(overlay: false),
            owner: 0,
            originTileX: 0,
            originTileY: 0,
          )
          .plan;

      expect(plan.hasOverlay, isFalse);
      expect(plan.overlayRecord, isNull);
    });

    test('skips footprint cells that write no terrain', () {
      final plan = factory
          .create(
            recipe: _recipe(overlay: false, writesSecondTile: false),
            owner: 0,
            originTileX: 1,
            originTileY: 1,
          )
          .plan;

      expect(plan.tileWrites, hasLength(1));
      expect(plan.tileWrites.single.tileX, 1);
    });

    test('rejects a center that cannot fit a uint16 coordinate', () {
      final result = factory.create(
        recipe: _recipe(overlay: false),
        owner: 0,
        originTileX: 2048,
        originTileY: 0,
      );

      expect(result.isPlanned, isFalse);
      expect(
        result.issueCode,
        ObjectPlacementFactoryCodes.doodadCenterOutOfRange,
      );
      expect(() => result.plan, throwsStateError);
    });

    test('rejects a negative origin tile', () {
      expect(
        () => factory.create(
          recipe: _recipe(overlay: false),
          owner: 0,
          originTileX: -1,
          originTileY: 0,
        ),
        throwsRangeError,
      );
    });

    test('reads the CV5 group of a raw tile value', () {
      expect(DoodadTileWrite.groupOf(200 * 16 + 3), 200);
      expect(
        DoodadTileWrite(
          tileX: 0,
          tileY: 0,
          rawTileValue: 1,
          requiredTileGroup: 0,
        ).acceptsAnyTerrain,
        isTrue,
      );
    });
  });
}

DoodadPlacementRecipe _recipe({
  required bool overlay,
  bool writesSecondTile = true,
}) => DoodadPlacementRecipe(
  tileset: StarCraftTilesetAssetSet.jungle,
  startTileGroup: 200,
  doodadType: 7,
  width: 2,
  height: 1,
  centerOffsetX: 32,
  centerOffsetY: 16,
  footprint: [
    DoodadFootprintCell(
      x: 0,
      y: 0,
      rawTileValue: 200 * 16,
      requiredTileGroup: 0,
    ),
    DoodadFootprintCell(
      x: 1,
      y: 0,
      rawTileValue: writesSecondTile ? 200 * 16 + 1 : null,
      requiredTileGroup: 0,
    ),
  ],
  overlay: overlay
      ? DoodadOverlayRecipe(semantic: DoodadOverlaySemantic.pureSprite, id: 42)
      : null,
);

UnitPlacementCapability _capability({
  required int unitId,
  bool isSpellcaster = false,
  bool hasShields = false,
  bool isResourceContainer = false,
  bool isGasResourceContainer = false,
  bool hasHangar = false,
  bool isFlyingBuilding = false,
  bool isBurrowable = false,
  bool isCloakable = false,
  bool isInvincible = false,
  bool isBuilding = false,
  bool requiresRelationLink = false,
}) => UnitPlacementCapability(
  unitId: unitId,
  isSpellcaster: isSpellcaster,
  hasShields: hasShields,
  isResourceContainer: isResourceContainer,
  isGasResourceContainer: isGasResourceContainer,
  hasHangar: hasHangar,
  isFlyingBuilding: isFlyingBuilding,
  isBurrowable: isBurrowable,
  isCloakable: isCloakable,
  isInvincible: isInvincible,
  isBuilding: isBuilding,
  requiresRelationLink: requiresRelationLink,
);

RawChkDocument _documentWith(String name, Uint8List payload) {
  final section = RawChkSection(
    nameBytes: name.codeUnits,
    declaredLength: payload.length,
    payload: payload,
    sourceOffset: 0,
  );
  return RawChkDocument(
    sections: [section],
    sourceLength: RawChkParser.headerLength + payload.length,
  );
}
