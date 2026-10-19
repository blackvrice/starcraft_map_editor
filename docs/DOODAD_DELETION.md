# 두다드 복합 삭제 지원 확대

2026-10-19. 첫 미완료 M6.2 항목의 **미지원 사례 확대** 중 비활성 두다드의
검증된 단일 삭제를 구현했다. 실제 게임/외부 에디터 왕복과 더 넓은 미지원 입력은
미완료로 유지한다. [ADR-0026](decisions/0026-disabled-doodad-deletion.md).

2026-10-19 후속: [ADR-0027](decisions/0027-atomic-batch-doodad-deletion.md)에 따라
**두다드만 선택한 최대 32개 일괄 삭제**를 추가했다. 아래 단일 삭제 결과는
초기 구현 당시 기록이며 최신 다중 삭제 범위/결과는 마지막 절을 따른다.

## 계획과 소스 분석

1. 기존 삭제 계획/배치 정의/상태 편집/복합 clipboard/확인 창을 분석한다.
2. 활성 상태로만 제한하던 삭제 검사를 알려진 DD2 0/1 상태로 확장한다.
3. THG2의 정확한 상태 플래그를 UI 후보와 domain에서 같은 규칙으로 검증한다.
4. 거부/바이트 보존·Undo/Redo·한국어/영어 UI·실제 MPQ 왕복과 전체 게이트를 검증한다.

기존 `ChkBasicEditing.setDoodadEnabled`와 복합 clipboard가 이미 DD2 비활성=1,
sprite-unit의 THG2 bit15를 지원한다. 삭제 계획은 DD2=0과 활성 THG2만 허용해
일관된 비활성 입력도 거부했다. 상태 편집이 삭제 계획을 호출하므로 삭제 쪽에서
상태 편집 함수를 호출하면 재귀가 된다. 원문을 활성 상태로 정규화하는 우회 대신
`DoodadOverlayRecipe.flagsForEnabled`에 플래그 계산만 두고 원래 문서에서 검증한다.
순수 스프라이트와 유닛형 오버레이의 차이는 코드 주석으로 명시했다.

새 검사는 상수 시간의 상태/플래그 대조이며 기존 footprint/복원/section 검사를
그대로 사용한다. 추가 전체 문서 복사나 별도 parser/의존성을 도입하지 않았다.
기존 선형 스캔의 인덱스화는 이 작은 변경에서 이익이 확인되지 않아 보류했다.
성능 수치 개선이나 게임 동작을 측정했다고 주장하지 않는다.

## 현재 계약

| DD2 값 | overlay 없음 | pure sprite | sprite-unit |
| --- | --- | --- | --- |
| 0 활성 | 지원 | THG2 flags `0x1000`만 | THG2 flags `0x0000`만 |
| 1 비활성 | 지원 | THG2 flags `0x1000`만 | THG2 flags `0x8000`만 |
| 나머지 | 거부 | 거부 | 거부 |

유효한 단일 DIM/ERA/MTXM/DD2/TILE, 일치한 로컬 recipe/footprint/현재 지형,
검증된 TILE 복원 값이 필요하다. 확인하지 않은 인근 두다드와 겹칠 가능성은 계속 거부한다.
overlay가 있으면 단일 THG2와 **사용자가 선택한** record의 종류/좌표/owner/
flags/unused가 모두 일치해야 한다. 후보가 한 개여도 자동 선택하지 않는다.
좌표가 같은 다른 레코드나 알 수 없는 플래그를 추측해 정리하지 않는다.

삭제는 MTXM 복원·대상 DD2·확인한 THG2만 한 명령으로 바꾼다. TILE과 다른
레코드/원시 섹션은 유지하며 한 Undo로 복원한다. 준비 이후 문서 변경 또는
필수 레이어 잠금은 적용을 막는다. 혼합 선택·TILE 부재·불일치 상태는 미지원이다.
비활성 DD2에 활성 유닛형 overlay가 남은 불일치 입력도 자동 보정하지 않는다.

확인 창은 대상 DD2 인덱스/종류/원시 상태와 recipe를 표시한다. 한영으로 번역하고
overlay 귀속 선택 전에는 삭제를 비활성화한다. 취소는 맵과 Undo를 바꾸지 않는다.

## 단일 삭제 구현 당시 결과

