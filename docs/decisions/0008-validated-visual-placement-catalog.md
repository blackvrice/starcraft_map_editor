# ADR-0008: 검증된 로컬 카탈로그와 종류별 배치 recipe

- Status: Accepted
- Date: 2026-08-22

구현 메모: 2026-08-22에 Application의
`StarCraftPlacementCatalogGateway`, 종류별 stable key, 제한된 페이지 요청/응답,
안전한 이름 fallback과 항목별 availability/diagnostic 모델을 구현했다. helper의
실제 카탈로그 operation과 기존 Object Palette/UI merge는 후속 항목이다.

## Context

현재 Object Palette는 열린 맵에 이미 있는 `UNIT`, `DD2 `, `THG2` 레코드를
byte-exact 템플릿으로 복제한다. 원시 필드 보존에는 안전하지만 맵에 없는 ID를
선택할 수 없고, Doodad가 `DD2 `뿐 아니라 지형과 overlay로 구성된다는 사실을
표현하지 못한다.

M6.2는 로컬 StarCraft: Remastered 설치에서 Tile, Doodad, Unit, Sprite 전체
카탈로그와 실제 이미지를 보여준다. Presentation에서 DAT/CV5를 해석하거나 빈
CHK 레코드를 임의로 만들면 계층 규칙과 raw-first 정책을 깨고, 잘못된 Doodad는
세 섹션 중 일부만 바꾸는 손상 상태를 만들 수 있다.

## Decision

### 카탈로그 경계

- Application에 페이지 가능한 `StarCraftPlacementCatalogGateway` 포트를 둔다.
  Infrastructure의 기존 번들 helper만 사용자가 고른 로컬 설치를 읽고,
  versioned protocol의 검증된 metadata를 반환한다.
- Domain/Application 카탈로그 모델은 kind, stable ID, optional tileset, 분류,
  검증된 이름 또는 숫자 fallback, thumbnail key, 배치 가능 상태와 진단만 가진다.
  Flutter, 파일 시스템, CascLib와 원시 게임 자산은 이 경계를 넘지 않는다.
- popup 탐색과 선택은 문서 밖 상태다. 실제 캔버스 배치가 성공한 시점에만
  dirty와 하나의 Undo entry를 만든다.
- 로컬 설치에서 온 합성 항목과 현재 맵 레코드 복제 항목은 `source`로 구분한다.
  기존 복제 경로는 호환 fallback으로 유지하지만 합성 기본값의 근거로 사용하지
  않는다.

### 종류별 생성

- Tile은 `(tileset, raw MTXM u16)` recipe로 배치한다. `TILE`과 `ISOM`은 수정하지
  않는다.
- Unit은 검증된 unit capability snapshot을 받는 `UnitPlacementFactory`로 36-byte
  레코드를 만든다. owner·비율·자원·valid flags와 class ID 할당은
  [조사 기준](../research/VISUAL_PLACEMENT_AND_CHK_RULES.md)에 고정한다. 필요한
  capability가 없거나 관계 규칙이 미확정이면 해당 항목만 비활성화한다.
- pure Sprite는 `DrawAsSprite`를 가진 10-byte `THG2` factory를 사용한다.
  sprite-unit은 ID 의미와 flags가 검증된 항목만 허용한다.
- Doodad는 tileset CV5/DDData에서 완전히 검증된 `DoodadPlacementRecipe`를
  사용한다. 한 command가 footprint의 `MTXM` before/after, enabled `DD2 `와
  optional overlay `THG2`를 함께 적용·Undo한다.
- Doodad recipe 일부가 없거나 footprint가 경계/placibility 검사를 실패하거나
  수정 대상 섹션이 모호하면 전체 배치를 거부한다. 부분 적용과 값 추측은 없다.

### 삭제와 재open 안전성

- 같은 세션에서 새 Doodad command는 저장한 before snapshot과 record identity로
  정확히 Undo/Redo한다.
