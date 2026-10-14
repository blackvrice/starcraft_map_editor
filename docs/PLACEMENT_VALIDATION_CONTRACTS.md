# 배치 검증 자료와 정책 계약

2026-10-14. FR-218/219, EP1의 다음 제한 구현이다. **충돌 자료 조회와 순수
기하 계산만 구현**했으며, 실제 배치 충돌 차단·정상/자유 모드 UI·지형 검사는
아직 연결하지 않았다. 기존 배치 허용/거절 동작과 저장 바이트는 바꾸지 않는다.

같은 날 후속 [UNIT 겹침 배치 정책](UNIT_OVERLAP_POLICY.md)에서 실제 카탈로그 UNIT
겹침 검사를 선택적 체크박스에 연결했다. 아래는 첫 자료 계약 단계의 기록이며
현재 정책 연결·검증 범위는 후속 문서를 따른다. 전체 정상/지형/게임 검증은 여전히 미완료다.
후속 [CV5/VF4 파생 자료·순수 footprint](TERRAIN_PLACEMENT_SNAPSHOT.md)도 구현했으며,
실제 지형 배치 정책/UI 연결은 아직 남았다. 아래 지형 snapshot 단락은 그 첫 설계 기록이다.

## 1. 실행 계획과 소스 분석

1. 고정 primary source에서 충돌 영역과 건물 타일 박스를 구분한다.
2. 로컬 classic DAT의 충돌 영역/Flyer를 선택적 버전 필드로 전달한다.
3. 순수 bounds/겹침과 비행 분류를 구현하고 누락/손상 계약을 검사한다.
4. 정상/자유 검증 지원표와 지형 자료 계약을 확정하고 후속 연결을 분리한다.
5. 합성/native/process/실제 로컬 자료/전체 회귀/Windows 빌드를 기록한다.

Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[DAT 구조](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L508-L577)와
[배치 검사](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L2189-L2355)를 확인했다.
`unitExtent`는 중심에서 left/up/right/down으로 뻗는 u16 값 네 개다.
StarEdit 박스/Addon 배열 뒤 offset `11284 + 228*4 + 96*4 = 12580`에서
ID별8byte를 읽는다. Flyer는 flags bit2이며 FlyingBuilding과 별개다.
참조 구현은 닫힌 픽셀 영역의 겹침, 비행 중 건물, CV5/VF4와 자원 거리 검사를
각각 구분한다. 이 구현을 게임 엔진의 모든 건설 규칙이라고 간주하지 않는다.

## 2. 구현된 자료 계약

| 항목 | 현재 계약 |
| --- | --- |
| native 입력 | classic units.dat 정확히19876byte, ID0~227만. 다른 형식은 추측하지 않음 |
| 전달 | `capability.collisionProfile={version:1,left,up,right,down,isFlyer}` |
| offset | 각0~65535px. 0도 확인된 값이며 null/누락과 다름 |
| 버전 | protocol3/helper0.13.0에 additive optional 필드. 기존 버전/원시 로그 유지 |
| old/null | 카탈로그 사용 가능, profile=null. 건물 박스에서 충돌 크기를 추정하지 않음 |
| 손상 | 미지원 version/비정수/누락 축/범위 이탈/비boolean/비object는 gateway invalidResponse |
| domain | `UnitCollisionProfile`/`UnitCollisionBounds`, Flutter/I/O/CHK/프로세스 의존 없음 |
| geometry | 중심에서 비대칭 offset을 계산, clamp/타일 반올림 없음. 닿는 변/꼭짓점도 겹침 |
| 비행 | Flyer 또는 Building+FlyingBuilding+inTransit. profile 미확인은 null |
| 비행 전제 | 호출자가 해당 UNIT 상태의 valid flags/지원 여부를 검사해야 함. 원시 비트만 추측 적용하지 않음 |
| 출처 | 응답의 설치/product/build/helperVersion 로그와 결합한 로컬 기본 자료. EUD/런타임 변경 자료 아님 |
| 사용 범위 | 카탈로그 Unit 및 이를 재사용하는 unit-sprite 메타데이터. pure Sprite에 억지 유닛 영역 부여 안 함 |

