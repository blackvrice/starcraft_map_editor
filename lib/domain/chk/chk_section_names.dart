import 'raw_chk_section.dart';

abstract final class ChkSectionNames {
  static const type = [0x54, 0x59, 0x50, 0x45];
  static const version = [0x56, 0x45, 0x52, 0x20];
  static const internalVersion = [0x49, 0x56, 0x45, 0x52];
  static const dimensions = [0x44, 0x49, 0x4d, 0x20];
  static const tileset = [0x45, 0x52, 0x41, 0x20];
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

  static bool isScenarioProperties(RawChkSection section) =>
      section.hasNameBytes(scenarioProperties);

  static bool isLegacyStrings(RawChkSection section) =>
      section.hasNameBytes(legacyStrings);

  static bool isExtendedStrings(RawChkSection section) =>
      section.hasNameBytes(extendedStrings);
}
