# ADR-0029: 유닛 관계 확인을 포함한 두다드 혼합 삭제

- Status: Accepted
- Date: 2026-10-19
- Supersedes: [ADR-0028](0028-doodad-sprite-mixed-deletion.md)

## Context

두다드/Sprite 혼합 삭제는 구현됐지만 UNIT 객체가 포함되면 거부한다.
UNIT 삭제는 레코드 제거뿐 아니라 남아 있는 애드온/나이더스 상대의 관계 해제가
필요하다. 선택 유닛의 나가는 참조만 검증하면 선택 대상을 향한 비대칭 참조가
남을 수 있다. 기존 일반 삭제와 두다드 삭제를 순차 실행해서는 부분 적용/별도 Undo가 된다.

## Decision

두다드 1~32개·선택 Sprite 0~256개의 기존 계약에 선택 Unit 0~256개를 추가한다.
새 순수 domain `UnitDeletionPlan`은 유일하고 완전한 UNIT에서 원본 인덱스를
검사한다. 입력을 257개까지만 읽고 초과/중복/범위 밖 값을 거부한다.

선택한 nonzero class ID를 가리키는 incoming 레코드도 수집한다. 정상 상호 연결은
선택 유닛당 최대 한 peer이므로 후보가 선택 개수의 두 배를 넘으면 거부한다.
기존 `ChkBasicEditing.unlinkUnits`로 연결된 후보의 nonzero/유일 ID·알려진 관계
flags·상호 참조를 검증한다. 일방/알 수 없는/중복/누락 관계는 추측 해제하지 않는다.
관련 없는 잘못된 관계는 정규화하지 않는다. 일반 객체 삭제 경로는 바꾸지 않는다.

선택 Unit만 제거한다. 남는 정상 peer은 원본 인덱스로 나열하고 관계 flags와
peer class ID만 0으로 바꾼다. 나머지 bytes는 보존한다. 확인 창의 체크박스가
선택되면 정확한 peer 인덱스 집합을 `confirmedUnitPeerRecordIndices`로 전달한다.
domain도 계산한 영향 집합과 정확히 일치하는지 검사한다. 두 유닛을 모두 삭제하면
남는 peer이 없어 관계 해제 확인을 요구하지 않는다.

Unit 계획을 Doodad 계획의 UNIT replacement로 결합하여 MTXM/DD2/THG2/UNIT을
한 명령으로 적용한다. 원본 identity·구조·필수 레이어 잠금/숨김·편집 가능 상태를
다시 확인한다. overlay 명시 귀속은 그대로 필요하다. 취소/오류는 부분 적용하지 않는다.
MRGN/TRIG/문자열/TILE은 바꾸지 않으며 Location 혼합은 계속 거부한다.

## Alternatives

- 선택 대상만 unlink: 들어오는 비대칭 참조를 놓칠 수 있어 채택하지 않는다.
- 상대도 자동 삭제: 명시 선택하지 않은 유닛까지 제거하므로 거부한다.
- UI checkbox만 검사: application 호출의 우회를 막기 위해 domain에서 정확한 집합도 확인한다.
- 관계 로직 새 구현: 기존 무손실 unlink 검증을 재사용하고 incoming 수집만 추가한다.

## Consequences and Validation

선택/확인 목록은 각각 257개까지만 읽고 관계 후보는 최대 512개다. incoming 수집은
한 번 순회하며 기존 unlink의 후보별 UNIT 스캔은 유지한다. 실제 지연/RSS 향상을
측정했다고 주장하지 않는다. preview와 Apply에서 계획을 재검증하는 비용은 수용한다.
한영 UI·상한·상호/비대칭 관계·한 Undo·실제 MPQ 저장/재열기와 전체 게이트는
[실행 기록](../DOODAD_DELETION.md)을 따른다. 게임/외부 에디터 인수 완료는 아니다.
