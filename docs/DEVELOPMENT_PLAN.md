# 개발 계획

## 사용 방법

- 별도 우선순위 지시가 없으면 위에서 아래로 첫 번째 미완료 체크박스를 진행한다.
- 개별 체크박스는 코드, 자동 테스트, 문서가 끝나면 닫는다. 단계(마일스톤)
  전체의 "완료"는 여기에 실제 실행 검증까지 더해져야 한다. 실행 검증이 남은
  체크박스에는 무엇이 남았는지를 검증 메모에 적는다.
- 구현이 계획과 다른 형태로 끝났으면 체크박스 문구를 실제 구현에 맞춰 고친 뒤
  닫는다. 문구를 그대로 두고 다른 것을 완료로 표시하지 않는다.
- 완료된 항목에는 관련 커밋 또는 검증 메모를 덧붙인다.
- 예상과 실제 포맷 동작이 다르면 구현을 억지로 맞추지 말고 문서와 계획을 수정한다.

## 현재 상태

| 단계 | 상태 | 결과 |
| --- | --- | --- |
| M0. 제품·기술 기준선 | 완료 | 문서, MIT, Flutter 3.44.8, Windows CI |
| M1. 데스크톱 기반 | 완료 | 계층 구조, 에디터 셸, 최근 맵, 작업 진행 |
| M2. CHK 무손실 코어 | 완료 | raw 왕복, 메타데이터·문자열 typed view, 구조 진단 |
| M3. 맵 아카이브 입출력 | 완료 | Open Map·검증형 Save As·fingerprint·복구 백업·자체 제작 SCX |
| M4. EUD 수직 기능 | 완료 | 실제 euddraft 빌드·검증·안전한 출력 승격 |
| M5. 맵 캔버스와 지형 | 완료 | 지형 typed view·탐색·실제 타일 렌더·편집·성능 계측 |
| M6. 객체와 로케이션 | 완료 | 객체·로케이션 편집·의미 참조 진단·Save As 왕복 |
| M6.1. 실제 객체 그래픽 | 완료 | CascLib 객체 자산·스프라이트 렌더·fallback·성능 기준 |
| M6.2. 시각적 배치 선택 탭 | 진행 | 카탈로그 탭에서 Tile·Doodad·Unit·Sprite 선택·배치 동작, Windows 게이트와 실제 설치 스모크 남음 |
| M6.3. 맵·플레이어·게임 설정 | 진행 | 섹션 구조·선택 규칙·합성 픽스처 확정, 편집 UI 대기 |
| M6.3.1. 유닛·무기 EUD 확장 | 대기 | 사거리·실드 활성·공격 타입 등의 선언적 설정과 안전한 빌드 |
| M6.3.2. 설정별 EUD 확장 | 대기 | 업그레이드·테크·플레이어·그래픽의 공통 확장 탭 |
| M6.4. 기본 제작·편집 도구 | 대기 | 새 맵·등각 지형·안개·클립보드·객체 속성 보완 |
| M6.5. 문자열·사운드 리소스 | 대기 | 사용처와 안전한 편집·아카이브 리소스 관리 |
| M7. 일반 트리거·미션 브리핑 | 대기 | M6.2~M6.5 완료 후 이벤트와 브리핑 편집 |
| M7.1. EUD 실행 규칙 | 대기 | 조건부 설정·런타임 객체·동적 텍스트/로케이션 |
| M8. 안정화와 배포 | 대기 | 검증된 Windows 릴리스 |

2026-09-07 [기본 에디터 기능 대조](BASIC_EDITOR_COVERAGE.md)에서 빠진 설정과
제작 도구를 M6.3~M6.5 및 M7에 연결했다. M0~M6.1의 완료는 각 단계의 당시
범위를 뜻한다. 배치된 유닛의 Inspector나 M6.2 factory가 맵 전체 Unit Settings의
완료를 뜻하지 않는다.

2026-09-07 M6.2의 카탈로그 탭·배치·진단·테스트 항목과 M6.3의 첫 조사 항목을
닫았다. M6.2에 남은 세 항목(기존 Doodad 복합 삭제, 성능 기준선, 실제 설치
스모크)은 실제 Windows 환경이나 상호 운용 확인이 필요해 M6.3과 병행한다.
다음 구현 작업은 M6.3의 첫 미완료 항목인 "맵 제목·설명 편집과 공유 문자열을
보존하는 이름 변경"이다.

---

## M0. 제품·기술 기준선

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m0)을 참조한다.

## M1. 데스크톱 기반

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m1)을 참조한다.

## M2. CHK 무손실 코어

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m2)을 참조한다.

## M3. 맵 아카이브 입출력

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m3)을 참조한다.

## M4. EUD 수직 기능

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m4)을 참조한다.

## M5. 맵 캔버스와 지형

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m5)을 참조한다.

## M6. 객체와 로케이션

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m6)을 참조한다.

## M6.1. 실제 객체 그래픽 렌더링

