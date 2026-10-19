# ADR-0028: 두다드와 스프라이트의 원자적 혼합 삭제

- Status: Superseded by [ADR-0029](0029-unit-mixed-doodad-deletion.md)
- Date: 2026-10-19
- Supersedes: [ADR-0027](0027-atomic-batch-doodad-deletion.md)

## Context

두다드만 최대 32개 삭제할 수 있지만 다른 스프라이트가 함께 선택되면 거부한다.
일반 Sprite 삭제를 먼저 적용하면 overlay의 THG2 인덱스가 밀리고, 두 명령으로
나누면 부분 삭제/여러 Undo가 생긴다. 좌표 일치만으로 overlay 귀속을 추정해서는 안 된다.

## Decision

ADR-0027의 동일 원본·복원 정보·footprint·상태·overlay·잠금 검증을 유지한다.
1~32개 두다드와 별도로 선택한 최대 256개 THG2 레코드의 혼합 삭제를 허용한다.
선택 Sprite의 원래 인덱스 목록을 `DoodadDeletionPlan.createBatch`에 전달한다.
목록은 257개까지만 읽고 초과·중복·음수/범위 밖 인덱스를 전체 거부한다.
유일하고 완전한 THG2가 필요하며 잘린 꼬리/중복 섹션을 자동 정규화하지 않는다.

두다드별 overlay는 별도로 명시 확인한다. Sprite로 선택한 사실만으로 귀속을
확인한 것으로 취급하지 않는다. 두다드 간 overlay 중복 귀속은 계속 거부한다.
검증한 overlay 인덱스와 선택 Sprite 인덱스의 합집합을 원본 THG2에서 한 번
삭제한다. 같은 레코드가 양쪽에서 선택되면 한 번만 삭제하며 실제 THG2 삭제 수는
`spriteCount`, 귀속 확인 수는 `overlayCount`로 구분한다.

명시 선택한 Sprite는 일반 객체 삭제와 같은 원시 레코드 삭제 대상이다. 다른
DD2와 숨은 귀속이 있는지 추측하지 않으며 좌표가 같다는 이유로 미선택 레코드를
추가 삭제하지 않는다. Unit/Location 혼합은 아직 거부하고 관련 UNIT/MRGN/TRIG/
문자열·TILE bytes는 바꾸지 않는다. pure sprite와 unit-sprite 모두 같은 원칙이다.

확인 창은 두다드/선택 Sprite 개수와 선택 THG2 인덱스/종류를 표시한다.
모든 필수 overlay 확인 후 MTXM/DD2/THG2를 한 Undo로 적용한다. 취소·오류·
문서 교체·필수 레이어 숨김/잠금에서는 부분 적용하지 않는다.

## Alternatives

- Sprite를 지운 문서에서 두다드 계획 생성: 원래 인덱스와 귀속 확인이 달라져 거부한다.
- 선택된 overlay 자동 귀속 확인: 선택과 소유권은 다르므로 채택하지 않는다.
- Unit/Location까지 확장: UNIT 관계와 MRGN 참조의 별도 정책이 필요하여 후속으로 둔다.

## Consequences and Validation

THG2 출력은 한 번만 생성한다. 추가 인덱스/섹션 검증을 출력 생성보다 먼저
수행하고 최대 288개 THG2 인덱스 집합을 유지한다. 전체 지연/RSS는 별도 측정이다.
[실행 기록](../DOODAD_DELETION.md)의 domain·명령·한영 UI·MPQ·전체 게이트로
확인한다. 실제 게임/외부 에디터 왕복 인수와 지원하지 않는 겹침/복원 부족 사례는 남는다.
