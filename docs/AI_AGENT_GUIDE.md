# AI 에이전트 가이드

이 문서는 **어떤 AI 도구(Claude, Codex, Copilot, Cursor, Gemini 등)와 어떤
기기에서도 동일한 방식으로 이 저장소를 작업**하기 위한 단일 진입 문서다.
새 세션을 시작하는 에이전트는 이 문서를 처음부터 끝까지 읽고 시작한다.

관련 문서: [AGENTS.md](../AGENTS.md) · [문서 인덱스](README.md) ·
[개발 워크플로](DEVELOPMENT_WORKFLOW.md) · [개발 계획](DEVELOPMENT_PLAN.md)

---

## 0. 30초 요약

새 세션에서 아래 순서를 그대로 따른다.

1. `git status --short --branch`로 브랜치와 미커밋 변경을 확인한다.
2. [docs/README.md](README.md) → [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)의
   **현재 상태 표**와 **첫 번째 미완료 체크박스**를 읽는다.
3. 해당 작업과 관련된 설계 문서(아키텍처 / 파일 포맷 / EUD / UX / 테스트)를 읽는다.
4. 변경 범위를 한 개의 검증 가능한 결과로 좁힌다.
5. 코드 + 테스트 + 문서를 같은 단위로 변경한다.
6. `dart format` → `flutter analyze` → `flutter test`를 통과시킨다.
7. 변경 유형별 추가 검증(§5 표)을 실행한다.
8. 관련 파일만 커밋하고 현재 추적 원격 브랜치로 푸시한다.
9. §9 형식으로 완료 보고한다.

**별도 지시가 없으면 진행할 작업은 항상 `DEVELOPMENT_PLAN.md`의 첫 번째
미완료 체크박스다.** 임의로 다른 항목을 고르지 않는다.

---

## 1. 프로젝트 정체성

| 항목 | 값 |
| --- | --- |
| 제품 | StarCraft: Remastered UMS 맵 에디터 (EUD 편집 지원) |
| 대상 OS | Windows 10/11 x64 |
| 대상 맵 | 보호되지 않은 UMS `.scm` / `.scx` |
| UI | Flutter for Windows |
| 언어 | Dart (앱) + C++17 (네이티브 helper) |
| 도구 체인 | Flutter `3.44.8` stable / Dart `3.12` |
| EUD | epScript + euddraft / eudplib (별도 프로세스) |
| 라이선스 | MIT |
| 기본 브랜치 | `master` |

범위 밖(초기 제외): StarCraft 1.16.1 호환, macOS/Linux 배포, 보호된 맵 복구,
시각적 EUD 블록 편집기.

### 현재 상태 (2026-09 기준)

| 단계 | 상태 |
| --- | --- |
| M0 제품·기술 기준선 ~ M6.1 실제 객체 그래픽 | 완료 |
| **M6.2 시각적 배치 선택 팝업** | **진행 중 — 현재 작업 지점** |
| M6.3 이후 (설정·제작 도구·리소스·트리거·배포) | 대기 |

이 표는 요약이며 **정확한 최신 상태는 항상
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)의 "현재 상태" 표**를 기준으로 한다.
두 문서가 다르면 `DEVELOPMENT_PLAN.md`가 맞다.

---

## 2. 세션 시작 절차

### 2.1 읽기 순서

