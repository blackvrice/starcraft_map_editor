# 개발 계획

## 사용 방법

- 별도 우선순위 지시가 없으면 위에서 아래로 첫 번째 미완료 체크박스를 진행한다.
- 각 단계는 코드, 테스트, 문서, 실제 실행 검증이 모두 끝나야 완료한다.
- 완료된 항목에는 관련 커밋 또는 검증 메모를 덧붙인다.
- 예상과 실제 포맷 동작이 다르면 구현을 억지로 맞추지 말고 문서와 계획을 수정한다.

## 현재 상태

| 단계 | 상태 | 결과 |
| --- | --- | --- |
| M0. 제품·기술 기준선 | 완료 | 문서, MIT, Flutter 3.44.8, Windows CI |
| M1. 데스크톱 기반 | 완료 | 계층 구조, 에디터 셸, 최근 맵, 작업 진행 |
| M2. CHK 무손실 코어 | 완료 | raw 왕복, 메타데이터·문자열 typed view, 구조 진단 |
| M3. 맵 아카이브 입출력 | 완료 | Open Map·검증형 Save As·fingerprint·복구 백업·자체 제작 SCX |
| M4. EUD 수직 기능 | 완료 | 실제 euddraft 빌드·검증·안전한 출력 승격 |
| M5. 맵 캔버스와 지형 | 완료 | 지형 typed view·탐색·실제 타일 렌더·편집·성능 계측 |
| M6. 객체와 로케이션 | 완료 | 객체·로케이션 편집·의미 참조 진단·Save As 왕복 |
| M6.1. 실제 객체 그래픽 | 완료 | CascLib 객체 자산·스프라이트 렌더·fallback·성능 기준 |
| M6.2. 시각적 배치 선택 팝업 | 대기 | Tile·Doodad·Unit·Sprite 카탈로그 선택과 배치 |
| M7. 일반 트리거 | 대기 | M6.2 완료 후 트리거 편집 |
| M8. 안정화와 배포 | 대기 | 검증된 Windows 릴리스 |

---

## M0. 제품·기술 기준선

목표: 구현 중 판단 기준으로 사용할 문서와 저장소 규칙을 확정한다.

- [x] 제품 비전, 대상 사용자, 범위 작성
- [x] 계층과 데이터 흐름 설계
- [x] 파일 무손실 정책 정의
- [x] EUD 빌드 보안 경계 정의
- [x] UX 기준과 핵심 흐름 작성
- [x] 테스트 전략과 완료 정의 작성
- [x] 단계별 개발 계획 작성
- [x] 프로젝트 오픈 소스 라이선스 선택 및 `LICENSE` 추가
- [x] Flutter SDK 기준 버전을 stable 또는 명시된 revision으로 고정
- [x] Windows CI 워크플로 추가

완료 조건:

- 신규 개발자가 문서만으로 첫 작업과 검증 명령을 찾을 수 있다.
- 외부 라이브러리 포함과 프로젝트 배포에 적용할 라이선스가 명확하다.
- CI에서 최소 `flutter analyze`와 `flutter test`가 실행된다.

## M1. 데스크톱 기반

목표: 카운터 템플릿을 실제 에디터 애플리케이션 셸과 테스트 가능한 계층으로 교체한다.

- [x] `lib`를 app/domain/application/infrastructure/presentation으로 분리
- [x] Windows 전용 지원 메시지와 앱 메타데이터 정리
- [x] 메뉴, 도구 모음, 좌/중앙/우/하단 패널로 구성된 에디터 셸 구현
- [x] 빈 문서 시작 화면 구현
- [x] 최근 프로젝트 목록과 다시 열기 상태 구현
- [x] 공통 `Diagnostic` 모델 구현
- [x] 공통 작업 진행 모델 구현
- [x] 설정 저장 포트와 메모리 구현 추가
- [x] 기본 키보드 명령과 Command 라우팅 구현
- [x] 기존 카운터 테스트를 에디터 셸 위젯 테스트로 교체

완료 조건:

- Windows 앱이 에디터 셸로 실행된다.
- 외부 파일이나 euddraft 없이 모든 자동화 테스트가 통과한다.
- UI에서 실행한 샘플 명령이 Application 계층을 통과하는 것이 테스트된다.

## M2. CHK 무손실 코어

목표: raw `scenario.chk`를 손실 없이 파싱하고 다시 쓸 수 있는 독립적인 Dart 코어를 만든다.

- [x] 4바이트 섹션 이름과 little-endian 길이 헤더 파서 구현
- [x] 섹션 순서, 중복, 원시 페이로드, 소스 오프셋 보존
- [x] 경계 초과, 잘린 헤더, 비정상 길이 진단 구현
- [x] 수정되지 않은 문서의 byte-exact round-trip 구현
- [x] `VER`, `TYPE`, `IVER`, `DIM`, `ERA` 최소 typed view 구현
- [x] `SPRP`, `STR`/`STRx` 문자열 참조를 raw-first 방식으로 구현
- [x] 직접 제작한 최소 CHK 픽스처와 손상 픽스처 추가
- [x] 속성 기반 또는 fuzz 테스트 도입 검토

검증 메모:

- `test/fixtures/chk/*.chk.hex`는 저장소에서 직접 작성한 검토 가능한 바이트 스트림이다.
- `test/domain/chk/raw_chk_parser_test.dart`에서 정상/중복/미지원/손상 입력과
  200개 결정적 생성 케이스의 byte-exact 왕복을 검증한다.
- `test/domain/chk/chk_metadata_views_test.dart`에서 5개 메타데이터 섹션의
  little-endian 읽기·수정, 중복 보존, 미지 값 보존, 고정 크기 진단을 검증한다.
- `test/domain/chk/chk_string_views_test.dart`에서 `SPRP`, `STR `, `STRx`의
  참조 해석, 원시 바이트, 공유 offset, append-only 수정, 손상 경계를 검증한다.
- 전용 fuzz 러너와 장시간 코퍼스 실행은 파서 입력 면적이 넓어질 때 다시 검토한다.

완료 조건:

- 정상 픽스처가 바이트 단위로 동일하게 왕복된다.
- 알 수 없는 섹션과 중복 섹션이 유지된다.
- 손상 픽스처가 크래시 없이 위치가 포함된 진단을 반환한다.
- Domain 계층이 Flutter나 파일 시스템에 의존하지 않는다.

## M3. 맵 아카이브 입출력

목표: 보호되지 않은 `.scm/.scx`에서 CHK를 추출하고, 새 맵으로 안전하게 저장한다.

- [x] StormLib 브리지 방식 FFI/helper process 비교와 ADR 작성
- [x] `MapArchiveGateway` 포트 구현
- [x] `staredit\scenario.chk` 탐색과 추출
- [x] 아카이브 목록과 기본 메타데이터 진단
- [x] Open Map UI와 최근 파일 연결
- [x] Save As 임시 출력 → 재열기 → 검증 → 승격 흐름 구현
- [x] 입력 파일 fingerprint와 외부 변경 감지
- [x] 원본 덮어쓰기 방지와 백업 정책 테스트
- [x] 재배포 가능한 자체 제작 `.scx` 통합 픽스처 추가

검증 메모:

- [ADR-0004](decisions/0004-stormlib-helper-process.md)에서 직접 FFI와 작은
  C ABI 래퍼, helper process를 크래시 격리, 취소, 테스트, 배포, 성능 기준으로
  비교했다.
- MVP는 고정된 StormLib를 정적으로 링크한 번들
  `map_archive_helper.exe`를 요청마다 실행한다. 앱은 구조화 프로토콜, 임시
  파일, fingerprint와 재열기 검증을 소유하며 helper는 원본을 수정하거나
  최종 출력을 승격하지 않는다.
- `lib/application/ports/map_archive_gateway.dart`는 open, 임시 아카이브 쓰기,
  operation ID 기반 취소를 정의한다. 요청/결과 값은 경로와 timeout, 읽기 전용
  CHK 바이트, 아카이브 메타데이터, 성공/실패 진단 불변식을 검증하며 helper나
  StormLib 타입을 노출하지 않는다.
- `test/application/map_archive_gateway_test.dart`는 가짜 어댑터 대입과 함께
  계약의 불변성, 경계값, 진단 규칙을 검증한다.
- `native/map_archive_helper`는 pinned StormLib를 정적으로 링크한다. 열기는
  원본을 read-only로 열어 정확히 `staredit\scenario.chk`만 추출한다. 저장은
  원본을 새 임시 MPQ로 복사한 뒤 복사본의 해당 항목만 교체한다. 고정 JSON
  프로토콜과 입력/출력/CHK 크기 상한, 기존 출력 거부를 적용한다.
- `ProcessMapArchiveGateway`는 절대 경로 helper를 셸 없이 실행하고 프로토콜,
  버전, 종료 코드, 메타데이터와 실제 파일 크기를 검증한다. stdout/stderr를
  동시에 소비하며 timeout, operation ID 취소와 정확한 임시 디렉터리 정리를
  제공한다.
- helper `0.4.0`과 Dart 어댑터는 최대 1,024개의 아카이브 엔트리를 열거하고
  MPQ format version, 전체/열거 항목 수, 항목별 압축·비압축 크기, flags,
  locale과 합성 이름 여부를 반환한다. 불완전 목록, 합성 이름, 대소문자를
  무시한 중복 경로, 예상 밖 format version은 비차단 경고로, 암호화 항목은
  내부 MPQ 관리 파일을 제외하고 정보 진단으로 노출한다.
