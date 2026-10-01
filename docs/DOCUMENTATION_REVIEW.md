# 문서 정합성 점검과 작업 인수인계

## 최신 선택·탐색 반영: 2026-10-01

[선택·탐색](SELECTION_NAVIGATION.md)의 검색·필터·선택 범위·좌표/카메라·겹침 메뉴와 기록 보존을 계획/요구사항/대조표/UX/아키텍처에 반영했다. 전체 테스트 871개 통과/37개 skip, analyze 무이슈. 기존 format 차이와 SDK 기준 차이는 계약의 검증 절에 기록했다. 사용자 설정 섹션 수정·조사는 별도 변경으로 보존한다.

## 기본 도구 반영: 2026-10-01

[기본 편집 도구](BASIC_EDITING_TOOLS.md)의 안개·객체 상태/관계·시작 위치·고도·
문서 내 clipboard·미니맵을 계획/대조표/UX/포맷에 반영했다. DD2 활성값 정정으로
현재 helper는 0.10.1이다. 아래 평지 채우기 구현 당시의 버전/검증은 이력으로 보존한다.

이번 작업 트리의 전체 Flutter 테스트 863개 통과/37개 선택 skip, 실제 MPQ/CASC 순차
스모크 17개와 native CTest 6개 통과, analyze 무이슈 및 Windows debug 빌드·시작 통과.
변경 Dart 38개 포맷 통과. 전체 format은 기존 무관한 테스트 3개 때문에 미통과다.
SDK 3.47.5/3.13.4와 기준 차이, VM 재시도, CASC 동시 열기 제한 및 미실행 인수는
[기본 도구 검증](BASIC_EDITING_TOOLS.md#검증)에 기록했다.


평지 형태 연결표·로컬 변환 카탈로그·맵 전체 채우기 UI와 snapshot v2/helper 0.10.0을
문서에 반영했다. 기존 “실제 카탈로그/UI 없음”은 아래 2026-09-30 당시 기록이다.
최신 지원 범위와 검증은 [평지 채우기](ISOMETRIC_TERRAIN.md#로컬-평지-채우기-2026-10-01)를 따른다.

## 과거 점검: 2026-09-30

구현 기준은 `cbd7225`이며 이번 변경은 문서만 수정한다. [남은 작업 요약](REMAINING_WORK.md)에
미완료 체크박스를 분야별로 묶고 코드 구현·게임 검증·배포 인수를 구분했다.
현재 재개 지점은 ISOM 형태 연결표 생성과 변환 카탈로그 조립이다.

- New Map/raw resize와 지형 검사·비적층 변환 코어·로컬 CV5 스냅샷·Dart 수신 기반을
  README, AI 가이드, 기본 기능 대조표와 개발 계획에 반영했다.
- `IsomTerrainCatalogGateway`의 제품 구현과 UI 조립이 아직 없음을 소스 참조로 확인했다.
  실제 자료 읽기와 실제 지형 변환은 서로 다른 검증이다.
- 최신 지형 문서에 남은 “Dart adapter 없음”을 당시 이력으로 명시했다.
- 기존 배치/객체 성능 검증·사용자 확인, 일부 EUD 게임 관찰, 동봉 라이선스 고지는
  보존했다. 최종 게임/배포 인수 대기를 전체 미구현과 혼동하지 않도록 정리했다.
- 사용자 미커밋 설정 섹션 코드·조사와 문서 수정은 이번 커밋에 포함하지 않는다.
  작업 트리에서만 보이는 설정 구현을 원격 완료 기능으로 승격하지 않는다.
- 아래 2026-09-29 결과와 날짜별 검증 수치는 과거 기록이다. 최신 기능 검증은
  [지형 계약](ISOMETRIC_TERRAIN.md)의 후속 기록을 따른다.

이번 점검 결과: 작업 트리 Markdown 82개·내부 링크 423개 검사와 `git diff --check` 통과.
현재 작업 트리에서 전체 Flutter 테스트 823개 통과/34개 선택 skip, 정적 분석 무이슈.
사용자 미커밋 변경이 포함된 작업 트리 결과이며 원격 CI 결과로 간주하지 않는다. 전체 format은 기존 infrastructure 테스트 3개
(local_map_save_file_gateway, process_eud_compiler_gateway, process_map_archive_gateway)의
차이로 미통과이며 비쓰기 검사만 했다. SDK는 Flutter 3.47.5/Dart 3.13.4로 기준과 다르다.
문서만 변경하므로 native 빌드·실제 CASC/MPQ·게임 실행은 재실행하지 않는다.

## 과거 점검: 2026-09-29

2026-09-29. README, AI 공통 가이드, 개발 계획, 기능별 계약과 조사/검증 문서의
상태·교차참조를 점검했다. 코드 기준은 `bad4bab`과 현재 작업 트리다.
이번 결과는 **문서 정리**이며 새 맵 통합 기능 완료나 릴리스 인증이 아니다.

## 수정한 불일치

| 영역 | 수정 내용 | 기준 문서 |
| --- | --- | --- |
| 진입 문서 | M6.2/M6.3 초기 상태를 가리키던 README·AI 가이드를 현행 상태로 갱신 | [계획](DEVELOPMENT_PLAN.md) |
| 기본 기능 | 설정·트리거·브리핑·리소스·공통 Undo/Redo를 미구현으로 표시하던 대조표 수정 | [대조표](BASIC_EDITOR_COVERAGE.md) |
| 설정 사용법 | Map Settings의 7개 탭을 주 진입점으로 안내, 기본 이름과 DAT 기본 수치 구분 | [설정 UI](MAP_SETTINGS_UI.md) |
| 배치 구조 | Unit/Sprite factory·Doodad 복합 명령의 미구현 설명 수정, 데이터 helper 0.8.0 반영 | [아키텍처](ARCHITECTURE.md) |
| EUD 공급 | 실제 동봉·생성 빌드 구현과 깨끗한 Windows 인수 대기를 분리 | [동봉](EUD_BUNDLED_TOOL.md), [확장 계획](EUD_TOOLCHAIN_LANGUAGE_PLAN.md) |
| EUD 생성 | 비실행 JSON만 있던 최초 이력과 현행 생성 Python·manifest·테스트 빌드 구분 | [미리보기](EUD_GENERATION_PREVIEW.md) |
| EUD 필드 | 61개 후보 편집·API 컴파일 완료와 공유 영향/게임 검증 미완료로 체크박스 분리 | [후보 필드](EUD_EXPANDED_FIELDS.md) |
| EUD 규칙 | 규칙 없음 v1 / 기본 규칙 v2 / 확장 규칙 v3의 저장 규칙 통일 | [실행 규칙](EUD_EXECUTION_RULES.md) |
| 게임 확인 | 실드·공격 간격 일부 사용자 확인을 유지하고 전체 사거리·피해·멀티 확인으로 확대하지 않음 | [관찰 기록](EUD_GENERATED_BUILD_VALIDATION.md) |
| 문서 접근 | 누락된 기능 문서와 ADR-0012를 인덱스에 연결 | [인덱스](README.md), [ADR 목록](decisions/README.md) |
| 품질/복구 | 실제 Windows CI와 목표 게이트 구분, 포맷 명령 통일, 자동 저장은 M8 미구현으로 명시 | [품질](TESTING_AND_QUALITY.md), [안전](DATA_SAFETY.md) |

2026-09-29 후속 개발: 아래 문서 점검 당시 미커밋이던 New Map UI·신규 MPQ
저장/재열기를 연결했다. 사용자 설정 변경 후 최종 helper의 CTest 5개와 실제 MPQ
통합 테스트 5개를 통과했다. 현행 재개 지점은 [개발 계획](DEVELOPMENT_PLAN.md),
새 검증 결과는 [새 맵 정책](NEW_MAP.md)을 따른다. 아래 목록은 문서 점검 당시 이력이다.

## 문서 점검 당시의 개발 재개 지점

**M6.4 New Map → 메모리 문서 → 새 MPQ Save As → 재열기**를 이어서 작업한다.

- 완료 커밋: `bad4bab` — 생성 정책, `NewMapFactory`, CHK 왕복·경계 테스트.
- 미커밋 작업: 원본 경로/fingerprint가 없는 세션, `createNew`, 새 문서 Save As
  분기, MPQ helper `createScenario`와 0.5.0 프로토콜 변경, 관련 nullable 처리.
- 남은 연결: New Map 대화상자·명령, 실제 로컬 카탈로그의 검증된 초기 타일 선택,
  기존 미저장 문서 교체 확인과 오래된 선택 거부.
- 남은 검증: 새 MPQ 생성·재열기, 취소/실패·기존 출력 보호·리소스 저장 테스트,
  native 빌드/CTest, Windows 실행, 별도 게임/외부 에디터 인수.

문서 요청에 따라 현재 코드 변경을 보존하고 문서 커밋과 분리한다. helper 0.5.0
코드가 있다는 이유로 이전에 빌드한 0.4.0 실행 파일과 호환된다고 가정하지 않는다.
다음 작업 시 변경된 Dart adapter와 native helper를 함께 빌드·검증해야 한다.
세부 계약은 [새 맵 정책](NEW_MAP.md)을 따른다.

그다음 코드 후보는 맵 크기 변경, 등각 지형·경사로, 초기 안개, 객체 상태/관계,
선택 영역 clipboard·미니맵이다. 게임/외부 에디터 검증 대기 항목은 별도로 남는다.
Python entry·Lua, 자동 저장·크래시 복구·배포 인수도 완료 처리하지 않는다.

## 점검 범위와 보존한 기록

- 저장소 Markdown 78개(생성 build 디렉터리 제외)의 내부 파일·제목 링크를 검사했다.
  주요 계약·현황 문서와 인덱스 33개를 갱신/추가했다.
- 기존 설정·리소스·브리핑의 상세 바이트 계약, 성능 측정, 실제 설치 스모크는
  구현과 모순되는 현행 안내만 수정하고 날짜별 원래 측정 결과는 보존한다.
- `docs/research/`의 고정 소스 조사, euddraft manifest/audit JSON과 해시,
  성능 JSON, 라이선스 원문, 자체 제작 fixture의 출처는 새 검증 없이 바꾸지 않는다.
- ADR의 결정은 유지한다. ADR-0008에는 factory/복합 배치의 후속 구현 상태만
  덧붙였으며 당시 pending 상태를 현재 미구현으로 오해하지 않도록 했다.
- 기존 사용자 수정과 미추적 설정 조사/테스트는 그대로 남기고 이 문서 커밋에
  섞지 않는다. 작업 트리에만 있는 자료를 원격에서 반드시 읽을 수 있다고 가정하지 않는다.

## 이번 실행 결과

| 검증 | 결과와 범위 |
| --- | --- |
| Markdown 내부 파일·제목 링크 | 작업 트리 383개 내부 링크 통과 |
| 요구사항 ID | FR/NFR 선언 중복 검사 통과 |
| `git diff --check` | 문서 변경 통과 |
| `flutter analyze` | 현재 작업 트리에서 무이슈 |
| `flutter test` | 현재 작업 트리에서 774개 통과, 선택 환경 27개 skip |
| `dart format --output=none --set-exit-if-changed lib test tool` | 미통과: 기존 infrastructure 테스트 4개와 미완료 새 맵 변경 8개, 총 12개 차이; 비쓰기 검사 |
| Windows build/CTest·신규 MPQ·게임/멀티플레이 | 이번 문서 작업에서는 미실행; 위 새 맵 통합 및 인수 게이트로 남김 |

검증 환경은 Flutter **3.47.2 / Dart 3.13.2**다. 저장소/CI 기준
**3.44.8 / 3.12** 재검증이나 원격 CI 통과를 주장하지 않는다. 테스트 결과는
미커밋 코드가 포함된 작업 트리의 기존 회귀이며 신규 MPQ 통합 테스트를 대체하지 않는다.

기존 포맷 차이: `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`,
`process_starcraft_data_asset_inspector_test.dart`(모두 `test/infrastructure/`).
새 맵 변경의 포맷은 기능 개발 재개 시 정리한다.
