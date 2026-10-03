# 새 맵 생성 정책과 CHK 생성기

2026-10-03: 기본 생성은 검증된 평지 ISOM과 변형 타일이다. 단일 타일 모드는
명시적으로 선택하며, 좁은 창에서는 단계 메뉴가 상단으로 이동한다.
[사용자 흐름 수정·검증 기록](EDITOR_WORKFLOW_REPAIR.md)을 함께 따른다.

2026-09-29: New Map UI → 원본 없는 메모리 문서 → 신규 MPQ Save As → 재열기까지
연결했다. 기존 맵을 복제하지 않는다. 최종 helper의 native 테스트와 실제 MPQ
저장·재열기 검증을 통과했으며 실제 게임/외부 에디터 인수는 별도다.

## 사용 방법

1. **File → New Map…** 또는 **Ctrl+N**을 누른다.
2. 제목·설명, 가로/세로(32~256, 32의 배수), Human 수(1~8), 타일셋을 선택한다.
3. 기본 **지형** 모드에서 로컬 CV5로 검증된 지형 썸네일/종류 ID를 선택한다.
   같은 지형의 검증된 좌우 타일 pair와 변형 member로 ISOM/TILE/MTXM을 생성한다.
   기본 선택은 변형이 여러 개인 지형을 우선하며, 단일 변형 지형은 임의로 늘리지 않는다.
   **단일 타일** 모드에서는 기존 raw 타일 썸네일을 Previous/Next로 선택한다.
   설치·렌더 검증 실패 시 Settings에서 설치를 준비하고 다시 읽는다.
4. Create로 문서를 만든다. 기존 문서가 dirty면 Discard and create 확인이 필요하다.
   Keep current map/Cancel, 잘못된 입력, 문서·자산 변경은 기존 세션을 유지한다.
5. Save As로 새 `.scx` 경로를 선택한다. 성공 후 저장 경로·fingerprint가 있는
   일반 세션이 되고 Open Map으로 다시 열 수 있다. 생성만 하면 디스크 파일은 없다.

새 문서는 항상 미저장 상태이며 `sourcePath`와 `sourceFingerprint`는 모두 null이다.
가짜 경로/해시를 만들지 않는다. 기존 사운드는 없지만 Resources에서 가져온 보류
WAV는 첫 Save As에 함께 저장한다. EUD 프로젝트 연결/빌드는 먼저 맵을 저장해야 한다.
New Map과 Save As 후 이전 맵의 공통 Undo 기록은 초기화된다.

## 계층과 보호 경계

- `NewMapController`는 대화상자 시작 시 문서 snapshot과 최신 검증된 지형/타일 페이지를
  보관한다. 설치/페이지/문서 변경, 닫힌 컨트롤러, 미검증 타일은 생성에 사용할 수 없다.
- UI는 `TilePlacementCatalogLoader`를 통해 로컬 카탈로그·아틀라스 포트를 사용한다.
  UI에서 파일·CASC·MPQ를 직접 읽지 않는다. 썸네일/게임 자산을 저장소에 넣지 않는다.
- MPQ helper **0.5.0**, protocol 1의 `createScenario`는 `sourcePath` 키를 받지 않는다.
  `MapArchiveWriteRequest.sourcePath == null`인 경우에만 이 연산을 요청한다.
  기존 파일이 있으면 거부하고 CREATE_NEW로 임시 경로를 확보한 뒤 MPQ v1을 생성한다.
- Save As는 대상 확인 → 임시 MPQ 생성 → CHK 전체 바이트/보류 WAV 재검증 → 대상
  외부 변경·문서 snapshot 재확인 → 승격 → 저장 세션 채택 순서를 따른다.
  원본 없는 문서의 source fingerprint 조회는 생략하지만 출력 검증은 생략하지 않는다.
- 실패/취소 시 미저장 문서와 보류 리소스를 유지한다. 기존 목적지 교체는 기존
  Save As의 명시적 확인·해시·백업·복원 규칙을 따르며 입력 맵 덮어쓰기는 여전히 금지한다.

## 현재 구현

`NewMapOptions`와 `NewMapFactory`는 기존 맵·템플릿·파일 시스템 없이 새 CHK
문서를 만든다. 입력이나 생성이 실패하면 기존 문서를 변경하지 않는다. 생성된
섹션은 모두 dirty다. 성공한 저장 뒤 clean 상태로 전환하는 책임은
문서 세션에 있으며, 생성기가 디스크 파일이나 가짜 원본 경로를 만들지 않는다.

