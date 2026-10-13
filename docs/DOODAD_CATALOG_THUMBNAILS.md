# 두다드 카탈로그 합성 썸네일

2026-10-13, EP1/FR-217의 그림 선택 보완. 전체 EP1·게임/외부 에디터 인수를
완료했다는 뜻이 아니다. 이전 [사전 검증](PLACEMENT_PREVIEW.md)과
[unit-sprite 계약](UNIT_SPRITE_PLACEMENT.md)은 유지한다.

## 1. 계획과 소스 분석

가이드/개발 계획 -> 카탈로그·recipe·타일/객체 atlas·UI 분석 -> 읽기 전용 합성
설계 -> 구현 -> 집중/실제 자료/전체 회귀 -> Windows 실행 -> 문서/커밋 순이다.
게임 관찰 대기인 앞선 항목은 유지하고, 직전 인계의 다음 코드 단위를 진행했다.
기존 Doodad 분기는 metadata만 읽어 그림이 없었다. 새 helper·파일 포맷·자산
fixture를 추가하지 않고 검증된 `DoodadPlacementRecipe`와 기존 포트를 재사용한다.

## 2. 요구사항과 구현

- FR-217: 두다드 격자/상세에 footprint 타일과 optional overlay를 합성한다.
- `DoodadPlacementCatalogLoader`는 한 page의 고유 raw 타일과 overlay 키를
  정렬/중복 제거해 조회한다. kind/tileset/설치/offset/limit/요청 ID를 대조한다.
- page와 atlas의 제품·빌드·helper·CascLib revision이 같을 때만 그림을 사용한다.
  helper가 실패하면 원시 진단을 보존한다. 잘못된 page는 metadata도 게시하지 않는다.
- `DoodadThumbnailComposer`는 32px 타일, row-major 셀 좌표를 사용한다. 지형을
  쓰지 않는 셀은 투명하며 현재 맵의 바탕 타일을 임의로 대입하지 않는다.
- pure Sprite overlay는 Sprite 그래픽, sprite-unit overlay는 Unit 그래픽을
  요청한다. 종류가 같다고 숫자 ID만 치환하지 않는다. recipe 중심에서 atlas
  anchor를 빼서 배치하고, 바깥으로 나온 전체 그림도 합성 경계에 포함한다.
- premultiplied RGBA의 source-over와 픽셀 중심 최근접 샘플링을 사용한다.
  비율을 유지하며 최대64x64, 작은 원본은 확대하지 않는다. overlay는 기존
  neutral WPE/frame0/direction0 정책으로, 소유자·게임 애니메이션을 재현하지 않는다.
- 필요한 타일/overlay 하나라도 없으면 해당 항목의 그림 전체를 숨긴다.
  다른 정상 항목은 유지하며 UI는 누락 아이콘과 상세의 한영 설명/진단 코드를 표시한다.
- `thumbnailIssueCode`는 배치의 `issue`와 별개다. 그림 실패가 배치 recipe나
  availability를 바꾸지 않는다. 실제 Apply는 기존 footprint 검사를 다시 실행한다.
  그림 경고의 raw 진단은 `previewDiagnostics`에 보존하고 목록 차단 `diagnostics`와
  구분한다. 탭/설치 변경 시 지우며 그림 오류가 격자 선택까지 가리지 않게 한다.
- 요청 취소/탭 변경/설치 변경/폐기 후에는 결과를 게시하지 않는다. 타일 포트에는
  프로세스 cancel API가 없으므로 실행 중 작업을 강제 종료한다고 주장하지 않는다.
  timeout은 기존 process adapter를 따르고 완료 후 generation을 확인한다.

## 3. 최적화와 안전

큰 원본 합성 버퍼를 만들지 않고 출력 픽셀에서 직접 타일과 overlay를 샘플링한다.
16x16 footprint의 원본은 512x512/1MiB인데 출력은 최대16KiB다. 이는 크기 상한
비교이며 전체 peak memory나 프레임 시간의 전후 벤치마크가 아니다. 별도 cache나
중복 디코더 없이 기존 virtualized grid와 작고 불변인 썸네일 버퍼를 사용한다.

한 page는 고유 타일4096개/원시 타일 픽셀16MiB까지 조회한다. 초과하면 atlas
요청 전에 `SC_CATALOG_DOODAD_PREVIEW_LIMIT_EXCEEDED`로 그림만 생략한다.
overlay는 page 최대256개이고 기존 object atlas 출력 제한을 따른다. 최종 썸네일은
원본 atlas backing buffer를 참조하지 않는다. 충분한 자료가 있어도 page 합계가
상한을 넘으면 썸네일을 생략할 수 있다. 대량 전체 카탈로그 peak/profile은 후속이다.

조회/선택은 CHK·dirty·Undo를 바꾸지 않는다. 도메인은 Flutter/FS/프로세스에
의존하지 않으며 UI는 loader를 연결한 controller만 사용한다. 입력 맵, unknown
CHK, raw 문자열, 기존 enabled/flags/배치 좌표의 정규화는 없다. 원시/추출 게임
자산은 로컬 임시 조회에만 사용하며 저장소나 배포물에 넣지 않는다.

