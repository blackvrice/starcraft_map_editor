# 초기 크립 관찰 증거 검증

2026-10-15. EP1/FR-218 실제 collector 작업의 **입력 계약·안전 검증 하위 단계**다.
실제 collector·게임 실행/주입·SC:R 비교·UI/배치 차단을 완료한 것이 아니다.
[ADR-0017](decisions/0017-creep-observation-evidence.md)과
[기존 앱 조회](UNIT_CREEP_INSPECTION.md)를 함께 따른다.

## 1. 실행 계획·소스 분석

1. 기존 `UnitCreepStateSnapshot.coverageFor`와 controller의 수신/cache/취소 경계를 확인한다.
2. 초기화/트리거 시점·관찰 권한을 표현하지 못하는 기존 API를 보완한다.
3. 순수 불변 관찰 증거와 수신 시 unknown 정규화를 구현한다.
4. legacy/오류/부분 관찰/읽기 전용·재시도·기존 회귀를 테스트한다.
5. format/analyze/전체 테스트·Windows 빌드·native 회귀 결과와 미실행 위험을 기록한다.

기존 포트는 current request·문서 revision·자료 tuple·DIM과 model을 검사하지만
실제 관찰 단계·게임/수집기 버전·권한과 false의 의미를 기록할 수 없었다.
프로세스나 게임 도구 없이도 이 입력 경계는 독립적으로 구현·검증할 수 있다.
CV5/MTXM/THG2/MASK/UNIT을 coverage로 변환하지 않는다.
이번 계약은 in-process typed API이며 JSON/파일 import나 외부 IPC decoder가 아니다.
실제 transport와 입력 실행 환경의 신뢰 검증은 후속 구현이다.

## 2. 구현 계약

| 항목 | 현행 계약 |
| --- | --- |
| domain | `UnitCreepObservation`, Flutter/FS/FFI/프로세스 의존 없음 |
| 증거 revision | `initial-creep-observation-v1`, 다른 revision은 initialMap 조회 거절 |
| 기록 | collectorVersion/gameVersion/gameSessionId/setupRevision, 비어 있거나 제어문자/256자 초과 거절 |
| phase | initializedBeforeFirstTriggerCycle만 초기 상태 후보, running/unknown 거절 |
| frame | gameFrame=원시 번호, simulationFrame=초기화 이후 정규화 단계 수. initial은 후자0만 |
| frame 상한 | 0..0xffffffff 입력 예산. SC:R 프레임 단위/번호/지속 시간 보증이 아님 |
| authority | fullMap/playerVision/unverified. unverified는 거절, playerVision은 명시적 player index0..11 |
| 관찰 mask | width/height1..256와 정확히 같은 row-major boolean 배열·방어 복사/불변 |
| unknown | 관찰하지 않은 present/absent 모두 unknown. fullMap도 mask 생략/추정 금지 |
| 범위 | coverage와 mask 차원이 다르면 snapshot all-unknown·`coverageFor` 거절 |
| legacy | observation optional은 생성 호환용. null은 all-unknown·유효 coverage 아님 |
| 부적격 증거 | 초기 phase/frame/권한/revision이 부적격이어도 snapshot은 all-unknown·조회 거절 |
| 수신 | snapshot 생성 시 한 번 정규화. 모든 타일이 관찰됐으면 기존 불변 coverage 재사용 |
| 조회 | 기존 request/model/source/DIM과 새 증거를 확인한 뒤 정규화된 동일 coverage 반환 |
| 기록 접근 | `lastUnitCreepStateRead.snapshot.observation`에서 버전/시점/권한 확인 가능 |
| 기본 앱 | collector 없음·unavailable 유지. live fallback/자동 실행/새 UI/정책 없음 |

이 구조는 **collector가 선언한 metadata의 형식/일관성 검증**이다. `gameVersion`이
정상 문자열이라는 이유로 지원 게임 build로 승인하지 않는다. gameSessionId/setupRevision도
실제 실행 입력과 대응한다고 자동 증명하지 않는다. CASC build와 게임 executable 버전이
같다고 가정하지 않는다. 실제 adapter가 권한·phase 대응·현재 문서/리소스·setup 일치와
지원 build 목록을 검증해야 하며 현재 해당 adapter는 없다.

기존 snapshot의 const 생성자는 수신 시 정규화 때문에 일반 생성자로 바뀌었다.
현재 호출부 두 곳은 테스트뿐이며, 합성 fixture에 명시적인 합성 증거를 추가했다.
실제 관찰 증거로 꾸미지 않도록 gameVersion은 `synthetic-game-not-SCR`다.

