# 설정별 EUD 후보 필드 확대

2026-09-26. 기존 5개에서 **8개 분류, 61개 필드**로 선언적 편집 범위를 확대했다.
완료 범위는 편집·구조 검증·저장·Undo/Redo·미리보기와 실제 도구 API 컴파일 검사다.
**SC:R 게임/멀티플레이 지원 완료가 아니다.** override가 있는 프로젝트의 앱 EUD
Build는 생성기 연결 전까지 차단한다. Save Project/맵 Save As는 게임 효과를 적용하지 않는다.

## 사용 방법

EUD Project를 열거나 현재 맵에서 만든 뒤 **All EUD field extensions**를 누른다.
분류 → 필드 → 이름/ID 검색으로 대상을 선택하고 값을 입력한다.
**Add / update draft**로 초안에 추가하고 **Apply draft to project**로 일괄 적용한다.
여러 분류의 변경은 한 Undo 단계가 된다. Remove from draft는 해당 값만 제거하며
Cancel은 모든 초안을 버린다. 선택 변경 전에 추가하지 않은 입력은 버려진다.
Save Project로 저장한다. 기존 실드/무기 편집기도 같은 프로젝트 값을 사용한다.
편집 중 프로젝트가 교체되면 오래된 초안 적용을 거부한다.

일반 DAT 기본 수치는 아직 로드하지 않으므로 0을 기본값처럼 채우지 않는다.
알려진 유닛·무기·업그레이드·테크 이름을 표시하고, 이름 없는 항목과 그래픽 참조는
종류와 숫자 ID를 유지한다. 플레이어 ID 0–7은 Player 1–8로 표시한다.

## 필드 목록

| 분류 | 수 | 필드 (키 접두사는 분류명) |
| --- | ---: | --- |
| unit | 17 | hasShield, maxShield, groundWeapon, airWeapon, flingy, seekRange, sightRange, sizeType, baseProperty, portrait, readySound, whatSoundStart/End, pissedSoundStart/End, yesSoundStart/End |
| weapon | 15 | minRange, maxRange, damageType, targetFlags, cooldown, damageFactor, attackAngle, launchSpin, removeAfter, splashInnerRadius/MiddleRadius/OuterRadius, behavior, explosionType, flingy |
| flingy | 6 | topSpeed, acceleration, haltDistance, turnSpeed, movementControl, sprite |
| upgrade | 8 | mineralCostBase/Factor, gasCostBase/Factor, timeCostBase/Factor, maxLevel, race |
| tech | 5 | mineralCost, gasCost, timeCost, energyCost, race |
| player | 3 | zergControlMax, terranSupplyMax, protossPsiMax |
| sprite | 2 | image, isVisible |
| image | 5 | isTurnable, isClickable, useFullIscript, drawIfCloaked, drawingFunction |

Registry는 `lib/domain/eud/eud_field_manifest.dart`에 있다. 스키마 v1의 field key를
추가했으며 바이너리 맵에 직접 쓰지 않는다. 구버전 앱은 모르는 키를 보존하지만
검증 시 거부한다. 알 수 없는 키를 실행 코드나 메모리 주소로 해석하지 않는다.

## 검증과 영향 범위

- 대상 수: Unit 228, Weapon 130, Flingy 209, Upgrade 61, Tech 44,
  Player 8, Sprite 517, Image 999. Weapon None 130은 참조 값으로만 허용한다.
- 초상화 0–109, 음성 0–1143. ready/pissed/yes 음성의 유닛 대상은 0–105,
  what 음성은 0–227. 확장 DAT의 임의 ID는 허용하지 않는다.
- unsigned 폭, 참조 범위, bool, 정확한 enum 문자열을 검사한다. baseProperty의
  미사용 비트 0x00040000과 targetFlags의 0x1ff 밖 비트는 거부한다.
  충돌 enum `Unknown_Crash`와 `HpBar`는 등록하지 않는다.
- 선언된 최소≤최대 사거리, 스플래시 안쪽≤중간≤바깥, 음성 시작≤끝을 검사한다.
  미설정 값은 추측하지 않는다. 게임 유효 조합 보증은 아니며 원시 단위를 사용한다.
  플레이어 인구수는 반 인구수 단위(400=200)다.
