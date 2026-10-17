# 여러 맵 편집 (FR-005 / EP3b 문서 수명)

## 범위와 요구사항

맵별 컨트롤러와 keyed 편집 화면을 유지한다. 문서 간 복사(FR-222)는 포함하지
않으며 기존 같은 문서 혼합 복사도 자기 문서의 payload만 사용한다.
중요 결정은 [ADR-0022](decisions/0022-multi-map-document-lifetime.md)를 따른다.

| 요구사항 | 구현 계약 |
| --- | --- |
| 여러 맵 | 최대 8개 문서, 가로 스크롤 탭, 파일명·dirty·진행 표시·닫기 |
| 독립 상태 | CHK/리소스, Undo/Redo, 선택/레이어, 카메라, 폼/트리거 초안, EUD 소스/프로젝트/로그, 복구·타이머 분리 |
| 전환 | Ctrl+Tab / Ctrl+Shift+Tab, 전환은 편집 아님. 진행 중 brush transaction은 완료/취소 전 거부 |
| 새 맵 | 새 문서를 별도로 준비. 취소/실패 시 기존 맵·Undo 무변경 |
| 중복 열기 | 같은 실제 파일의 case/경로/링크 별칭은 기존 탭 선택. 늦은 Open 완료는 사용자가 선택한 다른 탭의 focus를 빼앗지 않음 |
| 저장·출력 | Save As/EUD output/프로젝트 write 예약과 열린 입력 경로 검사, 원본 덮어쓰기 금지 유지 |
| 복구 | 새 문서에서 복원. owner별 체크포인트와 보관. 열린 문서 소유 checkpoint의 다른 문서 복구/삭제 금지 |
| 닫기 | 진행 작업/예약 중 거부, CHK dirty가 아닌 미적용 초안도 명시 확인, 확인 뒤 revision 변경 거부 |
| 종료 | 모든 문서 확인 후에만 종료 승인. 중간 취소/변경/작업 발생은 전체 취소, 이미 확인한 탭도 제거하지 않음 |
| 수명 | 탭 제거 후 화면 unmount, 소유 구독/타이머/요청/텍스처/controller 해제; 앱 전역 설정·포트만 공유 |

Save As는 맵만 저장한다. epScript·프로젝트·미적용 폼까지 저장했다고 표시하지
않으며 저장 뒤 닫기를 다시 확인한다. 닫은 문서의 복구 사본은 자동 삭제하지 않는다.
자동 저장 설정은 현재 문서에 즉시 적용되고 저장된 기본값은 새 문서에서도 읽는다.

## 실행 계획

1. 단일 bootstrap/셸·저장/빌드·자동 저장 경계와 FR-005/PAR-09 분석.
2. application 문서 registry·path lease, per-document bootstrap·탭 UI 구현.
3. 기존 controller에 optional 경로 검사만 추가하여 단일 문서 API와 테스트 유지.
4. A/B 격리·중복/예약·비동기 완료·초안/카메라·닫기/종료 자동 회귀 추가.
5. 실제 자체 제작 MPQ의 독립 저장/재열기·원본 해시, EUD 경계 회귀와 Windows/native 게이트.
6. 결과/실패/미실행 경계를 기록하고 관련 변경만 commit/push.

## 소스 분석과 최적화 판단

- snapshot 교체 방식 대신 문서별 기존 controller를 그대로 사용한다. 기존 Undo
  closure, 비동기 요청 context, 편집기 내부 초안을 다른 맵에 재바인딩하지 않는다.
- Stack/Offstage의 **직접 자식**에 stable key를 둔다. 앞 탭을 닫아 index가
  바뀌어도 나머지 화면 State를 재생성하지 않는다. 비활성 탭의 focus/ticker는 끈다.
- 전체 맵을 복제해서 전환하지 않는다. 기존 불변 session과 revision cache를 유지한다.
  8문서 상한과 닫기 해제를 제공하지만 실제 다중 문서 RSS 예산 인수는 별도다.
- 경로 비교는 기존 `MapSaveFileGateway.refersToSameLocation`을 재사용한다.
  예약 획득은 직렬화하고 비동기 비교 도중 registry revision이 바뀌면 거부한다.
  최종 map/EUD 출력 직전에 context/경로를 다시 확인한다.
- 자동 저장 initialize를 idempotent로 만들어 복구된 새 문서의 timer 중복을 막는다.

## 실행 기록

2026-10-16 구현 시작. 첫 집중 테스트는 테스트 대역의 `cancel`/취소 진단/void
dispose 처리 누락으로 컴파일 실패했다. 대역을 보완한 뒤 controller 9개가 통과했다.
정적 분석에서 AppExitResponse import와 async context 검사도 교정했다.

