# 초기 크립 출처와 수집 가능성 조사

2026-10-15. EP1 초기 크립 feasibility 항목의 조사·결정·회귀 결과다.
**실제 SC:R 초기 크립 collector를 구현하거나 인수한 문서가 아니다.**
[앱 조회](../UNIT_CREEP_INSPECTION.md)의 initialMap은 collector가 없으면 계속 unavailable이다.

## 1. 실행 계획

1. 고정 primary source에서 CV5/MTXM/THG2와 runtime 크립의 관계를 확인한다.
2. 현재 helper·domain이 실제로 전달하는 자료와 누락을 대조한다.
3. 실제 관찰, 참고 엔진 재현, 제작용 정적 모델의 지원/거절 기준을 결정한다.
4. 확인되지 않은 추론을 막는 주석·합성 회귀를 추가한다.
5. 자동 게이트·Windows 빌드를 실행하고 결과와 미실행 범위를 남긴다.

## 2. 소스 근거와 한계

모두 구현자가 공개한 소스를 읽었다. Blizzard의 SC:R 명세나 직접 관찰 결과로 취급하지 않는다.
참고 엔진을 빌드·실행·링크하거나 코드를 이 저장소로 복사하지 않았다.

### 2.1 CV5·MTXM·THG2

Chkdraft `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`:

