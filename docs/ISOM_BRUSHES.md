# 등각 경계·높이 브러시와 경사로

2026-10-03: Map 지형 도구 줄의 **지형** 버튼은 경계 브러시 모드로 직접 연다.
변형 seed(0~4294967295) 또는 섞기 버튼으로 타일 변형을 고른다. 잘못된 seed는
입력 오류를 표시하며 미리보기/적용에 사용하지 않는다. 새 맵은 기본적으로 검증된
평지 ISOM을 생성하므로 초기 평지 채우기를 별도로 할 필요가 없다.

2026-10-01. 기본 등각 지형 편집 구현 완료 범위다. 실제 게임의 통행과 외부
에디터 인수는 별도 검증이다. 후속 [ISOM·두다드 resize](MAP_RESIZE.md) 구현도 완료했다.

## 사용

Settings에서 로컬 SC:R 데이터를 지정하고 **File → 등각 지형 채우기**를 연다.
ISOM이 없는 신규 raw 맵은 먼저 평지 채우기를 적용한다.

- **경계 브러시**: 지형 종류 ID를 선택하고 자유 브러시 또는 선택 영역을 그린다.
  높이 전환도 해당 지형 ID를 선택한다. 크기는 1~4 다이아몬드이며 맵 끝에서 잘린다.
  다른 종류의 획을 미리보기에 누적할 수 있다. 주변 경계는 선택 영역 밖까지 연결된다.
- **경사로**: 로컬 VF4로 확인된 배치 자료를 선택하고 맞는 절벽의 왼쪽 위 타일을
  클릭한다. Doodad ID/CV5 시작 그룹·크기로 변형을 구분한다. 방향은 배치 자료에
  고정되어 있으며 임의 회전하지 않는다. 대각선 계단 형태를 포함하여 DDData의
  모든 footprint 조건이 맞는 절벽을 먼저 만들어야 한다.
- 로컬 타일을 렌더한 캔버스와 변경 타일 수를 확인하고 **지형 편집 적용**을 누른다.
  미리보기 초기화와 취소는 문서를 바꾸지 않는다. 브러시 획 전체 또는 경사로 한 건을
  공통 Undo 한 건으로 적용한다. 기존 Save As로 저장하고 재열 수 있다.

자료 이름이 없는 항목에 이름을 추측해서 붙이지 않는다. 렌더 자료가 준비되지
않으면 기존 숫자 타일 표시를 사용한다. 새 맵의 평지 채우기와 기존 ISOM 재계산도 유지한다.

## 연결 규칙