- eudplib 출력의 기본 locale `scenario.chk`가 1,200바이트 이하 placeholder면
  helper가 locale `0x0409`를 재시도한다. 선택한 locale과 목록 메타데이터를
  Dart 어댑터가 교차 검증하며 locale별 같은 경로 항목은 보존한다.
- native CTest는 자체 생성 MPQ의 한글 경로 추출, 원본 byte-exact 불변,
  완전한 내부 listfile과 listfile 없는 합성 이름, CHK 누락과 출력 충돌,
  복사본 CHK 교체와 비대상 엔트리 보존을 검증한다. Dart 프로세스 테스트와
  패키지의 실제 helper end-to-end 스모크 테스트가 전체 목록, 임시 쓰기와
  재열기, 진단, 성공/오류/손상 응답/대량 출력/timeout/취소를 검증한다.
- `test/fixtures/maps/generated/minimal-self-authored.scx`는 프로젝트가 직접
  작성한 `metadata.chk.hex`와 네 개의 테스트 바이트만 담은 460바이트 MPQ다.
  인접 README와 manifest가 생성 방법, MIT 라이선스, pinned StormLib revision,
  아카이브·CHK SHA-256과 예상 엔트리를 기록한다. 일반 테스트는 manifest를
  검증하고 Windows CI의 실제 번들 helper 스모크 테스트는 이 고정 입력을 열어
  CHK 교체·재열기와 원본 byte-exact 불변을 확인한다.
- `OpenMapController`는 Windows 파일 선택 또는 최근 맵 경로를 받아
  `MapArchiveGateway` 추출, raw CHK 파싱, typed 메타데이터 검증, 최근 파일
  기록을 한 유스케이스로 조립한다. 성공한 맵만 최근 목록에 기록하며 raw CHK
  구조 오류는 열기를 실패시키고 typed view 오류는 제한된 읽기 전용 세션으로
  표시한다. 파일 크기, UTC 수정 시각, SHA-256으로 만든 fingerprint를 열기
  전후에 비교하며 달라졌거나 다시 읽을 수 없으면 세션을 채택하지 않는다.
- `SaveMapController`는 Windows Save As 경로를 선택하고 최종 경로와 같은
  디렉터리에 앱 소유 임시 작업 공간을 만든다. raw CHK 인코딩, helper 임시
  아카이브 쓰기, 임시 맵 재열기, CHK byte-exact 비교와 파싱이 모두 성공한
  뒤에만 rename으로 최종 출력에 승격하고 저장된 경로를 현재 세션으로 채택한다.
  원본과 같은 실제 경로는 교체 확인 여부와 무관하게 거부한다. 다른 기존 출력은
  Windows Save As 대화상자에서 명시적으로 교체를 확인한 경우에만 허용한다.
  저장 시작 시 열린 세션과 기존 출력의 fingerprint를 기록하고, 검증된 임시
  출력 승격 직전에 둘을 다시 확인한다. 변경이나 삭제가 감지되면 임시 출력은
  승격하지 않으며 성공으로 표시하지 않는다.
- `LocalMapSaveFileGateway`는 기존 출력을 같은 디렉터리의 고유한 `.bak`
  경로로 이동한 뒤 검증된 임시 파일을 승격한다. 승격 실패 시 백업을 원래
  경로로 자동 복원하고, 복원도 실패하면 작업 공간 정리와 별개로 백업을 보존해
  정확한 복구 경로를 진단한다. 성공한 교체의 백업은 사용자가 결과를 확인할
  때까지 자동 삭제하지 않는다.
- `LocalMapFileFingerprintGateway`는 해시 계산 전후 파일 종류, 크기와 수정
  시각이 안정적인지 확인하고 SHA-256을 스트리밍 계산한다. 같은 크기와 수정
  시각을 유지한 내용 변경도 해시로 구분한다.
- Windows runner의 기본 파일 대화상자는 `.scm`/`.scx` 필터를 적용하고
  기존 출력에는 `OFN_OVERWRITEPROMPT` 확인을 적용한 뒤 method channel 뒤의
  `MapFilePicker` 포트로 노출된다. 위젯은 파일 시스템이나 네이티브 API를 직접
  호출하지 않는다.
- 에디터 셸은 열린 파일 경로, MPQ/CHK 크기, 아카이브 항목 수, CHK 섹션 수,
  맵 크기, 버전, 타입, 타일셋과 구조화 진단을 표시한다. 최근 맵을 누르면
  파일 선택 대화상자 없이 같은 실제 열기 흐름을 다시 실행한다.

완료 조건:

- 테스트 맵을 열고 CHK 요약을 표시한다.
- 변경 없이 Save As한 결과를 다시 열 수 있다.
- 원본 해시가 저장 전후 동일하다.
- 실패한 출력이 성공 결과로 표시되지 않는다.

## M4. EUD 수직 기능

목표: 기준 맵과 epScript를 선택해 별도 EUD 맵을 빌드하는 첫 사용자 가치 흐름을 완성한다.

- [x] euddraft 설치 경로와 버전 검사 구현
- [x] `EudCompilerGateway` 외부 프로세스 어댑터 구현
- [x] 기준 맵, 소스 경로, 출력 경로를 가진 빌드 설정 모델 구현
- [x] 최소 epScript 코드 편집기와 변경 상태 구현
- [x] Build/Cancel 명령과 출력 패널 구현
- [x] stdout/stderr, 종료 코드, 도구 버전 기록
- [x] 가능한 오류의 파일/행/열 진단 변환
- [x] 임시 출력과 성공 출력 승격 구현
- [x] 가짜 컴파일러를 이용한 성공/실패/취소 통합 테스트
- [x] 실제 euddraft와 자체 제작 테스트 맵 빌드 스모크 테스트

검증 메모:

- `EudToolInspector` 포트는 프로젝트 프로필, 사용자 설정, 번들 후보의 우선순위,
  4성분 버전, 성공/실패 진단 불변식을 Application 계층에 정의한다.
- `LocalEudToolInspector`는 절대 경로 디렉터리 또는 `euddraft.exe`를 받아
  실행 없이 `VERSION`, Python 런타임, eudplib/epScript companion과
  라이선스 파일을 확인한다. 현재 exact allowlist는 공식 최신 릴리스로 실제
  ZIP 레이아웃을 검증한 `0.10.2.5`다.
- 단위·파일 시스템 테스트는 경로 우선순위, 우회 금지, 누락 경로/실행 파일,
  손상·미지원 버전, companion 누락과 비-Windows 진단을 검증한다.
  `EUDDRAFT_TEST_INSTALLATION`을 지정하면 추출한 공식 릴리스도 같은 검사로
  스모크 테스트한다.
- `EudCompilerGateway`는 검사된 도구와 절대 `.eds` 설정, timeout, 명시적
  환경 override를 받고 시작·stdout·stderr·실패·취소·성공 이벤트를
  스트리밍한다. `ProcessEudCompilerGateway`는 셸 없이 한 번만 실행하고
  stdin을 닫으며 안전 환경 allowlist와 스트림별 1 MiB 상한을 적용한다.
- Windows PowerShell 가짜 컴파일러 테스트는 공백/한글 경로, UTF-8 양쪽
  로그, 비정상 종료, timeout, 사용자 취소, 중복 ID 격리, 출력 상한,
  환경 변수 최소 상속, 잘못된 경로와 시작 실패를 실제 프로세스로 검증한다.
  이 프로세스 포트의 성공은 종료 코드 0까지이며 전체 빌드 성공은
  `SafeEudBuildPipeline`이 출력 검증·승격을 마친 뒤에만 게시한다.
- `EudBuildConfiguration`은 `scr-euddraft` 프로필과 기준 `.scm/.scx`, 소스
  루트 내부 진입 `.eps`, 기준 및 소스 트리와 분리된 출력 `.scx`, 선택적 도구
  경로와 불변 옵션·환경 override를 Application 계층에 고정한다.
- 단위 테스트는 drive/UNC 절대 경로, 확장자, 기준/출력 충돌, 소스 포함 관계,
  위험한 Windows 경로 세그먼트, 옵션·환경 유효성, 방어적 복사와 도구
  검사·컴파일러 요청 변환을 검증한다. `LocalEudBuildFileGateway`는 파일
  존재·종류와 canonical 포함 관계를 다시 확인하고 일회성 `.eds`를 만든다.
- `EudSourceDocument`와 `EudSourceController`는 단일 epScript 문서의 immutable
  snapshot, 저장 기준선, revision과 dirty 계산을 Application 계층에 둔다.
  dirty 문서는 명시적 discard 없이는 교체하거나 닫을 수 없다.
- 셸은 `New epScript` 명령, 실제 다중행 입력, 줄 번호, 커서 위치, 맵/코드 탭,
  Project/Inspector와 상태 표시줄의 Clean/Modified 표시를 제공한다. 위젯
  테스트는 입력 후 dirty 전환과 탭 왕복 시 텍스트 보존을 검증한다. 실제
  `.eps` 열기·저장과 외부 변경 감지는 후속 파일 I/O 작업이다.
- `EudBuildController`는 준비된 `EudBuildPlan`을
  `ready/running/cancelling/finalizing`과 세 종료 상태로 조립하고 같은
  operation 진행 모델에 컴파일·검증 상태를 게시한다. 중복 시작을 막고 활성
  build ID만 취소하며, 이벤트 스트림 오류·결과 없는 종료·ID 불일치를
  구조화 실패로 바꾼다.
