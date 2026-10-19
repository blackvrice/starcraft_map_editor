# ADR-0026: 일관된 비활성 두다드의 검증형 단일 삭제

- Status: Accepted
- Date: 2026-10-19
- Supersedes: [ADR-0010](0010-reviewed-doodad-deletion.md)

## Context

상태 편집/복합 clipboard는 DD2=1 비활성을 지원하지만 단일 삭제는 활성만
허용했다. 비활성 입력의 DD2/THG2를 먼저 정규화하면 원문 귀속을 흐리고,
상태 편집 함수가 삭제 계획을 검증에 쓰므로 재귀 의존을 만들 수 있다.

## Decision

기존 ADR-0010의 단일 레코드·유일한 섹션·TILE/footprint 검증·인근 겹침 거절·
명시 overlay 귀속·잠금/context·한 Undo·다중/혼합 선택 거부를 모두 유지한다.
DD2 상태를 0/1로 제한하되 둘 다 삭제 가능하게 한다. pure sprite의 flags는
항상 `0x1000`, sprite-unit은 활성 `0x0000`/비활성 `0x8000`과 정확히 같아야 한다.
상태 계산은 recipe의 작은 순수 함수로 공유하고 원래 문서를 직접 검증한다.
이 정책은 일관되지 않은 legacy 상태의 자동 수리/플래그 정규화를 허용하지 않는다.

## Alternatives

- 상태 편집 호출 후 삭제: 재귀 경계와 정규화된 중간 상태를 만들므로 선택하지 않는다.
- 임의 flags에서 bit15만 무시: 알 수 없는 비트/의미를 지우므로 선택하지 않는다.
- 다중 삭제/인근 범위 완화: 추가 recipe/소유권 증거가 필요하므로 후속으로 유지한다.

## Consequences

비활성 두다드도 현재 지형/복원/overlay 증거가 완전할 때만 삭제한다. UI와 domain의
후보 조건이 같으며 확인 전 자동 변경하지 않는다. native/helper/CHK 포맷은 바꾸지 않는다.
실제 게임/외부 에디터 인수는 여전히 미완료다.

## Validation

[실행 기록](../DOODAD_DELETION.md)의 실패 재현·상태/geometry 거부·바이트 보존·
원자 Undo/Redo·한영 UI·실제 MPQ 왕복/원본 불변과 전체 회귀를 따른다.
