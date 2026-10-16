# 크립 수집 입력 결합·검증 어댑터

2026-10-16. EP1/FR-218의 **의도한 실행 입력 지문과 typed 수집 결과 검증** 단위다.
[ADR-0018](decisions/0018-creep-capture-input-binding.md),
[관찰 증거](UNIT_CREEP_OBSERVATION.md), [앱 조회](UNIT_CREEP_INSPECTION.md)를 따른다.
실제 engine collector/IPC·게임 자동 실행/주입·SC:R 호환 인수·UI/배치 차단은 구현하지 않았다.

후속 [임시 맵 준비·재검증](UNIT_CREEP_MAP_PREPARATION.md)에서 원본 재검증과 temporary
materialization을 별도 구현했다. 아래 날짜가 있는 실행 기록의 다음 작업은 당시 기준이며,
입력 adapter 자체가 실제 파일을 읽거나 게임을 실행하지 않는 경계는 유지한다.

## 1. 실행 계획·소스 분석

1. 기존 raw CHK encoder·immutable pending resources·source fingerprint와 상태 포트를 확인한다.
2. 원본 파일뿐 아니라 현재 CHK·pending resource overlay·setup·자료 출처를 입력으로 결합한다.
3. 명시적 capture 포트와 설정된 버전/대상 게임 세션만 수용하는 adapter를 구현한다.
4. 입력 불일치·부분 관찰·오류·취소/timeout/재시도와 기존 controller를 테스트한다.
5. 필수 게이트·Windows/native·로컬 설치 회귀와 한계·실패를 기록한다.

`OpenedMapSession.sourceFingerprint`는 원본 archive 지문이며 미저장 CHK/리소스 편집의
지문이 아니다. `RawChkEncoder`는 섹션 순서·중복·unknown·원시 문자열 bytes를 보존한다.
기존 `PendingMapResources`도 nested bytes를 불변으로 보관하므로 새 가변 복사 모델이나
UI/Domain I/O를 도입할 필요가 없다. 수집 포트만 새로 정의하고 infrastructure에서 결합한다.

## 2. 구현·신뢰 계약

| 항목 | 계약 |
| --- | --- |
| 수집 포트 | `UnitCreepCaptureGateway.capture(request)`와 request 객체별 `cancel(request)` |
| 검증 adapter | `ValidatedUnitCreepStateGateway`, 기존 `UnitCreepStateGateway` 구현, bootstrap 등록 없음 |
| 명시적 설정 | providerId/collectorVersion/gameSessionId·1~32개 exact game version 허용 목록 |
| setup | schema 이름과 1~65,536 opaque bytes의 불변 복사. JSON 의미/게임 설정 유효성을 추측하지 않음 |
| 현재 CHK | 원본 extracted bytes가 아니라 현재 raw document를 encode·SHA-256, 순서/중복/unknown 그대로 |
| base | 기존 저장 맵은 source archive SHA/size, 새 맵은 null. 실제 파일을 재읽거나 최신성 검증하지 않음 |
| resource | 현재 지원 pending `.wav` path 규칙 재사용. path를 변경하지 않고 case alias/부적합 경로 거절 |
| resource 내용 | 삭제 null·빈 bytes·없음 구분, sorted raw name+길이/hash. PCM 형식·game playback 검증은 아님 |
| source | product/build/helper/CascLib tuple·scenario locale 포함. 설치 경로를 실제 game version으로 간주하지 않음 |
| 입력 revision | `creep-input-v1:` canonical JSON SHA. path/mtime/operation ID/documentRevision 제외 |
| setup revision | `creep-setup-v1:` schema+exact bytes hash |
| payload | encoded CHK/setup·pending resources 모두 방어 복사 또는 기존 immutable snapshot 공유 |
| response 결합 | exact capture request 객체·capturedInputRevision·provider·collector/game version·game session·setup 모두 일치 |
| 관찰 검증 | 기존 initial phase/frame·권한/관찰 mask·current state request/DIM 계약 재사용 |
| state revision | `captured-creep-v1:` 입력+report revision·관찰 metadata/mask·보고된 타일값 hash |
| logs | stdout/stderr/exitCode 보존, 각 로그 최대65,536 UTF-16 code units. 초과는 잘라 기록하고 결과 거절 |
| 오류 | 입력/중복/response/transport/exception/output/timeout/cancel의 `UNIT_CREEP_CAPTURE_*` 코드 |
| timeout/cancel | 기본30초·양수 설정, advisory cancel 예외 수용. request identity로 늦은 응답과 같은 ID 재시도 분리 |
| 기본 동작 | capture 구현/지원 game build를 동봉하지 않음. live/자동 실행/추론 fallback 없음 |

