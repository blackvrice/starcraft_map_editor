# 에디터 배치·전력·크립 검사

2026-10-16. FR-218/219, EP1의 에디터 측 연결 단위다.
사용자가 **에디터 기능 우선, 실제 수집은 미지원 표시**를 선택했다.
따라서 SC:R collector·live 상태·게임/외부 에디터 인수를 완료로 표시하지 않는다.
[ADR-0020](decisions/0020-observed-creep-placement-policy.md),
[전력 설계 정책](UNIT_PREPLACED_POWER_POLICY.md), [크립 관찰 계약](UNIT_CREEP_OBSERVATION.md)을 따른다.

## 1. 실행 계획·소스 분석

1. 기존 배치 공통 prepare·전력/크립 inspection·문서/자료 수명과 미완료 항목을 대조한다.
2. 실제 수집 도구가 없음을 알리고 사용자에게 에디터/실제 수집의 범위를 확인한다.
3. 좌표별 읽기 전용 검사 화면과 명시적 조회, 실제 수집 미지원 표시를 연결한다.
4. 현재 검증된 초기 크립만 opt-in 배치 검사에 연결한다. 추론/자동 수집은 추가하지 않는다.
5. 한영·좁은 창·로딩/취소 경합·동일 preview/Apply·무변경/Undo를 자동 검증한다.
6. 전체 게이트·Windows 빌드/native·로컬 자료 회귀와 잔여 경계를 기록한다.

기존 전력/크립 API는 계산/수신 검증을 갖추었지만 사용자가 결과를 볼 화면과 크립 배치 정책은
없었다. 기본 전력 gateway는 사전 배치 설계 모델만 공급하며 실제 초기 상태를 공급하지 않는다.
기존 `UnitCreepCatalog`의 양의 요구 footprint 검사와 `coverageFor`의 phase/mask/request 검증을
재사용한다. UI에 별도 판정기·파일/프로세스 호출·raw 비트 해석을 만들지 않았다.

## 2. 화면·조회 계약

| 항목 | 동작 |
| --- | --- |
| 진입 | Map 배치 도구의 전력 아이콘·tooltip → 전력·크립 검사 |
| 좌표 | X/Y 픽셀 입력, 0~65535·5자리 제한, raw/최종 좌표를 기존 공통 preflight로 검사 |
| 전력 모델 | 기본 사전 배치 설계 모델 / 명시적 초기 관찰 segmented control |
| 크립 모델 | 검증된 initialMap만. live 선택이나 정적 후보 fallback 없음 |
| 조회 시작 | 각 새로고침 아이콘을 눌렀을 때만 numeric metadata 준비 후 해당 상태 load |
| 읽기 전용 | 열기·좌표/모델 변경·읽기·닫기는 CHK/session/Undo/선택·배치 옵션을 변경하지 않음 |
| 출처 | 판정에 사용한 현재 provider·revision과 최종 좌표 표시, 부적격/오래된 packet 출처는 숨김 |
| 결과 | 요구 충족/미충족·확인 불가·대상 아님·미지원 상태·경계/공통 거절 구분 |
| actual power | optional `UnitPowerStateModelSupport`로 명시한 모델만 UI에서 조회 가능 |
| 기본 앱 | 전력은 layout 모델만 광고, 실제 전력/크립 수집은 미지원 표시·조회 비활성 |
| legacy power port | 기존 read API는 유지. 지원 모델을 선언하지 않은 gateway는 UI 조회를 켜지 않음 |
| 로딩 | 중복 아이콘 비활성·진행 표시, power/creep 요청을 독립적으로 유지 |
| 종료/대상 변경 | metadata 대기 중 검사 창 종료·선택/session 변경이면 후속 상태 수집을 시작하지 않음 |

선언된 지원 모델은 신뢰나 게임 호환 증명이 아니다. 실제 provider를 등록하려면 기존
수집 포트의 provenance·초기 시점·권한·지원 build 검증과 별도의 인수가 필요하다.
현재 fixture의 power/creep 보고는 합성이다. provider 이름이나 UI의 ‘요구 충족’을
실제 SC:R 관찰/전체 건설 허가로 해석하지 않는다.

검사 창의 크립 checkbox만 명시적으로 배치 정책을 변경한다. 일반 읽기 전용 조회와 구분한다.
옵션을 켜거나 끄는 것 자체는 문서를 편집하지 않는다. 추가 checkbox를 Map 도구 줄에 쌓지 않고
스크롤 가능한 검사 창 안에 배치해 기존 grid/snap·브러시·로케이션 도구 접근을 유지했다.
모드 이름 옆 두 아이콘을 묶어 300px 폭에서 불필요한 새 줄이 생기는 것을 피했다.

