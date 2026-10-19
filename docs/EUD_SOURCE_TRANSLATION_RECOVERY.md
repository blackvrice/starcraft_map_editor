# EUD 소스 번역·Python 진입점·초안 복구

2026-10-19. 구현, 자동 검증, 게임/배포 인수를 구분한다.

## 요구사항과 실행 계획

| 요구 | 구현과 승인 기준 |
| --- | --- |
| 자유 EUD 자동 번역 | 공식 epScript 컴파일러로 EPS→Python, 변수/조건/반복 포함. 사용자 코드 실행 없이 읽기 전용 미리보기와 새 파일 내보내기 |
| 정식 Python 진입점 | .py 생성/열기/강조/완성/Save As/복구, Python 전용 빌드 프로필, 실제 euddraft 맵 빌드/재열기 |
| 공통 언어 변환 | epScript/Python/Lua 액션·훅 프로필의 정규 모델/왕복 동등성 검사. 미지원 구문 거부 |
| 미적용 초안 crash 복구 | 현재 원문·언어·최초 표시 소스·미저장 원문 이력·정확한 CHK 기준을 저장. 강제 종료 후 명시 복구, 자동 Apply 금지 |

- [x] 공식 EPS→Python 변환과 원문 불변/오류 거부
- [x] 정식 Python entry의 편집·새 파일·안전 빌드/재열기
- [x] 공통 액션·훅 프로필의 세 언어 왕복과 지원 밖 코드 거부
- [x] 미적용 초안/원문 이력의 verified checkpoint·강제 종료 후 수동 복구

실행 순서: 가이드/기존 일반 언어·EUD·복구 소스 분석 → 계층/포맷/안전 계약 →
초안 소유권과 복구 schema → Python 빌드/편집 → 제한 공통 모델 → 공식 compiler
helper → 회귀/실제 빌드/강제 종료 → 전체 게이트 → 문서/범위별 커밋·푸시.

## 지원표

| 입력 → 출력 | 지원 |
| --- | --- |
| 자유 epScript → Python | 동봉 0.10.2.5의 공식 compileString. 공개 이름 inventory에 없는 외부 API/구문은 오류로 거부하며 원문 불변 |
| 공통 액션·훅 epScript/Python ↔ epScript/Python/Lua | PortableEudScript v1. onPluginStart/beforeTriggerExec/afterTriggerExec, 순서 있는 액션·정수·문자열·bool·허용 상수·정수 EPD |
| 임의 Python → epScript/Lua, 임의 Lua → EUD | 미지원. 동적 코드/임의 import/클래스/표현식을 추측해 번역하지 않음 |
| Python EUD 빌드 | 네이티브 euddraft .py 로더. 원본 없는 새 초안은 먼저 Save As, 빌드는 명시적 신뢰 확인 필요 |
| Lua EUD 빌드 | 미지원. Lua 출력은 공통 소스 교환용이며 native Lua runtime을 제공하지 않음 |

공식 compiler 출력은 사람이 작성한 Python과 임의의 양방향 자동 동기화를
약속하지 않는다. 읽기 전용 변환 결과를 새 파일로 저장하고 직접 선택하여 연다.
원문/주석은 원본 편집 문서에 그대로 남으며 원본 파일은 덮어쓰지 않는다.
의존 파일은 복사하지 않으므로 import를 사용하는 소스는 적절한 소스 루트에
의존 파일을 유지해야 한다. 생성 코드의 독립 검증과 실제 게임 인수는 별개다.

## 설계와 안전 경계

- UI → EudSourceController → EudSourceTranslationGateway → 별도 helper 순서다.
  도메인의 PortableEudScript는 Flutter/파일/FFI/프로세스를 사용하지 않는다.
- native helper는 실행 파일 옆의 고정 bundle DLL만 로드한다. Dart가 사전에
  앱에 컴파일된 bundle 신뢰 목록/해시와 버전을 검사한다. 사용자 DLL 경로,
  PATH 검색, source eval/exec/import, 결과 Python 실행을 사용하지 않는다.
- helper가 registerPlibConstants/자체 Python keyword·builtin inventory를 설정한
  뒤 compileString/freeCompiledResult/getErrorCount만 호출한다. 사용자 코드를
  실행할 Python VM 자체가 없다. 문법 오류는 생성 결과를 폐기한다.
- 프로세스 timeout 5초, 취소/동시 요청 차단, 입력·출력 크기 제한을 둔다.
  stdout JSON protocol v1과 stderr 원시 로그를 분리하고 도구 버전을 반환한다.
  일반 TRIG 전환 경로는 계속 외부 compiler 실행 0회다.
