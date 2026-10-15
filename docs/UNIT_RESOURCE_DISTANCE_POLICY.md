# UNIT 자원 거리 배치 정책

2026-10-15. EP1/FR-218의 자원 거리 [기반 자료](UNIT_RESOURCE_DISTANCE.md)와
[현재 UNIT aggregate](UNIT_RESOURCE_DISTANCE_AGGREGATE.md)를 실제 카탈로그 배치에 연결했다.
classic DAT 기반의 제한 정책이며 전력/크립·EUD 런타임 변경·게임 인수 완료를 뜻하지 않는다.

## 1. 실행 계획과 소스 분석

1. 기존 `_prepareCatalogUnit`의 구조/좌표/factory·정렬·지형·겹침 검사와 preview/Apply 호출을 조사한다.
2. 별도 UI 판정기를 만들지 않고 같은 prepare에 aggregate를 연결한다.
3. 기본 꺼짐 checkbox, 기존 metadata 조회/재조회, 프리셋/지원표 및 한영 진단을 연결한다.
4. 최종 좌표·source/unknown/state·Undo/Save As와 좁은 화면을 자동 테스트한다.
5. 전체 게이트·Windows/native·실제 로컬 숫자 자료 결과와 미실행 범위를 기록한다.

새 binary parser/flag/게임 규칙을 도입하지 않는다. 참고 source와 비행 상태를 보수적으로
제한한 이유는 앞선 aggregate 계약을 그대로 따른다. domain은 계속 Flutter/I/O에 의존하지 않는다.

## 2. 정책 계약

| 항목 | 현재 동작 |
| --- | --- |
| 기본값 | 자원 거리 검사 꺼짐, 기존 자유 배치 동작 유지 |
| 검사 배치 | 지형 검사 켬·겹침 허용 해제·자원 거리 검사 켬을 한 emit으로 설정 |
| 자유 배치 | 지형/자원 검사 끔·겹침 허용 켬을 한 emit으로 설정 |
| 사용자 설정 | 세 boolean의 나머지6조합, 실제 설정에서 mode 파생 |
| 유지되는 설정 | 건물 정렬/point snap/grid/owner/continuous/selection을 프리셋으로 바꾸지 않음 |
| 대상 | 새 카탈로그 UNIT만 적용; Sprite/unit-sprite/Doodad·이동·템플릿·로케이션 제외 |
| 기존 자료 | 정책 선택만으로 현재 UNIT/CHK/문자열/Undo를 수정하지 않음 |
| 자료 | 전체228 metadata-only snapshot을 겹침 검사와 공유; 별도 프로세스 연산 없음 |
| 출처 | 선택의 product/build/helper/CascLib tuple이 같은 catalog만 prepare에 전달 |
| 수명 | 설치/세션/출처 변경·재조회·dispose 시 기존 epoch와 취소/무효화 재사용 |

`ObjectEditingController.placeCatalogUnit/previewCatalogUnit`의 선택적 입력은
`checkResourceDistance`와 `resourceDistanceCatalog`다. 두 경로는 같은
`_prepareCatalogUnit`에서 **실제 저장할 좌표**를 검사한다. 공통 구조/레이어/history/
ID/owner/좌표/factory를 먼저 검증하고, 건물 정렬 후 지형·겹침·자원 검사를 순서대로
적용한다. 서로 다른 정책에서 동시에 실패하면 이 순서의 첫 사유를 반환한다.
aggregate 내부 unknown/state/bounds/distance 우선순위는 그대로 유지한다.

점 스냅의 raw 좌표는 공통 안전 검증만 수행하고 최종 스냅 위치에 선택 정책을 적용한다.
음수/맵 밖 입력을 스냅으로 살리거나 가장자리로 clamp하지 않는다. 건물 박스와 DAT
collision extent는 다른 자료로 유지한다. 검사 직전에 현재 문서를 읽어 Undo/Redo 후에도
오래된 UNIT 목록을 사용하지 않는다. 읽기 전용 `inspectUnitResourceDistanceAt`도 유지한다.

## 3. 진단과 지원표