- 셸은 EUD Build/Cancel 명령과 `Ctrl+B`/`Ctrl+Shift+B`를 연결하고 실행 중
  도구 모음 버튼을 Cancel로 전환한다. Problems/Output/Build Log 탭은 각각
  구조화 진단, 일반 작업 진행, 현재 빌드의 원시 이벤트를 표시한다. 빌드
  시작 시 Build Log를 자동 선택한다.
- 단위·위젯 테스트는 설정 전 Build 비활성, 성공 stdout/stderr 표시, 실패
  진단, 취소 요청과 버튼 복귀, finalizing 전환, 결과 없는 스트림의 안전한
  실패를 검증한다. 부트스트랩은 안전 파이프라인을 실제 포트에 연결하지만
  프로젝트 설정 UI가 `EudBuildPlan`을 준비하기 전에는 임의 경로로
  euddraft를 실행하지 않는다.
- `SafeEudBuildPipeline`은 빌드 직전 도구를 다시 검사하고 기준 맵·진입
  epScript·기존 출력 fingerprint를 기록한 뒤, 최종 출력과 같은 디렉터리의
  앱 소유 작업 공간에 UTF-8 `.eds`와 임시 `.scx` 경로를 만든다. 공식
  `[main] input/output`과 절대 epScript 플러그인 섹션만 직렬화하며
  `input`/`output`을 사용자 옵션으로 덮어쓸 수 없다.
- 종료 코드 0 뒤에도 임시 파일 존재·비어 있지 않음, MPQ 재열기,
  `scenario.chk` raw 파싱, `VER`/`DIM`/`ERA` 최소 구조를 검사한다. 기준 맵과
  진입 소스, 기존 출력의 fingerprint를 승격 직전에 다시 비교하고 하나라도
  달라지면 성공을 게시하지 않는다.
- 검증된 임시 출력만 같은 볼륨에서 rename한다. 확인된 기존 출력은 고유
  `.backup-eud-<작업 토큰>.bak`로 보존하고, 승격 실패 시 자동 복원한다.
  복원도 실패하면 백업 경로를 복구 진단으로 남기며 일반 작업 공간 정리에서
  삭제하지 않는다.
- 파이프라인·파일 시스템 테스트는 프로세스 성공 뒤 출력 누락, 손상 CHK,
  빌드 중 기준/출력 변경, 기존 출력 백업, 승격 실패 복원, 복원 실패 백업
  보존, 공백·한글 경로의 `.eds` 생성과 앱 소유 작업 공간 정리를 검증한다.
- Windows 통합 테스트는 실제 `ProcessEudCompilerGateway`가 PowerShell 가짜
  euddraft를 실행해 생성된 `.eds`의 절대 input/output/epScript 경로를 읽고
  임시 `.scx`를 만들게 한다. 성공은 실제 fingerprint, 아카이브 재열기,
  `VER`/`DIM`/`ERA` 검증과 최종 rename까지 통과하며, 비정상 종료와 사용자
  취소는 최종 출력 없이 실패·취소 상태와 원시 로그를 보존한다. 세 경로 모두
  원본 바이트 불변과 앱 소유 작업 공간 정리를 확인한다.
- 실제 스모크는 `tool/generate_eud_smoke_fixture.dart`가 만든 32x32 자체 제작
  MPQ, 저장소의 `minimal-smoke.eps`, 공식 euddraft `0.10.2.5`를 사용한다.
  공백·한글 경로에서 컴파일, locale `0x0409` 실제 CHK 추출, eudplib terminal
  `ISOM` 보호 마커 raw 보존, 최소 메타데이터 검증, 원본·소스 불변, 승격,
  재열기와 작업 공간 정리까지 통과했다. 실제 테스트는
  `EUDDRAFT_TEST_INSTALLATION`과 `MAP_ARCHIVE_HELPER_PATH`를 명시할 때만
  실행되며 일반 CI에서는 자동 다운로드하지 않는다.
- 공식 `euddraft0.10.2.5.zip`은 2026-07-27 재확인한 SHA-256
  `87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3`을
  사용했다. 자체 제작 MPQ/CHK provenance와 재생성 명령은
  `test/fixtures/maps/eud_smoke/`의 README와 manifest에 고정했다.
- 안전 파이프라인은 검증 가능한 출력을 유지하기 위해 생성 `.eds`에
  `[freeze] freeze: 0`을 고정한다. Freeze 보호 출력은 일반 CHK 경계를
  의도적으로 숨기므로 별도 신뢰·검증 설계 전까지 MVP 범위에서 제외한다.
- `EudBuildRecord`는 build ID, euddraft 버전, UTC 시작·종료 시각, 실행
  상태, 선택적 종료 코드, 캡처 시각과 채널이 붙은 stdout/stderr, 진단을
  불변 스냅샷으로 보존한다. 성공 기록은 종료 코드 0을 강제한다.
- 컨트롤러는 진행 중 기록을 이벤트와 원자적으로 갱신하고 완료된 최근
  20개 기록을 세션에서 유지한다. 새 요청 준비 후에도 직전 기록을 보존하며
  기록 목록과 로그 목록은 외부에서 수정할 수 없다.
- Build Log는 결과와 종료 코드, 도구 버전, UTC 시각을 상단에 표시하고
  원시 줄을 `[stdout]`/`[stderr]`로 구분한다. 단위·위젯 테스트는 로그 순서,
  타임스탬프 정규화, 종료 코드, 실패·취소 진단과 기록 상한을 검증한다.
  원시 로그의 디스크 저장과 개인정보 제거 내보내기는 후속 manifest 작업이다.
- `EudCompilerDiagnosticParser` 포트는 외부 도구의 원시 줄을 선택적 구조화
  진단으로 변환한다. `EuddraftDiagnosticParser`는 공식 eudplib epScript의
  stderr 형식인 `[Error code] Module "file" Line line : message`만 보수적으로
  인식해 코드·파일·행을 보존한다. 현재 형식에 열이 없으므로 임의로 추정하지
  않으며, 인식 여부와 관계없이 원시 stdout/stderr는 Build Log에 남긴다.
- 컨트롤러 테스트는 하나의 stderr 줄이 원시 기록과 진단 이벤트 양쪽에
  남는지 검증한다. 파서 테스트는 Windows 공백 경로, 한글 모듈, 음수 오류
  코드와 미지원 줄을, 위젯 테스트는 `main.eps:line[:column]` 위치가 Problems와
  Build Log에 표시되는지를 검증한다.

완료 조건:

- 앱에서 epScript를 수정하고 새 EUD `.scx`를 생성할 수 있다.
- 원본 맵은 변경되지 않는다.
- 빌드 실패 원인과 원시 로그를 UI에서 확인할 수 있다.
- 출력 맵이 아카이브/CHK 구조 검증을 통과한다.

## M5. 맵 캔버스와 지형

목표: 실제 맵을 빠르게 탐색하고 기본 지형을 안전하게 편집한다.

- [x] 타일셋/지형 관련 typed view 구현
- [x] 맵 경계, 격자, 가시 영역 렌더링
- [x] 확대/축소, 이동, 좌표 상태 표시
- [x] StarCraft 데이터 자산 위치 설정과 누락 진단
- [x] 타일 선택, 브러시, 사각형 채우기
- [x] 편집 명령 병합과 Undo/Redo
- [x] 원시 값/미지원 타일의 대체 표시
- [x] 실제 타일 렌더링용 CascLib 읽기 경계와 캐시 ADR
- [x] 고정 매니페스트 기반 타일 자산 읽기 포트와 helper 프로토콜
- [x] `CV5`·`VX4EX`·`VR4`·`WPE` 디코더와 손상 입력 검증
- [x] `MTXM` raw 값의 32×32 RGBA 타일 합성과 텍스처 캐시
- [x] 실제 StarCraft 타일 렌더러와 안전한 대체 표시 전환
- [x] 캔버스 성능 계측과 256×256 스모크 테스트

구현 메모:

- 기존 `ERA ` typed view에 더해 `ChkTerrainViewDecoder`가 각 `MTXM`을
  little-endian `u16` 원시 타일 배열로 투영한다. 중복 `MTXM`은 병합하거나
  하나를 고르지 않고 원래 섹션 인덱스를 가진 별도 뷰로 유지한다.
- 정확히 하나의 정상·0이 아닌 `DIM `이 있으면 `width × height`와 타일 수가
  일치하는 뷰만 2차원 좌표 접근을 허용한다. `DIM `이 없거나 중복이면
  임의의 크기를 선택하지 않고 선형 값만 제공한다.
- 홀수 바이트 `MTXM`과 유일한 `DIM ` 기준 타일 수 불일치는 구조화 오류로
  진단하고 해당 typed view를 만들지 않는다. 원시 섹션은 그대로 남는다.
- 단일/전체 타일 변경 API는 기존 타일 수를 고정하고 `u16` 범위를 검사한 뒤
  정확한 `MTXM` 섹션만 dirty raw 섹션으로 교체한다. 실제 지형 편집 UI는
  `TILE`/정상 `ISOM` 우선순위와 게임·외부 에디터 호환성을 검증한 뒤 연다.
- Open/Save 검증은 `ChkTerrainViews`를 세션에 보관하고 지형 구조 오류를
  제한 편집 진단에 포함한다. 중앙 `MapCanvas`는 유일한 0이 아닌 `DIM `을
  fit-to-view로 배치해 경계와 원시 `MTXM` 색상 미리보기를 그린다.