`IsomBrushCatalog`는 평지·14개 전환 형태의 다이아몬드 연결 ID와 종류 인접 그래프를
담는다. 같은 CV5 snapshot에서 outer/inner soft-link를 읽으며 숫자 형태/그래프는
고정 [Chkdraft](https://github.com/TheNitesWhoSay/Chkdraft/tree/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core)의
규칙을 대조·적용했다. [MIT 고지](licenses/Chkdraft.txt)를 배포물에도 유지한다.
catalog revision은 `transition-isom-v2:<snapshot revision>`이다.

순수 domain `IsomTerrainPaint`는 `(x+y)%2==0` 다이아몬드를 네 ISOM rectangle에
투영한다. 원본의 모든 투영 값·인접 연결과 기존 CV5 타일 쌍을 먼저 확인한다.
선택 다이아몬드를 고정한 뒤 인접 종류 그래프의 첫 경로, 변경 이웃의 종류,
평지 후보 순으로 일치 후보를 찾고 주변에 전파한다. 255 이상 연결은 종류도 같아야
한다. 전파는 맵 크기로 제한하고 최종 모든 인접성을 다시 검사한다.

원본과 같은 종류를 칠하면 ISOM 플래그를 정규화하지 않는다. 실제 변경 다이아몬드에만
사분면 edge flag를 기록하고 기존 bit 0/15를 보존한다. 그 후 기존
[수직 적층 변환](ISOM_TRANSITIONS.md)의 열 전체/member 경로로 TILE/MTXM을 산출한다.
연결·카탈로그·적층 경로가 없으면 부분 적용 없이 전체 획을 거부한다.

## 경사로와 두다드

helper **0.12.0**, protocol 3은 기존 두다드 자산 5개에 해당 타일셋의 VF4를
추가하여 6개를 읽는다. VF4 길이는 VX4EX mega-tile 수와 일치해야 한다.
footprint의 모든 mega 참조를 검증하고, 4방향으로 연결된 보행 가능 mini-tile
영역에 Ramp bit `0x10`과 서로 다른 elevation이 있을 때만 `hasRamp=true`를 반환한다.
평지의 Ramp bit만 있거나 보행 불가능한 영역은 경사로로 분류하지 않는다.
Dart는 `hasRamp` boolean과 자산 수를 엄격히 확인한다. 원시 자산·추출 이미지는 배포하지 않는다.

경사로는 검증된 Doodad recipe로 MTXM·DD2 및 필요한 THG2를 함께 추가한다.
ISOM과 바닥 TILE은 그대로 보존한다. 따라서 경사로로 인해 TILE과 MTXM이 다른
것은 정상이다. 일반 브러시는 기존 두다드의 정확한 recipe·활성 값·footprint 타일을
확인하고 바닥 TILE에서 변환한 뒤 overlay를 복원한다. 투명 셀을 포함한 전체
footprint 바닥이 변하면 거부한다. THG2 소유권을 좌표만으로 추측하지 않는다.

보호·중복·손상 지형, 원시 MTXM 덮어쓰기, 미확인/비활성/겹친 두다드, 불일치
footprint는 보존하고 편집을 거부한다. 기존 전체 채우기/재계산은 여전히 두다드를
거부한다. 경사로 선택은 보행 메타데이터에 근거하며 실제 게임 경로 탐색 인수와 다르다.

## 검증

- 합성 자료: 같은 종류 칠하기의 바이트 보존, 없는 경계·잘못된 diamond·불일치
  투영 거부, 경사로 방향/지형/범위·unknown bytes·ISOM/TILE 보존, 모호한 recipe와 겹침 거부.
- 컨트롤러/한영 위젯: 미리보기 무변경, 적용·취소·단일 Undo/Redo, 오래된 초안과
  맵/설정 변경 거부, 늦은 경사로 카탈로그 취소, 실패한 획 이전 미리보기 유지.
- 실제 CASC: 8개 타일셋의 모든 평지 종류 쌍에 단일·두 모서리·선택 영역·꺾인 획,
  변환 멱등성. 8개 모두에서 생성 지형에 VF4 경사로 배치와 CHK 왕복·로컬 타일 렌더.
- 실제 자체 제작 MPQ: 여러 종류의 획·경사로 적용, Undo/Redo, Save As·재열기 바이트
  일치와 입력 파일 fingerprint 불변성. 원시 게임 자산을 fixture로 저장하지 않는다.
- 전체 Flutter 904개 통과/43개 선택 검증 skip. 마지막 맵 변경 무효화와 두다드
  보호 보완 후 관련 15개 테스트를 다시 통과했다. analyze 무이슈,
  Windows Debug 빌드·시작, native CTest 7/7 통과. 실제 자료 검증은 별도로 실행했다.

전체 테스트는 `flutter test --no-track-widget-creation --concurrency=1`로 통과했다.
기본 실행에서는 설치 SDK의 최적화 JIT가 Flutter dropdown 컴파일 중 내부 UTF8 오류로
종료되는 사례가 있었다. SDK나 앱 코드를 우회 수정하지 않았다. 기존 적층 회귀의
동일 생산 코드 경로도 임시 순수 Dart 검증으로 실행해 8개 타일셋/1,718개 적층 경로,
변환 멱등성·CHK 바이트 왕복·로컬 렌더를 통과했다. 이 보조 검증은
`dart.exe --optimization-counter-threshold=-1`로 JIT 최적화를 꺼 실행했으므로 성능 근거가 아니다.

실제 설치 검증 명령(로컬 설치 경로를 지정하며 원시 자산은 저장하지 않는다):

```powershell
$env:STARCRAFT_DATA_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/starcraft_data_helper.exe').Path
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
$env:STARCRAFT_TEST_INSTALLATION = 'C:\Program Files (x86)\StarCraft'
flutter test --no-track-widget-creation --concurrency=1 test/integration/isom_brush_local_data_test.dart test/integration/isom_brush_roundtrip_test.dart
```

사용 SDK는 Flutter 3.47.5/Dart 3.13.4로 기준 3.44.8/3.12와 다르다.
필수 전체 포맷 검사는 기존 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`의
형식 차이로 실패한다. 이번 변경 파일의 포맷은 통과하며 기존 파일은 변경하지 않는다.
실제 게임의 통행·외부 에디터 편집/재저장과 독립 배포 환경은 이번 자동 검증에 포함하지 않는다.
