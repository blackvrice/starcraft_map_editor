# ADR-0007: 요청별 객체 스프라이트 아틀라스 프로토콜

- Status: Accepted
- Date: 2026-08-16

구현 메모: 이 결정의 wire protocol 3과 helper 0.4.0은 2026-08-18 구현됐다.
설치 검사·타일 렌더·객체 렌더 어댑터가 같은 버전으로 함께 이관됐다.
2026-08-16에 classic DAT/TBL 크기·참조·경로를 검증하는 native
`ObjectSpriteReference`와 합성 테스트를 먼저 구현했다.
같은 날 GRP frame 0 decoder와 binary writer를 구현하면서 GRP 색상은 맵
타일셋 WPE에 의존한다는 점을 확인해 요청에 `tileset`을 명시하도록 계약을
보완했다. 이 변경은 아직 배포하지 않은 protocol 3 구현 계약에 포함한다.
2026-08-18에는 Dart `StarCraftObjectAtlasGateway` 계약, map key loader, 객체 전용
LRU와 operation 취소·generation 차단 controller를 구현했다. 이어서 native
CascLib object reader, WPE/128×1 tunit palette decoder와 concrete helper process
adapter를 연결하고 로컬 SC:R unit 0 대표 프레임 스모크를 통과했다. 캔버스
painter는 아직 연결하지 않았다.

## Context

[ADR-0006](0006-request-scoped-tile-atlas-cache.md)의 `renderTileAtlas`는 모든
결과가 32×32인 지형 타일에 맞춘 고정 envelope다. M6.1의 객체 그래픽은
`UNIT` 또는 `THG2` ID를 여러 DAT/TBL 참조로 해석하고 서로 다른 폭·높이와
투명 영역을 가진 GRP 대표 프레임을 반환해야 한다. 한 맵에서 같은 그래픽을
여러 객체가 공유하므로 배치·중복 제거와 부분 fallback도 필요하다.

원시 `units.dat`, `flingy.dat`, `sprites.dat`, `images.dat`, `images.tbl` 또는
GRP를 Dart로 전달하면 신뢰하지 않는 바이너리 파싱과 게임 자산 복제가 Flutter
프로세스 안으로 들어온다. 반대로 객체마다 helper를 실행하면 CASC를 반복해서
열고 프로세스 수가 객체 수에 비례한다. 기존 타일 envelope에 가변 크기 엔트리를
추가하면 이미 배포한 포맷의 의미와 검증 규칙이 바뀐다.

## Decision

같은 `starcraft_data_helper.exe`에 독립 operation `renderObjectAtlas`를 추가한다.
한 요청은 현재 맵에서 필요한 고유 객체 그래픽을 최대 256개까지 배치하고,
helper는 로컬 CASC 안에서 참조를 해석해 클래식 GRP의 정적인 대표 프레임을
premultiplied RGBA8888로 만든다. 원시 게임 자산은 helper 밖으로 내보내지 않는다.

### 버전과 프로세스 경계

- 구현 릴리스에서 공용 wire protocol을 3, helper 버전을 0.4.0으로 올린다.
  `inspectInstallation`, `renderTileAtlas`, `renderObjectAtlas`의 요청·응답 모두
  같은 protocol/helper 버전을 사용하도록 한 변경에서 함께 이관한다.
- Application의 별도 `StarCraftObjectAtlasGateway` 포트 뒤에서 요청별 번들
  helper 프로세스를 실행한다. UI와 도메인은 프로세스, 파일 시스템, CascLib에
  의존하지 않는다.
- 실행 파일은 앱 번들의 검증된 절대 경로만 사용하며 셸과 `PATH` 검색을 쓰지
  않는다. helper는 사용자가 선택한 절대 로컬 설치를 읽기 전용으로 연다.
- 요청마다 앱 소유의 새 임시 디렉터리를 만들고 성공·실패·timeout·취소에서
  해당 디렉터리만 정리한다. helper는 요청 뒤 종료하고 CASC 핸들을 공유하지
  않는다.

### JSON 요청

stdin은 줄바꿈으로 끝나는 단일 UTF-8 JSON 레코드다.

```json
{
  "protocolVersion": 3,
  "requestId": "object-atlas-42",
  "operation": "renderObjectAtlas",
  "installationPath": "C:\\Program Files (x86)\\StarCraft",
  "outputFileName": "object-atlas.rgba",
  "tileset": 0,
  "framePolicy": "firstFrame",
  "objects": [
    {"kind": "unit", "id": 0, "playerColor": 0, "direction": 0},
    {"kind": "sprite", "id": 130, "playerColor": null, "direction": 0}
  ]
}
```

