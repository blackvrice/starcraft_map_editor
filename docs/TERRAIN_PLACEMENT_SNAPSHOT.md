# 배치용 CV5/VF4 지형 자료

후속으로 [UNIT 지형 검사 연결](UNIT_TERRAIN_PLACEMENT_POLICY.md)을 구현했다.
아래는 자료·순수 판정 단계의 당시 범위와 검증 기록이며 현행 UI/정책은 후속 문서를 따른다.

2026-10-14. FR-218/219, EP1의 지형 자료·순수 footprint 판정 단위다.
**읽기 전용 조회와 판정만 구현**했다. 실제 카탈로그 배치/ghost/정상·자유 설정에
연결하지 않았고 현재 앱의 배치 허용/거절·기존 ISOM·저장 동작은 바꾸지 않는다.

## 1. 실행 계획과 소스 분석

1. 기존 ISOM 연결 자료와 graphics atlas를 조사하고 이동/건설 자료와 구분한다.
2. 고정 primary source로 CV5/VF4의 단위·인덱스·의미를 확인한다.
3. 숫자만 읽는 포트/새 helper 연산/엄격한 decoder와 출처 revision을 구현한다.
4. 순수 footprint 검사에 unknown/타일셋/맵 경계/예산 상한을 적용한다.
5. 합성/native/프로세스/기존 ISOM 회귀·실제8타일셋·전체 게이트를 기록한다.

