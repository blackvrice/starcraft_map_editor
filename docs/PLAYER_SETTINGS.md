# 플레이어 설정

## 현재 지원

File → Player Settings에서 플레이어 1~8의 슬롯 종류, 종족, 기본 색상 ID를
편집한다. 여러 플레이어를 오가며 변경을 모으고 Apply로 한 명령에 적용한다.
Cancel은 미적용 입력을 폐기한다. 객체·맵 정보와 같은 기록의 Undo/Redo를
사용하며 Save As로 저장한다. 오래된 문서 스냅샷에는 적용하지 않는다.
플레이어 9~12는 원시 슬롯·종족 값을 읽기 전용으로 표시한다.

OWNR/SIDE는 각각 12바이트, COLR는 8바이트다. 단일 알려진 VER(59/63/205/206)가
필요하다. 각 그룹의 누락·중복·크기 오류는 해당 그룹만 비활성화한다. 없는
섹션을 생성하지 않으며, 변경한 인덱스 이외 바이트와 IOWN 등 다른 섹션은
보존한다. 지원하지 않는 기존 값은 숫자 ID로 표시하고 그대로 유지할 수 있다.

초기 편집 선택지는 슬롯 0/3/5/6/7, 종족 0~7, 색상 0~11이다. 임의 숫자의
새 입력과 플레이어 9~12 쓰기를 거부한다. CRGB가 있으면 COLR 색상 편집을
차단하고 사유를 표시한다. CRGB의 사용자 색상과 COLR의 우선순위는 추측해
동기화하지 않는다. 캔버스의 팀 색상 미리보기는 아직 소유자별 기본 색상을
사용하며, COLR 설정을 반영하는 미리보기는 후속 범위다.

## 시작 위치 진단

UNIT 종류 ID 214를 시작 위치로 집계한다. 플레이어 1~8의 Human/Computer
계열 슬롯(원시 값 1/2/5/6)에 시작 위치가 없거나, 같은 플레이어에게 여러
시작 위치가 있으면 경고한다. 비활성 슬롯(0/8)의 시작 위치와 8 이상의 원시
소유자 ID도 경고한다. UMS에서 의도한 구성이 가능하므로 저장 차단이나 자동
배치·삭제는 하지 않는다. UNIT 레코드 길이가 잘못되면 집계를 추측하지 않고
진단 불가를 표시한다.

진단 코드는 CHK_PLAYER_SETTINGS_START_MISSING, START_DUPLICATE,
START_INACTIVE, START_OWNER, START_UNAVAILABLE이며 모두 동일한
CHK_PLAYER_SETTINGS_ 접두사를 쓴다. 맵 열기, 객체·설정 편집, Undo/Redo와
Save As 재검증에서 갱신하며 Problems 및 설정 창에서 확인한다.

## 검증과 남은 범위

합성 바이트로 선택 필드만 수정, 예약 플레이어·비표준 값 보존, 그룹별 오류,
CRGB 보호, 잘못된 입력의 무변경, 시작 위치 경고를 검증한다. 위젯 테스트는
여러 슬롯의 입력·취소·적용·Undo/Redo와 예약 슬롯 비활성화를 확인한다.
가짜 아카이브 gateway의 Save As 왕복 테스트는 출력 CHK를 재열어 설정값,
진단과 다른 섹션 보존을 확인한다. 실제 SC:R 실행과 색상 표현은 별도 검증이다.

## 근거

2026-09-08 다음 고정 revision의 선언을 확인했다. 이것은 상호 운용 참고
구현이며 실제 게임 검증을 대신하지 않는다.

- [Chkdraft chk.h: Race, PlayerColor, OWNR/SIDE/COLR/CRGB](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h)
- [Chkdraft sc.h: Player::SlotType, Unit::Type::StartLocation](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h)

File → Map Settings의 통합 탭에서도 편집할 수 있다. 검색과 1번부터 시작하는
번호 범위 복사는 [통합 설정 UI](MAP_SETTINGS_UI.md)의 초안·적용 규칙을 따른다.