## 3. 관찰된 크립 요구 배치 정책

- `UnitPlacementPolicy.checkCreep`의 기본값은 false다. 검사/자유 preset도 false로 유지한다.
  켜면 나머지 설정과 관계없이 custom이며 실제 boolean32조합에서 mode를 파생한다.
- checkbox는 기존 full228 metadata를 준비할 수 있지만 실제 관찰 요청을 자동 시작하지 않는다.
- 새 카탈로그 UNIT의 양의 requiresCreep 요구만 검사한다. Sprite/unit-sprite/Doodad와
  기존 이동/복제/Inspector 경로에는 적용하지 않는다.
- 현재 session/revision/설치/DAT source·DIM·initial 관찰 증거가 맞는 coverage만 전달한다.
  `_currentCreepCoverage`는 오래된/legacy/live/transaction 중 packet을 반환하지 않는다.
- 공통 `_prepareCatalogUnit`에서 최종 point/building alignment 뒤 StarEdit footprint를 다시 검사한다.
  hover 판정값을 Apply 허가로 저장하거나 비동기 수집 Future를 클릭에서 기다리지 않는다.
- covered/notApplicable은 이 검사만 거절하지 않는다는 뜻이다. 다른 배치 안전 검사는 유지된다.
- missing은 `OBJECT_PLACEMENT_CREEP_REQUIRED`, unknown/자료 없음은
  `OBJECT_PLACEMENT_CREEP_UNAVAILABLE`, 미지원 상태는 `OBJECT_PLACEMENT_CREEP_STATE_UNSUPPORTED`다.
  경계 밖은 기존 outOfBounds 코드다. 한영 안내를 공통 ghost/클릭 진단에 연결한다.
- requiresCreep=false는 크립 금지/면제 판정이 아니다. 이 옵션으로 전체 종족 건설 규칙을 보증하지 않는다.
- 실제 collector가 없는 기본 앱에서 켜면 크립이 필요한 유닛은 확인 불가로 거절된다.
  자유 배치 또는 checkbox 해제는 이 선택 규칙만 생략하며 구조/좌표/잠금/참조 검사를 유지한다.

배치 성공·편집·Undo/Redo·history transaction·재열기·설치/자료 변경은 관찰 cache를 무효화한다.
Undo로 bytes가 같아져도 관찰을 되살리지 않으며 필요한 경우 명시적으로 다시 읽어야 한다.
하위 object editing API에 raw coverage를 전달하는 caller는 source/session 결합 책임을 가진다.
실제 앱 경로는 위 controller getter로 이를 확인하고 공통 prepare로 전달한다.

## 4. 수명·최적화·주석

기존 document/history 구독을 재사용해 검사 화면에 무효화를 알린다. immutable preference
snapshot을 복사하지 않고 같은 state를 알림으로 발행해 기존 읽기 전용 identity·마지막 배치
진단을 유지한다. 요청 시작/완료 때도 알리므로 외부에서 시작한 load가 화면 로딩에 반영된다.
power current 검사에도 transaction guard를 추가했다. 늦은 응답을 검사 전에 거절하는 기존
request/session/source/revision 규칙은 유지한다.

hover는 기존 snapshot으로 bounded footprint O(k)만 계산한다. 별도 bitmap cache/관찰 I/O나
추가 DAT 프로세스를 만들지 않고 기존 metadata coalescing을 재사용한다. 실제 최대 맵의
FPS/메모리 개선 수치를 측정한 것은 아니다. 최종 좌표·coverage caller 책임·metadata 대기 뒤
창/대상 수명·preference identity 알림에 필요한 주석만 추가했다.

## 5. 요구사항·테스트 체크리스트

| 시나리오 | 검증 |
| --- | --- |
| 기본 off·검사/자유 preset·32조합 | opt-in/custom, preset은 관찰 가정 자동 활성화 안 함 |
| 현재 관찰 present/absent/unknown | preview/Apply 동일·미확인과 부재 구분·거절 시 무변경 |
| no-creep 요구 | packet 없이 N/A, 금지/면제 추론 없음 |
| source/role/box/geometry/full coverage 누락 | 확인 불가·문서/Undo 불변 |
| 최종 snap·Apply·Undo·재조회 | 최종 좌표 사용·snapshot 자동 부활/자동 수집 없음 |
| checkbox·검사 창 열기 | 명시적 옵션 변경만, 문서/Undo 불변 |
| en/ko·300/1000px | 모델 전환·출처 분리·리소스 미설정·텍스트/overflow 확인 |
| built-in 실제 전력/크립 | 미지원 안내·조회 비활성, 실제 수집 API 호출 안 함 |
| 초기 크립 3상태와 transaction | 결과 구분·현재 관찰 출처 폐기·자동 재조회 없음 |
| 외부 load·설치 변경·늦은 응답 | 로딩 반영·오래된 provider/결과 부활 없음 |
| metadata 대기 중 닫기/선택 변경 | 후속 observer 호출0·dispose 예외 없음 |
| 좌표 오류·선택 없음 | 잘못된 점/결과 없음·조회 비활성·무변경 |
| 전체 배치·문자열/unknown·Undo | 기존 전체 회귀와 raw bytes 왕복 유지 |
| 실제 SC:R/live·게임/외부 에디터 | 사용자 선택에 따라 이번 범위 제외·미지원/미실행 |

