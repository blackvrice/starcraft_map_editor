# 일반 트리거 편집기

2026-09-27 일반 조건 22종과 액션 57종의 구조 편집을 구현했다. M7의 미션
브리핑, M6.5의 사운드 파일 관리, M7.1의 EUD 실행 규칙은 별도 개발 범위다.

## 사용 순서

1. 맵을 열고 **Triggers** 탭을 선택한다. 탭이 안 보이면 가로 스크롤한다.
2. **Add trigger**는 Player 1 / Never로 시작한다. 레코드를 열고 Never를
   클릭하여 Always 또는 필요한 조건으로 변경한다.
3. 조건·액션을 추가하고 **Use slot → Apply to map → Save As**로 저장한다.
   일반 트리거에는 euddraft 빌드가 필요 없다. EUD 설정 반영에는 기존 빌드가 필요하다.
4. 체크박스로 여러 트리거를 선택하고 **Owners…**, **Enable/Disable selected**를
   사용한다. 소유자는 Unchanged/Add/Remove로 지정하여 다른 소유자를 보존한다.
5. **Validate references**에서 알려진 슬롯의 수치·참조 오류를 확인한다.
   수정된 TRIG의 오류가 남으면 Save As는 아카이브 쓰기 전에 차단한다.

레코드·슬롯 복제, 레코드·슬롯 순서 변경, 조건·액션·레코드 활성/비활성과
P1~P12/All Players/Force 1~4 소유자를 지원한다. 선택은 맵 변경 시 초기화한다.
슬롯 유형 변경은 해당 슬롯의 인자를 새로 만든다. 같은 유형 편집은 인자 외
플래그·패딩을 보존한다. Display Text/Transmission의 Always display도 편집한다.
초안 취소·오래된 초안 거부, 문서 Undo/Redo를 지원한다.

## 일반 opcode 지원표

| 조건 ID | 유형 |
| --- | --- |
| 1–5 | Countdown Timer, Command, Bring, Accumulate, Kills |
| 6–10 | Command Most, Command Most At, Most Kills, Highest Score, Most Resources |
| 11–12 | Switch, Elapsed Time |
| 14–18 | Opponents, Deaths, Command Least, Command Least At, Least Kills |
| 19–23 | Lowest Score, Least Resources, Score, Always, Never |

| 액션 ID | 유형 |
| --- | --- |
| 1–6 | Victory, Defeat, Preserve Trigger, Wait, Pause Game, Unpause Game |
| 7–12 | Transmission, Play WAV, Display Text, Center View, Create Unit with Properties, Set Mission Objectives |
| 13–16 | Set Switch, Set Countdown Timer, Run AI Script, Run AI Script At |
| 17–21 | Leaderboard Control, Control At, Resources, Kills, Score |
| 22–29 | Kill Unit, Kill Unit At, Remove Unit, Remove Unit At, Set Resources, Set Score, Minimap Ping, Talking Portrait |
| 30–37 | Mute/Unmute Unit Speech, Leaderboard Computer Players, Leaderboard Goal Control/Control At/Resources/Kills/Score |
| 38–44 | Move Location, Move Unit, Leaderboard Greed, Set Next Scenario, Set Doodad State, Set Invincibility, Create Unit |
| 45–51 | Set Deaths, Order, Comment, Give Units, Modify Hitpoints/Energy/Shields |
| 52–57 | Modify Resources, Modify Hangar Count, Pause Timer, Unpause Timer, Draw, Set Alliance Status |

조건 0/액션 0은 빈 슬롯, 조건 13은 브리핑 전용이며 일반 목록에서 제외한다.
비일반·확장 opcode는 읽기 전용이다. Deaths/Set Deaths의 범위 밖 플레이어·유닛,
EUDX 표식은 일반 인자로 재해석하지 않는다. 인자용 플레이어 그룹과 소유자는 구분한다.
유닛 이름·숫자 ID, 해당 액션의 Any Unit/Men/Buildings/Factories, 점수·자원·명령·
동맹·비교·수정 연산을 선택한다. AI 스크립트는 4문자 ASCII ID를 입력한다.
ID 형식 검사는 게임 설치에 해당 스크립트가 존재하거나 해당 상황에서 작동함을 보증하지 않는다.

## 문자열·스위치·유닛 속성

