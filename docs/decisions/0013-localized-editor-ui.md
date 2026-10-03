# ADR-0013: 시스템 언어를 따르는 현지화 UI (한국어·영어)

- Status: Accepted
- Date: 2026-09-28

## Context

메인 화면의 메뉴·안내·오류 문구가 영어로 하드코딩되어 있어 한국어 사용자가
작업 흐름을 이해하기 어려웠다. 개발 워크플로는 "사용자에게 보이는 문자열은
향후 현지화를 고려해 분리한다"고만 정했고, 문자열 저장 위치와 언어 선택 규칙은
정하지 않았다. 기존 위젯 테스트 수천 줄이 영어 문구로 화면을 찾는다.

## Decision

- Flutter 공식 `flutter_localizations`와 `gen-l10n`(`l10n.yaml`)을 사용한다.
  원본은 `lib/l10n/app_en.arb`(템플릿)와 `app_ko.arb`이며 생성 파일
  `lib/l10n/app_localizations*.dart`도 저장소에 포함해 SDK 버전에 따른 생성
  시점 차이 없이 analyze/test가 동작하게 한다. ARB를 바꾸면 `flutter gen-l10n`
  또는 `flutter pub get`으로 다시 생성해 함께 커밋한다.
- 기본값은 **시스템 언어 따르기**다. `MaterialApp.locale`을 `null`로 두어 Windows
  표시 언어를 따르고, 지원하지 않는 언어는 영어로 대체한다.
- 사용자는 `Edit → Language` 또는 도구 모음의 언어 버튼에서 시스템 언어 따르기,
  한국어, English를 고른다. 선택은 즉시 적용되며 재시작이 필요 없다. 값은 기존
  사용자 설정 저장소의 `uiLanguage` 키에 `ko`/`en`으로 저장하고 시스템 언어
  따르기는 키를 지운다. 저장 실패는 화면 언어를 되돌리지 않고 안내만 한다.
- 선택 목록의 언어 이름은 현재 UI 언어와 무관하게 자기 언어 이름(한국어,
  English)으로 표시해 잘못 고른 언어에서도 되돌아갈 수 있게 한다.
- 애플리케이션 계층의 `AppLanguageController`는 Flutter에 의존하지 않고 언어
  코드만 다룬다. `Locale` 변환과 `context.l10n`은 presentation 계층에 둔다.
  `context.l10n`은 현지화 위임자가 없는 호스트에서 영어로 대체한다.
- 진단 **코드**와 CHK 섹션 이름, epScript/euddraft 원시 로그는 번역하지 않는다.
  도메인·애플리케이션 계층이 만드는 진단 메시지는 이번 단계에서 영어로 유지한다.
- 1단계 범위는 메인 셸(메뉴, 도구 모음, 작업 공간 레일, 레이어·팔레트, Inspector,
  Problems/Output/Build Log, 상태 표시줄, 시작 화면)이다. 설정 대화상자, 트리거·
  리소스·EUD 패널, 카탈로그는 후속 단계에서 같은 ARB로 옮긴다.

- 2026-09-30 후속: 새 맵 마법사, 배치 카탈로그, EUD 빌드 단계, 트리거, EUD 확장
  프로젝트 화면을 같은 ARB로 옮겼다. 트리거 opcode·플레이어 값과 EUD 필드·실행 규칙
  이름은 도메인 모델이 영어 이름과 안정 ID를 유지하도록 presentation 계층의 표시
  표(`TriggerLabels`, `EudFieldLabels`, `EudRuleLabels`)에서 번역하고, 표에 없는
  값은 도메인 이름을 그대로 보여준다.

### 2026-10-03 후속 결정

- 설정·리소스·브리핑 세부·epScript 화면을 기존 ARB에 통합한다. 유닛/테크 등의
  기본 게임 이름과 사용자 문자열, 소스 코드, 경로, 원시 로그는 번역하지 않는다.
- `EditorDiagnostic`에 선택적 `messageId`/`messageArguments`와
  `remediationId`/`remediationArguments`를 둔다. 도메인은 Flutter나 로캘에 의존하지
  않으며 영어 원문·코드·위치·rawDetails를 보존한다. 내장 진단은 표시 계층에서
  ID를 해석하고, 알 수 없는 ID나 인자 불일치는 원문으로 대체한다.
- `tool/generate_editor_messages.dart`가 ARB에서 ID 해석기와 기존 편집기 소유
  라벨/검증 문구의 호환 어댑터를 생성한다. 호환 어댑터는 전체 문자열에 일치하는
  알려진 문구만 처리하며 사용자 데이터나 원시 로그에 사용하지 않는다.
- 컴파일러의 소스 오류 메시지는 원문을 유지한다. EUD 준비 화면은 구조화된 진단과
  원시 로그를 별도로 표시한다. 설정 작업의 구분은 번역된 라벨이 아닌 안정 Key로 한다.
- 회귀 테스트와 Windows 실제 글꼴 렌더링 검증은 [번역 계약](../LOCALIZATION.md)을 따른다.

## Alternatives

- `intl` 메시지를 직접 작성하거나 자체 문자열 맵을 두는 방식은 생성기 검증과
  복수형·자리표시자 형식 검사가 없어 누락을 찾기 어렵다.
- 앱 재시작 후 적용하는 방식은 구현이 단순하지만 사용자가 선택 결과를 즉시
  확인할 수 없어 택하지 않았다.
- 테스트의 영어 문구를 모두 Key로 바꾸는 방식은 변경 범위가 과도하다. 테스트
  기본 로캘(en-US)이 영어를 선택하므로 기존 테스트는 그대로 유지한다.

## Validation

`test/application/app_language_controller_test.dart`가 저장값 복원, 알 수 없는 값의
시스템 대체, 로딩 중 선택 우선, 저장 실패 시 즉시 적용을 검사한다.
`test/widget/editor_shell_test.dart`는 저장된 한국어 표시, 한국어 시스템 로캘 추종과
지원하지 않는 로캘의 영어 대체, 도구 모음에서 언어 전환·저장·시스템 복귀를 검사한다.
