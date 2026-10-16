# 앱 계층 읽기 전용 크립 조회

후속 [에디터 전력·크립 검사](PLACEMENT_ENVIRONMENT_EDITOR.md)에서 조회 UI와 opt-in 배치 검사를
연결했다. 아래는 API 도입 당시 기록이며 실제 수집 미지원·현재 요청/초기 관찰 결합은 유지한다.

후속 [초기 크립 출처 조사](research/INITIAL_CREEP_SOURCE_FEASIBILITY.md)에서 실제 collector
미지원과 정적 후보 자료의 지원 경계를 확정했다. 아래는 앱 API 연결 단계의 기록이다.
후속 [초기 관찰 증거 검증](UNIT_CREEP_OBSERVATION.md)은 snapshot에 명시적 관찰 정보를
요구하고 미관찰 present/absent를 unknown으로 정규화한다. evidence-free legacy는 조회를
거절하며 아래 합성 API 연결 당시의 테스트 수/계약 기록과 구분한다.

2026-10-15. EP1/FR-218의 [초기 크립 자료와 순수 판정](UNIT_CREEP_VALIDATION.md)을
application에 연결했다. 이번 결과는 **개발용 API와 문서/자료 수명 관리**다.
실제 초기 크립 collector·UI·배치 차단·게임 인수를 구현한 것은 아니다.
기본 앱에는 collector가 없으므로 요구 후보의 상태를 추측하지 않고 unavailable로 둔다.

## 1. 실행 계획과 소스 분석

1. 기존 power inspection의 source-matched full228 metadata와 공통 preflight를 재사용한다.
2. 크립 포트는 선택적으로 주입하고 상태/취소/원시 응답은 전력과 독립적으로 보관한다.
3. session·history·설치·metadata 변경과 명시적 reload에서 현재 요청을 무효화한다.
4. 출처/모델/coverage 응답을 검증한 뒤 최종 좌표의 양의 요구만 읽기 전용으로 검사한다.
5. 성공/unknown/실패·동기/비동기 취소 경합·Undo·전력 회귀·무변경을 테스트한다.
6. 자동 테스트와 Windows 빌드 결과, 실제 수집/앱/게임 미실행을 구분해 기록한다.

`PlacementCatalogController`는 이미 UNIT 선택의 graphics 출처와 numeric DAT tuple을
대조하고 source 별 full metadata cache, point/building snap과 공통 안전 검사를 제공한다.
별도 DAT 프로세스나 UI 검증기를 만들 필요가 없다. 공유 getter를
`_currentUnitDataIdentity`로 명확히 하고 기존 전력과 새 크립이 동일한 자료 경계를 쓴다.
전력/크립 모델·결과·cancel을 합치지는 않는다.

## 2. API와 반환 계약

| API | 계약 |
| --- | --- |
| `unitCreepStateGateway` | 선택적 constructor 주입. 실제 구현/자동 bootstrap 등록 없음 |
| `loadCollisionMetadata()` | 검증된 기존 full228 snapshot으로 `UnitCreepCatalog`도 생성. 별도 파일/IPC 없음 |
| `loadUnitCreepState()` | UNIT 선택·source 준비·일반 문서·transaction 밖에서 명시적으로만 수집 |
| pending/cache | 같은 요청 Future 공유. current cached packet은 재사용. reload는 성공/실패에 관계없이 이전 결과를 먼저 폐기 |
| 모델 | initialMap만 지원. live 요청은 거절하고 이전 initialMap pending/cache도 무효화. fallback 없음 |
| 응답 검증 | 현재 request/token 확인 후 transport 성공과 `coverageFor(request)` 검사. 잘못된 echo/model/provenance/rules/DIM 거절 |
| 원시 기록 | 현재 read의 stdout/stderr/exitCode/errorCode·provider/revision은 `lastUnitCreepStateRead`에 보관. 오래된 응답 로그는 버림 |
| `inspectUnitCreepAt()` | UNIT의 raw 좌표와 최종 point/building snap 좌표를 공통 preflight로 확인한 후 순수 checker 호출 |
| `UnitCreepInspection` | check·최종 point·요청 model·현재 provider/state revision 또는 공통 issueCode. Apply 허가가 아닌 시점별 읽기 결과 |