| 순서 | 문서 | 언제 필수인가 |
| --- | --- | --- |
| 1 | [AGENTS.md](../AGENTS.md) | 항상 |
| 2 | 이 문서 | 항상 (새 기기·새 도구일 때 특히) |
| 3 | [docs/README.md](README.md) | 항상 |
| 4 | [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | 항상 (작업 선택) |
| 5 | [DEVELOPMENT_WORKFLOW.md](DEVELOPMENT_WORKFLOW.md) | 항상 |
| 6 | [ARCHITECTURE.md](ARCHITECTURE.md) | 계층·경계를 건드릴 때 |
| 7 | [FILE_FORMATS.md](FILE_FORMATS.md) | CHK/MPQ 파서·저장 변경 시 |
| 8 | [EUD_INTEGRATION.md](EUD_INTEGRATION.md) | euddraft·epScript 연동 변경 시 |
| 9 | [EDITOR_UX.md](EDITOR_UX.md) | 사용자 흐름·화면 변경 시 |
| 10 | [TESTING_AND_QUALITY.md](TESTING_AND_QUALITY.md) | 검증 방법이 애매할 때 |
| 11 | [DATA_SAFETY.md](DATA_SAFETY.md) | 파일·프로세스·보안 정책 변경 시 |
| 12 | [decisions/](decisions/README.md) | 되돌리기 어려운 결정 전후 |
| 13 | [GLOSSARY.md](GLOSSARY.md) | 용어가 불확실할 때 |

### 2.2 문서 충돌 시 우선순위

1. 데이터 손실을 막는 정책
2. 검증된 실제 코드와 테스트
3. 제품 요구사항과 인수 조건
4. 아키텍처와 세부 설계
5. 개발 계획의 예상 일정과 순서

문서와 코드가 다르면 **검증된 현재 동작을 기준으로 문서를 함께 고친다.**
코드를 문서에 억지로 맞추지 않는다.

---

## 3. 새 기기 환경 구축

### 3.1 필수 소프트웨어

| 도구 | 버전 기준 | 용도 | 확인 |
| --- | --- | --- | --- |
| Windows | 10/11 x64 | 대상 플랫폼 | — |
| Git | 최신 stable | 저장소 + CMake FetchContent | `git --version` |
| Flutter | **3.44.8 stable** (Dart 3.12) | 앱 빌드·테스트 | `flutter --version` |
| Visual Studio 2022 | "Desktop development with C++" 워크로드 | MSVC C++17, 네이티브 helper | `flutter doctor` |
| CMake | **3.25 이상** | helper 빌드 | `cmake --version` |
| PowerShell | Windows PowerShell 또는 pwsh | 기준 셸, 가짜 helper 스크립트 | `$PSVersionTable` |

> Flutter 버전은 저장소 `.fvmrc`에 `3.44.8`로 고정되어 있고 CI도 같은 버전을
> 설치한다. FVM을 쓰면 `fvm use`가 자동으로 같은 버전을 선택한다.
> 다른 SDK로 작업했다면 **완료 보고에 그 차이를 반드시 기록**한다.

### 3.2 최초 셋업 (PowerShell)

```powershell
git clone <repository-url> starcraft_map_editor
cd starcraft_map_editor

flutter --version          # 3.44.8 stable / Dart 3.12 인지 확인
flutter doctor             # Windows 데스크톱 툴체인 확인
flutter pub get
flutter analyze
flutter test
flutter run -d windows     # 앱이 뜨는지 확인
```

### 3.3 네이티브 helper 빌드 (첫 빌드에 네트워크 필요)

```powershell
flutter build windows --debug
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
```

- 첫 CMake configure에서 **full commit SHA로 고정된** StormLib, CascLib,
  JSON for Modern C++를 공식 GitHub 저장소에서 가져온다. 즉 **첫 빌드에는
  인터넷 연결이 필요**하다.
- 이후 빌드는 `build/`의 FetchContent 캐시를 재사용하며, StarCraft 데이터
  helper는 고정 revision 확보 후 불필요한 Git update와 네트워크 접속을 하지
  않는다.
- 의존성 revision을 바꾸는 작업에서만 CMake cache의
  `STARCRAFT_DATA_ALLOW_CASCLIB_UPDATES=ON`을 사용한다.
- `build/`는 `.gitignore` 대상이다. 새 기기에서는 helper 빌드를 **처음부터
  다시** 해야 하며, 시간이 걸린다는 점을 작업 계획에 반영한다.

산출 helper (Debug 기준 경로):

```text
build/windows/x64/runner/Debug/map_archive_helper.exe
build/windows/x64/runner/Debug/starcraft_data_helper.exe
```

### 3.4 선택 도구 (있으면 스모크 검증 가능)

| 도구 | 없을 때 | 있을 때 |
| --- | --- | --- |
| euddraft (예: `C:\Tools\euddraft-0.10.2.5`) | 가짜 프로세스 테스트만 실행 | 실제 EUD 빌드 스모크 가능 |
| StarCraft: Remastered 설치 | 가짜 helper 테스트만 실행 | 실제 CASC 자산 스모크 가능 |

**둘 다 없어도 개발과 필수 게이트는 전부 통과할 수 있어야 한다.** 자동 테스트는
자체 제작 픽스처와 가짜 gateway/helper 스크립트
(`test/fixtures/helpers/*.ps1`)만 사용한다.

### 3.5 선택 스모크용 환경 변수

| 변수 | 값 예시 | 사용처 |
| --- | --- | --- |
| `MAP_ARCHIVE_HELPER_PATH` | `build/windows/x64/runner/Debug/map_archive_helper.exe` | 번들 아카이브 helper·실제 EUD 빌드 스모크 |
| `MAP_ARCHIVE_TEST_MAP` | `test/fixtures/maps/generated/minimal-self-authored.scx` | 번들 아카이브 helper 스모크 |
| `STARCRAFT_DATA_HELPER_PATH` | `build/windows/x64/runner/Debug/starcraft_data_helper.exe` | 번들 StarCraft 데이터 helper 스모크 |
| `STARCRAFT_TEST_INSTALLATION` | `C:\Program Files (x86)\StarCraft` | 실제 로컬 CASC 읽기 스모크 |
| `EUDDRAFT_TEST_INSTALLATION` | `C:\Tools\euddraft-0.10.2.5` | euddraft 설치 검사·실제 빌드 스모크 |

경로는 `Resolve-Path`로 절대 경로화해서 넣는다(§5 예시 참조).

### 3.6 환경 구축 완료 판정

아래가 모두 통과하면 그 기기는 "동일 작업 가능" 상태다.

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build windows --debug
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
```

이는 [Windows CI 워크플로](../.github/workflows/windows-ci.yml)와 같은 게이트다.
로컬에서 통과하지 못하면 **먼저 환경 문제를 해결하고** 코드 작업을 시작한다.

### 3.7 흔한 환경 실패

| 증상 | 원인 | 대응 |
| --- | --- | --- |
| `flutter build windows` 실패, MSVC 못 찾음 | VS2022 C++ 워크로드 누락 | `flutter doctor` 지시대로 설치 후 재시도 |
| CMake configure에서 fetch 실패 | 첫 빌드 네트워크 차단 / Git 없음 | 네트워크·Git 확인. 오프라인이면 helper 관련 작업을 보류하고 보고 |
| `dart format` CI 실패, 로컬 통과 | 대상 경로 차이 | CI와 동일하게 `lib test tool`을 지정해 실행 |
| 선택 스모크 테스트 skip | 환경 변수 미설정 | 정상. 미실행 사실을 완료 보고에 기록 |
| 버전 불일치 경고 | SDK가 3.44.8이 아님 | FVM으로 맞추거나, 차이를 보고에 기록하고 CI 결과로 재확인 |

---

## 4. 작업 루프

한 사이클은 아래 순서를 벗어나지 않는다.

1. **확인** — `git status --short --branch`. 사용자 미커밋 변경이 있으면 관련 없는
   파일을 건드리지 않는다.
2. **선택** — `DEVELOPMENT_PLAN.md`의 첫 번째 미완료 체크박스. 그 항목의 "구현
   순서" 본문을 끝까지 읽는다.
3. **설계** — 바꿀 계층, 추가할 테스트, 사용자에게 보이는 결과를 먼저 정한다.
   되돌리기 어려운 선택이면 ADR을 쓴다.
4. **구현** — §6 경계를 지키며 작은 단위로.
5. **검증** — §5 표.
6. **문서** — §8 갱신 규칙.
7. **커밋·푸시** — §7.
8. **보고** — §9.

### 좋은 작업 단위 / 피할 작업 단위

| 좋음 | 피함 |
| --- | --- |
| raw CHK 헤더 파서 + 잘린 입력 테스트 | 파서 + 전체 UI 재설계 + 패키징을 한 커밋에 |
| 문서 변경 상태와 닫기 확인 UI | 테스트 없이 여러 CHK 섹션 동시 지원 |
| euddraft 버전 검사 + 가짜 프로세스 테스트 | 관련 없는 Flutter 템플릿 플랫폼 파일 일괄 삭제 |

---

## 5. 검증 명령표

### 5.1 필수 게이트 (모든 코드 변경)

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

### 5.2 변경 유형별 추가 검증

| 변경 | 추가 검증 |
| --- | --- |
| CHK | byte-exact 왕복, 손상 픽스처 |
| 아카이브 | 실제 자체 제작 맵 Open / Save As |
| StarCraft 데이터 | 가짜 helper + 실제 로컬 CASC 선택 스모크 |
| EUD | 가짜 프로세스 + 실제 euddraft 스모크 |
| UI | 위젯 테스트 + Windows 실행 |
| 저장 | 원본 해시, 임시 출력 실패 경로 |
| 네이티브 helper | `flutter build windows --debug` + `ctest` |
| 배포 | 깨끗한 Windows 설치 테스트 |

### 5.3 명령 모음

네이티브 helper 변경:

```powershell
flutter build windows --debug
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
```

StarCraft CASC 경계 변경 (실제 설치 선택적 스모크):

```powershell
$env:STARCRAFT_DATA_HELPER_PATH = (Resolve-Path `
  "build/windows/x64/runner/Debug/starcraft_data_helper.exe").Path
$env:STARCRAFT_TEST_INSTALLATION = "C:\Program Files (x86)\StarCraft"
flutter test test/infrastructure/bundled_starcraft_data_helper_test.dart
```

euddraft 설치 검사 변경 (선택적 스모크):

```powershell
$env:EUDDRAFT_TEST_INSTALLATION = "C:\Tools\euddraft"
flutter test test/infrastructure/local_eud_tool_inspector_test.dart
```

실제 EUD 빌드 경계 변경 (자체 제작 맵 전체 스모크):

```powershell
$env:EUDDRAFT_TEST_INSTALLATION = "C:\Tools\euddraft-0.10.2.5"
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path `
  "build/windows/x64/runner/Debug/map_archive_helper.exe").Path
flutter test test/integration/real_euddraft_build_smoke_test.dart
```

EUD 문서·빌드 설정 또는 euddraft 프로세스 경계 변경:

```powershell
flutter test test/application/eud_build_configuration_test.dart `
  test/application/eud_source_controller_test.dart `
  test/application/eud_compiler_gateway_test.dart `
  test/infrastructure/process_eud_compiler_gateway_test.dart `
  test/widget/editor_shell_test.dart
```

**실행하지 못한 검증은 이유와 위험을 완료 보고에 반드시 남긴다.**
"돌렸다"고 추정해서 쓰지 않는다.

---

## 6. 아키텍처 경계와 금지 사항

### 6.1 계층

```text
presentation/   Flutter 위젯·화면          ← 파일/FFI/프로세스 직접 호출 금지
application/    컨트롤러·유스케이스·ports  ← 외부 도구는 포트 인터페이스 뒤
domain/         CHK 모델·typed view·규칙   ← Flutter/FS/FFI/euddraft 의존 금지
infrastructure/ 프로세스·파일·설정 구현    ← 포트의 실제 구현만
```

`lib/application/ports/*`가 계층 간 계약이다. 새 외부 연동은 **먼저 포트를
정의하고** `infrastructure/`에 구현한다.

### 6.2 금지 사항 (위반 시 되돌림)

**아키텍처**

- UI가 바이너리 파서, 파일 시스템, 네이티브 라이브러리, 프로세스 실행을 직접 호출
- Domain 계층이 Flutter / 파일 시스템 / FFI / euddraft에 의존
- 외부 도구를 인터페이스 없이 직접 호출 (버전·원시 로그 기록 없이)

**데이터 안전**

- 입력 `.scm` / `.scx`를 기본적으로 직접 덮어쓰기 (기본은 Save As)
- 알 수 없는 CHK 섹션, 중복 섹션, 원시 문자열 바이트를 임의로 정규화
- 손상되거나 보호된 맵을 추측으로 자동 복구
- 지원하지 않는 필드를 기본값으로 덮어쓰기
- 저장 시 "검증 → 임시 출력 → 재검증 → 원자적 교체 또는 Save As" 순서 생략

**저장소·보안**

- SC:R 원시 자산이나 추출 이미지를 저장소 fixture / 배포물에 포함
- 재배포 권한이 없는 맵 파일 추가 (직접 제작한 맵만 추가)
- EUD 플러그인·Python 코드를 신뢰할 수 있는 코드로 취급 (항상 격리 실행)

**Git**

- 명시적 승인 없는 force push, 히스토리 재작성
- 관련 없는 파일 stage

### 6.3 구현 규칙

- 바이너리 파서는 실패 위치와 안정적인 오류 코드를 반환한다.
- 사용자에게 보이는 문자열은 향후 현지화를 고려해 분리한다.
- 데이터 변경은 Undo/Redo 가능한 명령을 우선한다.
- 구조가 불명확한 값에 임의로 이름을 붙이지 않는다. 모르면 종류 + 숫자 ID로
  노출한다 (`Unit #37`, `Sprite #130`).
- 복합 배치/삭제는 부분 적용을 남기지 않는다. 거부하거나 전부 적용한다.

### 6.4 의존성 추가 전 확인

표준 라이브러리·기존 코드로 어려운가 / 최근 유지보수와 Windows 지원 / 라이선스 /
네이티브 바이너리·코드 실행 포함 여부 / 앱 크기와 빌드 복잡도 / 테스트 대체 가능성.
되돌리기 어려우면 ADR을 쓴다.

---

## 7. Git 규칙

```powershell
git diff --check
git status --short
```

- 관련 파일만 stage한다.
- 커밋 메시지는 결과를 명령형으로, `type: summary` 형태로 쓴다.
- 코드 수정이 완료되면 커밋하고 현재 추적 원격 브랜치로 푸시한다.

```text
docs: define product and architecture baseline
feat: add lossless CHK section parser
test: cover malformed CHK section lengths
fix: preserve unknown trigger payload bytes
```

---

## 8. 문서 갱신 규칙

| 변경 | 갱신할 문서 |
| --- | --- |
| 사용자에게 보이는 기능·범위 | PRODUCT_REQUIREMENTS, EDITOR_UX |
| 계층·의존성·외부 도구 | ARCHITECTURE, decisions/ (ADR) |
| CHK / MPQ 동작 | FILE_FORMATS |
| 빌드·보안 정책 | EUD_INTEGRATION, DATA_SAFETY |
| 작업 완료·새 후속 작업 | DEVELOPMENT_PLAN (체크박스 갱신) |
| 명령·환경 | README, DEVELOPMENT_WORKFLOW, **이 문서** |
| 새 개념 | GLOSSARY |

---

## 9. 완료 보고 형식

세션을 마칠 때 아래를 간결하게 남긴다. 다음 기기·다음 AI가 이것만 보고 이어받을
수 있어야 한다.

```text
결과: (사용자가 얻은 것 한 문장)
변경: (핵심 파일 목록)
검증: (실행한 명령과 결과 / 실행하지 못한 것과 이유)
Git: (커밋 해시, 푸시한 브랜치)
상태: DEVELOPMENT_PLAN의 어떤 항목을 완료/부분 완료했는가
다음: 다음 미완료 항목과 알려진 제한
```

---

## 10. 기기·AI 간 인수인계

### 10.1 상태는 저장소에 남긴다

세션 메모리는 이어지지 않는다. 다음 세션이 알아야 할 것은 **전부 저장소에**
남긴다.

- 진행 상황 → `DEVELOPMENT_PLAN.md` 체크박스와 메모
- 결정과 이유 → `docs/decisions/`
- 확인된 포맷·동작 → 해당 설계 문서
- 미실행 검증과 위험 → 커밋 메시지와 계획 메모

**"AI가 기억하고 있다"에 의존하는 상태는 없어야 한다.**

### 10.2 새 AI 세션 첫 프롬프트 (그대로 복사해서 사용)

```text
이 저장소는 StarCraft: Remastered UMS/EUD 맵 에디터다.
작업 전에 다음을 순서대로 읽어라.

1. AGENTS.md
2. docs/AI_AGENT_GUIDE.md
3. docs/README.md
4. docs/DEVELOPMENT_PLAN.md 의 "현재 상태" 표와 첫 번째 미완료 체크박스
5. 해당 작업과 관련된 설계 문서

그다음 docs/DEVELOPMENT_PLAN.md 의 첫 번째 미완료 항목을 진행하고,
docs/AI_AGENT_GUIDE.md 의 검증 명령표와 금지 사항을 지켜라.
작업이 끝나면 같은 문서의 완료 보고 형식으로 보고해라.
```

### 10.3 도구별 참고

이 저장소의 기준 문서는 `AGENTS.md`와 이 문서다. 특정 AI 도구가 자체 규약
파일(`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules` 등)을 읽는
경우, 그 파일은 **내용을 복제하지 말고 이 두 문서를 가리키기만 한다.** 규칙이
여러 파일로 갈라지면 기기마다 다른 동작이 나온다.

---

## 11. 빠른 참조

### 디렉터리

```text
lib/app/              부트스트랩·앱 셸 구성
lib/application/      컨트롤러, 유스케이스, ports(계층 계약)
lib/domain/           chk(raw/typed), terrain, placement, assets, diagnostics
lib/infrastructure/   archive, assets, compiler, filesystem, settings 구현
lib/presentation/     shell, map_canvas, eud_editor, settings 위젯
native/map_archive_helper/     StormLib 기반 MPQ helper (C++)
native/starcraft_data_helper/  CascLib 기반 SC:R 자산 helper (C++)
test/                 domain / application / infrastructure / widget /
                      integration / performance / fixtures
tool/                 픽스처 생성 스크립트
docs/                 기준 문서 (이 디렉터리)
```

### 테스트 픽스처

- `test/fixtures/chk/*.hex` — 정상·손상 CHK 바이트
- `test/fixtures/maps/generated/`, `test/fixtures/maps/eud_smoke/` — 자체 제작 맵
- `test/fixtures/helpers/fake_*.ps1` — 가짜 helper / 컴파일러 프로세스
- `test/fixtures/eud/minimal-smoke.eps` — 최소 epScript

새 픽스처는 **직접 제작하거나 재배포가 허용된 것만** 추가한다.