## 3. 요구사항·테스트 체크리스트

| 시나리오 | 자동 검사 |
| --- | --- |
| 5개 필수 문자열의 empty/공백/control/C1/초과 | domain 거절 |
| 원시/정규화 frame 경계·음수·상한 초과 | domain, raw 번호와 normalized0 독립 |
| phase3종×frame0/1·미지원 revision | 초기 상태 자격만 인정, 나머지 거절 |
| 권한/관찰자 조합·미확인 권한 | null/음수/초과/잘못된 권한-슬롯 조합 거절 |
| mask 차원/부족/초과·immutable·row-major | domain·반환 coverage 불변/원본 입력 불변 |
| fullMap도 마지막 tile 미관찰 | 최대256×256의 마지막 tile unknown |
| legacy missing 증거 | all-unknown·initialMap 실패 |
| partial hidden present/absent·관찰된 unknown | snapshot 수신 시 정규화, 반복 조회 동일 객체 |
| 잘못된 관찰 증거6종 | controller 거절·명시적 재시도 회복·로그/Undo 보존 |
| fullMap/playerVision×미관찰 present/absent | 조회는 성공하나 footprint unavailable, cache 공유·CHK/state/history 불변 |
| 기존 취소/Undo/재열기/source 변경/live 거절 | 기존 controller 전체 회귀 |
| 실제 engine phase/권한/coverage·게임 버전 호환 | 미실행·미구현, 별도 인수 |

## 4. 최적화·주석

관찰 mask 정규화는 수신 시 O(width×height), 최대65,536tile 한 번이다.
전체 관찰이면 기존 불변 coverage를 재사용하고 부분 관찰이면 정규화된 불변 coverage를 한 번 만든다.
snapshot 생성 후 조회는 증거/크기 O(1)와 기존 bounded footprint 검사만 수행한다.
프로세스/bitmap/로컬 자산 읽기·새 cache·UI 구독을 추가하지 않았다.
프레임 해석·미관찰 false·전체 권한과 실제 샘플·legacy 실패 경계에 주석을 추가했다.
FPS/메모리 개선 수치를 측정한 것은 아니다.

## 5. 실행·결과 분석

ignored `.dart_tool/creep_observation_*.log`에 원시 로그를 남긴다.
실행 SDK Flutter3.47.5 stable/Dart3.13.4는 기준3.44.8/3.12와 다르다.

| 실행 | 결과 |
| --- | --- |
| domain/포트/controller 집중 | 400통과·10skip·exit0, 초기/최종 정규화 보강 후 모두 통과 |
| 최종 `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 1,993통과·59skip·exit0, 새74개 포함 |
| 로컬 설치 연결 domain/포트/controller | 410통과·skip 없음·exit0 |
| 변경 Dart6파일 format | 0변경·exit0 |
| 전체 format | 480파일 중 기존3파일 차이·exit1 |
| 최종 Windows Debug build | 성공·exit0, 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| 문서 링크 검사 | 관련6문서의 로컬 링크176개 존재 확인 |
| `git diff --check` | 통과 |

집중 테스트의10skip은 기존 실제 로컬 설치 선택 테스트다. 실제 설치를 연결한 재실행은
전부 통과했다. 이 중 크립 관찰 증거는 합성 자료다. 새 테스트는 domain55·포트9·controller10으로
총74개다. 이번 실행에서 소스/테스트 실패는 없었으며 초기 구현 뒤 부적격 증거의 public
coverage도 all-unknown으로 정규화하도록 보강하고 집중/분석/빌드를 재실행했다.

전체 format 차이는 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
해당 파일은 수정하지 않았다. 기준 SDK·전체 format·실제 게임 인수는 남는다.
기존 사용자 수정과 staged `local.properties`는 이번 커밋에 포함하지 않는다.
59skip을 통과로 계산하지 않으며 실제 수집·게임 관찰의 증거로 합성 테스트를 사용하지 않는다.

## 6. 완료·잔여

이번 완료 범위는 **초기 관찰 증거와 unknown 입력 검증**이다. 넓은 실제 collector 항목은
미완료로 유지한다. 다음은 검증된 collector transport/지원 버전·현재 실행 입력/설정의
fingerprint 결합·실제 초기화 시점 수집·명시적 사용자 실행·SC:R 비교 인수다.
live는 별도 freshness/observer 변경/끊김/재시작 정책이 필요하며 이번 증거를 재사용해
활성화하지 않는다. 자동 테스트/빌드 지시에 따라 실제 앱·게임·외부 에디터는 조작하지 않는다.
