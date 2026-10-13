# 두다드 배치 사전 검증과 실행 기록

2026-10-13. 사용자 승인으로 EP 개발을 시작한 첫 구현 단위다.
FR-217/EP1/PAR-02의 **두다드 사전 검증**을 구현했다. EP0 전체 인수나
EP1 전체 배치 유형·썸네일·스냅 완료로 확대하지 않는다.

## 1. 실행 계획

1. 가이드/개발 계획/배치 설계와 현재 factory·컨트롤러·캔버스·테스트 분석.
2. 클릭 전 footprint의 지형·경계·레이어·섹션 상태를 실제 Apply와 같은 경로로 검사.
3. 읽기 전용 미리보기, 거절 안내와 캔버스 입력/Undo 회귀 구현.
4. 집중·전체 테스트, 포맷/분석, Windows 빌드/기동과 native 회귀 실행.
5. 실패 원인·수정·잔여 위험을 문서에 남기고 관련 변경만 커밋/푸시.

사용자의 기존 설정 섹션 조사/코드/테스트, 플랫폼·의존성 변경과 staged
`local.properties`는 변경·커밋하지 않는다. 입력 맵을 열어 수정/저장하지 않았으며
회귀 입력은 기존 자체 작성 fixture다.

## 2. 소스 분석과 변경

기존 `MapCanvasPainter`는 ghost가 맵 안에 들어오는지만 검사했다. 요구 지형이
맞지 않거나 레이어가 잠겨도 초록색으로 보인 뒤 클릭 시 거절될 수 있었다.

`ObjectEditingController._prepareCatalogDoodad`를 preview/Apply 공통 경로로
분리했다. `previewCatalogDoodad`는 사유 코드 또는 null(현재 배치 허용)을 반환한다.
세션 편집 가능 여부, 레이어, 유일한 크기/타일셋/지형, 요구 지형 그룹,
DD2/필요 THG2의 대상 섹션과 중심/전체 footprint 경계를 검사한다.
Apply는 저장된 hover 결과를 믿지 않고 다시 검사하고 기존 원자 명령으로 적용한다.

- 미리보기는 문서·선택·dirty·Undo/Redo·파일을 변경하지 않는다.
- UI는 application의 읽기 전용 callback만 사용하고 파서/FS/프로세스를 호출하지 않는다.
- 캔버스 build에서 검증하고 painter에는 결과만 전달한다. paint 중 검증은 하지 않는다.
- 허용 footprint는 초록색, 거절은 빨간색과 한영 사유다. 색상만으로 구분하지 않는다.
- 취소·맵 밖 포인터 이동 시 안내가 사라지고 안내는 캔버스 입력을 가로채지 않는다.
- 공통 `OBJECT_PLACEMENT_*` 10개 코드 모두 구체적인 한영 사유를 제공한다.
  그 밖의 미지원 유형/factory 코드 전체 번역은 이 작업의 완료 범위가 아니다.

빈 셀을 포함하는 sparse footprint의 일부가 맵 밖인데 기록 중심과 실제 쓰는 셀은
맵 안에 있는 사례도 발견했다. 기존 검사는 이 영역을 허용할 수 있었지만 이제
preview/Apply 모두 전체 영역을 검사한다. 기존 두다드 레코드를 자동 정규화하지 않는다.

## 3. 주석·최적화

공통 preparation과 sparse footprint 경계에 짧은 계약 주석을 추가했다.
미리보기에서는 전체 MTXM 목록을 복사하지 않고 footprint가 실제 쓰는 셀을 조회한다.
전체 목록 복사/인코딩은 성공한 Apply에서만 수행한다. footprint는 기존 recipe의
최대 16x16/256셀 상한을 유지한다. 전체 UI 이동 비용·profile FPS 개선은 아직
측정하지 않았으므로 최적화 완료 수치로 주장하지 않는다.

## 4. 요구사항과 시나리오 결과