- 격자는 현재 타일 픽셀 크기에 따라 1·2·4·8·16… 타일 간격으로 축약한다.
  painter는 계산된 가시 타일 범위만 순회하고 viewport 밖은 clip한다.
- 캔버스 카메라는 fit 배율을 100%로 삼아 25%~3200% 범위에서 단계적으로
  확대한다. 마우스 휠은 포인터 아래 맵 좌표를 유지하고, `Space`+좌클릭 또는
  중간 버튼 드래그는 문서 변경 기록과 분리된 화면 이동만 수행한다.
- 이동은 확대된 축에서 맵 가장자리 24px 이상을 viewport에 남기도록 제한하며,
  Fit 컨트롤은 100%와 중앙 위치로 복귀한다. 포인터 상태는 0기준 타일 좌표와
  타일당 32픽셀인 StarCraft 맵 픽셀 좌표를 함께 표시하고 맵 밖에서는 비운다.
- `TerrainEditingController`는 정확히 하나의 좌표 접근 가능한 `MTXM`이 있고
  차단 진단과 euddraft 보호 마커가 없는 세션만 편집한다. Select tile은 기존
  raw `u16` 값을 샘플링하고, Brush는 빠른 드래그 사이를 정수 타일 선분으로
  보간하며, Rectangle은 양 끝점을 정규화한 포함 영역을 한 번에 채운다.
- 편집은 선택한 `MTXM` payload의 길이를 바꾸지 않고 해당 raw 섹션만 dirty로
  교체한다. 갱신된 세션은 즉시 캔버스·Inspector·Save As에 공유되며, Save As
  재열기 뒤에는 검증된 clean 세션을 채택한다. 선택과 카메라는 dirty가 아니다.
- 각 지형 명령은 적용 전·후의 정확한 `MTXM` raw 섹션을 기록한다. 연속 Brush
  드래그의 여러 화면 갱신은 마우스를 놓을 때 하나의 명령으로 병합하고,
  Rectangle은 한 명령으로 기록한다. `Escape` 또는 포인터 취소는 진행 중인
  Brush의 최초 섹션을 복원해 기록을 남기지 않는다.
- Undo/Redo는 현재 raw 섹션이 명령의 예상 snapshot과 같은지 확인하고 교체
  뒤 terrain view를 다시 검증한다. 새 편집은 Redo 기록을 비우고 세션별 최근
  100개 명령을 유지한다. 최초 clean 섹션까지 Undo하면 `Modified`도 해제된다.
  새 맵 또는 검증된 Save As 세션을 채택하면 이전 source의 기록을 초기화한다.
- Edit 메뉴와 지형 도구 모음에 Undo/Redo 상태를 연결하고, 맵 작업 화면에서만
  `Ctrl+Z`/`Ctrl+Y`를 활성화해 epScript 텍스트 편집과 충돌하지 않게 한다.
- 현재 도구는 CHK의 게임 지형인 `MTXM`만 수정한다. Chkdraft
  `7ad7c28c15ab404eb6b535433f518f65a7b6e0f8`의 `Scenario::setTile`도 Game
  scope의 `MTXM`과 Editor scope의 `TILE`을 별도 배열로 다루는 것을 확인했다.
  따라서 `TILE`/`ISOM`은 byte-exact 보존하고 UI에 `MTXM only` 범위를
  표시한다. 외부 에디터에서 보이는 편집 지형과 달라질 수 있으므로 두 표현의
  동기화는 별도 검증 전 자동으로 추측하지 않는다.
- `MTXM`이 없거나 active 섹션을 안전하게 하나로 고를 수 없으면 임의 데이터를
  사용하지 않고 경계·격자만 표시한다. 유일한 정상 `DIM `도 없으면 캔버스를
  비활성화하고 필요한 조건을 표시한다.
- Settings에서 사용자가 `.build.info`, `Data`, `StarCraft.exe`가 있는
  StarCraft: Remastered 설치 폴더를 선택할 수 있다. 선택 경로는 사용자 로컬
  설정의 `starcraftInstallationPath`에만 저장한다.
- `StarCraftDataAssetManifest`는 8개 타일셋의
  `CV5`·`VF4`·`VX4EX`·`VR4`·`WPE` 총 40개 CASC 내부 경로를 고정한다.
  리마스터 설치본은 고전 `.vx4` 대신 확장 메가타일 `.vx4ex`를 사용한다.
- [ADR-0005](decisions/0005-casclib-helper-process.md)에 따라 pinned CascLib을
  정적으로 링크한 번들 `starcraft_data_helper.exe`가 로컬 CASC를 읽는다.
  Dart 어댑터는 절대 설치 경로와 프로토콜/버전/매니페스트를 검증하고 누락,
  손상, timeout, 대량 출력과 비정상 응답을 구조화 진단으로 반환한다.
- 실제 로컬 SC:R `s1` 빌드 `13515`에서 40개 자산 33,670,360바이트를 끝까지
  읽는 스모크 테스트를 통과했다. 게임 데이터를 추출·복사·다운로드하거나
  CASC 저장소를 수정하지 않는다.
- 도구 모음의 환경 배지와 하단 Problems가 검사 상태와 해결 방법을 표시한다.
  데이터 자산이 없거나 불완전해도 현재 원시 색상 캔버스와 안전한 Save As는
  사용할 수 있다.
- `MTXM` raw 값은 `group = value / 16`, `member = value % 16`으로 분해한다.
  전체 `u16`은 최대 4,096개 그룹을 주소화할 수 있다. 실제 SC:R `CV5`는
  doodad 등을 포함해 1,024개보다 많은 52바이트 엔트리를 가지므로
  `0x4000` 이상도 해당 파일의 실제 그룹 범위 안이면 렌더링한다. 실제 그룹
  밖 값만 helper가 unsupported로 돌려주며, 앱은 값을 손실 없이 유지한 채
  자홍색 교차 경고 패턴과 unsupported 개수로 구분한다. 선택한 타일에는 raw 값,
  그룹, 멤버와 helper가 확인한 지원 상태를 함께 표시한다.
- [ADR-0006](decisions/0006-request-scoped-tile-atlas-cache.md)에 따라 원시
  타일셋 자산과 디코더는 helper 경계 안에 유지한다. 새 `renderTileAtlas`
  작업은 고정 매니페스트에서 선택한 tileset의 `CV5`·`VX4EX`·`VR4`·`WPE`만
  읽고 최대 4,096개 raw 값을 요청별 32×32 RGBA 아틀라스로 합성한다. RGBA는
  JSON이 아닌 앱 소유 임시 binary envelope로 교환하고 채택 직후 삭제한다.
- `StarCraftTileAtlasGateway`의 요청은 절대 설치 경로, 8개 tileset enum과
  정렬·중복 제거된 1~4,096개 `u16` raw 값만 허용한다. 공용 helper protocol
  2는 기존 설치 검사와 `renderTileAtlas` 작업을 operation으로 분리한다.
  렌더 경계는 helper 0.2.0에서 도입했고 디코더가 포함된 현재 버전은
  0.3.0이다. helper는 요청 tileset의 고정 `CV5`·`VX4EX`·`VR4`·`WPE` 네
  경로만 strict-read하며 임의 CASC 경로나 출력 경로를 받지 않는다.
- 아틀라스 교환 파일은 `SCTRGBA\0` magic, format 1, 32px tile, 열·행·타일
  수, raw 엔트리·픽셀 바이트 길이를 가진 32바이트 little-endian header 뒤에
  4바이트 raw 엔트리와 타일별 연속 premultiplied RGBA8888을 둔다. 열·행은
  최대 64열의 논리 배치와 마지막 padding 크기를 나타내며 픽셀 scanline
  stride가 아니다. Dart 어댑터는 JSON,
  실제 파일 종류·크기, header, raw/unsupported의 요청 전체 포함 관계를
  교차 검증하고 요청별 임시 디렉터리를 항상 정리한다.
- helper 0.3.0은 네 자산을 strict-read한 뒤 `CV5` 52바이트 그룹,
  `VX4EX` 64바이트 메가타일, `VR4` 64바이트 미니타일과 1,024바이트 `WPE`를
  little-endian으로 해석한다. 요청 중 정상인 raw만 최대 64열 아틀라스의
  엔트리와 RGBA 영역에 기록하고 실제 `CV5` 그룹 밖 값만 unsupported로
  분리한다.
- helper의 픽셀 합성은 `MTXM`의 group/member로 `CV5` mega-tile을 선택하고,
  `VX4EX`의 4×4 mini-tile 인덱스와 반전 플래그, `VR4`의 8×8 팔레트 인덱스,
  `WPE` 색상을 순서대로 해석해 32×32 RGBA 타일을 만든다. 모든 offset,
  index와 파일 길이는 사용 전에 검증하며 `VF4`는 향후 이동·배치 가능 영역
  오버레이를 위해 계속 검사하되 픽셀 합성 필수 입력으로 간주하지 않는다.
- 잘린 파일, `CV5` 4,096그룹 초과, `CV5→VX4EX` 또는 `VX4EX→VR4` 범위 밖
  참조는 `SC_CASC_TILE_ASSET_INVALID` 비차단 진단으로 전체 요청을 격리한다.
  자체 생성 바이트의 group/member·수평 반전·RGB/alpha와 실제 로컬 SC:R
  8개 타일셋의 raw `0/1` 합성을 검증했다. 원시 게임 자산은 저장소나 Dart로
  복사하지 않는다.
