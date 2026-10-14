# 현재 UNIT의 자원 거리 검사

2026-10-15. EP1/FR-218의 제한 구현이다. [역할·pair 기반](UNIT_RESOURCE_DISTANCE.md)에
현재 UNIT 전체를 결합하는 순수 aggregate와 source-aware application 조회를 추가했다.
**읽기 전용 검사만 구현**했으며 실제 배치 차단, ghost, checkbox/프리셋은 다음 단위다.
`clear`/`notApplicable`을 전체 배치 허용이나 게임 동작 보증으로 해석하지 않는다.

## 1. 계획과 분석

1. 기존 `UnitCollisionCatalog`의 immutable metadata와 controller의 전체228항목 조회,
   출처/product/build/helper/CascLib·epoch·취소 경계를 조사한다.
2. 고정 Chkdraft primary source와 기존3tile pair 계약을 재확인하고 지원 범위를 정한다.
3. 순수 aggregate의 우선순위·미확인·비행·경계를 구현한다.
4. 공통 사전 검증과 최종 정렬 좌표를 재사용하는 읽기 전용 application 조회를 연결한다.
5. 요구사항/시나리오 회귀, 실제 로컬 숫자 자료, 전체 자동 테스트와 Windows 빌드를 기록한다.

참고 원문은 [고정 Chkdraft 거리 검사](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L2298-L2353)다.
웹 raw 조회의 cache miss 후 같은 URL의 읽기 전용 HTTP로 다시 확인했다.
역할 flag와 collision extent 기반3tile 사각형 검사를 유지한다. 참고 소스의 거리
루프에는 비행 상태 분리가 없다. 아래 비행 거절은 **우리 프로그램의 보수적인 지원
범위**이며 참고 에디터/게임의 실제 제한이라고 주장하지 않는다. 보호/손상/EUD
상태를 자동 복구하거나 현재 raw UNIT의 상태를 재작성하지 않는다.

## 2. 구현 계약

`UnitResourceDistanceCatalog`는 capability map을 복사해 고정하고 key/unitId 불일치를
거절한다. 입력은 후보 capability·최종 중심·DIM·현재 `ChkUnitPlacement` iterable이다.
Flutter, 파일 시스템, native/helper에 의존하지 않는다.

| 대상 | 계약 |
| --- | --- |
| 후보 출처 | 같은 ID의 snapshot 역할 두 flag와 Building/FlyingBuilding/subunit/relation 일치 |
| 확인된 비대상 후보 | 두 역할 모두 false면 notApplicable; 일반 배치 안전 검증은 별도 |
| 관련 후보 | collision4축/Flyer 일치, DIM1~256, 전체 collision bounds 경계 |
| 새 후보 flight | 기본 ground state; 관련 Flyer 후보는 stateUnsupported |
| 기존 UNIT 자료 | 누락 ID/role/geometry/subunit은 멀리 있어도 metadataUnavailable |
| 기존 inTransit | bit4이면 Building/FlyingBuilding/validState bit4를 모두 확인 |
| 잘못된 inTransit | 역할과 무관하게 stateUnsupported; raw 상태를 보정하지 않음 |
| 관련 flying/lifted UNIT | 정적 ground만 지원하므로 stateUnsupported |
| 확인된 무관 UNIT | 거리 pair에서 제외; 정상 flight와 무관 bounds로 거리 위반을 만들지 않음 |
| 관련 역할 | depot-first, resource 후보의 상대는 depot; both flag를 보존 |
| 범위 | owner/resourceAmount=0/gas 여부로 ResourceContainer를 제외하지 않음 |
| map 경계 | 후보 및 관련 ground 상대의 전체 bounds; clamp·center-only 금지 |
| 결과 우선순위 | metadataUnavailable > stateUnsupported > outOfBounds > tooClose > clear |

알려진 tooClose를 먼저 발견해도 전체 iterable을 계속 확인한다. 더 뒤에 미확인
자료가 있으면 위반보다 검증 불가가 우선이며 UNIT 나열 순서에 의존하지 않는다.
`notApplicable`은 대상 판단으로 조기 반환하며 다른 맵 검사의 성공을 뜻하지 않는다.

## 3. Application 조회

`PlacementCatalogController.inspectUnitResourceDistanceAt(pixelX, pixelY)`는 다음을 따른다.

1. 선택이 일반 UNIT가 아니면 notApplicable이며 조회/배치를 시작하지 않는다.
2. `_previewAt(checkPolicies:false)`로 공통 세션/기록/레이어/좌표/factory 안전 검증을 수행한다.
3. `resolvePoint`의 스냅 또는 건물 정렬 후 좌표도 사전 검증하고 DIM/현재 UNIT를 읽는다.
4. 선택 그래픽 자료의 출처 tuple과 full numeric snapshot 출처가 일치할 때만 aggregate를 호출한다.
5. 결과 DTO에 typed check 또는 공통 issueCode와 검사한 point를 반환한다.

조회는 선택/오류 상태·문서·Undo/Redo를 변경하지 않고 프로세스를 시작하지 않는다.
선택적 겹침/지형 옵션을 이 조회에 혼합하지 않으며 실제 preview/Apply는 기존 정책을
계속 검사한다. 비대상/불가/성공을 하나의 null로 표현하지 않는다.

기존 `loadCollisionMetadata()`의 coalesced228 metadata-only 요청에서 두 catalog를
함께 생성한다. 별도 포트/IPC/asset read를 추가하지 않는다. 재조회/설치 변경/맵 세션
변경/출처 변화/폐기에서 둘 다 무효화하고 stale 응답을 버린다. current UNIT 편집과
Undo/Redo는 같은 numeric 자료를 재사용하되 문서 snapshot을 매번 다시 읽는다.
구 helper의 resourceProfile 누락은 unknown이며 비기지/비자원으로 추정하지 않는다.

