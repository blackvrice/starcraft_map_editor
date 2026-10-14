# UNIT 배치 지형 검사 연결

2026-10-14. EP1, FR-218/219의 좁은 후속 구현이다. 기존
[CV5/VF4 snapshot](TERRAIN_PLACEMENT_SNAPSHOT.md)을 새 카탈로그 UNIT의 실제
preview/Apply에 연결했다. 전체 정상/자유 모드나 게임 건설 규칙 완료가 아니다.

## 1. 실행 계획과 소스 분석

1. 공통 배치 검증, 점 스냅/건물 정렬, UNIT 겹침 정책과 helper 출처를 조사한다.
2. 설치/맵/타일셋/조회 epoch별 지형 자료 수명을 구현한다.
3. 최종 좌표의 현재 MTXM을 같은 prepare 경로에서 검사한다.
4. 체크박스·로딩·재조회·한/영 사유를 제공하고 기본 동작은 보존한다.
5. 합성 회귀, 실제 로컬 자료, Windows 앱, 저장 왕복과 필수 게이트를 기록한다.

분석한 주요 소스는 `PlacementCatalogController`, `ObjectEditingController`,
`TerrainPlacementSnapshot`, snapshot gateway/decoder, `PlacementAlignmentToolbar`,
`EditorShell`이다. 기존 ghost는 catalog preview를 사용하므로 별도의 UI 판정기를
만들지 않았다. UI는 application 포트만 호출하며 domain에는 I/O를 추가하지 않았다.

