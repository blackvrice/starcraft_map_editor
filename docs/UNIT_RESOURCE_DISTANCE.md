# 자원·기지 거리 자료와 순수 판정

2026-10-14. EP1/FR-218의 다음 제한 구현이다. classic DAT의 자원·기지 분류와
**두 collision 영역의 순수 거리 판정**을 추가했다. 실제 UNIT 배치/ghost/프리셋
차단에는 아직 연결하지 않았다. 현재 UI 지원표의 자원 거리 `미구현`은 배치 정책
연결을 뜻하며 기존 배치·Undo·CHK/저장 동작은 유지한다.

2026-10-15 후속 [현재 UNIT aggregate와 application 조회](UNIT_RESOURCE_DISTANCE_AGGREGATE.md)를
구현했다. 아래는 기반 단위의 당시 결과다.
이어서 [실제 배치 정책](UNIT_RESOURCE_DISTANCE_POLICY.md)을 연결했다. 현행 checkbox/
preview/Apply 지원 범위는 후속 문서를 따르고 아래 결과는 기반 단위의 당시 검증이다.

## 1. 실행 계획과 소스 분석

1. 기존 capability/native reader·엄격한 decoder·충돌 영역을 조사한다.
2. 고정 primary source로 DAT 분류와 거리 계산/예외 경계를 확인한다.
3. optional version1 resource profile과 일관성 검사를 추가한다.
4. 알려진 두 영역만 판정하는 순수 함수를 구현하고 unknown/경계를 구분한다.
5. 합성/native/process·실제 로컬 자료·전체 게이트와 미실행 범위를 기록한다.

근거는 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[Unit flags](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h)와
[isValidUnitPlacement 거리 검사](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L2298-L2353)다.
웹 도구 raw 조회는 cache miss였으며 같은 고정 URL의 읽기 전용 HTTP로 원문을 확인했다.
`ResourceDepot=BIT_12`, `ResourceContainer=BIT_13`이다. 거리 검사 이름에 mineral이
있더라도 실제 분기는 모든 ResourceContainer flag를 사용한다. 광물 ID만으로
좁히거나 gas/refinery를 임의로 제외하지 않는다.

참고 구현은 collision extent를32px 타일 영역으로 환산하고 기존 상대 영역을
각 방향으로3타일 확장하여 닫힌 사각형 겹침을 검사한다. 96px 중심 반경이나
Euclidean 거리로 바꾸지 않는다. depot 후보를 먼저, resource 후보는 else-if로
검사한다. 같은 후보에 두 flag가 모두 있으면 원래 flag를 보존하고 이 우선순위를 따른다.

## 2. 구현 계약

| 항목 | 현재 계약 |
| --- | --- |
| native | 기존 classic units.dat 19876byte, offset7032 + ID×4의 동일 flags buffer 재사용 |
| 새 flag | `is_resource_depot`, bit12만 독립 판독. bit13/Building/Flyer를 대입하지 않음 |
| 전달 | `capability.resourceProfile={version:1,isDepot:boolean,isResource:boolean}` |
| 버전 | protocol3/helper0.13.0의 additive optional field, 새 연산/프로세스 없음 |
| domain | `UnitResourceProfile`, immutable/Flutter·I/O 비의존 |
| 누락/null | profile=null, 비기지/비자원으로 추정하지 않음; 기존 factory는 유지 |
| 잘못된 profile | version/object/boolean/missing field·기존 ResourceContainer와 불일치면 invalidResponse |
| 모델 일관성 | resourceProfile.isResource와 isResourceContainer가 다르면 constructor 거절 |
| depot/Building | 임의 논리 제약 없음. 사실인 bit를 다른 분류로 재작성하지 않음 |
| factory | 기존 resourceAmount/gas·valid/state defaults 유지, 추가 profile이 UNIT bytes를 바꾸지 않음 |
| 출처 | 기존 request/설치/product/build/helper/CascLib 식별과 결합, 런타임/EUD override 자료 아님 |

원시 DAT/추출 그림/사용자 맵 fixture는 추가하지 않는다. metadata-only와 graphics
경로에서 같은 UnitCapability를 읽으며 관련 이미지의 존재로 자원 역할을 추정하지 않는다.

## 3. 순수 Pair 판정

`UnitResourceDistance.checkPair`의 입력은 nullable 두 역할/profile에서 계산한
닫힌 collision bounds와 맵 크기1~256tile이다. 후보는 새 UNIT 역할이라는 전제이며
문서 스캔·기존 UNIT flight state·EUD 변경·source 일치는 이 함수의 책임이 아니다.

1. 후보 역할 미확인은 `unavailable`이다. 확인된 후보가 두 역할 모두 아니면 `notApplicable`.
2. 관련 후보의 상대 역할이 미확인이면 `unavailable`. 상대가 보완 역할이 아니면 `notApplicable`.
3. 관련 pair의 DIM/geometry 누락은 `unavailable`. 전체 collision 영역이 맵 밖이면 `outOfBounds`.
4. 각 legal axis의 min/max를32로 나눈 타일 인덱스를 계산한다. 상대 영역을3타일 확장한다.
5. 닫힌 두 타일 사각형이 닿으면 `tooClose`, 그 밖은 `clear`다.