- `tileset`은 CHK `ERA`의 low 3 bits와 같은 0~7 enum이다. 클래식 GRP의
  인덱스 16~255를 RGBA로 바꾸는 기본 팔레트는 해당 타일셋 WPE에서 읽으므로
  추측하거나 설치 기본값으로 대체하지 않는다.
- `objects`는 1~256개다. `kind`는 `unit` 또는 `sprite`, `id`는 `u16`이다.
  `THG2`에서 `Draw as sprite` 비트가 있으면 `sprite`, 없으면 `unit`을 사용한다.
- `playerColor`는 0~7 또는 `null`이다. Application은 owner 0~7만 같은 색으로
  변환하고 나머지는 `null`로 요청한다. `null`은 선택한 타일셋 WPE의 기본색을
  그대로 사용한다. 0~7은 `game\\tunit.pcx`에서 얻은 해당 player gradient로
  GRP 팔레트 인덱스 8~15만 치환하고 나머지는 WPE 색을 유지한다.
- 첫 구현의 `framePolicy`는 `firstFrame`, `direction`은 0만 허용한다. 필드는
  캐시 키와 후속 방향 정책을 명시하기 위해 처음부터 포함하지만 지원하지 않는
  값은 조용히 무시하지 않고 protocol 오류로 거부한다.
- 객체 키는 `kind`(`unit` 먼저), `id`, `playerColor`(`null`은 255),
  `direction` 순으로 엄격히 증가해야 한다. helper와 Dart가 중복·비정렬 요청을
  모두 거부한다.
- CASC 내부 경로나 임의 출력 경로는 요청에 넣을 수 없다. 출력 파일명은
  `object-atlas.rgba`로 고정한다.

### 참조 해석과 부분 fallback

- `unit`은 `units.dat → flingy.dat → sprites.dat → images.dat → images.tbl →
  GRP`, `sprite`는 `sprites.dat → images.dat → images.tbl → GRP` 순으로
  해석한다. 각 레코드 길이, ID, 중간 참조, TBL offset·NUL 종료와 정규화된
  상대 경로를 접근 전에 검증한다.
- `images.tbl` 결과는 검증된 table에서 읽은 `.grp` 확장자의 상대 CASC 경로만
  허용하며 절대 경로, 상위 경로 이동, 빈 세그먼트와 NUL 미종료를 거부한다.
  실제 GRP는 요청에서 도달한 정규화 경로만 strict-read한다.
- GRP header, frame table, 행 offset과 모든 RLE run이 파일 범위 안인지 확인한
  뒤 frame 0을 투명한 논리 canvas에 합성한다. 픽셀은 alpha 0 또는 255의
  premultiplied RGBA8888이고 player-color 팔레트 변환은 helper에서만 수행한다.
- 공용 DAT/TBL이 누락·손상되면 전체 요청을 실패시킨다. 개별 ID가 범위 밖이거나
  경로·GRP·프레임을 지원하지 않으면 해당 키만 `unsupportedObjects`에 넣고
  나머지 객체를 계속 렌더한다. 성공 엔트리와 unsupported 엔트리의 합집합은
  요청 키와 정확히 같아야 한다.
- 자동 복구, 다른 ID·경로·프레임 추측, 대체 스킨 검색은 하지 않는다. 실패한
  객체는 캔버스의 기존 위치 마커와 Problems 진단으로 대체한다.

### JSON 성공 응답

stdout은 JSON 한 줄만 사용한다. 공통 metadata 외에 설치 제품·빌드,
strict-read한 자산 수·전체 바이트, 출력 파일 metadata와 부분 실패를 포함한다.

```json
{
  "protocolVersion": 3,
  "requestId": "object-atlas-42",
  "operation": "renderObjectAtlas",
  "helperVersion": "0.4.0",
  "cascLibRevision": "4971d363e665551ac4142f541e5f2d71f1cda653",
  "status": "success",
  "installation": {"path": "...", "storageProduct": "s1", "storageBuildNumber": 13515},
  "assets": {"readCount": 9, "totalBytes": 89000},
  "atlas": {"fileName": "object-atlas.rgba", "fileBytes": 42000, "formatVersion": 1, "entryCount": 1, "tileset": 0},
  "unsupportedObjects": [
    {"kind": "sprite", "id": 130, "playerColor": null, "direction": 0, "code": "SC_CASC_OBJECT_GRP_MISSING"}
  ]
}
```

