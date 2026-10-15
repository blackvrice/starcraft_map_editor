# 사전 배치 전력 검사 정책

2026-10-15. EP1/FR-218의 [사전 배치 설계 모델](UNIT_POWER_LAYOUT.md)을 새 카탈로그
UNIT의 checkbox·지원표·공통 preview/Apply에 연결했다. [ADR-0015](decisions/0015-power-state-models.md)의
**제작용 가정**이며 실제 게임 전력이나 건설 가능성 보증은 아니다.

## 1. 실행 계획과 소스 분석

1. 자원/지형 정책의 공통 prepare, 최종 스냅 좌표, metadata 수명과 지원표를 조사한다.
2. 설계 투영을 domain의 순수 함수로 공유해 adapter/실제 배치의 규칙 중복을 없앤다.
3. 기본 꺼짐 옵션과 한영 scope/진단, 실제 전력 상태와 별도 지원표 row를 연결한다.
4. 현재 UNIT·source·최종 좌표·거절 무변경·Undo/Redo·Save As·좁은 UI를 검증한다.
5. 전체 게이트·Windows/native·로컬 자료 결과와 실제 앱/게임 미실행을 기록한다.

이전 비동기 조회 packet은 문서 편집 직후 무효화된다. 이를 클릭 허가로 재사용하거나
hover에서 상태 수집기를 호출하면 stale 결과나 불필요한 I/O가 생긴다. 따라서 제작용
정책은 공통 prepare 시점의 UNIT을 같은 순수 projection으로 다시 읽는다. 실제 상태
조회 API와 그 기본 initialMap/모델 분리·provenance 계약은 유지한다.

## 2. 정책과 원자성

| 항목 | 구현 |
| --- | --- |
| 기본값 | checkPreplacedPower=false, 기존 자유 배치 유지 |
| 명시적 선택 | Map의 ‘사전 배치 전력’ checkbox만으로 켬. game state 미확인 문구 표시 |
| 프리셋 | 기존 검사/자유 모두 이 옵션을 끔. 일반 검사 선택으로 설계 가정을 자동 수락하지 않음 |
| mode | 기존3개 설정이 checked/free를 결정하며 이 옵션이 켜진8조합은 모두 custom |
| 대상 | 새 카탈로그 UNIT만. Sprite/unit-sprite/Doodad·기존 이동/복제/Inspector 제외 |
| 현재 자료 | 같은 source의 full228 numeric metadata와 현재 immutable session의 UNIT |
| source 수명 | 설치/세션/자료 변경·reload·취소에 기존 metadata 수명을 재사용 |
| 저장 | 옵션 선택만으로 CHK/원시 문자열/unknown sections/Undo/복구/저장 자료를 변경하지 않음 |

`PreplacedUnitPowerLayout.project()`에 기존 regular Pylon 규칙을 그대로 옮겼다.
상태 adapter도 이를 사용하므로 가정이나 지원 범위를 바꾸지 않고 중복을 제거했다.
domain은 Flutter/파일/process에 의존하지 않는다. 체크박스는 실제 초기 상태 collector를
등록하거나 initialMap/live 요청으로 projection을 반환하게 만들지 않는다.

`ObjectEditingController.placeCatalogUnit/previewCatalogUnit`의 선택 입력은
`checkPreplacedPower`와 `preplacedPowerCatalog`다. 같은 `_prepareCatalogUnit`이 구조,
session/history/layer, ID/owner, 원래 좌표와 factory를 검사한 뒤 최종 정렬 좌표에서
지형 → 겹침 → 자원 거리 → 사전 배치 전력을 판정한다. 첫 실패를 반환한다.
pure checker 안의 unknown/state/bounds/power 우선순위는 유지한다.

point snap의 raw 좌표는 공통 안전 검증을 받고 최종 snap 좌표에 정책을 적용한다.
건물 정렬도 같은 prepare 안에서 처리한다. 음수/맵 밖 좌표를 clamp하거나 정렬로 살리지
않는다. 실제 append와 Undo 생성 전에 거절하며 선택을 유지한다.
hover 이후 파일런 삭제·소유자 변경·Undo/Redo가 있어도 클릭에서 현재 자료를 다시 검사한다.

## 3. 결과와 지원표

| domain 결과 | 배치 결과 |
| --- | --- |
| powered/notApplicable | 이 규칙은 거절하지 않음. 전체 게임 허용 판정 아님 |
| unpowered | OBJECT_PLACEMENT_PREPLACED_POWER_REQUIRED |
| unavailable/자료 없음 | OBJECT_PLACEMENT_PREPLACED_POWER_UNAVAILABLE |
| stateUnsupported | OBJECT_PLACEMENT_PREPLACED_POWER_STATE_UNSUPPORTED |
| outOfBounds | 기존 OBJECT_PLACEMENT_OUT_OF_BOUNDS |

세 새 진단은 카탈로그와 Shell ghost의 공통 `placementFailureText`에서 한영으로
표시한다. unknown이나 미지원 상태를 단순 전력 부재로 표시하지 않는다.
260px CheckboxListTile에 scope,16px 로딩과 재조회 아이콘/tooltip을 추가했다. 재조회는
기존 겹침/자원 거리와 같은 numeric cache를 새로 읽으며 graphics 출처가 다르면 계속 거절한다.

