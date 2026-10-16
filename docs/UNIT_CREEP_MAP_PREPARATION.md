# 크립 수집용 임시 맵 준비·재검증

2026-10-16. EP1/FR-218의 현재 입력 materialization 단위다.
[입력 결합](UNIT_CREEP_CAPTURE_INTAKE.md),
[ADR-0019](decisions/0019-owned-creep-capture-map-preparation.md)를 따른다.
실제 collector/IPC·게임 실행·setup 적용·관찰 권한 검증·UI/배치 차단은 포함하지 않는다.

## 1. 실행 계획·소스 분석

1. 기존 `MapArchiveGateway.writeTemporary/open`, resource reader, source fingerprint를 확인한다.
2. 의도한 입력 지문과 실제 임시 MPQ 지문을 구분하는 preparation 포트를 추가한다.
3. 원본 재검증 → 소유 임시 경로 생성 → 쓰기 → 재열기/bytes 비교 → 지문 재검증을 구현한다.
4. 변조·모호한 archive·취소·정리 실패를 합성 테스트로 검증한다.
5. 자체 제작 MPQ의 새 맵/기존 맵 왕복과 필수 게이트·Windows/native를 실행한다.
6. 결과·제한·실패 수정과 다음 collector 작업을 기록한다.

기존 저장 pipeline의 최종 경로 승격은 이 용도에 필요하지 않다. 기존 archive/fingerprint/
resource 포트를 재사용하고 별도의 임시 작업 공간 소유권만 추가했다. UI/Domain은 파일이나
프로세스에 의존하지 않으며 새 라이브러리·native wire 변경·게임 자산 fixture는 없다.
기존 resource reader는 `.wav` 경로만 읽으므로 임의 MPQ 엔트리 보존을 검증했다고 주장할 수 없다.
검증 불가능한 입력을 줄여 지원하며 추측·자동 이름 변경으로 통과시키지 않는다.

## 2. 구현 계약

| 항목 | 동작 |
| --- | --- |
| 포트 | `UnitCreepMapPreparationGateway.prepare/revalidate/cancel/release` |
| 구현 | `UnitCreepMapPreparer`, 기본 앱/collector에 자동 등록하지 않음 |
| 입력 | 설정으로 `UnitCreepCaptureInput` 재생성, 지문/CHK/setup/schema/base/리소스 exact 일치 검사 |
| 원본 | source path의 size/mtime/SHA-256을 loaded session과 처음/마지막에 비교 |
| baseline | 기존 archive를 재열어 최초 extracted CHK와 exact 비교, 현재 edited CHK와 구분 |
| 새 맵 | source 없는 신규 MPQ 생성, current CHK/pending resources만 사용 |
| 기존 맵 | source copy에 current CHK와 resource overlay, writer 자체 지원/충돌 정책 유지 |
| 출력 경로 | gateway가 생성한 전용 canonical 임시 디렉터리의 `input.scx`, source alias 거절 |
| CHK 검증 | 출력 재열기·raw bytes exact 일치·RawChkParser 성공, unknown/중복 섹션 그대로 |
| 리소스 검증 | 기대 경로 집합 exact 비교, 모든 수정 bytes 및 미수정 source bytes·metadata 길이 비교 |
| 지문 | 출력 검증 전후 fingerprint 동일 + 원본 마지막 재검증 후 receipt 발급 |
| receipt | exact request/issued receipt 객체·실제 출력 지문, 임의 복제 receipt 수용 안 함 |
| revalidate | 현재 소유 receipt와 original/output fingerprint를 다시 확인, 오류는 false |
| release | receipt 즉시 폐기, active 중 거절, 동시 release 배제, 실패는 소유권 보존 후 재시도 |
| 취소 | request 객체별 표시·현재 archive operation advisory cancel, 진행 중 I/O 완료 후 정리 |
| timeout | 기존 archive 요청마다 기본30초·양수 설정, 전체 작업 deadline은 아님 |
| 정리 | 실패 시 자동 cleanup, 실패하면 `cleanupPending=true`와 명시적 release 재시도 |
| 진단 | 기존 helper의 버전/원시 진단 전달, 예외 details 최대4,096 UTF-16 code units |

임시 파일은 사용 후 명시적으로 release해야 한다. cancel은 이미 발급한 receipt를 삭제하지 않는다.
성공 receipt를 가지고 있어도 파일이 잠기는 것은 아니므로 향후 collector는 실행 직전 revalidate하고
실제로 실행/관찰한 입력을 별도로 결합해야 한다. 이 단계로 capture 결과나 게임 신뢰를 얻지 않는다.
준비 대상은 요청 당시의 불변 snapshot이다. 현재 editor session/history 구독은 추가하지 않았으므로
향후 caller는 문서 revision/설치 변경·늦은 완료를 기존 controller의 요청 수명 검증과 결합해야 한다.

## 3. 지원표·안전 경계

