# 문서 정합성 점검과 작업 인수인계

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

## 다음 개발 재개 지점

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
