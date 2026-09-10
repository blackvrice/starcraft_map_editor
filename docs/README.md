# 문서 인덱스

이 디렉터리는 제품 범위, 설계 결정, 구현 순서와 완료 기준의 기준 문서입니다. 코드와 문서가 다르면 검증된 현재 동작을 기준으로 문서를 함께 수정합니다.

## 읽는 순서

1. 현재 구현 상태와 다음 작업: [개발 계획](DEVELOPMENT_PLAN.md)
2. 제품 범위와 기존 에디터 대비 항목: [제품 요구사항](PRODUCT_REQUIREMENTS.md), [기본 기능 대조표](BASIC_EDITOR_COVERAGE.md)
3. EUD 확장 개발 범위: [EUD 확장 설정 설계](EUD_EXTENSIONS.md)
4. 구현할 계층과 사용자 흐름: [아키텍처](ARCHITECTURE.md), [에디터 UX](EDITOR_UX.md)
5. 작업과 검증 절차: [개발 워크플로](DEVELOPMENT_WORKFLOW.md), [테스트와 품질](TESTING_AND_QUALITY.md)

개발 계획은 현재 상태, 구현 이력은 완료 당시의 증거, 기능 대조표는 점검 당시의
누락 분석을 담당한다. 설계 문서의 계획 항목은 현재 앱의 지원 기능 목록이 아니다.
M0~M6.1 완료는 당시 범위의 완료이며 기본 설정과 EUD 확장 탭의 완료를 뜻하지 않는다.

## 문서 지도

| 문서 | 용도 | 변경 시점 |
| --- | --- | --- |
| [AI 에이전트 가이드](AI_AGENT_GUIDE.md) | 새 기기·새 AI 도구의 환경 구축, 작업 루프, 검증 명령표, 금지 사항, 인수인계 | 환경·명령·작업 규칙이 바뀔 때 |
| [제품 요구사항](PRODUCT_REQUIREMENTS.md) | 대상 사용자, 범위, 요구사항, MVP 완료 조건 | 제품 범위가 바뀔 때 |
| [아키텍처](ARCHITECTURE.md) | 계층, 컴포넌트, 데이터 흐름, 의존성 규칙 | 구조나 경계가 바뀔 때 |
| [파일 포맷과 무손실 정책](FILE_FORMATS.md) | MPQ/CHK 처리 원칙과 지원 단계 | 파서·저장 동작이 바뀔 때 |
| [EUD 확장 설정 설계](EUD_EXTENSIONS.md) | 유닛·무기 및 설정별 확장 탭, 런타임 실행의 계획과 지원 기준 | 확장 범위·필드 검증 기준이 바뀔 때 |
| [EUD 연동](EUD_INTEGRATION.md) | epScript/euddraft 빌드와 보안 경계 | EUD 도구 연동이 바뀔 때 |
| [유닛–무기 참조 목록](UNIT_WEAPON_REFERENCES.md) | 로컬 DAT의 무기 공유·서브유닛 연결과 읽기 계약 | 무기 영향 목록이 바뀔 때 |
| [설정 검색과 범위 복사](SETTINGS_EDITING_UX.md) | 검색·ID 범위 초안 복사와 적용 범위·검증 | 공통 설정 UX가 바뀔 때 |
| [테크 설정](TECH_SETTINGS.md) | 비용·시간·에너지·플레이어 허용/연구 완료와 상속 | 테크 편집이 바뀔 때 |
| [업그레이드 설정](UPGRADE_SETTINGS.md) | 비용·시간·레벨·상속과 버전별 바이트 보존 | 업그레이드 편집이 바뀔 때 |
| [유닛 생산 허용](UNIT_AVAILABILITY.md) | PUNI 맵 기본값·플레이어 허용/상속·원시 값 보존 | 생산 허용 편집이 바뀔 때 |
| [유닛 기본 설정](UNIT_SETTINGS.md) | 유닛 수치·이름·기본값과 공유 무기 피해량의 지원 범위 | 유닛 설정 편집이 바뀔 때 |
| [세력 설정](FORCE_SETTINGS.md) | 세력 배정·이름·동맹·공동 승리·시야·시작 위치 옵션 | 세력 편집 동작이 바뀔 때 |
| [플레이어 설정](PLAYER_SETTINGS.md) | 슬롯·종족·색상 편집과 시작 위치 진단의 지원 범위 | 플레이어 설정 동작이 바뀔 때 |
| [에디터 UX](EDITOR_UX.md) | 화면 구조, 핵심 작업 흐름, 입력 규칙 | 사용자 흐름이 바뀔 때 |
| [테스트와 품질](TESTING_AND_QUALITY.md) | 테스트 계층, 픽스처, 성능과 릴리스 게이트 | 검증 방법이 바뀔 때 |
| [256×256 캔버스 성능 기준선](performance/MAP_CANVAS_256_SMOKE.md) | 캔버스 계측 방법, 환경과 측정 결과 | 렌더 경로나 성능 기준이 바뀔 때 |
| [256×256 객체 스프라이트 성능 기준선](performance/OBJECT_SPRITE_256_SMOKE.md) | 다수 객체 로딩·LRU·paint 계측 방법과 결과 | 객체 렌더 경로나 성능 기준이 바뀔 때 |
| [SC:R 객체 그래픽 자산 조사](research/OBJECT_GRAPHICS_ASSETS.md) | 객체 ID와 로컬 그래픽 자산의 연결, 포맷·버전·배포 경계 | 객체 그래픽 경로나 지원 범위가 바뀔 때 |
| [시각적 배치와 CHK 생성 규칙 조사](research/VISUAL_PLACEMENT_AND_CHK_RULES.md) | Tile·Doodad·Unit·Sprite 선택 흐름, factory와 복합 배치 경계 | 배치 카탈로그나 생성 규칙이 바뀔 때 |
| [데이터 안전과 보안](DATA_SAFETY.md) | 원본 보호, 입력 검증, 외부 코드 실행 정책 | 파일·프로세스 정책이 바뀔 때 |
| [개발 워크플로](DEVELOPMENT_WORKFLOW.md) | 로컬 개발, 브랜치, 커밋, 완료 정의 | 팀 작업 방식이 바뀔 때 |
| [구현 이력](IMPLEMENTATION_HISTORY.md) | M0~M6.1 완료 당시 체크리스트와 검증 근거 | 완료 기록을 이관하거나 근거를 정정할 때 |
| [개발 계획](DEVELOPMENT_PLAN.md) | 단계별 작업과 인수 조건 | 작업을 시작하거나 마칠 때 |
| [기본 에디터 기능 대조표](BASIC_EDITOR_COVERAGE.md) | 기존 에디터 기본 기능의 누락 점검과 개발 단계 연결 | 기본 기능 범위나 구현 상태가 바뀔 때 |
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
