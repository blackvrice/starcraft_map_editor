# ADR-0025: 실행 없는 다중 소스 작업 공간

- Status: Accepted
- Date: 2026-10-19

## Context

FR-320은 여러 소스와 완성/검색/진단을 요구한다. 기존 active source만 검사하는
복구·맵 닫기·빌드는 비활성 원문을 보호하지 못하며 interpreter 기반 완성은
프로젝트를 여는 것만으로 신뢰할 수 없는 코드를 실행할 수 있다.

## Decision

기존 EudSourceController/API를 확장하되 문서별 탭과 전체 dirty/경로 수명을
명시한다. 파일은 SourceWorkspaceGateway, 정적 분석은 순수 domain 색인과
isolate에 둔다. 탭별 원문을 자동 변환하거나 컴파일하지 않는다.
기존 안전 저장 포트의 예상 SHA/백업/임시 출력/승격을 재사용한다.
복구 schema v3는 모든 탭과 선택 상태를 기록하며 확인하지 않은 루트에 자동
접근하지 않는다. EUD 빌드 준비/완료 시 의존 목록과 원본 지문을 재검증한다.

## Alternatives

- 완전한 LSP/실행 기반 완성: 배포 크기·언어별 프로세스와 보안 경계가 크므로 후속.
- 단일 파일 편집기 교체만 구현: 비활성 탭의 복구/빌드 안전을 충족하지 못한다.
- 외부 변경 자동 reload/merge: 사용자 원문을 자동 변경하므로 선택하지 않는다.

## Consequences

현재 정적 지원은 advisory이며 동적 import/type 추론을 보장하지 않는다.
루트는 OS 샌드박스가 아니며 신뢰된 빌드의 임의 코드 실행 권한을 제한하지 않는다.
Lua native runtime은 추가하지 않는다. 현재 상한/지원 문법/미실행 인수는
[구현 문서](../SOURCE_WORKSPACE.md)에 명시한다. 새 패키지 의존성은 없다.

## Validation

domain/controller/filesystem/widget, 전체 Flutter 회귀, Windows/native 빌드,
공식 euddraft 다중 파일 MPQ와 강제 종료 복구로 검증한다. 결과와 실패 수정은
구현 문서에 기록하며 앱/게임/배포 인수와 구분한다.
