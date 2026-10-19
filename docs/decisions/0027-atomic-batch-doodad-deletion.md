# ADR-0027: 원본 인덱스 기반 두다드 일괄 삭제

- Status: Accepted
- Date: 2026-10-19
- Supersedes: [ADR-0026](0026-disabled-doodad-deletion.md)

## Context

기존 단일 삭제는 복원/귀속 검증을 제공하지만 다중 선택을 거부한다.
단일 삭제를 반복하면 DD2/THG2 인덱스가 밀리고 일부만 삭제될 수 있다.
확인된 선택 이웃도 최대 16×16 미확인 범위로 취급하면 인접한 선택을 지울 수 없다.

## Decision

기존 단일 경로와 상태 0/1·TILE·geometry·명시 귀속·잠금/context 검증을 유지한다.
최대 32개의 immutable 요청을 원래 문서에서 검증하고 원본 레코드 인덱스로
최종 MTXM/DD2/THG2를 한 번 생성한다. 한 Undo로 적용하며 실패 시 부분 결과를 내지 않는다.
DD2/overlay 중복 귀속을 금지한다. 모든 선택의 recipe를 검증할 때만 그 이웃의
실제 전체 footprint를 비교한다. 확인하지 않은 이웃은 기존 보수적 범위를 유지한다.
혼합 객체/실제 겹침/알 수 없는 상태/복원 정보 부족은 계속 거부한다.

확인 창은 개수와 각 대상/recipe/overlay를 표시하고 overlay를 자동 선택하지 않는다.
입력 iterable은 33개까지만 읽어 상한을 검사한다. UI 파일/바이너리 I/O는 기존
application/gateway 경계 뒤에 유지하고 네이티브 helper/CHK 포맷은 바꾸지 않는다.

## Alternatives

- 순차 삭제와 여러 Undo: 인덱스 이동과 부분 적용을 만들므로 선택하지 않는다.
- 선택한 모든 인근 범위를 무조건 무시: 잘못된 recipe/실제 겹침도 지워지므로 거부한다.
- 일반 Sprite/Unit 혼합 삭제: overlay 귀속 충돌을 포함한 별도 정책이 필요하여 후속이다.

## Consequences and Validation

32개·8192 footprint 셀 상한과 sparse 복원 정보를 사용한다. 폐기할 전체 섹션을
검증마다 만들지 않고 최종 출력만 생성한다. typed decode 재사용과 서로 다른 종류의
직렬 catalog 조회는 유지하며 실제 성능/RSS 인수는 별도다.
[실행 기록](../DOODAD_DELETION.md)의 한 Undo/무변경 거부·한영 확인 창·실제 MPQ
원본 보존과 전체 회귀로 검증한다. SC:R/외부 에디터 인수를 완료한 결정은 아니다.