- 합성 결과는 StarCraft 설치 fingerprint·게임 빌드·타일셋·raw 값을 키로
  삼은 128 MiB 메모리 LRU에 `ui.Image`로만 캐시하고 설치 경로나 검사
  revision이 바뀌면 dispose한다. 캔버스는 준비된
  실제 타일을 우선 사용하되 자산 누락, 디코딩 실패, 미지원 raw 값에는 현재
  색상·교차 경고 대체 표시를 유지한다. 렌더링 실패는 맵 저장을 차단하거나
  `MTXM` 값을 정규화하지 않는다.
- `TerrainTileAtlasLoader`는 정확히 하나의 정상 `ERA `·`MTXM`과 준비된 자산
  검사 snapshot이 있을 때만 context를 만든다. 맵에 실제로 등장하는 raw 값을
  정렬·중복 제거하고 전체 `u16` 범위를 최대 4,096개씩 요청한다. helper가 돌려준
  RGBA 영역은 raw 엔트리 순서의 연속 4,096바이트 타일로 절단하고 마지막 논리
  셀 padding은 무시하며,
  응답의 설치 제품·빌드·helper/CascLib revision이 검사 snapshot과 다르면
  채택하지 않는다.
- `TerrainTileTextureController`는 절단된 RGBA를 즉시 `ui.Image`로 변환하고
  CPU 버퍼를 보관하지 않는다. 설치 경로·제품·빌드·helper/CascLib revision·
  tileset·검사 snapshot·raw 값 identity를 사용하는 기본 128 MiB LRU가 hit를
  승격하고 교체·퇴출·맵 닫기·설정 갱신에서 반드시 `Image.dispose()`를 호출한다.
  비동기 로드 중 generation이 바뀌면 늦게 완성된 이미지도 즉시 폐기한다.
- 4,097개 고유 raw 값의 `4,096 + 1` 배치, 연속 타일과 마지막 padding 절단,
  확장 `CV5` 그룹 렌더링, 캐시 재사용과
  snapshot 무효화, LRU 퇴출, 이미지 변환 실패, helper unsupported, 오래된
  generation dispose를 자동 테스트로 고정했다.
- 앱 조립은 `ProcessStarCraftTileAtlasGateway`·`TerrainTileAtlasLoader`·
  `TerrainTileTextureController`를 한 수명으로 연결한다. `EditorShell`은 열린
  문서나 자산 검사 상태가 바뀔 때 generation을 동기화하며, 설정 해제·교체나
  맵 세션 해제 시 캐시를 비우고 이전 이미지를 dispose한다. 렌더 진단은 기존
  Problems 목록에 합쳐지며 저장 차단 진단으로 승격하지 않는다.
- `MapCanvasPainter`는 가시 타일마다 준비된 32×32 `ui.Image`를
  `FilterQuality.none`으로 먼저 그린다. 이미지가 아직 없거나 이미지 변환에
  실패한 raw는 기존 결정적 색상으로, helper가 실제 그룹 밖이라고 반환한 raw는
  자홍색 교차 패턴으로 그린다. 배지는 loading, 실제 타일,
  혼합 fallback, 전체 raw fallback 상태를 구분한다.
- 위젯 테스트는 실제 RGBA 이미지를 캔버스에 그린 결과 픽셀, 미지원 타일의
  fallback 픽셀, 로딩 배지, painter 갱신 identity를 검증한다. 셸 통합 테스트는
  준비된 설치에서 맵의 고유 raw만 요청해 실제 타일 모드로 전환하고 자산 설정을
  지우면 모든 텍스처를 해제한 뒤 raw fallback으로 복귀하는 흐름을 고정한다.
- `MapCanvasPainter.paint`는 DevTools에서 찾을 수 있는 Timeline 범위에 맵 크기,
  가시 타일 수, zoom, grid step, terrain/texture 상태를 기록한다. 선택적
  `onPaintMeasured` 콜백은 Stopwatch 시간과 texture/fallback/unsupported 타일
  수를 불변 스냅샷으로 전달하며, 콜백이 없으면 타일별 계측 카운터를 만들지 않는다.
- 256×256 성능 스모크는 800×600 viewport에서 실제 raw 65,536개를 그린 뒤
  fit·zoom·pan의 시간과 가시 타일 수를 기록한다. debug 자동 테스트의 1초 상한은
  병적인 동기 렌더링 회귀만 차단하며 30/60 FPS 판정은 profile 빌드의 DevTools
  frame timing으로 별도 수행한다. 2026-08-06 기준선은
  [성능 기록](performance/MAP_CANVAS_256_SMOKE.md)에 보존한다.

완료 조건:

- 정상 SC:R 자산이 준비되면 지원되는 `MTXM`이 실제 32×32 타일 이미지로
  표시된다.
- 자산 누락·손상 또는 미지원 raw 값은 구조화 진단과 대체 표시로 격리되며
  원본 맵과 Save As 결과를 변경하지 않는다.
- 256×256 테스트 맵을 탐색할 수 있다.
- 지형 변경을 되돌리고 다시 적용할 수 있다.
- Save As 후 변경 지형이 다시 열었을 때 동일하다.

## M6. 객체와 로케이션

목표: 게임 객체를 선택, 배치, 이동, 수정할 수 있게 한다.

- [x] 유닛, 스프라이트/두다드, 로케이션 typed view 구현
- [x] 레이어 표시/잠금과 선택 우선순위
- [x] 단일/다중 선택, 박스 선택, 이동, 삭제
- [x] 객체 팔레트와 검색
- [x] 속성 Inspector와 유효성 검사
- [x] 로케이션 생성, 크기 조절, 이름 변경
- [x] 잘못된 문자열/플레이어/좌표 참조 진단
- [x] 편집 왕복 통합 테스트

구현 메모:

- `ChkObjectViewDecoder`는 `UNIT` 36바이트, `DD2` 8바이트, `THG2`
  10바이트 레코드와 `MRGN`의 64/255개 로케이션 테이블을 little-endian typed
  view로 투영한다. 모든 필드에는 raw 플래그·예약 값이 포함되며 각 view는 원래
  섹션 인덱스와 `RawChkSection`을 유지한다.
- 중복 섹션은 합치거나 active 항목을 추측하지 않고 원래 순서의 별도 view로
  남긴다. 불완전한 고정 레코드와 1280/5100바이트가 아닌 `MRGN`은 차단 진단을
  만들고 해당 typed view만 생략하며 raw 섹션은 변경하지 않는다.
- Open Map과 검증형 Save As는 객체 view를 다시 디코딩해
  `OpenedMapSession.objectViews`에 보관한다. 문자열 view도 같은 세션에 보관하며
  Open/Save 검증과 객체 편집 후 의미 참조 진단을 다시 계산한다.
- `MapLayerController`는 Terrain, Locations, Doodads, Sprites, Units의 활성·표시·
  잠금과 단일 검사 선택을 문서 변경 상태와 분리해 관리한다. 새 원본 스냅샷을
  열면 선택만 지우고 레이어 설정은 유지한다.
- 캔버스 표시 순서는 Terrain → Locations → Doodads → Sprites → Units이며,
  기본 선택 순서는 그 역순이다. 현재 활성 레이어가 표시되고 잠금 해제된 경우
  첫 우선순위로 이동한다. 숨김은 렌더와 hit test 모두에서 제외하고, 잠금은
  렌더를 유지하면서 hit test와 편집 진입을 막는다.
- 애플리케이션 계층은 typed view를 렌더 중립적인 point/region 장면으로 만들고,
  Presentation은 이를 단순 도형과 선택 강조로 표시한다.
- 클릭은 우선순위의 첫 객체를 단일 선택하고 Ctrl/Shift+클릭은 선택을 토글한다.
  빈 공간 드래그는 활성 객체 레이어만 박스 선택하며 Terrain 활성 상태에서는
  표시·잠금 해제된 모든 객체 레이어를 선택한다. 선택 객체에서 시작한 드래그는
  StarCraft 픽셀 단위 이동 미리보기를 표시한 뒤 맵 경계 안에서만 반영한다.
- `ChkObjectSectionEditor`는 이동 시 `UNIT`의 x/y 4바이트와 `DD2 `/`THG2`의
  x/y 4바이트, `MRGN`의 네 좌표만 바꾼다. 고정 객체 삭제는 선택 레코드만
  제거하고 나머지 바이트 순서를 유지하며, 로케이션 삭제는 ID가 바뀌지 않도록
  64/255개 테이블 길이를 유지한 채 해당 20바이트 슬롯만 0으로 비운다.
- `ObjectEditingController`는 여러 섹션 변경을 한 Undo 단계로 묶고 매 적용 뒤
  객체 typed view를 재검증한다. Delete와 객체 레이어의 Ctrl+Z/Ctrl+Y 및
  도구 모음 Undo/Redo가 이 기록을 사용한다.
- `ObjectPaletteController`는 현재 맵의 `UNIT`, `DD2 `, `THG2`를 레이어와 type
  ID로 묶어 개수와 첫 레코드 템플릿을 만든다. 검색은 종류·레이어·`#type ID`를
  지원한다. 외부 게임 데이터 카탈로그를 아직 신뢰할 수 없으므로 이름이나 새
  기본 레코드를 추측하지 않고 `Unit type 1` 같은 수치 이름을 표시한다.