- **Add text…**에서 새 문자열과 할당 ID를 준비하고 적용한다. 그 ID를 액션에서
  입력하면 텍스트를 확인할 수 있다. 기존 문자열·공유 참조는 덮어쓰지 않는다.
- **Switch names…**는 0~255 스위치의 이름을 새 문자열로 연결한다. 빈 이름은
  기본 이름으로 복원한다. STR/STRx는 안전하게 추가 가능한 단일 테이블이 필요하다.
- **Unit properties…**는 UPRP 1~64 슬롯의 HP/실드/에너지 비율, 자원·행거 수량,
  클로킹·버로우·공중·환상·무적의 상속/활성/비활성을 편집한다. 참조 액션 수를
  표시하며 공유 슬롯 수정은 모든 사용처에 적용된다. 다른 슬롯·예약 바이트와
  비활성 인자의 기존 값을 보존하고 UPUS 사용 표시에 연결한다.
- 필요한 SWNM/UPRP/UPUS가 없으면 명시적 리소스 적용에서 뒤에 추가한다.
  추가 섹션과 문자열 변경을 한 Undo 명령으로 되돌린다. 중복·잘린 테이블은 거부한다.
- 사운드 액션은 기존 문자열 ID를 사용한다. MPQ 사운드 가져오기/삭제/미리듣기,
  전체 문자열 사용처·삭제 관리와 WAV 파일 존재 검사는 M6.5 범위다.

## 데이터 보존·검증 경계

단일 TRIG의 2400바이트 레코드(조건 16개/액션 64개)만 구조 편집한다. 누락·중복·
잘린 TRIG는 자동 복구하지 않는다. 원시 레코드는 읽기 전용 16진수로 확인한다.
슬롯 삭제는 그 슬롯만 비우며, 이동은 명시적으로 선택한 슬롯을 교환한다.
전체 레코드 삭제는 미지원 데이터까지 삭제함을 확인하며 Undo로 복원한다.

알려진 슬롯의 수치·enum·문자열·로케이션·속성 슬롯 범위를 검사한다. 수정하지
않은 TRIG를 임의로 정규화하지 않는다. Raw/EUD 슬롯의 의미·전체 게임 동작은
검증하지 않는다. 새 동작의 실제 SC:R 실행과 멀티플레이는 별도 관찰이 필요하다.

## 자동 검증 근거

독립 기준 데이터 `test/fixtures/trigger_opcode_layouts.json`은 로컬 eudplib 0.80.6
sdist의 stockcond.py/stockact.py에서 일반 생성자 숫자 필드를 대조하여 작성한
자체 테스트 입력이다. 22개 조건·57개 액션의 전체 바이트 배치를 비교한다.
원본 패키지 SHA-256: `5be90f655d29198ef9ab6b4f59c51b1fad62b504752fcf51c1c05461fab71da2`.
속성 필드는 같은 패키지의 unitprp.py, 활성 비트는 Chkdraft chk.h와 대조했다.

공식 소스: [eudplib](https://github.com/armoha/eudplib/tree/e04ac54dccbdcda94512214c4730b46f7f13d74f/src/eudplib/core),
[Chkdraft](https://github.com/TheNitesWhoSay/Chkdraft/blob/master/src/mapping_core/chk.h).
참고 코드를 게임 실행 증거로 대신하지 않는다.

검증 환경은 Flutter 3.47.2 / Dart 3.13.2로 저장소 기준 3.44.8 / 3.12와 다르다.
검증 결과는 아래 완료 기록에 남긴다.

완료 기록: flutter analyze 통과, 전체 735개 테스트 통과·23개 환경 조건부 skip,
native MPQ 포함 왕복 테스트 3개 통과, Windows debug 빌드·프로세스 시작 확인.
전체 테스트의 첫 실행은 선택 스모크용 맵 경로가 상대 경로라 실패했으며,
MAP_ARCHIVE_TEST_MAP을 자체 제작 맵의 절대 경로로 설정해 재실행·통과했다.
작업 대상 파일 format 검사는 통과했다. 저장소 전체 format 검사 명령은 자동 승인
검토가 기존 사용자 파일 덮어쓰기 위험을 이유로 거부하여 이번 실행에서는 미실행이다.
이전에 알려진 다른 테스트 파일 4개의 서식 차이는 수정하지 않았다.
