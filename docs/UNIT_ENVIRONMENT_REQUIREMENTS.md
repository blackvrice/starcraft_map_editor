# 전력·크립 요구 자료와 지원 계약

2026-10-15. EP1/FR-218의 다음 제한 구현이다. 로컬 classic DAT의 전력/크립
**요구 flag 조회**를 구현했다. 실제 공급 영역/현재 크립 판정, 체크박스·배치 차단은
연결하지 않았다. 기존 자원/지형/겹침 정책·UNIT bytes·UI의 전력/크립 미구현 표시는 유지한다.

## 1. 실행 계획과 소스 분석

1. 고정 primary source에서 요구 flag와 공급/생성/현재 맵 상태를 구분한다.
2. 기존 native capability의 같은 DAT flags buffer와 metadata/graphics 전달을 재사용한다.
3. optional version1 profile·엄격한 decoder·누락 unknown과 기존 바이트 보존을 구현한다.
4. 후속 전력/크립 판정에 필요한 입력/지원 범위·unknown 정책을 문서화한다.
5. 합성/native/process·실제 로컬 설치·전체 자동 테스트와 Windows 빌드를 검증한다.

조사 결과는 다음 고정 공식 소스에 근거한다. 런타임 참고 구현을 SC:R 전체 동작
관찰로 취급하거나 소스의 결과를 사용자 맵에 자동 적용하지 않는다.

