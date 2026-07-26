# ADR-0004: StormLib helper process 브리지

- Status: Accepted
- Date: 2026-07-26

## Context

`.scm`과 `.scx`는 MPQ 아카이브이며 MVP는 그 안의
`staredit\scenario.chk`를 읽고 새 아카이브에 다시 써야 한다. StormLib는 이
작업에 필요한 아카이브 열기, 파일 읽기, 추가, 제거 API를 제공하는 MIT
라이선스 C/C++ 라이브러리다.

Flutter/Dart에서 StormLib를 사용하는 방법은 크게 두 가지다.

1. `StormLib.dll` 또는 작은 C ABI 래퍼를 Dart FFI로 같은 프로세스에 로드한다.
2. StormLib를 링크한 전용 실행 파일을 별도 프로세스로 실행하고 제한된
   프로토콜로 통신한다.

맵은 신뢰할 수 없는 바이너리 입력이다. 네이티브 라이브러리의 접근 위반이나
메모리 손상은 Dart 예외로 변환된다는 보장이 없으므로, 같은 프로세스에
로드하면 에디터 전체와 저장 중인 문서 세션이 함께 종료될 수 있다. 반면
아카이브 열기와 저장은 사용자의 명시적인 저빈도 작업이므로 프로세스 시작
비용은 편집 중 매 프레임 발생하는 비용이 아니다.

## Decision

MVP의 `MapArchiveGateway`는 번들된 자체 제작
`map_archive_helper.exe`를 실행하는 helper process 어댑터로 구현한다.
Flutter 앱은 StormLib를 직접 FFI로 로드하지 않는다.

### 네이티브 구성과 배포

- helper는 C++로 작성하고 검토된 StormLib revision을 해시와 함께 고정한다.
- Windows 빌드는 StormLib의 `BUILD_SHARED_LIBS=OFF` 구성을 사용해 정적으로
  링크한다. 배포 디렉터리에서 이름만 같은 임의 DLL을 검색하지 않게 한다.
- 앱은 설치 패키지 안의 고정 위치에서 helper의 절대 경로를 구하고
  `runInShell: false`로 실행한다. 실행 파일 경로를 사용자 입력이나 `PATH`에서
  찾지 않는다.
- helper와 StormLib의 MIT 라이선스 고지를 배포물에 포함한다.
- 자동 다운로드나 자동 교체는 서명과 해시 검증 정책이 구현되기 전에는
  제공하지 않는다.

### 프로세스와 프로토콜 경계

- 한 요청마다 helper 프로세스 하나를 실행한다. 성공, 실패, 크래시, 취소 때
  네이티브 핸들과 임시 상태의 수명은 그 프로세스와 함께 끝난다.
- 요청은 버전이 있는 UTF-8 JSON 한 건을 줄바꿈으로 끝나는 단일 표준 입력
  레코드로 전달한다. helper는 EOF 대신 첫 줄을 경계로 즉시 처리하며, 사용자 맵
  경로를 명령줄 인자에 넣지 않는다.
- 표준 출력은 기계 판독 가능한 JSON 이벤트와 정확히 한 개의 최종 응답에만
  사용한다. 사람용 로그와 제한된 네이티브 상세 로그는 표준 오류로 분리한다.
- 앱은 표준 출력과 표준 오류를 동시에 끝까지 소비하고, 종료 코드와 최종
  응답을 모두 확인한 뒤에만 성공으로 판정한다.
- 모든 요청과 응답에는 `protocolVersion`, `requestId`, 작업 이름이 포함된다.
  최종 응답은 helper 버전, 고정된 StormLib revision, 처리 단계, 안정적인 오류
  코드, 필요하면 OS/StormLib 오류 번호를 포함한다.
- 지원하지 않는 프로토콜 버전, 알 수 없는 작업, 중복 최종 응답, 손상된 JSON,
  응답 없는 정상 종료는 모두 실패다.

MVP 프로토콜은 다음 최소 작업만 허용한다.

| 작업 | 역할 |
| --- | --- |
| `inspect` | 아카이브 형식과 제한된 항목 메타데이터를 진단한다. |
| `extractScenario` | 정확히 `staredit\scenario.chk`를 앱 소유 임시 파일로 추출한다. |
| `replaceScenario` | 입력 아카이브의 복사본인 임시 출력에 정확히 해당 항목만 교체한다. |

CHK 같은 바이너리 본문은 JSON이나 표준 출력의 Base64로 운반하지 않는다. 앱이
만든 요청별 임시 디렉터리 안의 정확한 파일 경로로 전달해 메모리 복사와 로그
노출을 줄인다.

### 데이터 소유권과 안전

- helper는 원본 아카이브를 제자리에서 수정하지 않는다.
  `replaceScenario`는 서로 다른 입력 경로와 임시 출력 경로를 요구하며 동일한
  실제 경로면 거부한다.
- MVP에서 접근 가능한 아카이브 항목 이름은 정확히
  `staredit\scenario.chk`로 제한한다. 항목 이름을 일반 파일 시스템 경로로
  결합하지 않는다.
- 앱이 입력 fingerprint 확인, 임시 디렉터리 수명, CHK 파싱과 검증, 임시 출력
  재열기, 최종 출력 승격을 소유한다. helper의 성공 응답만으로 사용자 출력
  파일을 승격하지 않는다.
- timeout이나 취소 시 앱은 helper 프로세스 트리를 종료하고 앱이 만든 정확한
  요청 임시 디렉터리만 정리한다.
- helper 크래시는 종료 코드와 제한된 진단으로 변환한다. 원본과 기존 출력은
  그대로 유지한다.
- 프로세스 환경과 작업 디렉터리는 필요한 값만 전달하며 입력, 임시, 출력은
  절대 경로로 정규화하고 허용된 관계를 검증한다.

