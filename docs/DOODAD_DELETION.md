# 두다드 복합 삭제 지원 확대

2026-10-19. 첫 미완료 M6.2 항목의 **미지원 사례 확대** 중 비활성 두다드의
검증된 단일 삭제를 구현했다. 실제 게임/외부 에디터 왕복과 더 넓은 미지원 입력은
미완료로 유지한다. [ADR-0026](decisions/0026-disabled-doodad-deletion.md).

2026-10-19 후속: [ADR-0027](decisions/0027-atomic-batch-doodad-deletion.md)에 따라
**두다드만 선택한 최대 32개 일괄 삭제**를 추가했다. 아래 단일 삭제 결과는
초기 구현 당시 기록이며 최신 다중 삭제 범위/결과는 마지막 절을 따른다.

2026-10-19 혼합 후속: [ADR-0028](decisions/0028-doodad-sprite-mixed-deletion.md)에
따라 **두다드 최대 32개 + 별도 선택 Sprite 최대 256개**의 혼합 삭제를 지원한다.
기존 절은 당시 이력이며 최신 범위/검증은 마지막 혼합 삭제 절을 따른다.

2026-10-19 Unit 후속: [ADR-0029](decisions/0029-unit-mixed-doodad-deletion.md)에 따라
**Unit 최대 256개까지 혼합 삭제**를 지원한다. 남는 상호 연결 유닛은 관계 해제를
별도로 확인하며 Location 혼합과 게임/외부 에디터 인수는 남는다.

2026-10-20 Location 후속: [ADR-0030](decisions/0030-reviewed-location-mixed-deletion.md)에
따라 저장된 일반 TRIG/MBRF에서 정적 미참조를 검증한 Location 최대 254개를
혼합 삭제한다. 명시 확인한 MRGN 슬롯만 비우며 고정 ID/공유 문자열을 보존한다.
이전 절의 미지원 문구는 당시 이력이며 최신 프로필/검증은 마지막 절을 따른다.

2026-10-20 이웃 후속: [ADR-0031](decisions/0031-retained-doodad-neighbor-validation.md)에
따라 후보가 하나인 동일 종류의 미선택 이웃은 현재 지형/상태/경계를 검증하고 실제
전체 footprint가 겹치지 않으면 보존한다. 다른 종류/복수 후보/손상 이웃은 계속 거부한다.

2026-10-20 다른 종류 후속: [ADR-0032](decisions/0032-other-type-doodad-neighbors.md)에
따라 가능한 이웃 종류도 기존 카탈로그 한 번 조회에 포함한다. 최대 32종/256개
범위의 완전한 단일 후보는 종류가 달라도 실제 지형/상태/비겹침 검증 후 보존한다.
앞의 날짜별 미지원 문구는 당시 이력이며 최신 범위/결과는 마지막 절을 따른다.

2026-10-20 복수 후보 후속: [ADR-0033](decisions/0033-all-doodad-neighbor-candidates.md)에
따라 전체 후보의 geometry/비겹침과 최소 한 후보의 현재 지형 일치를 검사한다.
지형 불일치 후보의 영역도 제외하지 않으며 정의를 하나로 추측하지 않는다.

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
완전한 카탈로그 후보 집합으로 미선택 이웃 최대 256개의 지형과 전체 영역을
검증할 수 있다. 한 후보 이상이 현재 지형과 일치하고 모든 후보 영역이 삭제 대상과
겹치지 않아야 한다. 미선택 이웃을 삭제하거나 overlay 귀속을 추정하지 않는다.
overlay가 있으면 단일 THG2와 **사용자가 선택한** record의 종류/좌표/owner/
flags/unused가 모두 일치해야 한다. 후보가 한 개여도 자동 선택하지 않는다.
좌표가 같은 다른 레코드나 알 수 없는 플래그를 추측해 정리하지 않는다.

삭제는 MTXM 복원·대상 DD2·확인한 THG2를 한 명령으로 바꾼다. Unit 혼합은
선택 UNIT와 명시 확인한 남는 peer의 관계 필드만 추가 변경한다. TILE과 다른
레코드/원시 섹션은 유지하며 한 Undo로 복원한다. 준비 이후 문서 변경 또는
필수 레이어 잠금은 적용을 막는다. Location 혼합은 명시 확인한 슬롯만 비운다.
참조/미확인 트리거·Anywhere·TILE 부재·불일치 상태는 미지원이다.
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

위 문단은 다중 삭제 초기 구현의 기록이다. 아래 후속 조회 최적화에서 종류별
반복 스캔을 제거했다. typed decode와 실제 지연/RSS 측정은 계속 후속 범위다.

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

## 다종류 Recipe 조회 계획과 실행

2026-10-19 후속. M6.2의 삭제 검토 준비 경로를 개선한다. 삭제 가능 범위와
TILE/overlay 귀속 검증은 넓히지 않으며 게임·외부 에디터 인수도 완료 처리하지 않는다.

1. 소스 분석: `doodadRecipes(type)`는 각 종류마다 전체 metadata를 순회했다.
   확인 창의 cache는 같은 종류만 재사용하여 최대 32종 선택 시 최대 32회 스캔했다.
   개별 페이지 모델은 페이지 내부 순서를 보장하지만 조회 함수는 페이지 간
   중복/전체 개수·출처 변경과 요청 ID/경로/limit 불일치를 충분히 검사하지 않았다.
2. 실행: `doodadRecipesForTypes`로 선택 종류를 한 번에 전달한다. 단일 조회도
   같은 경로를 사용한다. 전체 페이지 검증이 끝난 후 불변 map/list를 반환하고
   없는 종류는 빈 목록으로 남긴다. 썸네일/atlas/배치 카탈로그 UI 상태는 읽지 않는다.
3. 안전: 입력을 33개째에서 중단하고 32개 이하·16-bit ID만 받는다. 페이지의
   요청 ID/경로/kind/tileset/offset/limit/metadata 모드, 전체 개수, 엄격 증가 key,
   product/build/helper/CascLib 출처 일관성을 확인한다. 뒤 페이지 실패도 전체 거부한다.
4. 수명: 조회마다 고유 operation ID를 사용한다. 설치·문서·편집 이력 변경과
   종료에서 epoch를 무효화하고 진행 중 요청을 best-effort 취소한다. 취소의 동기/
   비동기 예외는 삼키지만 늦은 성공은 다시 허용하지 않는다. 응답 후 문서 identity도
   확인하므로 UI 동기화 호출 순서에 의존해 다른 문서에 결과를 제공하지 않는다.
5. UI: 다중 확인 창은 전체 종류 조회 한 번 이후에만 열린다. 한 종류라도 recipe가
   없거나 조회 중 문서가 바뀌면 창/적용을 거부한다. 명시 overlay 선택·취소·한 Undo는
   기존 경로를 유지한다. 복잡한 원자적 조회 계약을 코드 주석으로 남겼다.

