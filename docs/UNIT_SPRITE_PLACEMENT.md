# 유닛형 스프라이트 배치와 검증

2026-10-13, FR-217/EP1의 제한된 standalone unit-sprite 지원.
이번 작업은 CHK 생성·카탈로그·배치·Undo/Redo·저장 왕복을 구현했으며,
모든 유닛 ID의 SC:R 게임 동작을 확인한 것은 아니다.

## 1. 계획과 조사

가이드/개발 계획 -> 기존 Sprite factory/카탈로그/렌더/저장 경로 -> 공식 고정
소스 -> 제한 지원 설계 -> 구현 -> 집중/실제 도구/전체 테스트 -> 문서/커밋 순이다.
기존 첫 배치 작업인 [두다드 미리보기](PLACEMENT_PREVIEW.md)는 유지한다.
사용자 설정 섹션 조사와 플랫폼/의존성 변경, staged `local.properties`는 보존한다.

공식 근거는 Chkdraft revision `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[선택 기본값](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/left_bar.cpp#L156-L174)과
[THG2 구조/flags](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L333-L380)다.
공식 페이지와 raw 소스를 읽기 전용으로 확인했다. 일반 sprite-unit 기본값은
unit ID·현재 소유자·클릭 좌표·unused=0이며 DrawAsSprite 없이 IsUnit을 사용한다.
두다드 유래 flags의 변환은 standalone 생성 규칙과 섞지 않는다.

## 2. 요구사항과 지원 범위

- 별도 유닛형 스프라이트 탭에서 그림/이름/종류 ID를 선택한다.
- 일반 Unit과 같은 ID여도 `spriteUnit:<id>` 키로 분리하며 선택만으로 맵을 바꾸지 않는다.
- classic unit ID 0~227 중 검증된 capability가 있고 standalone 배치 가능한 항목만 허용한다.
- capability 누락·참조 관계 필요·DAT Subunit/터렛은 읽기 전용으로 유지한다.
  Addon/Nydus·독립 터렛 지원이나 모든 ID의 게임 호환을 확대 주장하지 않는다.
- Sprite 레이어와 맵 경계/편집 상태를 검사하고 단일 THG2에 한 건 추가한다.
  중복/손상 섹션은 추측하지 않고 거절한다. UNIT/DD2/지형은 변경하지 않는다.
- 기본 상태는 활성이다. 기존 [Sprite-unit 비활성 상태 편집](BASIC_EDITING_TOOLS.md)은
  계속 사용할 수 있다. 기존 flags나 두다드 overlay를 새 기본값으로 재작성하지 않는다.

## 3. 계층과 바이트 계약

`SpritePlacementFactory.createSpriteUnit`은 capability의 unit ID 일치, subunit/
관계 제약과 u8/u16 범위를 검사한 뒤 10바이트를 생성한다.

| offset | 필드 | 새 값 |
| --- | --- | --- |
| 0 | u16 type | unit ID |
| 2/4 | u16 x/y | 클릭한 게임 pixel 좌표 |
| 6 | u8 owner | 선택 소유자 |
| 7 | u8 unused | 0 |
| 8 | u16 flags | IsUnit=0x2000; DrawAsSprite=0, Disabled=0 |

`ObjectEditingController.placeCatalogSpriteUnit`은 기존 section target/append/공통
시간순 기록을 재사용한다. THG2가 없으면 끝에 생성하고 한 번의 Undo로 제거한다.
pure sprite(0x1000)와 Doodad overlay 생성 경로는 바꾸지 않는다.

process gateway는 같은 요청 ID/offset/limit로 기존 helper의 **Unit** 카탈로그를
조회한다. 버전·자료·ID·capability·개별 실패를 기존 parser로 검증한 후 구조화된
page/entry를 spriteUnit 키로 투영한다. helper가 새 native catalog kind를 지원한다고
가장하지 않고 wire/helper 버전도 바꾸지 않는다. timeout·취소·중복 operation ID
정책과 raw 로그/자료 출처는 기존 경로를 따른다.

`ObjectPlacementCatalogLoader`는 unit-sprite의 preview를 **Unit 그래픽 키**로
조회하며 sprites.dat의 같은 숫자 ID로 바꾸지 않는다. GRP/본체·터렛 합성,
자료 revision 대조와 기존 최대64x64 썸네일 처리를 재사용한다. 별도 자산 복사나
새 캐시를 만들지 않는다. UI가 parser/FS/process를 직접 호출하지 않는다.

## 4. 실행 결과와 실패 분석

| 시나리오 | 결과 |
| --- | --- |
| 생성 10바이트 | 고정 기대 배열과 decode 일치, DrawAsSprite/Disabled 없음, 반환 바이트 복사 확인 |
| capability/입력 실패 | 다른 ID·터렛·관계 필요·숫자 범위 초과 거절, 부분 바이트 없음 |
| 기존/누락 THG2 | 정확한 레코드 추가, Sprite 레이어 선택, UNIT 수 유지, Undo/Redo byte-exact |
| 잠금/경계/중복/관계 | 현재 세션·dirty·Undo 무변경 |
| metadata 투영 | 키/총228개/offset·마지막 페이지/개별 실패/버전 유지, 잘못된 응답은 전체 실패 |
| 그래픽 | Unit atlas 요청, unit-sprite catalog key로 썸네일 매핑 |
| UI | 탭 -> 그림 선택 -> Place -> 소유자/배치 -> Undo. capability 없는 항목은 confirm 전에 거절 |
| 실제 로컬 CASC | 새 unit-sprite 종류의 목록/그림/배치/Undo/Redo 확인 |
| Save As/재열기 | fake/native MPQ 모두 새 flags/type/좌표/owner 보존, 입력 아카이브와 미지 섹션 보존 |

초기 집중 실행에서는 새 테스트가 group 밖에 등록되어 helper 함수 scope 오류가
났다. group 안으로 옮겼다. UI에서는 구성요소 체크박스 문구가 26px 넘쳤고,
단일 클릭/더블클릭 판별 대기를 빠뜨려 선택이 null이었다. 문구를 Flexible로
바꾸고 기존 테스트와 동일하게 클릭 판별을 기다린 뒤 동일 시나리오가 통과했다.
정적 분석의 새 if 블록 표기 두 건도 보완했다.

## 5. 검증 기록

| 명령/검사 | 결과/로그 |
| --- | --- |
| factory/command/loader/controller/process/roundtrip 집중 테스트 | 128 통과/8 환경 조건부 skip, `.dart_tool/unit_sprite_focused.log` |
| 실제 CASC+native MPQ controller/roundtrip 테스트 | 49 통과, `.dart_tool/unit_sprite_real_tools.log` |
| `flutter test` | 1,008 통과/49 환경 조건부 skip, `.dart_tool/unit_sprite_tests.log` |
| `flutter analyze` | No issues, `.dart_tool/unit_sprite_analyze.log` |
| 비쓰기 전체 포맷 | 기존 미변경 테스트3개 차이, `.dart_tool/unit_sprite_format.log` |
| 변경 Dart 파일 비쓰기 포맷 | 16개/변경0, 종료0 |
| Windows build | debug 성공, `.dart_tool/unit_sprite_windows_build.log` |
| native CTest | 7개 통과. 최초 권한 제한 실행의 atlas 쓰기 실패2개는 제한 밖 동일 명령에서 통과 |
| 문서/공백 검사 | 변경 문서11개의 로컬 링크338개 확인, `git diff --check` 통과 |
| Windows UI 직접 조작 | 새 맵 -> 카탈로그 -> 스프라이트 유닛 -> #0 그림 선택 -> 배치 -> Undo 확인 |
| SC:R 게임/외부 에디터 | 미실행. 위젯/도구/Windows UI 인수를 게임 인수로 대신하지 않음 |

Windows debug 앱을 실행하여 기존 복구 목록을 삭제/열지 않고 닫은 뒤, 로컬
자료가 준비된 Badlands 128x128 임시 새 맵을 만들었다. 첫 Sprite-unit #0의
썸네일/상세 그림·소유자 UI를 확인하고 맵 내부에 배치했다. 스프라이트0->1,
유닛1 유지, Inspector type0/owner0/x1737/y1464, 진단0을 확인했다. 실행 취소
버튼으로 스프라이트1->0, 유닛1 유지와 다시 실행 항목을 확인했다. 임시 새 맵은
사용자 맵에 저장하지 않았으며 앱에 열어 두었다. 직접 UI Save As/Redo는 실행하지
않았고 자동 command/native MPQ 왕복 테스트로 별도 확인했다.

UI 자동화의 첫 접근성 index는 갱신되어 사용할 수 없었다. 새 화면을 캡처한
뒤 보이는 메뉴/버튼 좌표로 진행했다. 변경 파일 포맷의 권한 제한 실행은 출력
없이 대기하여 중단했고, SDK 실행 권한이 있는 동일 비쓰기 검사에서 통과했다.

실제 SDK는 Flutter3.47.5/Dart3.13.4, 기준3.44.8/3.12와 다르다.
기존 포맷 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
로컬 설치 자산/추출 이미지/사용자 맵은 저장소에 추가하지 않았다.
실제 도구 테스트도 직접 작성한 CHK/임시 MPQ만 사용했다.

## 6. 남은 작업

EP1 전체와 PAR-01~03/게임 인수는 미완료다. unit-sprite 관계/터렛 예외 확대는
새 지원표와 게임 증거가 필요하다. 다음 코드 단위는 두다드 합성 썸네일이며,
다른 유형의 hover 사전 검증과 스냅/정상·자유 정책도 남아 있다.
