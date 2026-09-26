# ADR-0012: 선언적 EUD 설정의 명시적 테스트 빌드

- Status: Accepted
- Date: 2026-09-26

## Context

61개 후보 필드의 API 컴파일은 통과했지만 게임 검증을 위해서는 UI 프로젝트 값을
실제로 맵에 넣는 경로가 필요하다. 게임 미검증 상태와 실행 가능한 빌드를 구분한다.

## Decision

- 기본 저장과 빌드는 분리한다. Prepare EUD Build의 명시적 테스트 설정 선택으로만
  선언적 설정을 포함한다. 일반 지원 완료/게임 호환성 확인으로 표시하지 않는다.
- 검증된 registry의 멤버만 결정적으로 Python 시작 플러그인에 생성한다. 값은
  검증된 bool/int/enum 리터럴이며 임의 필드/코드는 허용하지 않는다.
- 임시 작업 폴더의 생성 플러그인을 사용자 epScript보다 먼저 등록한다.
  시작 시 한 번 타입 값을 쓰고 기존 CUnit의 실드를 채우거나 클램프하지 않는다.
  이는 관찰을 위한 명시적 첫 정책이며 기존 유닛 초기화를 보장하는 정책이 아니다.
- entry가 비어 있으면 설정 전용 빌드다. 사용자 파일을 생성·수정할 필요가 없다.
  entry가 있으면 기존 소스 검증·fingerprint 검사와 신뢰 확인을 유지한다.
- 프로젝트/맵 스냅샷의 변경은 시작 및 출력 승격 전 거부한다. 입력 맵의 해시가
  선언적 프로젝트의 맵 해시와 같아야 한다. 기존 임시 출력→MPQ/CHK 검증→승격을 재사용한다.
- 생성 manifest는 프로젝트/맵/소스 해시, 생성기 버전, 실행 순서, 실드 정책을 담고
  빌드 로그에 남긴다. 임시 생성 파일은 작업 종료 시 정리한다.

## Alternatives

사용자 entry에 코드를 직접 삽입하거나 Save As에서 암묵적으로 빌드하면 소스/입력
보존과 실행 경계가 흐려진다. 전체 트리거 편집기 완성까지 기다리면 초기 필드의
게임 관찰도 막히므로 별도 시작 플러그인을 선택했다.

## Validation

euddraft v0.10.2.5의 [pluginLoader.py](https://github.com/armoha/euddraft/blob/v0.10.2.5/pluginLoader.py)는
설정 순서로 onPluginStart를 수집하고 [applyeuddraft.py](https://github.com/armoha/euddraft/blob/v0.10.2.5/applyeuddraft.py)는
그 순서로 호출한 후 일반 트리거 루프를 실행한다. 실제 동봉 빌드의 생성기/사용자
초기화 컴파일 로그 순서를 검사했다. 이는 게임에서 관찰한 수치 결과와 구분한다.
반복 빌드·입력 보존·설정 전용·잘못된 맵 binding 거부·stale 프로젝트 거부를 테스트한다.
수동 관찰 범위는 [게임 검증](../EUD_GENERATED_BUILD_VALIDATION.md)에 기록한다.
