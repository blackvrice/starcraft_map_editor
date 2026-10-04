# 사용자 제작 흐름 보완 (2026-10-03)

작업 시작 2026-10-03, 최종 검증 2026-10-04 (Asia/Seoul).

## 계획

사용자 실제 작업 피드백에 따라 이번 작업은 다음 순서로 진행한다. 기존 사용자
변경은 보존하고 원본 맵/원시 CHK/로컬 SC:R 자산 배포 금지 규칙을 유지한다.

1. 지형 브러시 이후 객체 배치, 기존 선택 위 로케이션 생성 입력 충돌을 재현/수정.
2. 유닛 본체/터렛은 DAT 서브유닛 관계로 표시하고 기본 배치는 본체 UNIT 하나만 기록.
3. 단일 raw 타일과 ISOM 지형을 구분. 새 맵은 검증된 지형의 변형 타일로 생성.
4. 설정 유닛/무기를 이름/로컬 그래픽 그리드로 선택, boolean은 체크박스로 표시.
5. epScript 예약어 색상·완성 후보·예제/용도 도움말을 제공. 편집만으로 코드 실행 금지.
6. 회귀/전체 테스트·정적 분석·Windows 실제 렌더/기동·로컬 자산 검사 및 결과 기록.

## 분석

- 카탈로그의 객체 confirm은 이전 terrain brush 도구를 종료하지 않았다. 셸은
  terrain select일 때만 객체 클릭을 전달해 배치 모드여도 brush가 입력을 소비했다.
- 로케이션 생성도 selection 위 drag를 이동으로 판단할 수 있고 활성 카탈로그
  선택이 남으면 영역 callback이 차단된다. 생성 시작 시 모드를 단일화한다.
- 새 맵은 초기 raw 타일 하나로 TILE/MTXM을 채웠다. 기존 ISOM 엔진과 검증된
  CV5 snapshot을 재사용해야 하며 무작위 raw member 선택으로 경계를 추측하지 않는다.
- 터렛은 게임이 본체의 subunit DAT 참조로 생성하는 구성요소다. 별도 UNIT을
  추가하지 않고 본체 그래픽과 합성한다. 기존 맵의 원시 터렛 레코드는 삭제하지 않는다.

## 실행 / 결과

### 요구사항 체크리스트

| ID | 요구사항 | 구현 및 판정 |
| --- | --- | --- |
| R1 | 탱크/골리앗 본체와 터렛 한 세트 | DAT `isSubunit`와 `subunit1`을 검증하여 원점 기준 GRP 합성. 기본 카탈로그에서 구성요소 숨김, 독립 배치 금지. 새 배치는 본체 UNIT 36바이트 하나. 통과. |
| R2 | 단일 타일 / 지형 브러시 구분 | 툴바의 `단일 타일`은 raw 카탈로그, `지형`은 기존 ISOM 경계 브러시. 지형 변형은 검증된 CV5 멤버와 seed로 선택. 통과. |
| R3 | 지형으로 새 맵 생성 | 기본 모드에서 지형 선택 후 ISOM/TILE/MTXM 생성. 단일 raw 타일 모드는 별도 보존. 모든 단계 성공 전에는 세션 교체 안 함. 통과. |
| R4 | 유닛/무기 그래픽·이름 그리드 | 유닛 설정과 EUD 대상 선택에 격자 추가. 무기는 검증된 사용자 유닛을 대표 이미지로 사용, ID 선택과 범위 복사 유지. 통과. |
| R5 | epScript 색상 / 자동 완성 | lexical 예약어·문자열·주석·숫자 색상, 정적 후보, 클릭/Tab/Enter 수락과 Esc 닫기. IME·선택·문자열/주석 안전 처리. 통과. |
| R6 | ON/OFF 체크박스 | 유닛 기본값/가용성, 기술/업그레이드 boolean, EUD boolean 변경. 알 수 없는 비정규 raw 값은 기존 선택 UI로 보존. 통과. |
| R7 | 유닛/sprite/두다드 배치 | 카탈로그/기존 팔레트 선택 시 브러시와 로케이션 생성 종료, 대상 레이어 전환. 검증된 레시피만 사용. 통과. |
| R8 | 로케이션 추가 | 생성 시작 시 객체 배치/브러시 종료. 선택된 객체 위에서 생성 drag도 이동 대신 새 영역으로 처리. 통과. |
| R9 | epScript 용도 확인 | 도움말과 삽입 예제 제공. EUD 빌드에 포함되는 게임 로직 소스이며 편집·저장과 빌드는 분리. 예제는 번들 컴파일러로 검증. 통과. |
| R10 | 작은 화면 사용성 | 새 맵 대화상자 800px 미만에서 단계 탐색을 상단으로 이동, 고정 크기 격자와 스크롤 유지. 600/1000px 실제 Windows 렌더 오류 없음. 통과. |

