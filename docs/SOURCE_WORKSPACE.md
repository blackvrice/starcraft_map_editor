# 여러 소스 편집 (FR-320)

2026-10-19. 요구사항은 [제품 요구사항](PRODUCT_REQUIREMENTS.md)의 FR-320,
결정은 [ADR-0025](decisions/0025-static-source-workspace.md)를 따른다.
일반 TRIG 선언 편집과 별도로 authored `.eps/.py/.lua` 파일을 보존하는 소스 작업 공간이다.

## 실행 계획과 분석

1. 기존 단일 EudSourceController, 번역/빌드, 맵 문서 수명과 복구 경로를 분석했다.
2. 기존 문서 API를 유지하면서 다중 탭과 루트 포트를 추가하고 파일 I/O를 UI에서 분리한다.
3. 실행 없는 정적 색인, 검색, 원본 진단 이동과 외부 변경 차단을 연결한다.
4. 복구/맵 닫기/빌드에 비활성 탭도 포함하고 단위·위젯·실제 도구로 회귀 검증한다.

기존 단일 `state.document`만 검사하면 비활성 탭을 잃거나 저장하지 않은 의존 파일로
빌드하는 문제가 생긴다. 모든 탭의 dirty/경로/작업 중 상태를 공유 문서 수명에
반영했다. 탭별 keyed IndexedStack으로 편집 컨트롤러·커서·Undo 수명을 유지한다.
색인은 debounce/isolate로 갱신하며 오래된 응답을 무시한다. 검색은 escaped literal,
UTF-16 원본 offset과 단일 순회 line 계산을 사용한다. 긴 한 줄에서 토큰마다
substring을 만드는 제곱 비용을 제거했고, 관련 이유를 코드 주석으로 남겼다.

## 구현과 사용 경계

- 소스 폴더 선택, 중첩 폴더 트리, 열기/새 탭/전환/닫기, 탭별 미저장 표시.
- EPS/Python/Lua 구문 강조와 기존 내장 후보 + 프로젝트 최상위 선언/import 별칭 완성.
  Python의 `import`, `from`, 상대 import, EPS import, Lua literal require를 보조 분석한다.
  주석/문자열·Python triple string·Lua long comment/string 안의 가짜 import를 건너뛴다.
- 전체 루트의 현재 버퍼 우선 검색, 최대 500건과 file:line:column 이동.
  EPS compiler 모듈 진단과 Python traceback의 파일/행을 보존한다. 정확한 프로젝트
  파일만 열며 basename/module 이름이 중복되거나 외부 경로면 거절한다.
- 명시적 폴더 새로 고침, 열기/저장/빌드 재검증으로 외부 변경을 탐지한다.
  자동 감시/자동 병합은 하지 않는다. 변경/삭제된 파일의 기존 버퍼는 유지하고
  해당 파일 저장을 차단한다. 다시 읽기는 dirty 내용을 버리는 별도 확인을 요구한다.
- 기존 파일 **저장**은 예상 SHA-256, 임시 출력, 내용 검증, 원본 바이트 백업과
  원자 승격을 사용한다. Save As는 기존의 **새 파일만** 정책을 유지한다.
  루트 밖 Save As는 사본만 내보내고 작업 탭을 clean으로 바꾸지 않는다.
  저장 중 추가 입력은 저장한 내용만 baseline으로 반영하고 새 입력은 dirty로 남긴다.
- 맵 닫기/종료/경로 점유/자동 저장은 모든 소스 탭을 검사한다. recovery schema v3는
  root/activeId/각 문서의 경로·저장 기준·현재 원문을 저장하며 v1/v2도 읽는다.
  복구는 파일이나 맵에 쓰지 않고 interpreter도 실행하지 않는다. 복구된 폴더는
  명시적 새로 고침 전까지 미확인 상태이며 빌드·루트 파일 저장을 차단한다.
- EUD 빌드는 저장된 모든 탭과 확인된 루트를 요구한다. 준비 시 의존 소스 목록과
  지문을 캡처하고 실행 전/출력 승격 전에 전체 목록을 재검사한다. 파일 추가·삭제·
  변경이나 문서 context 변경 시 출력 맵을 게시하지 않는다. 루트는 빌드 준비에 전달한다.

## 제한과 안전

| 항목 | 상한/정책 |
| --- | --- |
| 파일/탭 | 루트 256개 / 탭 16개 |
| 파일 크기 | UTF-8 4 MiB, 디코드 후 1 Mi UTF-16 code units |
| 스캔 | 총 UTF-8 8 MiB / 엔트리 4096개 / 중첩 12단계 |
| 색인 | 총 8 Mi code units / 파일당 토큰 200000개 / debounce 300ms |
| 검색 | literal 256 code units / 결과 500건 / excerpt 최대 180 code units |
| 복구 | 버퍼+저장 기준 합계 32 Mi code units, 개별 원문 4 Mi code units |

스캔은 `.git/.dart_tool/__pycache__/__epspy__/.venv/node_modules/build`를 제외한다.
`__epspy__`는 euddraft 생성 캐시용 예약 폴더이며 authored source를 두는 위치가 아니다.
절대 경로/`..`/장치명/모호한 Windows 이름·대소문자 중복과 링크 경유를 거절한다.
상대 import의 루트 이탈/모호함/누락은 진단하며 추측해서 열지 않는다.
외부 SDK import는 미해결 외부 참조로 두며 임의 경로를 따라가지 않는다.

