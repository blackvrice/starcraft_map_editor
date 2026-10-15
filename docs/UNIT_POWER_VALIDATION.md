# 읽기 전용 전력 mask와 공급자 검증

2026-10-15. EP1/FR-218의 [전력·크립 요구 자료](UNIT_ENVIRONMENT_REQUIREMENTS.md)에
순수 전력 mask와 공급자 상태 aggregate를 추가했다. **명시적으로 제공된 상태**를
판정하는 도메인 단계이며 앱의 상태 공급·checkbox·ghost/Apply에는 아직 연결하지 않았다.
현재 UI의 전력/크립 미구현 표시와 기존 UNIT/정책/저장 동작을 유지한다.

## 1. 실행 계획과 분석

1. 고정 primary source에서 mask, 좌표 anchor, 공급자의 존재/완공 조건을 재확인한다.
2. numeric mask와 현재 UNIT+명시적 상태를 분리한 순수 타입을 구현한다.
3. source에 사용되는 후보 자료 일치·소유자·지원 상태·unknown 우선순위를 검증한다.
4. 전체 픽셀 경계와 합성 상태, 실제 로컬 DAT/graphics를 연결해 테스트한다.
5. analyze/format/전체 회귀/Windows/native 결과와 미실행 범위를 기록한다.

BWAPI `d727fed68558c506163048ea889131d8cbb33915`의
[mask와 power query](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/Shared/Templates.h#L32-L65)는
10x16 mask와 pixel 차이를 사용하고, 존재/완공되지 않은 공급자를 제외한다.
[tile→중심 변환](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPILIB/Source/Game.cpp#L631-L651)을
확인해 입력을 후보의 최종 pixel 중심으로 정했다. 전체 footprint의 모든 타일에
전력이 있어야 한다는 규칙을 새로 만들지 않는다. 다만 맵 경계는 StarEdit 박스 전체로 검사한다.

이 참고 구현을 SC:R 게임 관찰로 간주하지 않는다. upstream의
[LICENSE](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/LICENSE)는
LGPL3 문서임을 확인했다. 라이브러리/바이너리/소스 함수는 복사하거나 링크하지 않았다.
호환 수치 규격을 행별 구간으로 표현하고 자체 정수 판정/상태 검증을 작성했다.
이는 릴리스 법률 검토를 대신하는 진술이 아니며 출처·표현/의존성 변경은 배포 고지 검토 대상이다.

## 2. 순수 mask

`UnitPsiField`의 revision은 `classic-psi-point-v1`이다. 10개 행의 포함 column 구간은
`5..10 / 2..13 / 1..14 / 0..15 / 0..15 / 0..15 / 0..15 / 1..14 / 2..13 / 5..10`이다.
총128개의 포함 cell이며 단순 원·직사각형 반경으로 근사하지 않는다.

- 후보와 공급자의 좌표는0..65535 정수다. 범위 밖은 false이며 clamp하지 않는다.
- 후보 중심과 공급자 중심의 차이는 각각 `-256 < dx < 256`, `-160 < dy < 160`이어야 한다.
- `row=(dy+160)~/32`, `column=(dx+256)~/32`로 해당 포함 구간을 읽는다.
- offset은 guard 이후 비음수다. 음수 나눗셈 반올림이나 signed overflow에 의존하지 않는다.
- 정렬되지 않은 pixel 중심도 그대로 계산한다. snap/건물 정렬은 caller의 책임이다.
- 이 함수의 true는 기하학적 포함이지 소유권·상태·맵 경계나 배치 허용이 아니다.

외곽을 포함해515x323=166345개 상대 pixel을 독립 cell oracle과 전부 비교한다.
strict 외곽 경계를 제외한 포함 pixel 수는130752다. 정수 경계의 비대칭도 그대로 검증한다.

## 3. 명시적 공급자 상태

`UnitPowerUnitState`는 immutable `ChkUnitPlacement`와 nullable `exists/isCompleted/isEnabled`를
묶는다. 세 사실의 기본값은 unknown이다. CHK 레코드의 존재·HP%·valid flags·그림으로
완공이나 활성 상태를 채우지 않는다. 따라서 raw CHK만 전달한 Pylon은 확인 불가다.
이 타입은 입력 계약이지 상태를 수집하는 포트나 증거 저장소가 아니다.

`UnitPowerCatalog`는 capability map을 복사·고정하고 key/unitId 불일치를 거절한다.
revision은 `classic-pylon-explicit-state-v1`이며 현재 모델의 공급자는 classic Unit156 Pylon이다.
그림·종족·실드로 공급자 역할을 추정하거나 EUD로 추가된 공급자를 이 ID로 치환하지 않는다.

| 항목 | 현재 지원 계약 |
| --- | --- |
| 후보 자료 | 같은 ID의 environment 두 flag·Building/Subunit/FlyingBuilding/relation이 snapshot과 일치 |
| 비전력 후보 | 확인된 requiresPsi=false면 notApplicable, 전체 배치 안전 승인 아님 |
| 관련 후보 | StarEdit 박스와 Flyer 값의 source 일치, DIM1~256, 전체 박스 경계 |
| 후보 지원 상태 | 건물·비subunit·비FlyingBuilding·비Flyer·관계 불필요, owner0~7 |
| 후보 geometry | collision offset을 power footprint로 쓰지 않음; Flyer 여부만 사용 |
| 기존 UNIT metadata | 누락 ID/environment/subunit은 먼 거리여도 unavailable |
| 공급자 자료 | Unit156의 Building/ground·관계 없음·두 요구 flag false·64x64 박스 |
| 공급자 metadata 누락 | geometry/박스 누락은 unavailable; 알려진 비지원 profile은 stateUnsupported |
| 알려진 비존재/미완공 | 공급하지 않음, 나머지 상태 사실을 채우지 않아도 됨 |
| 소유자 | valid owner bit와0~7 필요. 알려진 다른 플레이어는 공급하지 않음; 동맹·중립 공급은 추론하지 않음 |
| 현재 플레이어의 상태 | exists/completed/enabled 모두 알려져야 함. unknown은 unavailable |
| disabled | 실제 효과를 power-off로 추측하지 않고 stateUnsupported |
| raw 상태 | 기본/유효한 무적만 지원. cloak/burrow/flight/hallucination/unknown bit·관계 데이터는 stateUnsupported |
| 공급자 경계 | 확인된 active same-owner 공급자의 박스 전체가 맵 밖이면 outOfBounds |
| 집계 우선순위 | unavailable > stateUnsupported > outOfBounds > powered/unpowered |

다른 플레이어의 known Pylon과 known inactive 공급자에는 무관한 completion/activation을
요구하지 않는다. 반면 전체 UNIT의 metadata 누락은 처음부터 unknown으로 남긴다.
공급되는 위치를 먼저 발견해도 나머지를 검사해 순서에 따라 unknown을 숨기지 않는다.
`requiresCreep=true`의 처리나 현재 크립은 이 power query의 책임이 아니다.

## 4. Source·문서 경계

이번 단계에는 application 조회 포트·UI/배치 연결을 추가하지 않았다. caller는 다음을
충족해야 하며, 이를 달성하기 전 UI를 검사 사용/통과로 표시하지 않는다.

- 선택 graphics와 numeric DAT의 설치/product/build/helper/CascLib 출처 일치.
- 완전한 현재 UNIT iterable, 상태 사실의 같은 문서/record identity·revision 귀속.
- 상태 source의 신뢰/지원 범위 확인. 외부 live snapshot과 초기 맵 분석 모델을 구분.
- Undo/Redo·설치/세션/자료 변경 시 현재 snapshot 재선택과 stale 응답 폐기.
- 공통 세션/history/레이어/factory/정확한 raw 좌표와 최종 snap 좌표의 안전 검증.

지원 상태를 주는 provider가 없으면 임의로 true/false를 채우지 않고 unknown을 유지한다.
새 checker를 읽는 것만으로 UNIT/원시 문자열·unknown CHK·Undo/복구 자료를 바꾸지 않는다.
powered는 입력 모델 안의 전력 포함 결과이지 게임 건설 가능성이나 런타임/EUD 동작 보증이 아니다.

## 5. 요구사항·테스트 체크리스트

| 시나리오 | 검증 |
| --- | --- |
|160cell·모든 인접 pixel·strict4방향 외곽 |166345개 exhaustive 비교·포함 pixel 수·1px 경계 |
| 좌표 평행 이동·비정렬 중심·과대 정수 | mask translation·입력 guard/overflow 회귀 |
| 요구·박스·Flyer·사용 flag source 불일치 | 후보 unavailable, 임의 source 허용 없음 |
| DIM/전체 박스·empty snapshot | unavailable/outOfBounds/unpowered 구분 |
| 다른 owner·중립·owner valid 누락 | 같은 플레이어 모델·지원하지 않는 소유권 구분 |
| 존재/완공/활성 각각 unknown | 알려진 공급보다 unknown 우선·raw CHK로 추측하지 않음 |
| raw flight/hallucination/unknown/relation/무적 | unsupported와 지원 상태 구분 |
| canonical 공급자 변경·누락/extendedID | unknown 또는 unsupported, ID 숫자로만 허용하지 않음 |
| UNIT 순서와 priority | unknown/state/bounds가 powered보다 우선·역순 회귀 |
| immutable map·원시 bytes | 입력 복사·key 일치와 순수 조회 byte-exact |
| 실제 로컬 DAT·graphics | full228/Pylon156/Gateway160과 합성 명시 상태로 powered/unpowered/unknown |

실제 로컬 자료 검증에서도 completion/activation 사실은 자체 작성한 합성 입력이다.
게임에서 측정하거나 CHK만 보고 추론한 것이 아니다.

## 6. 최적화와 실행 기록

mask는 O(1), catalog는 UNIT 수 n에 O(n), 추가 작업 공간은 O(1)이다. 전체 bitmap이나
공간 index를 만들지 않고10개의 고정 구간만 사용한다. hover I/O나 새 프로세스를 추가하지
않았다. 성능 향상 수치·대규모 게임 처리량은 미측정이다.

로그는 ignored `.dart_tool/unit_power_*.log`다. 초기 analyze의 multiline if 스타일1건을
수정한 뒤 아래 결과를 확인했다. Windows 빌드와 전체 테스트는 동시에 실행하지 않았다.

| 실행 | 결과 |
| --- | --- |
| mask/catalog 집중 테스트 |66통과. exhaustive pixel·합성 상태·자료 일치·byte-exact |
| `flutter analyze` | No issues |
| `flutter test --reporter expanded` |1620통과/58skip. 선택적 환경 의존 테스트는 별도 |
| 로컬 설치를 지정한 placement process suite |84통과. 실제 DAT/graphics와 합성 상태 연결 |
| `flutter build windows --debug` | 성공. 기존 CascLib CMake deprecation 경고는 비차단 |
| VS CTest Debug |7/7통과 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` |465파일 중 기존3파일 차이로 exit1 |
| 이번 변경 Dart6파일 동일 format 검사 |0변경, exit0 |
| `git diff --check` | 통과 |

전체 format의 기존 차이는 `test/infrastructure/` 아래
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`다. 이번 변경에 포함하거나 자동 정리하지 않았다.
실행 SDK는 **Flutter3.47.5 stable / Dart3.13.4**이며 기준 **3.44.8 / Dart3.12**
재검증은 남아 있다. 이 실행은 순수 판정/로컬 자료 연결의 증거이지 실제 앱·SC:R·
외부 에디터·동적 EUD 전력 동작이나 릴리스 인수를 통과한 증거가 아니다.

## 7. 다음 단위

다음은 application의 읽기 전용 power inspection과 source/document/state revision
연결이다. 권위 있는 공급 상태가 없으면 unavailable을 반환하도록 한다. 이후 명시적
기본 꺼짐 정책·checkbox·공통 preview/Apply를 연결한다. 크립 영역·EUD 런타임 변경과
게임/외부 에디터 인수는 별도다. 사용자 지시에 따라 이번 실제 앱/게임 조작은 하지 않는다.
