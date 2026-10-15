# 초기 크립 자료와 읽기 전용 요구 판정

후속 [앱 계층 크립 조회](UNIT_CREEP_INSPECTION.md)에서 문서/자료 수명과 명시적
inspection API를 연결했다. 아래는 순수 판정/포트 단계 기록이며 실제 collector는 여전히 없다.

2026-10-15. EP1/FR-218의 제한 구현이다. 타일별 크립 관찰 자료, 현재 문서·출처에
결합하는 수집 포트 계약과 **크립을 요구하는 후보의 순수 footprint 검사**를 추가했다.
앱의 조회 controller·수집기·체크박스·배치 차단·미리보기 색상은 아직 연결하지 않았다.
현재 사용자가 사용하는 배치 정책과 크립 미구현 지원표는 바뀌지 않는다.

## 1. 실행 계획과 소스 분석

1. 요구 flag와 실제 영역을 구분하고 초기/동적 상태의 신뢰 경계를 확인한다.
2. immutable 타일별 있음/없음/미확인과 크기·자료 예산을 구현한다.
3. 같은 DAT 후보의 StarEdit 박스와 최종 좌표로 양의 요구만 검사한다.
4. 명시적 수집 포트에 문서/session/revision·설치·자료 identity·모델 계약을 둔다.
5. 합성·경계·출처·무변경 회귀, 필수 게이트와 Windows 빌드를 실행한다.
6. 앱 수명·실제 관찰·UI 정책·게임 인수를 완료와 구분해 인계한다.

현재 코드의 `UnitEnvironmentProfile`은 DAT bit17 요구 자료다. `TerrainPlacementSnapshot`의
CV5/VF4 건설/이동 자료나 MTXM 그림, 기존 UNIT의 위치는 현재 크립을 증명하지 않는다.
전력의 Pylon 설계 projection을 크립 생성 반경으로 바꾸어 재사용하지 않는다.

이번에 다시 읽은 primary source는 BWAPI 고정 revision
`d727fed68558c506163048ea889131d8cbb33915`다.

