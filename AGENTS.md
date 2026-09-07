# AGENTS.md

이 파일은 모든 AI 에이전트의 진입점이다. 새 기기이거나 이 저장소를 처음
작업하는 도구라면 먼저 [docs/AI_AGENT_GUIDE.md](docs/AI_AGENT_GUIDE.md)를
읽는다. 환경 구축, 검증 명령표, 금지 사항, 인수인계 절차가 그 문서에 있다.

## 기본 작업 순서

1. 작업 전 `docs/README.md`와 관련 문서를 읽는다.
2. 별도 지시가 없다면 `docs/DEVELOPMENT_PLAN.md`의 첫 번째 미완료 항목을 진행한다.
3. 변경 범위를 작게 유지하고 사용자 변경사항을 덮어쓰지 않는다.
4. 코드 변경에는 적절한 테스트와 문서 갱신을 포함한다.
5. `flutter analyze`, `flutter test`와 변경 범위에 필요한 검증을 실행한다.
6. 작업이 완료되면 관련 파일만 커밋하고 현재 원격 브랜치로 푸시한다.

## 필수 게이트

```powershell
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

기준 도구 체인은 Flutter `3.44.8` stable / Dart `3.12`다. 변경 유형별 추가
검증은 [AI 에이전트 가이드](docs/AI_AGENT_GUIDE.md)와
[개발 워크플로](docs/DEVELOPMENT_WORKFLOW.md)의 표를 따른다. 실행하지 못한
검증은 이유와 위험을 완료 보고에 남긴다.

## 데이터 안전 규칙

- 입력 `.scm`/`.scx` 파일을 기본적으로 직접 덮어쓰지 않는다.
- 알 수 없는 CHK 섹션, 중복 섹션, 원시 문자열 바이트를 임의로 정규화하지 않는다.
- 손상되거나 보호된 맵을 자동 복구하려고 추측하지 않는다.
- 테스트용 맵은 직접 제작하거나 재배포가 허용된 파일만 저장소에 추가한다.
- SC:R 원시 자산과 추출 이미지는 저장소 fixture나 배포물에 포함하지 않는다.
- EUD 플러그인과 Python 코드는 신뢰할 수 없는 실행 코드로 취급한다.

## 아키텍처 규칙

- UI가 바이너리 파서, 파일 시스템, 네이티브 라이브러리, 프로세스 실행을 직접 호출하지 않는다.
- 도메인 계층은 Flutter, 파일 시스템, FFI, euddraft에 의존하지 않는다.
- 외부 도구 연동은 인터페이스 뒤에 두고 버전과 원시 로그를 기록한다.
- 저장은 검증, 임시 출력, 재검증, 원자적 교체 또는 Save As 순서로 수행한다.
- 구조가 불명확한 값에 임의로 이름을 붙이지 않고 종류와 숫자 ID로 노출한다.

## 인수인계

세션 메모리는 이어지지 않는다. 진행 상황은 `docs/DEVELOPMENT_PLAN.md`,
결정은 `docs/decisions/`, 확인된 동작은 해당 설계 문서에 남긴다. 다음 세션이
저장소만 읽고 이어받을 수 있어야 한다.

도구별 규약 파일(`CLAUDE.md`, `.github/copilot-instructions.md`, `.cursorrules`
등)을 두는 경우 내용을 복제하지 않고 이 파일과
[docs/AI_AGENT_GUIDE.md](docs/AI_AGENT_GUIDE.md)를 가리키기만 한다.