| 요구사항 / 시나리오 | 기대 결과 | 검증 |
| --- | --- | --- |
| FR-203/213 단일 복합 삭제 | 한 Undo/Redo, 다른 객체 보존 | application |
| FR-204/217/218 상태·geometry·복원 정보 | 알려진 일관 상태만 지원, 거부 시 무변경 | domain 13개 |
| FR-203 명시적 overlay 귀속·취소 | 자동 선택 없음, 같은 좌표의 미선택 레코드 보존 | domain/UI |
| NFR-008 한국어 600px/영어 1200px | 문구/버튼 잘림·예외 없음, 확인·취소 가능 | widget |
| FR-101/102/104 실제 MPQ 저장/재열기 | 삭제 결과 bytes 유지, 원본 불변 | 실제 helper 3개 |

- 수정 전 새 domain 테스트는 **9 통과/3 실패**였다. 비활성 3종만 기존 상태
  검사에 걸리는 것을 `.dart_tool/doodad-delete-before.log`로 재현했다.
- 수정 후 domain/상태/clipboard 집중 검사는 15개 통과했다. 이후 geometry/섹션/
  overlay 거부 행렬을 추가한 domain 13개 + 실제 MPQ 3종은 **16개 모두 통과**했다.
  `.dart_tool/doodad-delete-roundtrip.log`.
- 기존 객체 배치/삭제 + 새 비활성 명령 3종/한영 UI 2종 **135개 통과**.
  `.dart_tool/doodad-delete-application.log`.
- 정적 분석에서 테스트 제어문 중괄호 1개를 지적하여 형식 수정 후 재실행했다.
- `flutter analyze`: 무이슈.
- `flutter test`: **2586 통과 / 83 조건부 skip / 실패 0**.
  `.dart_tool/doodad-delete-full-tests.log`. 새 실제 MPQ 3개는 기본 실행에서 환경
  변수 미설정으로 skip되며 위 별도 실행에서 모두 통과했다. 기존 조건부 skip도
  성공으로 계산하지 않는다.
- Windows Debug 빌드 성공, native CTest **7/7 통과**.
  `.dart_tool/doodad-delete-windows-build.log`.
- 필수 `dart format --output=none --set-exit-if-changed lib test tool`은 exit 1.
  기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 차이가 있으며 이번 변경 파일은 차이가 없다. 관련 없는 파일은 변경하지 않았다.
- 실제 SDK는 **Flutter 3.47.5 / Dart 3.13.4**, 기준 3.44.8/3.12와 다르다.
  기존 CascLib CMake 최소 버전 경고는 빌드 성공을 막지 않았다.

사용자의 자동 테스트·빌드 한정 지시에 따라 실제 열린 앱, SC:R, 외부 에디터를
조작하지 않았다. byte-exact MPQ 왕복은 게임/외부 상호 운용 인수 완료가 아니다.

## 다중 삭제 계획과 구현

1. 단일 계획/컨트롤러/확인 창·기존 MPQ fixture를 분석했다. 기존 UI는 다중
   선택을 거부하고 단일 삭제를 순차 적용하면 뒤 레코드의 인덱스가 바뀐다.
2. 원래 문서의 DD2 인덱스/recipe/명시 overlay 인덱스를 요청 목록으로 고정한다.
3. 모든 요청을 같은 원본에서 검증하고 sparse 복원 셀과 원본 레코드 인덱스를 모은다.
4. 최종 MTXM/DD2/THG2를 한 번씩 생성하고 기존 한 Undo 적용 경로로 게시한다.
5. 전체 거부·경계·한영 UI·실제 MPQ 왕복과 전체 게이트를 검증한다.

`DoodadDeletionPlan.createBatch`는 1~32개 요청만 읽고 33개째에서 거부한다.
비어 있거나 무한 반복하는 iterable도 무제한 읽지 않는다. DD2 중복 선택과
THG2 중복 귀속을 거부한다. 기존 상태/지형/TILE/overlay 검증을 재사용하며
먼저 삭제한 가상 문서로 다음 항목을 검증하지 않는다.

선택한 두다드의 recipe가 모두 확인된 경우에만 실제 **전체 사각 footprint**를
비교하여 인접하지만 겹치지 않는 선택을 허용한다. 쓰지 않는 sparse 셀도 footprint에
포함된다. 선택하지 않은 이웃은 기존 최대 16×16 영향 범위 검사를 유지한다.
잘못된 선택 recipe는 그 항목 검증에서 전체를 거부하므로 이웃 범위 완화의 우회가 아니다.
한 항목이라도 지형/상태/overlay/섹션 검증에 실패하면 문서/Undo는 바뀌지 않는다.