## 조회 요구사항과 검증

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203 다종류 삭제 검토 | 32종도 전체 카탈로그 한 번 순회 | application 합성 260항목/2페이지 |
| FR-203 종류별 variant/누락 | variant 순서·불변 결과, 누락은 빈 목록 | application |
| FR-005/217 조회 중 설치·맵 교체/종료 | 요청 취소·늦은 결과/후속 페이지 거부 | application 3상황 x 취소 정상/동기·비동기 실패 |
| FR-217 잘못된 요청/개수/출처/중복 key | 부분 결과 없이 전체 실패 | application |
| FR-102/204 UI 성공/누락 | 준비 중 문서 불변·한 Undo 복원/무변경 거부 | widget 다종류 2개 |
| NFR-006/009 입력 상한/중첩 조회 | 외부 도구 없이 무한 입력 33개만 읽음·고유 요청 ID | application |

합성 32종/260항목의 실제 관찰은 **요청 2개**다. 이전 코드의 종류별 전체 스캔은
같은 조건에서 계산상 64개 요청이며 이전 버전의 벽시계 측정을 수행한 것은 아니다.
조회 복잡도를 종류 수 x 전체 항목에서 전체 항목 + 선택 종류로 줄였다. helper
실행 시간·실제 SC:R 설치 데이터의 지연/RSS 개선 수치는 측정하지 않았다.

최종 결과:

- 신규 조회 회귀 26개와 다종류 확인 창 2개를 추가했다. 카탈로그/객체 편집 전체
  집중 실행은 **515 통과 / 10 조건부 skip**이다.
  `flutter test test/application/placement_catalog_controller_test.dart test/application/object_placement_command_test.dart`.
  `.dart_tool/doodad-lookup-application.log`.
- `flutter analyze`: 무이슈. 최초 실행의 테스트 취소 fake 중괄호 지적 1개를
  수정한 뒤 다시 확인했다. `.dart_tool/doodad-lookup-analyze.log`.
- `flutter test`: **2628 통과 / 86 조건부 skip / 실패 0**.
  `.dart_tool/doodad-lookup-full-tests.log`. skip을 검증 성공으로 계산하지 않는다.
- `flutter build windows --debug`: 성공.
  `.dart_tool/doodad-lookup-windows-build.log`. 기존 CascLib CMake 최소 버전 경고는 유지된다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- `MAP_ARCHIVE_HELPER_PATH`를 빌드된 helper로 지정하고
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **6/6 통과**.
  `.dart_tool/doodad-lookup-mpq.log`. 원본 불변·단일/다중 삭제의 Undo/Redo와
  Save As/재열기를 확인했다. 새 metadata 조회가 실제 CASC에서 검증됐다는 뜻은 아니다.
- `dart format --output=none --set-exit-if-changed lib test tool`: 기존 미수정
  infrastructure 테스트 3개 차이로 exit 1이다. 파일 목록은 위 단일 삭제 기록과
  같으며 이번 변경 파일 4개는 모두 포맷 차이가 없다.
  `.dart_tool/doodad-lookup-format.log`.
- SDK는 **Flutter 3.47.5 / Dart 3.13.4**다. 기준 3.44.8/3.12 또는 CI에서
  재검증하지 못했다. 실제 열린 앱·SC:R·외부 에디터 조작과 깨끗한 PC 인수도
  사용자 지시에 따라 수행하지 않았다. 자동 통과를 전체 기능/출시 인수로 보지 않는다.

## 혼합 삭제 계획과 소스 분석

1. 기존 확인 창은 두다드 외 객체가 있으면 먼저 거부한다. 일반 Sprite 삭제는
   THG2를 별도로 다시 작성하므로 두 명령을 연속 적용하면 overlay 인덱스가
   이동하고 부분 삭제가 생길 수 있다. 이번에는 Sprite 혼합만 확대한다.
2. `createBatch`에 원본 선택 Sprite 인덱스를 전달한다. 두다드별 recipe·상태·
   TILE·footprint·overlay 명시 확인은 그대로 유지한다. 원본 THG2의 유일성/완전성,
   선택 인덱스/중복·상한을 검증한 뒤 확인한 overlay와 합집합을 만든다.
3. 같은 overlay가 Sprite로도 선택되면 한 번 제거한다. Sprite 선택만으로
   overlay 귀속을 확인했다고 간주하지 않으며 두다드 간 중복 귀속은 계속 거부한다.
4. 확인 창은 두다드/선택 Sprite 개수와 선택 THG2 인덱스·종류를 한영으로
   보여준다. pure sprite/unit-sprite 모두 지원하며 개별 Sprite의 알 수 없는
   플래그를 재해석/정규화하지 않는다. 명시 선택하지 않은 레코드/다른 섹션은 보존한다.
5. domain → application의 기존 한 명령 적용 경로를 사용한다. 취소·실패·필수
   레이어 잠금·문서 교체는 무변경 거부한다. UI는 바이너리/I/O를 호출하지 않는다.

### 최적화 판단

THG2 삭제 인덱스는 집합으로 합쳐 원본 섹션을 한 번만 스캔/생성한다. 추가
Sprite 검증을 MTXM/DD2 출력 생성보다 앞에 두어 잘못된 요청의 불필요한 복사를
피했다. 입력은 257개까지만 읽으며 선택 Sprite 256개와 overlay 32개의 합집합은
최대 288개다. 기존 두다드 recipe 조회/footprint 검증을 재사용하고 새 캐시/의존성은
도입하지 않았다. 실제 지연/RSS 개선 수치를 측정했다고 주장하지 않는다.

## 혼합 삭제 요구사항과 검증

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203 두다드/Sprite 혼합 삭제 | 개수·원본 THG2 목록 표시, 한 Undo/Redo | application/widget |
| FR-102/217 overlay와 선택 Sprite 중복 | 명시 귀속 후 한 번만 제거·미선택 bytes 보존 | domain/application/MPQ |
| FR-217 선택 overlay만 있고 귀속 확인 없음 | 자동 확인하지 않고 전체 거부/Apply 비활성 | domain/widget |
| FR-204/218 잘린/중복/누락 THG2·잘못된 인덱스 | 정규화/부분 적용 없이 거부 | domain/application |
| FR-005/213 잠금·오래된 계획 | 문서/이력 불변·원래 명령 한 번만 적용 | application |
| NFR-008 한국어 600px/영어 1200px | 세 overlay 유형의 확인·취소·삭제, 예외 없음 | widget |
| NFR-006/009 선택 256/257개·무한 iterable | 256 허용·257에서 차단, 무제한 소비 없음 | domain/widget |
| FR-101/104 자체 제작 맵 MPQ | 단일/다중/혼합 3유형 Save As·재열기/원본 불변 | integration |

집중 검증은 181개 통과했다(domain 혼합 10 + 기존 batch 6 + 객체 편집/위젯
156 + 실제 MPQ 9). 최초 analyze는 새 domain 테스트의 if 중괄호 1개를 지적하여
수정했다. `.dart_tool/doodad-sprite-focused.log`.

최종 실행 결과:

- `flutter analyze`: 무이슈. `.dart_tool/doodad-sprite-analyze.log`.
- `flutter test`: **2649 통과 / 89 조건부 skip / 실패 0**.
  `.dart_tool/doodad-sprite-full-tests.log`. 새 MPQ 혼합 3개를 포함한 조건부 skip을
  통과로 세지 않았다. 실제 MPQ 9개는 helper 경로를 지정한 별도 실행에서 검증했다.