- 최대 실드 및 업그레이드/테크 비용·최대 레벨은 명시적 CHK override가 필요하다.
  비용은 UPGS/UPGx·TECS/TECx의 활성 버전과 useDefault를 읽는다. 기본값·손상·누락을
  구분한다. DAT 전역 maxLevel은 CHK 플레이어별 연구 제한과 달라 단일 기준값을
  표시하지 않는다. 일반 비용 변경만 필요하면 기존 Settings를 사용한다.
- 타입 설정은 플레이어 공통이고 player 필드만 해당 슬롯 대상이다. 업그레이드/테크의
  플레이어별 연구 허용·완료/레벨 변경으로 표시하지 않는다. 자원 액션도 추가하지 않는다.
- Unit/Weapon 영향 분석은 원본 DAT 기준이다. 새 참조 override 반영 그래프와
  Flingy/Sprite/Image 역참조 목록은 미구현이다. 이 경우 참조 없음 대신 영향 미확인으로
  표시한다. classic/HD 표시·경로 탐색 갱신은 미검증이다.

## 근거와 재현

- euddraft 0.10.2.5 / eudplib 0.80.6, API revision
  `e04ac54dccbdcda94512214c4730b46f7f13d74f`.
- 공식 source distribution `eudplib-0.80.6.tar.gz` SHA-256:
  `5be90f655d29198ef9ab6b4f59c51b1fad62b504752fcf51c1c05461fab71da2`.
  `src/eudplib/scdata/{unit,weapon,flingy,upgrade,tech,player,sprite,image}.py`와
  `offsetmap/memberkind.py`에서 활성 멤버·폭·enum 확인. 주석 처리 멤버는 제외했다.
- DAT 범위는 저장소 native 참조 파서와 [PyMS UnitsDAT](https://github.com/poiuyqwert/PyMS/blob/master/PyMS/FileFormats/DAT/UnitsDAT.py),
  [PortraitsDAT](https://github.com/poiuyqwert/PyMS/blob/master/PyMS/FileFormats/DAT/PortraitsDAT.py),
  [SoundsDAT](https://github.com/poiuyqwert/PyMS/blob/master/PyMS/FileFormats/DAT/SoundsDAT.py)를
  2026-09-25 대조했다. 수치 계약은 경계값 테스트로 고정한다.
- `test/integration/eud_expanded_fields_compile_test.dart`는 자체 제작 맵에서 각 필드의
  처음/마지막 대상과 모든 enum 선택값, 정수 경계를 쓰는 플러그인을 컴파일한다.
  동봉 `0.10.2.5-editor.1`에서 통과했다. 원본 맵과 동봉 도구 무결성을 재확인한다.
  극단값 시험 맵은 게임 플레이용 검증 맵이 아니며 임시 폴더에서 삭제된다.
- 재현: `EUDDRAFT_TEST_INSTALLATION`에 동봉 디렉터리 절대 경로,
  `EUDDRAFT_TEST_BUNDLED=1` 설정 후 위 테스트 실행. 미설정 환경에서는 skip한다.

## 남은 완료 조건

검증 기록: `flutter analyze` 통과, 전체 `flutter test` 714개 통과·25개 skip,
실제 동봉 컴파일 테스트 별도 1개 통과, Windows Debug 빌드·프로세스 시작 확인 통과.
전체 비쓰기 format 게이트는 기존 infrastructure 테스트 4개의 형식 차이로 실패했다.
이번 변경 파일 포맷은 통과했으며 기존 파일은 수정하지 않았다. 실행 도구는 Flutter
3.47.2 / Dart 3.13.2로 저장소 기준 3.44.8 / 3.12와 다르다. Windows 빌드에는 기존
CascLib CMake 최소 버전 경고가 남아 있다.

결정적 실행 소스 생성기·사용자 hook 순서·SafeEudBuildPipeline 연결, 배치/생성 유닛
실드 초기화 정책, 공유 그래픽 영향 조회와 실제 SC:R/멀티플레이 검증이 남아 있다.
컴파일 성공만으로 M6.3.1/M6.3.2 전체를 완료 처리하지 않는다.
관련: [개발 계획](DEVELOPMENT_PLAN.md), [실드 빌드 준비](EUD_SHIELD_BUILD_PREPARATION.md).