| 시나리오 | 결과 / 확인 방법 |
| --- | --- |
| 허용 hover | fixture의 여러 원점에서 null, 세션/선택/Undo/Redo 동일. redo 사용 가능 |
| 지형/타일셋 불일치 | preview와 Apply 같은 코드, CHK·dirty·history 무변경 |
| 음수 좌표/오른쪽·아래 경계 | 예외나 부분 수정 없이 같은 out-of-bounds 거절 |
| sparse 영역 경계 | 쓰지 않는 셀이 맵 밖이어도 전체 거절, 기존 바이트 유지 |
| DD2/THG2 중복 | 모호한 대상을 추측하지 않고 같은 코드로 거절 |
| 두다드/지형 레이어 잠금 | hover 이후 잠금 변경도 Apply에서 재검증 |
| 실제 배치/Undo | 기존 DD2+MTXM+optional THG2 원자 명령 테스트 통과 |
| 표시/입력 | 320x240/800x600, 200% 글자 크기. 원점 일치·오류 안내·입력 통과·취소/포인터 이탈 확인 |
| 색상 | painter RGBA 픽셀 검사로 거절 red/허용 green 확인 |
| 셸 연결 | 실제 EditorShell widget에서 클릭 전 사유, 클릭 후 같은 실패·코드, 취소와 맵 무변경 확인 |
| 번역 | 공통 배치 진단 10종의 영어/한국어가 일반 fallback이 아님을 검사 |

초기 집중 실행에서 두 가지 문제가 발견됐다. 200% 글자 크기에서 기존 좌표
badge의 Row가 38/200px 넘쳤고, 작은 맵에서 안내 중앙이 실제 지도 밖이라
입력 통과 테스트가 클릭을 기대할 수 없었다. badge를 제한된 폭/Flexible·ellipsis로
고치고 32x32 지도 위의 입력을 검사하도록 fixture를 수정했다.
다음 실행에서는 320x240의 안내 하단 160px가 좌표 상단153px와 겹쳤다.
작은 높이의 안내를 2줄로 제한하고 좁은 화면의 좌표를 하단 도구 위로 분리한
후 동일 시나리오와 집중 테스트 전체가 통과했다. 안내는 미니맵 영역도 피한다.

## 5. 실행 명령과 증거

| 검사 | 결과 |
| --- | --- |
| 집중 테스트: object_placement_command/map_canvas/placement_catalog_pane | 68 통과. `.dart_tool/placement_preview_focused.log` |
| EditorShell `catalog refusals stay visible` | 1 통과. `.dart_tool/placement_preview_shell.log` |
| `flutter test` | 995 통과/환경 조건부48 skip. `.dart_tool/placement_preview_full_tests.log` |
| `flutter analyze` | 최종 오류 없음. `.dart_tool/placement_preview_analyze.log` |
| `dart format --output=none --set-exit-if-changed lib test tool` | 기존 미변경 infrastructure 테스트3개 차이로 exit1. 비쓰기 검사, 파일 무변경. `.dart_tool/placement_preview_format.log` |
| 변경 Dart 파일 포맷 | 11파일/변경0, 통과 |
| 로컬 문서 링크·whitespace | 변경8문서/279경로 존재, 누락0. `git diff --check` 통과 |
| `flutter build windows --debug` | 성공. `.dart_tool/placement_preview_windows_build.log` |
| `ctest --test-dir build/windows/x64 -C Debug --output-on-failure` | 7/7 통과 |
| Windows 일반 앱 기동 | 새 빌드 프로세스/에디터 창·복구 선택 화면 accessibility 확인. 복구본은 열거나 삭제하지 않음 |

실제 SDK는 Flutter3.47.5/Dart3.13.4, 기준은3.44.8/3.12다. 포맷 차이는 기존
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`다. 기준 SDK에서 전체 게이트를 재검증해야 한다.
로그/생성 이미지/외부 게임 자산은 배포물이나 fixture에 추가하지 않는다.
마지막 badge 정렬 보완 후 전체995개 회귀·정적 분석·Windows 빌드를 다시 실행했다.

## 6. 한계와 다음 작업

Windows 창 활성화가 `failed to activate captured window`로 실패했다.
새 대상 정보로 재조회 시 에디터 접근성 트리는 반환됐지만 스크린샷은 전면의 다른
전체 화면 프로그램을 보여줬다. 그 화면을 에디터로 오인해 클릭하지 않았다.
따라서 실제 Windows 마우스 조작/해당 화면 스크린샷 인수는 미실행이다.
위젯/painter 검증과 Windows 기동을 실제 조작·게임 인수로 대신 표시하지 않는다.

남은 EP1: unit-sprite 계약/배치 지원, 두다드 합성 썸네일, 다른 유형의 공통 사전
검증·미지원 안내, 스냅/정상·자유 배치 정책, 실제 앱·게임/외부 에디터 검증.
전체 EP0/EP1과 PAR-01~03은 닫지 않는다. 다음 구현 단위는 unit-sprite의
THG2 생성/지원표 검증 또는 두다드 합성 썸네일이다.
