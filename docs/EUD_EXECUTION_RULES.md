# EUD 실행 규칙

2026-09-28: 기본 자원 규칙과 확장 규칙의 편집·저장·코드 생성·실제 컴파일을 제공한다.
실제 게임·성능·멀티플레이 인수 검증은 남아 있다. 지원 경계와 조사 항목의
보류 결정은 [런타임 지원 결정](research/EUD_RUNTIME_SUPPORT.md)을 따른다.

## 확장 규칙 사용

Triggers → **EUD extensions** 또는 Settings → **EUD execution rules**에서 진입한다.
프로젝트가 없다면 EUD Project에서 기준 맵에 연결한 프로젝트를 먼저 만든다.
Add execution rule → **Extended execution rule**을 켜서 다음을 설정한다.

- 조건 좌변/우변과 기존 Comparison, Action value를 지정한다.
- 값은 상수, 동기화 변수 0~15, 플레이어 자원, 업그레이드/연구 읽기 중 선택한다.
  식은 `source × factor + offset`이다. 읽은 값과 최종 결과는 0~65535로 제한하고
  중간 곱셈은 255배, offset은 -65535~65535로 제한해 언더플로/오버플로를 피한다.
  16개 변수는 게임 시작 시 0이며 사용자 코드 문자열이나 로컬 상태를 값으로 받지 않는다.
- action은 variable/minerals/gas/upgrade/technology/location/unitHp/unitShields/
  unitEnergy/followUnit/text/sound 중 선택한다. 자원 외 액션은 값을 설정한다.
- 위치는 x/y/width/height 식을 각각 입력하고 맵 픽셀 범위 안으로 제한한다.
  followUnit은 추적 개체 중심을 점 로케이션에 반영한다.
- Unit type과 Player는 단일 개체를 최초 바인딩할 때 사용한다. 첫 실행 조건을
  만족하는 살아 있는 개체 한 개만 바인딩하며 종류 전체 DAT를 수정하지 않는다.
  바인딩 후 선택 훅마다 슬롯·세대·종류·소유자·생존 상태를 확인한다. 사라지거나
  변경이 관찰되면 무효화하고 다른 개체로 교체하지 않는다. 게임 재시작으로 초기화한다.
- text는 접두어와 계산한 값을 선택한 로컬 플레이어에게 표시한다. sound는 Resources의
  WAV 등록 문자열 ID를 사용한다. 공유 게임 상태 조건·변수·1회 플래그는 로컬 분기 밖에서
  처리하며 표시 중 변경한 CurrentPlayer를 복원한다.
- beforeTriggers: 생성 규칙 → 사용자 beforeTriggerExec → 일반 트리거.
  afterTriggers: 일반 트리거 → 사용자 afterTriggerExec → 생성 규칙.
  같은 훅의 목록 순서는 위/아래 버튼으로 바꾸며 Undo/Redo가 가능하다.

활성 규칙 간 중복 쓰기, 변수 순환 및 자원/업그레이드/연구를 포함한 순환 의존성을
거부한다. 자기 자원 조건은 허용하지만 자기 변수 참조는 거부한다. 사용자 코드나
일반 TRIG까지 분석하지 않는다. 총 64개 규칙/개체 스캔 규칙 4개, 주기 최소 12회다.
개체 규칙의 생존 감시는 주기와 무관하게 매 선택 훅에서 최대 1700 슬롯을 스캔하므로
실제 게임 성능 검증이 필요하다.

확장 규칙은 schema v3이다. v1/v2 프로젝트는 계속 읽고 기본 규칙 표현을 유지한다.
v2에 확장 필드를 넣거나 알 수 없는 필드·타입을 넣으면 거부한다. 맵 재연결/override
편집은 v3 규칙도 보존한다. 소리/로케이션 참조는 빌드 준비 때 실제 맵에서 검증하고
생성 플러그인에서도 등록/범위를 확인한다.

## 기본 자원 규칙 (기존 v2)

### 사용 방법

1. 저장한 기준 맵으로 EUD Project를 만들거나 기존 프로젝트를 연다.
2. **EUD execution rules → Add execution rule**에서 플레이어, 자원,
   비교 조건/기준량, 변경 방식/수량과 실행 방식을 선택한다.
3. Apply rule은 프로젝트에 적용한다. Cancel은 초안을 버린다.
   수정·삭제는 목록 버튼으로, 되돌리기는 Undo project/Redo project로 한다.
4. Save Project 또는 Save Project As로 규칙을 보존한다.
5. Generation preview에서 규칙과 생성 순서를 확인한다. Prepare EUD Build의
   프로젝트 설정 테스트 빌드를 선택한다. 소스 없이 설정/규칙만 빌드할 수도 있다.
   Map Save As는 규칙을 컴파일하지 않는다.

예: Player 1 / Minerals / atMost 100 / add 50 / Once는 자원이 100 이하가
되는 첫 검사 때 50을 추가한다. Periodic / 24는 24번째 처리부터 매 24회에
한 번 검사한다. 게임 속도나 초 단위로 환산한 값이 아니다.

