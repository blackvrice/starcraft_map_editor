# 앱 계층의 읽기 전용 전력 조회

2026-10-15. EP1/FR-218의 [순수 전력 판정](UNIT_POWER_VALIDATION.md)에 문서·출처·상태
연결을 추가했다. **application API 단계**이며 UI 전력 checkbox/ghost/Apply 정책은
아직 연결하지 않았다. 실제 상태 수집기를 등록하지 않은 기본 앱은 전력 공급을 추측하지 않는다.

## 1. 계획과 소스 분석

1. 기존 자원 거리 조회의 공통 preflight와 full228 metadata 수명을 재사용한다.
2. 신뢰된 상태 수집용 포트를 추가하고 정확한 문서/출처/record에 응답을 묶는다.
3. 조회 중에는 I/O 없이 최종 snap 위치와 현재 owner로 순수 checker만 호출한다.
4. 누락/비지원 응답, 편집·Undo·재열기·설치/자료 변경·취소 경합을 자동 검증한다.
5. 전체 회귀·Windows 빌드 결과와 앱/게임 미실행 범위를 기록한다.

기존 `PlacementCatalogController`는 출처가 일치하는 graphics/numeric metadata와
공통 UNIT factory/session/history/layer 검사, point/building snap을 이미 갖고 있다.
그러나 `OpenedMapSession`은 immutable CHK snapshot이지 완공/활성을 관찰한 상태 자료가 아니다.
따라서 기존 유닛 레코드에 true를 채우는 대신 별도 포트와 검증된 응답 경계를 추가했다.

## 2. 상태 포트와 신뢰 계약

`UnitPowerStateGateway.read(request)`는 명시적으로만 호출한다. 기본 구현이나 bootstrap
등록은 없다. 테스트 구현은 자체 작성한 합성 상태이며 실제 게임 증거가 아니다.

| 계약 | 검증/제한 |
| --- | --- |
| request | operation ID, immutable session, controller-local document revision, 설치 경로, DAT 출처 tuple |
| DAT 출처 | product/build/helper/CascLib 네 값이 선택 graphics와 같아야 하며 build는 비음수 |
| UNIT 목록 | 현재 session의 전체 UNIT을 section/record 순서대로 고정한 목록 |
| 응답 request | 요청 객체 자체가 동일해야 함. 숫자 revision만 복사한 다른 응답은 거절 |
| 응답 provenance | 비어 있지 않은 provider ID와 state revision 필요 |
| 모델 | initialMap만 허용하고 power model revision이 순수 checker와 일치해야 함 |
| coverage | UNIT 수와 각 record의 객체 identity/순서가 모두 일치해야 함 |
| unknown facts | nullable 존재/완공/활성은 그대로 domain에 전달. 수집 성공과 powered는 다름 |
| 실패 | errorCode 또는 nonzero exitCode, 동기/비동기 예외는 수집 실패 |
| 원시 기록 | 현재 응답의 stdout/stderr/exitCode/오류·provider revision을 read result로 보관 |

provider 이름·revision 문자열은 사실의 진위를 증명하지 않는다. 이 포트는 **신뢰된 adapter**가
명시적 근거로 수집한 상태를 반환한다는 경계다. 제3자 EUD/Python 코드를 실행하거나
그 결과를 자동 신뢰하지 않는다. 실제 adapter의 상태 의미·근거·지원 범위는 후속 작업이다.
`initialMap`은 같은 문서/자료에서 유효한 초기 상태 계약이다. live/EUD 변경은 이 계약에
포함되지 않으며 live 응답을 거절한다. CHK 존재/HP/valid flags로 상태를 추론하지 않는다.

## 3. 수명과 조회

- `loadCollisionMetadata()`의 검증된 snapshot으로 power catalog도 만든다. 새 DAT 프로세스는 없다.
- `loadUnitPowerState()`는 metadata/source 준비 후 별도로 요청한다. 동일 pending 요청을 합친다.
- `reload:true`는 이전 상태와 pending을 먼저 무효화한다. 실패는 다시 요청할 수 있다.
- session 변경과 공통 history 알림을 구독한다. 편집·Undo/Redo·transaction 시작/종료마다
  상태 revision을 무효화해 과거 snapshot으로 돌아가도 이전 상태를 되살리지 않는다.
- 설치 변경·명시적 session 동기화·metadata reload·dispose도 상태를 지운다.
- 무효화된 요청은 cancel을 시도한다. 취소 실패와 무관하게 revision/request 검증으로
  늦은 응답을 버리며 새 요청의 cache나 raw result를 덮어쓰지 않는다.
- document revision은 controller 내부의 무효화 세대이지 저장 가능한 전역 문서 ID나 편집 횟수가 아니다.
- `inspectUnitPowerAt()`는 current UNIT 선택에만 적용한다. raw 좌표와 최종 snap 좌표를
  공통 preflight로 검사한다. 선택/session/history/layer/factory 오류는 기존 issueCode로 반환한다.
- 선택적 지형/겹침/자원 거리 정책은 이 독립 조회를 차단하지 않는다. 그 정책의 통과를 뜻하지도 않는다.
- source/state가 현재 문서와 일치하면 같은 owner와 최종 중심 좌표로 domain checker를 읽는다.
- 확인된 no-psi 후보는 상태 packet 없이 notApplicable이다. 그 외에는 상태가 없으면
  unavailable이며 빈 UNIT 문서도 추측으로 unpowered로 승격하지 않는다.