- `flutter build windows --debug`: 성공.
  `.dart_tool/doodad-sprite-windows-build.log`. 기존 CascLib CMake 최소 버전 경고는 남는다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper로 `MAP_ARCHIVE_HELPER_PATH`를 지정하고
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **9/9 통과**.
  `.dart_tool/doodad-sprite-mpq.log`.
- `dart format --output=none --set-exit-if-changed lib test tool`: 기존 미수정
  `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개 차이로 exit 1. 이번 변경 파일은 포맷 차이가 없다.
  `.dart_tool/doodad-sprite-format.log`.
- SDK **Flutter 3.47.5 / Dart 3.13.4**로 검증했다. 기준 3.44.8/3.12 및 CI
  버전에서 재검증하지 못했으며 전체 게이트가 동일 환경에서 통과했다고 주장하지 않는다.

Unit/Location 혼합, 실제 겹친 footprint, 미확인 이웃, 복원 정보 부재·오염은
여전히 미지원이다. 선택 Sprite의 숨은 DD2 귀속을 추정하거나 미선택 overlay를
추가 삭제하지 않는다. 실제 앱·SC:R·외부 에디터·고대비/DPI/깨끗한 PC 인수는
자동 테스트·빌드만 허용한 사용자 지시에 따라 수행하지 않는다.

## Unit 혼합 삭제 계획과 실행

1. 기존 `deleteSelection`의 일반 UNIT 삭제는 `ChkBasicEditing.unlinkUnits`로
   상호 관계를 해제한다. Doodad 삭제와 순차 결합하면 부분 적용/여러 Undo가 된다.
   선택 대상의 outgoing만 검사해서는 다른 유닛이 가리키는 비대칭 incoming을 놓친다.
2. 순수 domain `UnitDeletionPlan`에서 유일하고 완전한 UNIT·명시 원본 인덱스를
   검증한다. 선택 class ID를 가리키는 incoming도 수집하고 기존 unlink로 ID
   유일성·알려진 관계 flags·상호 참조를 검사한다. 무관한 raw 관계는 재해석하지 않는다.
3. 명시 선택한 Unit만 제거한다. 남는 정상 peer은 관계 flags/peer class ID만
   해제하고 다른 bytes는 보존한다. 남는 peer의 원본 인덱스를 UI에 전달한다.
4. 확인 창에 Doodad/Unit/Sprite 개수·선택 UNIT·남는 peer의 인덱스/종류를
   표시한다. peer이 있으면 체크박스 확인까지 Apply를 막는다. domain도 전달받은
   `confirmedUnitPeerRecordIndices`와 영향 집합의 정확한 일치를 요구한다.
5. 검증한 UNIT replacement를 기존 Doodad 계획에 합쳐 한 번 적용/Undo한다.
   필수 Units 레이어도 재검사하며 overlay 명시 귀속·기존 TILE/footprint/문서
   identity 검증은 유지한다. 기존 일반 객체 삭제 경로와 CHK 포맷은 바꾸지 않는다.

### 최적화 판단과 상한

Unit/peer 확인 목록은 각각 257개까지만 읽고 256개 초과/중복을 거부한다.
incoming 수집은 한 번 순회하며 정상 상호 관계의 후보가 선택 수의 두 배를
넘으면 거부한다(최대 512개). 새 관계 알고리즘/캐시 대신 기존 unlink의 후보별
UNIT 스캔을 재사용했다. 확인 창 준비와 Apply에서 계획을 다시 생성하는 비용은
명시 확인/문서 안전성 때문에 유지한다. 실제 지연/RSS 향상은 측정하지 않았다.

### 요구사항 체크리스트

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/213 Unit+Doodad+Sprite 삭제 | 선택/영향 개수·한 Undo/Redo | application/widget/MPQ |
| FR-102 남는 애드온/나이더스 한 peer | 관계 필드만 해제·다른 raw bytes 보존 | domain/application/MPQ |
| FR-217 양쪽 연결 유닛 선택 | 선택 Unit만 제거, 추가 peer 확인 없음 | domain/widget |
| FR-204/218 비대칭/unknown flags·중복/누락 ID | 관계를 추측 해제하지 않고 전체 거부 | domain |
| FR-203 peer 확인 없음/잘못된 집합 | domain 거부·checkbox 미확인 Apply 비활성 | domain/widget |
| FR-005/213 Units 등 잠금·오래된 계획 | 문서/이력 불변 거부 | application |
| NFR-006/009 256/257개·무한 입력 | 256 허용·257개만 읽어 차단 | domain/widget |
| NFR-008 한국어 600px/영어 1200px | 취소·overlay/peer 확인·스크롤·한 Undo | widget |
| FR-101/104 자체 제작 MPQ 15종 | 단일/다중/Sprite/Unit 혼합 Save As·재열기·원본 불변 | integration |

집중 검증 **211개 통과**(Unit domain 15 + Sprite domain 10 + batch domain 6 +
객체 편집/위젯 165 + 실제 MPQ 15). `.dart_tool/doodad-unit-focused.log`.
초기 domain 실행은 `chk.dart`가 basic editing을 재노출하지 않아 import 누락으로
컴파일 실패했다. 명시 import로 수정 후 통과했다. 초기 application은 164 통과/
1 실패였으며 영어 창의 화면 밖 overlay가 lazy 생성 전인데 `ensureVisible`을
호출한 테스트 보조 오류였다. 실제 스크롤 기반 검사로 수정하고 두 언어의 확인/
취소를 재검증했다. 앱 결함을 수정한 것으로 계산하지 않는다.

최종 게이트:

- `flutter analyze`: 무이슈. `.dart_tool/doodad-unit-analyze.log`.
- `flutter test`: **2673 통과 / 95 조건부 skip / 실패 0**.
  `.dart_tool/doodad-unit-full-tests.log`. 새 Unit 혼합 MPQ 6개를 포함한 skip은
  검증 성공이 아니다. 실제 MPQ 15개는 별도 helper 지정 실행에서 모두 통과했다.
- `flutter build windows --debug`: 성공.
  `.dart_tool/doodad-unit-windows-build.log`. 기존 CascLib CMake 최소 버전 경고는 남는다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper를 `MAP_ARCHIVE_HELPER_PATH`로 지정한
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **15/15 통과**.
  `.dart_tool/doodad-unit-mpq.log`. 원본 파일·Undo/Redo·재열기 bytes를 확인했다.
- `dart format --output=none --set-exit-if-changed lib test tool`: 기존 미수정
  `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개 차이로 exit 1. 이번 변경 파일에는 포맷 차이가 없다.
  `.dart_tool/doodad-unit-format.log`.
- SDK **Flutter 3.47.5 / Dart 3.13.4**를 사용했다. 기준 3.44.8/3.12와 CI에서
  재검증하지 않았다. Location 혼합과 실제 게임/외부 에디터·깨끗한 PC·고대비/DPI
  수동 인수는 미완료다. 자동 테스트·빌드 한정 지시대로 실제 앱을 조작하지 않았다.

## Location 혼합 삭제 계획과 실행

2026-10-20. 첫 미완료 M6.2의 미지원 사례 확대 중 정적 참조 검증형 Location
혼합 삭제를 추가한다. 일반 객체 삭제 경로 전체의 정책을 바꾸는 작업은 아니다.

