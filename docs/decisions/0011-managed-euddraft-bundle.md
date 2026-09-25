# ADR-0011: updater 대체 소스를 포함한 관리형 euddraft

- Status: Accepted
- Date: 2026-09-25

## Context

공식 0.10.2.5는 종료 후 자동 업데이트할 수 있고 영구 비활성화 계약이 없다.
checkpoint는 Shift·시간 경과로 우회돼 버전 고정에 쓸 수 없다.

## Decision

공식 ZIP 공개 해시를 검증하고 frozen library의 updater만 읽을 수 있는 소스로
교체한다. DLL 패치나 임의 bytecode 수정 대신 `issueAutoUpdate` 계약을 유지하면서
안내 출력 외 부작용을 없앤 별도 `editor.1` 구성이다. 다른 파일과 library 항목은
원본 바이트를 보존하고 원본/변경/보완 고지를 동봉한다.

최종 파일 목록을 앱에 컴파일하고 준비·실행 전·승격 전에 검사한다. CMake는 빌드 시
패키지를 준비·검사하여 버전별 경로에 동봉한다. 실행 중 다운로드하지 않는다.
외부 선택은 유지하며 외부 설치 파일을 수정하지 않는다.

## Consequences

공식 원본 패키지로 표시하지 않는다. 버전 변경은 새 목록·검토·실제 빌드 검증을 요구한다.
사용자 플러그인을 sandbox한 것은 아니다. 구현과 배포 인수를 구분하여 깨끗한 Windows,
읽기 전용 ACL, 차단망 검증을 남긴다.

## Validation

[동봉 기록](../EUD_BUNDLED_TOOL.md)에 재현·변조·실제 빌드·취소·시간 제한·설치 불변성과
미검증 경계를 기록한다.