입력 revision은 **base archive+편집 overlay의 의도**다. 실제 prepared MPQ hash나 engine
메모리를 측정한 hash가 아니다. base 파일이 외부에서 바뀌었는지는 이 단계에서 확인하지 않는다.
실제 collector가 base 재검증·안전한 temporary export/재열기·정확한 setup 적용·관찰 phase/권한과
지원 게임 build를 증명해야 한다. echo·문자열 allowlist를 채웠다는 이유로 수집기 자체를 신뢰하지 않는다.
허용 목록은 신뢰할 수 있는 caller의 설정이며, 현재 fixture의 유일한 game version은 합성 이름이다.
로그 제한은 typed 결과를 받은 뒤의 제한이다. 실제 IPC 구현은 별도의 streaming capture
상한을 적용해야 하며 이 adapter만으로 외부 프로세스의 메모리 사용을 제한한다고 주장하지 않는다.

## 3. 입력 예산·최적화·주석

- CHK 최대8MiB, resource 단일16MiB/합계64MiB·최대512개, setup64KiB.
- CHK/resource 예산은 더 낮출 수 있으나 위 hard ceiling을 넘길 수 없다. 게임 형식 상한이 아니다.
- CHK는 declared length 합을 먼저 검사한 뒤 한 번 encode/hash한다. 리소스는 정렬 후 한 번 hash한다.
- 전달 CHK/setup은 기존 저장소 패턴인 `Uint8List` 방어 복사와 unmodifiable view를 사용한다.
  큰 CHK를 일반 정수 List로 다시 보관하지 않으며 반환 버퍼로 원본을 바꿀 수 없다.
- metadata·hash·조건 검사에는 기존 crypto/JSON/encoder/path 검증을 사용하고 새 의존성을 추가하지 않았다.
- fingerprint는 명시적 read에서만 생성한다. hover/preview/Apply에서 파일/프로세스 작업을 시작하지 않는다.
- footprint 조회는 기존 정규화된 packet을 사용하며 추가 fingerprint 재계산은 없다.

input prepare는 동기 bounded 작업이며 전체 맵 FPS/최대 예산 지연 시간을 측정한 것은 아니다.
payload 불변·삭제 구분·path 비정규화·취소 소유권·base와 prepared MPQ 구분에 주석을 추가했다.
대형 테스트 fixture 대신 낮춘 예산의 정확한 경계로 동일한 거절 경로를 검사한다.

## 4. 요구사항·테스트 체크리스트

| 시나리오 | 자동 확인 |
| --- | --- |
| 현재 CHK vs 원본 extracted CHK·duplicate/unknown bytes | 현재 bytes/hash 일치·원본 불변 |
| 원본 SHA/size·새 맵·source tuple·setup bytes/schema | 관련 값 변경은 입력 revision 변경 |
| 파일/설치 이동·mtime/operation/document revision | content revision 동일, lifecycle은 별도 |
| resource 삽입 순서·변경·삭제/empty/없음 | canonical 순서·구분·immutable nested bytes |
| 기존 path 규칙·case alias·불량 byte·리소스 개수 | 추측/정규화 없이 입력 거절 |
| CHK/단일/합계 resource 예산·설정 hard ceiling | inclusive 경계·초과 거절 |
| 명시적 버전 목록/설정 형식·DIM/요청 source | 빈/초과/불완전 정보 거절 |
| request/input/provider/report/collector/game/session/setup 불일치 | 실패·재시도 회복 |
| 관찰 phase/frame/권한/크기·unknown | 기존 snapshot 검증·미관찰 present/absent는 unknown |
| sync/async 예외·오류/exit·큰 로그 | bounded 로그·안정적 오류·재시도 |
| 중복 ID·cancel 실패·timeout·늦은 reply | 요청 객체별 분리·같은 ID 재시도 보존 |
| controller 정상/입력/setup 불일치 | 최종 footprint·재시도·CHK/session/Undo 무변경 |
| 실제 process/engine 수집·prepared MPQ/SC:R 비교 | 미구현·미실행, 별도 인수 |

