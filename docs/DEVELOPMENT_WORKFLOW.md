# 개발 워크플로

## 1. 시작 전

1. `git status --short --branch`로 브랜치와 기존 변경을 확인한다.
2. [개발 계획](DEVELOPMENT_PLAN.md)의 첫 미완료 항목과 관련 문서를 읽는다.
3. 변경할 계층, 테스트, 사용자-visible 결과를 정한다.
4. 사용자 변경이 있으면 관련 없는 파일을 건드리지 않는다.

## 2. 환경

기준 플랫폼은 Windows PowerShell이다.

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

현재 SDK가 Flutter `main` 개발 버전이므로, M0에서 stable 또는 정확한 revision을 선택해 CI와 로컬 환경을 맞춰야 한다.

## 3. 작업 단위

한 변경은 가능한 한 하나의 검증 가능한 결과를 만든다.

좋은 예:

- raw CHK 헤더 파서와 잘린 입력 테스트
- 문서 변경 상태와 닫기 확인 UI
- euddraft 도구 버전 검사와 가짜 프로세스 테스트

피할 예:

- 파서, 전체 UI 재설계, 패키징을 한 커밋에 포함
- 테스트 없이 여러 섹션을 동시에 지원
- 관련 없는 Flutter 템플릿 플랫폼 파일 일괄 삭제

## 4. 구현 규칙

- Domain은 Flutter와 I/O에 의존하지 않는다.
- Presentation은 파일/FFI/프로세스를 직접 호출하지 않는다.
- 외부 도구는 포트 인터페이스 뒤에 둔다.
- 바이너리 파서는 실패 위치와 안정적인 오류 코드를 반환한다.
- 사용자에게 보이는 문자열은 향후 현지화를 고려해 분리한다.
- 데이터 변경은 Undo/Redo 가능한 명령을 우선한다.
- 지원하지 않는 필드를 기본값으로 덮어쓰지 않는다.

## 5. 의존성 추가

추가 전 확인:

- 실제로 표준 라이브러리나 기존 코드로 해결하기 어려운가?
- 최근 유지보수와 Windows 지원 상태는 어떤가?
- 라이선스가 프로젝트와 배포 방식에 맞는가?
- 네이티브 바이너리나 코드 실행을 포함하는가?
- 앱 크기와 빌드 복잡도는 얼마나 늘어나는가?
- 테스트에서 대체할 수 있는가?

결정이 되돌리기 어렵다면 ADR을 작성한다.

## 6. 테스트

최소 검증:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

변경 유형별 추가 검증:

| 변경 | 추가 검증 |
| --- | --- |
| CHK | byte-exact 왕복, 손상 픽스처 |
| 아카이브 | 실제 자체 제작 맵 Open/Save As |
| EUD | 가짜 프로세스 + 실제 euddraft 스모크 |
| UI | 위젯 테스트 + Windows 실행 |
| 저장 | 원본 해시, 임시 출력 실패 경로 |
| 배포 | 깨끗한 Windows 설치 테스트 |

실행하지 못한 검증은 이유와 위험을 작업 결과에 기록한다.

## 7. 문서 갱신

다음 변경에는 문서가 필요하다.

- 사용자-visible 기능/범위: 제품 요구사항, UX
- 계층/의존성/외부 도구 변경: 아키텍처, ADR
- CHK/MPQ 동작 변경: 파일 포맷
- 빌드/보안 정책 변경: EUD, 데이터 안전
- 작업 완료/새 후속 작업: 개발 계획
- 명령/환경 변경: README, 개발 워크플로

## 8. Git

- 커밋 전 `git diff --check`를 실행한다.
- `git status --short`로 포함 범위를 확인한다.
- 관련 파일만 stage한다.
- 커밋 메시지는 결과를 명령형으로 설명한다.
- 코드 수정이 완료되면 커밋하고 현재 추적 원격 브랜치로 푸시한다.
- 강제 푸시와 히스토리 재작성은 명시적 승인 없이 하지 않는다.

예:

```text
docs: define product and architecture baseline
feat: add lossless CHK section parser
test: cover malformed CHK section lengths
fix: preserve unknown trigger payload bytes
```

## 9. 완료 보고

다음을 간결하게 전달한다.

- 사용자가 얻은 결과
- 핵심 변경 파일
- 실행한 검증과 결과
- 커밋과 푸시 상태
- 알려진 제한 또는 다음 미완료 항목

## 10. 릴리스

릴리스 전:

- 모든 품질 게이트 통과
- `DEVELOPMENT_PLAN.md` 인수 조건 확인
- 외부 바이너리 버전과 라이선스 고지 확인
- 데이터 손실 Blocker/Critical 0건
- 실제 euddraft와 StarCraft 스모크 테스트
- 버전과 변경 기록 작성
- 릴리스 파일의 해시 기록