- 다시 연 기존 Doodad의 아래 지형은 `DD2 `만으로 복원할 수 없다. 유일하고
  유효한 `TILE` 기반 복원 규칙과 overlay 귀속을 검증하기 전에는 기존 Doodad의
  복합 삭제를 비활성화한다. 같은 좌표/type의 `THG2`를 무조건 함께 삭제하지 않는다.
- 중복 섹션의 active 대상을 추측하지 않는다. 새 섹션이 필요한 경우의 삽입
  위치는 raw 순서 보존 테스트로 결정한 뒤 구현한다.

## Alternatives

### 모든 새 객체를 zero-filled 레코드로 생성

Unit의 valid flags와 자원 기본값, sprite-unit의 type 의미를 잃는다. 게임에서
다르게 동작하거나 관계가 깨질 수 있으므로 채택하지 않는다.

### 현재 맵의 첫 레코드만 계속 복제

미지원 필드 보존에는 유용하지만 전체 카탈로그 요구사항을 충족하지 못하고
맵마다 배치 가능 항목이 달라진다. fallback으로만 유지한다.

### Doodad를 `DD2 `만 추가

footprint 지형과 overlay가 생기지 않아 화면과 게임 결과가 불완전하다. 반대로
MTXM만 칠하면 편집 가능한 Doodad metadata가 없다. 하나의 복합 recipe가
필요하므로 채택하지 않는다.

### 기존 Doodad 삭제에서 주변 타일을 추측

`DD2 `에는 underlying terrain이 없다. 사용자의 `MTXM`을 복구 불가능하게 바꿀
수 있으므로 채택하지 않는다.

## Consequences

장점:

- 맵에 없는 항목도 로컬 데이터로 일관되게 검색·선택할 수 있다.
- 잘못되거나 일부만 읽힌 항목은 전체 popup을 막지 않고 개별 비활성화된다.
- Doodad의 세 섹션 변경과 Undo가 하나의 원자적 사용자 동작이 된다.
- UI, 위험한 바이너리 parsing, CHK mutation의 경계가 분명해진다.

비용:

- helper protocol에 카탈로그/CV5/DDData/unit capability metadata가 추가된다.
- 합성 fixture, factory golden bytes와 Doodad 복합 왕복 테스트가 필요하다.
- 기존 Doodad의 완전한 삭제는 `TILE` 복원과 overlay 귀속을 검증할 때까지 제한된다.
- addon, Nydus와 sprite-unit의 일부 항목은 후속 검증 전 배치 불가일 수 있다.

## Validation

- 자체 제작 metadata로 종류별 stable ID, 이름 fallback, 정렬, 손상 항목 격리와
  tileset 제한을 단위 테스트한다.
- Unit/Sprite factory는 정확한 36/10-byte golden record와 DAT 조건별 flags,
  u16/u8 범위, class ID 충돌을 검증한다.
- Doodad recipe는 홀수/짝수 footprint 중심, sparse member, placibility, optional
  overlay, 경계 실패와 command rollback을 검증한다.
- 배치→Undo→Redo→Save As→재open에서 관련 섹션과 `MTXM`만 의도대로 바뀌고
  알 수 없는 섹션·중복·예약 바이트가 보존되는지 비교한다.
- 로컬 SC:R 스모크는 저장소에 게임 자산이나 결과 맵을 추가하지 않고 각 종류의
  대표 항목을 선택·배치한다.

## References

- [시각적 배치 선택과 CHK 생성 규칙 조사](../research/VISUAL_PLACEMENT_AND_CHK_RULES.md)
- [ADR-0002 raw-first 무손실 CHK 모델](0002-lossless-chk-model.md)
- [ADR-0005 CascLib helper](0005-casclib-helper-process.md)
- [ADR-0006 타일 아틀라스](0006-request-scoped-tile-atlas-cache.md)
- [ADR-0007 객체 스프라이트 아틀라스](0007-object-sprite-atlas-protocol.md)
