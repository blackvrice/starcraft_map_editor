# 읽기 전용 지도 분석

## 실행 계획과 요구사항

2026-10-18 EP4 / FR-219의 지형 표시를 구현했다. 기존 좌표/배치 검사와 별개로
기본 편집 도구 → **지도 분석** 탭에서 표시한다. 실제 수집기 미지원과
자동 테스트·빌드만 진행하는 사용자 결정을 유지한다.

1. 분석: raw MTXM view, CV5/VF4 배치 snapshot, helper decoder, 캔버스의
   viewport/카메라/계측, 전력/크립의 기존 관찰 경계를 확인했다.
2. 설계: 로컬 높이/건설/이동 사실과 미확인을 분리하고, 화면에 보이는 타일만
   projection하는 제한 캐시·읽기 전용 UI·취소/문서 수명을 정의했다.
3. 실행: 선택적인 VF4 높이 프로필, domain view, application 제어기,
   캔버스 overlay·범례/상태·픽셀 거리 측정을 추가했다.
4. 검증: synthetic/native 비트, malformed/최대 packet, stale/Undo/취소,
   렌더 픽셀·좁은 화면·256×256 스모크와 실제 8타일셋 자료를 검사했다.

## 지원과 미지원

| 모드 | 출처/의미 | 제한 |
| --- | --- | --- |
| 높이 | 로컬 VF4의 16개 8px 미니타일 | 동적 고도/시야 계산 아님, 프로필 누락은 미확인 |
| 건설 가능 | CV5 group의 unbuildable bit7 | 유닛 점유·전력/크립·자원 거리·전체 건설 허가 아님 |
| 이동 가능 | VF4 bit0 | UNIT 충돌·게임 pathfinder/도달 가능 영역 아님 |
| 실제 전력/크립 | 수집기 미지원 상태 | 모든 셀 미확인. false/꺼짐으로 추정하지 않음 |
| 거리 측정 | 사용자 입력 중심/픽셀 반경 | DAT 무기/시야 사거리 및 업그레이드/EUD 적용값 아님 |

기존 배치의 preplacedLayout 전력 조회/크립 후보·관찰 진단은 유지한다.
본 분석 탭의 실제 전력/크립은 계속 미확인이다. 후속 구현한
[주 편집 지도 보조 표시](EDITOR_OVERLAYS.md)에서는 DAT 기본 사거리·시야와
명시적으로 구분된 배치 설계 전력장을 제공하며 같은 지형 분석도 켤 수 있다.
별도 분석 탭의 카메라와 수동 거리 측정은 그대로 유지한다.

## 수치와 프로토콜

VF4의 bit1=중지, bit2=고지이며 둘 다 있으면 고지를 우선한다. 없는 높이
자료를 저지로 치환하지 않는다. 고정된 [Chkdraft sc.h 3743~3764](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L3743-L3764)를 대조했다.
구현은 기존 CV5 bit7/VF4 bit0 projection에 독립적인 두 uint16 mask를 추가한다.

`readTerrainPlacement`의 snapshot v1에 선택적 `elevationProfile`을 추가했다.
helper/wire 기존 계약을 바꾸지 않는 capability 확장이며 프로필 자체는 version 1,
`midMasks`/`highMasks`는 VF4 mega-tile 수와 정확히 같은 길이다. 누락/null은
legacy 미확인으로 허용하고, 미지원 버전·음수·실수·65535 초과·길이 오류는
packet 전체를 거절한다. source revision에 프로필 유무/전체 값을 포함한다.
최대 coverage(4096 CV5/65536 VF4)와 기본 2 MiB stdout 상한을 함께 검사했다.

제품/빌드/helper/CascLib·두 asset의 크기/SHA256·raw 로그는 기존 포트 결과에
남기며 UI에 제품/빌드/helper와 자료 revision을 표시한다. 자산·추출 이미지를
fixture나 배포물에 추가하지 않았다.

## 안전과 캐시

- `TerrainAnalysisController`는 명시적인 자료 불러오기에서만 포트를 호출한다.
  모드 전환·지도 이동·거리 측정·그리기에는 프로세스를 실행하지 않는다.
- maps/session/extractedMap, 설치 설정 identity, 타일셋, 요청 epoch와 폐기를
  검사한다. 문서 변경 중의 요청은 취소하고 늦은 응답을 버린다.
- 지형 자료는 같은 문서의 일반 편집에서 재사용할 수 있지만, projection view는
  문서 변경/Undo마다 새로 만든다. 새 맵/자료 변경/실패 reload 후는 미확인이다.
- domain view는 raw 값별 최대 4096개 LRU를 지연 계산한다. 알 수 없는 값도
  캐시하고 표시된 영역 밖 타일을 미리 계산하지 않는다.
- MTXM/CHK/리소스/dirty/Undo·편집 선택을 바꾸지 않는다. 분석 지도는 별도
  카메라를 사용한다. 거리 중심은 맵 내부, 반경 1~8192px로 제한한다.