정적 색인은 완전한 parser/type checker/LSP가 아니다. 동적 import/런타임 속성,
복잡한 re-export·다중 행 import·비ASCII 식별자의 정확한 해석을 보장하지 않는다.
프로젝트 루트는 편집/탐색 경계이지 Python 실행 샌드박스가 아니다. 명시적으로
신뢰 승인한 EUD 빌드 코드는 임의 동작을 할 수 있다. OS 파일 잠금을 사용하지
않으므로 다른 프로세스가 검증 직후 교체하는 경쟁까지 없애는 것은 아니다.
소스 폴더의 영구 프로젝트 manifest나 전체 Undo 이력 복구는 제공하지 않는다.
Lua는 편집/정적 탐색만 지원하고 native Lua 빌드·임의 Python/Lua 역변환은 미지원이다.

## 테스트 시나리오와 결과

| 시나리오 / 요구사항 | 기대 결과 | 검증 |
| --- | --- | --- |
| 다중 탭 편집/전환/닫기 FR-320 | 원문 격리, dirty 거절·취소 보존 | controller/widget |
| 언어별 선언/별칭/주석 FR-320 | 실행 없이 올바른 후보, 가짜 import 무시 | domain |
| Unicode·CRLF·literal 검색 FR-320 | 원본 UTF-16 행/열 유지, 500건 제한 | domain/widget |
| source 진단 FR-320 | 정확한 파일/행, 외부·모호한 경로 거절 | parser/controller/widget |
| 외부 변경/삭제/링크 FR-320 | 자동 덮어쓰기 없음, 명시 reload | filesystem/controller |
| 기존 소스 저장 NFR-008 | SHA 충돌 거절, 이전 bytes 백업 | 실제 임시 파일 |
| 저장 도중 입력 NFR-008 | 새 원문은 dirty로 보존 | 지연 gateway |
| 비활성 초안 FR-320/FR-005 | 맵 닫기 방지·모든 탭 checkpoint/복구 | workspace/autosave |
| 강제 종료 NFR-008 | 검증된 세대의 세 언어 초안/active 탭 유지 | 별도 프로세스 kill |
| 빌드 중 의존 변경 FR-320 | 임시 결과 정리, 출력 승격 0회 | pipeline/filesystem |
| 실제 다중 파일 빌드 FR-320 | Python helper import, MPQ 재열기·원본 불변 | bundled euddraft 통합 |

집중 검증에서 controller/index/pipeline/UI 37개와 파일/복구/맵 수명 28개가
통과했다(서로 겹치는 회귀 포함). 첫 UI 테스트는 FakeAsync 안에서 isolate 완료를
기다리며 멈췄다. 해당 테스트 프로세스만 종료하고 실제 비동기 구간을 runAsync로
분리한 뒤 한국어 600px/영어 1200px 시나리오를 재실행해 통과했다.
파일 링크 생성 검사는 Windows errno 1314 권한 부족으로 조건부 skip이다.

첫 전체 실행은 2562 통과/80 skip/4 실패였다. 새 소스 목록의 ListTile이 기존
ColoredBox 패널 안에서 Material 배경에 그려지는 Flutter assertion을 검출했다.
목록과 편집 작업 공간에 Material 경계를 명시하고 전체 회귀를 재실행한다.
추가 검토에서 잘못된 open 요청이 기존 문서를 목록에서 먼저 제거하는 순서와
Save As가 디스크 재확인 전에 clean으로 바뀌는 순서도 수정하고 회귀 테스트를 추가했다.
실제 EUD 첫 실행은 Python 2종/강제 종료 복구는 통과하고 EPS 빌드만 실패했다.
원본 EPS SHA는 그대로였지만 compiler가 `__epspy__/원본이름.py`를 생성해 목록
검사에 걸린 것을 확인했다. 생성 캐시를 색인 제외 목록에 추가하고 재검증한다.

최종 검증 결과:

- `flutter analyze`: 무이슈.
- `flutter test`: **2568 통과 / 80 조건부 skip / 실패 0**, 전체 재실행 로그
  `.dart_tool/source-workspace-full-tests-r2.log`. 기존 외부 도구/SC:R 환경 조건과
  추가 링크 생성 권한 조건을 포함하며 skip을 통과로 세지 않는다.
- 실제 도구/파일/controller 재실행: **17 통과 / 1 링크 권한 skip**,
  `.dart_tool/source-workspace-real-integration-r2.log`. bundled euddraft
  `0.10.2.5-editor.1`의 EPS·제한 Python·공식 번역 Python 3종 빌드/MPQ 재열기,
  Python helper import, 원본 맵/entry/도구 설치 hash 불변과 프로세스 강제 종료 후
  세 언어 탭/기준/activeId 복구를 확인했다. 게임 실행 성공을 뜻하지 않는다.
- Windows Debug 빌드 성공. native CTest **7/7 통과**.
- `dart format --output=none --set-exit-if-changed lib test tool`: exit 1.
  기존 미수정 `local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 차이가 있으며 이번 변경 파일은 포맷 차이가 없다. 사용자 파일은 수정하지 않았다.
- 검증 SDK: Flutter **3.47.5 / Dart 3.13.4**, 기준 3.44.8/3.12와 다르다.
  CMake의 기존 CascLib 최소 버전 경고는 빌드를 실패시키지 않았다.

실제 열린 앱/게임/외부 에디터/clean Windows는 조작하지 않는다. 자동 검증과
게임·배포 인수를 같은 완료로 계산하지 않는다.
