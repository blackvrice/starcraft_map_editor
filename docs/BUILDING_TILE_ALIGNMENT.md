# 건물 크기와 타일 정렬

2026-10-13. FR-218, EP1의 건물 정렬 단위. 정상/자유 배치와 게임 건설 가능성
전체를 완료한 것은 아니다. [이전 좌표 스냅](PLACEMENT_GRID_SNAP.md)을 보존한다.

## 1. 실행 계획과 소스 분석

1. 고정된 primary source에서 크기의 의미/offset/좌표 단위를 확인한다.
2. 기존 로컬 catalog 포트에 optional versioned 크기를 추가하고 unknown은 추측하지 않는다.
3. 순수 정렬/박스 경계를 preview/Apply/커서에 연결하고 기본 동작·문서를 보존한다.
4. native/프로세스/도메인/배치/화면/저장 회귀와 실제 로컬 자료·Windows 실행을 구분한다.

근거: Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[Unit::DatFile](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L508-L577)과
[건물 정렬](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L1837-L1856)을 읽었다.
StarEdit placement box는 u16 width/height 쌍228개이며 addonOffset/unitExtent와 별도다.
앞의 고정 배열 크기를 합산한 offset11284에서 ID별4byte를 읽는다(전체 classic19876byte만).
타일 축 홀짝에 따라 중심이0/16(mod32)으로 달라지는 정렬을 참조했다. 우리 구현은
음수 입력과 박스 맵 밖 출력을 거절하며 경계에 자동 clamp하지 않는다.

## 2. 자료·안전 계약

| 항목 | 계약 |
| --- | --- |
| native 입력 | classic units.dat 크기/ID 범위 검증 후 StarEdit width/height만 읽음 |
| 전달 | `capability.placementBox = {version:1,width,height}` 또는null |
| 버전 | protocol3/helper0.13.0의 additive optional 필드, 버전/기존 로그 유지 |
| 지원 크기 | 각 축32~8192px, 32의 배수. 예산/정렬 지원 한계이지 게임 크기 보증이 아님 |
| unsupported 크기 | native는null로 격리, 다른 capability flags/일반 배치 유지 |
| old/null 응답 | 기존 catalog 조회 가능. 타일 정렬을 켜면 자료 누락 사유로 거절 |
| 잘못된 응답 | 미지원 version/형식/축 범위/비건물 box는 gateway invalidResponse |
| domain | `BuildingPlacementBox`, Flutter/파일/프로세스 의존 없음 |
| 대상 | 새 카탈로그 UNIT Building만, 선택적 체크박스 기본 꺼짐 |
| 우선순위 | 건물 정렬이 켜진 Building은 중심 좌표 스냅보다 우선 |
| geometry | 가까운 타일 박스 원점, 동률은 큰 좌표. 전체 박스 경계 검사 |
| preview/Apply | raw 클릭 위치를 먼저 검사하고 같은 준비 경로에서 재정렬/현재 문서 검사 |
| 데이터 | 기존 레코드/unknown/섹션 순서 불변, 성공1회 Undo 명령·실패 무변경 |
| 다른 유형 | pure Sprite/unit-sprite/Doodad·기존 이동/템플릿/로케이션 유지 |

체크박스 변경은 문서·dirty·Undo를 바꾸지 않고 runtime-only 설정을 유지한다.
예:128×96 박스의 클릭63,47 -> 중심64,48 -> 원점0,0.
박스 전체가 맵 경계에 정확히 닿으면 허용하지만 중심만 맵 안에 있고 박스가
밖이면 거절한다. 자료 누락 사유는 `OBJECT_PLACEMENT_BUILDING_BOX_UNAVAILABLE`이며
한영 안내를 추가했다. 클릭은 이전 hover를 승인 근거로 사용하지 않는다.

## 3. 요구사항 체크리스트와 제한

