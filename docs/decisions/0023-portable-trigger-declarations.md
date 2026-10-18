# ADR-0023: 일반 TRIG의 버전형 세 언어 선언

- Status: Accepted
- Date: 2026-10-18

## Context

FR-406/319와 기존 L0~L4는 euddraft 없이 일반 트리거를 epScript/Python/Lua로
작성·전환하고 원시 TRIG를 보존해야 한다. 전체 Python/Lua/epScript 코드를
상호 번역하거나 EUD 실행 모델을 TRIG로 근사하는 것은 승인된 범위가 아니다.
기존 typed 모델은 22조건/57액션과 참조 검증·2400바이트·원자 Undo를 제공한다.

## Decision

1. `MapScript(1, CHK_SHA256)`와 positional call/literal만 받는 선언 API를 사용한다.
   실제 언어의 함수 호출·bool·정수·주석 문법을 따르되 import/연산/변수/루프/
   사용자 함수·파일 접근을 거부한다. 공통 call AST로 세 언어를 처리한다.
2. 레코드는 `Source(index)` 또는 `New()`이며 소유자·활성·조건/액션 slot index를
   명시한다. Source는 전체 CHK의 SHA-256과 현재 immutable document에 귀속된다.
   알 수 없는 슬롯은 `RawCondition/RawAction(index)` 참조로만 복사한다.
3. 미지원 슬롯·레코드 삭제에는 미리보기와 별도 승인이 필요하다. 미지원 slot을
   새 지원 slot으로 교체하는 것도 삭제로 센다. 원시 바이트 리터럴 주입은 없다.
4. args는 기존 `ChkTrigger.makeSlot`으로 검증한다. 같은 opcode는 original slot을
   전달해 비인자/예약 bytes·flags를 유지한다. buffer는 레코드당 한 번 조립한다.
5. 일반 모드의 파서는 killable Dart isolate에 둔다. 외부 언어 런타임/euddraft/
   사용자 소스 실행은 0회다. 1Mi UTF-16 단위 입력, 64MiB CHK, 512레코드,
   깊이 8, AST 값 100000개, 작업당 5초 상한을 둔다.
6. 전환은 검증→동등성 재검사→미리보기→명시적 새 초안 채택이다. 원문·주석은
   최대 8개 이력에 보관한다. 미저장 이력을 조용히 제거하지 않으며 확인된 새 파일
   저장본만 공간을 재사용할 수 있다. 닫기는 미적용 초안과 미저장 원문 모두 보호한다.
7. `.eps/.py/.lua`는 선언 v1 소스 파일이다. EUD project schema 1/2/3과
   기존 자유 작성 EPS는 변경하지 않는다. 생성 파일은 일반 모드의 에디터 API이며
   upstream euddraft에 독립 플러그인으로 넘기지 않는다. EUD/native Python은 L5다.
8. 함수 이름·인자 순서·슬롯/owner 0-based 의미 변경은 새 MapScript 버전이
   필요하다. 미래 버전/다른 snapshot은 실패시키며 자동 migration/rebase하지 않는다.

## Alternatives

- Python `ast`는 실제 Python 문법에 적합하지만 앱 런타임에 Python 설치·실행
  경계를 추가한다. Lua 전체 AST 라이브러리도 배포/버전 의존성이 필요하다.
- epScript DLL은 구문 변환을 제공하지만 그 출력 Python을 실행하는 경로는
  일반 모드의 실행 0회 원칙과 다르다. 세 언어 전체 AST를 허용한 뒤 위험 노드를
  제거하기보다, 작은 버전형 API의 bounded call AST만 앱에서 인수한다.
- 따라서 앱 의존성은 추가하지 않는다. 실제 Python AST·epScript DLL·Lua luac는
  **개발 검증용 syntax oracle**로만 사용한다. epScript API 이름은 검사 환경에
  명시적으로 등록한다. 사용자 코드/생성 Python을 실행하지 않는다.
- source 정규식 치환, eval/exec, 임의 코드를 JSON으로 실행시켜 얻는 방식은 배제했다.

## Consequences

일반 트리거 제한 선언은 세 언어로 전환되지만 범용 언어 변환은 아니다. 이름
대신 리소스 숫자 ID를 사용하며 신규 문자열은 기존 Resources 도구로 만든다.
canonical 출력은 주석/공백의 완전 왕복을 보장하지 않는다. 새 파일 저장은
기존 임시 출력·검증·비덮어쓰기 승격을 재사용한다. 가져온 파일도 덮어쓰지 않는다.
미적용 스크립트의 crash 복구/장기 workspace·전체 EUD 언어 전환은 별도 후속이다.

## Validation

[실행·시나리오·한계](../TRIGGER_SCRIPT_LANGUAGES.md)를 따른다. 전체 opcode의
세 언어 byte-exact, 실제 세 frontend syntax, 실제 자체 제작 MPQ Save As,
isolate 취소/timeout, 원문·파일 보존, 한국어/영어 UI를 분리 검증한다.
Lua 검증 도구만 공식 5.4.9 SHA-256으로 고정해 개발 캐시에 빌드하며 배포하지 않는다.
일반 앱은 Lua/Python을 로드하지 않으며 MIT 고지인 기존 re_highlight와
동봉 euddraft의 라이선스 정책도 바꾸지 않는다.
