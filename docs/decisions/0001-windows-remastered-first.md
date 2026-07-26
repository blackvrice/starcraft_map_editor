# ADR-0001: Windows와 StarCraft: Remastered 우선

- Status: Accepted
- Date: 2026-07-26

## Context

Flutter 템플릿은 여러 플랫폼을 포함하지만 StarCraft: Remastered, euddraft, 기존 맵 도구와 사용자 환경은 Windows 중심이다. 모든 플랫폼을 동시에 지원하면 파일 대화상자, 네이티브 MPQ 처리, 프로세스 실행과 배포 검증 범위가 크게 늘어난다.

## Decision

첫 제품 프로필은 Windows 10/11 x64와 StarCraft: Remastered UMS 맵으로 제한한다.

- UI와 Dart 도메인은 향후 이식 가능하게 유지한다.
- 네이티브 아카이브 브리지와 게임 실행은 Windows 구현부터 만든다.
- StarCraft 1.16.1 EUD 호환은 별도 프로필이 정의될 때까지 지원하지 않는다.
- 모바일과 웹은 정식 빌드 대상으로 취급하지 않는다.

## Alternatives

### 모든 Flutter 플랫폼 동시 지원

사용자 범위는 넓지만 네이티브 도구와 실제 게임 검증을 제공하기 어렵다.

### Windows 1.16.1과 Remastered 동시 지원

EUD 컴파일러/오프셋 프로필과 회귀 테스트가 늘어나 초기 수직 기능이 늦어진다.

## Consequences

- Windows 전용 기능을 조기에 실제 환경에서 검증할 수 있다.
- UI와 도메인에 불필요한 플랫폼 분기를 만들지 않는다.
- 다른 OS 사용자는 초기 릴리스를 사용할 수 없다.
- 향후 플랫폼 확장은 Archive/Compiler/GameLauncher 포트의 새 구현으로 진행한다.

## Validation

- Windows CI와 실제 Windows 패키지 빌드
- euddraft 실제 빌드
- StarCraft: Remastered 맵 실행 스모크 테스트
