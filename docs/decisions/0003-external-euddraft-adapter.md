# ADR-0003: euddraft 외부 프로세스 어댑터

- Status: Accepted
- Date: 2026-07-26

## Context

euddraft/eudplib는 Python 기반 도구와 네이티브 구성요소를 포함하며 자체 릴리스 주기를 가진다. 이를 Flutter 프로세스에 직접 임베드하면 런타임 충돌, 패키징, 업그레이드, 오류 격리가 어려워진다. 반대로 컴파일러를 새로 구현하는 것은 범위와 호환성 위험이 매우 크다.

## Decision

초기 EUD 빌드는 euddraft를 별도 프로세스로 실행하는 `EudCompilerGateway`로 구현한다.

- UI와 Application은 구체 명령행 형식을 모른다.
- 프로세스는 사용자 Build 동작에서만 시작한다.
- executable과 arguments를 분리해 실행한다.
- stdout, stderr, 종료 코드, 도구 버전을 기록한다.
- 빌드는 임시 출력에서 수행하고 검증 후 최종 경로로 승격한다.
- 가짜 gateway로 대부분의 자동화 테스트를 실행한다.

## Alternatives

### Python/eudplib 임베드

세밀한 API 접근이 가능하지만 Flutter/Windows 패키징과 프로세스 안정성이 복잡해진다.

### eudplib 기능 재구현

완전한 통제가 가능하지만 EUD 호환성과 유지보수 비용이 제품 범위를 초과한다.

### euddraft를 사용자가 별도로 직접 실행

앱 구현은 단순하지만 통합 진단과 안전한 출력 흐름이라는 제품 가치가 사라진다.

## Consequences

- euddraft 크래시를 앱 프로세스와 격리할 수 있다.
- 버전별 명령행/로그 차이를 어댑터가 처리해야 한다.
- 첫 사용 전 도구 설치 또는 번들 정책이 필요하다.
- Python 플러그인이 임의 코드를 실행할 수 있다는 경고와 신뢰 모델이 필요하다.

## Validation

- 가짜 프로세스 성공/실패/취소/timeout 테스트
- 공백과 한글 경로 테스트
- 실제 지원 euddraft 버전 스모크 테스트
- 원본 맵 해시 불변과 출력 맵 재열기 검증

## Implementation baseline

2026-07-26의 `ProcessEudCompilerGateway` 기준선은 다음과 같다.

- 공식 euddraft의 한 설정 파일 CLI에 맞춰 절대 `.eds` 경로 하나만 전달한다.
- 설정 부모를 작업 디렉터리로 지정하고 셸 없이 실행하며 stdin은 즉시 닫는다.
- UTF-8 stdout/stderr를 동시에 줄 이벤트로 전달하고 스트림별 기본 1 MiB
  상한을 넘으면 초과분을 버리면서 끝까지 소비한 뒤 실패한다.
- 부모 환경은 Windows 실행 allowlist만 상속하고 명시적 override를 추가한다.
- timeout, build ID 취소와 구독 취소는 소유 토큰이 일치하는 프로세스만
  종료한다.
- 종료 코드 0은 프로세스 단계 성공일 뿐이다. `SafeEudBuildPipeline`이
  앱 소유 작업 공간의 출력 MPQ/CHK를 검증하고 기준 맵·진입 소스·기존 출력
  fingerprint를 재확인한 뒤 최종 경로로 승격한다.
- `LocalEudBuildFileGateway`는 공식 `[main] input/output`과 절대 epScript
  플러그인 섹션을 가진 일회성 UTF-8 `.eds`를 최종 출력의 형제 작업 공간에
  만든다. 기존 출력 교체는 명시적 계획에서만 허용하고 백업·자동 복원한다.