## Comparison

| 기준 | 직접 FFI 또는 C ABI 래퍼 | helper process |
| --- | --- | --- |
| 네이티브 크래시 | Flutter 프로세스와 문서 세션까지 종료 가능 | 작업 프로세스 종료로 격리 |
| ABI와 메모리 | 핸들, 포인터, 버퍼, 호출 규약 수명을 Dart에서 관리 | C++ 내부에 제한, JSON 계약만 앱에 노출 |
| UI 응답성 | 호출 isolate와 blocking 작업 분리 설계 필요 | 비동기 프로세스 I/O와 진행 이벤트 사용 |
| 취소와 timeout | 안전한 호출 중단이 어렵고 라이브러리 상태가 남을 수 있음 | 프로세스 트리 종료 후 상태 폐기 가능 |
| 실패 테스트 | 접근 위반과 ABI 오류를 앱 안에서 재현하기 위험 | 가짜 helper로 크래시, 멈춤, 손상 응답 재현 가능 |
| 배포 | DLL 검색 경로와 ABI 호환성 관리 필요 | 실행 파일 하나와 버전 프로토콜 관리 |
| 성능 | 시작 비용이 없고 메모리 버퍼 직접 전달 가능 | 프로세스 시작과 임시 파일 I/O 비용 발생 |

아카이브 작업의 빈도와 데이터 안전 요구를 고려하면 MVP에서는 helper
process의 크래시 격리, 취소 가능성, 테스트 용이성이 FFI의 지연 시간 이점보다
중요하다.

## Alternatives

### StormLib DLL 직접 FFI

프로세스 시작 비용이 없지만 StormLib의 넓은 C API, 네이티브 핸들, 버퍼,
호출 규약과 ABI 변경을 Dart 코드에 직접 노출한다. 네이티브 크래시도 격리하지
못하므로 채택하지 않는다.

### 작은 C ABI 래퍼를 FFI로 로드

StormLib 전체 API를 숨기고 안정적인 함수 몇 개만 노출할 수 있어 직접 바인딩
보다는 낫다. 그러나 래퍼도 같은 프로세스에서 실행되므로 손상 입력으로 인한
네이티브 크래시와 안전한 취소 문제는 남는다. 성능 근거가 생기면 재검토할
수 있다.

### 순수 Dart MPQ 구현

네이티브 배포를 피할 수 있지만 MPQ 변형, 압축, 암호화와 호환성 범위를 새로
검증해야 한다. MVP의 무손실 저장 위험과 구현 범위가 커서 채택하지 않는다.

### 범용 외부 MPQ CLI

프로세스 격리는 얻지만 출력 형식, 오류 코드, 버전 호환성과 원본 보호 계약을
통제하기 어렵다. StormLib를 제한된 자체 프로토콜 뒤에 두는 helper가 테스트와
진단에 더 적합하다.

## Consequences

장점:

- 비정상 MPQ가 네이티브 크래시를 일으켜도 에디터 프로세스와 문서 세션을
  격리한다.
- Dart 코드는 StormLib ABI 대신 작은 버전 프로토콜에 의존한다.
- 실제 StormLib 없이 성공, 실패, timeout, 취소, 크래시, 손상 응답을
  결정적으로 테스트할 수 있다.
- helper 교체와 향후 다른 MPQ 구현 도입이 `MapArchiveGateway` 뒤에 머문다.

비용:

- C++ 실행 파일, 빌드 파이프라인, 배포 고지와 프로토콜 호환성을 관리해야 한다.
- 요청마다 프로세스 시작과 임시 파일 I/O가 발생한다.
- 파이프 교착을 막기 위해 stdout/stderr 동시 소비와 프로세스 트리 정리가
  필요하다.
- 앱 버전과 helper 프로토콜/바이너리 버전 불일치 진단이 필요하다.

## Validation

- Dart 통합 테스트에서 가짜 helper로 성공, 비정상 종료, timeout, 취소,
  손상 JSON, 프로토콜 불일치, 전체/불완전 아카이브 목록, 합성 이름,
  중복 경로, 암호화 항목과 stdout/stderr 대량 출력을 검증한다.
- 자체 제작 `.scx` 픽스처로 실제 helper가 `scenario.chk`를 추출하고 교체한
  임시 출력을 다시 여는 스모크 테스트를 추가한다. 열기 결과는 MPQ 버전과
  전체 엔트리 목록의 기본 메타데이터도 교차 검증한다.
- 저장 테스트는 작업 전후 원본 해시가 같고, 검증 전에는 최종 출력이
  승격되지 않으며, 실패 시 기존 출력이 유지됨을 확인한다.
- 성능 계측에서 프로세스 시작과 임시 파일 I/O가 실제 열기/저장 흐름의
  병목으로 확인될 때만 작은 C ABI FFI 래퍼를 새 ADR로 재검토한다.

## References

- [StormLib README](https://github.com/ladislav-zezula/StormLib/blob/master/README.md)
- [StormLib API header](https://github.com/ladislav-zezula/StormLib/blob/c91595a1a1b7b515567bd62a60af066914a29a6a/src/StormLib.h)
- [StormLib MIT license](https://github.com/ladislav-zezula/StormLib/blob/master/LICENSE)
- [Dart DynamicLibrary API](https://api.dart.dev/dart-ffi/DynamicLibrary-class.html)
- [Dart lookupFunction API](https://api.dart.dev/dart-ffi/DynamicLibraryExtension/lookupFunction.html)
- [Dart Process.start API](https://api.dart.dev/dart-io/Process/start.html)
- [Flutter Windows release build](https://docs.flutter.dev/platform-integration/windows/building)
