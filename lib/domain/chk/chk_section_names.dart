import 'raw_chk_section.dart';

abstract final class ChkSectionNames {
  static const type = [0x54, 0x59, 0x50, 0x45];
  static const version = [0x56, 0x45, 0x52, 0x20];
  static const internalVersion = [0x49, 0x56, 0x45, 0x52];
  static const dimensions = [0x44, 0x49, 0x4d, 0x20];
  static const tileset = [0x45, 0x52, 0x41, 0x20];
  static const terrainTiles = [0x4d, 0x54, 0x58, 0x4d];
  static const unitPlacements = [0x55, 0x4e, 0x49, 0x54];
  static const doodadPlacements = [0x44, 0x44, 0x32, 0x20];
  static const spritePlacements = [0x54, 0x48, 0x47, 0x32];
  static const locations = [0x4d, 0x52, 0x47, 0x4e];
  static const scenarioProperties = [0x53, 0x50, 0x52, 0x50];
  static const legacyStrings = [0x53, 0x54, 0x52, 0x20];
  static const extendedStrings = [0x53, 0x54, 0x52, 0x78];

  static bool isType(RawChkSection section) => section.hasNameBytes(type);

  static bool isVersion(RawChkSection section) => section.hasNameBytes(version);

  static bool isInternalVersion(RawChkSection section) =>
      section.hasNameBytes(internalVersion);

  static bool isDimensions(RawChkSection section) =>
      section.hasNameBytes(dimensions);

  static bool isTileset(RawChkSection section) => section.hasNameBytes(tileset);

  static bool isTerrainTiles(RawChkSection section) =>
      section.hasNameBytes(terrainTiles);

  static bool isUnitPlacements(RawChkSection section) =>
      section.hasNameBytes(unitPlacements);

  static bool isDoodadPlacements(RawChkSection section) =>
      section.hasNameBytes(doodadPlacements);

  static bool isSpritePlacements(RawChkSection section) =>
      section.hasNameBytes(spritePlacements);

  static bool isLocations(RawChkSection section) =>
      section.hasNameBytes(locations);

  static bool isScenarioProperties(RawChkSection section) =>
      section.hasNameBytes(scenarioProperties);

  static bool isLegacyStrings(RawChkSection section) =>
      section.hasNameBytes(legacyStrings);

  static bool isExtendedStrings(RawChkSection section) =>
      section.hasNameBytes(extendedStrings);
}
