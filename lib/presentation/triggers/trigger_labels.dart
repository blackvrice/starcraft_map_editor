import '../../domain/chk/typed/chk_trigger_editor.dart';
import '../settings/default_unit_names.dart';

/// Display names for trigger opcodes and argument values.
///
/// The domain keeps the stable English names used by the CHK model and tests.
/// These tables only change what the user reads; unknown ids and labels fall
/// back to the domain text so nothing is hidden.
abstract final class TriggerLabels {
  static const _conditionsKo = {
    22: '항상',
    23: '실행 안 함',
    12: '경과 시간',
    1: '카운트다운 타이머',
    2: '유닛 보유',
    3: '지역에 유닛 보유',
    4: '자원 누적',
    11: '스위치',
    5: '처치 수',
    6: '가장 많이 보유',
    7: '지역에서 가장 많이 보유',
    8: '가장 많이 처치',
    9: '최고 점수',
    10: '가장 많은 자원',
    14: '남은 상대 수',
    15: '사망 수',
    16: '가장 적게 보유',
    17: '지역에서 가장 적게 보유',
    18: '가장 적게 처치',
    19: '최저 점수',
    20: '가장 적은 자원',
    21: '점수',
  };

  static const _actionsKo = {
    1: '승리',
    2: '패배',
    3: '트리거 유지',
    4: '대기 (밀리초)',
    5: '게임 일시정지',
    6: '게임 재개',
    7: '교신',
    8: 'WAV 재생',
    9: '문구 표시',
    10: '화면 이동',
    11: '속성 지정 유닛 생성',
    12: '임무 목표 설정',
    13: '스위치 설정',
    14: '카운트다운 설정',
    15: 'AI 스크립트 실행',
    16: '지역에서 AI 스크립트 실행',
    17: '리더보드: 보유',
    18: '리더보드: 지역 보유',
    19: '리더보드: 자원',
    20: '리더보드: 처치',
    21: '리더보드: 점수',
    22: '유닛 죽이기',
    23: '지역의 유닛 죽이기',
    24: '유닛 제거',
    25: '지역의 유닛 제거',
    26: '자원 설정',
    27: '점수 설정',
    28: '미니맵 핑',
    29: '말하는 초상화',
    30: '유닛 음성 끄기',
    31: '유닛 음성 켜기',
    32: '리더보드 컴퓨터 표시',
    33: '리더보드 목표: 보유',
    34: '리더보드 목표: 지역 보유',
    35: '리더보드 목표: 자원',
    36: '리더보드 목표: 처치',
    37: '리더보드 목표: 점수',
    38: '로케이션 이동',
    39: '유닛 이동',
    40: '리더보드: 탐욕',
    41: '다음 시나리오 설정',
    42: '두다드 상태 설정',
    43: '무적 설정',
    44: '유닛 생성',
    45: '사망 수 설정',
    46: '명령',
    47: '주석',
    48: '유닛 넘겨주기',
    49: '체력 변경',
    50: '에너지 변경',
    51: '실드 변경',
    52: '자원량 변경',
    53: '격납 수 변경',
    54: '타이머 일시정지',
    55: '타이머 재개',
    56: '무승부',
    57: '동맹 상태 설정',
  };

  static const _briefingKo = {
    1: '대기',
    2: 'WAV 재생',
    3: '문구 표시',
    4: '임무 목표',
    5: '초상화 표시',
    6: '초상화 숨기기',
    7: '말하는 초상화',
    8: '교신',
    9: '튜토리얼 건너뛰기 허용',
  };

  static const _valuesKo = {
    'Current player': '현재 플레이어',
    'Foes': '적',
    'Allies': '동맹',
    'Neutral players': '중립 플레이어',
    'All players': '모든 플레이어',
    'Non-allied victory players': '비동맹 승리 플레이어',
    'At least': '이상',
    'At most': '이하',
    'Exactly': '정확히',
    'Minerals': '미네랄',
    'Gas': '가스',
    'Minerals and gas': '미네랄과 가스',
    'Total': '전체',
    'Units': '유닛',
    'Buildings': '건물',
    'Units and buildings': '유닛과 건물',
    'Kills': '처치',
    'Razings': '파괴',
    'Kills and razings': '처치와 파괴',
    'Custom': '사용자 지정',
    'Set': '켜짐',
    'Cleared': '꺼짐',
    'Clear': '끄기',
    'Toggle': '전환',
    'Randomize': '무작위',
    'Set to': '로 설정',
    'Add': '더하기',
    'Subtract': '빼기',
    'Enable': '켜기',
    'Disable': '끄기',
    'Any unit': '모든 유닛',
    'Men': '병력',
    'Factories': '생산 건물',
  };

  static bool _korean(String localeName) => localeName.startsWith('ko');

  /// The opcode name for [localeName], falling back to the domain name.
  static String opcodeName(
    String localeName,
    TriggerOpcode opcode, {
    required bool action,
    required bool briefing,
  }) {
    if (!_korean(localeName)) return opcode.name;
    final table = briefing
        ? _briefingKo
        : action
        ? _actionsKo
        : _conditionsKo;
    return table[opcode.id] ?? opcode.name;
  }

  /// A player, force or group name such as “Player 2” or “All players”.
  static String value(String localeName, String english) {
    if (!_korean(localeName)) return english;
    final player = RegExp(r'^Player (\d+)$').firstMatch(english);
    if (player != null) return '플레이어 ${player.group(1)}';
    final force = RegExp(r'^Force (\d+)$').firstMatch(english);
    if (force != null) return '세력 ${force.group(1)}';
    return _valuesKo[english] ?? english;
  }

  /// One readable line for a trigger slot: its name followed by the values
  /// that matter, e.g. “Deaths · Current player · At least · 10 · Marine”.
  static String slotSentence(
    String localeName,
    List<int> slot, {
    required bool action,
    required bool briefing,
  }) {
    final id = ChkTrigger.type(action, slot);
    final opcode = TriggerOpcodes.find(action, id, briefing: briefing);
    if (opcode == null) return 'Raw #$id';
    final name = opcodeName(
      localeName,
      opcode,
      action: action,
      briefing: briefing,
    );
    if (!ChkTrigger.editable(action, slot, briefing: briefing)) return name;
    final parts = <String>[name];
    for (final argument in opcode.arguments) {
      final raw = ChkTrigger.argument(slot, argument);
      parts.add(_argumentText(localeName, argument, raw));
    }
    return parts.join(' · ');
  }

  static String _argumentText(
    String localeName,
    TriggerArgument argument,
    int raw,
  ) {
    if (argument.choices[raw] case final label?) {
      return value(localeName, label);
    }
    final reference = argument.reference;
    const groups = {
      229: 'Any unit',
      230: 'Men',
      231: 'Buildings',
      232: 'Factories',
    };
    if (reference == 'unitGroup' && groups[raw] != null) {
      return value(localeName, groups[raw]!);
    }
    if ((reference == 'unit' || reference == 'unitGroup') &&
        raw >= 0 &&
        raw < defaultUnitNames.length) {
      return defaultUnitNames[raw];
    }
    return switch (reference) {
      'location' => _korean(localeName) ? '로케이션 $raw' : 'Location $raw',
      'switch' => _korean(localeName) ? '스위치 #$raw' : 'Switch #$raw',
      'string' => _korean(localeName) ? '문자열 #$raw' : 'String #$raw',
      _ => '$raw',
    };
  }
}
