# 혼합 영역 복사 (EP3a)

2026-10-17 [맵 간 혼합 영역 전송](DOCUMENT_TRANSFER.md)을 별도 UI/controller로
추가했다. 이 문서의 같은 맵 경로는 유지하며 문서 간 위치 이름/ID는 별도 재매핑한다.
같은 맵 Cut과 달리 문서 간 Cut/Move는 제공하지 않는다.

## 요구사항과 범위

FR-221 / PAR-08의 **현재 문서 내부** 복사 확대다. 기존 객체 선택 복사,
단일 두다드 복사, raw 타일 복사는 유지한다. 기본 편집 도구의 `혼합 영역 복사`
탭에서 영역·포함 레이어·연결 그래픽을 지정하고 Copy → Preview → Apply한다.
여러 맵 간 복사, 시스템 클립보드, 참조 closure/리소스 가져오기는 EP3b이며
이 기능에 포함하지 않는다.

| 항목 | 지원 계약 |
| --- | --- |
| raw 지형 | ISOM 없는 맵의 MTXM과 존재하는 TILE을 서로 독립적으로 복사 |
| ISOM 지형 | 검증된 전체 4×2 diamond가 선택 사각형 안에 들어오는 shape만 복사. 왼쪽/폭 4, 위/높이 2 타일 정렬; 이동도 4×2 정렬 |
| ISOM 경계 | shape를 고정하고 기존 region solver로 경계·CV5 pair·수직 적층을 재계산. 경계의 타일 member는 원본 바이트 복사가 아니며 선택 밖도 바뀔 수 있음 |
| 다수 두다드 | 모든 DD2를 로컬 recipe·전체 footprint·MTXM/TILE로 검증. 서로 겹치거나 일부만 걸친 footprint 거부 |
| 두다드 overlay | recipe에 있으면 사용자가 정확한 THG2 레코드를 명시. ID·중심·소유자·예약 바이트·활성/비활성 flag 일치와 유일성 검사; 좌표로 소유권 추정 금지 |
| UNIT | 영역 내 일반 UNIT. 양방향 pair/애드온은 함께 포함되어야 하며 새 class ID와 peer ID를 함께 생성 |
| Sprite | 선택한 독립 THG2 + 필수 두다드 overlay. 원래 레코드 순서·소유자·flag·기타 바이트 보존 |
| 로케이션 | 전체가 들어오는 MRGN을 빈 슬롯에 배치. 역전 좌표·이름 ID·고도 비트 유지; 이름의 원시 문자열이 바뀌면 거부 |
| 예약 레코드 | 시작 위치 UNIT 214와 Anywhere 슬롯 64는 복사/삭제하지 않고 제외 개수 표시 |
| 잘라내기 | raw는 맵의 기존 underlying 타일 값으로 채움. ISOM은 검증된 평지 shape로 채움. 복사 payload 유지 |
| 적용 | 현재 문서·자산 출처·미리보기 snapshot·관련 레이어 표시/잠금·진행 작업·공통 구조/참조 검사를 통과한 한 번의 Undo |

### 명시적 제한

- ISOM은 사각형의 raw stamp가 아니라 **내부의 완전한 diamond**를 복사한다.
  사각형 경계에 걸친 diamond는 고정 대상이 아니고 solver가 결정한다.
  원본 경계 flag나 타일 member의 byte-exact 복제를 보장하지 않는다.
- 대상 영역이 기존 두다드 footprint와 겹치거나, 재계산이 기존 두다드의
  underlying member를 바꾸면 전체 거부한다. 자동 삭제/복구하지 않는다.
- 위치를 참조하는 TRIG/MBRF는 복사하지 않으므로 기존 트리거의 로케이션 ID를
  새 슬롯으로 자동 치환하지 않는다. 위치 이름이 바뀐 오래된 payload도 거부한다.
- UNIT 건설 가능/충돌/전력/크립 게임 규칙은 이 복사 도구에서 새로 판정하지
  않는다. 좌표·바이너리 구조·연결 관계를 검증하는 제작용 복사다.
- 다른 문서를 열면 payload를 사용할 수 없다. 저장 뒤 문서 token이 바뀌는
  경우에도 다시 복사한다. 같은 문서에서 붙여넣기/Undo 후 반복 붙여넣기는 가능하다.
- 로컬 자산/수집 결과를 fixture나 배포물에 추가하지 않는다.

## 소스 분석과 설계 판단

1. 기존 `ChkEditingClipboard`가 UNIT fresh ID, pair, MRGN 빈 슬롯, 원시 레코드
   보존을 이미 담당한다. 별도 구현하지 않고 검증된 DD2 없는 임시 문서에 재사용한다.
2. 단일 `DoodadCompositeClipboard`의 인접 그래픽 보호 검사는 여러 두다드에
   재사용할 수 없다. `IsomDoodadOverlay`의 정확한 recipe 해석 결과를 노출하여
   전체 footprint/underlying 검사를 공유한다. 기본 raw-override 거부 정책은 유지한다.
3. `IsomTerrainPaint.previewShapes`의 기존 solver/변환기를 재사용한다.
   추측한 타일 조합이나 새 ISOM 엔진을 만들지 않는다.