첫 다중 탭 화면 회귀에서 공통 설치 설정의 동기 알림이 형제 화면 build 중
setState를 호출하고, IndexedStack 내부 wrapper 때문에 앞 탭 제거 시 뒤 화면이
재생성되는 결함을 발견했다. 공유 설정 로드를 첫 프레임 뒤 한 번으로 옮기고
직접 keyed Offstage를 사용하는 Stack으로 수정했다. 초안 controller와 MapCanvas
State 동일성을 검증하여 회귀를 막는다. 테스트 종료에서 fake frame 안의 비동기
구독 해제를 기다리는 문제와 Dialog 종류 선택 오류도 보완했다.

Windows 종료는 기존 runner의 Flutter top-level message 전달과
[취소 가능한 종료 observer](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver/didRequestAppExit.html)를
사용한다. 강제 종료/전원 차단은 취소할 수 없으며 자동 저장 체크포인트와 구분한다.

## 체크리스트와 최종 검증

- [x] 문서별 dirty/Undo/레이어/소스/프로젝트/clipboard 분리
- [x] 중복 case/경로/링크 별칭, 실패/늦은 열기의 기존 문서 보존
- [x] path lease 직렬화·경합/닫기 차단·Save As 다른 문서 원본 무변경
- [x] 복구 owner 분리/열린 사본 보호·비활성 문서에만 복원
- [x] 비활성 build 결과/로그·출력 예약 분리
- [x] 자료 조회 전 즉시 빌드 취소·실행 중 취소의 예약 해제, 사운드 가져오기 중 닫기 거부
- [x] keyed 화면·초안/카메라 유지·닫기/종료 UI 자동 회귀
- [x] 실제 MPQ 왕복·Windows/native·전체 필수 게이트 실행 (기존 format 차이는 아래에 구분)
- [ ] 실제 앱 수동 조작·다중 문서 RSS/DPI·게임/외부 에디터 인수 (이번 자동 검증과 별도)

추가 취소 회귀에서 취소 이벤트는 blocking diagnostic을 요구한다는 기존 계약을
확인하고 테스트 대역/새 adapter의 severity를 교정했다. 출력 경로 확인 전에
취소해도 컴파일러를 뒤늦게 시작하지 않도록 queued owner를 동기 등록한다.
현재 controller 12개, UI 3개(새 맵 생성/취소 포함), 실제 MPQ 왕복 1개가 통과했다.

2026-10-16 마무리 검토에서 문서별 `MapLayerController`의 명시적 해제를
추가했다. 이후 재빌드/커밋 요청은 도구 승인 검토기의 사용량 제한으로 실행되지
않았다. 2026-10-17 사용자의 계속 진행 요청으로 Windows Debug 재빌드와 형식·
정적 분석·전체 테스트, native/실제 MPQ·EUD 스모크 검증을 다시 수행했다.
아래 결과를 재확인했으며 실제 MPQ/EUD 선택 실행도 skip 없이 통과했다.
수동 앱 조작 허용 범위를 바꾸거나 다른 개발 항목으로 범위를 확장하지 않았다.

## 최종 검증 (2026-10-16~17)

Windows / Flutter **3.47.5 stable**, Dart **3.13.4**에서 실행했다. 저장소 기준
Flutter 3.44.8/Dart 3.12의 깨끗한 CI/다른 기기 결과는 아니다. 기존 사용자 설정
테스트가 포함된 현재 작업 트리 결과이며 사용자 변경은 커밋에 포함하지 않는다.

| 실행 | 결과/분석 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | 523파일 중 기존 infrastructure 테스트 3파일 차이로 exit 1. 이번 변경 파일 차이 없음 |
| `flutter analyze` | No issues found |
| `flutter test` | 2,236 PASS / 환경 조건부 66 skip |
| 새 controller/화면 회귀 | 12 + 3 PASS. 전환·초안/MapCanvas State 유지·앞 탭 닫기·종료 전체 취소·생성/취소 포함 |
| 관련 집중 회귀 | 취소 추가 전 자동 저장/EUD 프로젝트 포함 25 PASS; 취소 추가 후 controller 12 PASS. 전체 회귀와 겹치는 수이므로 더하지 않음 |
| 실제 MPQ + 동봉 euddraft 선택 실행 | 2 PASS, skip 없음. 두 맵 독립 SaveAs/Undo/재열기·원본 fingerprint, 실제 자체 제작 맵의 euddraft 빌드/검증/교체 |
| `flutter build windows --debug` | PASS; 기존 third-party CMake minimum-version 경고만 존재 |
| `ctest --test-dir build/windows/x64 -C Debug --output-on-failure` | 7/7 PASS |

기존 format 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
이번 기능과 무관한 형식 수정은 하지 않았다. 실제 SC:R 자산·추출 이미지를 새로
저장하지 않았고 테스트 맵은 임시 디렉터리의 자체 제작 데이터만 사용했다.

실제 앱/게임 조작은 이전 사용자 지시대로 수행하지 않았다. Windows 창 닫기·DPI·
다중 맵 RSS/texture 예산·외부 에디터/게임 인수는 자동 회귀와 별도다.
문서 간 참조 재매핑 복사(FR-222 / PAR-10)는 다음 개발 항목으로 유지한다.
