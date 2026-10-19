# 일반 트리거 언어 전환

## 실행 계획과 현재 범위

2026-10-18 FR-406/319 / L0~L4의 **일반 TRIG 제한 선언**을 구현했다.
트리거 목록의 코드 버튼에서 epScript/Python/Lua 선언을 수정하고 다른 언어로
미리보기·채택·적용할 수 있다. 일반 맵 저장에는 euddraft가 필요하지 않다.

1. 소스 분석: TriggerOpcodes/ChkTrigger·TRIG 변경 명령·원시 bytes/참조 검증,
   기존 EUD 소스/빌드의 EPS 제한과 Windows 파일 dialog를 확인했다.
2. 요구사항·설계: 세 언어 동일 선언 모델, raw snapshot 귀속, 부분 변환 거부,
   원문 보관/dirty 충돌, 명시적 적용·새 파일 저장과 실행 0회 계약을 정했다.
3. 구현: 제한 call AST 파서/formatter·프로필 v1, 격리 분석 포트, 초안 controller,
   세 언어 구문 강조/완성·진단/미리보기 UI와 비덮어쓰기 파일 저장을 연결했다.
4. 검증: 전체 opcode/10사례·실제 언어 구문 검사·원자 Undo·취소/늦은 응답,
   파일/MPQ 왕복·좁은 화면과 대형 입력을 검사한다. 결과는 아래에 남긴다.

결정은 [ADR-0023](decisions/0023-portable-trigger-declarations.md)을 따른다.
**자유 작성 EUD EPS/Python, 공통 EUD backend·native `.py` entry, 전체 Lua
프로그램의 자동 번역을 완료했다는 뜻이 아니다.** 기존 EPS/EUD 빌드는 그대로다.

## 선언 프로필 v1

세 언어는 같은 함수 API를 사용한다. 차이는 주석(`//`, `#`, `--`), bool
(`true/false`, Python `True/False`), epScript의 필수 문장 끝 `;`다.
정수는 0~4294967295의 10진수 또는 `0x` 16진수다. 위치/열 진단은 UTF-16이다.

Python 예시의 hash는 실제 편집기가 생성한 원본 값을 유지해야 한다:

```python
MapScript(1, "<current CHK SHA-256>")
MapTrigger(
    Source(0),
    Owners(0),
    Enabled(True),
    Conditions(ConditionAlways(0, True)),
    Actions(ActionWait(4, True, 2000), ActionPreserveTrigger(9, True))
)
```

| API | 의미 |
| --- | --- |
| MapScript(version, hash) | 한 파일 첫 선언. 미래 버전·다른 CHK snapshot 거절 |
| MapTrigger(source, owners, enabled, conditions, actions) | 출력 순서대로 TRIG 1건 |
| Source(index) / New() | 원본 레코드의 예약 데이터 보존 / 명시적 새 레코드 |
| Owners(ids...) | Player 1=0부터 11, All players=17, Force 1~4=18~21. 기존 비정규 nonzero 값은 bool 의미가 같으면 유지 |
| Enabled(bool) | trigger 비활성 bit만 변경, 나머지 실행 flags 보존 |
| Conditions(calls...) / Actions(calls...) | slot은 0-based. 조건 0~15, 액션 0~63. 빈 slot을 압축하지 않음 |
| Condition… / Action…(slot, enabled, args...) | 기존 22조건/57액션. 인자 순서는 TriggerOpcodes의 순서. 리소스는 숫자 ID |
| RawCondition(slot) / RawAction(slot) | 해당 Source의 미지원 slot bytes만 읽기 전용 복사 |

예를 들어 `ActionWait(4, True, 2000)`은 액션 slot 4의 대기 시간을 2000ms로
지정한다. Wait/Preserve/플레이어/레코드/슬롯 순서를 바꾸지 않으며 OR/루프를
자동 트리거 복제로 바꾸지 않는다. record/owner/slot 중복 및 잘못된 리소스 참조는
거절한다. 미지원 값이나 EUDX를 알 수 있는 값으로 추정하지 않는다.

### 지원과 미지원

- 지원: 명시적 트리거 추가/삭제/재정렬, owner/활성·slot/조건/액션·리터럴 인자,
  미지원 원시 slot 보존, 의미가 같은 세 언어 전환.
- 미지원: 변수/대입·사용자 함수/import·배열/테이블·일반 if/루프·연산식·런타임
  truthiness·직접 문자열 생성·임의 raw bytes·EUD 코드에서 일반 TRIG로 자동 강등.
- Source는 전체 CHK hash에 묶인다. 맵을 GUI에서 바꾸면 원문을 유지한 채
  stale로 차단한다. 다른 맵/수정된 맵에서 저장 소스를 자동 재기준화하지 않는다.
- 슬롯이 알려진 opcode라도 기존 인자/참조 검증을 통과하지 못하면 raw 참조로
  유지한다. 같은 opcode의 수정은 non-argument bytes까지 보존한다.