- [sc.h TileGroup L2876-L2896](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h#L2876-L2896)은
  CV5의 Creep=bit6, RecedingCreep=bit12, TemporaryCreep=bit14를 구분한다.
- [chk.h Sprite L309-L326](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L309-L326)은
  THG2의 같은 번호 비트에 sprite/unit 의미를 부여한다. 타일 위치별 runtime coverage와 같지 않다.

OpenBW `4b046d5f65302b10cb0a745f0fecd37ec85b20a8`:

| 고정 위치 | 확인한 사실 |
| --- | --- |
| [bwgame.h L20381-L20409](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L20381-L20409) | MTXM 로드가 CV5 flags와 VF4 파생 자료를 합치며 별도 has_creep 분기와 맵 가장자리 보정도 존재 |
| [game_types.h L205-L218](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/game_types.h#L205-L218) | raw_value는 u16인데 has_creep 판독식은 우측 시프트 뒤 0x8000을 검사 |
| [bwgame.h L16405-L16421](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L16405-L16421), [L20630-L20661](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L20630-L20661) | 초기 유닛 생성 조건·성공 여부와 크립 생성 경로가 연결됨 |
| [bwgame.h L18478-L18640](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L18478-L18640) | 확장에는 지형·점유·인접 타일·난수 선택이 관여. 단순 공급 반경만으로 대체할 근거가 아님 |

**조사 중 수정한 추론:** MTXM 로더의 has_creep 분기만 보고 raw bit15를 크립으로
해석하려 했으나, u16의 `((raw_value >> 4) & 0x8000)`은 항상 0이다. PowerShell로
0..65535 전수 대조해 true=0/65536, 최대 시프트 값=4095를 확인했다.
이는 해당 고정 참고 구현의 식에 대한 확인이다. 올바른 SC:R 비트 의미를 찾아냈다거나
실제 크립이 없다는 증거가 아니다. raw 고위 비트를 제거·재해석하지 않는다.

### 2.2 실제 관찰과 시야

BWAPI `d727fed68558c506163048ea889131d8cbb33915`:

- [Map.cpp L54-L89, L122-L126](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPI/Source/BWAPI/Map.cpp#L54-L89)은
  active tile의 temporary/has-creep과 관찰 권한을 읽는다. replay와 일반 게임의 전달 경로도 다르다.
- [GameImpl.cpp L402-L408](https://github.com/bwapi/bwapi/blob/d727fed68558c506163048ea889131d8cbb33915/bwapi/BWAPI/Source/BWAPI/GameImpl.cpp#L402-L408)은
  완전한 맵 정보 없이 보이지 않는 타일에 false를 반환한다. false는 관찰된 부재와 구분해야 한다.
- [프로젝트 README의 Quick Start](https://github.com/bwapi/bwapi#readme)는
  조회 당시 classic Brood War 환경을 설명한다. 이 항목은 위 고정 코드와 별도의 프로젝트
  문서이며 SC:R collector 호환성 증거로 채택하지 않는다.

현재 확인한 근거만으로 SC:R의 초기 관찰 시점과 권한·완전성을 보증하는 adapter는 없다.

## 3. 현재 저장소 대조

| 현재 코드 | 확인 |
| --- | --- |
| native `ReadTerrainPlacement` | CV5+VF4를 읽지만 bit7 buildable와 bit0 walkable만 전달. 크립 관련 원시 플래그는 전송하지 않음 |
| `TerrainPlacementSnapshot` | 건설/이동 전용. 조회 성공·모든 타일 buildable이어도 크립의 없음/있음 증거가 아님 |
| `UnitEnvironmentProfile` | 요구 flag이며 생성 역할·완공·초기 생성 성공·확장 결과 아님 |
| `UnitCreepCoverage` | 명시적 3상태 관찰을 보관. unknown을 absent로 정규화하지 않음 |
| `UnitCreepStateGateway` | 계약만 존재. 실제 구현 없음, 기본 앱에 등록하지 않음 |
| `loadUnitCreepState`/inspection | source/session/revision이 맞는 명시적 packet만 사용. 자료 없으면 unavailable |
| MTXM·THG2·MASK·UNIT | 원시 bytes 유지. 같은 숫자 비트·이름·빈 UNIT·생성 유닛만으로 coverage를 채우지 않음 |

이 대조는 저장소 코드 확인이다. 로컬 CV5의 크립 플래그 분포나 실제 게임 동작을
조사한 것으로 계산하지 않는다. 타일 group mask/렌더링/ISOM을 이번 범위에서 바꾸지 않았다.

## 4. 결정과 지원표

[ADR-0016](../decisions/0016-creep-source-boundaries.md)을 적용한다.

| 후보 | 현재 결정 | 사용 전 필요한 증거 |
| --- | --- | --- |
| 실제 SC:R 초기 관찰 | collector 미구현·unavailable 유지 | 게임/자료 build, 원본/현재 문서 일치, setup/player/seed, 정확한 phase/frame, 권한·전체/부분 관찰 명세 |
| live 관찰 | 미지원 유지 | observer/frame freshness, 변경/끊김/재시작, EUD/TRIG 이후 상태와 명시적 사용자 실행·취소 계약 |
| 참고 엔진 재현 | 실제 SC:R의 대체 아님. 자동 실행/배포하지 않음 | 별도 의존성/라이선스/보안 검토와 재현 가능한 자체 제작 입력, SC:R 비교 인수 |
| CV5 정적 플래그 | 출처 있는 후보 숫자 자료로 읽는 다음 작업은 가능 | 독립 bit 보존, optional version/strict decode, 8타일셋 로컬 대조, checksum·출처·상한 |
| 제작용 seed/배치 모델 | 현재 미구현. 별도 모델 설계 후만 가능 | 명시적 이름·가정·known/unknown 범위·초기/live와 cache 분리, 기본 off·미지원 표시 |
| 모든 UNIT에 고정 반경 채우기 | 채택하지 않음 | 생성/지형/점유·기타 미확인 조건을 숨기지 않는 검증된 모델이 먼저 필요 |

정적 seed 후보 자료와 최종 coverage를 분리한다. CV5 플래그가 false이거나 관련 UNIT이
없다는 이유만으로 실제 게임의 전체 absent snapshot을 만들지 않는다. 게임 관찰 권한을
얻기 위해 도구를 자동 설치·주입·실행하지 않으며 사용자 입력/기존 맵을 건드리지 않는다.

## 5. 요구사항·테스트 체크리스트

새 15개 합성 회귀를 `placement_catalog_controller_test.dart`에 추가했다.
각 경우 동일한 문서 bytes·선택/state·Undo/Redo를 유지하고 current provider/revision과
read result가 없는 unavailable임을 검사한다. 게임 재현이나 수집기 동작 검증이 아니다.

| 시나리오 | 수 | 기대 |
| --- | ---: | --- |
| MTXM 0/0x0040/0x4000/0x8000/0xffff, UNIT 없음 | 5 | raw bit를 크립/부재로 승격하지 않음 |
| THG2 0x1000/0x4000/0x5000 | 3 | sprite 플래그를 tile coverage로 복사하지 않음 |
| 합성 preplaced 131/132/133/143 | 4 | 생성 계열 ID만으로 초기 확장을 추정하지 않음 |
| MASK 0/255 | 2 | 초기 fog를 관찰 권한/실시간 visibility로 취급하지 않음 |
| 정상 buildable/walkable 지형과 빈 UNIT | 1 | 기존 지형 조회 성공도 크립 증거로 사용하지 않음 |

코드에는 포트의 정적 자료 비승격과 지형 snapshot의 투영 범위를 설명하는 주석을 추가했다.
새 수집기·프로세스·의존성·bitmap·cache를 추가하지 않아 실행 비용을 늘리지 않았다.
속도 향상이나 게임 FPS는 측정하지 않았다.

## 6. 실행과 분석

원시 로그는 ignored `.dart_tool/creep_feasibility_*.log`다. 기존 사용자 변경을 보존한
작업 트리에서 검증하며 이번 범위만 커밋한다.

| 실행 | 결과 |
| --- | --- |
| 새 출처 경계 집중 테스트 | 15통과·실패/skip 없음 |
| `flutter analyze` | No issues·exit0 |
| 전체 `flutter test` | 1,869통과·59skip·exit0 |
| 변경 Dart 3파일 format | 0변경·exit0 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 475파일 중 기존 3파일 차이·exit1 |
| `flutter build windows --debug` | 성공·exit0. 기존 CascLib CMake deprecation 경고는 비치명적 |
| native CTest | 7/7통과·exit0 |
| `git diff --check` | 통과 |

전체 format 차이는 기존 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
이 파일들은 수정하지 않았다. 실행 SDK Flutter3.47.5 stable/Dart3.13.4는
기준3.44.8/3.12와 다르다. 기준 SDK·전체 format 게이트/릴리스 인수는 남는다.

이번 실행에서 기능/테스트 실패는 없었고 59skip을 통과로 계산하지 않는다.
새 실제 수집/자산 조회 경로를 구현하지 않았으므로 별도 로컬 CASC 수집 스모크는 실행하지
않았다. 로컬 CV5 플래그 분포·SC:R coverage 비교는 여전히 미확인이다. 연구 단계의
참고 식 전수 대조를 실제 엔진 실행이나 SC:R 스모크 테스트로 계산하지 않는다.

## 7. 완료·잔여·다음

이번에 완료한 것은 **feasibility 조사·지원 범위 결정·추론 방지 회귀**다.
실제 initialMap/live 수집, 설계용 coverage, UI/배치 차단, SC:R/외부 에디터 인수는 미완료다.
사용자의 자동 테스트/빌드 지시에 따라 실제 앱·게임·외부 에디터는 조작하지 않았다.

다음 구현은 로컬 CV5의 크립 관련 bit6/12/14를 독립적인 파생 숫자 자료로 읽고,
기존 helper optional 응답·출처·strict decode·합성/native/8타일셋 회귀를 검증하는 단위다.
그 자료만으로 initialMap/live coverage를 만드는 기능까지 완료 처리하지 않는다.
