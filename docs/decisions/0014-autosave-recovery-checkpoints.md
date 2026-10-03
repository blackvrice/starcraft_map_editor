# ADR-0014: 원본과 분리된 복구 체크포인트

- Status: Accepted
- Date: 2026-10-03

## Context

미저장 맵에는 원시 CHK와 MPQ 리소스 편집이 있고 EUD 프로젝트와 epScript는
각자 저장 기준선이 있다. 주기적으로 원본을 덮어쓰면 무손실·Save As 정책과 충돌한다.

## Decision

원본 경로/fingerprint·마지막 CHK·현재 CHK/dirty 섹션·리소스 delta·EUD/epScript를
하나의 schema 1 체크포인트에 보관한다. 각 실행은 독립된 파일 ID를 사용하며
flush·checksum·재읽기 이후 새 세대를 rename한다. 보관 수 정리는 그 이후 수행한다.
복구는 명시적 UI 동작이며 마지막 원본 맵을 fingerprint/CHK로 재검증한다.
EUD 프로젝트는 새 미저장 프로젝트로 복원하고 컴파일러를 실행하지 않는다.

## Alternatives

원본 주기 저장은 데이터 안전 정책에 맞지 않는다. 매번 전체 MPQ를 복제/생성하는
방식은 helper I/O와 대용량 아카이브 비용이 크다. CHK만 저장하면 사운드·프로젝트·
소스 변경이 사라지므로 문서 상태를 함께 보관한다.

## Consequences

기존 맵은 마지막 저장 아카이브가 그대로 존재해야 전체 리소스를 보존해 복구 가능하다.
원본이 변경/삭제되면 추측 병합하지 않고 거부한다. 새 맵은 원본 없이 복구한다.
이전 실행의 복구본은 사용자가 정리하며 미적용 폼과 Undo 이력은 포함하지 않는다.
한 세대 최대 192 MiB, 기본 30초/5세대다. [계약](../AUTOSAVE_RECOVERY.md)을 따른다.

## Validation

바이트 보존·사운드·EUD/소스·쓰기 실패·세대 보관·충돌·손상·UI와 실제 MPQ
재시작/Save As 왕복을 자동 테스트로 검증한다.