- `UnitPowerInspection`은 시점별 결과일 뿐 Apply 허가나 편집 후 재사용할 토큰이 아니다.

조회는 UI 상태·선택·CHK bytes·unknown section·history·복구 자료를 변경하지 않는다.
전력/크립 지원표의 notImplemented와 기존 checkbox/preview/Apply/저장 동작도 유지한다.
현재 앱에서 이 API가 자동 호출되거나 전력 표시가 추가된 것은 아니다.

## 4. 요구사항과 테스트 체크리스트

`placement_catalog_controller_test.dart`에 새 전력 시나리오43개를 추가했다.

| 시나리오 | 기대 결과 |
| --- | --- |
| adapter 없음·legacy 요구 profile 없음 | unavailable, CHK로 상태를 채우지 않음 |
| 명시적 수집·중복 요청·반복 hover | 한 요청 재사용, hover I/O 없음, 선택/bytes/Undo/Redo 무변경 |
| 같은/다른 owner·정확한 mask 경계 | 현재 owner의 powered/unpowered 조회 |
| point/building snap | raw769에서는 공급되나 최종768에서는 공급 안 됨 |
| raw/final 범위·과대 정수·layer lock·history transaction | 기존 공통 진단, 조회나 수집으로 우회하지 않음 |
| 지형/겹침 선택 검사 | 해당 검사의 거절과 전력 결과를 혼동하지 않음 |
| 예외·오류·exitCode·request·provider/revision/model 오류 | 거절, retry로 회복 |
| 누락/clone/reorder/duplicate record packet | 숫자/bytes가 같아도 잘못 귀속된 응답 거절 |
| unknown/disabled 상태 | 수집 성공 후에도 unavailable/stateUnsupported |
| DAT 출처·coverage·요구 자료 누락 | unavailable, metadata reload 후 회복 |
| 편집+Undo·history·설치·session·metadata·재열기·dispose | cached/pending 각각 무효화; 동일 내용의 맵도 재수집 |
| cancel 실패·역순 응답 | 새 응답 유지, 오래된 응답과 로그 폐기 |
| Tile/Sprite/sprite-unit/Doodad | notApplicable, 상태 조회 프로세스 없음 |

초기 집중 테스트의 실패1건은 기본8x8 fixture에서1024 좌표를 조회해 생긴 테스트
범위 오류였다. 의도한64x64 합성 맵으로 수정했다. 초기 analyze의 multiline if 스타일
2건도 수정했다. 실패 기록은 ignored `.dart_tool/unit_power_app_*.log`에 남긴다.

## 5. 최적화와 실행 결과

상태 수집/coverage 검증은 UNIT 수 n에 O(n), packet 보관은 O(n)이다. immutable record를
복사하지 않고 참조 목록만 고정한다. hover는 기존 preflight와 O(n) 순수 판정을 재사용하며
파일/프로세스/상태 수집을 호출하지 않는다. 같은 pending/완료 packet을 재사용하고 변경
이벤트에서만 무효화한다. 속도 향상 수치와 대규모 성능은 미측정이다.

| 실행 | 결과 |
| --- | --- |
| `flutter test test/application/placement_catalog_controller_test.dart --reporter expanded` |180통과/9skip, 새 전력43개 포함 |
| `flutter analyze` | No issues |
| `flutter test --reporter expanded` |1663통과/58skip |
| 로컬 설치/helper 환경 변수를 지정한 controller suite |189통과, 기존 로컬 배치/자료 경로도 회귀 없음 |
| `flutter build windows --debug` | 성공 |
| VS CTest Debug |7/7통과 |
| 변경 Dart4파일 format 검사 |0변경, exit0 |
| 전체 format 검사 | 아래 기존3파일 차이, exit1 |
| `git diff --check` | 통과 |

Windows 빌드와 전체 회귀는 동시에 실행하지 않았다. 로컬 suite가 통과해도 새 전력
상태의 존재/완공/활성은 합성 입력이다. 실제 초기 상태를 관찰한 증거나 adapter 완성이 아니다.

전체 format은467파일 중 기존3개 테스트의 차이로 exit1이다. 대상은
`test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`이며
이번에 변경하거나 커밋하지 않았다. SDK는 **Flutter3.47.5 stable/Dart3.13.4**이며
기준 **3.44.8/3.12** 재검증은 남는다. CascLib의 기존 CMake deprecation 경고는 비차단이다.

## 6. 남은 범위

다음은 실제 초기 맵 공급 상태의 의미·근거와 지원 범위를 확정해 검증된 adapter를
구현하는 단위다. 증거가 없으면 unavailable을 유지한다. 그 후 기본 꺼짐 정책과 한영
checkbox/공통 preview·Apply 연결을 진행한다. 크립 영역, live/EUD 변경, 게임 규칙 전체와
릴리스 인수는 별도다. 사용자 지시에 따라 이번에는 자동 테스트/빌드만 진행하며
실제 앱 조작·SC:R·외부 에디터는 실행하지 않는다.