여기서 통과는 아래 명시된 자동화 및 로컬 도구 검증 범위의 판정이다. 전체 외부
에디터와의 동일 동작이나 실제 게임 인수 완료를 뜻하지 않는다.

### 테스트 시나리오

| 시나리오 | 실행 / 기대 결과 | 결과 및 근거 |
| --- | --- | --- |
| S1 입력 모드 충돌 | 지형 brush에서 카탈로그/기존 유닛 팔레트 선택 후 캔버스 클릭 | select 모드로 전환되고 UNIT 추가. controller 및 shell widget 테스트 통과. |
| S2 로케이션 drag | 선택 객체 위에서 생성 drag | 객체 이동 callback 없이 영역 생성 callback 발생. canvas 및 shell 테스트 통과. |
| S3 터렛 합성 | Goliath 3 / Tank 5 / Siege Tank 30 실제 자산 검사 | 부모/서브유닛 flag, 원점 합성 픽셀 전체 비교, 터렛 픽셀 변화와 단일 UNIT 확인. 실제 자산 테스트 통과. |
| S4 합성 경계 | 투명도/원점/손상 RGBA/초과 크기 | 정상 합성과 손상 거절. native graphics 테스트 통과. |
| S5 새 맵 지형 | 8 tileset 생성, 실제 타일 렌더, MPQ 생성/재열기 | ISOM 존재 및 CHK byte-exact 왕복. 실제 자산 테스트 통과. |
| S6 생성 안전성 | 취소/세션 변경/자산 변경/실패/seed | 오래된 응답·부적합 입력 거절, 동일 seed 결정성 및 원본 없는 세션. controller/domain 테스트 통과. |
| S7 그래픽 설정 | 유닛·무기 선택, 자산 없는 경우, draft/cancel/Undo | 실제 격자 렌더와 이름 fallback, 기존 설정 회귀 테스트 통과. |
| S8 boolean 보존 | 체크박스 변경, 비정규 값, 범위 복사 | canonical 0/1만 체크박스, unknown raw 보존, 취소/Undo byte-exact. shell/EUD widget 테스트 통과. |
| S9 소스 편집 | 예약어 색상, 한글 cursor, IME, 주석/문자열, 긴 소스 | 소스 원문 보존, 후보 억제/수락, 20만 자 초과 plain fallback. controller/widget 테스트 통과. |
| S10 예제 빌드 | 기존 선택 텍스트 보존 후 예제 삽입, 번들 빌드 | 원본 입력 불변, 별도 출력 컴파일 성공. 실제 euddraft 테스트 통과. |
| S11 실제 배치 | 로컬 228 유닛 / 517 pure sprite 카탈로그, 두다드/유닛/sprite 배치 | 지원 여부 검사, 실제 레코드/지형 변경과 정확한 Undo. 관련 44개 테스트 통과. |
| S12 화면 / 기동 | Windows 600/1000px의 5개 화면 및 기본 앱 실행 | 10개 캡처, render 오류 로그 없음. 기본 debug 앱 4초 생존 후 검사용 프로세스 종료. |

### 발견한 오류와 수정 과정

1. 최초 집중 검사에서 새 맵 스크롤 영역 밖 클릭과 격자 추가 후 중복 이름을
   한 개로 가정한 테스트가 실패했다. 실제 스크롤/선택 경로와 새 UI 계약으로 수정.
2. 실제 새 맵 검사는 변형이 하나뿐인 지형에 여러 타일을 기대하여 실패했다.
   검증된 여러 멤버가 있는 지형을 기본으로 선택하고 그 조건으로 테스트했다.
   물/우주 등 단일 멤버 지형에 임의 변형을 만들지는 않는다.
