# ADR-0030: 정적 참조를 검증한 로케이션 혼합 삭제

- Status: Superseded by [ADR-0031](0031-retained-doodad-neighbor-validation.md)
- Date: 2026-10-20
- Supersedes: [ADR-0029](0029-unit-mixed-doodad-deletion.md)

## Context

두다드/Unit/Sprite 혼합 삭제는 구현됐지만 Location은 참조 정책이 없어 거부했다.
MRGN 배열에서 레코드를 제거하면 ID가 밀리므로 슬롯을 비워야 한다. 단순히 빈
참조 목록을 얻었다고 미사용을 단정하면 unknown/EUDX/손상 트리거를 놓칠 수 있다.

## Decision

기존 두다드 복원·overlay·UNIT 관계 확인에 MRGN 슬롯 1~254개를 추가한다.
유일한 Original 64개/확장 255개 MRGN만 허용한다. 빈 슬롯·Anywhere(ID 64)·
중복/범위 밖 인덱스와 불완전한 섹션은 거부한다. 입력은 255개까지만 읽는다.

`LocationDeletionPlan`은 저장된 TRIG/MBRF 합계 최대 4096개를 검사한다. TRIG는
유일해야 하며 MBRF 부재는 허용하되 중복/잘림은 거부한다. 맵 간 복사의 기존
엄격한 portable 검증을 `ChkTriggerPortability`로 공유한다. 헤더/owner/예약 bytes,
briefing marker, unknown/EUDX/범위 밖 Deaths, canonical opcode/인자를 검사한다.
기존 transfer 진단 코드와 지원 범위는 바꾸지 않는다.

비활성 record/slot도 포함하여 알려진 모든 location 인자를 조사한다. 조건뿐 아니라
목적지 인자도 포함한다. 선택 ID가 사용되면 거부하며, 한 slot이라도 해석 불가능하면
미참조라고 추측하지 않는다. TRIG/MBRF bytes는 쓰지 않는다. 외부/미적용 EUD 코드와
런타임의 동적 참조는 이 정적 검사 범위 밖이다. UI는 이 미검증 경계를 고지한다.

사용자가 슬롯 비우기 checkbox를 확인하면 정확한 원본 인덱스 집합을 전달한다.
domain은 `confirmedLocationRecordIndices`의 정확한 일치를 요구한다. 선택한
20-byte 슬롯만 0으로 바꾸고 ID/배열 길이·다른 슬롯·공유 문자열을 보존한다.
MRGN replacement를 기존 계획에 합쳐 한 Undo로 적용한다. Location 레이어의
잠금/숨김·문서 identity·편집 상태를 재검사한다. 실패/취소는 부분 적용하지 않는다.

## Alternatives

- 참조가 있는 슬롯도 비우기: 이미 있는 일반 트리거 의미가 달라져 이번 프로필에서는 거부한다.
- 배열 원소 삭제/ID 재매핑: 알 수 없는 소비자와 원시 참조를 바꿀 수 있어 선택하지 않는다.
- unknown slot 무시: 참조 부재의 근거가 아니므로 거부한다.
- 외부 코드를 실행해 참조 수집: 신뢰 경계를 넘고 동적 참조도 보장하지 못해 수행하지 않는다.

## Consequences and Validation

기존 일반 객체 삭제 경로는 바꾸지 않는다. 이번 지원은 두다드를 포함한 정적
참조 검증형 혼합 삭제에 한정된다. canonical 검증과 인자 조회의 두 순회는
기존 안전 검증을 공유하기 위해 유지한다. 실제 지연/RSS와 동적 코드 의미는 미검증이다.
조건/액션/목적지/비활성 참조·불투명 slot·254/255개·원시 bytes·한영 UI·한 Undo·
자체 제작 MPQ와 전체 게이트를 [실행 기록](../DOODAD_DELETION.md)에 남긴다.
실제 게임/외부 에디터 왕복 인수를 완료한 결정은 아니다.
