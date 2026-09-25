# 선언적 EUD 생성 명세 미리보기

2026-09-25 EUD Project의 `Generation preview` 버튼을 추가했다. 후보 5개 필드의
구조 검증을 통과한 프로젝트를 `(table, id, field)` 순서의 결정적 JSON으로 보여준다.
입력 맵 SHA-256, 도구/API revision, 값과 명시적 CHK override 여부를 포함한다.

알 수 없는 필드, 범위/타입/enum 오류, 최소 사거리 > 최대 사거리와 명시적 동의가
없는 CHK 중복은 미리보기 생성 전에 거부한다. 같은 설정은 입력 순서와 무관하게 같은
문자열을 만들고 프로젝트/맵/사용자 소스는 변경하지 않는다.

이 명세는 **실행 불가능한 생성기 입력 미리보기**다. `executable: false`,
`runtimeStatus: unverified`와 `userHookOrder: unverified`를 고정한다. 기존/신규
유닛의 현재 실드 초기화, 사용자 hook 순서, 실제 euddraft 컴파일과 게임 검증이 남아
있어 Build를 활성화하지 않는다. Save Project와 Map Save As도 컴파일하지 않는다.

X2의 다음 작업은 검증된 SCData API·게임 프로필을 이 명세에 연결하고 실제 생성
소스·빌드 작업 공간·SafeEudBuildPipeline의 입력/결과 스냅샷 검증을 구현하는 것이다.
사용자의 성능 확인 완료 보고를 설정/EUD 게임 검증 완료로 확대 해석하지 않는다.

## 2026-09-25 통합 검증

- Flutter analyze: 오류 없음. 전체 flutter test: 701 통과, 선택적 환경 테스트 21 건너뜀.
- 실제 설치 자산을 지정한 카탈로그 테스트: 44 통과. Tile 해제 후 재요청과 실제
  Unit/Sprite 카탈로그를 포함한다.
- Windows Debug 빌드 및 5초 프로세스 시작 스모크 통과. 새 UI의 수동 조작 검증은 별도다.
- 변경 Dart 파일 포맷은 정리했다. 전체 포맷 게이트에는 기존 infrastructure 테스트
  4개의 포맷 차이가 남아 있으며 이번 작업에서 수정하지 않았다.
- 실행 환경은 Flutter 3.47.2 / Dart 3.13.2다. 기준 3.44.8 / 3.12는 미검증이다.
- Doodad 게임/외부 에디터 왕복, EUD 소스 생성·컴파일·게임 동작은 완료로 표시하지 않는다.