이미 legal/nonnegative 영역만 나누므로 Dart `~/`와 참고 C++의 나눗셈이 같다.
참고 구현의 맵 밖 footprint clamp는 복제하지 않는다. buffer 자체를 clamp하지
않아도 legal 후보의 겹침 결과는 같다. 마지막 legal pixel은 `width*32-1`이다.
StarEdit building box를 collision 크기로 대입하지 않으며 중심만 확인하지 않는다.

예: 상대 point의 tile이5일 때 buffer는2~8이다. 후보 pixel287은 tile8이라
`tooClose`, pixel288은 tile9라 `clear`다. tile별 대각선도 사각형 검사이며
중심 직선거리로 clearance를 설명하지 않는다.

`notApplicable`은 해당 pair의 거리 검사 대상이 아니라는 뜻이지 구조·맵 경계가
안전하다는 뜻이 아니다. 역할이 이미 무관하면 geometry/DIM을 읽지 않는다.
후속 application은 공통 안전 검증을 먼저 수행해야 하고 어떤 enum 결과도
전체 UNIT 배치를 단독으로 승인하지 않는다.

## 4. 요구사항 및 시나리오 체크리스트

| 시나리오 | 증거 |
| --- | --- |
| bit12/13 독립·neither/depot/resource/both | native228항목 stride/최종ID와 process4종 role |
| old/null·잘못된 version/object/bool/missing·flag 불일치 | metadata/graphics fake process 회귀 |
| 역할16조합·두 flag 우선순위·무관/unknown | 순수 domain 회귀 |
| 닫힌 tile 변·95/96/127/128/159px·대각선 | 중심 반경으로 오판하지 않는 회귀 |
| 비대칭 extent·1px tile 경계 변화 | 전체 영역 회귀 |
| 역할/geometry/DIM 누락·초과·맵 밖·최종 pixel | unavailable/outOfBounds·clamp 금지 회귀 |
| 기존 생성 바이트/defaults | optional profile 전후 UNIT byte-exact 및 기존 factory 전체 회귀 |
| 실제 local classic228·graphics 출처 동일 | native helper → strict decoder, 실제 profile/geometry pair |
| preview/Apply·UI 체크박스·전체 UNIT/Undo·게임/외부 인수 | 이번 미연결, 다음 단계 |

## 5. 최적화와 주석

native는 이미 읽은 u32 flags의 bit12만 추가 계산한다. 추가 자산 읽기/bitmap/IPC
연산은 없다. domain pair 판정은 역할/4축 정수 연산으로 O(1)이며 맵 전체 스캔을
하지 않는다. FPS/메모리 개선 수치는 측정하지 않았다. depot-first와 타일 사각형,
미확인 역할·기존 flag 일관성 경계에 짧은 주석을 남겼다.

## 6. 실행·결과 분석

원시 로그는 ignored `.dart_tool/resource_distance_*.log`다. 실제 SDK는
Flutter **3.47.5 stable / Dart3.13.4**, 기준은 **3.44.8 / 3.12**다.

| 검증 | 결과 |
| --- | --- |
| domain/factory/process 집중 | **143통과/2skip**, exit0 (`resource_distance_focused.log`) |
| 실제 로컬 설치 포함 process 전체 | **62통과**, exit0 (`resource_distance_local.log`) |
| flutter analyze | No issues, exit0 (`resource_distance_analyze.log`) |
| 전체 flutter test | **1446통과/56skip**, exit0 (`resource_distance_tests.log`) |
| 변경 Dart7파일 format | 0변경, exit0 (`resource_distance_scoped_format.log`) |
| 전체 format lib/test/tool | 456파일 중 기존3파일 차이만 exit1 (`resource_distance_format.log`) |
| Windows Debug build | 성공, exit0 (`resource_distance_windows.log`) |
| native CTest | **7/7통과**, exit0 (`resource_distance_ctest.log`) |

실제 로컬 테스트는228개의 profile consistency, Unit106 기지/Unit188 gas 역할,
Unit0 비기지와 graphics/metadata 출처·역할 일치, 실제 extent의 근접/비근접 pair를
확인했다. 게임 엔진의 배치 제한을 관찰한 것이 아니다.

전체 format 차이는 기존 미수정 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자/기존 변경을 보존하고 이번 범위에 넣지 않았다. CascLib의 기존 CMake
deprecation 경고는 비치명적이었다. 기능/테스트 실패는 이번 실행에서 없었다.
skip은 실제 도구·별도 환경 검증이고 통과로 계산하지 않는다. 기준 SDK 재검증과
필수 전체 format 게이트가 남아 있으므로 릴리스 승인 완료가 아니다.

사용자의 이번 **자동 테스트와 빌드만 진행** 지시를 유지해 앱 조작·SC:R 게임·
외부 에디터는 실행하지 않았다. 기존 객체/원본 맵/복구 자료는 변경하지 않았다.

## 7. 다음 구현 단위

현재 UNIT snapshot과 후보 source를 일치시켜 역할/geometry·지원 상태를 검사하는
[read-only aggregate](UNIT_RESOURCE_DISTANCE_AGGREGATE.md)를 후속 구현했다. 미확인
UNIT를 거리만 보고 무시하지 않으며 raw flight/예외 상태를 추측하지 않는다.
이어서 [실제 자원 거리 정책](UNIT_RESOURCE_DISTANCE_POLICY.md)의 최종 preview/Apply,
checkbox/프리셋·지원표를 연결했다. 다음은 전력/크립 요구 자료 조사·계약이며 EUD
override·게임 인수는 계속 별도다. 기반 자료 단위의 결과로 EP1 전체를 완료 표시하지 않는다.
