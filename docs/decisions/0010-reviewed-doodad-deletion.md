# ADR-0010: 복원 정보가 있는 단일 Doodad의 명시적 복합 삭제

- Status: Accepted
- Date: 2026-09-25

## Context

기존 `deleteSelection`은 DD2 레코드만 제거해 지형/overlay가 남을 수 있었다.
DD2에는 원래 지형이나 THG2 소유권 ID가 없으므로 좌표 일치로 소유권을 추측할 수 없다.
ADR-0008의 추측 금지 원칙을 유지하며 사용자가 요청한 기존 Doodad 삭제를 제한된
검증 가능 범위에서 제공한다.

## Decision

- 단일 Doodad만 복합 삭제한다. 종류·CV5 group recipe는 로컬 카탈로그에서 선택한다.
- DIM/ERA/MTXM/DD2/TILE은 유일하고 해석 가능해야 한다. TILE은 정확한 맵 크기여야 한다.
- enabled DD2의 좌표가 recipe 중심에 맞고 footprint가 맵 안에 있어야 한다.
- 쓰기 대상 MTXM이 recipe와 일치하고 TILE 복원 값이 Doodad 값과 다르며,
  지정된 placibility group이 있으면 그 group과 일치해야 한다.
- 다른 Doodad의 최대 16×16 footprint가 겹칠 가능성이 있으면 보수적으로 거부한다.
- overlay가 필요하면 THG2는 유일해야 한다. 사용자가 type/좌표/owner/flags/unused가
  맞는 레코드를 직접 골라 귀속을 확인한다. 유일한 후보라도 자동 선택하지 않는다.
- 한 Undo 명령으로 MTXM 복원, DD2 삭제, 확인한 THG2 삭제를 적용한다. TILE과 관련
  없는 바이트는 보존한다. 준비 이후 문서 변경과 필요한 레이어 잠금은 적용을 막는다.
- 일반 삭제에서 Doodad가 포함된 혼합 선택은 부분 삭제 없이 거부한다.

## Consequences

TILE이 없는 맵, disabled/변형된 Doodad, 겹침 가능성이 있는 배치, 다중 Doodad와
모호한 섹션은 아직 지원하지 않는다. 사용자 확인도 이 검증을 우회하지 못한다.
TILE을 자동 생성하거나 복원 값을 추정하지 않는다. 이 결정은 기존 조사 문서의
Chkdraft TILE 복원 참고를 따르지만 외부 에디터 상호 운용 검증 완료를 뜻하지 않는다.

## Validation

자체 제작 CHK를 직렬화/재열기한 뒤 DD2·MTXM·THG2 변경, Undo/Redo 바이트 정확
왕복, 잘못된 TILE/지형/overlay 거부, UI 취소와 명시적 overlay 선택을 자동 검증한다.
실제 SC:R/외부 에디터 왕복과 미지원 입력의 확대는 별도 검증으로 남긴다.