- 미지원 슬롯 삭제/교체와 전체 레코드 삭제를 계산해 별도 체크박스 승인을
  요구한다. 알려진 슬롯만의 명시적 수정/삭제는 일반 변경 미리보기로 처리한다.
- MBRF는 기존 GUI를 유지하며 이번 TRIG 언어 프로필의 대상이 아니다.

## 편집·원문·파일 수명

변환 미리보기는 맵이나 편집 중 원문을 바꾸지 않는다. **전환 소스 사용**에서
검증된 새 언어 초안을 만들고 원문/주석을 보관한다. 적용은 별도 검증 뒤 기존
`ObjectEditingController.applyTriggers`의 한 Undo로 수행한다. 변환만으로
dirty/리소스/맵 bytes/Undo를 바꾸지 않는다.

원문 보관함은 최대 8개다. 내보내기 확인을 받은 원문만 공간을 재사용하며,
미저장 원문을 조용히 없애지 않는다. 더 보관할 수 없으면 작업을 차단한다.
맵에 적용되어 초안이 clean이어도 미저장 원문/주석이 있으면 닫기 확인을 요구한다.
새 파일 저장 후 닫기는 남은 원문도 각각 저장한다. 취소/쓰기 실패는 닫지 않는다.
사용자가 명시적으로 버리는 경우만 해당 세션의 보관본을 없앨 수 있다.

열기/저장은 `TriggerScriptFiles` 포트와 Windows dialog를 사용한다. UTF-8 원문과
CRLF를 읽고 `.eps/.py/.lua`와 선택 언어를 대조한다. 링크·잘못된 UTF-8·상한
초과를 거절한다. 저장은 **새 파일만** 허용하며 임시 출력→재읽기→비덮어쓰기
승격→재검증한다. 기존 파일, 원본 맵, 가져온 소스를 덮어쓰지 않는다.

2026-10-19부터 미적용 초안/원문은 [복구 schema v2](EUD_SOURCE_TRANSLATION_RECOVERY.md)에
포함된다. 완료된 checkpoint 뒤 강제 종료 복구를 검증했다. 전원 차단 전체
행렬과 여러 소스 workspace는 여전히 후속이다.
정상 닫기/앱 종료는 source 보존 확인 또는 대화상자 종료를 먼저 요구한다.

## 파서·성능·보안

파서는 문자열 치환이 아닌 call/literal AST를 만든다. 외부 언어를 평가하지 않고
isolate에서 구문·기존 opcode 인자 검증·대상 언어 재파싱·바이트 동등성을 검사한다.
취소/초안/맵 변경·폐기 후의 결과는 적용하지 않는다. 일반 경로의 eval/exec/
프로세스·Python/Lua 런타임·euddraft 호출은 0회다.

입력 최대 1Mi UTF-16 단위, CHK 최대 64MiB, TRIG 최대 512건, 중첩 8, AST 값
100000개, 작업당 5초를 적용한다. 초과하면 기존 GUI/맵/원문을 그대로 유지하고
미지원 상태를 표시한다. 구문 강조는 기존 200000자 초과 시 plain text fallback이다.
isolate 경계를 보안 sandbox로 부르지 않으며 자유 EUD 빌드의 신뢰 정책도 유지한다.

구현 중 반복된 전체 레코드 복사를 찾아 레코드당 buffer 1개로 조립하도록
최적화했다. 512건의 세 언어 format/parse/동등성 debug 스모크는 집중 실행에서
290ms였다. 5초 상한 검출용이며 프레임/RSS/clean PC release 보장이 아니다.

## 실제 문법 검증과 라이선스

앱에는 새 파서/런타임 의존성을 추가하지 않았다. 기존 MIT re_highlight의
Python/Lua 표시 문법을 재사용하고 EPS 기본 강조/완성/IME 동작을 유지한다.
개발 검증은 다음 실제 frontend를 사용한다:

- Python 3.12 `ast.parse`: 소스 실행/임의 import 없이 구문만 검사.
- 동봉 euddraft 0.10.2.5의 epScript DLL `compileString`: 편집기 API 이름을
  검사 환경에 등록한 뒤 변환한 Python도 `ast.parse`만 수행한다.
- 공식 Lua 5.4.9 `luac -p -`: 구문만 검사. URL과 SHA-256을 CMake에 고정하고
  `.dart_tool`에만 빌드한다. 앱에 Lua binary/source를 배포·링크하지 않는다.

API 이름을 등록하지 않은 epScript 검사에서는 undefined function 오류를
확인했다. 이 이름들은 에디터 선언 API이지 upstream 기본 함수가 아니므로
등록 환경을 명시해 검사했다. 출력 소스를 독립 EUD 플러그인으로 실행하는
wrapper/import는 제공하지 않으며, 일반 저장은 이 검사 도구를 요구하지 않는다.