근거는 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[CV5 건설 flag](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L2876-L2899),
[VF4와 타일 인덱스](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L3743-L3767)다.
CV5 group은52byte, member16개의 u16 megatile reference는 offset20이다.
raw tile의 group=raw/16, member=raw&15다. CV5 flags의 bit7이 꺼져 있으면
기본 buildable이다. VF4는 megatile별32byte, 행 우선4×4 minitile의 u16 flags다.
각8px minitile의 bit0만 walkable이며 CV5의 walkable flag나 그림 색으로 대체하지 않는다.
같은 commit의 [지형 로드](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.cpp#L2007-L2010)도
확인했다. CV5 전체 group을 그대로 복사하는 자료 경계와 대조했으며 두다드의
다른 header word를 ISOM 모양이나 새 건설 규칙으로 해석하지 않는다.

기존 `readTerrainConnections` v2는 CV5와 렌더 자료4종의 연결/ISOM 경계용이다.
이를 VF4가 포함된 자료라고 간주하거나 버전을 바꾸지 않았다. 새
`readTerrainPlacement` v1는 CV5/VF4 **2종만** 같은 로컬 CASC에서 읽는다.

## 2. 구현과 계층 계약

| 계층/항목 | 계약 |
| --- | --- |
| 포트 | `TerrainPlacementSnapshotGateway.readPlacement`, UI의 I/O/파서 호출 없음 |
| native | 기존 bounded CASC reader/설치 검증 재사용, CV5/VF4만 읽음 |
| 새 연산 | `readTerrainPlacement`, protocol3/helper0.13.0의 additive 연산. 과거 helper는 unsupported로 실패 |
| native 크기 | CV5 1~4096group×52byte, VF4 1~65536megatile×32byte, 빈/잘린/초과 파일 거절 |
| 전달 | `groupBuildable` boolean 배열, `megaTileReferences` group×16 u16 배열, `walkableMasks` u16 배열 |
| mask | VF4 bit0을 (row*4+column) 비트로 투영. 0은 확인된 이동 불가, 누락과 다름 |
| 미지 reference | 원래 숫자 보존, VF4 범위 밖이면 조회/판정 unavailable. 0대입 없음 |
| 출처 | tileset·helper/CascLib revision·product/build·CV5/VF4 path/byteLength/SHA-256 |
| decoder | 정확한 request/설치/연산/버전·정수/boolean·자산 이름/stride/상한·배열 coverage 검사 |
| revision | canonical facts+출처 hash. request ID/설치 폴더는 제외, 사실/자산/build 변경은 추적 |
| transport | 기존 프로세스 경계 공유: 기본30초/출력2MiB·bounded stdout/stderr·취소·중복 ID·임시 폴더 정리 |
| 기존 ISOM | 기존 포트/결과 형식/v2 decoder 유지, 내부 transport만 공유 |
| domain | `TerrainPlacementSnapshot`, Flutter/FS/FFI/프로세스 의존 없음, 입력/nested 배열 고정 |

raw 자산/추출 이미지/새 맵 파일은 fixture나 배포물에 넣지 않는다. SHA-256와 파생
숫자 metadata만 전달한다. stdout은 원시 자산이 아니라 bounded JSON 응답이다.
helper가 제공한 hash를 신뢰 경계 안의 provenance로 사용하며 외부 서명 검증으로
표현하지 않는다. `.scm/.scx`·unknown CHK·원시 문자열·ISOM 데이터는 수정하지 않는다.

## 3. 순수 footprint 판정

입력은 현재 typed MTXM grid, 그 맵의 tileset, 검증된 collision bounds와
`requireBuildable`이다. record 중심을 알아서 스냅하거나 StarEdit 박스를 collision
크기로 대입하지 않는다. 빌딩/공중/스프라이트 예외의 선택은 후속 정책의 책임이다.

- DIM/MTXM grid 불명확·타일셋 불일치·미지 group/member/megatile은 unavailable이다.
- 닫힌 픽셀 영역으로 겹치는 타일과 minitile만 검사한다. 맵의 마지막 legal pixel은
  `width*32-1, height*32-1`이며 그 밖은 outOfBounds다. half-open StarEdit 박스의
  경계와 다르다. clamp하거나 맵 밖 영역을 안전한 지형으로 바꾸지 않는다.
- 기본 이동 검사는 VF4다. `requireBuildable=true`면 추가로 CV5 bit7도 검사한다.
  true를 전체 게임 건설 조건/전력/크립 확인으로 해석하지 않는다.
- 우선순위는 grid/타일셋 확인 → 전체 경계 → 검사 예산 → 미지 자료 →
  unbuildable → unwalkable → clear다. 알려진 장애물만 보고 미지 자료를 숨기지 않는다.
- 동기 검사 상한은 **4096 intersected tiles**다. 초과는 unavailable이며 게임 크기
  규칙이 아니다. 지원 경계64×64와 초과65×65를 테스트한다.

후속 실제 배치 연결은 현재 document/revision·최종 정렬 좌표·UNIT metadata의
출처와 새 지형 source를 일치시켜야 한다. 자유 배치가 지형 검사를 생략하더라도
구조/ID/레코드/u16·공통 경계·두다드 recipe 안전 검사는 유지한다.

## 4. 요구사항·테스트 체크리스트

| 시나리오 | 구현/증거 |
| --- | --- |
| CV5/VF4 별도 읽기·4×4 row-major mask | native 합성값/stride/16bits/최종ID와 domain16미니타일 회귀 |
| 건설/이동 독립·CV5 walking bit 대체 금지 | native/domain 회귀 |
| group/member/reference/0-mask·unknown | 숫자 보존, 알려진 막힘/미지 자료 구분 |
| 닫힌 footprint·8px/32px 경계·여러 타일·맵 끝 | domain point/교차/외부 영역 회귀 |
| 타일셋·DIM 중복/누락·자원 상한 | unavailable/outOfBounds, 추측/무제한 스캔 없음 |
| 버전/자산/형식/길이/range/coverage·revision | decoder mutation 회귀, transport 위치 독립 |
| 최대4096×16 reference/65536mask 응답 | fake process에서 이전256KiB 초과와2MiB 상한 검증 |
| timeout/overflow/start failure/cancel/중복 ID | 새 연산·기존 ISOM transport 회귀 |
| 기존 ISOM 자료 | 실제8타일셋의 CV5 hash/모든 reference/flags와 대조 |
| 읽기 불변·반복 revision | 합성/실제 CHK 바이트 불변과 native input 불변 |
| 배치 버튼/ghost/정상·자유 정책/전력/크립/EUD | 미연결/미검증, 이번 완료 범위 아님 |
| SC:R 실제 게임·외부 에디터 | 별도 인수 대기 |

## 5. 최적화와 주석

그림/VX4/VR4/WPE/DDData를 읽거나 bitmap을 할당하지 않는다. 기존 CASC Reader와
검증된 해시 함수를 재사용한다. 최악의 JSON 배열 크기도 파생 snapshot의 고정
상한으로 제한하고 프로세스 capture에서2MiB를 다시 검사한다. 지형 판정은 전체
맵이 아니라 footprint만 O(겹친 tile×최대16mini)로 검사하며4096tile 상한이 있다.
성능/FPS/메모리 개선 수치는 측정하지 않았다. source/revision별 앱 cache는 실제
배치 연결 단계에 구현한다. 유효 크기를 넘는 자료를 추측하여 잘라 저장하지 않는다.
byte offset/별도VF4/row-major mask·unknown/닫힌 경계·자원 예산에 주석을 남겼다.

## 6. 실행·실패·결과 분석

원시 로그: ignored `.dart_tool/terrain_placement_*.log`. SDK Flutter3.47.5 stable/
Dart3.13.4이며 기준3.44.8/3.12 재검증은 남는다.

- 초기 native build: PATH의 CLion CMake4.3과 기존 VS3.31 생성 모듈이 섞여
  `No preprocessor test for Renesas` configure 실패. 소스 오류가 아니다.
  기존 캐시에 맞는 VS CMake의 절대 경로로 다시 빌드해 성공했다. 로그는
  `terrain_placement_native_build.log`, `terrain_placement_native_retry.log`다.
- initial analyze: unbraced-if lint5개를 수정한 뒤 No issues를 확인했다.
- initial focused:77통과/3실패. JSON 손상 fixture의 bool/int 리스트가 강한 타입이고
  reference 리스트가 fixed-length여서 입력 변형 단계에서 먼저 실패한 테스트 문제다.
  실제 JSON 구조와 맞는 dynamic/growable fixture로 수정해 focused80통과했다.
- 실제8타일셋: 새 snapshot/기존 ISOM gateway4테스트 통과. CV5 hash와 전체 group
  flags/reference, 반복 revision, 자체 제작1타일 CHK의 clear/blocked와 byte-exact를 확인했다.
- 실제 ISOM 선택 테스트의 helperVersion0.12.0 하드코딩은 현행0.13.0과 달랐다.
  새 연산에서 버전을 변경한 것이 아니며 structured JSON의 기존 protocol constant로
  기대값을 정정하고 실제 회귀를 통과했다.
- 검사 예산 추가 전 전체1327통과/54skip. 최종 상한/전체 결과는 아래 표에 기록한다.

신규 일반 테스트77개(domain31/decoder39/process7), 로컬 선택1개를 추가했다.
native fixture는 기존 테스트 target에 확장했고 실제 게임 원시 자료는 저장소에 넣지 않았다.

| 최종 검증 | 결과 |
| --- | --- |
| 검사 상한 domain | 30통과, `terrain_placement_budget.log` |
| `flutter analyze` | No issues, `terrain_placement_analyze_verified.log` |
| `flutter test --concurrency=4` | 1329통과/54skip, `terrain_placement_tests_verified.log` |
| `flutter build windows --debug` | 성공, `terrain_placement_windows_final.log` |
| Debug CTest | 7/7통과, native CV5/VF4 합성 포함 |
| 실제 로컬8타일셋/기존 ISOM | 4통과, `terrain_placement_local.log` |
| 전체 nonwrite format | 449파일 중 미수정 infrastructure3파일의 기존 차이로exit1 |
| 변경 Dart10파일 nonwrite format | 0변경, 통과 |
| Windows 직접 조작·SC:R 플레이·외부 에디터 | 미실행, 이번에 신규 UI/배치 연결 없음 |

기존 format 차이3개는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
사용자/기존 변경을 보존하기 위해 이번 작업에서 정규화하지 않았다.

다음 코드 단위: 이 포트를 PlacementCatalog에 공급하고 tileset/source/epoch별 조회
수명·새 지형 검사 체크박스·최종 좌표 preview/Apply·미확인 안내를 연결한다.
전체 정상/자유 모드·크립/전력/자원 거리·EUD 변경·게임 인수는 별도다.
