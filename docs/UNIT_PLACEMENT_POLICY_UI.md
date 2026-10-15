# UNIT 배치 정책 프리셋과 지원표

2026-10-15 후속 [자원 거리 배치 정책](UNIT_RESOURCE_DISTANCE_POLICY.md)을 연결했다.
현행 프리셋은 지형/겹침/자원 세 설정을 변경한다. 아래 계약/표는 이를 반영했으며
기존 실행 결과는 각 날짜의 검증 범위다.

2026-10-14. EP1, FR-218/219의 후속 코드 단위다. 기존
[겹침 정책](UNIT_OVERLAP_POLICY.md)과 [지형 검사](UNIT_TERRAIN_PLACEMENT_POLICY.md)를
한 번에 설정하는 **검사 배치 / 자유 배치** 프리셋과 읽기 전용 지원표를 구현했다.
현행 자원 검사 추가·회귀 결과는 후속 정책 문서를 따른다.
전체 게임 정상 모드·전력/크립·EUD 변경 검증을 완료한 것은 아니다.

## 1. 실행 계획과 소스 분석

1. 기존 두 체크박스와 source/epoch 수명, 최종 좌표 preview/Apply를 확인한다.
2. runtime 정책과 파생 모드를 정의하고 두 설정의 원자적 변경을 구현한다.
3. 지원표에서 정책 생략·대상 아님·자료 상태·미구현·인수 대기를 구분한다.
4. 기존 도구 줄에 프리셋과 지원표 아이콘을 추가하고 한/영 좁은 화면을 확인한다.
5. 합성/실제 로컬 자료·전체 게이트·Windows 빌드 결과와 미실행 경계를 기록한다.

주요 분석 소스는 `PlacementCatalogState/Controller`, `PlacementAlignmentToolbar`,
기존 object editing 공통 prepare, Shell ghost, UNIT 지형/충돌 snapshot과 테스트다.
새로운 게임 규칙이나 binary flag는 도입하지 않는다. 기존 체크박스 설정과
검증된 같은 application prepare를 재사용하므로 UI가 별도의 허용 판정기를 갖지 않는다.
기존 source의 게임 의미는 앞선 자료 계약 문서의 고정 primary source를 따른다.

## 2. 정책 및 요구사항 계약

| 프리셋/상태 | UNIT 지형 검사 | UNIT 겹침 허용 | 자원 거리 검사 | 의미 |
| --- | --- | --- | --- | --- |
| 검사 배치 | 켬 | 해제 | 켬 | 로컬 지형/겹침/자원 검사를 사용 |
| 자유 배치 | 끔 | 켬 | 끔 | 세 선택 검사를 명시적으로 생략, 기본값 유지 |
| 사용자 설정 | 그 밖의 조합 | 그 밖의 조합 | 그 밖의 조합 | 실제 checkbox8조합 중 나머지6개에서 파생 |

- `UnitPlacementPolicy`는 Flutter/I/O가 없는 immutable runtime 값이다. 모드는
  실제 세 boolean에서 계산하므로 개별 체크박스 변경 후 프리셋 이름이 남지 않는다.
- 프리셋은 세 boolean을 한 state emit에서 변경한다. 중간에 지형만 켜진 상태를
  알림으로 내보내지 않는다. 이후 필요한 숫자 조회는 기존 coalescing 경로를 사용한다.
- 같은 정책 재적용은 no-op이다. 자유 배치로 바꿔도 pending 조회 완료가 이전
  정책을 되살리지 않는다. 완료 자료는 기존 cache 계약에 따라 재사용한다.
- 건물 타일 정렬, point snap, grid, owner, continuous, 선택은 변경하지 않는다.
  건물 정렬을 normal preset의 필수값으로 추측하지 않는다.
- 구조/잠금/history/ID/owner/좌표/factory/관계 안전 검사는 자유 배치에서도 유지한다.
  DD2 footprint/overlay/tileset 검사는 자유 UNIT 정책으로 생략하지 않는다.
- pure Sprite/unit-sprite/두다드·기존 이동/템플릿/로케이션에는 새 UNIT 정책을
  적용하지 않는다. 기존 맵 객체와 CHK/원시 문자열·Undo를 정책 선택으로 바꾸지 않는다.
- 검사 배치는 **로컬 기본 자료 검사**다. 게임 전체 건설 가능성이나 EUD로
  바뀐 collision/상태·전력/크립·멀티플레이를 보증하는 이름으로 쓰지 않는다.