| 항목 | 최초 지원 정책 |
| --- | --- |
| 버전 | Brood War UMS, `TYPE=RAWB`, `VER=205`, `IVE2=11`, 출력 확장자 `.scx` |
| 크기 | 가로·세로 각각 32~256, 32의 배수; 기본 128×128; 직사각형 허용 |
| 타일셋 | 기존 `ChkTileset` 8종, 기본 Badlands |
| 초기 지형 | 기본: 검증된 평지 ISOM과 seed 기반 좌우 pair/member 변형; 단일 타일: 지정 raw 값으로 TILE/MTXM 채움 |
| 플레이어 | 앞에서부터 Human 1~8명, 기본 1명, 초기 종족 Terran; 나머지 비활성, P12 Neutral |
| 시작 위치 | 활성 플레이어마다 UNIT #214 한 개; 한 명이면 중앙, 여러 명이면 서로 다른 사분점/변 중간점 |
| 세력 | 전원 Force 1, 동맹·공동 승리·공유 시야·무작위 시작 옵션은 해제 |
| 안개 | MASK 각 바이트 `0xff`; 플레이어별 편집 도구는 후속 범위 |
| 트리거 | TRIG·MBRF는 빈 목록; 자원·승리·패배·건물·일꾼을 자동 추가하지 않음 |
| 문자열 | 제목·설명 UTF-8, 단일 STR; NUL 금지, 제목 공백만 금지, 65535바이트 초과 거부 |
| 로케이션 | 255개; ID 64 Anywhere만 맵 전체 픽셀 범위, 나머지는 비어 있음 |
| 유닛/비용 | UNIx·UPGx·TECx의 기본값 사용 flags=1; 비활성 사용자 override는 0 |
| 생산/연구 | PUNI 허용/상속=1, PUPx 시작 레벨=0/표준 최대 레벨, PTEx 표준 연구 상태와 플레이어 상속 |

초기 타일 번호의 숫자 범위와 로컬 게임 자산 검증은 별개다. 도메인 생성기는
0~65535만 검사한다. UI는 해당 타일셋의 CV5 범위·렌더 성공을 검증한
카탈로그 타일만 선택하도록 제한한다. 시작 위치의 좌표 범위·소유자·중복은
검사하지만 지형의 보행 가능성은 아직 보장하지 않는다.

지형 모드는 도메인 생성이 모두 성공한 뒤에만 세션을 채택한다. 검증된 로컬
catalog/tileset/shape/seed를 전달해야 하며 별도 raw member를 무작위로 추측하지 않는다.
단일 타일 모드는 ISOM을 생성하지 않는다. TILE은 생성 시 MTXM과 일치하지만,
기존 raw 브러시는 MTXM만 변경한다. 기존 맵을 정규화하거나 자동 복구하지 않는다.
외부 에디터/실제 게임의 지형 상호 운용 인수 완료를 뜻하지 않는다.

## 생성 섹션

각 섹션은 정확히 한 번, 아래 순서로 생성한다. 이 목록은 이 제품의 생성
프로파일이며 모든 게임 버전의 최소 필수 섹션 목록이라는 뜻은 아니다.

```text
TYPE VER  IVE2 VCOD IOWN OWNR ERA  DIM  SIDE MTXM PUNI UNIT
TILE DD2  THG2 MASK STR  UPRP UPUS MRGN TRIG MBRF SPRP FORC
WAV  SWNM COLR PUPx PTEx UNIx UPGx TECx
```

- VCOD 1040바이트는 기존 자체 제작 게임 검증 맵의 데이터와 동일하다.
  `default_validation_code.dart`를 fixture 도구와 제품 생성기가 공유한다.
- MTXM/TILE은 폭×높이×2, MASK는 폭×높이, UNIT은 플레이어 수×36,
  MRGN은 255×20바이트다. 지형 모드는 ISOM을 마지막에 추가한다.
  단일 타일 모드와 구버전 설정 대체 섹션은 기존 정책을 유지한다.
- STR의 ID 1은 제목, 2는 설명, 3은 Anywhere, 4~7은 세력 이름이다.
  빈 설명은 SPRP에서 ID 0을 참조한다. 설명을 비워도 이후 문자열 ID는 안정적이다.
- PUNI 5700, PUPx 2318, PTEx 1672, UNIx 4168, UPGx 794, TECx 396바이트.
- UPRP 1280, UPUS 64, WAV 2048, SWNM 1024바이트는 전부 0으로 시작한다.
- 출력은 `RawChkEncoder`로 인코딩하고 `RawChkParser` 및 기존 typed decoder로
  다시 읽을 수 있다. VCOD golden SHA-256과 모든 생성 결과의 바이트 왕복을 검증한다.

## 남은 인수와 제한

