# ADR-0032: 다른 종류의 미선택 두다드 이웃 검증

- Status: Superseded by [ADR-0033](0033-all-doodad-neighbor-candidates.md)
- Date: 2026-10-20
- Supersedes: [ADR-0031](0031-retained-doodad-neighbor-validation.md)

## Context

단일 후보인 동일 종류 이웃을 보존할 수 있지만, 다른 종류의 이웃은 삭제 창이
정의를 조회하지 않고 domain도 선택 종류만 허용하므로 계속 거부했다. 카탈로그를
이웃마다 재조회하거나 미선택 이웃을 삭제 요청으로 바꾸지 않고 범위를 확대한다.

## Decision

`DoodadDeletionPlan.recipeLookupTypes`는 cached typed DD2와 명시 선택 인덱스를
읽는 순수 조회다. 선택은 1~32개이며 중복/범위 밖 값은 거부하고 입력을 33개까지만
읽는다. 두다드 최대 크기 16x16의 양쪽 중심 반경을 사용하여 두 중심의 x/y 차이가
각각 512px 미만인 미선택 후보를 모은다. 정확히 닿는 최대 영역은 겹침이 아니다.
이는 조회를 위한 보수적 범위이지 실제 삭제 허가가 아니다.

선택 종류와 가능한 이웃 종류를 합쳐 최대 32종, 미선택 후보 최대 256개를 조회
범위에 포함한다. 상한을 넘으면 **선택 종류 집합 전체로 되돌아간다**. 임의 일부를
선택하거나 기존 선택 종류를 누락하지 않는다. 실제 삭제의 기존 보수적 겹침 검사는
유지하므로 누락된 이웃을 안전하다고 추정하지 않는다. 결과는 불변 집합이다.
`ObjectEditingController`는 편집 가능한 유일 DD2 세션에서 이 조회를 제공한다.

단일/다중/혼합 삭제 창 모두 이 집합으로 기존 metadata API를 한 번 호출한다.
`requireCompleteTypes: true`와 페이지 출처/순서/문서 identity 검증은 유지한다.
선택한 두다드의 recipe 선택창은 선택 종류만 표시한다. 다른 종류의 후보가 누락되거나
여러 개면 보존 검증에 전달하지 않는다. 상한도 catalog/domain의 같은 상수로 관리한다.

domain은 `retainedNeighborRecipes`를 선택 종류로 제한하지 않되 최대 32종 및
key/type 일치를 검사한다. 가까운 실제 이웃의 타일셋·상태 0/1·정렬·맵 경계·현재
쓰기 타일 검증과 전체 footprint 비겹침, 최대 256개/계획 내부 재사용은 유지한다.
완전한 단일 후보 조회 결과라는 provenance는 내부 호출자 계약이다. 임의 외부
recipe를 이 API가 인증하지는 않는다.

이웃 DD2/지형·미선택 THG2를 그대로 보존하고 추가 overlay 선택이나 자동 귀속은
하지 않는다. 사용자가 별도로 선택한 Sprite를 제거하는 기존 계약은 유지한다.
Apply의 잠금/문서 identity 검증과 한 Undo/Redo, TILE/unknown bytes 보존은 그대로다.

## Alternatives

- 맵 전체 종류를 무제한 수집: 멀리 있는 무관한 원시 객체를 범위에 넣지 않는다.
- 상한에 맞춰 임의 일부 이웃 선택: 처리 순서에 따라 허용 범위가 바뀌므로 하지 않는다.
- 이웃마다 카탈로그 재조회: 이미 전체 metadata를 순회하므로 기존 한 번 조회를 재사용한다.
- 복수 후보 중 타일이 맞는 첫 후보 선택: 다른 크기를 배제할 근거가 없어 계속 거부한다.

## Consequences and Validation

추가 I/O/atlas/thumbnail이나 장기 cache가 없다. 조회 스캔은 DD2 수 N과 최대 선택
32개에 대해 O(32N)이며 상한 초과 시 조기 반환한다. 기존 typed view를 사용하므로
조회 때문에 binary를 다시 decode하지 않는다. 이웃 지형 검증은 최대 65,536개 셀,
실제 footprint 대조 및 선택 대상별 decode는 기존대로다. 시간/RSS 개선은 미측정이다.
복수/누락 후보·실제 겹침·복원 정보 부족·게임/외부 에디터 인수는 계속 남는다.
계획/시나리오/자동 결과는 [실행 기록](../DOODAD_DELETION.md)을 따른다.