| 요구사항/시나리오 | 판정 |
| --- | --- |
| 검증된 로컬 건물 크기/출처·버전 | 구현, native 합성/실제 로컬 설치 확인 |
| 짝수/홀수 축 정렬·박스 전체 경계 | 구현, domain/command/widget 회귀 |
| 크기 누락/invalid/오래된 helper 응답 | 추측 없이 누락 거절 또는 invalidResponse |
| layer/history/relation/subunit/ID 검사 | 기존 factory/공통 사전 검증 유지 |
| 실패/hover/설정 변경 무변경·Undo/Redo | 자동 회귀 |
| 박스 커서·한영 좁은 화면 | widget/Shell 검증 |
| Save As·MPQ 바이트 보존 | fake Save As와 native 임시 출력/재열기 경로 구분 |
| 충돌·지형 buildability·전력·크립 | 미구현. 타일 정렬 결과를 게임 적법성으로 표시하지 않음 |
| EUD/런타임 DAT 변경 | 로컬 기본 자료만 사용, 변경된 런타임 크기 보증 안 함 |
| SC:R 게임/외부 에디터 | 별도 인수 대기 |

## 4. 최적화와 주석

정렬/박스 검사 O(1), 별도 객체/지형 전체 스캔이나 충돌 인덱스를 추가하지 않았다.
기존 문서 identity별 class ID 요약 캐시를 재사용한다. factory의 기존 거절 사유를
유지하기 위해 먼저 record를 준비한 뒤 건물 박스를 검사한다.36byte 준비 비용을
추측 기반 다른 factory 경로로 대체하지 않았다. FPS/메모리 개선 수치는 측정하지 않았다.
native offset/별도 collision extent 의미와 domain 홀짝/동률 규칙에 주석을 추가했다.

## 5. 실행·실패·결과 분석

합성 입력은 직접 만들었으며 게임 원시 자산/추출 이미지/다른 제작자 맵은 추가하지 않았다.
로컬 ignored `.dart_tool/building_alignment_*.log`에 원시 명령 결과를 보관한다.

- 초기 focused에서 영어 라벨 Row의 좁은 화면 overflow를 재현했다. bounded
  CheckboxListTile로 줄바꿈을 적용했다.
- 후속 Shell에서 ListTile의 ink가 부모 ColoredBox에 가려진다는 Material assertion이
  다수 발생했다. 투명 Material을 해당 컨트롤에 제공해 근본 원인을 수정했다.
- 신규 테스트의 unbraced-if lint2개를 수정한 뒤 analyze를 재실행했다.
- 로컬 설치 s1/build13515의 Unit106 metadata-only 조회에서 version1/128×96px를 확인했다.
  그림 요청 없이 크기를 읽었다. 이것은 게임 실행 확인이 아니다.

신규 일반 테스트48개(domain13, command19, catalog4, process8, Shell3, canvas1)와
선택 스모크2개(local metadata, native MPQ)를 추가했다. 기존 Save As/한영 안내 회귀도 확장했다.

| 검증 | 결과 / 로그 |
| --- | --- |
| initial focused | 133통과, `building_alignment_initial.log` |
| 확대 focused / retry | 좁은 화면/Material 실패 재현, 각각 `building_alignment_focused.log`, `building_alignment_focused_retry.log` |
| 최종 Shell6종 | 6통과, `building_alignment_shell_final.log` |
| `flutter analyze` | 최종 No issues, `building_alignment_analyze_latest.log` |
| `flutter test --concurrency=4` | 초기1170통과/52skip, u16 추가 후1172통과/52skip, `building_alignment_tests_final.log` |
| 비표준 DIM/u16 출력 overflow | 가로/세로2통과, `building_alignment_u16.log` |
| 실제 로컬 metadata/catalog/MPQ | 100통과, `building_alignment_real_tools.log` |
| Debug native 변경 target 빌드/CTest | 빌드 성공,7/7통과, `building_alignment_native_build.log` |
| `flutter build windows --profile` | 최종 성공, `building_alignment_windows_build_final.log` |
| 최종 `flutter build windows --debug` | u16 검사 포함 성공, `building_alignment_debug_final.log` |
| Profile native CTest | 7/7통과 |
| 변경 Dart20파일 nonwrite format | 0변경, 통과 |
| 전체 nonwrite format | 437파일 중 기존 미변경3개 차이로exit1, `building_alignment_format_final.log` |