3. 완성 후보 ListTile의 Material 조상 누락, 작은 새 맵 대화상자의 overflow와
   겹침을 widget 및 native 렌더로 검출했다. Material과 반응형 단계/격자를 수정.
4. 변경 적용 중 기술 설정의 중복 지역 변수로 분석/빌드가 실패했다. 중복을
   제거하고 전체 분석·테스트·정상 앱 빌드를 다시 통과했다.
5. 최종 native CTest는 샌드박스에서 `replace succeeds`가 실패(6/7)했다.
   같은 바이너리를 승인된 실제 Windows 권한으로 재실행하면 7/7 통과했다.
   권한 제한에 따른 차이로 기록하며 실패 자체를 삭제하거나 코드로 우회하지 않았다.
6. 실제 자산 통합 병렬 재검사에서 타일 atlas render가 한 차례 실패했다(4/5).
   진단의 code/message/rawDetails를 테스트 실패 출력에 추가했다. 직렬 재실행과
   병렬 재실행은 각각 5/5 통과했다. 최초 원시 진단은 남지 않아 원인을 확정하지
   못했다. 일시 실패를 해결 완료로 단정하지 않고 반복 실행 시 확인할 위험으로 남긴다.

### 최적화 / 주석

- 새로운 파서나 경계 알고리즘 대신 검증된 ISOM 엔진과 도메인 배치 factory를 재사용.
- 격자 이미지는 32개 단위 페이지, 최대 8페이지 캐시, 최대 64x64 썸네일로 제한.
  선택 셀마다 helper 프로세스를 생성하지 않으며 자산 변경/종료 시 캐시 무효화.
- 로컬 측정: 유닛 228개 썸네일 3,074,624바이트, 첫 페이지 544ms/전체 4,162ms.
  pure sprite 517개 6,467,648바이트, 첫 페이지 496ms/전체 12,648ms.
  최대 개별 썸네일 16,384바이트. 이 수치는 해당 로컬 실행값이며 FPS 보장은 아니다.
- 색상 span은 소스/스타일 기준 캐시, 긴 소스는 plain 표시, 완성 후보 최대 8개.
- 복잡한 원점 합성, 비정규 boolean 보존과 오래된 비동기 결과 거절에는 계약 주석을
  두고 단순 대입에는 불필요한 주석을 추가하지 않았다.

### 최종 검증 명령과 증거

실행 환경: Windows, Flutter 3.47.5 / Dart 3.13.4. 저장소 기준 SDK
Flutter 3.44.8 / Dart 3.12와 다르다. native helper 0.13.0, wire protocol 3.

| 명령 / 검사 | 최종 결과 | 로컬 로그 (git 제외) |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | 실패: 기존 미변경 테스트 3개 SDK 포맷 차이. 이번 변경 Dart 파일 별도 검사 통과. | `.dart_tool/workflow_format_gate.log` |
| `flutter analyze` | 오류 없음 | `.dart_tool/workflow_analyze_final.log` |
| `flutter test` | 977 통과 / 환경 조건부 48 skip | `.dart_tool/workflow_full_tests.log` |
| 실제 자산 관련 배치 테스트 | 44 통과 | `.dart_tool/workflow_local_placement.log` |
| 실제 제작 흐름/ISOM/새 맵 통합 | 직렬 5 통과 / 병렬 재실행 5 통과 (앞선 병렬 실행 1 실패) | `.dart_tool/workflow_real_serial.log`, `.dart_tool/workflow_real_parallel_retry.log`, `.dart_tool/workflow_real_final.log` |
| `ctest --test-dir build/windows/x64 -C Debug --output-on-failure` | 실제 Windows 권한 7 통과 (샌드박스 6 통과/1 실패) | CTest 출력 및 위 실패 분석 |
| `flutter run -d windows -t tool/workflow_windows_smoke.dart` | 실제 엔진 10화면, 오류 로그 비어 있음 | `.dart_tool/workflow_render_final.log`, `.dart_tool/workflow_windows_smoke/` |
| `flutter build windows --debug` | 성공, 기본 main 복원 | `.dart_tool/workflow_app_final_build.log` |
| 기본 exe 기동 | 4초 생존, 검사용 PID 39252 정상 종료 | 기동 검사 출력 |

