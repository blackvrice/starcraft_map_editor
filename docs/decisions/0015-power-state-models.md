# ADR-0015: 전력 설계 모델과 실제 상태 분리

- Status: Accepted
- Date: 2026-10-15

## Context

초기 전력 조회를 위해 CHK의 UNIT을 실제 존재·완공·활성 상태로 변환하려 했다.
그러나 참고 엔진에서도 초기 유닛은 setup/player 조건에 따라 생성되지 않거나
생성에 실패할 수 있다. 정적 CHK만으로 실제 SC:R 상태를 확인했다고 주장할 수 없다.
참고 소스의 지원 한계와 고정 출처는 [조사·실행 기록](../UNIT_POWER_LAYOUT.md)에 남긴다.

## Decision

- 실제 초기 상태 `initialMap`, 미지원 동적 상태 `live`, 명시적인 사전 배치 설계 모델
  `preplacedLayout`을 분리한다. 기본 요청/조회는 계속 initialMap이다.
- 설계 모델은 지원되는 일반 UNIT156을 존재·완공·활성으로 **가정하는 제작용 투영**이다.
  로비 참여·유닛 생성·trigger/EUD 실행이나 실제 게임의 공급 상태를 보증하지 않는다.
- built-in adapter는 preplacedLayout을 요청한 경우만 응답한다. 실제 상태 요청으로
  자동 fallback하거나 결과 이름을 바꾸지 않는다. 미지원 레코드는 unknown으로 남긴다.
- 수집과 조회 모두 모델을 명시한다. 모델이 다른 cached/pending 응답은 공유하지 않는다.
  조회 결과에는 모델·provider ID·state revision을 담는다.
- 기존 문서/출처/record identity/revision·취소·최종 좌표 검증을 유지한다.
- 이후 UI에 연결할 때도 사전 배치 설계 검사라는 범위를 표시한다. 이번 UI/배치 차단은 유지한다.

## Alternatives

- 모든 UNIT을 실제 완공/활성으로 간주: 로비/setup/생성 실패와 runtime 차이를 숨겨 거절했다.
- 항상 unknown만 반환: 안전하지만 제작용 정적 범위 계산과 실제 상태의 구분을 제공하지 못한다.
- 게임/참고 엔진 자동 실행: 이번 자동 테스트/빌드 범위를 넘고 SC:R 인수의 대체도 아니므로 제외했다.

## Consequences

설계 모델은 사용할 수 있으나 실제 초기 상태 collector는 여전히 없다. 의미가 다른
결과의 재사용을 막는 API 변경과 모델별 테스트가 필요하다. Domain의 bool 사실은 caller의
모델 안에서만 유효하다. 참고 엔진을 링크·배포하거나 그 구현을 복사하지 않는다.

## Validation

모델 요청/응답 불일치, 기본 실제 상태의 unknown, 잘못된 상태의 미승격, 역순 응답,
Undo/Redo, 원시 bytes와 UI 정책 무변경을 자동 검증한다. 실제 게임/릴리스 인수는 별도다.
