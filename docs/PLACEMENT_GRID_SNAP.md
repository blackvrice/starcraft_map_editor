# 격자와 카탈로그 중심 좌표 스냅

2026-10-13. FR-218, EP1의 첫 정렬 단위. [공통 사전 검증](CATALOG_PLACEMENT_PREFLIGHT.md)을
확장하며 건물 정렬/게임 정상·자유 규칙 전체를 완료한 것은 아니다.

## 실행 계획과 소스 분석

1. 기존 자동 격자와 정확한 클릭 좌표 동작을 기본값으로 보존한다.
2. 표시 격자와 새 카탈로그 객체의 좌표 스냅을 독립 설정으로 제공한다.
3. 순수 정수 정책 하나를 preview/Apply/커서에서 사용하고 입력/출력 경계를 모두 검사한다.
4. 수학/컨트롤러/한영 UI/픽셀 렌더/Shell/전체 회귀와 Windows 실행을 기록한다.

현재 `UnitPlacementCapability`는 `isBuilding`은 있지만 타일 정렬에 필요한 검증된
건물 크기 자료가 없다. 임의 크기/ID별 표를 만들지 않았다. 이번 스냅은 종류와
무관하게 레코드 중심점을 정렬하며 건물 footprint를 표현하지 않는다.
Domain은 Flutter/I/O를 사용하지 않고 기존 factory/문서 공통 Undo를 재사용한다.
새 dependency나 helper protocol 변경은 없다.

## 계약과 요구사항 체크리스트

| 항목 | 구현 범위 |
| --- | --- |
| 격자 표시 | 독립 체크박스, 기본 켜짐. 자동 또는8/16/32/64/128px |
| 좌표 스냅 | 독립 체크박스, 기본 꺼짐. 프리셋 또는 사용자1~128 정수px |
| 적용 대상 | 새 카탈로그 Unit/pure Sprite/unit-sprite 레코드의 중심 |
| Doodad/지형 | 기존 중심 타일/recipe·지형 도구 유지. 픽셀 스냅 적용 안 함 |
| 기존 객체/템플릿/로케이션 | 자동 재작성 없음. 이동/복제/로케이션 스냅은 이번 범위 제외 |
| 설정 변경 | 문서/dirty/Undo/Redo 변경 없음. runtime-only, 재시작 시 기본값 |
| 변환 | 맵 원점 기준 가까운 정수 격자점, 동률은 큰 좌표. 음수 입력은 그대로 거절 |
| 경계 | 원시 입력과 정렬 출력 모두 검사. 맵 끝 밖으로 반올림되면 거절, clamp 안 함 |
| preview/Apply | 같은 정책 사용. 현재 상태/문서를 각각 재검사하며 hover는 읽기 전용 |
| 커서 | 정렬된 중심 십자와 한 타일 시각 커서. 실제 footprint/충돌 검사 아님 |
| 건물 타일 정렬·게임 정상/자유 | 미구현, 검증된 건물 크기/충돌/전력/크립 지원표 후속 |

`PointPlacementSnap`은 비활성 시 정확한 입력을 반환한다. 예:32px 스냅31->32,
사용자17px 스냅31,63->34,68. 설정값은 컨트롤러에서 검증하고 UI 숫자 대화상자는
잘못된 입력을 표시한 채 적용하지 않는다. 격자 자동/표시 설정은 카탈로그 reload와
자료 경로 변경에서도 유지되며 어떤 맵 바이트에도 저장하지 않는다.

## 최적화 판단

좌표 변환은 O(1) 정수 연산이다. 기존 문서별 class ID 요약 캐시를 유지한다.
입력/출력 안전 검사를 하나로 줄이지 않았다. 저배율의 수천 격자선을 피하도록
화면 간격8px 이상이 될 때까지 간격을2배로 늘려 같은 원점 격자의 부분집합을
그린다. viewport visible tiles 안의 선만 순회한다. 이는 표시 밀도 제한이며
설정한 배치 간격은 바꾸지 않는다. FPS 개선 수치를 측정하거나 주장하지 않는다.
해당 변환/밀도 제한에는 계약 주석을 추가했다.

## 테스트 시나리오와 실패 수정

- 비활성 정확한 좌표, 프리셋/홀수/최솟값 간격의 nearest/tie/idempotence,
  0..8191 좌표와 invalid step을 검사한다.
- 세 객체 종류별 설정 무변경, custom17px 좌표 저장, Undo byte-exact/Redo,
  스냅 해제와 음수/맵 끝/맵 밖 입력 거절을 검사한다.
- Doodad와 선택 없음은 픽셀 스냅 제외, 카탈로그/설치 경로 변경 시 설정 유지,
  invalid 설정의 원자적 거절을 검사한다.