| aggregate 결과 | 배치 결과 |
| --- | --- |
| clear / notApplicable | 이 정책은 거절하지 않음; 다른 공통 검사 성공은 별도 |
| tooClose | `OBJECT_PLACEMENT_RESOURCE_DISTANCE_TOO_CLOSE` |
| metadataUnavailable / snapshot 없음 | `OBJECT_PLACEMENT_RESOURCE_DISTANCE_UNAVAILABLE` |
| stateUnsupported | `OBJECT_PLACEMENT_RESOURCE_DISTANCE_STATE_UNSUPPORTED` |
| outOfBounds | 기존 `OBJECT_PLACEMENT_OUT_OF_BOUNDS` |

카탈로그 안내와 Shell ghost는 기존 `placementFailureText`를 통해 같은 한영 문구를
사용한다. unknown/미지원 상태를 거리 위반으로 표시하지 않는다. 거절은 UNIT append나
Undo 생성 전에 끝나며 선택을 유지해 자료 재조회/위치 변경/명시적 검사 해제를 할 수 있다.

도구 줄의260px CheckboxListTile에 체크박스·16px 로딩·재조회 아이콘/tooltip을 추가했다.
겹침과 같은 metadata를 읽기 때문에 두 재조회 버튼은 같은 cache를 새로 고친다.
재조회는 선택 graphics catalog를 자동 갱신하지 않으며 source가 다르면 확인 불가를
유지한다. 조회 중 자유 배치를 선택해도 늦은 응답이 정책을 다시 켜지 않는다.

지원표의 자원 거리 row는 비UNIT 대상 아님, 꺼짐 생략, pending 로딩, source/역할 누락·
불일치 확인 불가, 확인된 비자원/비기지 대상 아님, 관련 Flyer/geometry 누락 확인 불가,
나머지 자료 연결 시 검사 사용을 표시한다. **검사 사용은 좌표 통과가 아니다.** 기존
UNIT 전체와 정확한 후보 geometry/지원 상태는 preview/Apply 시 다시 판정한다.
전력/크립/EUD 미구현과 게임 인수 대기 표시는 유지한다.

## 4. 요구사항·테스트 시나리오

| 시나리오 | 검증 |
| --- | --- |
| 기본 off·checked/free/custom8조합 | domain 값/모드 및 controller 원자 변경 회귀 |
| pending 공동 조회·자유 전환 | metadata1회·늦은 응답이 검사 설정을 복원하지 않음 |
| 최종 point/건물 정렬의 거리 위반 | raw 위치 허용→최종 거절, preview/Apply 사유 일치 |
| source/coverage/role/geometry 불일치 | 문서/Undo 무변경, reload 후 재시도 |
| extendedID·flight·관련 UNIT 맵 밖 | unavailable/stateUnsupported/outOfBounds 구분 |
| free 모드·다른 객체 종류 | 거리 정책 생략, 기존 factory·안전 검증 유지 |
| 거절과 재시도·Undo/Redo | 선택 보존, 거절 기록0, 성공1회, 원시 CHK byte-exact 복원 |
| Save As | 합성 archive에서 기지/자원 허용·거절·Undo/Redo·저장 후 재판정, unknown 섹션/입력 보존 |
| 실제 로컬 DAT | full228과 graphics Unit106·자체 UNIT188, near 거절/far 허용·Undo |
| 한영 좁은 UI | 300px toolbar·500x760 화면의 checkbox/reload/preset/dialog, overflow/exception 없음 |
| 모든 진단 번역 | ObjectPlacementDiagnosticCodes.all의 한영 누락/fallback 거절 회귀 |
| 기존 Shell/기본 기능 | 전체 회귀 및 검사 프리셋의 공통 ghost/클릭/잠금/재시도 |

실제 게임에 새 자원을 놓아 자원 고갈/채취/건설/멀티 동작을 관찰한 것은 아니다.
지원하지 않는 비행 상태의 거리 의미를 추측하지 않으며 명시적 검사 해제만 허용한다.

## 5. 최적화·주석