오류 응답은 기존 `status=error` envelope의 `code`, `message`, `stage`,
`nativeError`를 유지한다. 로그에는 요청의 개인 설치 경로, CASC 원시 바이트,
팔레트 또는 RGBA를 기록하지 않는다.

### Binary envelope

helper는 작업 디렉터리에 부분 파일을 만든 뒤 flush하고 고정 최종 이름으로만
원자적 승격한다. 모든 정수는 little-endian이다.

32바이트 header:

| Offset | 크기 | 의미 |
| ---: | ---: | --- |
| 0 | 8 | magic `SCORGBA\0` |
| 8 | 2 | format version `1` |
| 10 | 2 | entry 크기 `32` |
| 12 | 4 | 성공 entry 수 |
| 16 | 4 | entry table 바이트 수 |
| 20 | 4 | pixel 영역 바이트 수 |
| 24 | 4 | flags, 현재 `0` |
| 28 | 4 | reserved, 반드시 `0` |

각 32바이트 entry:

| Offset | 크기 | 의미 |
| ---: | ---: | --- |
| 0 | 1 | kind: unit `0`, sprite `1` |
| 1 | 1 | player color `0..7`, neutral `255` |
| 2 | 1 | direction, 현재 `0` |
| 3 | 1 | flags, 현재 `0` |
| 4 | 2 | 요청 object ID |
| 6 | 2 | 해석된 sprite ID |
| 8 | 2 | 해석된 image ID |
| 10 | 2 | RGBA canvas width |
| 12 | 2 | RGBA canvas height |
| 14 | 2 | map 좌표 기준 anchor X, signed |
| 16 | 2 | map 좌표 기준 anchor Y, signed |
| 18 | 2 | frame index, 현재 `0` |
| 20 | 4 | pixel 영역 시작 기준 offset |
| 24 | 4 | RGBA byte length |
| 28 | 4 | reserved, 반드시 `0` |

성공 entry는 요청과 같은 키 순서이며 pixel 블록은 겹치거나 빈틈 없이 연속한다.
`pixel length = width × height × 4`이고 실제 배치는
`(mapX - anchorX, mapY - anchorY)`를 좌상단으로 사용한다. 빈 결과도 정상
header를 가지며 모든 요청 키가 `unsupportedObjects`에 있어야 한다.

Dart 어댑터는 helper 종료 코드와 JSON metadata, 요청한 tileset, 실제 일반 파일,
magic/version, reserved, entry 순서와 요청 포함 관계, 숫자 overflow, table/pixel 길이,
offset의 연속성, 성공/unsupported의 정확한 분할을 모두 교차 검증한 뒤에만
RGBA를 채택한다. link/reparse point, 기존 파일, 추가 trailing bytes와 중복
키를 거부한다.

### 상한과 수명

- stdin JSON 64 KiB, request ID 128 bytes, stdout/stderr 각각 256 KiB,
  기본 timeout 30초를 적용한다.
- CASC 원본은 개별 64 MiB, 요청 전체 strict-read 256 MiB를 넘지 않는다.
- GRP 논리 canvas는 각 축 1~1,024px, 한 프레임 최대 4 MiB다. 픽셀 수와
  곱셈은 할당 전에 overflow를 검사한다.
- binary envelope는 header와 entry table을 포함해 최대 32 MiB다. 요청이
  상한을 넘을 것으로 확인되면 일부 결과를 자르지 않고 전체 요청을 안정적인
  크기 오류로 실패시킨다. Application은 결정적인 키 순서로 더 작은 배치로
  재요청할 수 있다.
- RGBA 파일은 검증·`ui.Image` 생성 직후 삭제하고 CPU 버퍼도 유지하지 않는다.
  디스크 영구 cache와 이미지 내보내기는 만들지 않는다. Presentation LRU는
  별도 객체 이미지 예산을 가지며 퇴출·세션 전환·dispose에서 이미지를 해제한다.
- timeout 또는 취소는 operation ID가 소유한 helper 프로세스 트리만 종료한다.
  늦게 끝난 generation은 채택하지 않고 이미 만든 이미지도 즉시 dispose한다.

