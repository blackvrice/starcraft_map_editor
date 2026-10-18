# 주 편집 지도 보조 표시

## 실행 계획과 요구사항

2026-10-18 EP4 / FR-219의 DAT 기본 사거리·시야, 검증된 배치 설계 전력장과
주 편집 캔버스 통합을 구현했다. 실제 앱 조작 없이 자동 테스트·빌드만 진행하며,
실제 게임 전력·크립 수집 미지원이라는 기존 결정을 유지한다.

1. 분석: 기존 지형 분석, 전체 UNIT 메타데이터 조회, DAT 무기/서브유닛 참조,
   배치 전력 검사의 상태 우선순위, 편집 지도·여러 맵의 수명을 확인했다.
2. 설계: 표시용 조회와 배치 선택을 분리하고, 기존 검증기를 공유한다. 외부
   프로세스는 명시적 자료 불러오기에서만 호출하며 원본과 편집 이력은 보존한다.
3. 실행: domain 사거리 모델·전력 supplier projection, application 제어기,
   주 지도 도구막대/렌더러와 한국어·영어 상태/출처 표시를 추가했다.
4. 검증: 참조 순환/터렛·최소 사거리·미확인/상한, 전력 도형의 좌표별 일치,
   늦은 응답·설치/문서 변경·Undo, 픽셀과 좁은 화면·대형 지도를 검사한다.

## 지원표

| 표시 | 근거 | 의미와 제한 |
| --- | --- | --- |
| 높이·건설·이동 | 기존 CV5/VF4 snapshot | [지형 분석](TERRAIN_ANALYSIS.md)의 읽기 전용 표시를 주 지도에서도 사용 |
| 선택 유닛 시야 | 로컬 units.dat sightRange × 32px | 노랑 원. 지형 시야/고저차/은폐/실제 시야 계산이 아님 |
| 선택 유닛 지상·공중 사거리 | 로컬 weapons.dat minRange/maxRange | 빨강/청록 원. 가는 안쪽 원은 최소 사거리 |
| 터렛 무기 | 기존 UnitWeaponIndex의 양쪽 subunit 참조 | 탱크/골리앗의 터렛을 포함하며 sentinel과 순환은 종료 |
| 배치 설계 전력 | PreplacedUnitPowerLayout + UnitPowerCatalog + UnitPsiField | P1~P8을 명시적으로 선택. 같은 소유자 regular Pylon의 좌표 공급 범위 |
| 실제 전력·크립 | 수집기 미지원 | 회색 미확인. 설계 전력과 별개의 모드이며 false로 추정하지 않음 |

사거리 표시는 **로컬 DAT 기본값**이다. UNIS/UNIx, 업그레이드·EUD 패치,
대상의 크기·거리 판정, 캐리어/리버/벙커의 간접 공격, 발사체/런타임 상태를
유효 사거리로 계산하지 않는다. 시야 원은 실제 가시 영역이 아니다. 없음 sentinel과
반경 0은 원을 만들지 않는다. 잘못된 참조나 min > max는 추측/보정하지 않는다.

