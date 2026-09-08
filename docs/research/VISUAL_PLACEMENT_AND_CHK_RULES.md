# 시각적 배치 선택과 CHK 생성 규칙 조사

- 조사일: 2026-08-22
- 기준 구현: Chkdraft commit
  [`32d27861b16dda0b0f3d95e34bad894ea4efb2c3`](https://github.com/TheNitesWhoSay/Chkdraft/tree/32d27861b16dda0b0f3d95e34bad894ea4efb2c3)
- 적용 범위: M6.2 Tile·Doodad·Unit·Sprite 카탈로그와 배치 명령

## 1. 조사 목적과 한계

현재 `ObjectPaletteController`는 열린 맵에 이미 존재하는 `UNIT`, `DD2 `,
`THG2`의 첫 같은 type 레코드를 복제한다. 이 방식은 원본의 알려지지 않은
필드를 보존하는 안전한 호환 경로지만, 맵에 없는 항목을 전체 카탈로그에서 골라
새로 배치할 수 없다.

M6.2 구현 전에 다음을 분리해 확정한다.

1. 사용자가 항목을 고르는 UI 상태와 실제 문서 변경 시점
2. 로컬 StarCraft 데이터에서 카탈로그 항목을 만드는 키
3. 새 항목을 배치할 때 수정해야 하는 CHK 섹션과 기본 레코드
4. 로컬 데이터가 없거나 불완전할 때 배치를 막아야 하는 조건

Chkdraft는 Scmdraft 계열의 공개 구현이고 현재 동작을 확인할 수 있는 좋은
상호 운용 기준이지만 StarCraft 파일 포맷 사양 자체는 아니다. 아래의
"관찰"은 고정 commit의 실제 코드 경로에서 확인한 사실이고, "프로젝트 규칙"은
그 관찰과 이 저장소의 raw-first 정책을 함께 적용한 결정이다.

## 2. 공통 선택 흐름

Chkdraft 왼쪽 트리는 Doodads, Units, Sprites를 계층형 분류로 채운다. 항목을
선택하면 대응 레이어로 바꾸고 quick clipboard에 배치 템플릿을 넣은 뒤 paste
mode를 시작한다. Unit과 Sprite는 선택만으로 CHK를 바꾸지 않고, 캔버스를
클릭할 때 좌표를 채워 레코드를 추가한다. Doodad도 선택 시 CV5 기반 recipe만
만들고 클릭할 때 관련 레코드와 타일을 추가한다.

Tile은 별도의 크기 조절 가능한 modeless palette에 32×32 실제 타일 grid로
나온다. 클릭은 rectangular terrain sublayer의 quick tile을 바꾸고 paste mode를
시작하며, 캔버스에 붙일 때만 raw tile value가 변경된다.

프로젝트 규칙:

- 팝업의 탭·검색·분류·미리보기·최근 선택은 문서 밖 UI 상태다.
- 단일 클릭은 미리보기만, 더블 클릭·Enter·`Place`는 배치 도구 선택만 바꾼다.
- 캔버스에 유효한 배치를 확정하기 전에는 dirty와 Undo 기록을 만들지 않는다.
- 모든 카탈로그 항목은 종류와 숫자 ID를 안정적인 키로 가진다. 검증된 이름이
  없으면 `Tile #123`, `Doodad #7`, `Unit #37`, `Sprite #130`을 표시한다.
- 게임 데이터의 원시 DAT/TBL/CV5/GRP는 helper 경계 밖으로 내보내거나 저장소에
  포함하지 않는다.

참조:

- [레이어 선택과 quick paste 시작](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/left_bar.cpp#L23-L175)
- [Doodad 분류 트리](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/chkd_controls/doodad_tree.cpp#L15-L28)
- [Unit 분류 트리](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/chkd_controls/unit_tree.cpp#L45-L90)
- [Sprite와 sprite-unit 분류 트리](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/chkd_controls/sprite_tree.cpp#L18-L79)
- [Tile palette 선택과 렌더](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/dialog_windows/layers/terrain_palette.cpp#L38-L200)

## 3. 종류별 생성 규칙

### 3.1 Tile

관찰:

- 카탈로그 키와 실제 배치 값은 현재 tileset의 16-bit raw tile value다.
- rectangular paste는 32×32 좌표에 raw value를 쓰며 Chkdraft의 Game scope는
  `MTXM`이다.
- ISOM brush는 별도 sublayer와 변환 경로다. raw tile palette 선택과 같은
  연산이 아니다.

프로젝트 규칙:

- 첫 구현은 `ERA`가 유일하고 0~7 tileset으로 해석되며 유일한 유효 `MTXM`이
  있을 때만 Tile 카탈로그를 배치 가능하게 한다.
- 항목 키는 `(tileset, rawTileValue)`다. 표시용 CV5 group/member는 각각
  `raw >> 4`, `raw & 0x0f`로 제공할 수 있지만 저장 값은 원래 u16이다.
- 실제 CV5 범위와 32×32 렌더 성공을 검증하지 못한 raw 값은 목록에서 진단과
  함께 비활성화한다.
- M6.2 rectangular 배치는 `MTXM`만 바꾸며 `TILE`과 `ISOM`을 재생성했다고
  추측하지 않는다. ISOM terrain brush는 별도 단계다.

참조:

- [rectangular tile paste](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/mapping/clipboard.cpp#L163-L209)

### 3.2 Unit

관찰:

Chkdraft는 Unit 항목을 고를 때 36-byte `UNIT` 레코드를 zero-initialize하고
다음 기본값을 만든다.

| 필드 | 선택 시 기본값 또는 계산 |
| --- | --- |
| type | 선택한 `units.dat` ID |
| owner | 현재 플레이어 |
| x/y | 0, 실제 paste에서 클릭 좌표 |
| hitpoint/shield/energy percent | 각각 100 |
| resource amount | 일반 resource 1500, geyser/refinery/extractor/assimilator 5000, 그 외 0 |
| hangar amount | 0 |
| state flags | 0 |
| valid field flags | Owner + DAT 조건에 따른 Energy/Shields/Resources/Hangar |
| valid state flags | 기본 Invincible + DAT 조건에 따른 InTransit/Burrow/Cloak/Hallucinated; 원래 invincible unit은 Invincible valid bit 제외 |
| class/relation/unused | 선택 시 0 |

실제 paste는 배치 직전에 다음 class ID를 할당하고 relation을 초기화한다.
배치 가능 영역을 확인한 후 Addon과 Nydus 관계는 별도 규칙으로 연결한다.

프로젝트 규칙:

- `UnitPlacementFactory`는 UI가 아니라 Application/Domain 경계에 둔다.
- factory 입력은 검증된 unit ID, 현재 owner, 클릭 좌표와 helper가 반환한 최소
  unit capability snapshot이다. 위 표의 조건을 재현할 데이터가 부족하면 해당
  Unit을 배치 불가로 표시하고 임의 플래그를 만들지 않는다.
- class ID는 카탈로그에 저장하지 않고 배치 명령 적용 시 현재 문서에서 충돌
  없이 할당한다. Addon/Nydus 자동 연결은 별도 검증 작업 전에는 수행하지 않으며
  관계가 필요한 항목은 비활성화하거나 관계 없음이 유효함을 검증해야 한다.
- 기존 맵의 같은 type 레코드 복제는 별도의 `mapTemplate` source로 유지한다.
  합성 factory와 복제 template를 조용히 혼용하지 않는다.

구현 확인(2026-09-07):

- 고정 commit의 `chk.h`에서 `UNIT` 36-byte 필드 순서와 flag 비트를 확인해
  `ChkUnitPlacement`에 상수로 고정했다. state flag는 `Cloak=BIT_0`,
  `Burrow=BIT_1`, `InTransit=BIT_2`, `Hallucinated=BIT_3`, `Invincible=BIT_4`이고
  valid field flag는 `Owner=BIT_0`, `Hitpoints=BIT_1`, `Shields=BIT_2`,
  `Energy=BIT_3`, `Resources=BIT_4`, `Hangar=BIT_5`다. 같은 비트 정의가 offset 12
  `validStateFlags`와 offset 26 `stateFlags`에 함께 쓰인다.
- 같은 commit의 `left_bar.cpp` 선택 기본값에서 위 표를 다음까지 구체화했다.
  Energy valid는 `Spellcaster`, Shields valid는 `shieldEnable != 0`,
  Resources valid는 `ResourceContainer`, Hangar valid는 Carrier·Reaver 계열
  type일 때만 설정한다. valid state는 항상 `Invincible`로 시작해
  `FlyingBuilding`이면 `InTransit`, `Burrowable`이면 `Burrow`, `Cloakable`이면
  `Cloak`을 더하고, `Invincible` unit이면 `Invincible` 비트를 제거하며,
  invincible도 building도 아닐 때만 `Hallucinated`를 더한다. Hitpoints valid
  비트는 설정하지 않는다.
- `UnitPlacementCapability`는 위 조건을 재현하는 파생 boolean만 갖는 도메인
  모델이다. 원시 DAT 바이트는 helper 경계를 넘지 않으며, capability를 읽지
  못한 항목은 배치 불가로 남기고 값을 추측하지 않는다.
- `UnitPlacementFactory.create`는 class ID를 입력으로 받아 호출자가 문서에서
  할당하게 하고, `requiresRelationLink` capability는
  `CHK_PLACEMENT_UNIT_RELATION_REQUIRED`로 거절한다. 거절 결과는 바이트를
  전혀 반환하지 않는다.
- class ID는 열린 문서의 모든 `UNIT` 섹션에서 가장 큰 값 + 1로 할당한다.
  기존 레코드와 절대 충돌하지 않고, 값이 `uint32`를 넘으면
  `OBJECT_PLACEMENT_CLASS_ID_EXHAUSTED`로 배치를 거부한다.
- 2026-09-07 helper 0.8.0이 capability를 공급한다. `units.dat`은 고정 크기
  19,876바이트의 병렬 배열이고, 고정 commit의 `sc.h` `Sc::Unit::DatFile`
  선언을 순서대로 더한 오프셋이 `shieldEnable`은 2472, `flags`는 7032이며
  두 배열 합계가 파일 크기와 정확히 일치한다. flag 비트는 `Building=BIT_0`,
  `Addon=BIT_1`, `FlyingBuilding=BIT_5`, `Cloakable=BIT_9`,
  `ResourceContainer=BIT_13`, `Burrowable=BIT_20`, `Spellcaster=BIT_21`,
  `Invincible=BIT_29`를 쓴다.
- gas 컨테이너는 Terran Refinery(110), Zerg Extractor(149),
  Protoss Assimilator(157), Vespene Geyser(188)이고, hangar는
  Carrier(72)·Warbringer(81)·Gantrithor(82)·Reaver(83)다. 이 ID들은 같은
  commit의 `Sc::Unit::Type` 열거에서 읽었고 로컬 설치 스모크로 최종 확인한다.
- `requiresRelationLink`는 `Addon` flag이거나 Zerg Nydus Canal(134)일 때 참이며,
  해당 Unit은 관계 규칙이 검증될 때까지 배치를 거부한다.
- `units.dat`이 고정 크기가 아니거나 ID가 범위를 벗어나면 helper는 capability를
  만들지 않고 `SC_CASC_UNIT_CAPABILITY_UNAVAILABLE`로 그 항목만 격리한다.
  원시 DAT 바이트는 helper 경계를 넘지 않고 파생 boolean만 나간다.

참조:

- [Unit 선택 기본값](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/left_bar.cpp#L53-L123)
- [Unit paste와 class/relation 처리](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/mapping/clipboard.cpp#L328-L420)
- [`UNIT` 36-byte 구조](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L100-L155)

### 3.3 Sprite와 sprite-unit

관찰:

- `THG2`는 10-byte 레코드다. type, x/y, owner, unused와 flags를 가진다.
- pure sprite는 type을 `sprites.dat` ID로 해석하고 `DrawAsSprite`(`BIT_12`)를
  설정한다.
- sprite-unit은 type을 unit ID로 해석하고 `DrawAsSprite`를 지우며 `IsUnit`
  bit를 설정한다. Doodad에서 유래한 알려진 플래그가 있으면 pure/sprite-unit
  변환 뒤 호환 비트를 유지한다.
- 선택 시 x/y와 unused는 0이고 paste에서 클릭 좌표만 채운다.

프로젝트 규칙:

- UI의 `Sprites` 탭 안에서 `Pure sprite`와 `Sprite-unit`을 명시적으로 구분한다.
  같은 숫자 type이라도 `(semanticKind, id)`가 다른 카탈로그 키다.
- 일반 pure sprite factory는 `owner=current`, `unused=0`,
  `flags=DrawAsSprite`로 시작한다. 일반 sprite-unit은 데이터 관계가 충분히
  검증되기 전에는 숨기지 않고 비활성화한다.
- Doodad overlay용 `THG2`는 일반 Sprite factory가 아니라 Doodad recipe가
  만든다. 사용자가 만든 일반 Sprite와 위치/type이 같다는 이유만으로 Doodad
  삭제에 함께 제거하지 않는다.

구현 확인(2026-09-07):

- `SpritePlacementFactory.createPureSprite`는 10-byte 레코드에 type, 클릭 좌표,
  owner, `unused=0`과 `flags=DrawAsSprite`(`BIT_12`)만 쓴다. `IsUnit`과
  `SpriteUnitDisabled` 비트는 설정하지 않는다.
- Chkdraft의 pure sprite 기본값은 Doodad에서 유래한 flag를 함께 변환하지만,
  일반 카탈로그 Sprite에는 그런 원천이 없으므로 `DrawAsSprite`만 남긴다.
- sprite-unit은 `CHK_PLACEMENT_SPRITE_UNIT_UNSUPPORTED`로 거절해 탭에서 보이되
  배치만 비활성 상태로 둔다.

참조:

- [Sprite와 sprite-unit 선택 기본값](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/left_bar.cpp#L137-L174)
- [`THG2` 구조와 flags 변환](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L333-L380)
- [Sprite paste](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/mapping/clipboard.cpp#L423-L449)

### 3.4 Doodad

관찰:

Doodad tree의 leaf key는 DD2 type 자체가 아니라 현재 tileset CV5의 doodad 시작
tile group이다. 이 그룹의 `DoodadCv5`와 뒤따르는 footprint row에서 다음 recipe를
만든다.

| recipe 값 | 데이터 원천 |
| --- | --- |
| DD2 type | `ddDataIndex` |
| width/height | CV5 doodad의 `tileWidth`, `tileHeight` |
| footprint MTXM | non-empty member마다 `16 * (startGroup + y) + x` |
| placibility | DDData의 footprint별 허용 기존 tile group |
| overlay type | `overlayIndex`, 0이면 없음 |
| overlay semantic | CV5 flags의 `DrawAsSprite` 여부 |
| owner | 현재 플레이어 |
| center | footprint 시작점 + `(width*16, height*16)` pixels |

유효 클릭이면 Chkdraft는 하나의 동작에서 다음을 수행한다.

1. `DD2 `에 enabled 레코드 한 건 추가
2. overlay index가 0이 아니면 같은 중심·owner의 `THG2` 한 건 추가
3. non-empty footprint member를 `MTXM`에 기록

기본 설정에서는 footprint가 맵 안에 있고 DDData placibility가 현재 MTXM tile
group과 맞아야 한다. Chkdraft의 Doodad 삭제는 해당 footprint의 현재 `MTXM`이
recipe 타일과 일치할 때에만 `TILE` editor scope의 underlying tile로 되돌린다.
즉 `DD2 `만으로는 기존 Doodad 아래의 지형을 복원할 수 없다.

프로젝트 규칙:

- `DoodadPlacementRecipe`는 `(tileset, startCv5Group, ddDataIndex)`를 식별자로
  갖고 footprint, 중심점, placibility, optional overlay를 완전히 검증한 뒤에만
  배치 가능하다.
- 배치는 대상 `MTXM` 셀의 before/after, 새 `DD2 `, optional `THG2`를 하나의
  원자적 command/Undo entry로 적용한다. 어느 한 부분이라도 실패하면 아무
  섹션도 바꾸지 않는다.
- Doodad 배치는 Game terrain인 `MTXM`만 바꾼다. `TILE`/`ISOM`을 생성하거나
  동기화하지 않는다.
- 같은 세션에서 새로 배치한 Doodad는 command가 가진 before snapshot으로
  정확히 Undo/삭제할 수 있다. 다시 연 기존 Doodad의 지형 복원 삭제는 유일하고
  유효한 `TILE`과 상호 운용 규칙이 검증되기 전에는 MTXM을 추측해 복원하지
  않는다. 이 경우 metadata/overlay만 지우는 동작도 "Doodad 삭제"로 가장하지
  않고 명시적으로 차단한다.
- overlay 연결은 CHK에 별도 관계 ID가 없다. 새 command가 만든 THG2 record
  identity를 Undo 동안 추적하되, 재open 뒤에는 같은 좌표/type만으로 사용자가
  배치한 Sprite까지 자동 삭제하지 않는다.

구현 확인(2026-08-22):

- helper 0.7.0은 각 tileset의 `CV5`와 `dddata.bin`을 함께 읽고 `index == 1`,
  name ID가 0이 아닌 시작 group을 `(DDData ID, start group)` 순서로 페이지화한다.
- 폭·높이는 1~16, footprint는 최대 256칸으로 제한한다. non-empty CV5 member만
  `16*(startGroup+y)+x` raw `MTXM`을 가지며 DDData의 앞 `width*height` u16을
  같은 row-major 순서의 placibility group으로 보존한다.
- overlay 0은 없음, `DrawAsSprite`가 있으면 classic Sprite 0~516, 없으면
  sprite-unit Unit 0~227로 검증한다. 중심은 footprint 시작점 기준
  `(width*16, height*16)`이고 `DD2 ` enabled 값은 1로 고정한다.
- 정상 recipe도 원자적 command 구현 전에는 배치 불가다. 잘린 footprint,
  flags 0, 범위 밖 DDData/overlay 등은 `SC_CASC_DOODAD_*`로 해당 항목만
  비활성화하며 값을 추측하지 않는다.

구현 확인(2026-09-07):

- `DoodadPlacementFactory`는 recipe와 배치 원점에서 `DD2 ` 8바이트 레코드,
  선택적 `THG2` 10바이트 overlay, footprint의 `MTXM` 쓰기 목록을 하나의
  계획으로 만든다. 중심 좌표는 `originTile * 32 + centerOffset`이고 `uint16`을
  넘으면 `CHK_PLACEMENT_DOODAD_CENTER_RANGE`로 거절한다.
- overlay `THG2`는 중심 좌표와 owner를 `DD2 `와 공유하고 `unused`는 0,
  flags는 recipe overlay의 의미(pure sprite면 `DrawAsSprite`)를 그대로 쓴다.
- 배치 명령은 `MTXM` 셀의 before/after, `DD2 ` 추가, 선택적 `THG2` 추가를 한
  `_ObjectEditCommand`로 적용해 Undo/Redo 한 항목으로 되돌린다. 세 섹션 중
  하나라도 조건을 만족하지 못하면 아무 섹션도 바꾸지 않는다.
- DDData placibility는 `requiredTileGroup`이 0이 아닐 때만 검사하고, 현재
  `MTXM` 값의 CV5 group(`raw >> 4`)과 다르면
  `OBJECT_PLACEMENT_DOODAD_TERRAIN_MISMATCH`로 거절한다.
- recipe의 tileset이 유일한 `ERA`(0~7)와 다르면
  `OBJECT_PLACEMENT_DOODAD_TILESET_MISMATCH`, footprint가 맵 밖이면
  `OBJECT_PLACEMENT_OUT_OF_BOUNDS`로 거절한다. Doodad 배치는 Doodad와 Terrain
  레이어가 모두 잠겨 있지 않아야 한다.
- 기존 Doodad의 복합 삭제와 재open 후 overlay 귀속은 여전히 구현하지 않았다.
  이 단계는 배치, Undo/Redo와 Save As 왕복까지만 다룬다.

참조:

- [CV5 Doodad recipe 구성](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/mapping/clipboard.cpp#L57-L138)
- [Doodad paste의 DD2·THG2·MTXM 변경](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/mapping/clipboard.cpp#L213-L263)
- [CV5 Doodad 필드](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L3882-L3899)
- [Doodad 삭제와 underlying `TILE`](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L1370-L1419)

## 4. 카탈로그 및 명령 경계

카탈로그가 반환할 최소 모델은 다음과 같다.

```text
PlacementCatalogEntry
  kind: tile | doodad | unit | pureSprite | spriteUnit
  stableId: 종류별 ID 또는 복합 키
  tileset: null 또는 0..7
  categoryPath: 검증된 분류 경로
  displayName: 검증된 이름 또는 숫자 fallback
  thumbnailKey: terrain/object atlas에서 사용하는 불변 키
  availability: placeable | unsupported | invalid
  diagnostic: 비활성 이유
  source: localData | mapTemplate
```

Presentation은 이 모델만 검색·표시하고 CHK 레코드나 로컬 파일을 직접 만들지
않는다. 확정된 항목은 종류별 placement selection으로 바뀌고, 캔버스 명령이
factory/recipe를 호출한다.

```text
Popup selection (no document change)
  -> PlacementSelection
  -> canvas click + snap/footprint validation
  -> Unit/Sprite factory or Tile/Doodad recipe
  -> one EditorCommand
  -> typed re-decode + semantic validation
  -> session adoption + one Undo entry
```

중복된 `ERA`, `DIM `, `MTXM`, `UNIT`, `DD2 `, `THG2` 중 어느 섹션을 수정할지
모호하면 active section을 추측하지 않고 배치를 막는다.

섹션이 없는 경우의 삽입 규칙은 2026-09-07에 확정했다. 새 섹션은 문서 맨 끝에만
추가하고, 소스 오프셋은 원본 파일 길이로 고정하며, 거부된 배치는 빈 섹션조차
남기지 않는다. Undo는 그 명령이 추가한 꼬리 섹션만 정확히 제거한다. 자세한
규칙과 근거는 [파일 포맷과 무손실 정책](../FILE_FORMATS.md)의 "섹션 추가 규칙"에
있다.

## 5. 구현 전 해결해야 할 항목

- **미해결** helper가 CV5/DDData unit capability와 분류 이름을 원시 자산 비노출
  계약으로 어떻게 반환할지 protocol을 버전 관리한다. `UnitPlacementCapability`가
  요구하는 boolean 집합은 확정됐으므로 남은 것은 helper 쪽 구현이다.
- **미해결** Unit addon/Nydus와 sprite-unit의 유효한 합성 범위를 fixture로
  확정한다. 그때까지 두 경우 모두 배치를 거부한다.
- **미해결** 기존 Doodad 삭제의 underlying terrain 복원은 `TILE` 유일성·크기·
  정합성과 Chkdraft 왕복을 검증한 뒤 지원 범위를 정한다.
- **미해결** Doodad overlay의 재open 후 귀속 판정은 좌표/type 일치만으로
  확정하지 않는다.
- **미해결** 카탈로그 항목 수, 페이지 상한, 정렬과 thumbnail batching을 성능
  기준과 함께 고정한다.
- **해결(2026-09-07)** 섹션이 없거나 중복일 때의 삽입·거부 규칙과 class ID
  할당. 위 4절과 [파일 포맷과 무손실 정책](../FILE_FORMATS.md)에 기록했고
  도메인·애플리케이션·통합 테스트로 고정했다.

## 6. M6.2에 채택할 기준선

- Chkdraft의 선택→quick paste→캔버스 확정 흐름을 참고하되 popup 탐색 자체는
  문서를 변경하지 않는다.
- Tile은 `MTXM` raw u16, Unit은 `units.dat` ID, pure Sprite는 `sprites.dat` ID,
  Doodad는 tileset CV5 시작 group과 DDData ID를 기반으로 한다.
- Unit은 DAT capability가 충분할 때만 검증된 기본 레코드를 합성한다.
- Doodad는 `MTXM + DD2 + optional THG2`의 하나의 recipe/command다.
- 안전하게 합성할 수 없는 항목은 숫자 ID와 이유를 보여주고 배치만 비활성화한다.
- 현재 맵 레코드 복제는 raw 보존형 호환 fallback으로 계속 제공한다.