### 안정적인 진단 분류

구현은 최소한 protocol/version/operation/input/output, CASC open/read,
metadata missing/invalid, reference out-of-range, TBL path invalid, GRP
missing/invalid/unsupported/too-large, envelope write/promote, timeout/cancel과
response validation을 서로 구분한다. 세부 코드는 `SC_CASC_OBJECT_*` 접두사를
사용하며 모든 객체 렌더 진단은 맵 편집과 Save As에 비차단이다.

## Alternatives

### 객체마다 한 PNG 파일 출력

Flutter에서 읽기 쉽지만 최대 256개 파일의 생성·검증·정리와 PNG decoder 비용이
생기고 파일 누락·이름 충돌 표면이 커진다. 하나의 길이 제한 binary envelope가
완전성과 수명을 더 쉽게 검증하므로 채택하지 않는다.

### 타일 아틀라스 envelope 확장

기존 포맷은 고정 32×32와 raw `u16` 키를 전제로 한다. 가변 크기, anchor,
unit/sprite 키를 추가하면 기존 parser가 같은 magic/version을 다르게 해석할
수 있으므로 별도 operation과 magic을 사용한다.

### 원시 DAT/TBL/GRP를 Dart로 전달

순수 Dart 구현은 편리하지만 네이티브 프로세스 격리와 게임 원시 자산 비노출
결정을 깨고 손상 바이너리가 UI 프로세스 메모리를 직접 공격한다. 채택하지 않는다.

### 첫 단계부터 Remastered ANIM 지원

HD/HD2/SD 연결, 다중 레이어와 훨씬 큰 자산 상한을 동시에 설계해야 한다.
클래식 GRP fallback을 먼저 검증하고 ANIM은 별도 ADR/포맷 버전으로 확장한다.

## Consequences

장점:

- 객체 ID 해석과 위험한 바이너리 decoder가 Flutter 프로세스 밖에 남는다.
- 하나의 제한된 요청으로 중복 그래픽을 제거하고 부분 실패를 위치 마커로
  안전하게 대체할 수 있다.
- 가변 크기·anchor·player color가 명시된 envelope라 캔버스와 캐시가 원시
  게임 포맷을 알 필요가 없다.

비용:

- protocol 3 이관 때 설치 검사와 기존 타일 어댑터까지 같은 버전으로 갱신해야
  한다.
- helper와 Dart 양쪽에 가변 entry 검증, 배치 분할, 부분 fallback과 별도 이미지
  LRU가 필요하다.
- frame 0은 모든 객체의 게임 내 초기 모습을 완전히 재현하지 않으며 방향과
  애니메이션은 후속 정책이 필요하다.

## Validation

- 자체 제작 DAT/TBL/GRP 바이트로 unit/sprite 참조, frame 0의 투명·literal·solid
  RLE, WPE 기본색, player color 8색 치환, canvas와 anchor를 네이티브 단위
  테스트한다.
- 절단 header/table/row, overflow offset/run, 비종료 TBL, 경로 탈출, 순환·범위
  밖 참조, 1,024px/4 MiB/32 MiB 상한과 기존·외부 출력 거부를 검증한다.
- Dart 가짜 helper 테스트는 protocol/helper/request/path 불일치, malformed JSON,
  대량 출력, timeout·취소, link, header/entry/pixel 불일치, 성공과 unsupported의
  중복·누락을 검증한다.
- Application/Widget 테스트는 배치, cache identity, player color 구분, 부분 실패,
  scene key, anchor image, 선택 이동, marker fallback, generation 전환과 모든
  `ui.Image.dispose()` 경로를 검증한다.
- 로컬 SC:R 선택적 스모크는 재배포하지 않는 대표 unit/sprite의 크기·anchor와
  색을 Chkdraft 또는 게임 화면과 비교한다.

## References

- [객체 그래픽 자산 조사](../research/OBJECT_GRAPHICS_ASSETS.md)
- [ADR-0005](0005-casclib-helper-process.md)
- [ADR-0006](0006-request-scoped-tile-atlas-cache.md)
- [CascLib API header](https://github.com/ladislav-zezula/CascLib/blob/4971d363e665551ac4142f541e5f2d71f1cda653/src/CascLib.h)
- [Chkdraft 객체 렌더 참조 해석](https://github.com/TheNitesWhoSay/Chkdraft/tree/master/src/mapping_core/render)