실제 SC:R에서 로비/시작 위치/플레이어/타일 표시와 외부 에디터 왕복을 확인해야
한다. 기본 트리거가 비어 있으므로 자동 자원·승패·일꾼 생성은 없다. 신규 평지의
보행 가능성·게임 실행 성공은 보장하지 않는다. 이후 경계·높이·경사로 편집은
[ISOM 브러시](ISOM_BRUSHES.md)를 사용한다.
기존 맵 resize와 타일셋 변환은 이 대화상자의 기능이 아니다.

## 조사 근거와 제품 결정

고정된 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[CHK 구조 및 기본값](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L1249-L1600)과
[새 시나리오 생성](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/scenario.cpp#L526-L648)을 대조했다.
섹션 구조, VCOD, 업그레이드·테크 기본 상태, Anywhere ID의 근거로 사용했다.
최초 지원 크기·플레이어·빈 트리거는 이 제품의 범위 결정이다. 최초 raw 전용 정책은
2026-10-03 지형 기본 생성으로 확대했으며 원시 바이트 보존 경계는 유지한다.
구현 코드를 복사하거나 게임 DAT/CV5 원시 자산을 포함하지 않았다.

## 검증

`test/domain/chk/new_map_factory_test.dart`에서 결정성, dirty 상태, 바이트 왕복,
기존 설정 편집기로의 읽기, 문자열·객체 참조, 플레이어 시작 위치, 8개 타일셋,
직사각형과 최소/최대 크기, 잘못된 입력/초과 문자열 거부를 검증한다.
UI/세션·native 생성의 후속 검증은 아래 기록이며 실제 게임 검증은 별도다.

2026-09-29 최초 도메인 단계 실행 결과: 생성기 10개 포함 전체 774개 통과(선택 환경 27개 skip),
`flutter analyze` 통과. Flutter 3.47.2 / Dart 3.13.2로 검증했으며 기준 SDK는
3.44.8 / 3.12다. 변경 파일 format은 통과했고 전체 format은 기존 무관한
infrastructure 테스트 4개의 차이로 실패했다.

### UI·신규 MPQ 통합 검증 (2026-09-29)

- 생성 컨트롤러: 미검증/이전 페이지/설치 변경/늦은 결과/폐기된 선택 거부, 원본 I/O 없음.
- 위젯: 타일 선택 전 Create 비활성, 미저장 교체 확인의 취소/수락과 창 닫기.
- Save As: source fingerprint 조회 생략, 성공 시 저장 세션 채택, 쓰기/재검증/
  승격/확장자 실패 시 미저장 상태 보존.
- 초기 0.5.0 빌드의 실제 MPQ 통합 테스트 1개 통과: 8개 타일셋·32×64·8명·
  한글 경로·자체 제작 PCM WAV, 취소/재열기·CHK 전체 일치·기존 출력 바이트 보존.
- 전체 Dart 테스트 784개 통과/28개 선택 환경 skip. analyze 무이슈,
  변경 Dart 16개 format 통과. 전체 format은 기존 무관한 infrastructure 테스트
  4개의 차이로 미통과다. Flutter 3.47.2/Dart 3.13.2 사용(기준 3.44.8/3.12 별도).
- 최종 Windows debug 빌드와 앱 4초 시작 통과. native 아카이브 테스트 타깃도
  명시적 빌드 성공. 기존 CascLib CMake 최소 버전 경고는 남아 있다.
- 최종 native CTest 5개 모두 통과. 최종 helper의 신규/기존 MPQ 저장·재열기와
  번들 helper 통합 테스트 5개 모두 통과했다.
- 처음에는 Windows 앱 제어 정책(4551)으로 새 실행 파일이 차단되었다.
  사용자가 Smart App Control 설정을 변경했다고 알린 후 동일한 최종 바이너리로
  위 검증을 재실행해 통과했다. 에이전트가 보안 설정을 변경하지는 않았다.

실제 helper 검증 재현 명령:

```powershell
ctest --test-dir build/windows/x64 -C Debug --output-on-failure
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
$env:MAP_ARCHIVE_TEST_MAP = (Resolve-Path 'test/fixtures/maps/generated/minimal-self-authored.scx').Path
flutter test test/integration/new_map_roundtrip_test.dart test/integration/object_editing_roundtrip_test.dart test/infrastructure/bundled_map_archive_helper_test.dart
```

게임/외부 에디터 실행과 정상 로컬 자산으로 새 대화상자를 직접 조작하는 검증은
이번에 수행하지 않았다. 초기 타일을 선택할 수 있다는 사실이 보행 가능성·ISOM
상호 운용·플레이 가능한 승패/자원 트리거를 자동 보장하지 않는다.
