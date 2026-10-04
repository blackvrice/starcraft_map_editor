# 기존 에디터 비교와 개발 범위 점검

조사일: 2026-10-04. 자체 코드 기준: `559ffd0`와 조사 시점 작업 트리.
사용자의 미커밋 설정 섹션 조사와 테스트는 그대로 보존했다. 이번 작업은
요구사항·설계·계획 정리이며 아래 부족 기능을 구현한 작업이 아니다.

## 1. 실행 계획과 판정 방법

1. 문서 인덱스, 기본 기능 대조표, 개발 계획과 안전 정책을 읽는다.
2. ScmDraft 공식 설명·옵션·변경 기록과 Chkdraft/EUD Editor 3 고정 소스를 조사한다.
3. 자체 application/domain/presentation 경로와 기존 실행 기록을 대조한다.
4. 차이를 요구사항 ID, 설계, 단계와 테스트 시나리오로 연결한다.
5. 문서 링크와 필수 품질 게이트를 확인하고 관련 변경만 커밋한다.

판정은 **구현 / 자동 테스트 / 실제 도구 / 게임 관찰 / 배포 인수**로 분리한다.
타사 프로그램을 설치·조작한 비교 테스트는 이번에 하지 않았다. 공식 설명과
공개 소스의 기능 존재를 비교한 것이며 타사 안정성·성능 우열은 판정하지 않는다.
오래된 문서의 `Planned!`, 알파 기록과 현재 배포판을 혼동하지 않는다.
검색 결과에 나타난 커뮤니티 의견은 기능 판정 근거로 사용하지 않았다.

## 2. 비교 자료와 적용 범위