- 소스/저장/분석 상한은 1Mi UTF-16 문자, helper UTF-8 입력 4MiB/JSON 6MiB,
  native 출력 4MiB, 부모 stdout 8MiB/stderr 64KiB다. 초과는 오류다.
- Python 액션 문장은 DoActions로 감싸야 한다. 공통 Python 프로필은
  `from eudplib import *`, `@EUDFunc`, 4칸 들여쓰기 훅과 명시 pass를 사용한다.
  기본 Python 표현식만으로 액션이 실행된다고 가정하지 않는다.
- Save As는 언어/확장자 일치·기존 파일 거절·임시 출력/재검증/승격을 따른다.
  늦은 저장 완료가 새 텍스트를 clean 처리하지 않으며 늦은 번역은 거부한다.
- Python 프로필도 기존 원본/출력 분리·경로 루트·fingerprint·도구 재검증·
  임시 MPQ 재열기·승격 정책을 공유한다. 설정 플러그인은 사용자 entry보다 앞선다.
  프로젝트 v1/v2/v3 형식은 설정 전용이므로 변경하지 않는다.

## 초안 복구 계약

TriggerScriptDraftWorkspace는 문서별 소유이며 모달 dispose와 별개로 유지된다.
dirty 현재 소스와 내보내지 않은 원문 이력을 RecoverySnapshot schema v2에 담는다.
초안이 없으면 기존 schema v1을 쓰며 v1 읽기도 유지한다. 동일 LocalRecoveryStore의
체크섬·append-only 세대·flush/재검증·부분 파일 제외·보관 개수 정책을 재사용한다.

초안 변경은 자동 저장이 켜졌을 때 500ms debounce 뒤 checkpoint를 요청한다.
transaction/진행 중 작업/I/O 중이면 기존 주기에서 다시 시도한다. 전원 차단이나
완료 전 강제 종료의 마지막 입력까지 무손실이라고 보장하지 않으며 마지막 **검증
완료된** 세대를 복구한다. 자동 저장 off·디스크 오류는 복구 보장 대상이 아니다.

schema에는 정확한 기준 CHK bytes, 현재 text/language, loadedText와 미저장 원문
최대 8개가 들어간다. 텍스트 각 4Mi UTF-16, 기준 CHK 64MiB, 전체 복구 파일
기존 192MiB 상한을 유지한다. 분석 상한을 넘은 초안도 4Mi까지 복구한다.
더 큰 붙여넣기는 잘라내지 않고 이전 복구본을 유지하며 제한 오류를 표시한다.

복구 목록에서 명시적으로 선택한 뒤 트리거 코드 창을 열면 초안을 불러온다.
CHK가 정확히 같을 때만 현재 문서 identity에 결합한다. 다르면 stale로 표시하고
Apply를 차단한다. 복구 자체는 분석/빌드/코드 실행/맵 적용/원본 쓰기를 하지 않는다.
미적용 초안이 있으면 문서는 dirty로 남으며 일반 닫기에서도 보호한다.
명시적 버리기/모든 원문 내보내기와 단순 모달 dispose를 구분한다.

## 시나리오·결과·분석

| 시나리오 | 확인 내용 |
| --- | --- |
| 언어 의미 | 세 언어 9방향 왕복, 액션 이름/상수/숫자/문자열·훅 순서, 잘못된 wrapper 거부 |
| 불확실 구문 | import/변수/연산/동적 호출/중복 훅/빈 Python/잘못된 들여쓰기·예산을 공통 프로필에서 거부 |
| 실제 자유 코드 | 변수·for·if EPS를 동봉 DLL로 Python 변환, compiler 오류/미등록 함수/취소/후속 정상 요청 |
| 실제 빌드 | 기존 EPS, 공통 Python, 자유 EPS compiler 출력 Python 세 가지 실제 euddraft build/promote/reopen |
| 원본 보존 | 위 실제 빌드에서 원본 MPQ/소스와 도구 설치 전체 해시 불변 |
| 소스 파일 | Python 생성·Save As/열기·복구, dirty 열기 거부, Lua native 진입 거부, 늦은 저장/번역 차단 |
| 설정 조합 | generated settings가 native Python entry보다 먼저 기록되고 사용자 소스 불변 |
| 모달 수명 | 원문/오류 초안/언어는 dispose 이후 유지, 명시 버리기만 복구 상태 제거 |
| 새 컨트롤러 복구 | 깨끗한 맵의 미적용 초안도 checkpoint, 수동 복구와 기준 불일치 Apply 차단 |
| 실제 강제 종료 | 별도 Dart 프로세스에서 verified checkpoint flush 후 프로세스 kill, partial 세대 제외·원문/언어 이력 보존 |
| UI | 600px 한국어/1200px 영어 언어 선택·starter·열기·저장·번역 preview/export 무변경 |