- 팔레트 배치는 템플릿 레코드의 owner·flags·예약 필드를 그대로 복사하고 x/y
  4바이트만 클릭 좌표로 바꿔 해당 섹션 끝에 추가한다. 맵 경계, 레이어 잠금,
  제한 편집을 검사하고 한 배치마다 Undo 명령을 만든다. 선택은 연속 배치를
  유지하며 `Escape`나 레이어 전환으로 취소한다.
- 단일 선택 Inspector는 유닛의 type/x/y/owner/체력·실드·에너지 비율/자원/
  격납량, 두다드의 type/x/y/owner/enabled raw, 스프라이트의 type/x/y/owner를
  Apply 한 번에 편집한다. 좌표는 `DIM ` 맵 경계, 정수 필드는 실제 CHK 폭,
  비율은 0~100, 두다드 enabled는 0/1로 검증하며 실패 시 raw 문서를 바꾸지
  않는다. 변경은 한 객체 Undo 명령이고 선택은 새 typed view 좌표로 유지된다.
- class/relation/state flags, unused, 스프라이트 flags 같은 원시·예약 필드는
  읽기 전용으로 표시하고 byte-exact 보존한다. 다중 선택은 공통 레이어와 개수를
  표시하며 속성 Apply는 단일 선택으로 제한한다.
- 로케이션 생성 모드는 정확히 하나의 유효한 `MRGN`이 있을 때 첫 번째 빈
  20바이트 슬롯을 사용한다. 캔버스 드래그 경계는 맵 픽셀 안의 엄격한 사각형이어야
  하며 새 슬롯은 string ID 0과 elevation flags `0x003f`로 시작한다. 고정 테이블을
  확장하거나 뒤 슬롯을 이동하지 않으므로 기존 로케이션 ID가 유지된다.
- 로케이션 Inspector는 left/top/right/bottom과 이름을 편집한다. 이름 변경은
  정확히 하나의 구조적으로 안전한 `STR `/`STRx`에 UTF-8 문자열을 append하고 새
  ID로 선택 슬롯만 다시 가리키는 copy-on-write 방식이다. 공유 문자열, 기존
  offset 대상, 미참조 꼬리 바이트는 수정하지 않는다. 문자열 표가 없거나 중복·
  손상되었으면 경계 편집은 허용하되 이름 입력만 비활성화한다.
- 생성과 속성 Apply는 각각 하나의 Undo 명령이며, 이름 변경 시 `MRGN`과 문자열
  섹션의 전후 snapshot을 같은 명령에 묶어 Undo/Redo한다. `Escape`와 레이어
  전환은 아직 적용하지 않은 생성 모드만 취소한다.
- `ChkObjectReferenceValidator`는 유일한 `DIM ` 기준으로 유닛·두다드·스프라이트
  좌표와 비어 있지 않은 로케이션 경계를 검사하고, 객체 owner가 Player 1~12의
  raw 값 0~11인지 확인한다. 경계 밖 좌표와 뒤집히거나 0크기인 로케이션은 원본
  필드의 CHK byte offset을 포함한 경고로 Problems에 표시한다.
- 로케이션 name과 `SPRP`의 맵 이름·설명은 string ID 0을 없음으로 허용하고,
  유일한 `STR `/`STRx`에서 범위와 entry 구조를 검사한다. 표가 없거나 손상되어
  읽을 수 없으면 unresolved, 여러 표가 있으면 active table을 추측하지 않고
  ambiguous 경고를 만든다.
- 의미 참조 진단은 비표준/EUD raw 값을 자동 복구하거나 편집을 차단하지 않는
  warning이다. 객체 Apply·배치·삭제·Undo/Redo 뒤 현재 typed view에서 다시 만들어
  고쳐진 진단은 사라지고 되돌린 진단은 복원된다. 문자열 표 자체의 잘림·잘못된
  offset 같은 구조 오류는 기존 blocking 진단 정책을 유지한다.
- `test/integration/object_editing_roundtrip_test.dart`는 저장소에서 직접 조립한
  CHK를 Open Map으로 연 뒤 유닛·두다드·스프라이트·로케이션 속성과 객체 배치를
  편집하고, 로케이션 이름 변경의 Undo/Redo를 거쳐 검증형 Save As와 출력 재열기까지
  연결한다. 객체 레코드 순서와 지원 필드, 원시 flags·예약 바이트, 알 수 없는 섹션,
  섹션 순서, 기존 문자열과 미참조 꼬리 바이트가 보존되고 입력 snapshot이 바뀌지
  않는지를 함께 고정한다.

완료 조건:

- 각 지원 객체를 편집하고 Undo/Redo할 수 있다.
- 저장/재열기 후 객체 속성과 순서가 예상대로 유지된다.
- 미지원 필드는 임의로 초기화되지 않는다.

## M6.1. 실제 객체 그래픽 렌더링

목표: 현재의 위치 마커를 유지하면서 StarCraft 설치에서 읽은 실제 스프라이트
이미지를 객체 좌표에 표시한다.

- [x] SC:R CASC의 객체 메타데이터·그래픽 경로, 포맷, 버전 차이와 라이선스 조사
- [x] native helper의 객체 자산 읽기·디코딩 프로토콜과 안전 한계 정의
- [x] `THG2` sprite type에서 sprite/image/그래픽 자산으로 이어지는 참조 모델 구현
- [x] 대표 프레임을 RGBA로 변환하는 decoder와 응답 envelope 검증 구현
- [x] Application port 뒤에 객체 이미지 atlas/cache와 취소·오래된 응답 차단 구현
- [x] `renderObjectAtlas` native CASC reader와 protocol 3 process adapter 연결
- [x] 스프라이트 캔버스 이미지 렌더링과 누락·미지원 자산의 위치 마커 fallback
- [x] player color, 방향, 대표 프레임 및 애니메이션 범위 정책 확정
- [x] 자체 제작 합성 자산 단위·통합·위젯 테스트와 실제 설치 선택적 스모크 테스트
- [x] 다수 객체가 있는 256×256 맵의 로딩·메모리·paint 성능 계측

구현 원칙:

- 게임 자산은 사용자가 선택한 로컬 StarCraft 설치에서 런타임에만 읽고 저장소나
  테스트 픽스처에 포함하지 않는다.
- Presentation은 CascLib이나 파일 시스템을 직접 호출하지 않고, native helper와
  프로세스 실행은 기존 Application port와 Infrastructure adapter 경계를 따른다.
- 첫 구현은 편집에 충분한 정적인 대표 프레임을 우선하며, 게임 애니메이션의 완전한
  재현은 자산·스크립트 포맷 조사 뒤 별도 범위로 결정한다.
- 조사 결과와 구현 범위는
  [`research/OBJECT_GRAPHICS_ASSETS.md`](research/OBJECT_GRAPHICS_ASSETS.md)를
  기준으로 한다. 첫 decoder는 클래식 `unit/*.grp` 대표 프레임을 지원하고,
  Remastered `.anim`과 대체 스킨은 후속 범위로 둔다.
- 객체 렌더 경계는
  [ADR-0007](decisions/0007-object-sprite-atlas-protocol.md)의 protocol 3
  `renderObjectAtlas` 요청, 가변 RGBA envelope와 부분 fallback 상한을 따른다.
  helper 0.4.0부터 설치 검사·타일 렌더·객체 렌더가 공용 protocol 3을 사용한다.
- native `ObjectSpriteReference`는 클래식 DAT/TBL의 정확한 크기와 모든 중간
  참조를 검증하고 `unit → flingy → sprite → image` 및 pure sprite 경로를
  1-based `images.tbl` GRP ID와 정규화된 `unit\\*.grp` 경로로 해석한다.
- native `ObjectGrpDecoder`는 합성 GRP frame 0의 논리 canvas, 투명·literal·
  solid RLE, 중심 anchor와 선택적 player-color 인덱스 8~15 치환을 검증해
  premultiplied RGBA8888로 만든다. `ObjectAtlasProtocol`은 정렬·고유 entry,
  1,024px/4 MiB/32 MiB 상한을 검사하고 새 partial 파일을 flush한 뒤 고정
  `object-atlas.rgba`로 승격한다.
- 정적 preview 정책은 owner 0~7만 같은 player color로 요청하고 그 밖의 owner는
  `null`로 보내 현재 tileset WPE 색을 유지한다. 방향은 0, 대표 프레임은 classic
  GRP frame 0으로 고정하며 iscript 애니메이션, Remastered ANIM, 대체 스킨과
  시간 기반 재생은 M6.1에서 제외한다. 이 의미를 확장할 때는 protocol/envelope와
  cache identity를 함께 버전 변경하고 기존 값을 조용히 재해석하지 않는다.
- Application `StarCraftObjectAtlasGateway`는 operation ID, tileset과 최대 256개의
  정렬·고유 unit/sprite/player-color 키, 성공 entry와 unsupported의 정확한 분할,
  가변 RGBA·anchor 메타데이터와 취소 계약을 정의한다. `ObjectSpriteAtlasLoader`는
  `UNIT` 및 `THG2 DrawAsSprite`를 이 키로 중복 제거하고 설치 inspection snapshot을
  포함한 identity로 요청·응답을 교차 검증한다.
- Presentation의 `ObjectSpriteTextureController`는 256개 요청 배치, 64 MiB 객체
  전용 LRU, 설정·설치·타일셋 identity 변경 시 dispose, 새 synchronize/clear/dispose
  시 활성 operation 취소와 generation 기반 stale 응답 차단을 제공한다.