## 지원 계약

- 동기화된 게임 상태만 읽고 쓴다. 대상은 명시적 Player 1~8이며
  CurrentPlayer/LocalPlayer, 메모리 주소나 사용자 코드 식은 받지 않는다.
- 조건과 액션은 같은 플레이어의 같은 자원(Minerals 또는 Gas)을 대상으로 한다.
  비교는 atLeast/atMost/exactly, 변경은 setTo/add/subtract다.
- 수량은 정수 상수 0~2147483647이다. 엔진 자원 액션의 동작을 사용하며
  에디터가 누적 결과의 범위나 게임 경제 정책을 보장하지 않는다.
- Once는 매 처리 때 조건을 확인하다 첫 실행 후 내부 플래그로 막는다.
  Periodic은 내부 카운터를 증가시키며 주기에 도달하면 0으로 초기화한 뒤
  조건을 검사한다. 조건이 거짓이어도 다음 주기까지 기다린다.
- 최대 64개 규칙, 주기 12~86400회. 활성 규칙 중 동일 플레이어/자원 쓰기는
  거부한다. 비활성 규칙은 저장하되 코드와 상태 변수를 생성하지 않는다.
  중복 제한은 사용자 코드·일반 TRIG의 쓰기까지 분석하는 기능은 아니다.
- 규칙 목록 순서를 보존한다. 한 초안을 적용하는 동안 프로젝트가 교체되거나
  다른 변경이 생기면 덮어쓰지 않고 초안을 다시 열도록 안내한다.

## 저장과 생성

규칙이 없으면 schema v1, 기본 자원 규칙만 있으면 v2, 확장 규칙이 하나라도
있으면 v3로 저장한다. 현행 앱은 v1/v2/v3를 읽으며 마지막 규칙을 삭제하면
v1으로 저장한다. 구버전 앱이 이해하지 못하는 schema는 거부한다. 알 수 없는 규칙 키/enum, 잘못된 타입,
중복 ID와 상한 초과는 거부한다. 기존 override 편집과 맵 재연결은 규칙을 보존한다.

생성기는 기본 `Accumulate` 조건과 `SetResources` 액션을 사용한다. 실행 상태와
주기만 내부 `EUDVariable`로 관리한다. 이름/ID를 Python 소스로 삽입하지 않는다.
순서는 생성 onPluginStart → 사용자 onPluginStart, 매 처리 시 생성
beforeTriggerExec → 사용자 beforeTriggerExec → 일반 트리거다.
이 순서는 [euddraft v0.10.2.5 applyeuddraft.py](https://github.com/armoha/euddraft/blob/v0.10.2.5/applyeuddraft.py)의
createPayloadMain과 [pluginLoader.py](https://github.com/armoha/euddraft/blob/v0.10.2.5/pluginLoader.py)의
설정 등록 순서에 근거한다. 액션 인수는 고정 eudplib 0.80.6 소스의
`core/rawtrigger/stockcond.py` 및 `stockact.py`에서 확인했다.

기존 맵 바인딩·해시 검증, 사용자 코드 신뢰 확인, 임시 빌드·출력 재열기·새 경로
승격을 그대로 사용한다. 규칙만 있는 프로젝트도 이 게이트를 생략하지 않는다.

## 검증과 남은 범위

모델/JSON 경계, 중복 쓰기, 코드 생성, 폼 적용·취소·진단, 저장·재열기·Undo/Redo,
재연결 보존, 규칙 전용 빌드 준비와 준비 이후 수정 감지를 자동 테스트한다.
동봉 euddraft 0.10.2.5에서 Once/Periodic 규칙을 실제 컴파일하고 출력 맵 재열기,
입력 맵/사용자 소스 보존, 설정 전용 빌드와 바인딩 불일치 차단을 확인했다.
이 검증은 실제 SC:R 자원 변화나 멀티플레이 검증을 대체하지 않는다.

확장 규칙은 위 지원 범위를 구현했다. 원시 버튼셋/요구 조건/Order/IScript,
지형·안개·두다드 런타임 변경은 조사 후 보류했으며 임의 메모리 쓰기를 노출하지 않는다.
영구 개체 ID, 모든 엔진 이벤트 이력, 무제한 식/스크립트 언어는 지원하지 않는다.

게임 확인: Once가 첫 조건 일치 때만 적용되는지, Periodic의 조건 거짓/참 전환과
간격, 두 플레이어의 자원 독립성, 비활성 규칙, 일반 트리거와의 실행 순서,
두 클라이언트 멀티플레이 동기화를 자체 제작 맵에서 확인해야 한다.

## 일반 TRIG 쓰기 대상 비교 (2026-10-01)

자원·위치·HP/Energy/Shields 일반 액션과 실행 규칙의 쓰기 대상 및 고정 EUD 메모리를 비교한다. 실제 조건·그룹·hook 실행의 안전 증명은 아니며 미확인 코드 경계는 [EUD 보완](EUD_COMPLETION.md)을 따른다.
