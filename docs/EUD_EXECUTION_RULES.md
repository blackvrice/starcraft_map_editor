# EUD 실행 규칙 — 플레이어 자원

2026-09-28 M7.1 첫 수직 기능. 전체 동적 실행 언어의 완료가 아니다.

## 사용 방법

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

규칙이 없는 기존 schema v1은 바이트 표현을 유지한다. 규칙이 있으면 schema v2의
`rules` 배열을 사용한다. 구버전 앱은 v2를 거부한다. 새 앱은 두 버전을 읽으며,
마지막 규칙을 삭제하면 v1으로 저장한다. 알 수 없는 규칙 키/enum, 잘못된 타입,
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

다음 범위는 미구현이다: 사용자 변수/계산 식, Triggers의 EUD 확장 탭 및 설정별
연결, 업그레이드/연구 상태, 유닛 인스턴스 수명/재사용, 계산 로케이션과 대상 추적,
동적 텍스트/소리, 로컬 표시 분리와 전체 순환 분석. 임의 포인터 쓰기를 제공하지 않는다.

게임 확인: Once가 첫 조건 일치 때만 적용되는지, Periodic의 조건 거짓/참 전환과
간격, 두 플레이어의 자원 독립성, 비활성 규칙, 일반 트리거와의 실행 순서,
두 클라이언트 멀티플레이 동기화를 자체 제작 맵에서 확인해야 한다.