## 4. 시나리오와 실패 분석

| 시나리오 | 판정 |
| --- | --- |
| 직사각형/row-major/빈 셀 | 고정 RGBA 기대값과 투명 픽셀 일치 |
| 비대칭 anchor/반투명 overlay/바깥 경계 | 위치·premultiplied 합성·잘림 방지 픽셀 일치 |
| 큰 footprint/출력 소유권 | 비율·64px/16KiB 상한·불변 독립 버퍼 확인 |
| tile/overlay 키 | 정렬·중복 제거, Unit과 Sprite의 같은 ID 구분 |
| 미지원 tile/overlay/recipe | 해당 그림만 생략, 부분 그림·임의 대체 없음 |
| 설치/build 불일치·throw·실패 응답 | 잘못된 그림 거절, raw 진단·배치 recipe 보존 |
| 취소/상한 초과 | 늦은 게시 없음, 불필요한 다음 조회/큰 atlas 할당 없음 |
| 격자/상세/그림 없음 | 위젯 렌더, 설명 표시, 그림 실패만으로 Place 비활성화 안 함 |
| 조회/선택 | 동일 session/CHK, Undo 증가0 |
| 실제 Doodad 배치 | 기존 실제 CASC 복합 지형/overlay 배치·Undo/Redo 회귀 유지 |

최초 새 테스트는 non-const 생성자를 const로 선언하여 컴파일이 실패했다.
수정 후 두 실패 입력은 카탈로그 키 정렬 계약을 어겼다. 테스트 ID 순서를
고쳤으며 입력 검증은 완화하지 않았다. 분석의 if 블록/미사용 import도 보완했다.
최종 집중·전체·실제 자료 검사는 아래 결과를 따른다.
최종 UI 조건 검토에서 기존 `diagnostics`가 있으면 격자 전체를 가리는 경로를
확인했다. 목록 오류/그림 경고를 분리하고 helper throw에도 격자·명시적 선택·
recipe가 유지되며 탭 전환 후 경고가 사라지는 위젯 회귀를 추가했다.

## 5. 실행 기록

실제 SDK는 Flutter3.47.5/Dart3.13.4, 저장소 기준3.44.8/3.12와 다르다.

| 검사 | 결과 |
| --- | --- |
| 집중 loader/controller/pane/dialog | 77 통과/8 조건부 skip, `.dart_tool/doodad_thumbnail_focused.log` |
| 실제 CASC loader/controller | 71 통과, `.dart_tool/doodad_thumbnail_real_tools.log` |
| 전체 `flutter test` | 1,032 통과/50 조건부 skip, `.dart_tool/doodad_thumbnail_tests.log` |
| `flutter analyze` | 무이슈, `.dart_tool/doodad_thumbnail_analyze.log` |
| 비쓰기 전체 포맷 | 432개 중 기존 미변경 테스트3개 차이, `.dart_tool/doodad_thumbnail_format.log` |
| Windows debug build | 성공, `.dart_tool/doodad_thumbnail_windows_build.log` |
| native CTest | 7개 통과 |
| 변경 Dart 비쓰기 포맷 | 8개/변경0 |
| 문서/공백 | 변경 문서8개 로컬 링크296개, `git diff --check` 통과 |
| Windows 직접 실행 | 복구 목록 닫기 -> 임시 Badlands128x128 -> Catalog -> Doodad -> 그림/상세 확인 |

전체 포맷 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
수정하지 않았으며 변경 파일 포맷 검사는 별도로 수행한다.

로컬 CASC는 8개 타일셋 각16개, 총128개를 확인했다.126개 합성/2개 누락이며
spacePlatform의 `doodad:1:6:1036`/`1037`은 기존 `SC_CASC_DOODAD_FLAGS_INVALID`를
유지했다. 나머지 첫 page에는 누락이 없었다. 최종 실제 자료 실행의 page 소요시간은
560~882ms, 썸네일 합계는 타일셋별131,072~262,144B였다. Windows debug/로컬
설치의 첫16개 표본이며 전체 catalog나 release 성능 수치가 아니다.

Windows1266x713에서 첫 page128개, 서로 다른 CV5 variant의 그림을 확인했다.
첫 Doodad #0 선택 후 격자/상세 그림과 크기4x2 타일, 진단0·두다드0개를
확인했다. 항목 조회로 배치하지 않았으며 임시 새 맵은 사용자 맵에 저장하지 않고
앱에 열어 두었다. 직접 UI 배치/저장과 게임/외부 에디터 인수는 이번에 하지 않았다.
비차단 그림 도구 오류 경로는 위젯에서 검증했고, 진단 분리 후 Windows 빌드도
다시 통과했다. 직접 Windows 조작에서는 정상 그림 조회 경로만 확인했다.

## 6. 다음 작업

EP1의 유닛/Sprite 등 다른 유형 공통 사전 검증·스냅/정상·자유 배치 정책이 남는다.
게임/외부 에디터 관찰 대기와 unit-sprite 관계/터렛 지원표는 유지한다.
이 그림은 현재 맵 바탕·선택 owner·애니메이션·Remastered skin의 실시간 합성이 아니다.