- [Templates.h L162-L168, L230-L243](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/Shared/Templates.h#L230-L243):
  건물의 타일 박스를 순회하며 요구/부재를 비교한다. 크립 비요구 Zerg 예외도 있으므로
  `requiresCreep=false`만으로 금지/허용을 결정할 수 없다. 가스 건물은 그보다 앞선 별도 경로다.
- [GameImpl.cpp L402-L408](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPI/Source/BWAPI/GameImpl.cpp#L402-L408):
  완전한 맵 정보가 없고 보이지 않으면 `hasCreep`은 false를 반환한다. 따라서 수집기가
  그 false를 곧바로 ‘관찰된 부재’로 저장하면 안 된다. 관찰하지 못한 타일은 unknown이다.

이는 참고 구현의 관찰 계약이다. SC:R에서 직접 확인한 결과나 BWAPI의 SC:R 연동을
입증하는 자료가 아니다. 초기 상태를 정적 CHK만으로 추측하는 collector는 추가하지 않는다.

## 2. 구현한 자료·판정 계약

| 항목 | 계약 |
| --- | --- |
| `UnitCreepCoverage` v1 | 폭/높이 1..256, 정확히 width*height개 row-major 32px 타일. 상한 검증 후 defensive copy |
| `UnitCreepTile` | present/absent/unknown. 숨김·미관찰은 unknown, 범위 밖 조회도 unknown |
| `UnitCreepCatalog` | 같은 ID의 immutable DAT 후보 집합. 요구 flag·관련 역할·geometry 출처 사실 일치 검사 |
| 규칙 revision | `positive-creep-tile-footprint-v1` |
| 양의 요구 | requiresCreep=true인 지원 지상 건물의 전체 StarEdit 박스와 겹치는 모든 타일 검사 |
| 좌표 | caller의 최종 pixel 중심. 추가 snap 없음, half-open 박스의 right/bottom은 제외. 미정렬 좌표는 걸친 모든 타일 포함 |
| 미확인 우선 | footprint 안 unknown이 하나라도 있으면 unavailable. absent와 스캔 순서가 달라도 같음 |
| 대상 아님 | 검증된 requiresCreep=false는 이 양의 요구만 notApplicable. 크립 위 배치 허가 아님 |
| 다른 규칙 | psi·겹침·지형·가스·종족별 크립 금지/면제·EUD override는 이 판정이 승인하지 않음 |
| 안전 범위 | 맵 DIM/coverage 크기 일치, 전체 박스 경계, 4096타일 검사 예산. 극단 int 좌표도 거절 |
| 미지원 상태 | 비건물·subunit·flying building/Flyer·관계형·가스 예외 후보는 stateUnsupported |
| 쓰기 | 기존 UNIT/THG2/CHK/리소스/Undo를 변경하지 않음 |

반환값은 covered/missing/notApplicable/unavailable/stateUnsupported/outOfBounds다.
covered도 양의 크립 요구만 충족한다는 뜻이다. 원본 파일 저장/배치 승인은 아니다.
현재 자료가 없으면 unavailable이며 모든 타일 absent를 임의 생성하지 않는다.

## 3. 출처와 명시적 수집 포트

`UnitCreepStateGateway`는 read/cancel 인터페이스만 존재한다. bootstrap이나 native
helper에 실제 구현을 등록하지 않았다. hover/preview/Apply에서 호출되지 않는다.

- Request는 operation ID, immutable session, documentRevision, 설치 경로,
  기존 power와 같은 `(product, build, helper, CascLib)` tuple, 명시적 모델을 보관한다.
- `isCurrentFor`는 session identity·문서 revision·설치·자료 tuple을 전부 비교한다.
  Undo로 바이트가 같아져도 revision이 다르면 이전 응답을 재사용하면 안 된다.
- Snapshot은 정확한 request 객체를 echo하고 provider ID·관찰 revision·model·규칙
  revision·coverage를 전달한다. `coverageFor(currentRequest)`는 잘못된 echo, 빈 출처,
  모델/revision/크기 불일치, DIM 누락/중복, 제한 문서를 거절한다.
- `initialMap`만 이 단계의 검증 대상이다. `live`는 enum으로 예약하되 항상 거절한다.
  live를 initialMap으로 fallback하지 않으며 frame/observer freshness는 후속 계약이다.
- ReadResult의 isSuccess는 transport 성공일 뿐이다. 앱 consumer는 현재 request인지
  먼저 확인하고 `coverageFor`로 검증한 자료만 순수 판정기에 전달해야 한다.

이 echo/메타데이터 검사는 collector의 신뢰성을 증명하지 않는다. 실제 수집기의 초기
시점·관찰 권한·시야·완전성·runtime/EUD 대응을 검증하기 전에는 프로덕션 상태로 쓰지 않는다.
출처가 올바르다는 이유만으로 미확인 타일을 present/absent로 승격하지 않는다.
실제 비동기 controller의 취소/늦은 응답/문서 수명 연결은 다음 작업이다.

## 4. 요구사항·시나리오 체크리스트

새 테스트 80개를 추가했다. 합성 관찰 자료이며 실제 크립 수집/게임 실행 테스트가 아니다.

| 시나리오 | 결과/기대 |
| --- | --- |
| row-major·원본 List 변경·수정 차단 | snapshot 불변·3상태 보존 |
| coverage 크기/길이·상한·지도 DIM 불일치 | 잘못된 자료 거절·unavailable |
| present/absent/unknown·null snapshot | covered/missing/unavailable 구분 |
| absent 전/후 unknown·footprint 밖 unknown | 순서 독립·검사 영역 한정 |
| half-open 경계·1px 이동·홀짝 크기 | 참조 pixel 순회와 729개 좌표/박스 조합 일치 |
| 맵 가장자리·밖·최대 정수 좌표 | 전체 박스 경계와 overflow 전 가드 |
| DAT ID/profile/geometry/role 차이 | unavailable·false 요구로 보정하지 않음 |
| 특수 후보·no-creep·psi/creep 양쪽 요구 | 미지원/양의 요구 대상 아님/독립 판정 |
| 4096타일 예산 경계·256x256 자료 | 상한 내 검사·초과 unavailable |
| request identity·재열기·revision·Undo token·설치/tuple 변경 | 오래된 observation 거절 계약 |
| 빈 provider/revision·잘못된 규칙·live/초기 모델 혼동 | coverageFor=null |
| DIM 누락/중복·제한 문서·transport 성공만 존재 | 신뢰 가능한 자료로 승격하지 않음 |
| 합성 포트 read/cancel·UNIT/문자열/unknown bytes·dirty | 부작용 없이 유지 |

## 5. 최적화와 주석

타일 자료는 최대 65,536개를 한 번 복사해 공유한다. 매 판정은 footprint의 k타일만
O(k), 추가 메모리 O(1)로 읽고 k<=4096 예산을 둔다. 전체 맵/UNIT 스캔, 새 I/O,
bitmap 생성이나 hover cache는 추가하지 않았다. unknown 우선·반열린 박스·출처와
실제 관찰 신뢰의 차이를 코드 주석으로 설명한다. 속도 향상/FPS 실측은 이번 범위 밖이다.

## 6. 실행·결과

원시 로그는 ignored `.dart_tool/creep_contract_*.log`다.

| 실행 | 결과 |
| --- | --- |
| 새 domain/application 집중 테스트 | 80통과·실패/skip 없음 |
| `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 1,802통과·59skip·exit0 |
| 변경 Dart 5파일 format | 0변경·exit0 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 474파일 중 기존 3파일 차이·exit1 |
| `flutter build windows --debug` | 성공·exit0. 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| `git diff --check` | 통과 |

이번 구현에서 실패한 기능/테스트는 없었다. 59skip은 통과로 계산하지 않으며
로컬 설치/EUD 등 선택적 실행이 필요한 기존 테스트다. native 구현·외부 프로세스·
실제 자료 조회 경로를 바꾸지 않아 별도 로컬 CASC 수집 스모크는 실행하지 않았다.
새 초기 크립 collector 자체가 없으므로 실제 크립 연동을 검증했다고 해석하면 안 된다.

전체 format은 기존 미수정 3파일(`local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`)의
차이로 exit1이다. 실행 SDK Flutter3.47.5/Dart3.13.4는 기준3.44.8/3.12와 다르다.

## 7. 인수와 다음 작업

이 단위의 완료는 순수 판정과 수집 포트 계약이다. EP1 전체·실제 초기 크립 collector·
정상 배치 모드 완료가 아니다. 사용자 지시에 따라 자동 테스트/빌드만 진행하며 실제
Windows 앱·SC:R·외부 에디터는 조작하지 않는다. 신규 자산/맵 fixture도 추가하지 않는다.

다음은 이 포트를 앱의 문서/자료 수명에 연결하고 명시적으로 조회한 검증 snapshot을
최종 좌표로 읽는 read-only inspection이다. 실제 collector와 비요구 후보의 금지/면제
자료·live 관찰·UI/배치 차단·게임/외부 인수는 각각 근거를 확보한 뒤 연결한다.