수치 단위는 고정된 BWAPI의
[UnitType.cpp](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPILIB/Source/UnitType.cpp#L2299-L2305)와
[WeaponType.cpp](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPILIB/Source/WeaponType.cpp#L556-L562)를 대조했다.
외부 구현을 복사/링크한 것이 아니라 기존 DAT 숫자 자료와 참조 모델을 사용한다.

## 전력의 단일 검증 규칙

기존 `UnitPowerCatalog.check`의 supplier 검증을 `project`로 공유했다. 후보 건물의
종류/box/source 검사는 기존 `check`가 계속 담당한다. 공급자 검사에서는 모든
UNIT을 확인한 뒤 unknown > unsupported > bounds > supply 순서를 유지한다.
알 수 없는 UNIT/환경 profile/서브유닛, 잘못된 파이런 역할·크기·소유자·상태·관계,
맵 밖 footprint를 정상 공급자로 바꾸지 않는다. 검증된 공급자 하나가 미확인
공급자를 숨길 수 없다. 기존 배치 검사 테스트도 함께 실행한다.

regular 선배치 파이런에만 완성·활성·존재를 가정하는 기존 설계 모델을 명시적으로
사용한다. 일반 CHK가 실제 게임의 완성/활성 상태를 증명하는 것은 아니다.
[배치 전력 계약](UNIT_POWER_VALIDATION.md)과 동일한 10행 psi mask를 사용하며
타원/원으로 근사하지 않는다. 반개구간 정수 pixel strip은 strict 음수 경계까지
`containsPoint`와 일치한다. 초록은 좌표 공급 범위, 빨강은 그 밖, 회색은 미확인이다.
이것만으로 건설 가능/충돌/크립 등 전체 배치 조건 충족을 허가하지 않는다.

## 데이터 안전과 수명

- 포트와 기존 `PlacementCatalogController`를 통해서만 로컬 자료를 읽는다.
  UI는 파일/FFI/프로세스/바이너리 파서를 호출하지 않는다.
- 모드/체크박스/소유자/선택/그리기는 helper를 실행하지 않는다. 설치/문서 epoch가
  달라진 늦은 자료는 기존 catalog 검증에서 거절한다. 조회 실패는 상태에 남기고
  재시도할 수 있다. 실제 게임을 실행하거나 임의 EUD 코드를 평가하지 않는다.
- 별도 inspection getter는 현재 extractedMap/설치 수명과 terrain tileset을 검사한다.
  배치용 선택과 독립적이므로 표시를 위해 선택/플레이어/배치 정책을 변경하지 않는다.
- terrain view와 전력 field는 immutable session/source/owner별로 재생성한다.
  편집·Undo 후 이전 UNIT 좌표나 공급장 캐시를 재사용하지 않는다. 사거리 중심은
  selection에 남은 좌표가 아닌 현재 UNIT record에서 읽는다.
- 주 `MapCanvas`의 key/state와 입력 callback을 유지한다. terrain 숨김은 지형
  overlay를 숨기고 UNIT 숨김은 사거리/설계 전력을 숨긴다. 잠금은 기존 편집 정책을 따른다.
- CHK/리소스/원본 파일/dirty/Undo를 바꾸지 않는다. unknown/중복 UNIT은
  정규화하지 않으며 모호한 projection은 미확인으로 남긴다.
- 주 지도에서 벗어나 catalog/EUD 화면으로 전환하면 표시용 controller는 폐기되고
  재진입 시 표시 선택은 초기화된다. 문서 자체와 로컬 catalog 자료는 보존한다.

## 최적화와 상한

선택 UNIT 최대 64개, 반경 최대 8192px, 원 최대 512개를 지원한다. 초과하면
일부만 완전한 결과처럼 보이지 않도록 원 전체를 숨기고 예산 초과를 표시한다.
전력은 UNIT 최대 10000개/공급자 최대 256개이며 초과는 미확인이다.
표시 상한은 게임의 유닛 수 제한이나 유효 DAT 규칙을 새로 정의하는 것이 아니다.

전력 검증은 session/source/owner마다 한 번만 수행한다. 렌더러는 그 결과의
최대 2560개 strip 중 viewport와 겹치는 것만 하나의 path로 그린다. 중첩 공급을
중복 알파 합성하지 않는다. 사거리도 viewport 바깥 도형은 cull하며 원본 지형의
기존 visible-tile/LRU를 사용한다. 전체 맵 각 pixel에서 UNIT 전체를 재검색하지 않는다.

256×256 synthetic debug, 800×600, 파이런 256개/선택 사거리 원 192개:

| 확대 | 3회 paint µs |
| --- | --- |
| 1× | 11239 / 2580 / 1805 |
| 8× | 620 / 413 / 461 |

1초 병적 동기 계산 상한 스모크이며 16.7ms 프레임/RSS/release 성능 보장이 아니다.

## 시나리오 체크리스트

- [x] 시야의 tile→pixel, 무기의 pixel 단위·최소/최대·부모/터렛·양쪽 무기
- [x] 없음·순환·invalid 참조·min > max·map bounds·선택/원 예산과 immutable 결과
- [x] psi strip 전체 515×323 상대 좌표 대조, 기존 전력 검사와 오류 우선순위
- [x] 공급자 256/257 경계·소유자 전환·공급자 삭제/Undo와 캐시 갱신
- [x] 명시적 조회만 실행, 설치 변경·새 문서·늦은 응답·폐기·실패 재시도
- [x] 현재 UNIT 좌표 사용, 숨김 레이어/잘못된 선택·중복 UNIT 거절
- [x] 원본 bytes/리소스/Undo 깊이/배치 선택과 주 캔버스 state/입력 보존
- [x] 한국어·영어 320px 체크박스 라벨과 실제 전력/미확인/원 렌더 픽셀
- [x] 256×256 debug 스모크와 상한·화면 밖 culling
- [x] 실제 로컬 DAT의 탱크/골리앗 터렛 참조·기본 사거리와 파이런 메타데이터 대조
- [x] 실제 8타일셋 CV5/VF4 읽기·출처/높이 coverage 재검증
- [x] 전체 테스트·정적 분석·변경 파일 포맷·Windows 빌드·native CTest
- [ ] 실제 앱/DPI/게임·외부 에디터/release profile/RSS 인수

## 최종 실행 결과

| 게이트 | 결과 |
| --- | --- |
| 집중 5개 파일 | 87 통과. 기존 전력 검사 포함, 신규 테스트 24개 |
| `flutter test` 기본 전체 재실행 | 2350 통과 / 72 조건부 skip / 실패 0, 3분 27초 |
| `flutter analyze` | 무이슈 |
| `dart format --output=none --set-exit-if-changed lib test tool` | 569개 검사, 기존 미수정 인프라 테스트 3개의 차이로 exit 1. 이번 변경 파일은 차이 없음 |
| 실제 로컬 CASC 스모크 2개 파일 | 2 통과, DAT/터렛/전력 및 8타일셋 확인, 8초 |
| `flutter build windows --debug` | 성공, 19.9초 |
| 빌드 후 native CTest | 7/7 통과 |

전체 format 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`에
기존부터 있으며 해당 파일들은 수정하지 않았다. 조건부 skip은 로컬 도구/맵/자료
환경을 요구하는 기존 검사이며 모든 외부 인수가 실행됐다는 뜻이 아니다.
Windows 빌드의 기존 CascLib CMake 최소 버전 deprecation 경고는 남는다.
실제 SDK는 Flutter 3.47.5 / Dart 3.13.4로 기준 3.44.8 / 3.12와 다르다.

로컬 로그: `.dart_tool/editor_overlay_focused_final.log`,
`editor_overlay_all_tests_final.log`, `editor_overlay_analyze_verified.log`,
`editor_overlay_format_verified.log`, `editor_overlay_local_data.log`,
`editor_overlay_windows_build.log`, `editor_overlay_ctest_final.log`.

실행 중 발견한 영문 체크박스 라벨의 320px 넘침은 Flexible로 수정했고 재검증했다.
UI 테스트 fixture 정리는 실제/가상 비동기 큐를 모두 진행하도록 보완했다.
첫 전체 실행은 2349 통과/72 조건부 skip/1 실패였다. 새 도구막대가 기존
로케이션 추가 버튼을 초기 화면 아래로 밀어낸 회귀를 검출했다. 기존 도구 뒤로
옮겼으며 해당 기존 시나리오 1개와 새 UI 4개를 재검증했다. 검사 조건을 완화하거나
실패를 skip하지 않았다. 실제 로컬 CASC 스모크 2개는 8초에 통과했다.
자동 테스트 통과를 실제 앱 조작·게임·외부 에디터·clean Windows 인수로 세지 않는다.
사용자 지시에 따라 실제 앱/게임 조작은 수행하지 않았다. 남은 EP5 언어·소스,
EP6 결과 출력·출시와 외부/성능 인수는 [전체 추적표](COMPLETION_TRACKER.md)에 남긴다.