근거: [epScript 문법](https://github.com/armoha/euddraft/wiki/epScript-Basics),
[euddraft 고정 로더](https://github.com/armoha/euddraft/blob/v0.10.2.5/pluginLoader.py),
[Python 호출 문법](https://docs.python.org/3.12/reference/expressions.html#calls),
[Lua 문법](https://www.lua.org/manual/5.4/manual.html#3.4.10),
[Lua 공식 버전·SHA-256](https://www.lua.org/ftp/),
[Lua MIT 고지](https://www.lua.org/license.html).

## 시나리오와 실행 결과

| 사례 | 검사 |
| --- | --- |
| 1 무수정 왕복 | 세 언어 TRIG bytes/예약 값/nonzero owner 동일 |
| 2 인자 변경 | Wait u32에 지정된 4바이트 외 불변 |
| 3 owner·순서·활성 | 재정렬/새 레코드·비활성 상태·slot gaps |
| 4 전체 opcode | 22조건/57액션의 모든 인자와 세 언어 왕복 |
| 5 원시/EUDX | 읽기 전용 참조·잘못된 참조·명시 삭제 승인 |
| 6 손상·중복 | TRIG/owner/slot/Source 중복·missing/truncated 거절 |
| 7 언어 전환 | EPS→Python→Lua→EPS 의미 동일·원문/주석 보관 |
| 8 위험 문법·자원 | import/exec/require/연산·0 bool 거부, 깊이/크기·취소/timeout |
| 9 초안 충돌 | 맵/소스 변경·늦은 응답·Dispose·Undo/재기준화 |
| 10 실제 저장/도구 | 같은 CHK의 실제 MPQ Save As·원본 보존, 실제 세 언어 syntax |

집중 6개 파일 117 통과/1 조건부 skip(Windows 링크 생성 권한). 실제 syntax
스모크 1개와 실제 자체 제작 MPQ 스모크 1개 통과. 600px 한국어/1200px 영어에서
전환·채택·적용과 dirty 닫기/진단 이동을 확인했다. 정적 분석 무이슈다.

검출·수정: 선행 주석 없는 Python 소스의 offset 0 경계, Windows 경로 구분자의
링크 오판정, 새 분석 결과에 대한 삭제 승인 초기화, 적용 후 미저장 원문 보호를
보완했다. 전체 게이트/Windows/native 결과는 완료 시 아래에 기록한다.
기존 인프라 테스트 3개의 포맷 차이, SDK 차이와 실제 앱/게임/배포 미실행은
자동 검증과 구분하며 L5/L6 완료로 표시하지 않는다.

### 최종 게이트

| 명령/범위 | 결과 |
| --- | --- |
| 집중 6개 파일 | 117 통과/1 skip, 링크 생성 권한 제약 |
| `flutter analyze` | 무이슈 |
| 기본 `flutter test` | 2467 통과/75 조건부 skip/실패 0, 3분 21초 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 585개 검사, 기존 미수정 3개 파일 차이로 exit 1. 이번 변경 파일 차이 없음 |
| 실제 frontend syntax + MPQ 스모크 | 최종 2/2 통과, 사용자 코드 실행 0회 |
| `flutter build windows --debug` | 성공, 20.3초 |
| 빌드 후 native CTest | 7/7 통과 |

실제 검증 도구는 Python 3.12.14, 동봉 epScript DLL, 공식 Lua 5.4.9이다.
앱 SDK는 Flutter 3.47.5/Dart 3.13.4이며 기준 3.44.8/3.12와 다르다.
기존 CascLib CMake 최소 버전 경고는 남는다. 전체 skip 75개는 기존 도구/환경
조건부 검사 72개와 새 링크 권한·실제 syntax/MPQ 환경 변수 검사 3개다.
후자의 실제 syntax/MPQ 2개는 별도 환경 설정으로 실행해 통과했다.

포맷 차이는 미수정 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자의 기존 변경은 보존했다. 실제 앱 조작/게임·외부 에디터·clean Windows,
이 단락은 2026-10-18 검증 기록이다. 미적용 선언 초안의 crash 복구는 다음 날
[추가 구현·강제 종료 검증](EUD_SOURCE_TRANSLATION_RECOVERY.md)을 완료했다.

로컬 로그: `.dart_tool/trigger_language_focused_complete.log`,
`trigger_language_analyze_complete.log`, `trigger_language_format_complete.log`,
`trigger_language_all_tests_complete.log`, `trigger_language_real_complete.log`,
`trigger_language_windows_build.log`, `trigger_language_ctest.log`.
개발 syntax oracle 재현은 `tool/trigger_script_syntax/CMakeLists.txt`와
`verify.py`, `TRIGGER_SYNTAX_PYTHON/EPS_DLL/LUAC` 환경 변수를 사용한다.
