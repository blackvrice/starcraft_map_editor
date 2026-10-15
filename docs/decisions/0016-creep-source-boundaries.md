# ADR-0016: 크립 정적 자료와 실제 관찰의 경계

- Status: Accepted
- Date: 2026-10-15

## Context

읽기 전용 크립 API는 명시적 coverage를 요구하지만 실제 collector는 없다.
정적 타일/유닛 자료를 이용해 initialMap을 자동 생성할 수 있는지
[출처 조사](../research/INITIAL_CREEP_SOURCE_FEASIBILITY.md)로 대조했다.
참고 구현의 불명확한 raw bit 식과 실제 관찰·지형 seed·유닛 생성/확장의 차이를 확인했다.

## Decision

- 실제 initialMap/live는 현재 collector 미지원으로 유지한다. coverage가 없으면 unavailable이다.
- CV5의 관련 원시 플래그, MTXM 값, THG2·MASK·UNIT 레코드는 완전한 게임 관찰이 아니다.
  비트 숫자나 ID만으로 present/absent를 채우거나 높은 raw 비트를 지우지 않는다.
- 다음 로컬 자료 단계는 CV5 bit6/12/14를 각각 보존하는 optional 숫자 profile로 한정한다.
  자료 누락은 unknown이며 기존 buildability/walkability 응답으로 대체하지 않는다.
- 제작용 coverage가 필요하면 이름·가정·지원 범위·revision을 별도로 결정한다.
  실제 초기/live로 fallback·재명명하지 않고 모델별 결과/cache를 분리한다.
- 실제 collector는 문서/자료 일치 외에 관찰 phase/frame·setup·권한·unknown 영역과
  지원 게임 버전을 검증해야 한다. 정적 자료의 완전성을 실제 관찰의 완전성으로 바꾸지 않는다.
- 참고 엔진이나 BWAPI를 자동 실행·주입·설치하지 않는다. 코드/엔진 배포는 별도 검토이며,
  실제 게임/외부 에디터 인수 없이 호환 완료라고 표시하지 않는다.

## Alternatives

- raw MTXM 고위 비트를 실제 크립으로 해석: 모순된 참고 식만으로 명세를 추정하므로 거절했다.
- 모든 생성 유닛에 고정 반경 채우기: 상태·지형·생성 결과를 숨기므로 현재 채택하지 않는다.
- 수집기 없이 빈 맵을 absent로 간주: 정적/동적 다른 출처를 누락하므로 거절했다.
- 개발을 모두 중단: 출처 있는 로컬 후보 자료와 관찰 경계 검증은 독립적으로 진행할 수 있다.

## Consequences

이번 결정은 실제 collector 구현 완료가 아니다. 정적 플래그 조회는 가능하지만 그것만으로
정상 크립 배치 정책을 활성화할 수 없다. 기존 raw bytes/정책/UI를 유지하고, 실제 관찰을
추가할 때 범위와 인수를 별도로 증명한다. 외부 엔진 코드·원시 게임 자산을 추가하지 않는다.

## Validation

raw MTXM·THG2·생성 유닛·MASK·buildable/walkable 성공을 실제 coverage로 승격하지 않는
합성 회귀와 byte-exact/선택/history 무변경을 확인한다. 수집기/모델을 새로 도입할 때에도
이 회귀의 기본 initialMap/live 미확인 계약을 유지한다. 게임 관찰은 별도 인수다.