## 6. 실행·결과·분석

ignored `.dart_tool/environment_inspection_*.log`에 원시 실행 결과를 남긴다.
실행 SDK Flutter3.47.5 stable/Dart3.13.4는 기준3.44.8/3.12와 다르다.

- 초기 새 화면10개 테스트와 analyze를 통과했다. 정책 연결 뒤 multiline if 중괄호2건을 수정했다.
- 첫 집중 회귀에서 불변 state identity4건과 좁은 toolbar 클릭1건이 실패했다.
  알림을 위해 state를 복제하던 것을 같은 snapshot 발행으로 바꾸고, checkbox를 검사 창으로
  이동·도구 아이콘을 묶어 기존 도구 접근을 복구했다. 기존 판정 기대값을 완화하지 않았다.
- 추가된 한글300px 모델 전환 테스트1건은 스크롤 완료 전 클릭했다. ensureVisible 뒤
  pumpAndSettle로 실제 스크롤 완료를 기다려 수정했다. 판정/출처 분리 기대값은 유지했다.
- optional 모델 지원 인터페이스에서 nullable unrelated interface promotion을 기대해 컴파일이
  실패했다. 명시적 typed property pattern으로 바꾸고 집중456통과·10skip을 확인했다.
- 수동 test patch의 hunk 순서/위치 불일치는 적용 전에 거절되어 분리 재적용했다.
- 변경 중간 전체2,165통과/61skip은 지원 모델/종료 경합 회귀4개 추가 전의 기록이다.

| 최종 검증 | 결과 |
| --- | --- |
| 집중 domain/controller/widget/object editing | 456통과·10skip·exit0 |
| `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 2,169통과·61skip·exit0 |
| 로컬 DAT/graphics·자체 제작 MPQ 회귀 | 473통과·skip 없음·exit0 |
| 변경 Dart14파일 format | 0변경·exit0 |
| 전체 format | 493파일 중 기존3파일 차이·exit1 |
| Windows Debug build | 성공·exit0 |
| native CTest | 7/7통과·exit0 |
| 문서 로컬 링크 | 관련10문서423개 존재 확인 |
| `git diff --check` | 통과 |

새 테스트42개는 크립 정책12·검사 UI/수명14·mode 조합16개다. 집중10skip은 기존 로컬 선택
회귀이며 helper/설치를 지정한 별도 실행에서는 모두 통과했다. 로컬473개에는 기존 객체·설정
Save As/재열기와 임시 맵 검증도 포함되며 새 크립 packet은 합성으로 유지한다. 로컬 DAT나 MPQ를
사용했다는 이유로 실제 게임 크립/전력 수집을 검증했다고 표시하지 않는다.

전체 format 차이는 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`뿐이며 수정하지 않았다.
Windows 빌드의 기존 CascLib CMake deprecation 경고는 비치명적이었다. 사용자 선택에 따라 앱·게임·
외부 에디터를 조작하지 않았으므로 UI는 자동 widget 검증이지 실제 Windows 조작 인수가 아니다.
기준 SDK 재검증·전체 format 기준선·실제 게임/외부 인수는 남는다. 기존 사용자 변경과 staged
`local.properties`는 이번 커밋에서 제외해 보존한다.

## 7. 완료·미지원

이번 완료 대상은 에디터의 좌표별 전력/크립 조회·명시적 모드/출처/로딩·기본 실제 수집 미지원
표시와 opt-in 양의 크립 요구 배치 검사다. 기존 전력 설계 정책·지형/겹침/자원/안전 검사를 유지한다.
실제 initialMap/live collector·게임 관찰·전력/크립 overlay bitmap·runtime EUD DAT 재해석·
unit-sprite 관계 예외 확대·전체 게임 건설 가능성과 EP1 인수 전체는 완료 표시하지 않는다.
사용자가 선택한 에디터 범위와 추후 실제 수집 도구/자료가 필요한 범위를 구분한다.