- 영어/한국어300px toolbar에서 격자 토글·숫자 범위 거절/적용을 조작한다.
- 격자 숨김/16px/64px의 실제 RGBA 차이와 repaint, point ghost의 정렬 중심,
  실제 Shell 세 종류의 잠금/스냅 preview/배치/Undo 좌표를 확인한다.

초기 영어300px 메뉴는 intrinsic 폭 때문에149px overflow와 클릭 실패가 발생했다.
112px 메뉴 폭/expanded와 Wrap 줄바꿈으로 수정한 뒤 해당 시나리오를 통과했다.
초기 analyze의 unbraced-if info1개를 수정했다. 실패 로그도 로컬 `.dart_tool`에 보존한다.

## 검증 결과

새 테스트31개(도메인14, 컨트롤러/UI15, 캔버스2)를 추가했고 기존 Shell3개도 스냅
좌표 확인으로 확장했다. 로컬 ignored `.dart_tool/placement_snap_*.log`에 원시 로그를 남겼다.

| 명령/범위 | 결과 / 로그 |
| --- | --- |
| focused domain/catalog/canvas | 109통과/7skip, `placement_snap_focused_retry.log` |
| Shell 세 객체 유형 | 3통과, `placement_snap_shell.log` |
| `flutter analyze` | No issues, `placement_snap_analyze_final.log` |
| `flutter test --concurrency=4` | 1124통과/50skip, `placement_snap_tests.log` |
| 변경 Dart12파일 nonwrite format | 0변경, 통과 |
| 전체 nonwrite format | 기존3개 차이, exit1, `placement_snap_format.log` |
| `flutter build windows --release` | 성공, `placement_snap_windows_build.log` |
| `ctest --test-dir build/windows/x64 -C Release --output-on-failure` | 7/7통과 |
| 로컬 설치 catalog/객체 MPQ 왕복 | 71통과, `placement_snap_real_tools.log` |

현재 실행 SDK는 Flutter3.47.5/Dart3.13.4다. 저장소 기준3.44.8/3.12 재검증은 별도다.
전체 nonwrite format은435파일 중 기존 미변경 infrastructure 테스트3개의 차이로
exit1이었다(`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`). 사용자 변경과 해당 파일은 수정하지 않았다.

실행 중인 기존 Debug 앱을 덮어쓰지 않도록 이번 Windows 확인은 별도 Release 빌드를 사용한다.
SC:R 게임/외부 에디터 인수는 이번 작업에서 수행하지 않는다.
로컬 도구 회귀는 `STARCRAFT_DATA_HELPER_PATH`/`MAP_ARCHIVE_HELPER_PATH`를 Release helper로,
`STARCRAFT_TEST_INSTALLATION`을 실제 로컬 설치로 설정하고 catalog controller와
`object_editing_roundtrip_test.dart`를 실행했다. 기존 MPQ 왕복과 새 컨트롤러 좌표 검증을
구분하며 원시 게임 자산/추출 이미지는 저장소에 추가하지 않았다.

### 실제 Windows 관찰

별도 Release 창에서 복구 사본을 열거나 삭제하지 않고 Badlands128 새 맵을 만들었다.
한국어 체크박스/간격 메뉴의 레이아웃, 격자 숨김과 `격자 꺼짐` 표시를 확인했다.
좌표 스냅을 켜고16px를 선택한 뒤 로컬 카탈로그 Unit0을 배치했다.
Inspector 저장 좌표는1936,1984(둘 다16의 배수), 유닛 수는 시작 위치1->2였다.
실행 취소 버튼으로1개로 복원하고 Redo 활성화를 확인했다. 설정16px/격자 숨김도 유지됐다.
기존 Debug 창과 사용자 맵/복구 파일을 바꾸거나 저장하지 않았다. 새 테스트 맵은 미저장이다.
Windows pure Sprite/unit-sprite 수동 배치와 사용자 간격 대화상자는 이번에 직접 조작하지
않았으며 Shell3종/한영 widget 자동 회귀로 구분한다.
처음 Sky screenshot 참조가 `unknown screenshotId screenshot-0`로 거절되어 입력 없이
재관찰한 뒤 지원되는 window-relative 좌표 클릭으로 확인했다.

## 다음 작업

검증된 `units.dat` 건물 크기 자료의 출처/버전/포트/상한과 타일 정렬 규칙을 확정한다.
이후 중심 스냅과 건물 정렬을 구분하고 정상/자유 정책의 검사 지원표를 제공한다.
기존 객체 이동/템플릿/로케이션 정렬 및 실제 게임/외부 에디터 인수는 별도다.