- native `ObjectAssetReader`는 5개 DAT/TBL, 요청 tileset WPE,
  `game\\tunit.pcx`와 요청에서 도달한 고유 GRP만 CascLib strict-read한다.
  `tunit.pcx`의 128×1 색상표에서 player별 연속 8색을 읽고 공용 metadata 손상은
  전체 실패, 개별 ID·GRP 실패는 정렬된 unsupported로 격리한다.
- `ProcessStarCraftObjectAtlasGateway`는 protocol 3/helper 0.4.0 요청을 절대 경로의
  번들 helper에 전달하고 JSON·설치 identity·일반 파일·32바이트 header/entry·
  연속 pixel 영역·요청 전체 coverage를 교차 검증한다. timeout과 명시적 취소는
  해당 operation ID의 프로세스만 종료한다.
- `MapLayerController` scene은 `UNIT`과 `THG2 DrawAsSprite`를 atlas key에 연결한다.
  `EditorShell`은 열린 session·설치 inspection·tileset이 바뀔 때 객체 texture
  generation을 동기화하며, `MapCanvasPainter`는 32 StarCraft pixel 기준으로
  RGBA 크기와 anchor를 확대해 그린다. 레이어 표시 순서, 선택 outline과 이동
  미리보기에도 같은 image 경로를 쓰며 texture가 없는 객체는 기존 마커를 유지한다.
- 자산 누락, 알 수 없는 ID, 지원하지 않는 포맷은 맵 열기와 저장을 차단하지 않는다.
  해당 객체는 현재의 색상·도형 위치 마커로 표시하고 stable unsupported code를
  Problems에 비차단 진단으로 남긴다.
- 그래픽 조회 결과는 표시 전용이다. `UNIT`, `DD2 `, `THG2` 원시 레코드와 Save As
  결과를 정규화하거나 변경하지 않는다.

검증 메모:

- `starcraft_object_graphics_native_test`는 자체 작성 GRP와 RGBA만 사용해
  frame 0 RLE·투명도·anchor·player-color 치환, 손상 입력 거부와 binary
  envelope 필드·정렬·길이·기존 출력 보존·32 MiB 상한을 검증한다.
- 2026-08-16 Debug native CTest 3/3, `flutter analyze`, `flutter test`
  319개 통과(환경 의존 5개 skip), `flutter build windows --debug`가 통과했다.
- `starcraft_object_atlas_gateway_test`, `object_sprite_atlas_loader_test`,
  `object_sprite_texture_test`는 key/coverage/불변 RGBA 계약, `UNIT`/`THG2` 변환,
  256+1 배치, cache reuse·invalidation·eviction, 부분 fallback, 활성 취소와 stale
  결과 폐기를 자체 작성 CHK와 가짜 gateway/texture만으로 검증한다.
- 2026-08-18 `flutter analyze`, `flutter test` 332개 통과(환경 의존 5개 skip),
  `flutter build windows --debug`가 통과했다.
- 2026-08-18 protocol 3 process 테스트는 정상·부분 fallback·빈 atlas·손상
  JSON/envelope·대량 출력·timeout·취소를 통과했다. Debug native CTest 3/3과
  로컬 SC:R의 unit 0 player 0 대표 프레임 선택적 스모크도 통과했다.
  `flutter analyze`와 `flutter test` 339개(환경 의존 6개 skip)가 통과했다.
- 2026-08-18 scene key·anchor image·선택 이동·marker fallback widget 테스트와
  EditorShell의 객체 texture 로드/해제 통합 테스트를 추가했다. 자산 설정을
  지우면 객체 LRU 이미지도 dispose되고 painter가 marker 경로로 복귀한다.
  `flutter analyze`, `flutter test` 341개(환경 의존 6개 skip),
  `flutter build windows --debug`가 통과했다.
- 2026-08-20 `StarCraftObjectPreviewPolicy`와 native 공용 상수로 owner 색상,
  `firstFrame`, direction 0, frame index 0 계약을 고정했다. Dart 요청·process
  adapter 집중 테스트와 Debug native CTest 4/4가 통과했다. `flutter analyze`,
  `flutter test` 342개(환경 의존 6개 skip), `flutter build windows --debug`도
  통과했다.
- 2026-08-20 합성 DAT/TBL/GRP native 단위 테스트, 자체 CHK Application 테스트,
  가짜 protocol 3 process 통합 테스트, 실제 `ui.Image`와 marker fallback widget
  테스트의 계층별 증거를 다시 확인했다. 로컬 SC:R 선택적 스모크 3/3은 8개
  tileset과 unit 0의 player 0/기본 팔레트 차이, sprite ID 0~15 중 하나 이상의
  pure sprite 대표 프레임을 번들 CascLib helper로 검증했다. 일반 환경의
  `flutter analyze`, `flutter test` 342개(환경 의존 6개 skip),
  `flutter build windows --debug`도 통과했다.
- 2026-08-20 객체 성능 스모크는 256×256 맵의 4,096 placements와 256 unique
  key에서 실제 `ui.Image` 240개, fallback 16종을 준비했다. synchronize 46.844 ms,
  LRU 983,040 bytes, fit/zoom/pan paint 15.853/4.253/4.760 ms였고 clear 뒤 LRU가
  0 bytes로 복귀했다. debug 자동 상한은 load 2초, paint 1초, LRU 64 MiB이며
  [객체 성능 기록](performance/OBJECT_SPRITE_256_SMOKE.md)에 조건과 한계를 남겼다.
  전체 `flutter analyze`, `flutter test` 343개(환경 의존 6개 skip),
  `flutter build windows --debug`도 통과했다.
- 2026-08-22 `DD2 ` 두다드 위에 항상 겹치던 주황색 fallback 마커를 제거했다.
  두다드 외형은 `MTXM` 지형으로 표시하고 선택·이동 중일 때만 위치 마커를
  그리며, 클릭·박스 선택은 기존 scene 좌표를 그대로 사용한다. 중심 픽셀과
  paint marker 수 회귀 테스트를 포함해 `flutter analyze`, `flutter test`
  344개(환경 의존 6개 skip), `flutter build windows --debug`가 통과했다.

완료 조건:

- 지원하는 `THG2` 스프라이트가 맵 좌표와 올바른 중심점에 실제 이미지로 표시된다.
- 자산이 없거나 지원하지 않는 스프라이트는 식별 가능한 마커와 진단으로 대체된다.
- 레이어 표시·잠금·선택·이동 미리보기와 실제 이미지 렌더링이 함께 동작한다.
- 자산을 사용할 수 없는 환경에서도 기존 객체 편집과 Save As 테스트가 동일하게
  통과하며, 저장 전후 CHK 바이트 보존 정책이 유지된다.
- 256×256 성능 스모크가 문서화된 시간·메모리 상한 안에서 통과한다.

## M6.2. 시각적 배치 선택 팝업

목표: 다른 StarCraft 맵 에디터처럼 로컬 게임 데이터의 Tile, Doodad, Unit,
Sprite를 실제 이미지 목록에서 찾고 선택한 뒤 캔버스에 배치할 수 있게 한다.
이 단계가 완료되기 전에는 M7 일반 트리거 구현을 시작하지 않는다.

- [x] 기존 에디터의 Tile·Doodad·Unit·Sprite 선택 흐름과 CHK 생성 규칙 조사
- [ ] 로컬 SC:R 배치 카탈로그 포트·모델과 안전한 이름/ID fallback 정의
- [ ] 타일셋별 Tile 카탈로그와 실제 32×32 썸네일 공급
- [ ] Unit·Sprite 전체 카탈로그와 실제 객체 썸네일 공급
- [ ] Doodad 정의, 크기, 중심점, 지형·overlay 구성 관계 해석
- [ ] 현재 맵에 없는 Unit·Sprite를 위한 검증된 기본 레코드 factory 구현
- [ ] Doodad의 `DD2 `·`MTXM`·필요한 `THG2` 원자적 배치/삭제/Undo 구현
- [ ] Tile·Doodad·Unit·Sprite 탭이 있는 크기 조절 가능 선택 팝업 구현
- [ ] 분류·이름·숫자 ID 검색, 타일셋 필터, 최근 선택과 상세 미리보기 구현
- [ ] 선택 결과의 커서 ghost, 스냅, 단일/연속 배치와 `Escape` 취소 구현
- [ ] 레이어 잠금·맵 경계·미지원 자산·잘못된 카탈로그 항목 진단 연결
- [ ] 합성 카탈로그 단위 테스트, 팝업 위젯 테스트와 Save As 왕복 테스트
- [ ] 대형 카탈로그 가상 스크롤·검색·썸네일 cache 성능 계측
- [ ] 로컬 SC:R 설치에서 선택적 Tile·Doodad·Unit·Sprite 배치 스모크 검증

구현 순서:

1. **카탈로그 계약과 포맷 조사**
   - Tile은 현재 tileset의 유효한 `MTXM` raw 값과 32×32 미리보기를 기본 키로
     사용한다. CV5 group/member, 지형 분류와 이름을 확인할 수 있으면 함께
     제공하되 구조가 불명확한 값을 임의로 이름 붙이지 않는다.
   - Unit은 `units.dat`, Sprite는 `sprites.dat` 기준 ID를 사용하고 검증된 로컬
     TBL 이름이 있을 때만 표시한다. 이름이 없거나 손상되면 `Unit #37`,
     `Sprite #130`처럼 종류와 숫자 ID를 항상 노출한다.
   - Doodad는 단순 `DD2 ` 레코드가 아니라 여러 `MTXM` 타일과 선택적인 overlay
     sprite가 함께 구성될 수 있다. 타일셋별 정의·폭·높이·중심점·소유자·enabled
     규칙을 확인해 하나의 배치 recipe로 모델링한다. recipe가 완전하지 않은
     항목은 배치 버튼을 비활성화하고 이유를 보여주며 바이트를 추측하지 않는다.
   - 조사 결과와 기본 레코드 값은
     [시각적 배치와 CHK 생성 규칙 조사](research/VISUAL_PLACEMENT_AND_CHK_RULES.md)와
     [ADR-0008](decisions/0008-validated-visual-placement-catalog.md)에 고정했다.
     기존 맵의 첫 레코드를 복제하는 현재 `ObjectPaletteController` 경로는
     호환 fallback으로 유지하되,
     전체 카탈로그의 기본값을 대신하는 근거로 사용하지 않는다.

2. **Application 경계와 로컬 자산 공급**
   - Domain/Application 모델은 `kind`, stable ID, tileset, 분류, 검증된 표시 이름,
     배치 가능 여부와 진단만 갖고 Flutter, 파일 시스템, CascLib에 의존하지 않는다.
   - Infrastructure는 기존 설치 검사 snapshot과 helper 프로세스 경계 뒤에서만
     카탈로그·썸네일을 읽는다. 요청은 종류·타일셋·페이지 범위를 제한하고 버전,
     원시 로그와 구조화된 실패를 기록한다.
   - Tile 썸네일은 기존 terrain atlas, Unit·Sprite 썸네일은 object atlas와 LRU를
     재사용한다. 화면에 보이는 항목과 주변 prefetch 범위만 비동기로 준비하며
     세대가 바뀐 이미지와 팝업 종료 뒤 GPU 자원을 명시적으로 해제한다.
   - SC:R 원시 자산과 추출 이미지는 저장소 fixture나 배포물에 포함하지 않는다.
     자동 테스트는 자체 제작 DAT/TBL/GRP/CV5 계열 바이트와 가짜 gateway만 쓴다.

3. **선택 팝업 UX**
   - 공용 `Place` 명령과 레이어별 명령으로 하나의 크기 조절 가능한 팝업을 열고
     `Tiles`, `Doodads`, `Units`, `Sprites` 탭을 제공한다. 팝업은 왼쪽 분류/필터,
     가운데 가상화 썸네일 grid, 오른쪽 큰 미리보기·ID·크기·지원 상태로 구성한다.
   - 검색은 표시 이름, 종류, `#숫자 ID`를 지원하고 현재 tileset과 호환되지 않는
     항목은 숨기지 않고 비활성 상태와 이유를 구분한다. 최근 선택은 로컬 UI 설정에
     저장하되 맵 문서, dirty 상태와 Undo 기록에는 포함하지 않는다.
   - 클릭은 상세 미리보기만 바꾸고 더블 클릭 또는 명시적 `Place` 버튼이 선택을
     확정한다. 팝업을 닫으면 문서는 바뀌지 않으며, 확정 후에만 해당 레이어와
     배치 도구가 활성화된다. 키보드 탐색, Enter 확정, Escape 닫기와 Windows
     100%/125%/150% 배율에서의 레이아웃을 지원한다.

4. **캔버스 배치와 무손실 편집**
   - 선택한 Tile은 기존 Brush/Rectangle 도구의 입력이 되고, Doodad·Unit·Sprite는
     실제 anchor와 footprint를 반영한 반투명 cursor ghost를 표시한다. 좌클릭은
     배치, 우클릭 또는 `Escape`는 취소하며 연속 배치와 1회 배치를 명확히 전환한다.
   - Unit·Sprite factory는 조사로 확정한 필드만 초기화한다. 좌표·owner·flags와
     예약 바이트를 각 CHK 폭으로 검증하고 현재 맵에 해당 섹션이 없을 때의 새 섹션
     삽입 위치도 무손실 정책에 맞춰 결정적으로 처리한다.
   - Doodad 한 번의 배치는 `DD2 ` metadata, footprint의 `MTXM`, 필요한 `THG2`
     overlay를 하나의 명령으로 적용한다. 경계 밖 footprint, 손상 recipe, 잠긴
     레이어나 중복/모호한 대상 섹션이면 전체를 거부한다. Undo/Redo도 세 섹션을
     함께 복원하며 중간 상태를 사용자 문서에 노출하지 않는다.
   - 다시 연 기존 Doodad의 `DD2 `에는 아래 지형이 없으므로, 유일하고 유효한
     `TILE`을 이용한 복원과 overlay 귀속 규칙을 상호 운용 테스트로 확정하기
     전에는 기존 Doodad의 복합 삭제에서 `MTXM`이나 같은 위치의 `THG2`를 추측해
     지우지 않는다. 같은 세션에서 새로 배치한 Doodad는 command의 before snapshot과
     record identity로 정확히 Undo/Redo한다.
   - 저장은 기존 검증형 Save As만 사용한다. 알 수 없는 섹션, 중복 섹션, 기존
     객체 순서·예약 바이트와 원시 문자열은 이 기능과 무관한 경우 그대로 보존한다.

테스트와 성능 기준:

- 자체 제작 카탈로그에서 정렬·분류·검색·숫자 fallback·타일셋 제한과 손상 항목
  격리를 단위 테스트한다.
- 팝업 위젯 테스트는 빈/로딩/부분 실패/대량 목록, 탭 전환, 검색, 키보드,
  확대 배율, Place/Cancel과 stale 썸네일 폐기를 검증한다.
- 배치 통합 테스트는 각 종류를 현재 맵에 없던 ID로 추가하고 Undo/Redo, Save As,
  재열기까지 연결한다. Doodad는 footprint의 모든 `MTXM`과 overlay가 원자적으로
  왕복하고 관련 없는 CHK 바이트가 바뀌지 않는지 비교한다.
- 최소 2,000개 항목의 가상 grid에서 팝업 첫 표시, 빠른 검색, 연속 스크롤과
  썸네일 cache 메모리를 debug/profile로 계측하고 측정 환경·상한을 별도 성능
  문서에 기록한다. 자동 상한은 첫 기준 측정 뒤 CI 변동 폭을 반영해 확정한다.
- 로컬 설치 스모크는 각 tileset에서 Tile/Doodad 하나와 Unit/Sprite 대표 항목을
  실제 이미지로 선택·배치하되 게임 자산이나 결과 맵을 저장소에 추가하지 않는다.

완료 조건:

- 사용자가 숫자 ID를 직접 입력하지 않고 실제 이미지 팝업에서 네 종류를 찾고
  선택해 캔버스에 배치할 수 있다.
- 현재 맵에 없던 Unit·Sprite도 검증된 기본 레코드로 생성되고 다시 열 수 있다.
- Doodad의 지형과 overlay가 올바른 위치에 함께 표시되며 Undo/Redo와 Save As에서
  부분 적용이 발생하지 않는다.
- 자산 누락·손상·미지원 항목은 팝업 전체를 막지 않고 해당 항목만 비활성화한다.
- 팝업을 열거나 항목을 둘러보는 행위만으로 문서가 dirty 상태가 되지 않는다.
- 가상화·검색·cache가 문서화된 성능 상한을 통과하고 실제 설치 스모크 증거가 있다.

## M7. 일반 트리거

목표: 일반 트리거를 구조적으로 편집하면서 원시 표현을 확인할 수 있게 한다.

- [ ] `TRIG`와 관련 문자열/로케이션 참조 모델 구현
- [ ] 플레이어/조건/액션 구조 편집 UI
- [ ] 복사, 이동, 활성/비활성, 일괄 소유자 변경
- [ ] 원시 트리거 바이트/텍스트 검사 뷰
- [ ] 지원하지 않는 조건/액션의 무손실 보존
- [ ] 참조 무결성과 제한값 검증
- [ ] 일반 트리거와 EUD 생성 트리거의 경계 정책 확정

완료 조건:

- 일반 트리거를 추가·수정·삭제하고 다시 열 수 있다.
- 지원하지 않는 트리거 레코드가 손실되지 않는다.
- 잘못된 참조가 저장 전에 진단된다.

## M8. 안정화와 배포

목표: 실제 제작에 시험 사용할 수 있는 Windows 프리뷰를 배포한다.

- [ ] 자동 저장과 충돌 복구
- [ ] 크래시 로그와 개인정보 제거 기능
- [ ] 대용량 맵 성능 프로파일링
- [ ] 키보드 접근성 및 고대비 확인
- [ ] 외부 도구/라이브러리 라이선스 고지
- [ ] Windows 패키징과 깨끗한 PC 설치 테스트
- [ ] 버전, 변경 기록, 마이그레이션 정책
- [ ] 대표 맵 수동 회귀 테스트
- [ ] StarCraft: Remastered 실제 실행 스모크 테스트

완료 조건:

- 새 Windows 환경에서 설치·실행·제거가 가능하다.
- MVP 흐름이 릴리스 패키지에서 재현된다.
- 알려진 데이터 손실 결함이 없다.
- 외부 구성요소 버전과 라이선스가 배포물에 기록된다.

## 장기 후보

- 시각적 EUD 블록/템플릿
- epScript 언어 서버와 심볼 탐색
- StarCraft 테스트 실행과 로그 연결
- 지형 대칭, 고급 브러시, 타일 적합성 도구
- 다중 문서와 diff/merge
- 플러그인 API
- StarCraft 1.16.1 호환 프로필
- macOS/Linux 읽기 전용 도구
