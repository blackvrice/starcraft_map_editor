# 설정·트리거 작성 보완 (EP2)

2026-10-16, [ADR-0021](decisions/0021-settings-trigger-editing.md).
요청: 설정·트리거 개발 완료. 사용자 허용에 따라 자동 테스트와 빌드만 실행한다.
**에디터 구현과 게임 인수 완료는 구분한다.**

## 계획과 소스 분석

기존 일곱 설정 영역, TRIG/MBRF 지원 opcode, 소유자·활성 일괄 편집과 Undo는
이미 구현되어 있었다. 이를 누락으로 다시 집계하지 않고 다음 네 영역을 보완했다.

| 요구사항 | 구현·사용 흐름 | 검증 시나리오 |
| --- | --- | --- |
| FR-223 / PAR-04 | Unit/Upgrade/Tech에서 로컬 기본값 읽기, 기본/초안 예상값·출처·단위 | native offset·가짜 helper·로컬 CASC·조회 무변경 |
| FR-224 / PAR-05 | Player의 리마스터 색상·4모드/RGB/ID·swatch·byte diff·Apply | COLR 보존·명시 VER 전환·unknown/중복/손상·stale·Undo |
| FR-225 / PAR-06 | Resources 문자열의 byte token/팔레트/preview·공유 ID 또는 단일 참조 분리 | 1~255 모든 바이트·Unicode·NUL/잘못된 token·취소/Undo·공유 참조 |
| FR-405 / PAR-07 | Trigger/Briefing 텍스트/소유자/활성/조건·액션 ID/참조 검색·선택 치환 preview | 원본 인덱스·인자 검증·미지원/EUD 보존·stale/Undo·10,000건 profile |

## 구현과 보존 계약

readEudDat는 DAT revision v2/68열이며 EUD manifest/실행 가능 필드를 늘리지 않는다.
일반 설정용 추가 열은 classic units.dat의 HP(offset3156,u32/228), armor(8856,u8/228),
minerals(14860,u16/228), gas(15316,u16/228), buildTime(15772,u16/228)과 weapons.dat의
baseDamage(3640,u16/130), bonusDamage(3900,u16/130)다. HP는 1/256 고정소수,
시간은 기존 CHK 필드의 단위를 표시한다. shields·upgrade/tech 기존 열도 재사용한다.

제품/빌드/helper·revision·자산별 hash를 표시한다. mode0은 초안 사용자 지정값,
1은 DAT 상속, 나머지는 확인 불가다. 읽기 실패/잘못된 숫자 초안을 0으로 대신하지
않는다. 조회는 문서/Undo를 변경하지 않는다. 무기 예상값은 선택 유닛의 기본값
플래그 기준이며 모든 참조 유닛의 상태가 같다는 보장이 아니다. 플레이어별 업그레이드/
기술 상속 표시는 유지한다. 런타임 EUD·게임 초기화 결과는 포함하지 않는다.

CRGB의 canvas 표시는 소유자 색상 표식이며 sprite atlas 재색상은 아니다.
모드/채널/VER/COLR 계약은 ADR을 따른다. 문자열은 UTF-8/raw 계약을 유지하고
제어 코드/잘못된 UTF-8을 가역 표기한다. `<HH>`/`<<`는 이 에디터의 표기이며 다른
에디터의 축약 문법 전체를 지원하지 않는다. 정렬/숨김/이후 제거 효과는 숫자 token으로
남긴다. preview의 근사 색상을 게임 렌더로 취급하지 않는다.

참조 치환은 location/string/unit/unitGroup/switch/property만 제공한다. string에는
sound path 참조도 포함된다. unknown opcode/EUD 바이트의 참조를 추측하지 않는다.
지원 슬롯의 나머지 인자도 검증하며 하나라도 잘못되면 전체 preview를 거절한다.
알려진 읽기 전용 참조는 유지/skip 수 표시. 미지원 슬롯의 모든 참조를 찾았다고
주장하지 않는다. 필터 변경은 선택을 비우고 Select visible은 원본 인덱스만 사용한다.

## 실행·결함 수정·최적화

1. 기존 코드·요구사항·보존 계약을 확인하고 domain→controller→한영 UI로 연결했다.
   복잡한 가역 표기·CRGB 전환·참조 검증에 주석을 추가했다. 사용자 미커밋 연구/
   설정 섹션 테스트는 보존하고 이번 커밋에서 제외한다.
