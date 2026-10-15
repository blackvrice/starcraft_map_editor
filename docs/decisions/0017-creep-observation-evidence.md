# ADR-0017: 초기 크립 관찰 증거와 미관찰 타일 처리

- Status: Accepted
- Date: 2026-10-15

## Context

[ADR-0016](0016-creep-source-boundaries.md)은 정적 후보와 실제 관찰을 분리했다.
기존 크립 포트는 request/source/DIM은 검사하지만 관찰 phase/frame·게임/수집기 버전·
권한을 기록하지 않아 초기 상태와 일반 실행 중 샘플을 구분할 수 없었다.
이 결정은 실제 collector를 구현하거나 신뢰할 수 있다고 선언하는 결정이 아니다.

## Decision

- 순수 불변 `UnitCreepObservation`에 contract/collector/game version·game session/setup
  revision·phase·raw game frame·정규화된 simulation frame·권한/관찰자·타일별 관찰 여부를 기록한다.
- initialMap은 현행 contract와 `initializedBeforeFirstTriggerCycle`, simulationFrame=0,
  unverified가 아닌 명시적 권한 선언을 필요로 한다. running/unknown/unverified는 사용할 수 없다.
- simulationFrame은 이 계약의 초기화 이후 단계 수다. raw gameFrame=0을 SC:R 명세로
  가정하지 않는다. 실제 collector가 초기화 완료/첫 trigger cycle 이전 지점의 대응을 증명해야 한다.
- fullMap/playerVision은 collector의 선언이며 권한을 얻거나 검증하는 기능이 아니다.
  playerVision은 명시적 observerPlayer 0..11을 요구한다. 이 숫자 범위는 입력 슬롯 계약이지
  게임의 observer 권한/슬롯별 이용 가능성에 대한 선언이 아니다.
- 관찰 mask가 false인 타일은 전달된 present/absent에 관계없이 unknown이다. fullMap도
  mask를 생략하거나 전체 관찰로 간주하지 않는다. 관찰된 unknown도 그대로 유지한다.
- snapshot 생성 시 한 번 정규화하고 이후 `coverageFor`에서 O(1) 증거 검증을 한다.
  missing/불일치 증거는 coverage를 all-unknown으로 두고 유효 조회를 거절한다.
- 기존 evidence-free snapshot은 생성할 수 있으나 더 이상 유효 coverage가 아니다.
  source echo·잘 형성된 metadata만으로 실제 게임/문서 일치·지원 build·권한을 증명하지 않는다.
- live·collector/bootstrap 등록·프로세스/게임 실행·UI/배치 정책은 여전히 미지원이다.

## Alternatives

- 기존 snapshot의 자료를 암묵적으로 전체 맵 관찰로 간주: 숨긴 false를 부재로 바꿀 수 있어 거절.
- raw frame0만 확인: 초기화/트리거 단계와 프레임 번호 대응을 추정하므로 거절.
- 매 커서 조회에서 관찰 mask 처리: 동일한 불변 자료를 반복 순회하므로 수신 시 한 번 처리.
- 실제 engine adapter 구현 완료 처리: 출처/관찰 지점/지원 build/SC:R 비교가 없으므로 거절.

## Consequences

기존 외부 adapter가 있다면 새 증거를 명시적으로 제공해야 한다. 현재 기본 앱은 collector가
없으므로 기존 unavailable 동작을 유지한다. 합성 fixture는 합성 game/collector 이름을 사용하며
실제 게임 증거로 계산하지 않는다. 최종 collector는 실행/수집 권한, 현재 CHK·리소스·setup과
실제 실행 입력의 일치, 지원 버전 목록, 관찰 시점·영역을 별도 검증해야 한다.

## Validation

메타데이터/프레임/권한/크기·legacy 거절, 부분 관찰/행 우선/최대 mask, 반복 불변 조회,
controller 거절 후 재시도·읽기 전용·기존 취소/Undo 회귀를 수행한다.
결과는 [구현·검증 기록](../UNIT_CREEP_OBSERVATION.md)에 남긴다.
