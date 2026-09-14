# ADR-0009: EUD 선언적 설정 프로젝트

- Status: Accepted
- Date: 2026-09-14

## Context

일반 맵 Save As는 CHK 변경만 저장한다. 사거리·실드 활성 같은 EUD 확장 값은
소스 설정으로 보존하고, 향후 EUD Build가 해당 설정에서 출력 맵을 생성해야 한다.
필드 설정을 사용자 epScript에 직접 삽입하면 원본 코드 보존과 반복 빌드가 어렵다.

## Decision

- `.eud.json`은 UTF-8 JSON이고 format은 `starcraft-map-editor-eud`, schemaVersion은
  정수 1이다. map 객체의 path·sha256과 overrides 배열만 포함한다.
- map.path는 명시적으로 연결한 맵의 경로 참조, sha256은 해당 스냅샷의 소문자
  64자리 해시다. 모델은 해시를 계산하거나 맵을 열지 않는다. 앱 연결 단계에서
  실제 맵 fingerprint와 대조해야 하며, 프로젝트 열기만으로 경로를 신뢰하지 않는다.
  Save As로 프로젝트 위치를 바꿔도 맵 참조는 그대로이고 재연결은 별도 Undo 명령이다.
- override는 field·targetId·value·overrideChk로 구성한다. 동일 필드/대상 중복은
  거부한다. 알려진 필드의 잘못된 값과 모르는 필드의 scalar 값은 가져오기/저장 시
  보존하되 진단한다. 일반 편집 명령은 유효한 일괄 설정만 반영한다.
- 최대 실드는 명시적 overrideChk=true가 필요하다. 같은 무기의 최소/최대 사거리가
  모두 있으면 순서를 검사한다. 기본 DAT를 읽어 나머지 값과 대조하거나 공유 영향을
  확정하는 기능은 후속 단계다. 구조 검증 성공은 빌드 가능이나 게임 지원이 아니다.
- JSON 속성이 추가/누락되거나 값 구조가 지원되지 않으면 열기를 거부한다. v1이
  최초 형식이므로 과거 migration은 없다. 버전 0·상위 버전은 추측 변환하지 않고
  원본 파일/기존 세션을 유지한다. 새 스키마 도입 때 명시적 migration을 추가한다.
- 최대 파일 크기 2 MiB, 설정 5000개. 출력은 field/targetId 순서로 결정적이다.
- `EudProjectStore`는 I/O 포트다. 로컬 구현은 새 경로만 저장하며 기존 파일을
  교체하지 않는다. 기존 Save As gateway의 임시 workspace→flush→다시 읽어
  검증→승격→cleanup을 재사용한다. 임시 파일의 내부 확장자는 gateway 구현에
  따른 `.scx`이지만 내용은 JSON이고 맵 파서나 컴파일러에 전달하지 않는다.
- 프로젝트 dirty는 현재 내용과 마지막 저장 내용의 차이다. 일괄 편집·맵 재연결이
  Undo/Redo에 포함된다. 저장·열기 중에는 편집/교체/닫기를 막는다. 실패한 저장은
  clean으로 표시하지 않는다. 맵 Save As와 EUD Build는 호출하지 않는다.

## Alternatives

- CHK 내부 또는 사용자 epScript에 저장: 일반 저장과 빌드 경계가 혼동되고 기존
  바이트/소스 보존이 어려워 선택하지 않았다.
- 모르는 값을 삭제하며 가져오기: 데이터 손실이므로 선택하지 않았다.

## Consequences

현재는 도메인·컨트롤러·실제 파일 gateway까지 구현했다. 화면 연결, 기존 프로젝트
덮어쓰기(외부 변경 검사·백업 포함), map fingerprint 대조, 생성기·빌드 스냅샷 연결은
후속 작업이다. 앱의 기존 맵 Save As로 프로젝트가 저장되거나 EUD가 빌드되지 않는다.

## Validation

다섯 필드와 알 수 없는 scalar 필드의 왕복, 버전/크기/타입/중복 오류, 명시적 CHK
override, 사거리 순서, Undo/Redo 저장 기준선, I/O 실패와 동시 편집 거부,
실제 파일 왕복·원본 바이트 보존·기존 파일 덮어쓰기 거부·승격 실패 cleanup을 검증한다.