2. 첫 회귀에서 검색 dropdown의 74px 가로 넘침을 발견해 expanded로 수정했다.
   개발 중 token 버튼 괄호·새 위젯 테스트 fixture 경로 오류도 수정/재실행했다.
   600px 창의 기존 제목 줄 216px 넘침은 Wrap으로 수정했다. 전체 회귀에서 새 예상값
   표의 숫자와 입력 필드를 혼동한 기존 테스트 3건은 입력 위젯으로 범위를 좁혔다.
   이는 값 변경 결함이 아니라 화면 구성 변화에 따른 잘못된 finder 기대였다.
3. 문서/언어별 검색 index와 opcode 집합을 cache하여 매 질의마다 80개 슬롯을
   재해석하지 않는다. 색상은 scene당 한 번 decode한다. byte diff는 동일 section
   객체를 건너뛴다. 측정 없는 범용 parser/cache 재작성은 하지 않았다.
4. native projection 확장에 맞춰 배열 크기를 열 정의에서 유도하게 바꾸고 독립
   offset/endianness 테스트를 추가했다. 파일/프로세스 직접 호출은 UI/domain에 없다.
5. 마지막 소스 검토에서 token 편집 진입 전에 안전한 문자열 표/ID를 검증하도록
   보완했다. 잘못된 UTF-8과 손상된 문자열 표를 혼동하지 않는다. 손상 표를 안전한
   컨트롤러로 주입하려던 테스트는 기존 검증에서 이미 거절되므로 기대를 바로잡고,
   원본 불변·정상 리소스 편집 지속을 확인한다.

## 검증 결과

사용 SDK는 Flutter 3.47.5 stable / Dart 3.13.4다. 저장소 기준 3.44.8/3.12와
다르며 기준 SDK/CI 재확인은 별도다. 명령은 저장소 루트에서 실행했다.

| 검증 | 결과 |
| --- | --- |
| `flutter analyze` | 통과, No issues found |
| `flutter test` | 최종 2,202 통과 / 62 skip / 실패0 |
| 새 도메인/화면 시나리오 | token·색상·기본값·참조 편집/보존, 새 화면 회귀 파일 12건 통과 |
| `flutter build windows --debug` | 성공, Windows Debug 실행 파일 생성 |
| `ctest --test-dir build/windows/x64 -C Debug --output-on-failure` | 7/7 통과, 새 native DAT offset/폭/endian 포함 |
| 로컬 CASC/MPQ 등 선택 검증 | 18 통과, skip 0. 68열 DAT·소스 hash·기존 그래픽/카탈로그·가짜 helper·실제 자체 제작 맵 저장 왕복 |
| 변경 Dart 파일 형식 검사 | 31파일/변경0 통과 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 506파일 중 기존3파일 차이 검출, exit1. 해당 파일은 수정하지 않음 |
| 문서/공백 | 신규 문서 내부 상대 링크 검사 통과, `git diff --check` 통과 |

전체 형식 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`의
기존 차이다. 자동 형식 검사 실패를 숨기거나 관련 없는 파일을 정리하지 않았다.
소유자 색상 변경은 scene cache를 갱신하며 설정/VER/CRGB를 한 Undo로 복원하는
회귀를 포함한다. 합성 10,000건은 index 466ms, 질의20회 50ms였다. Debug 테스트
환경의 단일 측정이며 실제 맵/릴리스 성능 보장은 아니다.
이 검색 기능은 이전에 없었으므로 동일 경로의 변경 전 측정값은 없으며, 개선율을
주장하지 않는다. 해당 측정은 새 기능의 회귀 기준선이다.

선택 검증은 `STARCRAFT_DATA_HELPER_PATH`, `STARCRAFT_TEST_INSTALLATION`,
`MAP_ARCHIVE_HELPER_PATH`, `MAP_ARCHIVE_TEST_MAP`을 절대 경로로 설정했다.
첫 실행에서 기존 MPQ 테스트의 기본 상대 입력 경로가 안전 정책에 의해 거절됐다
(`ARCHIVE_SOURCE_PATH_NOT_ABSOLUTE`). 테스트 입력을 절대 경로로 지정해 18건을
재실행/통과했다. 새 자체 제작 맵 테스트는 다른 출력 경로에 CRGB/token/TRIG를
저장하고 CHK byte-exact 재열기·미지 섹션·원본 아카이브 바이트 불변을 검사했다.
원시 게임 자산은 fixture/배포물에 추가하지 않았다.

빌드의 기존 CascLib CMake 최소 버전 deprecation warning은 비차단 경고다.

실제 앱 UI·SC:R·ScmDraft/Chkdraft 인수는 미실행이다. 사용자 허용 범위 밖이며
게임/외부 에디터의 색상 우선순위·문자 렌더·PAR-04~07/M6.3/M7는 미완료로 유지한다.
sprite 재색상/확장 palette ID 지원도 별도다. 자동 통과를 무결함/전체 출시 인수로
표현하지 않는다.
