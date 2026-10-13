# 카탈로그 객체 배치 공통 사전 검증

2026-10-13 실행 기록. FR-217, EP1, PAR-01/02의 부분 구현이다.
전체 EP1·게임 배치 규칙·외부 에디터 인수 완료를 뜻하지 않는다.

## 1. 실행 계획과 소스 분석

1. 두다드의 기존 preview/Apply 검사를 유지하며 Unit/pure Sprite/unit-sprite에 확장한다.
2. hover에서 문서/선택/dirty/Undo/Redo를 바꾸지 않고 클릭 시 현재 상태를 재검사한다.
3. 실제 클릭 픽셀 좌표와 factory/섹션 선택을 공유하고 알려진 실패 사유를 한영으로 표시한다.
4. 종류별 경계·거절·허용·오래된 preview·Undo 회귀, Windows 앱/로컬 도구를 확인한다.

기존 Unit/Sprite 경로는 클릭에서만 검사했고 캔버스 ghost는 타일 단위였다.
별도 hover 검사를 복제하면 factory·섹션·정확한 좌표가 달라질 위험이 있었다.
`ObjectEditingController`에 읽기 전용 준비 결과를 두고 preview/Apply 모두 사용했다.
`PlacementCatalogController.previewAt`가 종류별 좌표와 capability/recipe를 전달한다.
`MapCanvas`의 픽셀 콜백은 build에서 검사하며 painter는 검사 결과만 그린다.
기존 타일 콜백은 호환성을 위해 유지했다.

최적화: hover마다 전체 UNIT에서 class ID를 스캔하지 않도록 raw document identity별
max+1 요약을 하나만 보유한다. Apply/Undo/Redo/문서 교체 시 다른 identity는 재계산한다.
추가 배열 복사는 하지 않는다. 측정된 FPS/메모리 개선 수치를 주장하지 않는다.
해당 캐시와 Apply의 재검사 계약에는 코드 주석을 추가했다.

## 2. 요구사항 체크리스트

| 항목 | 결과/범위 |
| --- | --- |
| Unit/pure Sprite/unit-sprite와 두다드 공통 preview/Apply | 구현. Apply는 hover 허용 결과를 재사용하지 않음 |
| 맵/좌표·ID/owner·레이어·capability·섹션 검사 | 구현. u16 픽셀/u8 owner, 모호한 중복 거절 |
| protected/malformed 세션과 진행 중 history transaction | 거절. 손상 레코드는 세션 제한이 우선 |
| 읽기 전용 preview, 거절 시 무변경 | 자동 테스트로 raw document/선택/Undo/Redo 확인 |
| 경고 사유/색상, 잠금 해제 후 재시도 | 자동 및 Windows Unit 확인 |
| 알려진 코드 한영 안내 | 공통13+factory5+catalog5+controller2 =25종, 새 문자열6개 |
| 정확한 Unit/Sprite 픽셀 좌표 | 타일 내부31,63 포함 자동 회귀. 한 타일 ghost는 시각 커서 |
| 생성 레코드/unknown 섹션 보존 | factory 기본값/flags 유지, 원자 append/Undo, MPQ 왕복 회귀 |
| 실제 footprint/충돌·전력/크립·객체 스냅 | 미구현. 이번 중심 좌표 검증과 구분 |
| 템플릿 복제·로케이션 사전 검사 통합 | 이번 범위 제외 |
| SC:R 게임/외부 에디터 관찰 | 미실행, 인수 대기 |

없는 UNIT/THG2는 Apply에서 생성할 수 있으나 preview는 생성하지 않는다.
미지원 relation/subunit/capability 정책은 완화하지 않는다. 미래의 알 수 없는 코드는
기존 일반 안내와 원시 진단 코드를 유지한다.

## 3. 테스트 시나리오와 실행

새 일반 테스트61개: 명령53, 카탈로그4, 캔버스1, Shell3.
기존 두 언어 진단 테스트는25종을 검사하도록 확장했다.

| 시나리오 | 결과 |
| --- | --- |
| 세 종류별 lock/hidden/음수/오른쪽/하단/duplicate/malformed/DIM/보호/transaction/ID/owner | preview와 Apply 사유 일치, 거절 무변경 |
| 허용 preview와 없는 섹션·기존 Redo | 문서와 기록 무변경 |
| hover 뒤 잠금 변경, 해제 후 정확한 좌표 배치 | 재검사 거절/성공, Undo 복원 |
| capability 불일치/subunit/관계 필요 | 기존 factory 사유 유지 |
| class ID 캐시·Apply/Undo/Redo·ID 소진 | 기존 max+1 규칙 유지, sprite-unit 별도 |
| pixel callback 우선과 경고 후 클릭 전달 | 성공 |
| 실제 Shell Unit/pure Sprite/unit-sprite와 기존 Doodad | 신규3+기존1 성공 |

