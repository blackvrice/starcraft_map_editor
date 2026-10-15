# 사전 배치 전력 설계 모델

2026-10-15. EP1/FR-218의 [앱 계층 조회](UNIT_POWER_INSPECTION.md) 후속 단계다.
**실제 초기 상태 collector를 완성한 것이 아니다.** CHK만으로 확정할 수 없는 부분을
조사하고 제작용 `preplacedLayout` 모델과 built-in adapter를 별도로 구현했다.
결정은 [ADR-0015](decisions/0015-power-state-models.md)를 따른다.

## 1. 실행 계획과 근거 분석

1. 초기 유닛 생성·완공·조건부 제외의 primary source를 확인한다.
2. 실제 상태를 확정할 수 없다면 설계 가정과 실제 상태를 다른 모델로 나눈다.
3. 명시적 모델 요청·응답/cache 분리와 provenance가 있는 읽기 전용 adapter를 연결한다.
4. 합성 UNIT/상태·기존 실제 로컬 자료 경로와 전체 회귀를 자동 검증한다.
5. UI/게임 미연결·실제 수집기 미완료와 실행 결과를 기록한다.

OpenBW `4b046d5f65302b10cb0a745f0fecd37ec85b20a8`의
[초기 생성 경로](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L16405-L16421)는
생성 실패를 허용하며 성공 경로에서 완공을 처리한다.
[UNIT 로드](https://github.com/OpenBW/openbw/blob/4b046d5f65302b10cb0a745f0fecd37ec85b20a8/bwgame.h#L20630-L20678)는
setup·플레이어 조건으로 레코드를 제외하고, 생성 후 HP 등을 적용하며 일부 속성 처리는
TODO로 남긴다. 따라서 HP나 레코드 존재만으로 실제 생성·완공·활성을 증명할 수 없다는
보수적 결론을 내렸다. 이것은 참고 엔진 소스 분석이지 SC:R 실행 관찰이 아니다.
소스 코드를 복사·링크하거나 엔진/게임을 실행하지 않았다.

## 2. 모델과 adapter 계약

| 모델 | 의미와 이번 지원 |
| --- | --- |
| initialMap | 실제 초기 상태를 제공하는 신뢰된 collector용. 기본값 유지, 이번 실제 collector 없음 |
| live | 실행 중 상태. 이번 수집/재사용 미지원 |
| preplacedLayout | 지원되는 사전 배치 파일런이 존재·완공·활성이라는 **명시적 설계 가정** |

`PreplacedUnitPowerStateGateway`의 provider ID는 `editor-preplaced-layout`, revision은
`regular-pylon-layout-v1`이다. preplacedLayout 요청만 받아 원래 record identity와 순서를
유지한 immutable packet을 만든다. 파일·native/process·게임·외부 코드를 실행하지 않는다.

지원 가정은 일반 Unit156, owner0~7과 유효 owner bit, 알려진 validField/validState bits,
기본 또는 유효한 무적 상태, 관계 없음, unused=0에 한한다. 그 밖에는 세 상태 사실을
모두 unknown으로 남긴다. 이를 exists=false나 unpowered로 바꾸지 않는다.
다른 Unit의 사실도 채우지 않는다. HP%는 완공의 근거로 읽지 않는다.

설계 가정에 따라 일반 파일런의 세 사실이 true여도 숫자 DAT 역할·StarEdit 박스·Flyer·
맵 경계·같은 owner는 기존 `UnitPowerCatalog`가 다시 검증한다. ID만 같다고 공급을 승인하지
않는다. 빈 UNIT/비공급자만 있는 문서는 이 **설계 모델 안에서만** unpowered가 될 수 있다.

이 모델은 게임 생성 성공, 로비 참가, 최초 trigger 실행, 동적 disabled/파괴/소유권 변경,
동맹·중립 공급, EUD override를 모델링하지 않는다. ‘정상 게임 배치 가능’의 판정도 아니다.

## 3. 앱 연결과 데이터 안전

- bootstrap에 순수 adapter를 등록했다. 자동 수집·전력 표시나 배치 차단을 활성화하지 않는다.
- `loadUnitPowerState(model: preplacedLayout)`와
  `inspectUnitPowerAt(..., model: preplacedLayout)`에서만 설계 모델을 사용한다.
- 기본 initialMap 요청은 해당 adapter에서 MODEL_UNAVAILABLE이며 기본 조회는 unavailable이다.
- 요청과 응답 모델이 다르면 거절한다. 모델 변경은 이전 cached/pending 상태를 무효화한다.
- query만 다른 모델로 읽을 때에는 기존 packet을 변경하지 않지만 그 사실을 재사용하지 않는다.
- `UnitPowerInspection`의 model/providerId/stateRevision으로 결과의 의미를 보존한다.
  unavailable 등 packet이 쓰이지 않은 결과에 provider 출처를 잘못 붙이지 않는다.
- source/document/record/revision·Undo/Redo·재열기·취소 경계는 기존 조회와 동일하다.
- CHK/원시 문자열·unknown section·선택·Undo/복구/저장을 바꾸지 않는다.
- 전력 지원표의 notImplemented와 기존 UI/preview/Apply 정책을 그대로 둔다.

이후 UI에서 결과를 쓸 때 ‘사전 배치 설계’와 실제 게임 미검증 범위를 표시해야 한다.
초기 상태 collector가 나중에 생겨도 같은 bool이나 동일 cache로 두 모델을 섞지 않는다.

## 4. 요구사항과 시나리오 체크리스트

새 시나리오28개를 기존 controller suite에 추가했다.

| 시나리오 | 확인 사항 |
| --- | --- |
| 기본 요청·initialMap/live 직접 adapter 요청 | 실제 상태를 지어내거나 projection으로 fallback하지 않음 |
| 명시적 layout 조회·반복 조회 | 모델/provider/revision 표시, 실제 상태 조회는 계속 unavailable |
| HP0/1/100/255 | 설계 가정과 HP 기반 완공 추론을 구분 |
| cloak/burrow/flight/hallucination/unknown state | 세 사실 unknown 유지 |
| valid bits·owner-valid·neutral·관계/unused | 미지원 사실을 유효 공급이나 공급자 부재로 승격하지 않음 |
| 유효한 invincible | projection 지원, record identity와 immutable packet 유지 |
| 빈 UNIT·비공급자 | 설계 모델에서만 unpowered, 실제 상태는 unknown |
| 편집·Undo·Redo | 이전 projection 재사용 금지, 명시적 재수집 필요 |
| 변형된 Pylon DAT 역할 | domain이 stateUnsupported, ID-only 승인 없음 |
| 두 모델의 잘못된 응답·pending 모델 전환 | 거절/취소·늦은 projection이 새 실제 모델 packet을 덮어쓰지 못함 |
| 원시 bytes·selection·history·지원표 | 읽기 전용·기존 정책 유지 |

테스트의 UNIT은 직접 생성한 합성 자료다. 초기 생성/완공/활성에 대한 실제 게임 관찰로
보지 않는다. 기존 로컬 DAT/graphics 경로의 통과도 이 가정을 게임 증거로 승격하지 않는다.

## 5. 최적화와 실행 기록

adapter는 UNIT 수 n에 O(n), packet 참조 목록도 O(n)이다. 레코드 바이너리나 이미지,
지형 자산을 복제하지 않는다. 요청의 cache/coalescing과 hover의 I/O 없는 순수 조회를
재사용한다. 실제 성능 수치와 대규모 처리량은 미측정이다.

로그는 ignored `.dart_tool/unit_power_layout_*.log`다.

| 실행 | 결과 |
| --- | --- |
| controller suite |208통과/9skip, 새 모델 시나리오28개 포함 |
| `flutter analyze` | No issues |
| `flutter test --reporter expanded` 재실행 |1691통과/58skip |
| 초기 로더 오류 suite 단독 재실행 |4통과 |
| 로컬 설치/helper를 지정한 controller suite |217통과 |
| `flutter build windows --debug` | 성공 |
| VS CTest Debug |7/7통과 |
| 변경 Dart7파일 format 검사 |0변경/exit0 |
| 전체 format 검사 | 아래 기존3파일 차이/exit1 |
| `git diff --check` | 통과 |

전체 회귀 첫 실행에서 `object_sprite_atlas_loader_test.dart` 로딩 중 Flutter test runner의
`Cannot close sink while adding stream` 오류1건으로 해당 suite4개가 미완료였다.
코드 변경 없이 단독4개와 전체1691개 재실행이 통과해 재현되지 않았지만 원인은 미확정이다.
Windows 빌드와 전체 회귀를 동시에 실행하지 않았다.

전체 format은468파일 중 기존3개 테스트 차이로 exit1이다. 대상은
`test/infrastructure/local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`이며
이번에 수정하지 않았다. 변경 Dart7파일은0변경/exit0다. 실행 SDK는
**Flutter3.47.5 stable/Dart3.13.4**, 기준 **3.44.8/3.12** 재검증은 남는다.
Windows 빌드는 기존 CascLib CMake deprecation 경고 외 성공했고 native7/7도 통과했다.

## 6. 다음 작업과 미완료 범위

다음 제작용 단위는 기본 꺼짐 ‘사전 배치 전력’ 정책과 한영 지원표·preview/Apply 연결이다.
이를 실제 게임 전력 확인으로 부르지 않는다. **실제 initialMap/live collector**, 크립 영역,
EUD 변경과 게임/외부 에디터 인수는 계속 미완료다. 이전 계획의 ‘실제 초기 상태 adapter’는
이번 정적 조사로 완료 처리하지 않는다. 사용자 지시에 따라 실제 앱/게임 조작은 하지 않는다.
