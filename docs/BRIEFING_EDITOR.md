# 미션 브리핑 편집기

2026-09-28 M7의 미션 브리핑 구조 편집을 구현했다. 맵을 열고 상단 **Briefing**
탭을 선택한다. 탭이 가려지면 문서 탭을 가로 스크롤한다. 일반 게임 중 트리거는
**Triggers**, 문자열·음원 파일은 **Resources**에서 관리한다.

## 사용 순서

1. **Add briefing**으로 Player 1 대상의 빈 브리핑을 추가한다.
2. 레코드를 열고 플레이어/세력 소유자를 선택한다. 여러 레코드는 체크 후
   **Owners…**로 Add/Remove/Unchanged를 적용한다.
3. Actions의 **Add**에서 아래 9개 유형을 고르고 **Use slot**으로 초안에 넣는다.
   초상화는 유닛 이름/ID와 화면 슬롯 1~4를 선택한다. 시간은 밀리초다.
4. **Add text…**로 문자열을 추가하고 표시된 ID를 사용한다. 문자열 ID 입력 아래에
   본문 또는 음원 경로가 표시된다. 음원은 Resources에서 가져온 뒤 해당 문자열
   ID를 Sound string ID에 입력한다. Play WAV/Transmission의 Duration은 직접
   입력하는 저장 시간이며 오디오 길이 자동 계산은 후속 기능이다.
5. **Apply to map**으로 문서에 적용하고 **Save As**로 저장한다. 일반 브리핑은
   euddraft 빌드 없이 저장된다. EUD 변경은 기존 별도 빌드 흐름을 따른다.

레코드와 액션의 복제·삭제·위/아래 이동, 활성/비활성, 초안 취소, 문서 Undo/Redo를
지원한다. 레코드 전체 삭제는 원시 슬롯까지 삭제됨을 확인한다. 초안을 연 뒤
문서가 달라지면 적용을 거부한다. 일반 트리거와 브리핑은 같은 Undo 이력을 쓴다.

## 액션 지원표

| MBRF 유형 | 편집 항목 |
| --- | --- |
| 1 Wait | 대기 시간 |
| 2 Play WAV | 사운드 문자열 ID·시간 |
| 3 Text message | 텍스트 문자열 ID·표시 시간 |
| 4 Mission objectives | 목표 텍스트 문자열 ID |
| 5 Show portrait | 유닛·초상화 슬롯 |
| 6 Hide portrait | 초상화 슬롯 |
| 7 Speaking portrait | 초상화 슬롯·말하는 시간 |
| 8 Transmission | 텍스트·슬롯·사운드·시간·Set/Add/Subtract 시간 조정 |
| 9 Skip tutorial enabled | 인자 없음 |

MBRF와 TRIG는 같은 숫자라도 액션 의미가 다르다. 별도 opcode 목록과 레코드의
briefing 모드로 해석하며 Application은 다른 모드의 레코드를 섞는 것을 거부한다.
모델과 초안 UI는 공통 구조를 재사용한다.

## 바이트 보존과 저장

- 단일 MBRF의 2400바이트 레코드, 액션 64개를 지원한다. 새 레코드는 첫 조건의
  유형 13(Mission Briefing)과 Player 1 소유자를 설정한다. 기존 조건 영역은
  구조 편집하지 않고 원시 바이트로 보존한다.
- MBRF가 없을 때 첫 명시적 추가는 새 섹션을 문서 끝에 붙인다. Undo는 그 섹션까지
  제거한다. 중복·잘린 MBRF는 편집을 막으며 합치거나 자동 복구하지 않는다.
- 같은 액션 유형 편집은 인자 밖 바이트와 플래그를 보존한다. 유형 변경은 선택한
  슬롯만 새로 만든다. 미지원 유형·EUDX 슬롯은 읽기 전용이며 원시 레코드 뷰로 확인한다.
- 기존 TRIG 및 다른 CHK 섹션은 브리핑 편집으로 바꾸지 않는다.
- 문자열/음원 참조는 [리소스 사용처 모델](RESOURCE_MANAGEMENT.md)에 연결된다.
  사용 중인 리소스 삭제를 막고, 편집한 MBRF의 잘못된 인자·문자열 ID는 Save As의
  아카이브 쓰기 전에 차단한다. **Validate references**로 위치를 확인할 수 있다.
- Save As는 기존 임시 출력·재열기·원본 지문 검사·최종 승격 절차를 따른다.

## 검증과 실제 게임 확인

9종 액션의 필드 offset·폭·초기 플래그를 독립 CHK 기준 값과 비교한다.
손상/중복 섹션, 범위 밖 슬롯·시간·참조, TRIG/MBRF 분리, 원시 바이트 보존,
초안 취소·Undo/Redo와 별도 탭 연결을 자동 테스트한다. 자체 제작 맵의 실제 MPQ
Save As 왕복에서 브리핑과 원시 레코드, 기존 TRIG 및 원본 보존을 확인한다.

레이아웃 근거는 [Chkdraft의 briefingTextArguments 및 briefingDefaultFlags](https://github.com/TheNitesWhoSay/Chkdraft/blob/master/src/mapping_core/chk.cpp)와
[Action/Condition 구조](https://github.com/TheNitesWhoSay/Chkdraft/blob/master/src/mapping_core/chk.h)다.

실제 SC:R 관찰은 별도다. Player 1 브리핑에 Show portrait → Text message →
Play WAV/Transmission → Wait → Hide portrait를 넣고 Save As한 맵에서 텍스트,
초상화 슬롯, 소리, 표시 시간·순서를 확인한다. 다른 플레이어/세력에 배정한 레코드도
해당 플레이어로 확인한다. 이 관찰 전에는 M7의 실제 게임 검증을 완료 처리하지 않는다.