1. 소스 분석: 기존 `deleteLocations`는 선택 MRGN의 20-byte 슬롯만 0으로
   비우므로 ID가 밀리지 않는다. 하지만 이것만으로 트리거 미참조는 증명되지 않는다.
   기존 맵 간 복사는 unknown/EUDX/예약 bytes까지 거부하는 portable 검증이 있다.
2. 순수 `LocationDeletionPlan`에서 MRGN의 유일성/64·255 슬롯 구조와 선택
   인덱스를 검사한다. 빈 슬롯/Anywhere 64·중복/범위 밖 값은 거부한다.
3. 저장된 TRIG/MBRF 합계 4096개 이하를 검사한다. TRIG는 유일해야 하며 MBRF
   부재는 허용한다. 잘림/중복은 거부한다. 엄격한 canonical 검증을
   `ChkTriggerPortability`로 옮겨 문서 전송과 공유하며 기존 transfer 진단은 유지한다.
4. 비활성 record/slot을 포함해 모든 알려진 location 인자를 조회한다. 조건·
   액션·목적지에서 선택 ID가 사용되거나 slot을 해석할 수 없으면 전체 거부한다.
   읽는 동안 트리거를 재작성하지 않으며 외부/EUD 동적 코드를 실행하지 않는다.
5. 확인 창은 로케이션 ID/MRGN 인덱스·개수를 표시한다. 슬롯 비우기 checkbox가
   확인돼야 Apply가 가능하며 domain도 정확한 `confirmedLocationRecordIndices`
   집합을 요구한다. 외부 스크립트 참조는 미검증이라는 경고를 함께 표시한다.
6. MRGN replacement를 기존 두다드/Unit/Sprite 계획과 결합하여 한 명령으로
   적용한다. Location 레이어도 재검사한다. 취소/오류/잠금/문서 교체는 부분 적용하지
   않는다. 선택하지 않은 슬롯·문자열·TRIG/MBRF·TILE/unknown bytes를 보존한다.

### 최적화 판단과 한계

중복된 portable 검증을 공유하여 소비자별 규칙이 달라지는 것을 막았다. canonical
검증 뒤 location 인자를 조회하는 두 순회는 기존 검증 계약을 그대로 쓰기 위해
유지한다. Trigger 총량은 payload 크기에서 먼저 검사한다. 선택/확인 iterable은
255개까지만 읽고 최대 254개만 허용한다. 출력 MRGN은 한 번 생성한다.
복원/관계 검증과 preview/Apply 재검증은 유지하며 실제 지연/RSS 개선은 미측정이다.
정적 미참조는 저장된 canonical TRIG/MBRF 범위의 결과이지 외부/미적용 스크립트나
런타임 동적 참조까지 없다는 보장이 아니다. 그 경계는 확인 창에서도 명시한다.

### 요구사항과 테스트

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/213 Location 포함 혼합 삭제 | 각 확인 후 다섯 레이어를 한 Undo/Redo | application/widget/MPQ |
| FR-102/104 64/255 MRGN·공유 이름 | 선택 20-byte만 비움·ID/문자열/다른 슬롯 보존 | domain/MPQ |
| FR-204/218 조건/액션/목적지·비활성 참조 | 사용 중 ID는 전체 거부 | domain/widget |
| FR-204 unknown/EUDX/예약 bytes·잘린 섹션 | 미참조라고 추측하지 않음 | domain/기존 transfer 회귀 |
| FR-203 Anywhere/빈 슬롯·잘못된 확인 집합 | 준비/적용 무변경 거부 | domain/widget |
| FR-005/213 확인 중 잠금·조회 중 교체 | 맵/Undo 불변·다시 준비/해제 후 검증 | application/widget |
| NFR-006/009 254/255 선택·무한 입력·TRIG 예산 | 254 허용·255까지만 읽음·4096개 상한 | domain/widget |
| NFR-008 한영 600/1200px | 취소·세 확인·스크롤·재시도, 예외 없음 | widget |
| FR-101/104 자체 제작 MPQ | Location/전체 혼합 포함 21종 Save As·재열기·원본 불변 | integration |

집중 검증 **259개 통과**(Location domain 19 + Unit 15 + Sprite 10 + batch 6 +
기존 transfer 12 + 객체 편집/위젯 176 + 실제 MPQ 21).
`.dart_tool/doodad-location-focused.log`. 최초 analyze는 옮긴 검증의 미사용 비교
함수 1개와 if 중괄호 3개를 지적했다. 미사용 함수를 제거하고 중괄호를 보완했다.
참조/삭제 동작 테스트는 실패하지 않았다. 최종 게이트:

- `flutter analyze`: 무이슈. `.dart_tool/doodad-location-analyze.log`.
- `flutter test`: **2703 통과 / 101 조건부 skip / 실패 0**.
  `.dart_tool/doodad-location-full-tests.log`. 새 Location MPQ 6개를 포함한 skip을
  성공으로 세지 않았으며 실제 MPQ는 별도 helper 지정 실행에서 확인했다.
- `flutter build windows --debug`: 성공.
  `.dart_tool/doodad-location-windows-build.log`. 기존 CascLib CMake 최소 버전 경고는 유지된다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 helper 경로를 `MAP_ARCHIVE_HELPER_PATH`로 지정하여 집중 회귀를 다시
  실행했다. **259/259 통과**, 실제 MPQ **21/21 포함**.
  `.dart_tool/doodad-location-focused-final.log`. 문자열/고정 ID·원본/Undo/재열기
  bytes를 검증했으며 실제 게임 인수로 보지 않는다.
