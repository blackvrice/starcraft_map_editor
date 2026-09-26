# 일반 트리거 편집기 — 첫 구현

2026-09-27 사용자 우선순위에 따라 M7을 먼저 진행했다. EUD 게임 관찰 중
미확인 항목은 검증 완료로 바꾸지 않는다.

## 사용 방법

맵을 열고 **Triggers** 탭을 선택한다. 탭이 화면 밖이면 탭 표시줄을 가로로
스크롤한다. Add trigger로 만든 레코드는 Player 1 / Never 조건으로 시작한다.
실행하려면 Never를 제거하고 필요한 조건을 추가한다. 레코드를 누르면 실행
플레이어(P1~P8), 조건 16개와 액션 64개 슬롯을 편집할 수 있다.

슬롯의 Use slot은 초안만 바꾼다. **Apply to map**으로 적용하고 **Save As**로
저장한다. Cancel은 초안을 버린다. 추가·복제·삭제·레코드 순서 변경과 적용은
기존 맵 Undo/Redo를 공유한다. 편집 중 맵이 변경되면 오래된 초안 적용을 거부한다.
일반 TRIG 변경에는 euddraft 빌드가 필요하지 않다. 선언적 EUD 설정을 게임에
반영하는 과정은 기존 EUD 빌드 흐름을 따른다.

## 지원 범위

| 구분 | 편집 가능한 유형(ID) |
| --- | --- |
| 조건 8종 | Always(22), Never(23), Elapsed Time(12), Countdown Timer(1), Command(2), Bring(3), Accumulate(4), Switch(11) |
| 액션 12종 | Victory(1), Defeat(2), Preserve Trigger(3), Wait(4), Display Text(9), Center View(10), Set Switch(13), Kill Unit(22), Remove Unit(24), Set Resources(26), Create Unit(44), Comment(47) |

유닛은 기본 이름과 ID로 선택한다. 로케이션과 문자열은 기존 ID를 입력하며
사용 가능한 단일 테이블의 범위를 검사한다. 문자열을 새로 만들거나 자원 삭제의
사용처를 추적하는 기능은 아직 없다. 스위치 인덱스는 0~255다.
수치 폭, 비교 연산, 자원 종류와 수정 연산을 적용 전에 검사한다.

## 보존과 경계

- 단일 TRIG의 2400바이트 레코드만 편집한다. 누락·중복·잘린 TRIG는 자동으로
  생성·병합·복구하지 않고 편집을 차단한다.
- 지원하지 않는 opcode와 EUDX 표식이 있는 슬롯은 읽기 전용이다. 알려진
  슬롯을 바꿀 때도 인자 외의 바이트, 플래그, 패딩, 다른 소유자 바이트는 보존한다.
- 슬롯 제거는 선택한 슬롯만 비우고 다른 슬롯의 번호를 유지한다. 레코드 전체
  삭제는 미지원 슬롯도 삭제한다는 확인 창을 거치며 Undo로 원상 복구한다.
- 원시 레코드는 읽기 전용 16진수로 확인한다. EUD 컴파일 결과를 일반 트리거로
  역변환하거나 생성된 코드의 의미를 추정하지 않는다.
- 기존의 잘못된 참조를 일괄 수정하지 않는다. 현재 편집하는 슬롯의 참조만
  검사하며 전체 맵 참조 무결성 검증 완료를 뜻하지 않는다.

레이아웃과 opcode는 eudplib 0.80.6 공식 소스의 rawtrigger
[condition.py](https://github.com/armoha/eudplib/blob/e04ac54dccbdcda94512214c4730b46f7f13d74f/src/eudplib/core/rawtrigger/condition.py),
[action.py](https://github.com/armoha/eudplib/blob/e04ac54dccbdcda94512214c4730b46f7f13d74f/src/eudplib/core/rawtrigger/action.py),
stockcond.py / stockact.py를 대조했다.

## 검증과 후속 작업

바이너리 배치, 원시 바이트 보존, 잘못된 참조·EUDX 편집 차단, 초안 취소,
Undo/Redo, 탭 전환 및 실제 native MPQ Save As → 재열기 테스트를 추가했다.
게임에서 새 일반 트리거를 실행하는 확인은 별도로 남아 있다.

검증 환경은 Flutter 3.47.2 / Dart 3.13.2로 저장소 기준 3.44.8 / 3.12와
다르다. flutter analyze 통과, 전체 테스트 726개 통과·26개 환경 조건부 skip,
native MPQ 포함 왕복 테스트 3개 통과, Windows debug 빌드·프로세스 시작을 확인했다.
이번 변경 파일의 format 검사는 통과했다. 전체 format 검사는 기존의
local_map_save_file_gateway_test.dart, process_eud_compiler_gateway_test.dart,
process_map_archive_gateway_test.dart, process_starcraft_data_asset_inspector_test.dart
4개 파일의 서식 차이로 실패했으며 이 파일들은 변경하지 않았다.

다음 범위는 나머지 기본 조건·액션, 슬롯 순서 변경·활성/비활성, 일괄 소유자,
문자열·사운드 사용처, UPRP 속성 슬롯과 미션 브리핑(MBRF)이다.
기본 트리거 전체 지원이나 M7 완료를 의미하지 않는다.