이번 단계는 조회와 계산만 추가한다. 기존 객체/unknown CHK/원본 맵/Undo 기록과
카탈로그 factory defaults는 변경하지 않는다. 새 실제 자산/추출 그림 fixture도 없다.

## 3. 정상/자유 정책 지원표

아래 정상/자유 열은 **후속 정책 계약**이다. 현재 UI에 이 두 모드가 있다는 뜻이 아니다.
검사 결과는 `통과/거절/검증 불가/대상 아님/정책으로 생략`을 구분해야 한다.
검증 불가를 통과로 바꾸지 않으며 기존 맵의 겹친 객체를 자동 삭제하지 않는다.

| 검사 | 현재 구현 | 정상 정책 계약 | 자유 정책 계약 |
| --- | --- | --- | --- |
| 편집 가능 세션/레이어/history/섹션 | 공통 preview/Apply 구현 | 필수 | 필수 |
| 중심/u16/ID/owner/관계/subunit/레코드 | 공통 factory 구현 | 필수 | 필수 |
| 건물 타일 박스 정렬/전체 경계 | 별도 선택 설정 구현 | 검증된 자료만 | 설정을 켰으면 동일 검사 |
| 두다드 footprint/overlay/tileset/기반 지형 | 공통 recipe 검증 구현 | 필수 | 필수 |
| UNIT 기존 객체와 겹침 | 자료/순수 geometry만 구현, 배치 연결 미완료 | 지상/공중 분리, 미확인 객체 자료는 검증 불가 | 명시적으로 생략 가능, 구조 검사는 유지 |
| THG2 unit-sprite의 게임 충돌 | 미검증 | UNIT 규칙을 무조건 재사용하지 않음 | 레코드 안전 검사 유지 |
| 지상 이동/건물 건설 지형 | 계약만, 자료 전달/검사 미완료 | CV5/VF4의 검증된 footprint만 | 정책으로 생략 가능, 두다드 검사는 유지 |
| 자원/기지 거리 | 미구현 | 자료/예외 확인 후 별도 검사 | 명시적 생략 가능 |
| 전력/크립 | 미구현 | 자료·상태·게임 의미 미확인 표시 | 생략 상태를 표시, 검증 통과로 표시 안 함 |
| EUD 변경 DAT/런타임 크기 | 미구현 | 해당 revision 자료 없으면 검증 불가 | 로컬 기본 자료를 변경된 게임 값으로 표시 안 함 |
| 게임 건설 가능성/SC:R/외부 에디터 | 별도 인수 대기 | 에디터 검사가 게임 보증을 대체하지 않음 | 동일 |

## 4. 후속 지형 자료 계약

기존 타일 atlas는 RGBA 렌더 자료이며 이동/건설 가능성의 증거가 아니다.
`MTXM`의 group/member를 해당 tileset의 CV5 megatile과 VF4의16개 minitile
flags로 연결하는 read-only snapshot이 필요하다. UI가 바이너리를 해석하지 않는다.

- snapshot version, tileset, 설치/product/build, 원본 자산의 연결 식별을 검증한다.
- 건설 가능성(CV5)과 8px minitile 이동 가능성(VF4)을 별도 boolean으로 전달한다.
- 없는 group/member/megatile, 잘린 배열, 불명확한 DIM/MTXM, revision 불일치는
  '검증 불가'다. RGBA 색상/ISOM 이름에서 추정하지 않는다.
- 공급 snapshot은 CHK를 수정하지 않는다. 상한/출력 예산·페이지 범위·캐시 수명은
  실제 크기를 확인한 다음 포트 확장에 명시한다. 현재 클래스가 존재한다고 표기하지 않는다.