## 표시와 최적화

tile extent 8px 이상이면 4×4 미니타일을 그대로 색칠한다. 그보다 작을 때는
한 타일 안의 값이 섞인 경우 별도 혼합색으로 표시하며 한 점을 샘플링해 전체가
가능/불가 또는 같은 높이라고 표시하지 않는다. 미확인은 회색과 확대 시 사선이다.
지도 경계/객체/선택은 기존 렌더 순서를 유지하고 overlay는 지형 바로 위에 그린다.

기존 `MapCanvasPaintMetrics`에 표시한 타일/미니타일 수를 추가했다. 숫자
snapshot과 projection은 공유하되 UI/renderer가 I/O를 직접 호출하지 않는다.
높이 비트 우선순위, 캐시 수명, 저확대 혼합 판정에 계약 주석을 추가했다.

256×256 synthetic debug 스모크(800×600, 첫 집중 실행):

| 모드/확대 | 표시 타일 | 3회 paint µs | 고유 projection/캐시 |
| --- | --- | --- | --- |
| 높이/1× | 65536 | 46610 / 32414 / 27916 | 32 / 32 |
| 이동/1× | 65536 | 29814 / 28541 / 28134 | 32 / 32 |
| 높이/8× | 1408 | 8630 / 8748 / 9262 | 32 / 32 |
| 이동/8× | 1408 | 7747 / 8981 / 9917 | 32 / 32 |

이는 환경 의존적인 debug 스모크이며 1초 이상 병적 동기 계산을 검출하는
상한이다. 16.7ms 프레임 보장, 실제 자산 profile/release, RSS 예산 완료로
간주하지 않는다. 전체 지도 표시에서 draw-call/세분화의 추가 최적화는 후속이다.

## 검증 체크리스트와 실행 결과

- [x] native 합성 VF4의 bit1/bit2 독립 보존과 원본 입력 무변경
- [x] 누락 높이/invalid reference는 미확인, 둘 다 있는 높이는 고지 우선
- [x] 프로필 버전/마스크/coverage·최대 프로세스 packet·legacy 호환·raw 로그
- [x] source revision·raw immutable/LRU 상한·화면 밖 미계산
- [x] 문서/자산 변경·늦은 응답/취소·실패 재시도·Dispose·Undo 무변경
- [x] 실제 픽셀의 높이/미확인/거리 원 표시와 visible 계측
- [x] 600px/1200px 한국어 UI의 모드/로드/거리 측정·원본/Undo 보존
- [x] 로컬 SC:R 8타일셋의 CV5/VF4 읽기·높이 coverage·hash/revision 반복 확인
- [ ] 실제 앱 수동 조작, 게임/외부 에디터/DPI·release profile/RSS 인수

집중 6개 파일 84개 통과. 별도 실제 CASC+프로세스 경계 2개 파일 11개 통과
(8타일셋 검사 1개와 최대 크기/오류·취소 검사 포함), Windows Debug 빌드와
native CTest 7/7 통과. 최종 기본 `flutter test`는 **2326 통과/72 조건부 skip**,
`flutter analyze`는 무이슈다. 전체 format은 기존 미수정 인프라 테스트
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart`의 3개 차이로 exit 1이며 이번 변경 파일은
포맷 차이가 없다. 기존 third-party CMake 최소 버전 경고는 유지한다.
첫 렌더 테스트의 `MapCanvasLayout.fit`에 없는 zoom 인자는 `view` 생성자로
수정했고, 수정 후 픽셀·viewport 테스트가 통과했다. 정적 분석에서 검출한
조건문 스타일/불필요 import도 수정했다.

첫 기본 전체 실행은 2300 통과/72 skip과 기존 object/tile atlas 테스트 2개의
30초 timeout으로 실패했다. 두 파일을 단독 실행하면 13개가 모두 통과했다.
각 실패 테스트는 13개의 외부 프로세스 검사를 한 테스트 안에서 실행하고
있었다. 검사를 제외하거나 timeout을 늘리지 않고 각 scenario를 개별 테스트로
분리했다. 그 결과 테스트 수가 24개 늘어난 것은 신규 기능 24개를 추가한 것이
아니라 기존 검사 집계 단위의 변경이다. 수정 전 동시성 4 재검증은
2302 통과/72 skip이었다. 수정 후 기본 전체 실행은 2326 통과/72 skip으로
통과했고 원래 assertion과 helper 시간 제한은 유지한다. 관련 문서 6개의
상대 링크 197개도 경로 존재 검사를 통과했다.

환경 Flutter 3.47.5/Dart 3.13.4는 기준 3.44.8/3.12와 다르다.
사용자의 기존 미커밋 변경을 포함한 공유 작업 트리에서 검증했다.
게임을 실행하거나 수동으로 앱을 조작하지 않았다. 언어/소스/출력·출시 등
전체 잔여 기능의 완료를 의미하지 않는다.