- `dart format --output=none --set-exit-if-changed lib test tool`: 기존 미수정
  `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개 차이로 exit 1. 이번 변경 파일은 포맷 차이가 없다.
  `.dart_tool/doodad-location-format.log`.
- 실제 SDK **Flutter 3.47.5 / Dart 3.13.4**. 기준 3.44.8/3.12 및 CI 버전에서
  재검증하지 않았다. 자동 통과를 전체 요구사항/배포 인수 완료로 표현하지 않는다.

실제 앱/게임/외부 에디터·고대비/DPI·깨끗한 PC 인수는 자동 테스트·빌드만 허용한
사용자 지시에 따라 수행하지 않는다. 참조 중인/미확인 Location의 삭제나 동적 EUD
참조 재작성, 실제 겹침/미확인 이웃/복원 정보 부족의 두다드 삭제는 계속 미지원이다.

## 미선택 동일 종류 이웃 보존 계획과 실행

2026-10-20. 첫 미완료 M6.2의 미지원 사례 확대를 이어간다. 실제 앱/게임 조작은
하지 않고 자체 제작 CHK·위젯·MPQ를 사용한다.

1. 소스 분석: 기존 선택 이웃은 전체 footprint로 검사하지만 미선택 이웃은 최대
   16x16 반경으로 차단했다. 한 개만 삭제하려고 다른 두다드까지 선택해야 했다.
2. 삭제 요청과 보존 이웃의 recipe를 분리한다. 선택 종류와 key/type이 맞는 최대
   32종만 받는다. 기존 조회 결과가 정확히 한 후보인 경우에만 UI에서 전달한다.
3. 카탈로그는 정상 recipe만 모으므로 손상 후보가 필터링되면 유일성으로 오인할
   위험이 있다. 삭제 경로만 `requireCompleteTypes`를 사용하여 어떤 페이지에서든
   해당 종류의 recipe 누락을 발견하면 종류 전체를 빈 결과로 반환한다. 기본 조회는
   유지하며 문서/출처/순서 검증과 전체 한 번 순회를 유지한다.
4. 가까운 미선택 이웃의 DD2 상태 0/1·타일셋·정렬·맵 경계·쓰기 MTXM 셀을
   검증한다. 투명 셀을 포함한 전체 영역이 모든 삭제 대상과 겹치면 전체 거부한다.
5. 이웃을 삭제/overlay 집합에 추가하지 않는다. 원래 DD2와 미선택 THG2·이웃 지형·
   TILE/unknown bytes를 보존한다. 별도 선택 Sprite의 명시 삭제 계약은 유지한다.
6. DD2의 완전한 8-byte 레코드 및 MTXM의 정확한 격자 길이를 검사하여 삭제 시
   trailing bytes가 유실되지 않도록 거부한다. 준비/취소는 읽기 전용이며 Apply는
   기존 문서 identity/레이어 검증 및 한 Undo/Redo를 사용한다.

### 최적화 판단

추가 카탈로그/atlas/thumbnail 요청 없이 이미 조회한 정의를 사용한다. 성공한 미선택
이웃의 원본 인덱스를 한 계획 내부에서만 재사용하여 다중 삭제 대상마다 이웃 지형을
중복 검사하지 않는다. 최대 256개 이웃·종류당 하나의 최대 256-cell recipe이므로
이웃 지형 대조는 최대 65,536회다. 각 대상과 전체 사각형 대조는 별도로 유지한다.
선택 대상별 typed decode와 원본 안전성 검사는 유지하며 실제 지연/RSS는 미측정이다.
미선택 이웃끼리의 겹침/overlay 무결성을 증명하지 않으며, 삭제 영역 밖의 데이터는
보존한다. 외부에서 임의로 제공한 recipe의 출처를 이 domain API가 인증하지는 않는다.

### 요구사항과 테스트

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/217 단일/다중 인접 삭제·overlay 3종 | 선택만 제거·이웃 DD2/MTXM/THG2 원시 보존 | domain/MPQ |
| FR-204/218 상태/정렬/경계/지형 불일치 | 전체 거부·원본 불변 | domain |
| FR-204 실제/투명 셀 포함 footprint 겹침 | 원시 타일 일치만으로 삭제 허용하지 않음 | domain |
| FR-217 복수 후보/누락 후보/다른 종류 | 유일성을 추정하지 않고 차단 | catalog/widget/domain |
| FR-102 DD2/MTXM 불완전 bytes | trailing bytes를 버리지 않고 거부 | domain |
| NFR-006/009 256/257개 이웃·멀리 있는 raw 상태 | 256 허용·257 거부·무관한 레코드 보존 | domain |
| NFR-008 한영 600/1200px·취소·명시 overlay | 준비/취소 무변경·overlay 자동 선택 없음 | widget |
| FR-101/104/213 Save As·재열기·Undo/Redo | 이웃/원본 보존·한 Undo·정확한 재열기 | application/MPQ |

초기 집중 검증은 **229개 통과**(새 domain 12 + 기존 batch 6 + 객체 편집/위젯
184 + 실제 MPQ 27). `.dart_tool/doodad-neighbor-focused.log`.
카탈로그 누락 후보 검증을 추가한 최종 결과는 아래에 기록한다.

최종 검증 명령/결과:

- `flutter analyze`: **무이슈**. `.dart_tool/doodad-neighbor-analyze.log`.
- `MAP_ARCHIVE_HELPER_PATH`를 기존 빌드 helper로 지정하고 새 이웃 domain,
  기존 batch domain, `object_placement_command_test`,
  `placement_catalog_controller_test`, `doodad_deletion_roundtrip_test`를 함께
  실행: **601 통과 / 10 조건부 skip / 실패 0**.
  `.dart_tool/doodad-neighbor-focused-final.log`. skip은 로컬 게임 설치/helper
  경로가 필요한 기존 실제 카탈로그 검사이며 성공으로 계산하지 않는다.
- `flutter test`: **2725 통과 / 107 조건부 skip / 실패 0**.
  `.dart_tool/doodad-neighbor-full-tests.log`. 기본 실행의 MPQ 27종 skip은 별도
  실제 helper 실행으로 검증했으며 나머지 조건부 검사를 완료한 것은 아니다.
- `flutter build windows --debug`: **성공**, 18.6초.
  `.dart_tool/doodad-neighbor-windows-build.log`. 기존 CascLib CMake 최소 버전
  deprecation 경고는 남는다. UI 실행/게임 실행을 의미하지 않는다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper를 `MAP_ARCHIVE_HELPER_PATH`로 지정한
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **27/27 통과**.
  `.dart_tool/doodad-neighbor-mpq-final.log`. 추가한 이웃 보존 6종을 포함한다.
- `dart format --output=none --set-exit-if-changed lib test tool`: **exit 1**.
  기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 포맷 차이가 있다. 이번 변경 파일은 포맷 차이가 없으며 무관한 파일을
  변경하지 않았다. `.dart_tool/doodad-neighbor-format.log`.
- 실제 SDK **Flutter 3.47.5 / Dart 3.13.4**. 기준 3.44.8/3.12 및 CI 환경은
  재검증하지 않았다. 기능 테스트 실패는 없었지만 전체 포맷 게이트 통과로 표현하지 않는다.

요구사항별 자동 시나리오는 통과했으며 원본/미선택 bytes·한 Undo 계약을 확인했다.
다른 종류 또는 복수/누락 후보 이웃, 실제 footprint 겹침, 부족/오염된 TILE,
동적/불투명 Location 참조는 미지원이다. 실제 SC:R·외부 에디터 왕복과 수동 앱
조작·고대비/DPI·깨끗한 PC 인수는 수행하지 않았다. 다음 단계는 다른 종류 이웃의
명시 검증 또는 실제 상호 운용 인수이며 첫 미완료 M6.2 항목은 열어 둔다.

## 다른 종류 이웃 보존 계획과 실행

2026-10-20. M6.2 첫 미완료의 미지원 확대를 이어간다. 앞의 동일 종류 한정은
이전 단계의 범위이며 이 절과 [ADR-0032](decisions/0032-other-type-doodad-neighbors.md)가
최신 계약이다. 복원/overlay/Unit/Location 안전 정책과 실제 게임 인수 대기는 유지한다.

### 소스 분석과 실행 계획

1. 기존 카탈로그는 선택 종류만 반환하고 domain의 보존 recipe도 선택 종류로
   제한했다. 다른 종류의 실제 footprint를 확인할 근거가 없어 인접 삭제를 거부했다.
2. 순수 `recipeLookupTypes`로 원본 DD2와 명시 인덱스를 읽는다. 선택 최대 32개,
   입력은 33개까지만 읽으며 중복/범위 밖 선택을 거부한다. 두 개의 최대 16x16
   영역이 만날 수 있는 양 축 중심 차이 512px 미만의 미선택 이웃을 모은다.
3. 선택+가능한 이웃 합계 32종 또는 미선택 후보 256개를 넘으면 선택 종류 집합
   전체로 되돌린다. 임의 이웃 일부를 추려 안전하다고 처리하지 않는다. 불변 결과를
   반환하며 문서·선택·Undo를 변경하지 않는다.
4. application은 편집 가능한 유일 DD2의 cached typed view만 전달한다. 단일/
   다중/혼합 UI는 조회 종류 집합으로 metadata를 한 번 요청한다. 누락 후보가 있는
   종류 전체를 비우는 complete-type 정책과 페이지/문서 검증은 유지한다.
5. domain은 보존 recipe의 선택 종류 제한만 해제한다. 최대 32종·key/type 일치,
   실제 이웃의 타일셋/상태/정렬/경계/현재 쓰기 타일과 전체 비겹침을 계속 검사한다.
   복수 후보/누락 후보는 UI에서 보존 recipe로 전달하지 않는다. 조회 범위는 삭제
   허가가 아니며 실제 겹침이나 잘못된 지형은 끝까지 거부한다.
6. 이웃 DD2/지형과 미선택 THG2·TILE/unknown bytes를 보존하고 선택한 것만 기존
   한 Undo로 삭제한다. overlay 자동 귀속/확인은 하지 않는다. 조회 중 문서 변경,
   적용 시 잠금·취소·실패는 부분 적용하지 않는다.

### 최적화 판단

카탈로그 종류당 재조회 대신 기존 전체 metadata 한 번 순회를 사용한다. 조회는
이미 decode된 DD2를 사용하여 별도 binary decode나 atlas/thumbnail 요청이 없다.
최대 선택 32개와 DD2 수 N에 대해 O(32N)이며 후보/종류 상한 초과 시 조기 반환한다.
이웃 실제 타일 대조는 계획 내부에서 한 번이며 최대 65,536셀이다. 기존 대상별
typed decode와 정확한 footprint 대조는 유지했다. 실제 시간/RSS 개선은 측정하지 않았다.
출처가 검증된 완전한 단일 후보 전달은 내부 호출자 계약이지 임의 recipe 인증이 아니다.

### 요구사항 체크리스트

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/217 다른 종류 이웃·단일/다중·overlay 3종 | 선택만 삭제, 이웃 DD2/MTXM/미선택 THG2 bytes 보존 | domain/MPQ |
| FR-204/218 상태·지형·실제 겹침 | 조회 성공만으로 허용하지 않음·문서 불변 | domain |
| NFR-006/009 최대 영역 경계 511/512px | 가능한 후보 포함·정확히 닿는 최대 영역 제외 | domain |
| NFR-006/009 32/33종·256/257개 이웃 | 상한 내 확장·초과 시 선택 종류 전체로 복귀 | domain |
| FR-203/204 중복/잘못된 인덱스·무한 입력 | 33개까지만 읽어 거부·원본 불변 | domain |
| FR-217 복수/누락 후보·한 번 카탈로그 조회 | 이웃 정의를 추정하지 않고 거부·complete-type 요청 | catalog/widget |
| FR-005/213 조회 중 교체·잠금 후 재시도·취소 | 문서 identity/잠금 재검증·부분 적용 없음 | widget |
| NFR-008 한국어 600px/영어 1200px | 기존 명시 overlay/취소·스크롤·한 Undo/Redo 유지 | widget |
| FR-101/102/104 혼합 Sprite·Save As/재열기 | 명시 선택만 제거·원본 보존·정확한 재열기 | application/MPQ |

### 실행 결과

초기 domain/객체 편집·위젯 **216개 통과**.
`.dart_tool/doodad-other-neighbor-focused.log`. 누락/교체/혼합 및 최종 MPQ를 포함한
집중 실행은 **631 통과 / 10 조건부 skip / 실패 0**.
`.dart_tool/doodad-other-neighbor-focused-final.log`. 실제 MPQ **33종 통과**를 포함하며
10 skip은 로컬 게임 설치/helper 경로가 필요한 기존 카탈로그 테스트로 성공이 아니다.
최초 analyze는 새 테스트의 여러 줄 if 중괄호 1건을 지적했다. 중괄호를 보완했으며
기능 테스트 실패나 실제 맵 데이터 손상을 재현한 사례는 아니다. 전체 게이트는 아래에 기록한다.

- `flutter analyze`: **무이슈**. `.dart_tool/doodad-other-neighbor-analyze.log`.
- `flutter test`: **2749 통과 / 113 조건부 skip / 실패 0**.
  `.dart_tool/doodad-other-neighbor-full-tests.log`. 기본 실행에서는 MPQ 33종도 skip되며
  별도 실제 helper 실행으로 검증했다. 나머지 skip은 검증 성공이 아니다.
- `flutter build windows --debug`: **성공**, 33.4초.
  `.dart_tool/doodad-other-neighbor-windows-build.log`. 기존 CascLib CMake 최소 버전
  deprecation 경고는 남아 있으며 네이티브 의존 revision을 변경하지 않았다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper를 `MAP_ARCHIVE_HELPER_PATH`로 지정한
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **33/33 통과**.
  `.dart_tool/doodad-other-neighbor-mpq-final.log`. 다른 종류 이웃의 단일/다중×overlay
  3종 6개를 포함하며 원본 archive·이웃·Undo/Redo·Save As/재열기 bytes를 확인했다.
- `dart format --output=none --set-exit-if-changed lib test tool`: **exit 1**.
  기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 포맷 차이가 있다. 이번 변경 파일은 포맷 차이가 없고 무관한 파일은 수정하지
  않았다. `.dart_tool/doodad-other-neighbor-format.log`.
- 실제 SDK는 **Flutter 3.47.5 / Dart 3.13.4**. 기준 3.44.8/3.12 및 CI 버전에서는
  재검증하지 않았다. 필수 포맷 게이트까지 모두 통과했다고 표현하지 않는다.

실제 열린 앱·SC:R·외부 에디터 조작, 고대비/DPI·깨끗한 PC 인수는 사용자 지시가
자동 테스트/빌드로 제한되어 수행하지 않았다. 실제 로컬 카탈로그 재검증도 환경 변수
미설정으로 skip이다. synthetic/MPQ 자동 통과는 실제 게임이나 외부 상호 운용 인수가
아니다. 복수 후보 이웃의 정의를 명시 검증하는 범위와 실제 겹침/복원 정보 부족은
계속 미지원이며 다음 후속 작업이다. 첫 미완료 M6.2 항목은 닫지 않는다.

## 복수 이웃 후보 전체 영역 검증 계획과 실행

2026-10-20. M6.2 첫 미완료 항목의 미지원 확대를 이어간다. 앞의 복수 후보 일괄
거부는 당시 계약이다. [ADR-0033](decisions/0033-all-doodad-neighbor-candidates.md)부터
완전한 후보 집합의 전체 영역이 안전함을 검증하는 보존 삭제를 지원한다.

### 소스 분석과 실행

1. 기존 UI는 후보 개수가 하나인 종류만 domain에 전달했다. 복수 정의는 선택하지
   않은 이웃의 크기를 확정할 수 없어 거부했다. 실제 정의를 하나로 결정하는 대신
   모든 가능한 영역을 그대로 보호하는 방향으로 범위를 좁혔다.
2. 단일/다중/혼합 창은 complete-type 카탈로그 결과 전체를 새 후보 인자로
   전달한다. 추가 조회·자동 overlay 귀속/선택은 없고 삭제 대상의 recipe 선택은 유지한다.
3. domain은 기존 단일 recipe 인자를 유지한다. 두 인자 간 중복 종류·key/type
   불일치·32종 초과·전체 256개 후보 초과를 거부한다. iterable 합계 최대 257개만
   읽어 immutable 후보 snapshot을 만든다. 누락된 정의를 유일성으로 바꾸지 않는다.
4. 실제 가까운 이웃의 상태 0/1과 모든 후보의 타일셋·정렬·전체 맵 경계를 검사한다.
   최소 한 후보의 쓰기 MTXM이 모두 일치해야 한다. 모든 후보의 전체 사각형이 모든
   삭제 대상과 겹치지 않아야 한다. 어떤 후보라도 geometry가 불명확하면 거부한다.
5. 초기 접근은 지형과 일치한 후보만 영역 검사에 사용할 수 있다고 보았다. 소스 검토에서
   불일치 후보가 수정된 지형의 실제 정의일 가능성을 배제하지 못함을 확인했다.
   불일치 대안도 영역 검사에 남기고, 일치 후보가 있어도 다른 geometry가 불명확하면
   거부하도록 보강했다. 이 두 상황을 별도 domain 회귀로 추가했다. 실제 사용자 맵의
   손상이나 배포된 앱 결함을 재현한 기록은 아니며 구현 중의 안전성 보강이다.
6. 후보 검증을 원본 DD2 인덱스로 계획 내부에 재사용한다. 후보의 실제 정체를 기록하거나
   이웃을 삭제하지 않는다. 이웃 DD2/지형·미선택 THG2/TILE·unknown bytes를 보존하며
   기존 한 Undo/Redo·잠금/문서 identity·명시 overlay·Unit/Location 확인을 유지한다.

### 최적화와 작업 예산

최대 32종·총 256개 후보·256개 이웃을 허용한다. 후보의 모든 footprint 셀 반복을
합계 262,144회로 제한하며 투명 셀도 센다. 지형 불일치가 발견되면 그 후보의 남은
셀 반복만 생략한다. 영역은 생략하지 않는다. 동일 이웃의 검증을 한 계획에서 한 번
수행하고 다중 대상에 재사용한다. 후보 영역 대조의 보수적 상한은 2,097,152회다.
실제 지연/RSS 개선은 미측정이며 전체 map typed decode의 기존 비용은 유지한다.
장기 cache나 새 dependency/I/O/atlas/thumbnail은 도입하지 않았다.

이는 이웃의 실제 정의 식별이나 모든 지형의 무결성 증명이 아니다. 최소 하나의
현재 타일 일치와 모든 가능한 영역 밖만 변경함을 확인한다. 다른 대안의 현재 지형이
수정됐을 가능성을 배제하지 않으며 그 bytes도 보존한다. 임의 외부 recipe의 출처를
인증하는 API가 아니고 complete-type 카탈로그 전달은 내부 호출자 계약이다.

### 요구사항과 테스트

| 요구사항 / 시나리오 | 기대 결과 | 자동 근거 |
| --- | --- | --- |
| FR-203/217 동일/다른 종류 복수 후보·단일/다중 | 모든 영역 안전할 때 선택만 삭제·이웃 보존 | domain/widget/MPQ |
| FR-204/218 서로 다른 크기/투명 셀/불일치 대안 겹침 | 첫 일치로 우회하지 않고 전체 거부 | domain/widget |
| FR-204 한 후보 일치+다른 geometry 불명확 | 불명확 대안을 배제하지 않고 거부 | domain |
| FR-217 후보 없음/전부 불일치/잘못된 tileset | 근거 없는 안전 추정 거부 | domain/기존 catalog 회귀 |
| NFR-006/009 32종/256 후보·합계 257회/무한 입력 | 유한하게 snapshot·중복 출처/key 오류 거부 | domain/widget |
| NFR-006/009 262,144셀 경계·batch 재사용 | 경계 허용·초과 거부·두 번째 대상에서 재검증 안 함 | domain |
| FR-005/213 취소/잠금/문서 변경·한 Undo/Redo | 준비/실패 무변경·원자적 Apply | application/widget |
| NFR-008 한국어 600px/영어 1200px | 명시 overlay·복수 후보/혼합·예산 거부·버튼 유지 | widget |
| FR-101/102/104 MPQ 39종 | 원본/이웃 bytes·Save As/Undo/재열기 보존 | 실제 helper integration |

초기 도메인/객체 편집·위젯 **231개 통과**.
`.dart_tool/doodad-candidates-focused.log`. UI/MPQ 확장 후 초기 집중 검증은
**664 통과 / 10 조건부 skip**이었다. 위 소스 검토의 두 안전 회귀를 추가한 최종
집중 실행은 **666 통과 / 10 조건부 skip / 실패 0**.
`.dart_tool/doodad-candidates-focused-final.log`. 실제 MPQ **39종 통과**를 포함한다.
10 skip은 실제 로컬 설치/helper 경로가 필요한 기존 카탈로그 검사로 성공이 아니다.
기존 복수 후보 UI의 무조건 거부 기대는 모든 영역이 안전한 경우 허용하도록 변경했다.
실패한 기능 테스트를 수정한 것으로 계산하지 않는다. `flutter analyze`는 무이슈였다.

최종 게이트:

- `flutter analyze`: **무이슈**. `.dart_tool/doodad-candidates-analyze.log`.
- `flutter test`: **2778 통과 / 119 조건부 skip / 실패 0**.
  `.dart_tool/doodad-candidates-full-tests.log`. 기본 실행에서 skip된 MPQ 39종은
  별도 실제 helper 실행으로 검증했다. 다른 조건부 skip은 성공으로 계산하지 않는다.
- `flutter build windows --debug`: **성공**, 17.7초.
  `.dart_tool/doodad-candidates-windows-build.log`. 기존 CascLib CMake 최소 버전
  deprecation 경고는 남으며 네이티브 의존 revision/프로토콜은 변경하지 않았다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper를 `MAP_ARCHIVE_HELPER_PATH`로 지정한
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **39/39 통과**.
  `.dart_tool/doodad-candidates-mpq-final.log`. 복수 후보·단일/다중×overlay 3종 6개를
  포함해 원본/이웃·한 Undo/Redo·Save As/재열기 bytes를 확인했다.
- `dart format --output=none --set-exit-if-changed lib test tool`: **exit 1**.
  기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 차이가 있다. 이번 변경 파일은 포맷 차이가 없으며 무관한 파일은 수정하지
  않았다. `.dart_tool/doodad-candidates-format.log`.
- 실제 SDK **Flutter 3.47.5 / Dart 3.13.4**. 기준 3.44.8/3.12 및 CI 환경에서는
  재검증하지 않았다. 기능 통과를 전체 게이트/배포 인수 완료로 표현하지 않는다.

실제 앱/SC:R/외부 에디터 조작·고대비/DPI·깨끗한 PC 인수는 자동 테스트/빌드만
허용한 사용자 지시에 따라 수행하지 않았다. 로컬 카탈로그 재검증은 환경 변수
미설정으로 skip이다. 후보 누락·불명확한 geometry·모든 후보 지형 불일치·실제 겹침·
복원 정보 부족과 작업 예산 초과는 계속 거부한다. 다음 범위는 이런 입력을 추측
복구하는 작업이 아니라, 지원 가능 근거 확정 또는 실제 상호 운용 검증이다.
첫 미완료 M6.2 항목은 게임/외부 인수가 남아 열린 상태로 유지한다.

## 삭제 준비 원본 해석 재사용

2026-10-20. M6.2 첫 미완료 항목의 자동 검증 가능한 후속 최적화다. 삭제 지원
범위와 ADR-0033의 보수적 검증 계약을 변경하지 않으며 게임/외부 인수를 대신하지 않는다.

### 계획과 소스 분석

기존 `createBatch`는 각 대상의 `_create`에서 metadata/terrain/object를 다시
해석하고 TILE payload 사본을 만들었다. 최종 병합에서도 terrain/object를 다시
해석했다. 최대 32개 대상에서는 metadata/TILE 32회, terrain/object 33회였다.
같은 불변 원본 문서의 반복 작업이므로 계획 내부 재사용이 가능하다고 판단했다.
대상마다 달라지는 recipe tileset, 상태, geometry, 후보 영역, overlay 및 복원값
검사는 제거하지 않는다. 후보 검증의 기존 예산과 원본 인덱스 병합도 유지한다.

### 실행과 요구사항 체크

- [x] `_DoodadDeletionSource`는 단일/다중 호출마다 생성한다. 각 view와 TILE
  ByteData는 필요할 때 한 번만 만들고, 성공한 섹션 유일성 조회만 재사용한다.
- [x] 공개 API/삭제 결과는 그대로다. 문서 변경을 넘는 cache, I/O, 새 dependency는
  없으며 준비 단계의 교체 섹션은 실제 Apply 이전에 원본에 반영하지 않는다.
- [x] 기존 검증 순서를 유지한다. THG2를 쓰지 않는 no-overlay 삭제에 불필요한
  THG2 존재 조건을 추가하지 않는다. 복잡한 수명/지연 해석의 이유를 주석으로 남겼다.
- [x] NFR-006/009: 대형 맵 32개 정방향/역방향 입력의 기존 인덱스/예산을 유지한다.
- [x] FR-203/204/217: 뒤쪽 대상의 다른 tileset도 여전히 거부하고, 필수 섹션
  DIM/ERA/MTXM/DD2/TILE 중복을 거부한다. 오류 시 원본 bytes는 불변이다.
- [x] FR-005/101/104: 256x256 맵의 전체 지형 복원, 미선택 DD2/다른 섹션 보존,
  서로 다른 TILE 원본을 번갈아 준비해도 stale 값이 없는지 확인한다.

새 domain 회귀는 `test/domain/placement/doodad_deletion_source_test.dart` 9종이다.
기존 batch/복수 후보 테스트를 합친 최초 집중 실행은 **28 통과 / 실패 0**이다.
fixture는 `NewMapFactory`로 온전한 256x256 raw-terrain 맵을 새로 만들고 자체
DD2/THG2를 넣는다. DIM만 바꾼 불일치 맵이나 SC:R 추출 자산을 사용하지 않는다.

### 전후 측정과 분석

재현 명령: `dart run tool/doodad_deletion_benchmark.dart`.
자체 제작 256x256 raw-terrain 맵, no-overlay 1x1 대상 1/8/32개, 동일 프로세스 내
대상 수별 10회 warm-up 후 31회 측정한다. fixture 생성은 측정에서 제외하고
계획 준비 전체를 잰다. 기존 구현과 변경 구현 각각 같은 명령을 한 번 실행했다.

| 대상 수 | 변경 전 median / p95 (ms) | 변경 후 median / p95 (ms) |
| --- | --- | --- |
| 1 | 5.056 / 5.335 | 4.030 / 4.316 |
| 8 | 11.314 / 12.646 | 3.992 / 4.755 |
| 32 | 31.165 / 32.605 | 4.045 / 4.544 |

32개 중앙값 약 87% 감소는 이 로컬 JIT synthetic 측정에 한정된다. timing assert를
추가하지 않았으며 실사용 UI/카탈로그/대형 object 수, Profile/Release, 여러 실행의
통계나 RSS/GPU는 측정하지 않았다. 구조적으로 32개 batch에서도 각 view/TILE은
한 번만 만든다. UNIT/MRGN의 별도 혼합 삭제 검증이나 서로 다른 계획의 비용은
합치지 않는다. 전체 DD2 영역 반복과 최종 출력 복사는 여전히 필요하다.

### 최종 검증

최초 전체 실행은 **2782 통과 / 119 조건부 skip / 로딩 실패 1**이었다.
`app_language_controller_test.dart`가 `Connection closed before test suite loaded`로
로드되지 않았다. 해당 파일을 단독 재실행한 결과 **5/5 통과**였고 소스를 수정하지
않았다. 일시적인 로더/환경 문제 가능성이 있지만 원인을 확정하지 않으며,
`.dart_tool/doodad-source-tests.log`에 실패를 남기고 전체 테스트를 다시 실행했다.

- `flutter analyze`: **무이슈**. `.dart_tool/doodad-source-analyze.log`.
- 최종 `flutter test`: **2787 통과 / 119 조건부 skip / 실패 0**, 1분 50초.
  `.dart_tool/doodad-source-tests-final.log`. skip은 성공으로 계산하지 않는다.
- `flutter build windows --debug`: **성공**, 17.1초.
  `.dart_tool/doodad-source-windows-build.log`. 기존 CascLib CMake 최소 버전
  deprecation 경고는 유지되며 네이티브 의존 revision은 변경하지 않았다.
- `ctest --test-dir build/windows/x64 -C Debug --output-on-failure`: **7/7 통과**.
- 최종 빌드 helper를 `MAP_ARCHIVE_HELPER_PATH`로 지정한
  `flutter test test/integration/doodad_deletion_roundtrip_test.dart`: **39/39 통과**.
  `.dart_tool/doodad-source-mpq-final.log`. 전체 실행에서 skip된 실제 MPQ 사례를
  별도로 실행해 원본 bytes·미선택 이웃·한 Undo/Redo·Save As/재열기를 확인했다.
- `dart format --output=none --set-exit-if-changed lib test tool`: **exit 1**,
  622개 검사 중 기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개의 포맷 차이만 남는다. 변경 파일 포맷은 통과했고 무관한 파일은 수정하지
  않았다. `.dart_tool/doodad-source-format.log`.
- 실제 SDK는 **Flutter 3.47.5 / Dart 3.13.4**다. 기준 3.44.8/3.12와 CI 환경에서는
  재검증하지 않았으므로 전체 필수 게이트/배포 인수 완료로 표현하지 않는다.

실제 앱/SC:R/외부 에디터 조작은 자동 테스트/빌드만 허용한 사용자 지시에 따라
수행하지 않는다. 첫 미완료 항목의 외부 인수, 불명확한 geometry, 실제 겹침/복원
근거 부족은 이 변경으로 닫지 않는다.