primary source는 Chkdraft commit
`32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[isValidUnitPlacement](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L2189-L2267)다.
건물은 CV5 건설 flag와 VF4 이동 mask, 비건물 지상 유닛은 VF4를 검사한다.
비건물 Flyer는 지형 이동 검사를 생략한다. 해당 소스의 경계 clamp/미지 group 허용을
복제하지 않고 본 저장소의 닫힌 전체 footprint·unknown 거절 계약을 유지한다.
웹 도구의 raw URL 조회는 cache miss였으며 같은 고정 URL을 읽기 전용 HTTP로 확인했다.

## 2. 구현 계약

| 항목 | 동작 |
| --- | --- |
| 기본값 | `UNIT 지형 검사` 꺼짐. 이전 자유 배치 동작 유지 |
| 켜짐 | 공통 구조/ID/소유자/잠금/원시 좌표 → factory → 건물 정렬 → 지형 → UNIT 겹침 순 |
| ground | 검증된 DAT collision offsets의 닫힌 전체 영역과 현재 MTXM의 VF4 8px mask |
| building | 동일 영역의 CV5 buildable도 확인. StarEdit box를 collision 크기로 대입하지 않음 |
| airborne | 비건물 Flyer만 지형 생략. profile 없으면 비행 여부를 추측하지 않고 거절 |
| 신규 상태 | factory의 새 UNIT state=0. 기존 건물 이동/리프트는 이 경로 대상 아님 |
| final point | 점 스냅의 raw 입력에서는 구조/좌표 안전만 검사하고 최종 좌표에서 정책 검사 |
| 건물 정렬 | 공통 prepare에서 정렬한 동일 좌표로 preview/Apply 검사 |
| source | 선택 UNIT catalog와 product/build/helper/CascLib revision 일치 필요 |
| map | unique ERA/MTXM과 DIM 기반 grid, 현재 tileset과 source 일치 필요 |
| unknown | 누락/미지 reference/잘못된 tileset·profile/출처 불일치·예산 초과는 검증 불가 |
| refusal | 불건설/불이동/검증 불가를 구분. 영역 맵 밖은 기존 outOfBounds |
| Apply | 한 번의 원자적 UNIT 추가/Undo. 미리보기와 거절은 문서/Undo 불변 |
| 제외 | THG2 pureSprite/unit-sprite, DD2 recipe, 기존 이동/복제/로케이션, EUD DAT 변경 |

지형 해제나 겹침 허용은 서로 독립이다. 지형 해제 시에도 공통 구조·좌표·factory
안전 검사와 선택한 건물 정렬은 유지한다. 보조 높이/전력/크립/자원 거리·게임
동작 보증은 제공하지 않는다. 알려진 막힘과 확인할 수 없는 자료를 같은 것으로
표시하거나 자료 실패를 이동 가능으로 바꾸지 않는다.

## 3. 조회 수명과 최적화

- bootstrap이 기존 bounded process gateway의 새 포트를 주입한다. helper 버전은
  변경하지 않으며 실제 자료/로그 계약은 snapshot 문서를 따른다.
- 명시적인 체크/UNIT 확인/재조회만 프로세스를 시작한다. hover와 클릭은 동기적인
  숫자 검사만 하며 반복 hover가 조회 재시도 루프를 만들지 않는다.
- 같은 요청은 pending future로 합친다. pending을 loading emit보다 먼저 등록하고
  `Future.sync`로 동기 throw도 처리하여 실패 후 명시적인 재시도를 허용한다.
- 설치/새 맵/폐기/재조회는 epoch를 증가하고 해당 operation만 취소한다. 완료가
  늦은 이전 요청은 source/로그/loading 상태를 다시 덮어쓰지 않는다.
- 동일 extractedMap의 ERA 변경도 별도로 감지하여 무효화/재조회한다. source 사용
  시에도 현재 ERA를 확인하므로 session 동기화 전에도 오래된 tileset을 허용하지 않는다.
- MTXM 페인트·Undo/Redo에는 숫자 자산 cache를 유지한다. 판정 결과는 cache하지
  않고 현재 immutable session의 typed grid를 검사한다.
- UNIT catalog의 출처 변경도 cached terrain을 무효화한다. 출처 mismatch를
  재로드 성공으로 간주하여 배치 권한을 주지 않는다.
- 검사 비용/4096 intersected tile 예산은 기존 domain 계약을 유지한다. 맵 전체
  스캔/bitmap 할당은 없으며 FPS/메모리 개선 수치는 측정하지 않았다.

복잡한 raw/final 정책 분리, airborne/StarEdit box 구분, 숫자 cache와 현재 MTXM
판정 분리에는 짧은 주석을 추가했다. 무관한 파일/SDK format 변경은 하지 않았다.

## 4. 요구사항 및 테스트 체크리스트

| 시나리오 | 증거 |
| --- | --- |
| 기본 꺼짐·기존 UNIT/Sprite/Doodad 배치 보존 | 전체 회귀, 6종 shell 시나리오 |
| ground/building/air·검증 불가·경계·건물 정렬 | object placement 공통 preview/Apply 회귀 |
| unique ERA/MTXM·미지 reference·profile/출처 누락 | 거절과 문서/Undo 불변 회귀 |
| 최종 snap과 raw 안전 | raw 막힘/최종 clear 합성 회귀, 기존 좌표 안전 회귀 |
| MTXM paint·Undo/Redo | current typed grid 재판정, 자산 조회 1회 유지 |
| 동일 맵 ERA 변경 | cache 무효화/새 tileset 조회·선택 유지 회귀 |
| 요청 합치기·취소·obsolete completion | reload/설치/session/dispose 회귀 |
| 동기 throw/비동기 실패/출처 mismatch·재시도 | loading/pending 해제·명시적 재조회 회귀 |
| 한/영 좁은 toolbar·재조회·사유 | 300px widget, diagnostics 목록 전체 번역 회귀 |
| ghost와 click·잠금/거절 후 재시도 | 실제 Shell widget의 UNIT/건물과 Sprite 구분 |
| Save As·unknown CHK·원시 보존 | 기존 합성 archive 왕복에 지형 검사 추가 |
| 실제 로컬 CV5/VF4와 UNIT | 실제 verified clear/zero-mask 타일의 허용/거절·Undo/Redo |
| Windows 실제 앱 | 새 Badlands 맵, UNIT 검사 켜기/재조회, Unit #0 배치·메뉴 Undo |
| SC:R 게임/다른 에디터 | 인수 대기, 자동/로컬 자료 증거와 구분 |

## 5. 실행 결과와 분석

원시 로그는 ignored `.dart_tool/unit_terrain_*.log`다. 실제 SDK는
Flutter **3.47.5 stable / Dart 3.13.4**이며 저장소 기준 **3.44.8 / 3.12** 재검증은 남는다.

- 초기 집중 테스트 229통과/7skip. 편집기·저장 흐름 143통과/9skip.
- 첫 analyze는 unbraced-if lint 1건이었다. 수정 후 No issues를 확인했다.
- 전체 첫 실행 1355통과/54skip. 이후 ERA/실제 로컬 시나리오를 추가했다.
- 실제 로컬 CV5/VF4 → UNIT 배치/거절/Undo 테스트 1통과. 원시 자산 fixture 없음.
- 추가 동일 맵 ERA 변경 테스트 1통과.
- Windows Debug build 성공, CTest 7/7. 기존 CascLib CMake 호환성 경고는 비치명적이다.
- 전체 format은 기존 미수정 infrastructure 테스트 3개만 차이로 exit1이다.
  `local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
  `process_map_archive_gateway_test.dart`의 변경은 이번 범위에 포함하지 않았다.