명령과 원시 로그는 로컬 `.dart_tool/object_preview_*.log`에 남겼다(ignored).

| 검증 | 결과 / 로그 |
| --- | --- |
| focused4파일 | 175통과/7skip, `object_preview_focused.log` |
| 신규 Shell3 / 기존 Doodad1 | 각각 통과, `object_preview_shell.log`, `object_preview_doodad_shell.log` |
| `flutter analyze` | No issues, `object_preview_analyze.log` |
| `flutter test --concurrency=4` | 최종1093통과/50skip, `object_preview_tests.log` |
| 로컬 CASC/MPQ 도구 회귀 | 56통과, `object_preview_real_tools.log` |
| `flutter build windows --debug` | 성공, `object_preview_windows_build.log` |
| native CTest | 7/7통과 |
| 변경 Dart14파일 nonwrite format | 0변경, 통과 |
| 전체 nonwrite format | 432파일 중 기존 미변경3개 차이, exit1, `object_preview_format.log` |

로컬 도구 테스트는 `STARCRAFT_DATA_HELPER_PATH`, `STARCRAFT_TEST_INSTALLATION`,
`MAP_ARCHIVE_HELPER_PATH`를 실제 설치/helper 경로로 지정해 catalog controller와
`object_editing_roundtrip_test.dart`를 실행했다. 게임 원시 자산/추출 이미지는 추가하지 않았다.
현재 실행 SDK는 Flutter3.47.5/Dart3.13.4로 저장소 기준3.44.8/3.12와 다르다.
기준 SDK 재실행과 전체 format 게이트는 출시 전 남는다. 미변경 format 차이는
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`이며 이번 작업에서 수정하지 않았다.

## 4. 실패 수정과 결과 분석

- 초기 테스트의 없는 `withSections` 호출과 괄호 오류를 실제 constructor/구문으로 수정했다.
- 새 코드의 unbraced-if lint를 수정한 뒤 analyze를 다시 통과했다.
- malformed 레코드3개 시나리오는 섹션 코드보다 세션 제한이 먼저였다. 기존 안전 정책에
  맞춰 기대값을 `sessionNotEditable`로 바로잡았으며 손상 문서 편집을 허용하지 않았다.
- 첫 전체 실행에서 기존 catalog loader suite가 `Connection closed before test suite loaded`
  로 로드 실패했다(`object_preview_tests_initial.log`). 원인은 확정하지 않았다.
  해당 파일 단독10통과(`object_preview_loader_retry.log`), 전체 재실행1093통과로 확인했다.

## 5. 실제 Windows 앱

Debug 앱에서 기존 파일/복구 사본을 열거나 저장하지 않고 Badlands128 새 맵을 만들었다.
카탈로그 Unit0 선택 -> 레이어 잠금 -> 맵 클릭에서 한국어 사유와
`OBJECT_PLACEMENT_LAYER_LOCKED` 및 붉은 경고를 관찰했다. 유닛 수는 시작 위치1개로 유지됐다.
잠금 해제 -> 클릭에서 유닛 수2개, 경고 해소, Inspector 픽셀 좌표를 확인했다.
실행 취소 버튼 ->1개로 복원됐고 Redo가 활성화됐다. 새 맵은 저장하지 않았다.

Ctrl+Z 시도만으로는 수가 바뀌지 않았다. 이번 수동 Undo 판정은 버튼 경로에 한정한다.
단축키 focus/등록 회귀는 별도 확인 대상으로 남긴다. pure Sprite/unit-sprite의 실제
Windows 수동 배치는 이번에 하지 않았으며 Shell 자동 회귀와 로컬 도구 왕복으로 구분한다.

## 6. 다음 작업

격자 표시와 객체 스냅을 분리하고 정상/자유 배치 정책을 설계·구현한다(FR-218).
기존 데이터 자동 정규화 없이 preview/Apply/Undo를 공유해야 한다. 관계/터렛 예외,
게임·외부 에디터·기준 SDK 인수와 EP0 전체 회귀는 계속 미완료다.