## 4. 요구사항 체크리스트

| 요구사항·시나리오 | 구현/증거 |
| --- | --- |
| depot/resource/both/neither·3tile 닫힌 경계 | domain aggregate 양방향/우선순위 회귀 |
| 후보/source 역할·4축·Flyer·사용 flag 불일치 | domain 및 fake numeric/graphics 회귀 |
| extendedID/누락/geometry/subunit이 멀리 존재 | unknown 우선과 역순 회귀 |
| flight/invalid validState·grounded liftable | stateUnsupported/지원 범위 회귀 |
| empty UNIT·DIM·extent·관련 맵 밖·무관 UNIT | 경계/무관 대상 분리 회귀 |
| 다른 owner·gas·고갈 자원 | flag 분류 유지 및 원시 byte-exact 회귀 |
| 현재 UNIT 추가/Undo/Redo | 같은 metadata1회, 최신 문서 재판정 회귀 |
| raw/final point·건물 정렬·레이어 잠금 | 공통 issueCode와 최종 좌표 회귀 |
| 프로세스 미시작·상태/Undo 무변경 | 반복 조회와 비UNIT 선택 회귀 |
| source mismatch/coverage/role/geometry | unknown 후 명시적 reload 회복 |
| 설치/세션/dispose 중 pending 요청 | 취소 및 stale 폐기 회귀 |
| 실제 로컬 classic DAT 및 graphics 후보 | full228 snapshot/자체 작성 UNIT188/near-far aggregate |
| 실제 배치 정책·checkbox/ghost·게임 인수 | 이번 미연결/미실행, 완료 처리하지 않음 |

## 5. 최적화와 주석

228개 capability snapshot을 기존 metadata load 시 한 번 생성하고 hover마다 map을
복사하거나 bitmap/IPC를 만들지 않는다. 각 검사는 현재 UNIT 수 n에 O(n), 추가
작업 메모리는 O(1)이며 일치한 역할만 pair 정수 계산을 수행한다. 미확인 자료를
무시하는 거리 기반 pruning은 하지 않는다. 재판정 경계가 명확해지는 것에 우선순위를
두며 FPS/대규모 맵 지연 개선 수치는 측정하지 않았다. 우선순위·비행 지원 범위·공통
사전 검증 이후 snapshot 접근에만 짧은 주석을 추가했다.

## 6. 실행과 결과

원시 로그는 ignored `.dart_tool/resource_aggregate_*.log`다. 실제 SDK는
Flutter **3.47.5 stable / Dart3.13.4**, 기준은 **3.44.8 / Dart3.12**다.

첫 집중 실행은168통과/8skip/1실패였다. 실패는 새 테스트가 기존 UNIT 지형 전용
진단 `unitTerrainUnavailable` 대신 Doodad 등의 공통 `terrainUnavailable`을 기대한
테스트 오류였다. 기대 코드를 수정했으며 기존 제품 진단 코드는 바꾸지 않았다.

| 검증 | 최종 결과 |
| --- | --- |
| domain/application 집중 재실행 | **169통과/8skip**, exit0 (`resource_aggregate_focused_final.log`) |
| 실제 로컬 설치 포함 process 전체 | **62통과**, exit0 (`resource_aggregate_local.log`) |
| flutter analyze | No issues, exit0 (`resource_aggregate_analyze.log`) |
| 전체 flutter test | **1508통과/56skip**, exit0 (`resource_aggregate_tests.log`) |
| 변경 Dart6파일 format | 0변경, exit0 (`resource_aggregate_scoped_format.log`) |
| 전체 format lib/test/tool | 459파일 중 기존3파일 차이만 exit1 (`resource_aggregate_format.log`) |
| Windows Debug build | 성공, exit0 (`resource_aggregate_windows.log`) |
| native CTest | **7/7통과**, exit0 (`resource_aggregate_ctest.log`) |

실제 helper의 전체228 profile을 검사 snapshot으로 사용하고 graphics Unit106 후보와
자체 작성한 Unit188 gas UNIT의 근접/비근접 결과를 확인했다. 다른 owner를 제외하지
않으며 원시 CHK 바이트는 그대로다. SC:R 게임의 배치 제한을 관찰한 것은 아니다.

전체 format 차이는 기존 미수정 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자/기존 작업은 보존하고 이번 범위에 포함하지 않았다. CascLib의 기존 CMake
deprecation 경고는 비치명적이었다. 수정 이후 실행에서 기능/테스트 실패는 없었다.
skip은 외부 도구/환경 의존 검증이며 통과로 계산하지 않는다. 기준 SDK 재검증과
필수 전체 format 게이트가 남으므로 릴리스 승인 완료가 아니다.

사용자의 **자동 테스트와 빌드만 진행** 지시로 실제 앱 조작·게임·외부 에디터는
실행하지 않았다. 사용자 원본 맵·복구 자료·선택/Undo 기록은 수정하지 않았다.

## 7. 다음 단위

현재 read-only 검사와 최종 preview/Apply를 공통 경로에서 연결하고 명시적 자원 거리
checkbox(기본 꺼짐), 프리셋/custom·자료 지원표·진단 한영 안내를 추가한다. 상태/metadata
불가를 단순 거리 위반으로 표현하지 않고, 거절 시 문서/Undo 무변경과 Save As 왕복을
검증한다. 대규모 profile·전력/크립·EUD 변경·PAR-01~03 게임/외부 인수는 별도다.