- 사용자 허용 후 새로 빌드한 앱을 실행해 자체 새 128×128 Badlands terrain #2
  맵을 만들었다. UNIT 검사 체크/로딩 종료·재조회 버튼, Unit #0을 (2001,1682)에
  배치하여 유닛 수 1→2와 Inspector ID0을 확인했다. 편집 메뉴 Undo로 2→1 복원했다.
  Ctrl+Z 입력에서는 화면 원복을 관찰하지 못해 단축키 성공으로 기록하지 않는다.
  원본 맵/사용자 복구 자료는 열거나 덮어쓰지 않았으며 테스트 앱의 새 맵은 미저장 상태다.
- 실제 재조회 버튼 클릭 후 loading이 종료되고 다시 재조회 아이콘으로 돌아오는 것을
  확인했다. 유닛 수는 1개로 유지되어 조회가 배치를 추가하지 않았다.
- UIA index 입력은 cached element unavailable 1회, 사용자 입력 감지 1회가 있어
  재관찰 후 최신 screenshot 좌표로 진행했다. 앱 기능 실패로 분류하지 않는다.
- 커밋 준비에는 별도 Git index를 사용해 기존 staged `local.properties`와 공유
  문서의 다른 작업을 제외했다. PowerShell patch 전달 끝의 CR whitespace로 첫
  cached check가 실패하여 해당 두 문서의 별도 stage만 다시 생성하고 check를 통과했다.

| 최종 검증 | 결과 |
| --- | --- |
| 변경 Dart 13파일 format | 0변경, exit0 (`unit_terrain_scoped_format.log`) |
| 전체 format lib/test/tool | 449파일, 위 기존3파일 차이만 exit1 (`unit_terrain_format.log`) |
| flutter analyze | No issues, exit0 (`unit_terrain_analyze_final.log`) |
| flutter test | **1356통과 / 55skip**, exit0 (`unit_terrain_tests_verified.log`) |
| 실제 local CV5/VF4 → UNIT | **1통과**, exit0 (`unit_terrain_local.log`) |
| MPQ helper 포함 왕복 | **4통과**, exit0 (`unit_terrain_mpq.log`) |
| Windows Debug | 성공, exit0 (`unit_terrain_windows.log`) |
| native CTest | **7/7통과**, exit0 (`unit_terrain_ctest.log`) |

MPQ4건에는 기존 건물 UNIT native 기록/재열기와 일반 설정 Save As가 포함된다.
이번 terrain 옵션을 켠 catalog UNIT 추가·unknown 보존은 fake archive 왕복이며
이를 실제 게임/새 terrain 옵션의 native 전체 인수로 확대 해석하지 않는다.
전체 skip은 실제 설치/외부 도구·별도 환경 검증이고 통과로 계산하지 않았다.
필수 전체 format 게이트와 기준 SDK의 재검증이 남으므로 배포 승인 완료가 아니다.

## 6. 다음 개발 경계

유닛/건물별 정상·자유 정책의 지원표와 명시적 상태 UI를 정리하는 다음 단위가 남는다.
자원 거리·전력/크립·높이 보조 표시·EUD 변경 profile은 각각 검증된 출처/정책이 필요하다.
SC:R 게임 실행과 외부 에디터 인수, 실제 앱의 막힌 지형/건물/airborne 전체 표본,
Ctrl+Z 포커스 경로는 이번 Windows 성공 표본으로 완료 처리하지 않는다.