확인 창은 개수와 각 레코드의 종류/상태·recipe·overlay 선택을 표시한다.
overlay가 있는 항목을 모두 확인하기 전까지 삭제 버튼을 비활성화한다.
같은 좌표의 미선택 THG2를 자동 삭제하지 않는다. 취소·혼합 선택·33개 이상·
metadata 조회 중 문서 교체는 무변경 거부한다. 적용 직전 문서 identity와 레이어
잠금도 재검사한다. 일반 Unit/Sprite/Location 삭제 경로는 바꾸지 않는다.

## 다중 삭제 최적화와 제한

검증 단계는 sparse 복원 셀만 모으고 폐기할 전체 출력 섹션을 만들지 않는다.
최종 출력 섹션 생성/문서 적용은 한 번이다. 같은 종류의 recipe 조회는 확인 창
안에서 재사용한다. 서로 다른 종류는 기존 gateway 조회를 직렬 수행한다.
최대 32개·최대 8192 footprint 셀로 제한하며 반복 typed decode는 기존 검증을
재사용한다. 전체 카탈로그의 다종류 일괄 조회/비동기 UI 색인과 실제 RSS/지연
프로파일링은 이번 범위가 아니며 성능 수치 향상을 측정했다고 주장하지 않는다.

겹친 실제 footprint, 확인하지 않은 인근 두다드, TILE 없음/오염·모호한 섹션,
불일치 상태, 두다드 외 객체가 섞인 삭제는 계속 미지원이다. 게임/외부 에디터
상호 운용 인수는 별도로 남으며 코드 지원 확대로 완료 처리하지 않는다.

## 다중 삭제 검증 결과

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/004 인접한 활성/비활성 2개 | 한 Undo/Redo·원본 인덱스 유지 | domain/application |
| FR-102 비선택 DD2/THG2·unknown bytes | 레코드 순서/원시 bytes 보존 | domain/실제 MPQ |
| FR-204/217/218 한 항목 손상·겹침·중복 귀속 | 전체 거부, 부분 삭제 없음 | domain/application |
| FR-203/NFR-008 한영 확인/취소 | 모든 overlay 명시 확인·600/1200px 예외 없음 | widget |
| FR-005 metadata 조회 중 문서 교체 | 창/Apply 거부, 새 문서 무변경 | widget |
| FR-101/104 실제 MPQ 왕복 | 단일/다중 3유형 저장·재열기, 원본 불변 | integration 6개 |

집중 검증 **155개 통과**: batch domain 6개, 객체 편집/확인 창 143개,
실제 MPQ 단일/다중 6개. `.dart_tool/doodad-batch-focused-final.log`.
도메인 32개 경계/무한 iterable/역순 인덱스·한 항목 손상/이웃·겹침·중복 귀속,
한영 UI 명시 확인·취소/혼합/초과/조회 중 교체를 확인했다. 정적 분석은 새 테스트의
중괄호와 fake의 override 위치를 지적했고 수정 후 무이슈다.
최종 게이트:

- `flutter analyze`: 무이슈.
- `flutter test`: **2600 통과 / 86 조건부 skip / 실패 0**.
  `.dart_tool/doodad-batch-full-tests.log`. 실제 MPQ 6개는 기본 실행에서 환경 변수
  미설정으로 skip되며 위 집중 실행에서는 모두 통과했다.
- Windows Debug 빌드 성공, native CTest **7/7 통과**.
  `.dart_tool/doodad-batch-windows-build.log`.
- 필수 format 게이트는 기존 미수정 테스트 3개 차이로 exit 1이며 이번 변경 파일은
  모두 포맷 차이가 없다. 파일 목록은 단일 삭제 당시 기록과 같다.
- SDK **Flutter 3.47.5 / Dart 3.13.4**, 기준 3.44.8/3.12와 다르다.
  기존 CascLib CMake 최소 버전 경고는 빌드를 실패시키지 않았다.
- 실제 열린 앱/SC:R/외부 에디터/DPI·고대비 수동 인수는 실행하지 않았다.
  자동 테스트·빌드만 진행한다는 사용자 지시를 유지했다.

커밋 선별 중 새 지역화 파일의 loose Git blob `a3ce6ad2...`에서 inflate/CRC 오류가
발견됐다. `git hash-object`로 현재 작업 파일이 그 해시와 같고 HEAD/default index는
다른 기존 해시임을 확인했다. 해당 객체 하나를 `.dart_tool`에 백업하고 검증된
작업 파일에서 재생성한 뒤 전체 스트림 읽기·staged diff·`git fsck --full --no-dangling` 검사를 통과했다.
원인은 확정하지 않았으며 사용자 원문·기존 index·커밋 이력은 변경하지 않았다.
