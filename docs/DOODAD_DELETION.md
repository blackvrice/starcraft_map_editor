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
필수 레이어 잠금은 적용을 막는다. Unit/Location 혼합·TILE 부재·불일치 상태는 미지원이다.
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