기존 immutable228 catalog와 full numeric 조회를 재사용한다. hover에서 I/O/bitmap을
추가하지 않고 현재 UNIT 수에 O(n), 작업 메모리 O(1)로 계산한다. 프리셋 변경은
모든 boolean을 원자적으로 설정해 중간 상태의 불필요한 조회를 피한다. getter는
자료/정책 가용성만 보고 매 UI rebuild에서 전체 UNIT를 스캔하지 않는다. 대규모
맵의 FPS 개선 수치는 미측정이며 게임 인수나 릴리스 성능 통과로 주장하지 않는다.

## 6. 실행·결과 분석

원시 로그는 ignored `.dart_tool/resource_policy_*.log`다. SDK는 Flutter3.47.5 stable /
Dart3.13.4이며 기준 Flutter3.44.8/Dart3.12와 다르다.

초기 기존 회귀는190통과/8skip였다. 신규 시나리오를 추가한 집중 실행에서 통합 테스트
파일의 진단 클래스 import 누락1건을 수정했고, 재실행156통과/10skip을 확인했다.
초기 analyze의 multiline if 블록 스타일3건도 수정하여 최종 No issues를 확인했다.
제품 동작을 완화해서 테스트를 통과시키지 않았다.

새 로컬 선택 테스트 추가 후 전체 실행에서 미수정 `chk_editor_terrain_test.dart`가
`Connection closed before test suite loaded`로 로드 실패1건을 보고했다. assertion
실패가 아닌 테스트 실행 연결 종료였고, 파일 변경 없이 단독5통과를 확인했다.
원인은 확정하지 않았다. 빌드와 겹치지 않는 전체 재실행의 결과를 최종 게이트로 기록한다.

| 게이트 | 결과 |
| --- | --- |
| domain/application/진단/Save As 집중 | **156통과/10skip**, exit0 (`resource_policy_focused_final.log`) |
| 실제 로컬 DAT·graphics/native MPQ 포함 application/integration | **150통과**, exit0 (`resource_policy_local.log`) |
| flutter analyze | No issues, exit0 (`resource_policy_analyze_final.log`) |
| 전체 flutter test 최종 재실행 | **1525통과/57skip**, exit0 (`resource_policy_tests_retry.log`) |
| 변경 Dart13파일 format | 0변경, exit0 (`resource_policy_scoped_format.log`) |
| 전체 format lib/test/tool | 459파일 중 기존3파일 차이만 exit1 (`resource_policy_format.log`) |
| Windows Debug build | 성공, exit0 (`resource_policy_windows.log`) |
| native CTest | **7/7통과**, exit0 (`resource_policy_ctest.log`) |

실제 로컬 DAT 테스트는 full228과 graphics Unit106 기지 후보 및 자체 작성 Unit188
gas UNIT로 근접 거절/먼 위치 허용·Undo byte-exact 복원을 확인했다. 같은 실행에서
기존 실제 MPQ 설정 Save As/재열기 회귀도 통과했다. 새 자원 정책 Save As 시나리오는
합성 archive 경로이며 실제 MPQ에 대한 전체 자원 배치/게임 인수와 구분한다.

전체 format의 기존 미수정 파일은 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
이번 범위에서 기존 작업을 보존하고 정규화하지 않았다. CascLib의 기존 CMake
deprecation 경고는 비치명적이었다. 기준 SDK 재검증·필수 전체 format 게이트가
남으므로 릴리스 승인은 아니다. skip은 환경 의존 검증으로 통과 수에 포함하지 않는다.

## 7. 인수와 다음 단위

사용자의 자동 테스트/빌드만 진행 지시를 유지한다. 실제 앱 조작·SC:R 게임·외부 에디터는
실행하지 않는다. EP1 전체와 게임 정상 배치 모드는 완료로 닫지 않는다.
후속 [전력/크립 요구 자료와 판정 지원 계약](UNIT_ENVIRONMENT_REQUIREMENTS.md)을 추가했다.
동적 게임 상태와 로컬 기본 요구 flag를 분리했으며 실제 차단은 연결하지 않았다.
다음은 순수 power mask 판정과 공급자 지원 범위다. unit-sprite 관계/터렛 예외와
게임/외부 인수도 별도다.
