/// Candidate SCData fields. Structural validity is not runtime compatibility.
enum EudTable { unit, weapon }

enum EudValueType { boolean, unsignedInteger, enumeration }

enum EudFieldUnit { flag, shieldPoints, rawDistance, damageType }

enum EudFieldError {
  unknownField,
  invalidTarget,
  invalidType,
  outOfRange,
  invalidEnum,
}

class EudFieldDefinition {
  const EudFieldDefinition({
    required this.key,
    required this.table,
    required this.member,
    required this.type,
    required this.bits,
    required this.unit,
    this.choices = const [],
    this.overlapsChk = false,
    this.relatedFields = const [],
  });

  final String key;
  final EudTable table;
  final String member;
  final EudValueType type;
  final int bits;
  final EudFieldUnit unit;
  final List<String> choices;
  final bool overlapsChk;
  final List<String> relatedFields;

  int get targetCount => table == EudTable.unit ? 228 : 130;
  bool get requiresWeaponImpactAnalysis => table == EudTable.weapon;

  /// Storage bounds only; these are not verified gameplay limits.
  int get storageMaximum => (1 << bits) - 1;

  EudFieldError? validate(int targetId, Object? value) {
    if (targetId < 0 || targetId >= targetCount) {
      return EudFieldError.invalidTarget;
    }
    switch (type) {
      case EudValueType.boolean:
        return value is bool ? null : EudFieldError.invalidType;
      case EudValueType.unsignedInteger:
        if (value is! int) return EudFieldError.invalidType;
        return value < 0 || value > storageMaximum
            ? EudFieldError.outOfRange
            : null;
      case EudValueType.enumeration:
        if (value is! String) return EudFieldError.invalidType;
        return choices.contains(value) ? null : EudFieldError.invalidEnum;
    }
  }
}

enum EudCompatibility { toolVersionMismatch, runtimeUnverified }

abstract final class EudFieldManifest {
  static const euddraftVersion = '0.10.2.5';
  static const eudplibVersion = '0.80.6';
  static const sourceRevision = 'e04ac54dccbdcda94512214c4730b46f7f13d74f';

  /// No SC:R build has been verified for generated field patches yet.
  static const List<String> verifiedGameBuilds = [];

  static EudCompatibility compatibility({
    required String euddraft,
    required String eudplib,
  }) => euddraft == euddraftVersion && eudplib == eudplibVersion
      ? EudCompatibility.runtimeUnverified
      : EudCompatibility.toolVersionMismatch;

  static const fields = <EudFieldDefinition>[
    EudFieldDefinition(
      key: 'unit.hasShield',
      table: EudTable.unit,
      member: 'TrgUnit.hasShield',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
      relatedFields: ['unit.maxShield'],
    ),
    EudFieldDefinition(
      key: 'unit.maxShield',
      table: EudTable.unit,
      member: 'TrgUnit.maxShield',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.shieldPoints,
      overlapsChk: true,
      relatedFields: ['unit.hasShield'],
    ),
    EudFieldDefinition(
      key: 'weapon.minRange',
      table: EudTable.weapon,
      member: 'Weapon.minRange',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.rawDistance,
      relatedFields: ['weapon.maxRange'],
    ),
    EudFieldDefinition(
      key: 'weapon.maxRange',
      table: EudTable.weapon,
      member: 'Weapon.maxRange',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.rawDistance,
      relatedFields: ['weapon.minRange'],
    ),
    EudFieldDefinition(
      key: 'weapon.damageType',
      table: EudTable.weapon,
      member: 'Weapon.damageType',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.damageType,
      choices: [
        'Independent',
        'Explosive',
        'Concussive',
        'Normal',
        'IgnoreArmor',
      ],
    ),
  ];

  static EudFieldDefinition? find(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  static EudFieldError? validate(String key, int targetId, Object? value) {
    final field = find(key);
    return field == null
        ? EudFieldError.unknownField
        : field.validate(targetId, value);
  }
}
