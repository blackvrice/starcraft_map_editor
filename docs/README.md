# 문서 인덱스

이 디렉터리는 제품 범위, 설계 결정, 구현 순서와 완료 기준의 기준 문서입니다. 코드와 문서가 다르면 검증된 현재 동작을 기준으로 문서를 함께 수정합니다.

## 문서 지도

| 문서 | 용도 | 변경 시점 |
| --- | --- | --- |
| [제품 요구사항](PRODUCT_REQUIREMENTS.md) | 대상 사용자, 범위, 요구사항, MVP 완료 조건 | 제품 범위가 바뀔 때 |
| [아키텍처](ARCHITECTURE.md) | 계층, 컴포넌트, 데이터 흐름, 의존성 규칙 | 구조나 경계가 바뀔 때 |
| [파일 포맷과 무손실 정책](FILE_FORMATS.md) | MPQ/CHK 처리 원칙과 지원 단계 | 파서·저장 동작이 바뀔 때 |
| [EUD 연동](EUD_INTEGRATION.md) | epScript/euddraft 빌드와 보안 경계 | EUD 도구 연동이 바뀔 때 |
| [에디터 UX](EDITOR_UX.md) | 화면 구조, 핵심 작업 흐름, 입력 규칙 | 사용자 흐름이 바뀔 때 |
| [테스트와 품질](TESTING_AND_QUALITY.md) | 테스트 계층, 픽스처, 성능과 릴리스 게이트 | 검증 방법이 바뀔 때 |
| [256×256 캔버스 성능 기준선](performance/MAP_CANVAS_256_SMOKE.md) | 캔버스 계측 방법, 환경과 측정 결과 | 렌더 경로나 성능 기준이 바뀔 때 |
| [256×256 객체 스프라이트 성능 기준선](performance/OBJECT_SPRITE_256_SMOKE.md) | 다수 객체 로딩·LRU·paint 계측 방법과 결과 | 객체 렌더 경로나 성능 기준이 바뀔 때 |
| [SC:R 객체 그래픽 자산 조사](research/OBJECT_GRAPHICS_ASSETS.md) | 객체 ID와 로컬 그래픽 자산의 연결, 포맷·버전·배포 경계 | 객체 그래픽 경로나 지원 범위가 바뀔 때 |
| [시각적 배치와 CHK 생성 규칙 조사](research/VISUAL_PLACEMENT_AND_CHK_RULES.md) | Tile·Doodad·Unit·Sprite 선택 흐름, factory와 복합 배치 경계 | 배치 카탈로그나 생성 규칙이 바뀔 때 |
| [데이터 안전과 보안](DATA_SAFETY.md) | 원본 보호, 입력 검증, 외부 코드 실행 정책 | 파일·프로세스 정책이 바뀔 때 |
| [개발 워크플로](DEVELOPMENT_WORKFLOW.md) | 로컬 개발, 브랜치, 커밋, 완료 정의 | 팀 작업 방식이 바뀔 때 |
| [개발 계획](DEVELOPMENT_PLAN.md) | 단계별 작업과 인수 조건 | 작업을 시작하거나 마칠 때 |
| [용어집](GLOSSARY.md) | 프로젝트에서 사용하는 용어의 의미 | 새 개념을 도입할 때 |
| [아키텍처 결정 기록](decisions/README.md) | 중요한 선택의 이유와 대안 | 되돌리기 어려운 결정을 할 때 |

## 문서 우선순위

충돌이 있을 때 다음 순서로 해석합니다.

1. 데이터 손실을 막는 정책
2. 검증된 실제 코드와 테스트
3. 제품 요구사항과 인수 조건
4. 아키텍처와 세부 설계
5. 개발 계획의 예상 일정과 순서

## 현재 기준선

- 대상 OS: Windows 10/11 x64
- 대상 게임: StarCraft: Remastered
- 대상 맵: 보호되지 않은 UMS `.scm`/`.scx`
- UI: Flutter desktop
- 도구 체인: Flutter 3.44.8 stable / Dart 3.12
- EUD 언어/컴파일러: epScript와 euddraft/eudplib
- 저장 기본값: 원본과 다른 경로로 Save As
- 첫 수직 기능: 맵 선택 → epScript 편집 → 빌드 → 새 출력 맵 생성

StarCraft 1.16.1 호환, macOS/Linux 배포, 보호된 맵 복구, 시각적 EUD 블록 편집기는 초기 범위에 포함하지 않습니다.