## 3. 지원표와 화면

Map 도구 줄의 segmented control은 검사/자유 두 명령을 제공한다. 사용자 설정이면
두 프리셋 모두 선택하지 않고 현재 모드 이름을 표시한다. 기존 binary 설정은 계속
체크박스다. 프리셋 strip만 추가하고 기존 Wrap/controls의 배치는 유지한다.
표시 폭160/226px와 높이40px, 기존 checkbox 폭260px을 사용하며 좁은 창에서는 줄바꿈한다.
지원표는 `rule` 아이콘과 tooltip으로 열고 모달 내부의 row/scroll layout을 사용한다.

지원표는 **정책 및 자료 가용성**이지 특정 좌표의 통과/거절 결과가 아니다.
`검사 사용`을 `통과`나 `게임 정상`으로 표시하지 않는다. 좌표·맵 구조·기존
UNIT 자료는 ghost/클릭 시 기존 공통 경로에서 다시 검사한다.

| 검사/상태 | 현재 표시 |
| --- | --- |
| 구조·경계·레코드 안전 | 항상 검사 |
| 건물 타일 정렬 | 비건물/비UNIT 대상 아님; 꺼짐 생략; box 누락 확인 불가; 켜짐 검사 사용 |
| UNIT 지상/공중 겹침 | 비UNIT 대상 아님; 허용 시 생략; 로딩/출처 또는 profile 누락 확인 불가; 자료 연결 시 검사 사용 |
| 지형 footprint | 비UNIT/검증된 비건물 Flyer는 대상 아님; 꺼짐 생략; 로딩/누락·source 불일치 확인 불가; 연결 시 검사 사용 |
| 자원·기지 거리 | 꺼짐 생략·로딩·source/역할 누락 확인 불가·확인된 비대상 N/A·자료 연결 시 검사 사용; 실제 UNIT 전체 판정은 배치 때 수행 |
| 전력/크립 | UNIT 건물 미구현; 나머지 대상 아님. 건물별 필요 flag/동적 상태는 미판정 |
| EUD·런타임 DAT 변경 | UNIT 미구현, 로컬 기본 자료를 런타임 변경값으로 표시하지 않음 |
| 게임/외부 에디터 | 인수 대기, 자동 테스트 결과로 게임 인수를 통과 표시하지 않음 |

총9개 rule/8개 support 상태의 enum으로 application에서 계산한다. 모달은
controller stream을 구독해 로딩 종료·조회 실패/재시도·정책 변경에 맞춰 갱신한다.
열기/읽기/닫기는 조회나 문서 편집을 시작하지 않는다. 프리셋으로 시작한 조회와
지원표 자체를 읽는 행위를 구분한다. 자료의 전체 의미나 특정 좌표를 캐시하지 않는다.

## 4. 시나리오 및 체크리스트

| 시나리오 | 검증 |
| --- | --- |
| 세 boolean의8조합·두 preset | domain mode/default 테스트 |
| 세 설정 원자 변경·반복 선택 no-op | emitted state 조합·metadata 조회 각1회 |
| pending 중 자유 선택·다시 검사 선택 | 정책 원복 없음·cache 재사용 |
| 원본 세션/Undo·선택/정렬/grid/snap/owner 유지 | 동일 session/undoDepth/각 preference 확인 |
| ground/air/building·missing box/profile/source | 지원표 rule별 enabled/N/A/unavailable 회귀 |
| no selection·pureSprite/unit-sprite/Doodad | UNIT 규칙 대상 아님과 factory 유지 |
| 개별 checkbox 변경 | custom/free/checked 파생 모드와 segment 선택 일치 |
| 한/영 300px toolbar·500×760 화면 | preset 클릭·custom 표시·지원표 줄바꿈/닫기·오버플로 없음 |
| 모달 loading→실패→retry→enabled | stream 갱신·생략/미구현/인수 대기 번역 회귀 |
| 실제 Shell UNIT/건물/Sprite | preset 사용 후 동일 ghost/click·잠금·지형 거절/재시도·Undo 회귀 |
| 실제 로컬 CV5/VF4/DAT | 검사 모드 허용/막힘 거절·자유 모드 막힌 지형 허용·Undo |
| source 설치/map/epoch | 기존 자료 조회 수명 회귀 유지, 새 cache/프로세스 없음 |
| 실제 Windows 클릭/SC:R/외부 에디터 | 미실행/인수 대기, 아래 사유 참조 |

## 5. 최적화 및 주석