실제 스모크는 helper/설치 환경 변수를 Profile helper와 로컬 SC:R 경로로 지정했다.
fake Save As는 기존 unknown/섹션 순서와 일반 UNIT+정렬 건물의 저장 좌표를 검사한다.
native MPQ 시나리오는 별도 임시 출력/재열기와 원본 아카이브 바이트 불변을 검사하며
Save As UI나 게임 동작 확인과 혼동하지 않는다.

실행 SDK는 Flutter3.47.5/Dart3.13.4로 기준3.44.8/3.12와 다르다. 기준 SDK 재검증은 남는다.
기존 앱 문서를 닫지 않고 별도 Profile 앱으로 UI를 확인했다. 마지막 u16 출력 검사를
추가한 뒤 Debug 전체 runner 빌드도 성공했고 Debug CTest7/7을 다시 확인했다.
기준 SDK와 게임 인수는 별도다.
전체 format의 미변경 차이는 infrastructure의 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
초기 주석 추가 파일의 포맷 차이는 수정했으며 사용자 변경과 기존3개는 유지했다.

### Windows 수동 관찰

별도 Profile 창에서 복구 사본을 열거나 삭제하지 않고 Badlands128 새 맵을 만들었다.
`건물 타일 정렬`을 켜고 실제 카탈로그 Unit106을 선택했다. 확대125%에서 왼쪽 경계
클릭 위치의 hover 표시(raw Pixel30,2052)는 붉은 전체 객체 경계 사유를 보여주고
유닛 수1개를 유지했다. 내부 클릭은 Unit106 중심2016,2384를 저장했다.
x는0(mod32), y는16(mod32)으로128×96 박스의 정렬에 맞고 유닛 수2개가 됐다.
Edit -> 실행 취소로1개로 복원했다. 타일 정렬 설정은 유지했고 새 맵은 저장하지 않았다.
이전 Debug/Release 창과 사용자 맵 파일은 수정하지 않았다.

Sky 검색 텍스트 입력 시도는 화면에 반영되지 않았다. 재관찰 후 접근성 `set_value`도
`element ... is not available in cached app state`로 거절되어 스크롤로106번을 선택했다.
원인은 확정하지 않았으며 검색 입력/단축키는 이번 Windows 수동 성공 판정에 포함하지 않는다.
수동 확인 종료 후 추가 창 상태 조회는 사용자의 물리 Esc 입력으로 중단됐다.
이후 Computer Use 호출/창 조작은 하지 않고 CLI 검증·문서·커밋 작업만 진행했다.

### 최종 경계 보완

diff 검토에서 비표준 DIM2049×8/8×2049의65535 좌표가 정렬 후65536이 되는 경로를
확인했다. 박스는 해당 DIM 안에 들어갈 수 있어 박스 경계만으로는 CHK u16을 보장하지
못한다. factory의 RangeError를 유발하지 않도록 정렬 출력에도 u16 범위를 검사하고
`outOfBounds`로 거절했다. 두 합성 회귀는 원본/Undo 무변경까지 확인했다.
이 보완 후 전체 테스트/분석/Debug 빌드를 다시 실행했다. 비표준 맵 게임 호환성을
지원한다는 뜻은 아니며 Profile 수동 관찰은 앞의 일반128×128 맵에 한정한다.

## 6. 다음 작업

정상/자유 배치 검증 지원표와 collision extent/지형 자료 계약을 확정한다. 검증된
경계/ID/레이어/섹션/두다드 지형 검사를 자유 모드에서도 끄지 않아야 한다.
전력/크립과 EUD 변경 자료의 미확인 상태, 게임/외부 에디터 인수는 계속 별도다.