당시 범위 완료. 체크리스트와 검증 근거는 [구현 이력](IMPLEMENTATION_HISTORY.md#m61)을 참조한다.

## M6.2. 시각적 배치 선택 탭

목표: 다른 StarCraft 맵 에디터처럼 로컬 게임 데이터의 Tile, Doodad, Unit,
Sprite를 실제 이미지 목록에서 찾고 선택한 뒤 캔버스에 배치할 수 있게 한다.
이 단계와 M6.3~M6.5가 완료되기 전에는 M7 일반 트리거 구현을 시작하지 않는다.

- [x] 기존 에디터의 Tile·Doodad·Unit·Sprite 선택 흐름과 CHK 생성 규칙 조사
- [x] 로컬 SC:R 배치 카탈로그 포트·모델과 안전한 이름/ID fallback 정의
- [x] 타일셋별 Tile 카탈로그와 실제 32×32 썸네일 공급
- [x] Unit·Sprite 전체 카탈로그와 실제 객체 썸네일 공급
- [x] Doodad 정의, 크기, 중심점, 지형·overlay 구성 관계 해석
- [x] 현재 맵에 없는 Unit·Sprite를 위한 검증된 기본 레코드 factory 구현
- [ ] Doodad의 `DD2 `·`MTXM`·필요한 `THG2` 원자적 배치/삭제/Undo 구현
      (배치와 Undo는 완료, 기존 Doodad의 복합 **삭제**는 귀속 규칙 확정 전까지 보류)
- [x] Tile·Doodad·Unit·Sprite 탭이 있는 카탈로그 선택 탭 구현
- [x] 분류·이름·숫자 ID 검색, 타일셋 필터, 최근 선택과 상세 미리보기 구현
- [x] 선택 결과의 커서 ghost, 스냅, 단일/연속 배치와 `Escape` 취소 구현
- [x] 레이어 잠금·맵 경계·미지원 자산·잘못된 카탈로그 항목 진단 연결
- [x] 합성 카탈로그 단위 테스트, 카탈로그 탭 위젯 테스트와 Save As 왕복 테스트
- [ ] 대형 카탈로그 가상 스크롤·검색·썸네일 cache 성능 계측
      (계측 하네스와 구조적 판정은 완료, Windows 기준선과 썸네일 cache 메모리는 미기록)
- [ ] 로컬 SC:R 설치에서 선택적 Tile·Doodad·Unit·Sprite 배치 스모크 검증

구현 순서:

1. **카탈로그 계약과 포맷 조사**
   - Tile은 현재 tileset의 유효한 `MTXM` raw 값과 32×32 미리보기를 기본 키로
     사용한다. CV5 group/member, 지형 분류와 이름을 확인할 수 있으면 함께
     제공하되 구조가 불명확한 값을 임의로 이름 붙이지 않는다.
   - Unit은 `units.dat`, Sprite는 `sprites.dat` 기준 ID를 사용하고 검증된 로컬
     TBL 이름이 있을 때만 표시한다. 이름이 없거나 손상되면 `Unit #37`,
     `Sprite #130`처럼 종류와 숫자 ID를 항상 노출한다.
   - Doodad는 단순 `DD2 ` 레코드가 아니라 여러 `MTXM` 타일과 선택적인 overlay
     sprite가 함께 구성될 수 있다. 타일셋별 정의·폭·높이·중심점·소유자·enabled
     규칙을 확인해 하나의 배치 recipe로 모델링한다. recipe가 완전하지 않은
     항목은 배치 버튼을 비활성화하고 이유를 보여주며 바이트를 추측하지 않는다.
   - 조사 결과와 기본 레코드 값은
     [시각적 배치와 CHK 생성 규칙 조사](research/VISUAL_PLACEMENT_AND_CHK_RULES.md)와
     [ADR-0008](decisions/0008-validated-visual-placement-catalog.md)에 고정했다.
     기존 맵의 첫 레코드를 복제하는 현재 `ObjectPaletteController` 경로는
     호환 fallback으로 유지하되,
     전체 카탈로그의 기본값을 대신하는 근거로 사용하지 않는다.

2. **Application 경계와 로컬 자산 공급**
   - Domain/Application 모델은 `kind`, stable ID, tileset, 분류, 검증된 표시 이름,
     배치 가능 여부와 진단만 갖고 Flutter, 파일 시스템, CascLib에 의존하지 않는다.
   - Infrastructure는 기존 설치 검사 snapshot과 helper 프로세스 경계 뒤에서만
     카탈로그·썸네일을 읽는다. 요청은 종류·타일셋·페이지 범위를 제한하고 버전,
     원시 로그와 구조화된 실패를 기록한다.
   - Tile 썸네일은 기존 terrain atlas, Unit·Sprite 썸네일은 object atlas와 LRU를
     재사용한다. 화면에 보이는 항목과 주변 prefetch 범위만 비동기로 준비하며
     세대가 바뀐 이미지와 탭을 떠난 뒤 GPU 자원을 명시적으로 해제한다.
   - SC:R 원시 자산과 추출 이미지는 저장소 fixture나 배포물에 포함하지 않는다.
     자동 테스트는 자체 제작 DAT/TBL/GRP/CV5 계열 바이트와 가짜 gateway만 쓴다.

3. **선택 탭 UX**
   - 공용 `Place` 명령과 레이어별 명령으로 맵·EUD 탭 옆의 `Catalog` 작업 영역
     탭을 열고 `Tiles`, `Doodads`, `Units`, `Sprites` 종류를 제공한다. 탭은 왼쪽
     분류/필터, 가운데 가상화 썸네일 grid, 오른쪽 큰 미리보기·ID·크기·지원 상태로
     구성한다.
   - 검색은 표시 이름, 종류, `#숫자 ID`를 지원하고 현재 tileset과 호환되지 않는
     항목은 숨기지 않고 비활성 상태와 이유를 구분한다. 최근 선택은 로컬 UI 설정에
     저장하되 맵 문서, dirty 상태와 Undo 기록에는 포함하지 않는다.
   - 클릭은 상세 미리보기만 바꾸고 더블 클릭 또는 명시적 `Place` 버튼이 선택을
     확정한다. 탭을 떠나도 문서는 바뀌지 않으며, 확정 후에만 해당 레이어와
     배치 도구가 활성화된다. 키보드 탐색, Enter 확정, Escape 취소와 Windows
     100%/125%/150% 배율에서의 레이아웃을 지원한다.

4. **캔버스 배치와 무손실 편집**
   - 선택한 Tile은 기존 Brush/Rectangle 도구의 입력이 되고, Doodad·Unit·Sprite는
     실제 anchor와 footprint를 반영한 반투명 cursor ghost를 표시한다. 좌클릭은
     배치, 우클릭 또는 `Escape`는 취소하며 연속 배치와 1회 배치를 명확히 전환한다.
   - Unit·Sprite factory는 조사로 확정한 필드만 초기화한다. 좌표·owner·flags와
     예약 바이트를 각 CHK 폭으로 검증하고 현재 맵에 해당 섹션이 없을 때의 새 섹션
     삽입 위치도 무손실 정책에 맞춰 결정적으로 처리한다.
   - Doodad 한 번의 배치는 `DD2 ` metadata, footprint의 `MTXM`, 필요한 `THG2`
     overlay를 하나의 명령으로 적용한다. 경계 밖 footprint, 손상 recipe, 잠긴
     레이어나 중복/모호한 대상 섹션이면 전체를 거부한다. Undo/Redo도 세 섹션을
     함께 복원하며 중간 상태를 사용자 문서에 노출하지 않는다.
   - 다시 연 기존 Doodad의 `DD2 `에는 아래 지형이 없으므로, 유일하고 유효한
     `TILE`을 이용한 복원과 overlay 귀속 규칙을 상호 운용 테스트로 확정하기
     전에는 기존 Doodad의 복합 삭제에서 `MTXM`이나 같은 위치의 `THG2`를 추측해
     지우지 않는다. 같은 세션에서 새로 배치한 Doodad는 command의 before snapshot과
     record identity로 정확히 Undo/Redo한다.
   - 저장은 기존 검증형 Save As만 사용한다. 알 수 없는 섹션, 중복 섹션, 기존
     객체 순서·예약 바이트와 원시 문자열은 이 기능과 무관한 경우 그대로 보존한다.

테스트와 성능 기준:

- 자체 제작 카탈로그에서 정렬·분류·검색·숫자 fallback·타일셋 제한과 손상 항목
  격리를 단위 테스트한다.
- 카탈로그 탭 위젯 테스트는 빈/로딩/부분 실패/대량 목록, 종류 전환, 검색, 키보드,
  확대 배율, Place/Cancel과 stale 썸네일 폐기를 검증한다.
- 배치 통합 테스트는 각 종류를 현재 맵에 없던 ID로 추가하고 Undo/Redo, Save As,
  재열기까지 연결한다. Doodad는 footprint의 모든 `MTXM`과 overlay가 원자적으로
  왕복하고 관련 없는 CHK 바이트가 바뀌지 않는지 비교한다.
- 최소 2,000개 항목의 가상 grid에서 탭 첫 표시, 빠른 검색, 연속 스크롤과
  썸네일 cache 메모리를 debug/profile로 계측하고 측정 환경·상한을 별도 성능
  문서에 기록한다. 자동 상한은 첫 기준 측정 뒤 CI 변동 폭을 반영해 확정한다.
- 로컬 설치 스모크는 각 tileset에서 Tile/Doodad 하나와 Unit/Sprite 대표 항목을
  실제 이미지로 선택·배치하되 게임 자산이나 결과 맵을 저장소에 추가하지 않는다.

검증 메모:

- 2026-08-22 protocol 3/helper 0.5.0에 `listPlacementCatalog`의 Tile page를
  추가했다. helper는 현재 tileset의 `CV5` group/member 범위를 최대 256개씩
  열거하고 같은 `CV5`·`VX4EX`·`VR4`·`WPE` decoder로 해당 페이지를 실제
  렌더 가능한지 먼저 검증한다. Dart process adapter는 operation ID 취소,
  설치·버전·타일셋·offset/limit·연속 u16 ID·자산 크기를 교차 검증한다.
- `TilePlacementCatalogLoader`는 검증된 page만 기존 `renderTileAtlas`에 넘기고
  storage product/build와 helper/CascLib identity 및 전체 ID coverage가 같을 때만
  항목별 32×32 RGBA thumbnail을 공급한다. 자체 작성 native 자산, 가짜 process와
  application gateway 테스트가 페이지 끝·빈 페이지·손상 응답·timeout·취소·
  unsupported/mismatched atlas를 검증하며 게임 자산은 저장소에 포함하지 않는다.
- 로컬 SC:R build 13515에서 번들 helper로 8개 tileset 각각 Tile ID 0~3의
  카탈로그와 32×32 RGBA thumbnail을 실제 생성하는 선택적 스모크가 통과했다.
- `flutter analyze`, 단일 동시성 전체 `flutter test` 362개(환경 의존 7개 skip),
  native CTest와 `flutter build windows --debug`가 통과했다.
- 2026-08-22 protocol 3/helper 0.6.0은 `listPlacementCatalog`에 classic
  `units.dat` 228개와 `sprites.dat` 517개의 전체 ID page를 추가했다. 각 항목은
  기존 DAT/TBL/GRP frame 0 renderer를 먼저 통과하며, 실패 코드는 항목별
  `previewIssueCode`로 격리된다. Dart adapter는 종류별 고정 total, 연속 ID,
  object asset read count와 preview code를 검증한다.
- `ObjectPlacementCatalogLoader`는 preview 가능한 항목만 기존
  `renderObjectAtlas`에 다시 요청하고 storage/helper/CascLib identity와 전체
  coverage가 같을 때 가변 width/height·anchor·RGBA thumbnail을 채택한다.
  Unit·Sprite 기본 CHK factory는 다음 항목이므로 현재 항목은 실제 이미지가 있어도
  `SC_CATALOG_ITEM_PLACEMENT_FACTORY_PENDING`으로 배치 비활성 상태를 유지한다.
- 로컬 SC:R build 13515에서 Unit 228개와 pure Sprite 517개 전체 catalog page의
  DAT/TBL/GRP preview 검증이 통과했고, 대표 Unit 8개·Sprite 16개의 실제 RGBA
  thumbnail을 bundled gateway/loader 왕복으로 확인했다.
- `flutter analyze`, 단일 동시성 전체 `flutter test` 372개(환경 의존 8개 skip),
  native CTest, 로컬 bundled helper 스모크 5개와
  `flutter build windows --debug`가 통과했다.
- 2026-08-22 protocol 3/helper 0.7.0은 tileset별 CV5와
  `tileset\\<name>\\dddata.bin`을 strict-read해 Doodad를 `(tileset, DDData ID,
  CV5 start group)` 안정 키로 페이지화한다. 각 recipe는 1~16 타일 폭·높이,
  row-major sparse `MTXM`, DDData placibility group, footprint 시작점 기준
  `(width*16, height*16)` 중심 오프셋, enabled `DD2 ` 값과 optional pure
  Sprite/sprite-unit `THG2` 의미를 함께 가진다. 구조가 불완전한 항목은
  `SC_CASC_DOODAD_*` code로 개별 격리한다.
- 로컬 SC:R `s1` build 13515의 8개 tileset 전체 Doodad page를 검사했다.
  tileset별 194~1,217개, 총 6,730개 중 6,668개 recipe가 검증됐고 62개
  비표시/잘린 정의는 항목별로 격리됐다. 최대 256개 JSON page는 162,711 bytes로
  256 KiB process 상한 안이었다. 배치 command는 다음 항목이므로 정상 recipe도
  `SC_CATALOG_ITEM_DOODAD_COMMAND_PENDING`으로 아직 문서를 변경하지 않는다.
- `flutter analyze`, 단일 동시성 전체 `flutter test` 378개(환경 의존 9개 skip),
  native CTest 5/5, 로컬 bundled helper 스모크 6/6과
  `flutter build windows --debug`가 통과했다.
- 2026-09-07 Unit·Sprite 기본 레코드 factory의 도메인 계층을 구현했다.
  `UnitPlacementCapability`는 `units.dat`에서 파생한 boolean만 갖는 스냅샷이고,
  `UnitPlacementFactory`와 `SpritePlacementFactory`는 고정 commit의 Chkdraft
  선택 기본값대로 36-byte `UNIT`과 10-byte `THG2` 바이트를 합성한다. flag 비트
  정의는 `ChkUnitPlacement`의 상수로 고정했고 근거는
  [조사 문서](research/VISUAL_PLACEMENT_AND_CHK_RULES.md) 3.2·3.3의 구현 확인
  항목에 기록했다. relation이 필요한 Unit과 sprite-unit은 바이트를 만들지 않고
  안정적인 거절 코드를 돌려준다.
- 위 factory는 아직 사용되지 않는다. capability를 공급할 helper protocol과,
  합성 레코드를 문서에 삽입하는 배치 명령이 남아 있어 체크박스는 열어 둔다.
  남은 작업은 (1) helper의 unit capability 페이지와 항목별 격리 코드,
  (2) `UNIT`/`THG2` 섹션이 없거나 중복일 때의 결정적 삽입·거부 규칙과
  class ID 할당, (3) 단일 Undo entry로 적용하는 배치 command다.
- 검증은 Linux 컨테이너에서 Flutter 3.44.8로 실행한 도메인 범위
  `dart format`·`flutter analyze`·`flutter test` 88개까지다. Windows 전체
  `flutter test`, native CTest, `flutter build windows --debug`와 실제 설치
  스모크는 실행하지 못했다.
- 2026-09-07 배치 명령 경로를 구현했다. `RawChkDocument.appendSection`과
  `removeTrailingSections`, `ChkObjectSectionEditor`의 합성 레코드 append와
  빈 섹션 생성, `DoodadPlacementFactory`의 `DD2 `·`MTXM`·optional `THG2`
  계획, `ObjectEditingController.placeCatalogUnit`/`placeCatalogPureSprite`/
  `placeCatalogDoodad`가 들어갔다. Doodad 배치는 세 섹션을 하나의
  `_ObjectEditCommand`로 적용해 Undo/Redo 한 항목으로 되돌리고, 어느 조건이든
  실패하면 아무 섹션도 바꾸지 않는다.
- 섹션 규칙을 확정했다. 같은 이름의 섹션이 둘 이상이거나 하나인데 typed view로
  해석되지 않으면 거부하고, 없으면 문서 맨 끝에 새 섹션을 추가한다. class ID는
  모든 `UNIT` 섹션의 최대값 + 1이다. 근거와 규칙은
  [파일 포맷과 무손실 정책](FILE_FORMATS.md)의 "섹션 추가 규칙"과
  [조사 문서](research/VISUAL_PLACEMENT_AND_CHK_RULES.md) 3.4·4절에 있다.
- 진단 연결은 배치 경로까지 마쳤다. 레이어 잠금, 맵 경계, `DIM `/`ERA`/`MTXM`
  부재·중복, tileset 불일치, DDData placibility 불일치, class ID 고갈을 각각
  `OBJECT_PLACEMENT_*` 코드로 거부하고 도메인 거절 코드(`CHK_PLACEMENT_*`)는
  그대로 통과시킨다. 카탈로그 항목의 `availability`를 placeable로 바꾸는 것은
  helper capability가 도착한 뒤의 작업이다.
- 검증: Linux 컨테이너 Flutter 3.44.8에서 `dart format`,
  `flutter analyze`(무이슈), `flutter test` 141개 통과. 새 테스트는 도메인
  factory·append 규칙, `ObjectEditingController` 배치 14개, Save As 왕복
  통합 1개다. 왕복 테스트는 `UNIT`·`THG2`가 없는 맵에 Unit·Sprite·Doodad를
  배치하고 저장한 뒤, 알 수 없는 `XTRA` 섹션과 기존 `DD2 ` 바이트가 그대로인
  것과 새 섹션이 맨 끝에 붙는 것을 확인한다.
- 남은 M6.2 작업: (1) helper protocol의 unit capability 페이지, (2) 카탈로그
  항목 availability 전환, (3) Tile·Doodad·Unit·Sprite 탭 선택 팝업과 검색·필터·
  최근 선택·상세 미리보기, (4) 커서 ghost·스냅·연속 배치·`Escape` 취소,
  (5) 팝업 위젯 테스트, (6) 대형 카탈로그 가상 스크롤·썸네일 cache 성능 계측,
  (7) 실제 SC:R 설치 스모크. 체크박스는 Windows 게이트와 위 UI 작업이 끝난 뒤
  닫는다.
- 2026-09-07 카탈로그 배치 팝업을 붙였다. `PlacementCatalogController`가 설치
  경로와 열린 맵의 `ERA` 타일셋으로 종류별 페이지를 불러오고, 검색·최근 선택·
  owner·연속 배치와 확정된 선택을 갖는다. `PlacementCatalogDialog`는
  `Tiles`/`Doodads`/`Units`/`Sprites` 탭, 가상화 grid, 상세 미리보기와
  `Place`/`Cancel`을 제공한다. Object Palette 헤더의 `+` 버튼이 팝업을 연다.
- 확정된 Tile은 `TerrainEditingController.selectCatalogTile`로 브러시 값이
  되고, Doodad·Sprite는 캔버스 클릭에서 배치 명령으로 이어진다. Doodad는 클릭한
  타일을 footprint 중심으로 삼는다. `Escape`는 팔레트 배치와 카탈로그 선택을
  함께 취소한다.
- 카탈로그 항목 availability를 실제 구현 상태에 맞췄다. Tile은 항상, Doodad는
  검증된 recipe가 있을 때, pure Sprite는 미리보기가 있을 때 배치 가능하다.
  Unit은 `SC_CATALOG_ITEM_UNIT_CAPABILITY_PENDING` 사유로 계속 비활성이며,
  helper가 `units.dat` capability를 제공해야 열린다.
- bootstrap이 `ProcessStarCraftPlacementCatalogGateway.bundled()`와 기존 tile·
  object atlas gateway를 공유해 배치 카탈로그를 연결한다. 설치 경로는
  StarCraft 데이터 설정 컨트롤러의 상태를 구독해 갱신한다.
- 검증: Linux 컨테이너 Flutter 3.44.8에서 `dart format`, `flutter analyze`
  (무이슈), `flutter test` 190개 통과. 새 테스트는 `PlacementCatalogController`
  10개와 팝업 위젯 6개다.
- 여전히 남은 것: helper의 unit capability protocol, 커서 ghost와 스냅 표시,
  사용자가 끌어서 조절하는 팝업 크기, 분류 트리 필터, 대형 카탈로그 성능 계측,
  실제 SC:R 설치 스모크, Windows 게이트 실행.
- 2026-09-07 helper 0.8.0이 `units.dat` capability를 공급한다. 기존 객체 자산
  경로가 이미 읽는 `arr\units.dat`에서 `shieldEnable`(offset 2472)과
  `flags`(offset 7032)를 읽어 파생 boolean만 JSON으로 내보내고, Dart adapter가
  이를 `UnitPlacementCapability`로 검증한다. 근거 오프셋과 flag 비트는
  [조사 문서](research/VISUAL_PLACEMENT_AND_CHK_RULES.md) 3.2에 기록했다.
- Unit 카탈로그 항목의 availability가 capability에 따라 결정된다. capability를
  읽지 못하면 `SC_CATALOG_ITEM_UNIT_CAPABILITY_UNAVAILABLE`, addon과 Nydus
  Canal처럼 관계가 필요하면 `SC_CATALOG_ITEM_UNIT_RELATION_REQUIRED`로
  비활성이고, 그 밖의 Unit은 팝업에서 배치할 수 있다.
- 팝업에 오른쪽 아래 크기 조절 손잡이와 분류 필터를 추가했다. 분류는 로컬
  데이터가 검증된 `categoryPath`를 줄 때만 나타난다.
- 캔버스가 확정된 선택의 footprint ghost를 타일에 스냅해 그린다. Doodad는
  recipe 크기, Unit과 Sprite는 한 타일이며 맵 밖이면 색이 바뀐다.
- `test/performance/placement_catalog_performance_test.dart`가 2,000개 카탈로그
  페이지에서 첫 표시·검색·연속 스크롤·페이지 추가를 계측하고 가상화와 페이징을
  구조적으로 검증한다. 이 테스트가 grid build 중 `setState`가 호출되던 실제
  결함을 찾아냈고, 다음 페이지 요청을 프레임 뒤로 미뤄 고쳤다. 측정 기록은
  [배치 카탈로그 팝업 성능](performance/PLACEMENT_CATALOG_POPUP.md)에 있다.
- 검증: Linux 컨테이너 Flutter 3.44.8에서 `dart format`, `flutter analyze`
  (무이슈), `flutter test` 192개 통과. C++ capability 로직과 native 테스트가
  쓰는 단언은 g++ `-Wall -Wextra`로 따로 컴파일해 실행 확인했지만, helper 전체
  빌드와 CTest는 Windows에서만 가능하다.
- 남은 것: Windows 게이트(`flutter test`, native CTest,
  `flutter build windows --debug`), 실제 SC:R 설치에서의 배치 스모크와 성능
  기준선 기록, sprite-unit 배치, 기존 Doodad의 복합 삭제.
- 2026-09-07 사용자 요청으로 카탈로그를 모달 팝업에서 작업 영역 탭으로 바꿨다.
  `_WorkspaceView`에 `catalog`를 더해 맵·EUD 탭 옆에 `Catalog` 탭을 놓고,
  `PlacementCatalogDialog`를 `PlacementCatalogPane`으로 대체했다. 확정과
  `Back to map`은 맵 탭으로 돌아가며, 탭을 다시 열면 이미 불러온 페이지를
  재사용한다. 모달이 아니므로 크기 조절 손잡이는 없앴다.
- 탭 전환 시 pane의 첫 로딩이 build 중 `setState`를 부르던 문제를 프레임 뒤로
  미뤄 고쳤다. 팝업의 페이지 추가 로딩에서 고친 것과 같은 종류다.
- 검증: `dart format`, `flutter analyze`(무이슈), `flutter test` 193개 통과.
  새 셸 위젯 테스트가 탭 존재, 탭 전환, `Back to map` 복귀를 확인한다.
- 2026-09-07 위 작업이 끝난 항목의 체크박스를 닫았다. 닫은 항목은 코드, 자동
  테스트, 문서가 모두 있고 Linux 컨테이너에서 `dart format`·`flutter analyze`·
  `flutter test`를 통과한 것들이다. **Windows 게이트(전체 `flutter test`, native
  CTest, `flutter build windows --debug`)와 실제 SC:R 설치 스모크는 아직
  실행하지 못했으므로, 그 두 가지가 남았다는 사실은 아래 열린 항목과 이
  메모로 남긴다.**
- 열어 둔 세 항목의 이유:
  - Doodad 원자적 배치/삭제/Undo — 배치와 Undo/Redo는 하나의 명령으로 동작
    하지만, 다시 연 기존 Doodad의 아래 지형·overlay 귀속 규칙을 상호 운용
    테스트로 확정하기 전에는 복합 삭제를 구현하지 않는다.
  - 성능 계측 — 하네스와 가상화·페이징 구조 판정은 있으나 Windows profile
    기준선과 썸네일 cache 메모리·GPU 해제 측정이 없다.
  - 실제 설치 스모크 — Windows에서만 실행 가능하다.
- 문서 표기를 구현에 맞췄다. 모달 팝업이 작업 영역 탭이 되면서 "크기 조절
  가능한 팝업"은 "카탈로그 선택 탭"이 됐고, 사용자가 끌어 조절하던 손잡이는
  탭에서는 의미가 없어 사라졌다. 단계 제목과 UX 절의 표현도 함께 고쳤다.

- 2026-09-08 Windows 통합 검토: helper의 함수 범위 `sc` 별칭을 공통 범위에
  선언해 C2653 빌드 오류를 수정했다. Windows 가짜 helper와 기대값을 0.8.0
  capability 계약 및 Doodad 배치 가능 상태에 맞췄다. 맵 재열기·설치 경로 변경은
  카탈로그와 배치 선택을 초기화하며, 이전 요청 및 종료 뒤 응답을 무시한다.
  동일 경로 재열기·설치 변경·종료 중 응답 회귀 테스트를 추가했다.
  Windows Flutter 3.47.2 / Dart 3.13.2에서 analyze, 전체 테스트 456개
  (환경 의존 9개 skip), Debug 빌드, native CTest 5/5 통과. 기준 SDK 3.44.8,
  실제 SC:R 배치·게임 실행과 Windows profile 성능은 이번에 검증하지 않았다.
  포맷 검사는 기존 infrastructure 테스트 4개에서 차이가 남았다.
  기존 Doodad 복합 삭제와 실제 설치·성능 검증이 남아 M6.2 전체 완료는 아니다.

완료 조건:

- 사용자가 숫자 ID를 직접 입력하지 않고 실제 이미지 카탈로그 탭에서 네 종류를
  찾고 선택해 캔버스에 배치할 수 있다.
- 현재 맵에 없던 Unit·Sprite도 검증된 기본 레코드로 생성되고 다시 열 수 있다.
- Doodad의 지형과 overlay가 올바른 위치에 함께 표시되며 Undo/Redo와 Save As에서
  부분 적용이 발생하지 않는다.
- 자산 누락·손상·미지원 항목은 탭 전체를 막지 않고 해당 항목만 비활성화한다.
- 탭을 열거나 항목을 둘러보는 행위만으로 문서가 dirty 상태가 되지 않는다.
- 가상화·검색·cache가 문서화된 성능 상한을 통과하고 실제 설치 스모크 증거가 있다.

## M6.3. 맵·플레이어·게임 설정

목표: 배치된 객체의 속성과 구분되는 맵 전체 설정을 편집한다. FR-206~FR-210을
담당하며, 설정별 데이터 모델 → Application 명령 → UI → 저장 왕복 순으로 진행한다.

- [ ] 버전별 설정 섹션 선택·기본값/사용자 값·누락/중복 처리 규칙과 합성 픽스처 확정
- [x] 맵 제목·설명 편집과 공유 문자열을 보존하는 이름 변경 구현
- [ ] 플레이어 슬롯 종류·종족·색상과 시작 위치 참조 진단 구현
- [ ] 세력 배정·이름·동맹·공동 승리·시작 위치 관련 옵션 편집 구현
- [ ] 유닛 종류별 이름·최대 체력/실드·방어력·생산 비용/시간·무기 기본/추가 피해량과 기본값 복원 구현
- [ ] 플레이어별 유닛 생산 허용과 기본값 상속 편집 구현
- [ ] 업그레이드 비용/시간 및 증가량, 플레이어별 시작/최대 레벨과 기본값 편집 구현
- [ ] 테크 비용/연구 시간/에너지, 플레이어별 허용·연구 완료와 기본값 편집 구현
- [ ] 설정 탭의 검색·선택 범위 적용·취소·검증·Undo/Redo와 Inspector 구분 구현
- [ ] 설정별 golden bytes, 미편집 값 보존, Save As/재열기와 실제 SC:R 적용 검증

완료 조건:

- 특정 유닛 하나의 체력 비율 변경과 같은 종류 전체의 최대 체력 변경이 별도 UI로 제공된다.
- 기본값 사용 여부와 사용자 설정을 구분하며 비활성 사용자 값도 임의 삭제하지 않는다.
- 공유 무기/문자열 변경의 영향 범위를 표시하고 잘못된 참조·레벨·비율 입력을 거부한다.
- legacy/확장 섹션이 함께 있을 때 어느 쪽을 편집하는지 검증하며 추측해 동기화하지 않는다.
- 설정만 바꾼 맵을 다시 열어 값과 다른 섹션 바이트가 보존됨을 확인한다.

### 맵 제목·설명 구현 확인 (2026-09-08)

- File → Map Information에서 제목·설명을 입력하고 Apply/Cancel한다. 적용은
  기존 객체·로케이션 편집 명령 기록을 공유하므로 공유 문자열 변경을 순서대로
  Undo/Redo하며, 창에서 실제 명령 이름을 표시한다. 지형까지 포함하는 문서 공통
  기록 통합은 M6.4 범위로 남긴다.
- SPRP 참조 변경과 새 문자열 추가를 한 명령으로 적용한다. 변경 없는 값은 기존
  ID를 유지하고 빈 값은 0 참조로 바꾼다. 기존 공유 문자열과 미참조 tail 및
  다른 섹션은 보존한다. 오래된 문서 스냅샷의 적용은 거부한다.
- 지원 범위는 단일 정상 SPRP와 안전한 STR 또는 STRx 하나다. 중복·손상·잘못된
  참조·기존 UTF-8 해석 실패는 편집을 차단한다. NUL과 새 ID의 u16 상한 초과도
  문서를 바꾸기 전에 거부한다. 레거시 비 UTF-8 편집과 게임 표시 한계의 실측은
  후속 인코딩·실제 게임 검증에 남긴다.
- Windows Flutter 3.47.2 / Dart 3.13.2에서 analyze, 전체 테스트 461개
  (환경 의존 9개 skip), Windows Debug 빌드를 통과했다. 이후 추가한 u16 상한을
  포함한 도메인 테스트 5개도 통과했다. 실제 게임 적용과 기준 SDK 3.44.8은
  이번에 실행하지 않았으며, 전체 포맷 검사에는 기존 infrastructure 테스트
  4개의 차이가 남는다.
- Save As 통합 테스트는 실제 아카이브 gateway 대신 가짜 gateway를 사용한다.
  원본 바이트 보존과 출력 CHK 재열기를 검증했으며 실제 게임 표시는 검증하지 않았다.

## M6.3.1. 유닛·무기 EUD 확장 설정

목표: M6.3의 Unit Settings에 EUD 확장 탭을 추가해 코드를 직접 작성하지 않고
검증된 유닛·무기 설정을 빌드한다. M4와 M6.3 이후 진행하며 FR-307~FR-311과
[EUD 확장 설계](EUD_INTEGRATION.md#14-계획된-유닛무기-eud-확장-설정)를 따른다.

- [ ] 지원 필드 매니페스트와 euddraft/eudplib·SC:R 버전별 호환성·단위·범위·enum 검증 확정
- [ ] 선언적 설정 스키마·맵 연결·프로젝트 저장/다시 열기·migration과 dirty/Undo 모델 구현
- [ ] 유닛/무기 공유 참조 영향 분석, CHK 기본값·EUD override 및 중복 설정 충돌 검증 구현
- [ ] 지상/공중 무기 최소·최대 사거리와 피해 유형(일반형·폭발형·진동형 등) 설정 구현
- [ ] 실드 활성/비활성·최대량과 기존 배치/신규 생성 유닛 초기화 정책 구현
- [ ] 무기 선택·공격 대상, 쿨다운·스플래시 효과/범위의 검증된 조합 구현
- [ ] 후속 필드 묶음: 시야·탐색 거리·크기/속성 및 이동 속도·가속·회전의 공유/적용 제약 조사·구현
- [ ] Unit Settings EUD 탭의 검색·기본값·지원 상태·영향 목록·생성 코드 미리보기 구현
- [ ] 현재 맵/설정 스냅샷에서 결정적 소스·manifest 생성, 사용자 entry 보존과 hook 실행 순서 검증
- [ ] SafeEudBuildPipeline 연결, 별도 출력·반복 빌드 비누적·stale 결과/충돌 진단 구현
- [ ] 선언적 설정·생성 소스·UI 테스트와 사거리/실드/피해 유형의 실제 euddraft·SC:R 검증

완료 조건:

- 일반 설정과 EUD 설정을 구분하고 Save As만으로 EUD 효과가 적용됐다고 표시하지 않는다.
- 같은 무기 등을 공유하는 다른 유닛에 미치는 영향을 확인할 수 있다.
- 첫 버전은 종류별 전역 초기 설정이며 소유자별/개별 유닛/실시간 조건부 변경을 가장하지 않는다.
- 지원 여부가 확인되지 않은 필드는 이유와 함께 비활성화하고 원본 맵·사용자 코드를 보존한다.
- 핵심 3종 설정이 실제 게임에서 적용되고 새 유닛·공유 무기·업그레이드/변신·멀티플레이 검증을 통과한다.

## M6.3.2. 설정별 EUD 확장 탭

목표: M6.3.1의 공통 기반을 유닛 외 설정으로 확장한다. FR-312~FR-315와
[EUD 연동 15절](EUD_INTEGRATION.md#15-계획된-설정별-eud-확장-탭)의 범위를 따른다.
초기 설정은 이 단계에서, 조건부/주기적 실행은 M7.1에서 처리한다.

- [ ] category별 필드 registry·대상/시점·지원 상태·schema/생성기 버전과 공통 EUD 탭 구현
- [ ] Upgrades/Technologies의 검증된 metadata와 전역/플레이어별 설정 구분 구현
- [ ] Players의 종족별 인구수 상한 등 지원 필드와 기본 자원 액션 중복 방지 구현
- [ ] Graphics의 Sprite/Image 참조·표시·그리기 지원 필드와 공유 영향 분석 구현
- [ ] Graphics/Sounds의 유닛 초상화·응답 음성 참조와 기존 게임 자산 ID 검증 구현
- [ ] 기존 유닛/무기/Flingy 설정 바로가기를 동일한 프로젝트 데이터에 연결
- [ ] 탭 간 충돌·CHK override·일반 트리거 중복 및 미지원 필드 빌드 차단 구현
- [ ] category별 프로젝트 저장·Undo/Redo·생성 코드·실제 빌드/게임/멀티플레이 검증

완료 조건:

- 동일 설정을 여러 탭에서 바꿔도 한 번 저장/생성하며 영향 범위를 일관되게 표시한다.
- 기본 기능으로 충분한 항목은 기본 경로를 사용하고 EUD 전용 기능으로 오인하게 하지 않는다.
- 그래픽/업그레이드/인구수의 엔진 제한을 검증하며 멤버 존재만으로 지원 완료로 표시하지 않는다.
- 미지원 속성·잘못된 참조는 이유와 함께 비활성화하고 기존 프로젝트 값은 보존한다.

## M6.4. 기본 제작·편집 도구

목표: 기존 맵 복제 없이 새 UMS 맵을 만들고 기본 지형·객체·안개 작업을 완결한다.
FR-106, FR-211~FR-215를 담당한다. 아래 항목은 각각 작은 구현 단위로 나눈다.

- [ ] 지형·객체·설정 편집을 시간순으로 기록하는 문서 공통 Undo/Redo와 오래된 명령 거부 구현
- [ ] 새 맵의 버전·크기·타일셋·초기 지형·플레이어·기본 트리거 정책과 필수 섹션 생성 규칙 확정
- [ ] New Map → 메모리 문서 → 새 아카이브 Save As → 재열기 구현
- [ ] 기존 맵 크기 변경의 anchor·잘릴 객체/로케이션/지형/안개 영향 미리보기와 원자적 적용 구현
- [ ] 기본 등각 지형 전환·경사로 브러시와 TILE/ISOM/MTXM 상호 운용 규칙 조사·구현
- [ ] 플레이어별 초기 Fog of War 표시·브러시/사각형 편집·Undo/Redo 구현
- [ ] 시작 위치의 명시적 선택·소유자별 배치/이동과 누락·중복 진단 구현
- [ ] 유닛 상태(무적·버로우·클로킹·공중 상태·환상)와 valid flags의 검증된 편집 구현
- [ ] Sprite의 지원 flags와 Doodad enabled 속성 편집의 의미 검증 및 복합 데이터 동기화
- [ ] Addon/Nydus의 연결·해제·복제/삭제 시 관계 및 class ID 무결성 구현
- [ ] 다중 객체 공통 속성 적용과 로케이션 목록·고도 조건·이름/ID 탐색 구현
- [ ] 같은 문서의 지형/객체 선택 영역 자르기·복사·붙여넣기와 Doodad 복합 데이터 보존 구현
- [ ] 미니맵 탐색·겹친 객체 선택과 편집 도구 단축키 연결 구현
- [ ] 각 도구의 취소/실패 무변경, 교차 편집 Undo/Redo, Save As 왕복과 외부 에디터 상호 운용 검증

완료 조건:

- 자체 제작 새 맵으로 설정·지형·객체·안개 편집 후 실제 SC:R에서 시작할 수 있다.
- 일반 등각 지형과 raw 타일 도구의 차이를 표시하며 기존 손상 ISOM을 자동 복구하지 않는다.
- 맵 크기 변경은 영향을 보여주고 사용자가 명시적으로 적용하기 전 문서를 바꾸지 않는다.
- 기존 Doodad의 아래 지형/overlay 귀속이 불명확하면 자르기·이동·삭제도 추측하지 않는다.
- 기존 맵 타일셋 변환, 고급 대칭/사용자 브러시와 문서 간 붙여넣기는 별도 후속 범위다.

## M6.5. 문자열·사운드 리소스

목표: 트리거와 브리핑에서 사용할 텍스트와 소리를 안전하게 관리한다. FR-216을 담당한다.

- [ ] 문자열 전체 목록·검색·사용처와 디코딩 실패/용량 진단 구현
- [ ] 공유 참조를 고려한 문자열 편집·선택 참조 분리·참조 중 삭제 차단 구현
- [ ] WAV 참조와 MPQ 사운드 항목 목록·가져오기·추출·미리듣기·삭제 구현
- [ ] 사운드 경로/크기/지원 포맷 검증, 같은 경로 충돌과 참조 중 삭제 정책 구현
- [ ] 아카이브 리소스 변경을 임시 출력·재검증·Save As 및 문서 Undo/Redo에 연결
- [ ] 자체 제작 소리/문자열로 원본·다른 MPQ 항목 보존과 저장 왕복 검증

완료 조건:

- 사용자가 추가한 소리를 새 출력 맵에서 다시 읽을 수 있고 원본은 변하지 않는다.
- 전체 사용처가 검증되지 않은 문자열/사운드를 미사용으로 단정해 정리하지 않는다.
- M7은 TRIG/MBRF 참조 공급자를 이 사용처 모델에 연결한다. 연결 전 관련 리소스 삭제는 제한한다.
- 기존 문자열 bytes를 자동 재인코딩하거나 번호를 압축하지 않는다.

## M7. 일반 트리거·미션 브리핑

목표: 일반 트리거를 구조적으로 편집하면서 원시 표현을 확인할 수 있게 한다.

- [ ] `TRIG`와 관련 문자열/로케이션 참조 모델 구현
- [ ] 플레이어/조건/액션 구조 편집 UI
- [ ] 복사, 이동, 활성/비활성, 일괄 소유자 변경
- [ ] 원시 트리거 바이트/텍스트 검사 뷰
- [ ] 지원하지 않는 조건/액션의 무손실 보존
- [ ] 참조 무결성과 제한값 검증
- [ ] 일반 트리거와 EUD 생성 트리거의 경계 정책 확정
- [ ] 기본 조건·액션 전체의 지원 표와 플레이어/유닛/로케이션/자원/점수/AI 스크립트 인자 편집 검증
- [ ] 스위치 이름·참조와 Create Unit with Properties의 속성 슬롯 관리 구현
- [ ] M6.5 문자열·사운드 사용처에 TRIG/MBRF 참조 연결 및 참조 중 변경/삭제 검증
- [ ] 미션 브리핑의 플레이어별 액션 순서·시간·텍스트·초상화·사운드 편집 구현
- [ ] 트리거·브리핑의 추가/복제/삭제/순서 변경·Undo/Redo와 실제 실행 왕복 검증

완료 조건:

- 일반 트리거를 추가·수정·삭제하고 다시 열 수 있다.
- 지원하지 않는 트리거 레코드가 손실되지 않는다.
- 잘못된 참조가 저장 전에 진단된다.
- 지원 표가 기본 조건·액션을 빠짐없이 다루고 미지원/EUD 확장은 원시 바이트로 보존한다.
- 브리핑 텍스트·초상화·소리·순서가 실제 게임에서 검증되며 일반 TRIG와 혼동하지 않는다.

## M7.1. EUD 실행 규칙과 동적 표현

목표: M7의 일반 트리거와 M6.3.1~M6.3.2의 선언적 설정을 연결한다. FR-316~FR-318을
담당하며 기존 폼/목록 UI를 확장한다. 시각적 블록 언어는 이 단계 범위가 아니다.

- [ ] 타입 있는 변수·조건·값 식·대상·시점·1회/주기 규칙과 범위/비용 상한 모델 구현
- [ ] Triggers의 EUD 확장 탭 및 각 설정 탭의 실행 규칙 연결과 기본 액션 우선 생성 구현
- [ ] 런타임 유닛의 생성/생존/소멸/변신/슬롯 재사용 식별 및 지원 인스턴스 속성 편집 구현
- [ ] 플레이어별 조건부 자원·업그레이드/연구 상태의 검증된 규칙 구현
- [ ] 로케이션 변수 좌표/크기·계산 영역·검증된 대상 추적 규칙 구현
- [ ] 동적 텍스트와 표시 대상/갱신 주기, 기본 소리 액션 및 리소스 참조 연결 구현
- [ ] 동기화 게임 상태와 로컬 표시의 분리, 순환/중복 쓰기·과도한 반복 진단 구현
- [ ] 버튼셋/요구 조건/Order/IScript 연결의 별도 지원 가능성 조사와 필드별 보류/지원 결정 기록
- [ ] 지형/안개/두다드의 런타임 변경 가능성과 표시·충돌·경로 탐색·동기화 제약 조사 및 보류/지원 결정 기록
- [ ] 규칙 저장/Undo·생성 순서·실제 실행·성능·객체 재사용·멀티플레이 회귀 검증

완료 조건:

- 코드 입력 없이 검증된 규칙을 구성할 수 있고 사용자 코드와 생성 코드의 실행 순서를 확인할 수 있다.
- 한 개체 변경이 종류 전체 DAT 변경으로 변하지 않으며 유효하지 않은 객체 쓰기를 거부한다.
- 로컬 표시 조건이 동기화 게임 상태를 변경하는 규칙으로 연결되지 않는다.
- 후속 조사 항목은 편집 가능 항목과 구분하며 검증 전 임의 주소/포인터 쓰기를 제공하지 않는다.

## M8. 안정화와 배포

목표: 실제 제작에 시험 사용할 수 있는 Windows 프리뷰를 배포한다.

- [ ] 자동 저장과 충돌 복구
- [ ] 크래시 로그와 개인정보 제거 기능
- [ ] 대용량 맵 성능 프로파일링
- [ ] 키보드 접근성 및 고대비 확인
- [ ] 외부 도구/라이브러리 라이선스 고지
- [ ] Windows 패키징과 깨끗한 PC 설치 테스트
- [ ] 버전, 변경 기록, 마이그레이션 정책
- [ ] 대표 맵 수동 회귀 테스트
- [ ] StarCraft: Remastered 실제 실행 스모크 테스트
- [ ] 기본 기능 대조표의 모든 기본 항목과 새 맵 → 설정 → 편집 → 트리거/브리핑 → 저장 → 게임 실행 시나리오 검증
- [ ] EUD 확장 지원표의 category별 초기 설정·실행 규칙·공유 영향·멀티플레이 시나리오 검증

완료 조건:

- 새 Windows 환경에서 설치·실행·제거가 가능하다.
- MVP 흐름이 릴리스 패키지에서 재현된다.
- 기본 에디터 완료를 표방하는 릴리스는 M6.2~M7과 기본 기능 대조표의 인수 조건을 모두 통과한다.
- EUD 확장을 지원한다고 표시하는 category는 M6.3.1~M6.3.2/M7.1의 해당 검증을 통과한다. 조사 중 항목은 지원 완료로 표시하지 않는다.
- 알려진 데이터 손실 결함이 없다.
- 외부 구성요소 버전과 라이선스가 배포물에 기록된다.

## 장기 후보

- 시각적 EUD 블록/템플릿
- epScript 언어 서버와 심볼 탐색
- StarCraft 테스트 실행과 로그 연결
- 지형 대칭, 고급 브러시, 타일 적합성 도구
- 기존 맵 타일셋 변환과 다중 문서 간 붙여넣기
- 다중 문서와 diff/merge
- 플러그인 API
- StarCraft 1.16.1 호환 프로필
- macOS/Linux 읽기 전용 도구
