# ADR-0020: 관찰된 초기 크립의 선택적 배치 검사

- Status: Accepted
- Date: 2026-10-16

## Context

기존 초기 크립 API는 phase/관찰 mask·문서/자료 revision을 검증하지만 UI와 배치 정책에
연결되지 않았다. 기본 앱에는 실제 SC:R collector가 없다. 사용자는 에디터 기능을 우선하고
실제 수집은 미지원으로 표시하도록 선택했다. 전력의 사전 배치 설계 모델은 이미 별도다.

## Decision

기존 power/creep inspection의 좌표별 UI와 명시적 조회를 연결한다. power provider의 optional
모델 지원 선언은 UI 요청 가능 여부만 결정하며 실제 게임 호환/권한 증명으로 사용하지 않는다.
기본 power adapter는 layout만 선언하고 초기/live를 수집하는 척하지 않는다.

크립 요구 검사는 기본 off이며 양의 requiresCreep 요구만 대상으로 한다. 현재 source/session/
revision/initial 관찰 증거에 결합된 coverage만 공통 prepare에 전달하고 최종 footprint를 검사한다.
unknown/자료 없음은 확인 불가로 거절한다. hover/Apply는 상태 수집을 시작하지 않는다.
문서/transaction/Undo/설치 변경은 관찰을 무효화하며 Undo로 같은 bytes가 되어도 부활하지 않는다.

## Alternatives

- UNIT 반경·CV5 후보 flag로 실제 크립 생성: 검증 근거가 없으므로 금지한다.
- 체크 프리셋에서 관찰 규칙 자동 활성화: collector 없는 기본 앱을 불필요하게 막으므로 채택하지 않는다.
- hover 결과를 클릭 허가로 보관: 현재 문서/최종 좌표가 바뀔 수 있으므로 채택하지 않는다.
- 실제 게임 자동 실행/주입: 이번 사용자 선택 범위가 아니며 구현하지 않는다.

## Consequences

기본 앱은 사전 배치 전력 설계 검사를 사용할 수 있지만 실제 게임 크립/전력을 수집하지 못한다.
크립 요구 옵션을 켜고 관찰이 없으면 대상 유닛은 거절된다. no-creep 요구는 금지/면제 규칙의
승인이 아니다. 기존 UNIT 이동/복제·Sprite/Doodad·runtime EUD 수정값과 전체 건설 규칙은 범위 밖이다.
실제 collector를 추가하려면 별도 지원 build·초기 시점/권한·입력 결합과 게임 인수가 필요하다.

## Validation

[에디터 계약·계획·요구사항·실행 기록](../PLACEMENT_ENVIRONMENT_EDITOR.md)을 따른다.
합성 관찰·로컬 DAT/MPQ 자동 회귀를 실제 SC:R 실행 증거로 계산하지 않는다.