공통 session/history/layer/factory/좌표 검사는 유지한다. 지형/겹침/자원/사전 배치 전력 같은
선택적 배치 정책은 이 독립 크립 조회를 거절하지 않는다. 조회가 해당 정책을 통과시켰다는
뜻도 아니다. 비UNIT(Tile/Sprite/unit-sprite/Doodad)은 대상 아님이며 수집도 시작하지 않는다.

현재 coverage가 있어도 absent는 missing, unknown은 unavailable이다. 둘 다 수집 실패와
구분해 provider/revision을 반환할 수 있다. 현재 packet이 없으면 provenance도 null이다.
검증된 no-creep 요구는 packet 없이 notApplicable이며, 금지/면제 규칙의 승인으로 바꾸지 않는다.
전체 박스 경계의 domain outOfBounds와 공통 좌표 preflight의 issueCode도 구분한다.

## 3. 문서 수명과 취소 경합

기존 session/history 구독을 함께 사용하며 새 구독이나 UI listener는 만들지 않았다.
크립의 document revision·pending/request/snapshot·read result는 전력과 별개다.

- session 교체·편집·Undo/Redo·transaction 시작/종료가 관찰되면 상태를 지운다.
  바이트가 같은 snapshot으로 돌아가도 과거 관찰을 되살리지 않는다.
- 설치 경로 변경·명시적 session 동기화·metadata reload·재열기·dispose도 무효화한다.
- pending 요청에 cancel을 시도하지만 성공을 기다려 신뢰하지 않는다. 동기/비동기
  취소 예외를 수용하고 current request/session/revision/source로 늦은 응답을 거절한다.
- 새 요청이 성공한 뒤 이전 요청의 실패 응답이 와도 최신 packet과 raw log는 유지한다.
- 명시적 크립 reload는 power pending/cache를 취소하거나 바꾸지 않는다. 공통 metadata/
  문서 변경은 양쪽 모두를 무효화한다.
- 조회는 I/O를 호출하지 않는다. 수집은 명시적 load만 담당하며 cursor/preview/Apply에서
  load를 자동 호출하지 않는다. 반복 inspection은 문서·선택·history/dirty를 그대로 둔다.

echo와 revision 검증은 실제 collector의 정확성을 증명하지 않는다. 현재 synthetic gateway는
오직 테스트용이다. 실제 초기 시점·관찰 권한·미관찰 tile·runtime/EUD 자료를 검증한
adapter만 추후 연결한다. CHK의 UNIT/MTXM이나 지형 그림에서 임의 coverage를 만들지 않는다.

## 4. 요구사항·시나리오 체크리스트

`placement_catalog_controller_test.dart`에 크립 시나리오 52개를 추가했다.

| 시나리오 | 기대/확인 |
| --- | --- |
| 기본 collector 없음·legacy role 없음 | unavailable, 실제 초기 상태를 추측하지 않음 |
| 명시적 중복 요청·반복 조회·소유자 변경 | pending/cache 재사용·I/O 증가 없음·coverage는 소유자별 전력이 아님 |
| 최종 point/building snap | raw1023의 missing과 최종1024의 covered 구분 |
| raw/final/과대 정수·잠금/숨김·transaction | 기존 공통 진단으로 거절 |
| 독립 양의 크립 요구 | 지형 등 선택 정책의 거절과 결과를 혼동하지 않음 |
| sync/async read 예외·오류·exitCode·빈 응답·echo/provider/revision/model/rules/크기 오류 | 실패·명시적 retry 회복 |
| 성공 후 reload 실패 | 이전 성공 snapshot이 되살아나지 않음 |
| 명시적 absent/unknown·no-creep | missing/unavailable/대상 아님 구분·신뢰하지 않은 허가 없음 |
| source/metadata 누락·role/geometry/box 차이 | unavailable·reload 후 회복 |
| cached/pending 각각 UNIT+Undo·MTXM+Undo·history·설치/session·metadata·재열기·dispose | 현재 결과와 로그 무효화, pending 취소 시도 |
| sync/async cancel 실패·역순 실패 응답 | 최신 packet/log 보존 |
| live 요청·응답 | 거절·initialMap fallback/과거 cache 부활 없음 |
| power/creep cached/pending 병행 | 한쪽 reload로 다른 쪽 요청을 취소하지 않음 |
| Tile/Sprite/unit-sprite/Doodad | 대상 아님·포트 호출 없음 |
| 반복 read-only 조회 | 전체 CHK bytes(session의 문자열/unknown 포함)·session·선택·Undo/Redo·dirty 불변 |