새 의존성/native 연산/binary layout 변경은 없다. preset은 기존 두 조회를 병합하지
않고 각 port의 pending cache를 재사용한다. 지원표는 선택과 cached source에 대한
고정9개 rule만 계산하며 hover 때 전 맵/228개 유닛을 추가 스캔하지 않는다.
FPS/메모리 개선은 측정하지 않았다. mode 파생, 원자적 preference 변경, 지원표와
실제 좌표 verdict 구분에 짧은 주석을 추가했다. 기존 controls의 재들여쓰기 변경은
정리하여 toolbar diff를 프리셋 strip 추가로 제한했다.

## 6. 실행·결과 분석

원시 로그: ignored `.dart_tool/placement_policy_*.log`.
실제 SDK는 Flutter **3.47.5 stable / Dart 3.13.4**이며 기준 **3.44.8 / 3.12** 재검증은 남는다.

- 초기 domain/application focused: **110통과/8skip**, `placement_policy_focused.log`.
- 한/영 모달 및 Shell 포함: **156통과/8skip**, `placement_policy_widget.log`.
- 전체 첫 실행: **1375통과/55skip**, `placement_policy_tests.log`.
- 실제 로컬 자료 추가: **1통과**, `placement_policy_local.log`. native collision
  snapshot과 terrain source가 같은 설치/build에 연결되며 지형 거절을 자유 선택으로
  생략할 수 있는 것을 확인했다. 원시 자산/추출 그림/다른 사람의 맵 fixture 없음.
- analyze: No issues, `placement_policy_analyze_final.log`.
- Windows Debug build 성공, `placement_policy_windows.log`; native CTest **7/7**,
  `placement_policy_ctest.log`. 기존 CascLib CMake deprecation 경고는 비치명적이다.
- 필수 전체 nonwrite format은453파일 중 기존 미수정 infrastructure 테스트3개
  차이로 exit1이다. `local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`는
  사용자/기존 작업을 보존하여 수정하지 않았다.
- 실제 앱 테스트용 새 runner를 실행했으나 반환 캡처가 에디터 화면을 확인하기에
  적합하지 않았고, activation 시 사용자 입력 감지가 발생했다. 재확인 질문에
  사용자가 **이번에는 자동 테스트와 빌드만 진행**하도록 지시하여 UI 조작을 중단했다.
  새 맵 생성/모드 클릭/지원표 Windows 관찰 성공을 주장하지 않는다. 원본 맵/복구
  자료를 열거나 저장·discard하지 않았다. 테스트용 프로세스는 열린 상태로 남았다.

| 최종 검증 | 결과 |
| --- | --- |
| 변경 Dart 11파일 format | 0변경, exit0 (`placement_policy_scoped_format.log`) |
| 전체 format lib/test/tool | 기존3파일 차이만 exit1 (`placement_policy_format.log`) |
| flutter analyze | No issues, exit0 (`placement_policy_analyze_verified.log`) |
| 전체 flutter test | **1375통과/55skip**, exit0 (`placement_policy_tests_final.log`) |
| final toolbar/Shell 회귀 | **156통과/8skip**, exit0 (`placement_policy_widget_final.log`) |
| 실제 로컬 정책/배치 | **1통과**, exit0 (`placement_policy_local.log`) |
| Windows Debug 최종 build | 성공, exit0 (`placement_policy_windows_final.log`) |
| native CTest | **7/7**, exit0 (`placement_policy_ctest.log`) |

skip은 도구/실제 설치와 별도 환경 의존 테스트이며 통과로 계산하지 않았다.
도구 줄 정리 뒤에도 전체 회귀를 다시 실행했으며 code 변경에 추가 의존성이나
원시 자산은 없다. 커밋에는 별도 Git index로 이번 파일과 공유 문서의 해당 hunk만
포함하고 기존 staged `local.properties`·무관한 working tree는 보존한다.

## 7. 인수 경계와 다음 작업

코드/자동 회귀와 Windows 빌드는 이 제한 기능의 증거다. 전체 format 게이트,
기준 SDK, 실제 앱 클릭·게임/외부 에디터 인수는 별도다. EP1 전체 체크박스를
완료로 닫지 않는다. 다음은 자원·기지 거리 등 미지원 검사별 자료/예외 계약을
확정하는 단위와 PAR-01~03 인수 시나리오 정리다. 전력/크립/EUD 변경을 검증 없이
정상 배치의 필수 지원으로 간주하지 않는다.