- 완전한 이름 목록·locale0·유일한 scenario.chk와 canonical ASCII WAV 경로만 지원한다.
- 이름 불명/synthetic·case/slash 중복·비정규 WAV 경로·non-WAV 추가 자산·다른 locale은 거절한다.
- `(signature)`가 있는 signed archive는 거절한다. `(listfile)`/`(attributes)`는 helper 관리 메타데이터다.
  이 두 엔트리의 bytes 동일성은 보장하지 않으며 사용자 CHK/리소스 검증과 구분한다.
- WAV는 raw bytes 보존 대상이다. 이 작업은 PCM 가져오기/게임 재생 유효성 검증을 대체하지 않는다.
- 주입한 writer가 지원하는 overlay만 쓸 수 있다. 현재 bundled writer는 요청당 변경64개와
  유효 PCM WAV 신규 추가/기존 삭제만 지원하고 **기존 WAV 경로 교체를 거절**한다.
  input descriptor의512개/opaque bytes 계약이나 합성 gateway의 교체/빈 bytes 검증이
  bundled writer의 지원 확대를 뜻하지 않는다. writer 거절은 진단을 보존한 WRITE_FAILED다.
- CHK8MiB·개별 WAV16MiB·합계64MiB·최대512개, 설정으로 낮출 수 있다.
  기존 source inventory와 overlay 적용 뒤의 예상 집합을 쓰기 전에 검사하고 출력에도 적용한다.
  이 예산은 WAV uncompressed payload 기준이며 MPQ 총 파일 크기나 OS I/O 시간 상한이 아니다.
- 사용자 destination이나 입력 경로로 승격/덮어쓰기하지 않고 session·문서·Undo도 변경하지 않는다.
- local workspace gateway는 자신이 발급한 exact token만 정리한다. symlink/nonfile 유형·canonical
  경로 변경을 거절하고 known map file과 빈 디렉터리만 삭제한다. 재귀 삭제는 하지 않는다.
- 예상 밖 파일이 있으면 남기고 오류/소유권을 유지한다. 앱 강제 종료 뒤의 orphan 자동 청소는 없다.
- 파일 검사와 사용 사이의 외부 변경 경쟁을 완전히 제거하는 OS 파일 잠금/파일 ID sandbox는 아니다.
  동일 경로의 regular directory 재생성이나 OS 밖의 변경까지 token이 증명하지 않는다.
  신뢰된 gateway와 로컬 workspace를 전제로 하며 악성 프로세스 격리 도구로 사용하지 않는다.
- cancel은 helper가 협력하지 않아도 작업 Future가 끝나기 전에 파일을 지우지 않는다.
  helper timeout 외 fingerprint/resource/workspace port의 무한 대기를 강제로 중단하지 않는다.

오류는 `UNIT_CREEP_PREPARE_` 접두사의 `INPUT_INVALID`, `ACTIVE`, `SOURCE_CHANGED`,
`UNSUPPORTED_ARCHIVE`, `WORKSPACE_INVALID`, `OPEN_FAILED`, `WRITE_FAILED`, `VERIFY_FAILED`,
`OUTPUT_CHANGED`, `CANCELLED`, `FAILED`다. 실패 receipt는 발급하지 않는다.

## 4. 요구사항·시나리오 체크리스트

| 요구/상황 | 자동 확인 |
| --- | --- |
| 현재 CHK vs baseline·unknown/duplicate bytes | exact 임시 출력, 원본/session 불변 |
| 새 맵 | source null로 MPQ 생성, 사용자 원본 파일 생성 안 함 |
| 주입형 writer의 WAV overlay·교체/빈 bytes | 합성 verifier의 기대 경로 집합·edited/untouched bytes 일치 |
| 입력/CHK/setup/schema/base/resource 불일치 | 외부 작업 시작 전 거절 |
| 원본 선행/후행 변경·baseline 변경 | SOURCE_CHANGED, receipt 없음 |
| 출력 CHK/resource 변경·누락/추가·길이 불일치 | 검증 실패·소유 임시 파일만 정리 |
| 불완전 목록/이름/locale/alias/non-WAV/signature | source/output 양쪽 거절 |
| 개별/합계/병합 예산·개수 경계 | 쓰기 전 거절 + 출력 재검사 |
| open/write/path/fingerprint/read/create 예외 | 오류·진단 보존·실패 cleanup |
| 취소 중 쓰기·advisory cancel 예외·중복 prepare | I/O 완료 전 미삭제, 후속 취소 결과/정리 |
| cleanup 실패·재시도·동시 release | 소유권 유지·즉시 receipt 폐기·중복 정리 방지 |
| forged receipt·source/output 변경 | revalidate=false |
| foreign token/unknown file/경로 유형 대체 | unrelated 파일 유지·비재귀 cleanup·명시적 재시도 |
| 실제 native MPQ 새/기존 자체 제작 맵 | CHK·WAV 추가/삭제·미수정 bytes·source fingerprint·tamper/release 확인 |
| 실제 writer의 WAV 기존 경로 교체 거절 | WRITE_FAILED·원시 진단·원본 보존·임시 cleanup 확인 |
| 실제 SC:R 실행·초기 크립 관찰·setup 적용 | 이번 범위 아님·미실행 |