| 자료 | 확인한 비교 기준 | 한계 |
| --- | --- | --- |
| [S1 ScmDraft 공식 소개](https://www.stormcoast-fortress.net/cntt/software/scmdraft/) | 다중 맵/뷰, 맵 간 객체·지형 복사, 사용자 브러시 | 역사적 소개이며 최신 전체 지원표가 아님 |
| [S2 공식 옵션](https://stormcoast-fortress.net/cntt/software/scmdraft/Options/) | 격자 크기, 건물 타일/유닛 격자 스냅, 배치 옵션 | 옵션마다 구현/계획 구분 필요 |
| [S3 공식 변경 기록](https://www.stormcoast-fortress.net/downloads/scmdraft2ZIP/changelist/) | unit sprite 팔레트, 지형 대칭, 경로 영역 표시, OGG | 변경 기록의 기능 존재 근거, 게임 동작 보증 아님 |
| [S4 공식 갤러리](https://stormcoast-fortress.net/cntt/software/scmdraft/gallery/) | 배치 가능 영역, 게임 데이터 사운드, 여러 맵 보기 | 시각적 흐름 참고, 정량 성능 비교 아님 |
| [S5 공식 기능 비교표](https://www.stormcoast-fortress.net/cntt/software/scmdraft/featuretable/) | 이미지 출력·편집 도구와 StarEdit/SCXE 기본 범위 | 오래된 비교표. 최신 경쟁 제품 전체 목록으로 사용하지 않음 |
| [C1 Chkdraft text_trig.cpp](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/dialog_windows/text_trig/text_trig.cpp) | 일반 트리거 텍스트 생성과 컴파일 | 고정 revision의 소스 존재/호출 확인 |
| [C2 Chkdraft color_properties.cpp](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/dialog_windows/map_settings/color_properties.cpp) | CRGB RGB 색상 선택 | 같은 고정 revision, 실제 게임 인수는 별도 |
| [E1 EUD Editor 3 배포 목록](https://github.com/Buizz/EUD-Editor-3/releases) | 비교 대상으로 0.19.6.0 선택 | 범용 맵 에디터와 역할이 다른 EUD 중심 도구 |
| [E2 ButtonData](https://github.com/Buizz/EUD-Editor-3/blob/be43bbd4c17a6aa15d2b89f83ce285188d79d099/EUD%20Editor%203/UserContorl/DataEditor/ButtonData.xaml) | 버튼 데이터 목록·명령 UI | 소스 확인만으로 SC:R 지원을 인정하지 않음 |
| [E3 RequireData](https://github.com/Buizz/EUD-Editor-3/blob/be43bbd4c17a6aa15d2b89f83ce285188d79d099/EUD%20Editor%203/UserContorl/DataEditor/RequirePage/RequireData.xaml) | 요구 조건 편집 UI | 우리 제품의 런타임 지원 결정과 별도로 평가 |

Chkdraft revision은 `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`, EUD Editor 3
태그 0.19.6.0의 revision은 `be43bbd4c17a6aa15d2b89f83ce285188d79d099`다.
일부 GitHub/raw 페이지의 웹 도구 읽기가 실패하여 공식 GitHub tree API와
raw 소스를 읽기 전용 HTTP로 보완했다. 외부 코드를 복사하거나 실행하지 않았다.

## 3. 이미 있는 기능을 다시 개발하지 않는다

- 안전한 Open/Save As, 새 맵·ISOM 무작위 초기 지형, raw 단일 타일 편집이 있다.
- 지형 경계·높이·경사로 브러시와 ISOM/두다드 resize가 있다.
- 유닛/무기 그래픽 격자, 탱크·골리앗 본체/터렛 합성, 객체·로케이션 편집이 있다.
- 유닛·생산 허용·업그레이드·테크·플레이어·세력 설정, 일반 트리거와 브리핑이 있다.
- 문자열/PCM WAV, 공통 Undo/Redo, 자동 저장·복구, 한영 번역이 있다.
- epScript 색상/정적 완성, 관리형 EUD 도구와 선언적 설정/규칙 빌드가 있다.

이 구현 목록은 전체 게임·외부 에디터 왕복·릴리스 인수 완료를 의미하지 않는다.
2026-10-04 유닛 #0/pure sprite #0/두다드 #0의 실제 클릭과 Undo, 두다드 지형
불일치 안내를 확인한 범위는 [기존 실행 기록](EDITOR_WORKFLOW_REPAIR.md)을 따른다.
사용자가 보고한 모든 배치 오류가 재현·해결됐다고 확대하지 않는다.

## 4. 차이와 우선순위

P0: 기본 작업 실패/데이터 안전/출시 게이트. P1: 반복 제작에서 우선 보완.
P2: 기반 구축 후 작업 효율 확대. P3: 선택 기능/조사. 우선순위는 추천이며
이번 문서 작성만으로 기존 첫 미완료 작업의 실행 순서를 바꾸지 않는다.

| 차이 | 자체 현재 상태와 근거 | 비교 기준 | 요구사항 / 단계 |
| --- | --- | --- | --- |
| 배치 유형·그래픽·거절 이유 | `PlacementCatalogController.placeAt`은 unit/pureSprite/doodad만 처리하고 spriteUnit을 거절. 두다드 합성 썸네일/footprint 및 모든 거절 이유의 시각 안내 확대 필요 | S3/S4 | P0 FR-217, EP1 |
| 스냅·배치 정책 | 위 컨트롤러는 pixel 좌표를 직접 전달. 사용자 격자/건물 스냅·정상/자유 배치 정책을 선택하는 경로 없음 | S2 | P1 FR-218, EP1 |
| 지형/배치 보조 표시 | 미니맵·안개·선택은 구현. 높이/건설 가능/경로 영역·전력/범위 오버레이는 별도 미구현 | S3/S4 | P2 FR-219, EP4 |
| 사용자 브러시·대칭 | ISOM 경계 브러시와 선택 영역은 구현. 저장형 사용자 브러시와 지형 대칭 없음 | S1/S3 | P2 FR-220, EP4 |
| 혼합 영역 복사 | `BASIC_EDITING_TOOLS.md`: raw MTXM, 객체, 검증된 단일 두다드만. 다수 두다드 혼합·ISOM 경계 복사 미지원 | S1 | P1 FR-221, EP3a |
| 여러 맵 작업 | `OpenMapController`는 현재 세션 하나. 탭별 문서/초안/Undo 분리와 맵 간 복사 없음 | S1 | P2 FR-005/222, EP3b |
| 기본 수치 확인 | 설정의 기본값 사용은 구현. 일반 설정 전체의 실제 로컬 DAT 기본 수치 조회는 없음. EUD 58필드 조회와 다름 | 자체 FR-207~210의 작성 효율 분석. 타사 전체 기본 수치와의 수치 대조는 미실시 | P1 FR-223, EP2 |
| 확장 플레이어 색상 | `ChkPlayerSettingsEditor`는 CRGB 존재 시 COLR 편집 차단. RGB/모드 편집과 실제 맵 색상 미리보기 미지원 | C2 | P1 FR-224, EP2 |
| 문자열 색상 작성 | UTF-8/원시 보존·참조 관리는 구현. 게임 제어 바이트 색상 선택/안전한 미리보기 없음 | 기존 FR-216의 작성 효율 확대 | P1 FR-225, EP2 |
| 사운드 범위 | PCM WAV 가져오기/재생은 구현. OGG 등 추가 압축 형식과 로컬 게임 사운드 선택기는 별도 범위 | S3/S4 | P2 FR-226, EP6 |
| 트리거 탐색 | `TriggerPane`에 소유자/활성 일괄 변경과 순서 편집은 있음. 텍스트·조건/액션·참조 검색과 검색 결과 기반 조건/액션·참조 일괄 수정은 미지원 | C1 기반 텍스트 작업과 자체 사용성 분석 | P1 FR-405, EP2 |
| 일반 트리거 스크립트 | 일반 TRIG UI와 EUD epScript가 분리. EUD 빌드 없는 일반 스크립트 편집/왕복 없음 | C1 | P1 FR-406, EP5 L0~L2 |
| 언어·소스 작업 공간 | 앱 entry는 .eps, 정적 완성만. 정식 Python/Lua entry와 여러 소스 파일 탐색/위치 진단 미지원 | EUD 도구 역할 비교 및 사용자 요청 | P2 FR-319/320, EP5 |
| 게임 확인 흐름 | 게임 관찰 기록 일부 존재. 저장/빌드 결과별 테스트 안내·실행 포트·결과 묶음 없음 | 자체 FR/M8 인수 미충족 | P0 수동 인수, P1 FR-107, EP0/6 |
| 이미지 출력 | 맵 전체/영역 이미지 출력 UI/포트 없음 | S5 | P3 FR-227, EP6 |
| 접근성·배포 | 한글 렌더/성능 스모크는 있음. 신규 제작자 반복 시나리오, 키보드/고대비, profile·깨끗한 PC 전체 게이트 미완료 | 자체 NFR/M8 | P0 NFR-001/005/008/009, EP0/6 |

부족의 성격은 서로 다르다. spriteUnit은 **확인된 미지원 분기**, DAT/CRGB는
**문서와 코드의 명시적 제한**, 나머지 생산성 항목은 조사한 현재 경로·계약에
**사용자 기능이 없는 상태**다. 일반 트리거 검색 같은 항목은 모든 경쟁 제품이
제공한다고 단정한 것이 아니라 비교와 사용자 작업에서 도출한 제품 요구다.

## 5. 도입하지 않거나 보류할 기능

- 손상/보호 ISOM 추측 복구, 로드 중 불법 객체 자동 삭제는 따라 하지 않는다.
- 기존 맵 타일셋 변환은 대응표·경계/두다드 보존 실험 전까지 P3 조사다.
- 버튼셋/Requirement/Order/IScript는 E2/E3에 UI가 있어도 즉시 지원하지 않는다.
  [런타임 결정](research/EUD_RUNTIME_SUPPORT.md)을 유지하고 별도 ABI/게임/멀티
  검증과 ADR 이후 지원표를 확장한다. 단순 필드 쓰기로 동등 구현을 주장하지 않는다.
- 완전한 IScript 애니메이션, 범용 모드/플러그인, 1.16.1 호환, 보호 해제,
  프로세스 주입은 이번 필수 개발 범위가 아니다.

## 6. 설계·문서 정리 결과

[제품 요구사항](PRODUCT_REQUIREMENTS.md)에 고유 FR/NFR를 추가하고
[보완 설계](EDITOR_PARITY_DESIGN.md)에 UI·계층·무손실 계약과 미결정을 정리한다.
[개발 계획](DEVELOPMENT_PLAN.md)의 EP0~EP6는 기존 M/X/L 작업의 연결이며
언어 개발 34~61일 추정을 중복 작업량으로 합산하지 않는다.
[테스트와 품질](TESTING_AND_QUALITY.md)의 PAR-01~15가 각 요구사항의 인수 증거다.
아키텍처/UX/포맷/안전/기본 대조표/남은 작업/인덱스의 현재 설명도 함께 갱신한다.
과거 실행 결과와 사용자 조사 문서, 라이선스 원문은 새 결과로 덮어쓰지 않는다.

## 7. 소스 이해도와 최적화 검토

현재 배치 분기는 설명 주석과 타입으로 읽을 수 있으므로 계획 작업을 위해
코드 주석을 억지로 추가하지 않는다. 후속 구현에서는 두다드 footprint 기준점,
ISOM 전파, 문서 간 참조 재매핑에만 짧은 계약 주석을 붙인다.

기존 썸네일 LRU·가시 영역 렌더링은 재사용한다. 보조 표시를 매 paint에 재계산하거나
다중 문서마다 모든 자산을 중복 적재하지 않는다. revision별 파생 자료 캐시,
가상화 팔레트/트리거 목록, 취소 가능한 비동기 계산과 공유 자산 예산을 검토한다.
실제 profile 측정 전에는 이 제안을 성능 개선 완료로 표시하지 않는다.

## 8. 이번 작업 검증

실행: 공식 문서/고정 소스 읽기 -> 현재 코드/기능 계약 대조 -> 신규 비교/설계와
관련 17문서 갱신 -> 필수 명령 -> 링크/요구사항 정합성 -> 관련 변경 분리 커밋.

| 검사 | 2026-10-04 실제 결과 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | exit 1. 429파일 중 기존 미변경 테스트 3파일의 포맷 차이. 비쓰기 검사라 파일은 변경하지 않음. `.dart_tool/editor_parity_format.log` |
| `flutter analyze` | exit 0, No issues found. `.dart_tool/editor_parity_analyze.log` |
| `flutter test` | exit 0, 978 통과/환경 조건부 48 skip. `.dart_tool/editor_parity_tests.log` |
| 변경 문서 로컬 링크 경로 검사 | 17문서/364경로 존재, 누락 0. 외부 URL/앵커 성공 검사와는 구분 |
| 요구사항 정합성 | FR/NFR 74개 고유 ID, 중복 0, 비교표의 미정의 요구사항 0 |
| `git diff --check -- docs` | 통과 |

SDK는 Flutter 3.47.5 / Dart 3.13.4로 저장소 기준 3.44.8 / 3.12와 다르다.
포맷 차이 파일은 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
기준 SDK 재검증 없이 전체 품질 게이트 통과라고 표시하지 않는다.
사용자 staged `local.properties`, 설정 섹션 조사/코드/테스트, 플랫폼/의존성 변경은
이번 문서 커밋에 넣지 않는다. README/개발 계획은 이번 추가 부분만 분리한다.

코드 기능·타사 UI·실제 게임·새 Windows 설치 테스트는 이번 계획 작업의 실행
범위 밖이며 EP0/EP6의 미완료 인수로 유지한다.

## 9. 결과 분석과 다음 결정

기본 편집 코어의 재개발보다 **배치/실패 복구 완성도 -> 설정·트리거 작성 효율 ->
복사·여러 맵 -> 브러시/보조 표시 -> 언어·출시**가 효과적인 순서다. 일반 스크립트는
L0~L2를 먼저 제공할 수 있으며 전체 세 언어와 고급 EUD를 기다릴 필요는 없다.
추천 첫 개발 단위는 EP0의 회귀 기준선과 EP1의 배치 지원표/공통 preview 계약이다.
기존 대기 게임/외부 인수를 지우거나 이번 계획 요청을 구현 승인으로 해석하지 않는다.
