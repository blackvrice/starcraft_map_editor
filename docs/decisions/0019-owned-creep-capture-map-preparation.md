# ADR-0019: 소유 임시 맵 준비와 실제 수집 실행 분리

- Status: Accepted
- Date: 2026-10-16

## Context

[ADR-0018](0018-creep-capture-input-binding.md)의 지문은 base archive+현재 편집 overlay의
의도이지 실제 실행 MPQ hash가 아니다. 원본이 바뀌었거나 resource가 누락된 임시 맵으로
관찰하면 같은 지문을 echo해도 수집 결과를 신뢰할 수 없다. 실제 수집 경로/지원 build/
게임 실행 승인은 확정되지 않았다. 기존 resource reader는 WAV 경로만 지원한다.

## Decision

별도 `UnitCreepMapPreparationGateway` 뒤에서 원본 fingerprint·baseline 재열기,
전용 임시 MPQ 쓰기·CHK/WAV exact 재검증·출력 전후 fingerprint를 구현한다.
실제 collector/게임 실행·setup 적용·UI/기본 bootstrap 등록은 추가하지 않는다.
검증 가능한 locale0·완전 이름 목록·canonical WAV만 지원하며 signed/알 수 없는 자산을
추측으로 건너뛰지 않는다. helper의 listfile/attributes는 사용자 payload 보존과 구분한다.

receipt는 exact request와 실제 임시 출력 지문에 결합하고 사용 직전 재검증과 release를
명시한다. 취소는 advisory이며 in-flight I/O 완료 뒤 cleanup한다. 소유 token의 known file과
빈 directory만 비재귀 삭제하고 정리 실패는 소유권을 유지해 재시도한다.

## Alternatives

- 기존 Save As pipeline 사용: 사용자 경로 승격·session 변경이 불필요하므로 채택하지 않는다.
- collector에서 임의 export/정리: 재사용 가능한 검증 경계가 사라지므로 채택하지 않는다.
- WAV 외 모든 MPQ 자산을 불검증 복사: exact materialization을 증명하지 못하므로 거절한다.
- 실제 게임 관찰을 합성 결과로 대체: 입력 준비와 관찰 증거는 다르므로 금지한다.

## Consequences

일부 정상 맵도 추가 자산/locale/이름 모호성 때문에 이 preparation 경로를 쓸 수 없다.
일반 맵 열기/저장의 지원 범위를 줄이는 변경은 아니다. 포트는 독립이며 앱 동작은 그대로다.
receipt는 파일 잠금/OS sandbox가 아니고 전체 작업 deadline이나 강제 종료 orphan 청소도 없다.
실제 수집기 연동은 명시적 승인·지원 build·setup·관찰 phase/권한·게임 인수를 별도로 요구한다.

## Validation

[실행 계획·지원표·테스트·실패 수정·최종 결과](../UNIT_CREEP_MAP_PREPARATION.md)를 따른다.
합성 실패 테스트와 실제 helper의 자체 제작 신규/기존 MPQ 검증을 게임 관찰과 구분한다.