## 5. 실행·결과 분석

원시 로그는 ignored `.dart_tool/creep_prepare_*.log`에 남긴다.
실행 SDK Flutter3.47.5 stable/Dart3.13.4는 기준3.44.8/3.12와 다르다.

- 초기 analyze에서 새 production 코드의 multiline if 중괄호6건을 확인하고 수정했다.
- 첫 집중 실행은 존재하지 않는 `throwsFileSystemException` matcher로 파일 로딩에 실패했다.
  `throwsA(isA<FileSystemException>())`로 수정 후61개 통과·native 선택2개 skip을 확인했다.
- 테스트 fixture의 if 중괄호1건을 수정한 후 analyze는 No issues다.
- 실제 MPQ helper 지정 실행의 PowerShell exit0은 finally의 환경 변수 정리가 Flutter 실패를
  가린 것이었다. 초기 MPQ 통과 안내는 잘못되어 정정했다. saved fixture는 WRITE_FAILED였다.
  종료 코드를 별도로 보존하고 원시 진단을 출력해 ARCHIVE_RESOURCE_WRITE_FAILED를 확인했다.
  native 소스를 확인해 기존 WAV 경로 충돌을 의도적으로 거절하는 정책임을 확인했다.
  교체 지원을 추가하거나 보호를 완화하지 않고 실제 fixture를 추가/삭제 성공과 교체 거절로 분리했다.
- 수동 patch는 format 뒤 context 불일치로 적용 전에 거절된 뒤 정확한 범위로 재적용했다.
- 병합 리소스 개수512/513과 unchanged resource/source read 실패 회귀를 추가했다.
- 별도 Git index의 공유 문서 hunk 선택에서 생략된 개수를0으로 해석해 최초 apply가 거절됐다.
  기본 개수1로 파싱을 고친 뒤 이번15파일만 선택했다. 일반 index의 사용자 staged 파일은 그대로다.

| 최종 검증 | 결과 |
| --- | --- |
| 변경 Dart6파일 format | 0변경·exit0 |
| 전체 format | 492파일 중 기존3파일 차이·exit1 |
| `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 2,127통과·61skip·exit0 |
| 실제 MPQ 지정 집중 테스트 | 66통과·skip 없음·exit0 |
| Windows Debug build | 성공·exit0 |
| native CTest | 7/7통과·exit0 |
| 문서 로컬 링크 | 관련9문서345개 존재 확인 |
| `git diff --check` | 통과 |

새 테스트는 preparer57·local workspace7·native 선택2개다. 전체의61skip은 기존 선택59개와
새 native2개이며 별도 helper 지정 실행에서는 새2개도 통과했다. 초기 전체2,124통과는 추가
병합/원본 리소스 회귀3개 전의 결과다. native 원시 실패 로그는
`.dart_tool/creep_prepare_native_diagnostic.log`, 최종66통과는
`.dart_tool/creep_prepare_native_integration.log`로 구분한다.

전체 format 차이는 기존 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`뿐이며 수정하지 않았다.
최종 포맷 검사 직전 byte 비교 helper의 메서드 사이 공백1건을 formatter로 정리한 뒤 변경6파일은
통과했다. Windows 빌드의 기존 CascLib CMake deprecation 경고는 비치명적이었다.
사용자 지시에 따라 실제 앱·게임·외부 에디터는 조작하지 않았다. 기준 SDK 재검증·실제 관찰·
전체 format 기준선 정리는 남는다. 기존 사용자 변경과 staged `local.properties`는 보존한다.

## 6. 최적화·다음 작업

기존 read/write/helper/byte snapshot을 재사용하고 CHK는 한 번 encode한 입력과 비교한다.
리소스 이름 집합을 먼저 검증해 누락/추가나 초과 입력의 불필요한 bytes 읽기를 피한다.
각 WAV를 순차로 비교해 전체 원본·출력 WAV를 동시에 한 목록으로 적재하지 않는다.
불변 payload·취소/정리 barrier·ownership·추측 없는 path 계약에만 설명 주석을 남겼다.
최대 입력의 시간/메모리 실측 최적화 완료를 주장하지 않는다.

다음은 허용 가능한 실제 collector 경로·지원 build·신뢰/실행 승인과 transport의 설계/검증이다.
향후 실행 단계는 준비 receipt → 실행 직전 재검증 → 정확한 setup/초기 관찰 → 명시적 release를
연결해야 한다. SC:R 비교 인수 전에는 engine capture·live 지원이나 EP1 전체를 완료 표시하지 않는다.