지원표에 preplacedPower row를 추가했다. 꺼짐=생략, 비UNIT=대상 아님, metadata pending=로딩,
출처/후보 profile 누락·불일치=확인 불가, 확인된 no-psi=대상 아님, 나머지 지원 자료=검사 사용이다.
getter는 전체 UNIT을 스캔하거나 좌표를 판정하지 않는다. **검사 사용은 배치 통과가 아니다.**
기존 power row는 ‘실제 전력 상태’로 명확히 구분하고 여전히 미구현으로 둔다.
크립/EUD 미구현과 게임 인수 대기도 유지한다.

Shell의 배치 옵션은128px 고정 높이의 스크롤 영역에 둔다. 옵션 추가/로딩 표시 때문에
캔버스가 줄거나 기존 terrain/object/로케이션 도구가 밀리지 않도록 했다.

## 4. 요구사항·시나리오 체크리스트

새32개 시나리오(일반31개·선택적 로컬1개)를 추가했다.

| 시나리오 | 검증 |
| --- | --- |
| 기본 off·프리셋·16 boolean 조합 | 설계 가정 opt-in과 custom 파생, free/checked가 자동 활성화하지 않음 |
| 최종 point/건물 위치 | raw769 허용→최종768 거절, preview/Apply 사유 일치 |
| source/coverage/role/geometry/box 오류 | 거절 시 문서/Undo 유지, explicit reload 후 회복 |
| unknown/hallucination·중립·경계·변형 DAT | 확인 불가/미지원/경계와 단순 전력 부재 구분 |
| owner 변경·hover 후 파일런 삭제·Undo/Redo | 오래된 packet/hover가 클릭 허가가 되지 않음 |
| pending 공동 metadata·자유 전환 | 1회 조회, 늦은 결과로 정책 부활 없음 |
| raw/final 좌표·잠금·history | 새 정책이 공통 안전 검증을 우회하지 않음 |
| no-psi·Sprite/unit-sprite/Doodad | 대상 아님, 기존 배치 유지 |
| 한영300/1000px UI | checkbox/reload/scope/지원표 두 종류·텍스트 fit·overflow/exception 없음 |
| Save As·거절·삭제/Undo·저장 후 재판정 | 합성 archive에서 원본/unknown/string/두다드 bytes 유지 |
| 실제 로컬 DAT/graphics | Unit160 Gateway/156 Pylon·source·far 거절/near 허용·Undo, 게임 관찰 아님 |
| 전체 진단 | ObjectPlacementDiagnosticCodes.all의 한영 fallback 누락 검사 |

새 전력 Save As 시나리오는 합성 archive 검증이다. 로컬 native MPQ로 실행하는 기존
설정/정렬/저장 회귀와 새 전력 모델의 게임 검증은 별도 증거로 기록한다.

## 5. 최적화·실행 결과

현재 UNIT 수 n에 O(n), 추가 작업 메모리 O(1)의 lazy projection을 공통 prepare에서 읽는다.
bitmap·파일/process 호출·전체 상태 목록 cache를 hover에 추가하지 않는다. numeric metadata는
기존 조회/취소/재조회와 공유한다. 속도 향상 수치나 대규모 FPS는 미측정이다.

초기 analyze의 multiline if 스타일2건을 수정했고 최종 No issues를 확인했다.
집중258통과/11skip을 확인한 뒤 선택적 로컬 시나리오1개를 추가했다.
첫 전체 실행에서 옵션 줄 증가가 기존 브러시 좌표와 로케이션 생성 도구 접근에 영향을
주는 Shell 회귀2건을 검출했다. 옵션 영역을128px로 고정해 수정했으며 테스트 기대값은
완화하지 않았다. 실패했던 두 테스트가 각각 통과했고, 기존 캔버스 테스트에 옵션을
켜고 꺼도 캔버스 크기가 불변인 회귀를 추가했다.
이어진 전체 실행에서128px 영역 아래의 정렬 checkbox를 스크롤 없이 클릭하던
기존 테스트6건이 실패했다. 실제 접근 방식에 맞게 ensureVisible 후 클릭하도록
수정했으며 잠금 거절·재시도·배치 결과의 기대값은 유지했다. 해당6건과 최종 전체
실행이 통과했다. 로그는 ignored `.dart_tool/preplaced_power_policy_*.log`다.

| 최종 실행 | 결과·한계 |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | 1,722통과·59skip. 로컬 설치/도구가 필요한 skip은 아래 별도 실행과 구분 |
| 로컬 DAT·graphics/native MPQ 연동 | 245통과·skip 없음. 새 실제 DAT 전력 시나리오와 기존 native 저장 회귀 포함 |
| `flutter build windows --debug` | 통과. CascLib의 기존 CMake deprecation 경고는 남음 |
| native CTest | 7/7통과 |
| 변경 Dart18개 format | 변경 없음·통과 |
| 전체 `dart format --output=none --set-exit-if-changed lib test tool` | 469파일 중 기존3파일 차이로 exit1. 해당 파일은 수정하지 않음 |

전체 포맷 차이는 `test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`다.
실행 SDK는 Flutter3.47.5 stable/Dart3.13.4로 저장소 기준3.44.8/3.12와 다르다.
따라서 기준 SDK 게이트를 통과했다고 주장하지 않는다.

## 6. 인수와 다음 단위

사용자 지시에 따라 자동 테스트/빌드만 진행하며 실제 Windows 앱 조작·SC:R·외부 에디터는
실행하지 않는다. 이 기능과 기본 꺼짐 옵션만 완료 처리하며 EP1 전체를 닫지 않는다.
다음은 초기 크립 영역 자료의 출처·미확인 상태와 읽기 전용 판정 계약이다. actual
initialMap/live collector·EUD 변경·크립 정책과 게임/외부 도구 인수는 계속 별도다.
