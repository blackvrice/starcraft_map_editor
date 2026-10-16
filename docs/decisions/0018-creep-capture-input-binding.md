# ADR-0018: 크립 수집 입력 지문과 명시적 수집 포트

- Status: Accepted
- Date: 2026-10-16

## Context

[관찰 증거](0017-creep-observation-evidence.md)는 관찰 phase/권한을 표현하지만 실제
수집 결과가 어떤 CHK·리소스 변경·setup에 대응하는지 결합하지 않았다.
현재 검증된 SC:R collector/IPC 구현은 없으며 게임 자동 실행·주입은 허용하지 않는다.

## Decision

- `UnitCreepCaptureGateway`를 명시적 capture/cancel 포트로 둔다. 실제 구현은 동봉하지 않는다.
- `ValidatedUnitCreepStateGateway`는 선택적으로 주입한 포트와 명시적 provider/collector
  version·gameSessionId·정확한 game version 허용 목록·setup schema/bytes만 사용한다.
  실제 지원 build 목록이나 기본 collector를 bootstrap에 등록하지 않는다.
- 입력은 현재 raw CHK byte hash·source archive SHA/size·scenario locale·pending resource
  이름/삭제/길이/hash·setup schema/bytes hash·numeric DAT source tuple을 canonical JSON으로 결합한다.
- 기존 `.wav` pending resource path 규칙을 재사용한다. 원시 이름을 바꾸지 않고 중복 case
  alias는 거절한다. 삭제/null·빈 bytes·항목 없음은 다른 입력이다.
- 입력 지문은 **원본+편집 overlay의 의도**이지 새 MPQ의 hash가 아니다. path/mtime/요청 ID/
  문서 revision은 content hash에서 제외하며 request 객체와 기존 controller 수명 검사를 별도로 유지한다.
- 결과는 exact capture request·capturedInputRevision·선택 provider/버전/게임 세션·setup을
  만족해야 한다. 기존 관찰 phase/권한/unknown 및 current request/DIM 검증도 유지한다.
- timeout/cancel은 request 객체별로 소유한다. 같은 ID 재시도에서 오래된 cancel/reply가 새
  요청에 영향을 주지 않도록 adapter token과 포트 cancel의 객체 identity를 사용한다.
- 원본 파일·맵·setup을 자동으로 실행/저장하지 않는다. 실제 collector가 현재 base archive를
  재검증하고 정확한 prepared input·setup으로 실행했음을 확인해야 한다. echo/hash는 악의적
  collector의 정확성이나 게임 호환성을 증명하지 않는다.

## Alternatives

- 원본 `.scx` 파일 hash만 사용: 미저장 CHK·리소스 편집을 누락하므로 거절.
- 전체 MPQ를 이 adapter에서 생성: 파일 I/O/저장 검증과 게임 실행 범위를 불필요하게 합치므로 보류.
- 설정을 임의 JSON schema로 추측: 실제 collector가 없으므로 versioned opaque bytes로만 결합.
- helper/CASC build를 게임 executable 버전으로 사용: 서로 다른 출처이므로 거절.

## Consequences

명시적 capture 포트가 없는 기본 앱은 계속 unavailable이다. 이번 결과는 typed in-process
수집 연결·검증 adapter이며 파일 import/JSON/외부 프로세스/실제 게임 collector가 아니다.
실제 게임 인수·지원 버전 검증·live freshness와 UI/배치 정책은 계속 미완료로 둔다.

## Validation

canonical 입력/수정/삭제/불변·예산/alias 거절, 자료/버전/setup 불일치, 부분 관찰,
취소/timeout/재시도/늦은 응답, controller의 CHK/Undo 보존을 합성 포트로 검사한다.
[실행 기록](../UNIT_CREEP_CAPTURE_INTAKE.md)에 자동 검증과 실제 미실행을 구분한다.