포맷 실패 파일은 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`.
이번 작업 밖의 사용자/SDK 변경을 임의로 정리하지 않았다.

실제 테스트는 로컬 `STARCRAFT_DATA_HELPER_PATH`, `STARCRAFT_TEST_INSTALLATION`,
`MAP_ARCHIVE_HELPER_PATH`, `MAP_ARCHIVE_TEST_MAP`, `EUDDRAFT_TEST_INSTALLATION`,
`EUDDRAFT_TEST_BUNDLED=1`을 지정한다. 자산/설치 경로가 없으면 조건부 skip이며
SC:R 원시 자산과 추출 이미지는 저장소나 배포 fixture에 포함하지 않는다.
`re_highlight` MIT 고지는 `docs/licenses/re_highlight.txt`에 보관한다.
Windows 번들 `data/flutter_assets/NOTICES.Z`에도 re_highlight/Reqable 고지가
포함된 것을 압축 해제하여 확인했다.

## 남은 인수 범위

- 터렛 합성은 검증된 첫 GRP 프레임과 원점 기준이다. 전체 IScript 애니메이션,
  방향별 프레임과 게임 실행 시 특수 offset까지 동일하다고 주장하지 않는다.
- 무기 그래픽은 사용하는 유닛의 대표 이미지이며 발사체 전용 아이콘이 아니다.
  모든 보조 유닛 선택기가 격자로 바뀐 것은 아니다.
- epScript 완성은 정적 예약어/일부 EUD API 목록이다. import 심볼 분석·언어 서버,
  전체 API 타입 검사와 실행 디버거는 제공하지 않는다.
- 지원하지 않는 addon/Nydus 연계, 불일치 두다드 지형 등은 진단으로 거절한다.
  알 수 없는 맵 데이터를 추측하거나 기존 터렛 UNIT을 삭제하지 않는다.
- 기준 SDK 재검사, clean PC release 설치, 게임/외부 에디터 상호운용,
  멀티플레이 실행과 profile FPS 인수는 별도 작업이다. 오류가 전혀 없다는 보장은 아니다.
- 실제 자산 병렬 atlas 렌더의 일시 실패는 재현되지 않아 원인을 확정하지 못했다.
  재발 시 이번에 보강한 원시 진단으로 조사한다.

## 2026-10-04 실제 Windows 배치 재검증

### 실행 계획과 소스 분석

사용자 보고 대상은 유닛, 스프라이트, 두다드 배치다. 기본 `main` Windows 앱을
실행하고 카탈로그 선택 -> 배치 버튼 -> 맵 클릭 -> 개수/속성 확인 -> 실행 취소로
검사한다. 예외가 발생하지 않아도 배치가 거절되는 경로를 확인하며 원본을 저장하지
않는다. 사용자 로컬 Jungle 128x128 맵을 사용했고 파일/추출 자산은 fixture로
추가하지 않았다.

소스에서 `PlacementCatalogController.placeAt`이 실패 코드를 보관하지만 맵 화면은
그 코드를 표시하지 않았다. 두다드의 CV5 요구 바닥 지형 검사 자체는 정상이고,
지형 불일치 거절이 사용자에게 무반응처럼 보이는 표시 결함을 확인했다.
검증을 우회하거나 지형을 자동 변경하지 않고 기존 상태/진단을 재사용한다.
추가 파싱/자산 로딩/프로세스 호출 없이 표시만 갱신하며 안정적인 코드 보존에
짧은 계약 주석을 추가했다.

### 실행과 요구사항 체크리스트

| 검사 | 실제 실행 / 결과 | 판정 |
| --- | --- | --- |
| 유닛 카탈로그 배치 | Unit #0 선택 후 클릭, 127 -> 128개, 선택 Unit #127 및 좌표/owner 표시. Undo 후 127개/저장할 변경 없음. | 해당 항목 통과 |
| pure sprite 카탈로그 배치 | Sprite #0 선택 후 클릭, 32 -> 33개, 선택 Sprite #32 및 좌표 표시. Undo 후 32개/저장할 변경 없음. | 해당 항목 통과 |
| 두다드 지형 불일치 | Doodad #0 / startTileGroup 1024 / 4x4 선택 후 다른 바닥 클릭. 108개 유지, `OBJECT_PLACEMENT_DOODAD_TERRAIN_MISMATCH`. | 기존 무안내 결함 확인 |
| 요구 지형 일치 | 읽기 전용 인메모리 probe로 origin tile (110,56) 확인. 실제 화면에서 center tile (112,58) 클릭하면 108 -> 109개, 좌표 (3584,1856), Undo 후 108개. | 통과 |
| 새 빌드 실패 안내 | 같은 불일치 클릭 후 한국어 이유/안정적 진단 코드가 맵 상단에 표시됨. 활성 배치 종류도 표시됨. | 통과 |
| 실패 후 재시도 | 오류 뒤 선택 유지, 일치 지형 클릭 시 109개로 증가하고 오류/배치 안내 해제. Undo로 원상 복구. | 통과 |
| 경계/취소 | widget 테스트로 맵 밖 거절 이유, 선택 유지, 취소 시 안내/표시 해제 확인. | 통과 |
| 데이터 안전 | widget 거절 전후 Raw CHK byte-exact 및 dirty=false. 실제 맵 probe 전후 파일 지문 동일. UI에서 저장하지 않았고 모든 시험 추가는 Undo. | 통과 |

표시 변경: 맵 상단에 활성 카탈로그 배치 종류와 실패 안내를 추가했다. 지형
불일치, 숨김/잠금 레이어, 맵 경계 초과를 한국어/영어로 설명하며 그 외 코드는
일반 거절 안내와 원래 코드를 보존한다. 접근성 live region을 적용했다.
전체 유닛/스프라이트 ID, 기존 팔레트 복제, 연속 배치와 모든 맵 조합을 수동으로
전수 검사한 것은 아니다. 이번 정상 배치 예시는 사용자 보고의 모든 오류가
해결되었다는 증거로 취급하지 않는다.

### 검증 결과와 실행 중 실패

| 명령 / 검사 | 결과 | 증거 |
| --- | --- | --- |
| `flutter analyze` | 오류 없음 | 실행 출력 |
| `flutter test` | 978 통과 / 환경 조건부 48 skip | `.dart_tool/placement_feedback_full.log` |
| 추가 shell 거절 회귀 테스트 | 1 통과 | `.dart_tool/placement_feedback_test.log` |
| 실제 맵 인메모리 probe | 지형 불일치 거절/일치 지형 성공, 원본 지문 동일, 1 통과 | 로컬 `.dart_tool/placement_probe_test.dart` 실행 출력 (git 제외) |
| 전체 필수 포맷 게이트 | 기존 미변경 infrastructure 테스트 3개 SDK 포맷 차이로 실패 | 승인된 실행 출력, 위 기존 포맷 실패 목록과 동일 |
| 이번 변경 Dart 6파일 포맷 | 0 changed, 통과 | 승인된 실행 출력 |
| `flutter build windows --debug` | 성공, 기본 앱 재실행 및 직접 클릭 검사 | `.dart_tool/placement_feedback_build.log` |

환경은 Flutter 3.47.5 / Dart 3.13.4로 기준 SDK와 다르다. 최초 집중 widget 실행은
Dart compiler의 `WidgetCallSiteTransformer` null cid 내부 오류로 중단되었다.
동일 테스트 재실행과 전체 테스트는 통과했고 앱 결함으로 확정하지 않는다.
샌드박스에서 빌드/포맷 명령이 출력 없이 진행하지 않아 해당 세션을 종료한 뒤
승인된 일반 권한으로 다시 실행했다. 빌드는 CASCLib CMake 최소 버전 폐기 예정
경고가 있으나 성공했다. 일부 UI 자동화의 접근성 항목 조회/클릭과 잘린 창의
좌표가 불안정하여 앱 최대화 후 최신 화면을 확인하며 클릭했다.
동작 검증은 실제 화면과 객체 개수/속성으로 판단했으며 자동화 도구 실패를
앱의 배치 오류로 집계하지 않았다.