4. 불변 payload/preview는 도메인에, 자산 수명·문서/레이어 검사는 application에,
   입력/그래픽 미리보기는 presentation에 둔다. UI에서 파일/프로세스를 호출하지 않는다.
5. 바이트가 같은 섹션을 다시 쓰지 않고 변경이 없는 Apply는 Undo를 만들지 않는다.
   recipe는 type별, overlay는 중심 좌표별로 색인하고 DD2 payload는 한 번 복사하여
   반복 전체 조회/복사를 줄였다. 늦게 끝난 이전 자산 요청은 최신 자료를 덮지 못한다.
   연결/복합 처리에는 계약 주석을 두고 타일과 객체의 원본 복사본만 편집한다.

## 실행 계획과 기록 (2026-10-16)

| 순서 | 실행 | 결과/분석 |
| --- | --- | --- |
| 1 | 계획·FR-221·PAR-08·기존 복사/ISOM/Undo 분석 | EP3a와 EP3b 분리, 기존 안전 계약 유지 |
| 2 | 도메인·application·한영 UI 및 미리보기 연결 | 다중 DD2/THG2와 일반 객체의 상대 좌표·참조 보존 구현 |
| 3 | 집중 테스트 첫 실행 | 테스트 fixture의 필수 seed 누락으로 컴파일 실패; 실제 UNIT relation flag offset도 10으로 교정 |
| 4 | 도메인/컨트롤러/한글 화면 재실행 | 최초 14개 PASS; raw/ISOM 복합·잠금·Undo·600/1200px 화면 포함 |
| 5 | 전체 게이트·Windows·실제 MPQ/CASC 자동 검증 | 아래 최종 검증 표에 기록 |
| 6 | 연결 그래픽을 직접 선택하는 화면 회귀 추가 | 스크롤 밖에서 지연 생성되는 버튼을 찾는 테스트가 실패; 화면 스크롤 후 찾도록 테스트 수정 |

## 요구사항·테스트 체크리스트

- [x] 다수 인접 두다드, 비활성 sprite-unit, 연결 유닛, 독립 Sprite, 역전 로케이션의 상대 이동
- [x] 원시 레코드 순서/예약 바이트·unknown CHK·원본 문서 보존
- [x] 부분 footprint/로케이션, 미확인/중복 overlay, 깨진 pair/incoming 참조 거부
- [x] 대상 footprint/좌표 경계/로케이션 용량/잘못된 채움 거부
- [x] 미리보기 무변경, 단일 Apply/Undo/Redo, 무변경 Undo 없음, 오래된 preview/문서·자산·잠금 거부
- [x] ISOM 정렬·known shape/pair·기존 두다드 보호
- [x] 한국어 UI의 Copy/Preview/Apply/Undo와 좁은 화면 레이아웃
- [x] 실제 MPQ Save As/재열기 바이트 일치와 원본 해시 보존
- [x] 로컬 8타일셋의 실제 ISOM 전환 shape 복사·경계 재검증
- [x] 전체 게이트 실행과 Windows Debug/native CTest (전체 format의 기존 3개 파일 차이는 아래에 구분)
- [ ] 실제 앱 수동 조작·ScmDraft/Chkdraft 왕복·SC:R 게임 인수 (별도, 이번 자동 검증 범위 아님)

## 최종 검증

2026-10-16 Windows에서 최종 확인했다. Flutter **3.47.5 stable / Dart 3.13.4**를
사용했으며 저장소 기준 3.44.8/3.12와 다르다. 기준 버전 재검증이나 원격 CI
결과로 간주하지 않는다.
전체 테스트 수는 기존 사용자 설정 테스트도 포함한 현재 작업 트리의 결과다.

| 실행 | 결과 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | 515파일 중 기존 infrastructure 테스트 3파일 차이로 exit 1. 이번 변경 파일은 차이 없음 |
| `flutter analyze` | No issues found |
| `flutter test` | 2,221 PASS / 환경 조건부 65 skip |
| 환경 변수를 지정한 혼합 복사 집중 5개 테스트 파일 | 22 PASS, skip 없음. 일반 회귀와 겹치는 수이므로 전체 PASS에 더하지 않음 |
| raw/ISOM 실제 MPQ 왕복 | 자체 합성 맵의 Cut/Paste/Undo/Redo → 한글 Save As → 재열기 CHK 전체 바이트 일치. 원본 fingerprint 동일 |
| 로컬 SC:R CASC 자동 검사 | 8타일셋 전환 shape를 목적지에 고정하고 재계산 후 shape/pair 검증. 추출 자산은 저장소에 추가하지 않음 |
| `flutter build windows --debug` | PASS; 기존 third-party CMake minimum-version 경고만 존재 |
| native `ctest --test-dir build/windows/x64 -C Debug --output-on-failure` | 7/7 PASS |

전체 format에 남은 기존 파일은 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자 변경과 무관한 형식 수정은 하지 않았다. 사용자 작업/기존 staging은
유지하고 별도 index로 이번 기능 범위만 commit/push한다.

실제 앱/게임 조작은 이전 사용자 지시에 따라 실행하지 않았다. 외부 에디터 왕복,
SC:R 게임 동작, 기준 SDK/깨끗한 Windows 배포 인수는 여전히 별도다.
자동 테스트 통과를 이 인수의 완료로 표시하지 않는다. 다음 개발은 EP3b다.
