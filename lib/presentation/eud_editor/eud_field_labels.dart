/// Readable names for EUD field keys such as `unit.maxShield`.
///
/// The key stays the stable identifier in project files, previews and tests.
/// These names are only what the user reads next to it; unknown keys fall
/// back to a spaced version of the member name so nothing is hidden.
abstract final class EudFieldLabels {
  static const _labels = <String, (String, String)>{
    'unit.groundWeapon': ('Ground weapon', '지상 무기'),
    'unit.airWeapon': ('Air weapon', '공중 무기'),
    'unit.flingy': ('Movement data', '이동 데이터'),
    'unit.seekRange': ('Target acquisition range', '적 탐지 범위'),
    'unit.sightRange': ('Sight range', '시야'),
    'unit.sizeType': ('Unit size', '유닛 크기'),
    'unit.baseProperty': ('Base properties', '기본 속성'),
    'unit.portrait': ('Portrait', '초상화'),
    'unit.readySound': ('Ready sound', '준비 음성'),
    'unit.whatSoundStart': ('Select sounds (first)', '선택 음성 (처음)'),
    'unit.whatSoundEnd': ('Select sounds (last)', '선택 음성 (마지막)'),
    'unit.pissedSoundStart': ('Annoyed sounds (first)', '짜증 음성 (처음)'),
    'unit.pissedSoundEnd': ('Annoyed sounds (last)', '짜증 음성 (마지막)'),
    'unit.yesSoundStart': ('Order sounds (first)', '명령 음성 (처음)'),
    'unit.yesSoundEnd': ('Order sounds (last)', '명령 음성 (마지막)'),
    'unit.hasShield': ('Has shields', '실드 사용'),
    'unit.maxShield': ('Maximum shields', '최대 실드'),
    'weapon.attackAngle': ('Attack angle', '공격 각도'),
    'weapon.behavior': ('Projectile behavior', '발사체 방식'),
    'weapon.cooldown': ('Cooldown', '공격 속도 (쿨다운)'),
    'weapon.damageFactor': ('Damage factor', '피해 배수'),
    'weapon.damageType': ('Damage type', '피해 유형'),
    'weapon.explosionType': ('Explosion type', '폭발 방식'),
    'weapon.flingy': ('Projectile movement', '발사체 이동'),
    'weapon.launchSpin': ('Launch spin', '발사 회전'),
    'weapon.maxRange': ('Maximum range', '최대 사거리'),
    'weapon.minRange': ('Minimum range', '최소 사거리'),
    'weapon.removeAfter': ('Projectile lifetime', '발사체 유지 시간'),
    'weapon.splashInnerRadius': ('Splash radius (inner)', '스플래시 반경 (안쪽)'),
    'weapon.splashMiddleRadius': ('Splash radius (middle)', '스플래시 반경 (중간)'),
    'weapon.splashOuterRadius': ('Splash radius (outer)', '스플래시 반경 (바깥)'),
    'weapon.targetFlags': ('Allowed targets', '공격 가능 대상'),
    'flingy.acceleration': ('Acceleration', '가속도'),
    'flingy.haltDistance': ('Stopping distance', '정지 거리'),
    'flingy.movementControl': ('Movement control', '이동 제어 방식'),
    'flingy.sprite': ('Sprite', '스프라이트'),
    'flingy.topSpeed': ('Top speed', '최고 속도'),
    'flingy.turnSpeed': ('Turn speed', '회전 속도'),
    'image.drawIfCloaked': ('Draw while cloaked', '클로킹 중에도 그리기'),
    'image.drawingFunction': ('Drawing function', '그리기 방식'),
    'image.isClickable': ('Clickable', '클릭 가능'),
    'image.isTurnable': ('Turnable', '방향 회전'),
    'image.useFullIscript': ('Full animation script', '전체 애니메이션 스크립트'),
    'player.protossPsiMax': ('Protoss psi limit', '프로토스 인구 한도'),
    'player.terranSupplyMax': ('Terran supply limit', '테란 인구 한도'),
    'player.zergControlMax': ('Zerg control limit', '저그 인구 한도'),
    'sprite.image': ('Image', '이미지'),
    'sprite.isVisible': ('Visible', '보이기'),
    'tech.energyCost': ('Energy cost', '에너지 비용'),
    'tech.gasCost': ('Gas cost', '가스 비용'),
    'tech.mineralCost': ('Mineral cost', '미네랄 비용'),
    'tech.race': ('Race', '종족'),
    'tech.timeCost': ('Research time', '연구 시간'),
    'upgrade.gasCostBase': ('Gas cost', '가스 비용'),
    'upgrade.gasCostFactor': ('Gas cost per level', '레벨당 가스 증가'),
    'upgrade.maxLevel': ('Maximum level', '최대 레벨'),
    'upgrade.mineralCostBase': ('Mineral cost', '미네랄 비용'),
    'upgrade.mineralCostFactor': ('Mineral cost per level', '레벨당 미네랄 증가'),
    'upgrade.race': ('Race', '종족'),
    'upgrade.timeCostBase': ('Research time', '연구 시간'),
    'upgrade.timeCostFactor': ('Research time per level', '레벨당 연구 시간 증가'),
  };

  static const _groupsKo = {
    'unit': '유닛',
    'weapon': '무기',
    'flingy': '이동',
    'image': '이미지',
    'player': '플레이어',
    'sprite': '스프라이트',
    'tech': '테크',
    'upgrade': '업그레이드',
  };

  /// The readable name of [key] for [localeName].
  static String label(String localeName, String key) {
    final entry = _labels[key];
    if (entry != null) return localeName.startsWith('ko') ? entry.$2 : entry.$1;
    final member = key.contains('.') ? key.split('.').last : key;
    final spaced = member.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match[1]} ${match[2]!.toLowerCase()}',
    );
    return spaced.isEmpty
        ? key
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  /// The readable group of [key], e.g. “Unit” / “유닛”.
  static String group(String localeName, String key) {
    final table = key.split('.').first;
    if (localeName.startsWith('ko')) return _groupsKo[table] ?? table;
    return table.isEmpty
        ? key
        : '${table[0].toUpperCase()}${table.substring(1)}';
  }
}