## 5. 실행·결과 분석

ignored `.dart_tool/creep_capture_*.log`에 원시 실행 로그를 남긴다.
최종 실행 로그를 해당 이름에 남기고, 중간 실패는 아래에 따로 기록한다.
실행 SDK Flutter3.47.5 stable/Dart3.13.4는 기준3.44.8/3.12와 다르다.

- 초기 집중48개 통과 후 설정/예산·controller 회귀를 확장해384개를 통과했다.
- 초기 analyze는 합성 fixture의 if 중괄호 규칙1건을 검출했다. 수정 뒤 analyze를 통과했다.
- CTest 첫 직접 호출은 VS 경로의 `CommonExtensions`를 `Extensions`로 잘못 적어 실패했다.
  정확한 설치 경로로 재실행해7종을 통과했다. 테스트 자체의 실패가 아니다.
- 버퍼 최적화 중 import가 파일 끝에 삽입되어 format parse와 테스트3파일 loading이 실패했다.
  `Directives must appear before any declarations`를 확인해 import 위치를 수정했다.
- generic byte list의 범위 밖 값이 u8로 잘리지 않도록 검증을 추가했다. 최종 집중385개 통과,
  10개 로컬 선택 테스트 skip을 확인했고 최종 analyze/전체 테스트/Windows 빌드를 재실행했다.
- 테스트 수정 patch context 불일치는 적용 전에 거절되어 정확한 범위로 재적용했다.

전체 format은486파일 중 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`의 차이로 exit1이다.
이3파일은 수정하지 않았다. 최종 게이트 결과는 다음과 같다.

| 실행 | 결과 |
| --- | --- |
| 최종 집중 input/adapter/controller | 385통과·10skip·exit0 |
| 최종 `flutter analyze` | No issues·exit0 |
| 최종 전체 `flutter test` | 2,063통과·59skip·exit0, 새70개 포함 |
| 로컬 설치 연결 재실행 | 395통과·skip 없음·exit0 |
| 변경 Dart7파일 format | 0변경·exit0 |
| 전체 format | 486파일 중 기존3파일 차이·exit1 |
| 최종 Windows Debug build | 성공·exit0, 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| 문서 링크 검사 | 관련6문서의 로컬 링크180개 존재 확인 |
| `git diff --check` | 통과 |

새 테스트는 input41·adapter26·controller3개다. 반복 전체 실행의 첫2,062통과는 버퍼
최적화/byte 회귀 추가 전의 기록이며 최종 결과와 구분한다. 집중10skip은 기존 로컬 설치
선택 테스트다. 원본 CHK/unknown 섹션·session/Undo 무변경과 입력 payload 불변을 확인했다.
로컬 재실행에서도 새 capture 보고는 합성 자료다. 실제 DAT/graphics 회귀와 함께 실행했지만
실제 크립 수집·게임 권한 검증으로 계산하지 않는다. 사용자 지시에 따라 앱·게임·외부 에디터는
조작하지 않았고 기존 사용자 변경과 staged `local.properties`도 보존했다.
실제 engine이나 게임 자산·맵 파일을 fixture에 추가하지 않았다. 기준 SDK·기존 format 차이·
실제 게임 인수는 남는다. 10skip과 전체 선택 skip을 통과로 계산하지 않는다.

## 6. 완료·다음

완료 대상은 현재 입력 지문·명시적 typed capture 포트·검증/취소 adapter다.
실제 collector/IPC·지원 build 검증·최신 원본 재검증·temporary map export/실행·게임 인수는
계속 미완료다. 다음은 실제 수집 경로 선택과 신뢰/실행 승인, 입력 materialization 검증을
포트 뒤에서 연결하는 단위다. 기본 앱에는 임의 collector를 등록하지 않는다.
