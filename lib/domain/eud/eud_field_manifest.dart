/// Candidate SCData fields. Structural validity is not runtime compatibility.
enum EudTable { unit, weapon, flingy, upgrade, tech, player, sprite, image }

enum EudValueType { boolean, unsignedInteger, enumeration }

enum EudFieldUnit {
  flag,
  shieldPoints,
  rawDistance,
  damageType,
  raw,
  referenceId,
  frames,
  bitmask,
  supplyHalfPoints,
}

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
    this.maximum,
    this.targetLimit,
    this.allowedBits,
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
  final int? maximum;
  final int? targetLimit;
  final int? allowedBits;

  int get targetCount =>
      targetLimit ??
      switch (table) {
        EudTable.unit => 228,
        EudTable.weapon => 130,
        EudTable.flingy => 209,
        EudTable.upgrade => 61,
        EudTable.tech => 44,
        EudTable.player => 8,
        EudTable.sprite => 517,
        EudTable.image => 999,
      };
  bool get requiresWeaponImpactAnalysis => table == EudTable.weapon;

  /// Storage bounds only; these are not verified gameplay limits.
  int get storageMaximum => (1 << bits) - 1;
  int get valueMaximum => maximum ?? storageMaximum;

  EudFieldError? validate(int targetId, Object? value) {
    if (targetId < 0 || targetId >= targetCount) {
      return EudFieldError.invalidTarget;
    }
    switch (type) {
      case EudValueType.boolean:
        return value is bool ? null : EudFieldError.invalidType;
      case EudValueType.unsignedInteger:
        if (value is! int) return EudFieldError.invalidType;
        return value < 0 ||
                value > valueMaximum ||
                (allowedBits != null && value & ~allowedBits! != 0)
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
      key: 'unit.groundWeapon',
      table: EudTable.unit,
      member: 'TrgUnit.groundWeapon',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.referenceId,
      maximum: 130,
    ),
    EudFieldDefinition(
      key: 'unit.airWeapon',
      table: EudTable.unit,
      member: 'TrgUnit.airWeapon',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.referenceId,
      maximum: 130,
    ),
    EudFieldDefinition(
      key: 'unit.flingy',
      table: EudTable.unit,
      member: 'TrgUnit.flingy',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.referenceId,
      maximum: 208,
    ),
    EudFieldDefinition(
      key: 'unit.seekRange',
      table: EudTable.unit,
      member: 'TrgUnit.seekRange',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.rawDistance,
    ),
    EudFieldDefinition(
      key: 'unit.sightRange',
      table: EudTable.unit,
      member: 'TrgUnit.sightRange',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.rawDistance,
    ),
    EudFieldDefinition(
      key: 'unit.sizeType',
      table: EudTable.unit,
      member: 'TrgUnit.sizeType',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: ['Independent', 'Small', 'Medium', 'Large'],
    ),
    EudFieldDefinition(
      key: 'unit.baseProperty',
      table: EudTable.unit,
      member: 'TrgUnit.baseProperty',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.bitmask,
      allowedBits: 4294705151,
    ),
    EudFieldDefinition(
      key: 'unit.portrait',
      table: EudTable.unit,
      member: 'TrgUnit.portrait',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 109,
    ),
    EudFieldDefinition(
      key: 'unit.readySound',
      table: EudTable.unit,
      member: 'TrgUnit.readySound',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 106,
    ),
    EudFieldDefinition(
      key: 'unit.whatSoundStart',
      table: EudTable.unit,
      member: 'TrgUnit.whatSoundStart',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 228,
    ),
    EudFieldDefinition(
      key: 'unit.whatSoundEnd',
      table: EudTable.unit,
      member: 'TrgUnit.whatSoundEnd',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 228,
    ),
    EudFieldDefinition(
      key: 'unit.pissedSoundStart',
      table: EudTable.unit,
      member: 'TrgUnit.pissedSoundStart',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 106,
    ),
    EudFieldDefinition(
      key: 'unit.pissedSoundEnd',
      table: EudTable.unit,
      member: 'TrgUnit.pissedSoundEnd',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 106,
    ),
    EudFieldDefinition(
      key: 'unit.yesSoundStart',
      table: EudTable.unit,
      member: 'TrgUnit.yesSoundStart',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 106,
    ),
    EudFieldDefinition(
      key: 'unit.yesSoundEnd',
      table: EudTable.unit,
      member: 'TrgUnit.yesSoundEnd',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 1143,
      targetLimit: 106,
    ),
    EudFieldDefinition(
      key: 'weapon.targetFlags',
      table: EudTable.weapon,
      member: 'Weapon.targetFlags',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.bitmask,
      allowedBits: 511,
    ),
    EudFieldDefinition(
      key: 'weapon.cooldown',
      table: EudTable.weapon,
      member: 'Weapon.cooldown',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.frames,
    ),
    EudFieldDefinition(
      key: 'weapon.damageFactor',
      table: EudTable.weapon,
      member: 'Weapon.damageFactor',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'weapon.attackAngle',
      table: EudTable.weapon,
      member: 'Weapon.attackAngle',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'weapon.launchSpin',
      table: EudTable.weapon,
      member: 'Weapon.launchSpin',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'weapon.removeAfter',
      table: EudTable.weapon,
      member: 'Weapon.removeAfter',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'weapon.splashInnerRadius',
      table: EudTable.weapon,
      member: 'Weapon.splashInnerRadius',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.rawDistance,
    ),
    EudFieldDefinition(
      key: 'weapon.splashMiddleRadius',
      table: EudTable.weapon,
      member: 'Weapon.splashMiddleRadius',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.rawDistance,
    ),
    EudFieldDefinition(
      key: 'weapon.splashOuterRadius',
      table: EudTable.weapon,
      member: 'Weapon.splashOuterRadius',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.rawDistance,
    ),
    EudFieldDefinition(
      key: 'weapon.behavior',
      table: EudTable.weapon,
      member: 'Weapon.behavior',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: [
        'Fly_DoNotFollowTarget',
        'Fly_FollowTarget',
        'AppearOnTargetUnit',
        'PersistOnTargetSite',
        'AppearOnTargetSite',
        'AppearOnAttacker',
        'AttackAndSelfDestruct',
        'Bounce',
        'AttackNearbyArea',
        'GoToMaxRange',
      ],
    ),
    EudFieldDefinition(
      key: 'weapon.explosionType',
      table: EudTable.weapon,
      member: 'Weapon.explosionType',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: [
        'None',
        'NormalHit',
        'SplashRadial',
        'SplashEnemy',
        'Lockdown',
        'NuclearMissile',
        'Parasite',
        'Broodlings',
        'EmpShockwave',
        'Irradiate',
        'Ensnare',
        'Plague',
        'StasisField',
        'DarkSwarm',
        'Consume',
        'YamatoGun',
        'Restoration',
        'DisruptionWeb',
        'CorrosiveAcid',
        'MindControl',
        'Feedback',
        'OpticalFlare',
        'Maelstrom',
        'SplashAir',
      ],
    ),
    EudFieldDefinition(
      key: 'weapon.flingy',
      table: EudTable.weapon,
      member: 'Weapon.flingy',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.referenceId,
      maximum: 208,
    ),
    EudFieldDefinition(
      key: 'flingy.topSpeed',
      table: EudTable.flingy,
      member: 'Flingy.topSpeed',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'flingy.acceleration',
      table: EudTable.flingy,
      member: 'Flingy.acceleration',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'flingy.haltDistance',
      table: EudTable.flingy,
      member: 'Flingy.haltDistance',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'flingy.turnSpeed',
      table: EudTable.flingy,
      member: 'Flingy.turnSpeed',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
    ),
    EudFieldDefinition(
      key: 'flingy.movementControl',
      table: EudTable.flingy,
      member: 'Flingy.movementControl',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: ['FlingyDat', 'PartiallyMobile_Weapon', 'IscriptBin'],
    ),
    EudFieldDefinition(
      key: 'flingy.sprite',
      table: EudTable.flingy,
      member: 'Flingy.sprite',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 516,
    ),
    EudFieldDefinition(
      key: 'upgrade.mineralCostBase',
      table: EudTable.upgrade,
      member: 'Upgrade.mineralCostBase',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.mineralCostFactor',
      table: EudTable.upgrade,
      member: 'Upgrade.mineralCostFactor',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.gasCostBase',
      table: EudTable.upgrade,
      member: 'Upgrade.gasCostBase',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.gasCostFactor',
      table: EudTable.upgrade,
      member: 'Upgrade.gasCostFactor',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.timeCostBase',
      table: EudTable.upgrade,
      member: 'Upgrade.timeCostBase',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.timeCostFactor',
      table: EudTable.upgrade,
      member: 'Upgrade.timeCostFactor',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.maxLevel',
      table: EudTable.upgrade,
      member: 'Upgrade.maxLevel',
      type: EudValueType.unsignedInteger,
      bits: 8,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'upgrade.race',
      table: EudTable.upgrade,
      member: 'Upgrade.race',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: ['Zerg', 'Terran', 'Protoss', 'All'],
    ),
    EudFieldDefinition(
      key: 'tech.race',
      table: EudTable.tech,
      member: 'Tech.race',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: ['Zerg', 'Terran', 'Protoss', 'All'],
    ),
    EudFieldDefinition(
      key: 'tech.mineralCost',
      table: EudTable.tech,
      member: 'Tech.mineralCost',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'tech.gasCost',
      table: EudTable.tech,
      member: 'Tech.gasCost',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'tech.timeCost',
      table: EudTable.tech,
      member: 'Tech.timeCost',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'tech.energyCost',
      table: EudTable.tech,
      member: 'Tech.energyCost',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.raw,
      overlapsChk: true,
    ),
    EudFieldDefinition(
      key: 'player.zergControlMax',
      table: EudTable.player,
      member: 'TrgPlayer.zergControlMax',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.supplyHalfPoints,
    ),
    EudFieldDefinition(
      key: 'player.terranSupplyMax',
      table: EudTable.player,
      member: 'TrgPlayer.terranSupplyMax',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.supplyHalfPoints,
    ),
    EudFieldDefinition(
      key: 'player.protossPsiMax',
      table: EudTable.player,
      member: 'TrgPlayer.protossPsiMax',
      type: EudValueType.unsignedInteger,
      bits: 32,
      unit: EudFieldUnit.supplyHalfPoints,
    ),
    EudFieldDefinition(
      key: 'sprite.image',
      table: EudTable.sprite,
      member: 'Sprite.image',
      type: EudValueType.unsignedInteger,
      bits: 16,
      unit: EudFieldUnit.referenceId,
      maximum: 998,
    ),
    EudFieldDefinition(
      key: 'sprite.isVisible',
      table: EudTable.sprite,
      member: 'Sprite.isVisible',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
    ),
    EudFieldDefinition(
      key: 'image.isTurnable',
      table: EudTable.image,
      member: 'Image.isTurnable',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
    ),
    EudFieldDefinition(
      key: 'image.isClickable',
      table: EudTable.image,
      member: 'Image.isClickable',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
    ),
    EudFieldDefinition(
      key: 'image.useFullIscript',
      table: EudTable.image,
      member: 'Image.useFullIscript',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
    ),
    EudFieldDefinition(
      key: 'image.drawIfCloaked',
      table: EudTable.image,
      member: 'Image.drawIfCloaked',
      type: EudValueType.boolean,
      bits: 1,
      unit: EudFieldUnit.flag,
    ),
    EudFieldDefinition(
      key: 'image.drawingFunction',
      table: EudTable.image,
      member: 'Image.drawingFunction',
      type: EudValueType.enumeration,
      bits: 8,
      unit: EudFieldUnit.raw,
      choices: [
        'Normal',
        'NormalNoHallucination',
        'NonVisionCloaking',
        'NonVisionCloaked',
        'NonVisionDecloaking',
        'VisionCloaking',
        'VisionCloaked',
        'VisionDecloaking',
        'EMPShockwave',
        'UseRemapping',
        'Shadow',
        'WarpTexture',
        'SelectionCircle',
        'PlayerColorOverride',
        'HideGFX_ShowSizeRect',
        'Hallucination',
        'WarpFlash',
      ],
    ),
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