- hover와 Apply는 같은 현재 문서/revision의 검사 경로를 사용한다. 점 스냅을
  켠 경우 최종 정렬 좌표의 충돌을 검사해야 하며 원시 hover 결과를 승인으로 재사용하지 않는다.

다음 코드 단위: 충돌 profile의 전체 유닛 metadata snapshot을 기존 UNIT와 결합해
검증 불가/겹침/비겹침을 반환하는 read-only 검사와 명시적 겹침 허용 정책을 연결한다.
그 뒤 지형 snapshot/footprint 검사, 정상 모드의 지원표 UI와 게임/외부 인수를 진행한다.

## 5. 최적화와 주석

native는 이미 읽은 DAT buffer에서 ID별 네 u16만 추가로 읽는다. 별도 파일 접근이나
그래픽 요청을 추가하지 않았다. bounds/겹침은 O(1), 자료 판정에 건물 크기나
타일 크기를 대입하지 않는다. offset/배열 stride·닫힌 영역·unknown/비행 전제에
주석을 남겼다. 아직 문서 전체 충돌 스캔이 없으므로 spatial index/캐시 최적화는
보류했다. FPS/메모리 개선 수치는 측정하지 않았다.

## 6. 요구사항·테스트 체크리스트

| 시나리오 | 예상/판정 |
| --- | --- |
| 228 native 항목의 stride/4축/최종 ID/Flyer bit | 합성 fixture의 서로 다른 값 그대로 읽음 |
| 비대칭/0/65535 offset·음수/큰 중심 | narrowed/clamped 값 없이 원래 geometry |
| 변/꼭짓점/내부/1px 분리 | 닫힌 겹침, 순서에 무관한 결과 |
| old/null/정상/한계값 helper | 조회 성공, unknown과0구분 |
| 잘못된 version/Flyer/object 및 각 축 음수/overflow/type/missing | invalidResponse, 추측 없음 |
| graphics와 metadata-only | 동일 geometry, preview 성공에 의존하지 않음 |
| 지상/공중/떠 있는 건물·unknown | flags 조합16개 및 unknown 회귀 |
| 전체 배치/Undo/Save As/한영 화면 | 기존 회귀 유지, 이번 단계에 신규 정책 UI 없음 |
| FR-218/219, PAR-03 전체 정상/자유/지형/게임 | 부분 구현, 인수 미완료 |

## 7. 실행 결과와 분석

원시 로그는 ignored `.dart_tool/collision_profiles_*.log`에 보관한다.
실행 SDK: Flutter3.47.5 stable/Dart3.13.4. 기준3.44.8/3.12 재검증은 남는다.

- focused: domain13+process46 =59통과/로컬 선택2skip.
- native Debug helper/변경 테스트 빌드 성공, CTest7/7통과.
- 필수 전체 nonwrite format:439파일 중 미변경 infrastructure 테스트3개 차이로
  exit1. `local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
  `process_map_archive_gateway_test.dart`는 사용자/기존 작업 보존을 위해 수정하지 않았다.
- `flutter analyze`: No issues, `collision_profiles_analyze.log`.
- `flutter test --concurrency=4`:1208통과/53skip, `collision_profiles_tests.log`.
  이번 일반 신규36개(domain13/process23), 실제 로컬 선택 신규1개를 추가했다.
- 새 Debug helper와 `C:\Program Files (x86)\StarCraft`로 process suite48통과/
  skip0, `collision_profiles_local.log`. metadata-only로228개의 geometry와
  Flyer 분류를 읽었으며 게임 실행 확인은 아니다.
- `flutter build windows --debug`: 전체 runner 빌드 성공,
  `collision_profiles_windows_build.log`.
- 이번 변경에는 UI가 없다. 이전 컴퓨터 조작 중단 이후 새 UI 조작을 실행하지
  않았고 Windows 클릭·SC:R 플레이·외부 에디터 확인 성공을 주장하지 않는다.

전체 테스트 성공은 무결함/게임 정상 건설 가능성/정상 모드 완료 판정이 아니다.