## 5. 최적화와 주석

DAT는 기존 full228 응답으로 O(228) catalog를 함께 만들고 immutable capability를 재사용한다.
초기 coverage는 한 번 수신해 공유하며 매 inspection은 current token/source 검사와 bounded
footprint O(k), 추가 작업 메모리 O(1)이다. 포트의 coverageFor는 전체 타일 목록을 다시 복사/
순회하지 않는다. 같은 pending은 합치고 변경 이벤트에서만 무효화한다.
복잡한 취소 경합과 source 공유 이유에 주석을 추가했다. FPS/실시간 게임 성능은 미측정이다.

## 6. 실행·분석

집중 52개가 통과했다. 초기 analyze에서 테스트 helper의 multiline if 중괄호 스타일
3건을 검출해 수정했다. 최종 analyze와 전체 테스트를 재실행해 통과했다.
원시 로그는 ignored `.dart_tool/creep_inspection_*.log`에 기록한다.

| 실행 | 결과 |
| --- | --- |
| 크립 집중 테스트 | 새 52개 통과·실패/skip 없음 |
| 최종 `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 1차/최종 각각 1,854통과·59skip·exit0 |
| 로컬 DAT/graphics/native MPQ controller·integration | 297통과·skip 없음·exit0 |
| 변경 Dart 3파일 format | 0변경·exit0 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 475파일 중 기존 3파일 차이·exit1 |
| `flutter build windows --debug` | 성공·exit0. 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| `git diff --check` | 통과 |

전체 format 차이는 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
해당 파일은 이번 범위에서 수정하지 않았다. 실행 SDK는 Flutter3.47.5 stable/Dart3.13.4로
기준3.44.8/3.12와 다르며 기준 SDK 게이트/릴리스 승인을 완료했다고 주장하지 않는다.

기존 사용자 변경을 보존한 작업 트리에서 검증했고 이번 범위만 커밋한다. 59skip은 통과가
아니다. 로컬 연동 297개에는 새 합성 크립 시나리오와 기존 실제 DAT·graphics/MPQ 회귀가
함께 들어 있다. **크립 coverage는 여전히 합성 자료이며 실제 게임 수집 검증이 아니다.**
이번 실행에서 기능/테스트 실패는 없었다. 실제 앱/SC:R·외부 에디터 인수는 미실행이다.

## 7. 다음 단위

앱 API 수명 연결만 완료 처리한다. 기존 배치 checkbox/지원표/ghost/Apply/저장은 유지하며,
UI/실제 collector/live·EUD 변경 자료와 EP1 게임/외부 인수는 계속 미완료다.
사용자의 자동 테스트/빌드만 진행 지시에 따라 실제 Windows 앱·게임·외부 에디터를 조작하지 않는다.

다음은 초기 크립을 신뢰할 수 있게 수집할 수 있는 자료와 시점·권한·미확인 영역의
feasibility 조사 및 adapter 지원 범위 확정이다. 불가능한 범위를 unavailable로 유지하고
제작용 추정 모델이 필요하면 실제 상태와 명확히 분리하는 결정을 먼저 남긴다.