- Chkdraft `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
  [DAT flags](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L400-L432):
  CreepBuilding=bit17, Unused=bit18, RequiredPsi=bit19. 기존 classic 배열 offset7032를 재사용한다.
- BWAPI `d727fed68558c506163048ea889131d8cbb33915`의
  [UnitType 요구 함수와 생성 함수](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPILIB/Source/UnitType.cpp#L2423-L2505):
  requiresCreep은 CreepBuilding, requiresPsi는 RequiresPsi flag를 읽는다. producesCreep은
  별도 함수이므로 크립 요구와 생성 역할을 동일하게 취급하지 않는다.
- 같은 revision의 [runtime query](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPI/Source/BWAPI/GameImpl.cpp#L402-L413)와
  [power/buildability 검사](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/Shared/Templates.h#L32-L65):
  전력은 공급자와 mask, 크립은 별도의 맵 상태를 사용한다. 요구 flag가 있다고 공급이
  확인된 것이 아니다. 현재 UNIT 위치나 타일 그림만으로 동적 결과를 생성하지 않는다.

특히 같은 Templates.h의 [creep 검사](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/Shared/Templates.h#L230-L247)는
요구하지 않는 건물의 크립 위 허용도 별도로 다룬다. 따라서 `requiresCreep=false`를
크립 위 배치 허용으로 해석하지 않는다. 종족·가스 건물 등 예외 자료는 이 profile의 범위가 아니다.

## 2. 구현된 자료 계약

| 항목 | 현재 계약 |
| --- | --- |
| 입력 | 기존 classic units.dat19876byte, ID0~227, offset7032+ID*4의 u32 flags |
| 전달 | `capability.environmentProfile={version:1,requiresPsi:boolean,requiresCreep:boolean}` |
| native | bit17/19 독립 판독. bit18·Building·Flyer·종족·실드·ID로 대입/재작성하지 않음 |
| version | protocol3/helper0.13.0의 additive optional field, 새 연산/외부 의존성 없음 |
| domain | immutable `UnitEnvironmentProfile`, Flutter/파일/native/process에 의존하지 않음 |
| 누락/null | profile=null, 두 요구가 false라는 뜻이 아닌 unknown; 구 helper는 계속 사용 가능 |
| 잘못된 값 | profile object/version/int/bool/missing 검증 실패는 helperInvalidResponse |
| flag 조합 | neither/psi/creep/both를 그대로 보존; 양쪽 true나 비건물 true를 추측 보정하지 않음 |
| 공급/생성 | `hasPower`, `hasCreep`, `producesCreep`, 공급자 ID/완공/소유자는 전달하지 않음 |
| 출처 | 기존 설치/product/build/helper/CascLib tuple에 귀속된 로컬 기본 자료, EUD override 아님 |
| 생성/저장 | factory 기본값/state/resourceAmount·UNIT/THG2 bytes·unknown CHK/문자열 유지 |

metadata-only와 graphics 양쪽은 같은 `AddUnitCapability`로 profile을 전달한다.
검증된 native 자료만 새 profile을 제공하고, 구 helper에서 없는 값을 이름/그림으로
보충하지 않는다. 원시 DAT·자산 그림·사용자 맵 fixture를 추가하지 않는다.

## 3. 판정 지원 범위

| 범위 | 현재 상태 / 후속 계약 |
| --- | --- |
| 요구 여부 | 구현: 로컬 DAT의 두 독립 flag. 이 결과는 좌표 통과/거절이 아님 |
| power/creep UI | 기존 미구현 유지; 새 requirement 조회만으로 검사 사용/좌표 통과로 승격하지 않음 |
| 전력 mask | 미구현: 정확한 mask·좌표 단위/anchor·경계와 공급자 목록/상태 지원 계약 필요 |
| 크립 영역 | 미구현: 믿을 수 있는 초기/동적 tile mask와 source/revision/크기 계약 필요 |
| 기존 지형 snapshot | CV5/VF4 건설/이동 자료이며 현재 크립 공급 증거가 아님 |
| EUD/동적 변경 | 미지원: runtime revision 없이 로컬 flags를 변경된 게임 상태로 표시하지 않음 |
| 게임/외부 에디터 | 인수 대기, 자동 테스트/실제 DAT 조회와 구분 |

### 3.1 다음 전력 구현의 입력과 원칙

다음 단위는 요구 조회와 분리한 **순수 읽기 전용 power mask 판정**이다. 자료/알고리즘
revision과 source를 고정하고 합성 경계 회귀를 먼저 구현한다. 아래는 계획이며 현재
타입/포트/배치 기능이 존재한다는 뜻이 아니다.

- 후보의 검증된 요구 profile·건물 여부·지원 상태·owner·최종 pixel 좌표·DIM을 받는다.
- 공급자 역할/현재 UNIT snapshot·owner·완공/disabled/hallucination/flight/valid flags의
  처리 범위를 확정한다. 누락 값과 모순된 상태를 지원되는 공급자로 추정하지 않는다.
- 참고 mask는10x16 격자다. 단순 원/사각 반경이나 충돌 박스로 대체하지 않는다.
  동일 소유자/중립/동맹 지원 범위를 명시하고 공급자가 없는 경우와 목록 불완전을 구분한다.
- source 불일치·미확인 자료·지원하지 않는 상태·맵 밖·미공급·공급·대상 아님을 구분한다.
  known 미공급보다 unknown이 우선해야 하는 범위를 순서 독립적으로 검증한다.
- 이후 application의 공통 안전 검증과 최종 정렬 좌표에 연결한다. 명시적 기본 꺼짐
  정책으로 만들고 자유 배치에서도 구조/레이어/history/좌표 안전 검사는 유지한다.
- 초기 preplaced UNIT 모델과 실제 게임의 생성/파괴/완공·EUD 동작은 다른 증거 단계다.

### 3.2 크립 구현 전 추가 조사

현재 CHK/UNIT/MTXM만으로 시간에 따른 확장/소멸 영역을 임의 생성하지 않는다.
초기 게임 생성 모델 또는 권위 있는 coverage snapshot이 확보될 때까지 unavailable로 둔다.
판정 시에는 후보 footprint의 타일 범위, 요구/금지/허용 예외, 종족/가스·특수 건물,
source와 current map revision을 함께 검증해야 한다. false 요구 flag만으로 예외를 추론하지 않는다.

## 4. 요구사항·시나리오 체크리스트

| 시나리오 | 증거 |
| --- | --- |
| bit17/19 독립·bit18 오인 방지·최종 ID | native228항목 합성 flags/stride 회귀 |
| neither/psi/creep/both·비건물 조합 보존 | fake metadata/graphics 및 domain 회귀 |
| 구 helper 누락/null | optional unknown, 기존 항목 사용 가능 |
| object/array/version 누락·문자열/소수/미지원값 | strict process 응답 거절 |
| 각 flag의 숫자/문자/null/누락 | strict process 응답 거절, false로 보정하지 않음 |
| 기존 UNIT/THG2 bytes |8조합의 UNIT, 비건물4조합 THG2 byte-exact 비교 |
| 실제 로컬228 profile | metadata-only 전체 누락 없음, graphics 후보 source/flag 일치 |
| 생성과 요구의 구분 | 실제 local Hatchery/Pylon 등 비요구와 Spawning Pool/Gateway 요구 표본 |
| 기존 배치·저장·정책 UI | 실제 처리 경로 변경 없음, 전체 회귀로 검증 |
| 현재 공급·게임 상태 | 이번 미구현/미실행, 검증 완료로 계산하지 않음 |

## 5. 최적화·주석

기존 u32 flags buffer에 두 bit 연산만 추가했다. 추가 파일/asset read/bitmap/IPC 연산은
없고 profile도 기존228 numeric metadata cache에 함께 실린다. 코드에서 요구/coverage,
크립 요구/생성, false/unknown을 구분하는 주석만 추가했다. 실측 FPS/메모리 개선이나
전체 coverage 성능을 측정했다고 주장하지 않는다.

## 6. 실행과 결과

ignored `.dart_tool/environment_profile_*.log`에 원시 결과를 남긴다. 실제 SDK는
Flutter **3.47.5 stable / Dart3.13.4**, 기준은 **3.44.8 / Dart3.12**다.

| 검증 | 결과 |
| --- | --- |
| domain/factory/process 집중 | **115통과/4skip**, exit0 (`environment_profile_focused.log`) |
| 실제 로컬 설치 포함 process 전체 | **84통과**, exit0 (`environment_profile_local.log`) |
| flutter analyze | No issues, exit0 (`environment_profile_analyze.log`) |
| 전체 flutter test | **1554통과/58skip**, exit0 (`environment_profile_tests.log`) |
| 변경 Dart5파일 format | 0변경, exit0 (`environment_profile_scoped_format.log`) |
| 전체 format lib/test/tool | 460파일 중 기존3파일 차이만 exit1 (`environment_profile_format.log`) |
| Windows Debug build | 성공, exit0 (`environment_profile_windows.log`) |
| native CTest | **7/7통과**, exit0 (`environment_profile_ctest.log`) |

전체 format은460파일 중 기존 미수정3파일 차이로 exit1이며 해당 파일은
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`다. 이번 범위에서 기존 변경을 보존한다.

실제 로컬 profile을 읽은 결과와 게임의 전력/크립 동작 관찰은 별개다.
이번 실행에서 기능/테스트 실패는 없었다. 기준 SDK 재검증·전체 format 게이트가
남으므로 릴리스 승인 완료가 아니다. CascLib의 기존 CMake deprecation 경고는
비치명적이며 skip은 통과 수로 계산하지 않는다.

## 7. 인수와 다음 작업

사용자의 자동 테스트/빌드만 진행 지시를 유지해 실제 앱 조작·SC:R·외부 에디터는
실행하지 않는다. 이번 자료 단위만 완료 처리하고 전력/크립 정책이나 EP1 전체를
닫지 않는다. 다음은 위 계약에 따른 순수 power mask 판정과 공급자 지원 범위다.