초기 집중 102개·추가 71개와 UI 2개, 실제 통합 5개를 통과했다. 실제 통합은
Windows 자체 제작 fixture만 사용하며 사용자의 열린 앱/게임을 조작하지 않았다.
검출·수정: 늦은 Save As의 clean 오인, Py bare action 의미 손실 방지,
줄바꿈/들여쓰기의 UTF-16 진단 위치, 큰 초안 붙여넣기 시 복구 예산 초과의
UI 예외, 취소한 compiler의 다음 요청 오염 방지와 저장 언어 변경 차단.
최종 전체 게이트는 아래 기록을 따른다.

실제 도구 근거: [고정 euddraft Python/EPS 로더](https://github.com/armoha/euddraft/blob/v0.10.2.5/pluginLoader.py),
[공식 epScript 문법](https://github.com/armoha/euddraft/wiki/epScript-Basics).
실제 동작의 근거는 저장소 integration 테스트와 실행 로그다.

다중 파일 workspace/LSP/source map·임의 Python/Lua 역변환·실제 앱/SC:R·외부
에디터/clean Windows 배포·전원 차단 전체 행렬은 이번 완료 범위가 아니다.
설치 SDK는 Flutter 3.47.5/Dart 3.13.4로 기준 3.44.8/3.12와 다르다.

## 재현 명령

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build windows --debug
ctest --test-dir build/windows/x64 -C Debug --output-on-failure

$env:EUD_TRANSLATE_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/eud_source_translate_helper.exe').Path
$env:EUDDRAFT_TEST_INSTALLATION = (Resolve-Path 'build/windows/x64/runner/Debug/tools/euddraft/0.10.2.5-editor.1').Path
$env:EUDDRAFT_TEST_BUNDLED = '1'
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
$env:DART_EXECUTABLE_PATH = Join-Path (Split-Path (Get-Command flutter).Source) 'cache/dart-sdk/bin/dart.exe'
flutter test test/integration/eud_source_translation_smoke_test.dart test/integration/real_euddraft_build_smoke_test.dart test/integration/trigger_draft_crash_recovery_test.dart
```

## 최종 게이트

| 검사 | 결과 |
| --- | --- |
| `flutter analyze` | 무이슈 |
| 기본 `flutter test` 최종 재실행 | 2,544 통과 / 79 환경 조건부 skip / 실패 0, 3분 55초 |
| 초안 debounce/off/쓰기 실패 | 별도 1개 통과 후 위 전체 실행에도 포함 |
| 전체 비쓰기 포맷 검사 | 597개 검사. 기존 미수정 인프라 테스트 3개 차이로 exit 1; 이번 변경 파일 차이 없음 |
| 로컬 문서 링크 | 변경 문서 최종 567개 대상 확인 |
| Windows Debug 최종 빌드 | 성공, 36.5초. 앱 실행 파일과 번역 helper 포함 |
| native CTest | 7/7 통과, 0.53초 |
| 실제 통합 최종 재실행 | 5/5 통과, 16초. EPS→Python 오류/취소/timeout·3경로 맵 빌드/재열기·강제 종료 복구 |

포맷 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자 수정/스테이징을 보존했다. 79개 skip 중 이번 추가 도구 조건은 compiler
helper/강제 종료 2개와 기존 실제 build의 추가 Python 경우 2개다. 실제 도구를
설정한 위 별도 실행에서 실제 build 3가지와 새 두 조건을 모두 통과했다.
기존 CascLib CMake 최소 버전 경고는 남는다. 기준 SDK·실제 앱 조작/SC:R·외부
에디터·깨끗한 PC·전원 차단 전체 행렬은 미실행이며 기능 테스트 통과로 대체하지 않는다.

최적화 판단: 공통 parser는 기존 bounded call AST를 재사용한다. 초안 변경 때
CHK를 매번 직렬화하지 않고 불변 기준 문서를 보관하고, checkpoint의 큰 JSON은
isolate에서 만든다. 파일 검증/프로세스 stdout·stderr도 상한을 둔다. 대용량
문서의 release RSS/다중 파일 인수까지 완료했다고 확장 해석하지 않는다.

원시 실행 로그는 `.dart_tool/eud_completion_analyze_final.log`,
`eud_completion_all_tests_final.log`, `eud_completion_format_final.log`,
`eud_completion_focused{,2,3}.log`, `eud_completion_widget.log`,
`eud_completion_debounce.log`, `eud_completion_windows_final.log`,
`eud_completion_ctest.log`, `eud_completion_real_final.log`에 있다.
