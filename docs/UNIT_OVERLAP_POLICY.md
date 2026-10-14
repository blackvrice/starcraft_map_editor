# UNIT 겹침 배치 정책

2026-10-14. FR-218, EP1/PAR-03의 제한 구현이다. 로컬 기본 DAT의 충돌 영역을
새 카탈로그 **UNIT** 배치에 연결했다. 전체 정상/자유 모드나 게임 건설 가능성,
지형·전력·크립·EUD 변경 검증을 완료한 것은 아니다.

## 1. 실행 계획과 소스 분석

1. [자료 계약](PLACEMENT_VALIDATION_CONTRACTS.md)의 순수 geometry와 로컬 출처를 재사용한다.
2. 전체228개 numeric metadata snapshot을 조회하고 수명/취소/출처를 검증한다.
3. 현재 UNIT의 지상/공중 겹침을 preview와 Apply의 공통 준비 경로에 연결한다.
4. 기존 동작을 기본값으로 유지하는 체크박스와 한영 거절 사유를 추가한다.
5. 스냅/건물 정렬·Undo·자료 실패/race·화면·Save As/로컬 자료를 검증한다.

고정 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[겹침 판정](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/main_windows/gui_map.cpp#L2269-L2295)을
재확인했다. 닫힌 영역과 지상/공중 분리를 참조하되, extended/누락 자료를 통과시키거나
불명확한 in-transit 상태를 추측하지 않는다. 이것은 참조 구현과 의도적으로 다른
보수적 지원 범위이며 게임 엔진 전체 규칙을 복제했다는 뜻이 아니다.

## 2. 구현과 사용자 흐름

Map의 배치 설정 줄에서 **UNIT 겹침 허용** 체크박스를 제공한다. 기본 체크는
기존 동작과 동일하다. 해제하면 로컬 collision metadata를 읽고, 같은 지상 또는
공중 영역의 UNIT가 겹칠 때 빨간 미리보기/거절 사유를 표시한다. 자료 로딩 중에는
작은 진행 표시, 완료 후에는 충돌 자료 다시 불러오기 아이콘을 제공한다.

- 체크박스/조회/hover/거절은 문서·dirty·Undo·기존 레코드를 변경하지 않는다.
- 성공한 배치만 기존 공통 명령으로 기록한다. Undo/Redo 후 현재 UNIT를 다시 읽는다.
- 허용 설정은 runtime-only이며 맵/설치 변경 후에도 유지한다. 기존 맵의 겹친
  객체를 읽을 때 삭제하거나 옮기지 않는다.
- 허용을 켜도 레이어/history/섹션·ID/owner/관계/subunit·중심/u16·두다드/선택적
  건물 박스 경계 검사는 생략하지 않는다.
- pure Sprite/THG2 unit-sprite/두다드, 기존 객체 이동·템플릿/로케이션은 이번 정책
  대상이 아니다. 특히 unit-sprite의 게임 충돌을 UNIT와 같다고 가정하지 않는다.

## 3. 자료와 검증 계약

| 항목 | 계약 |
| --- | --- |
| 포트 | 기존 catalog `unitMetadataOnly=true`, limit228, 그림/새 native 기능 요청 없음 |
| 전체 응답 | total/행228, ID0~227 순서, request operation/path/kind/tileset/offset/limit 일치 |
| 출처 | product/build/helperVersion/CascLib revision 필수. graphic catalog의 출처와 동일해야 함 |
| 선택 자료 | 선택 capability와 snapshot의4축/Flyer/Building/FlyingBuilding 일치 검사 |
| 누락 | old/null profile, 누락된 used ID, extended ID, standalone subunit은 검증 불가 |
| 미지 객체 | 중심이 멀어도 충돌 영역이 없으면 안전하게 제외할 수 없어 검증 불가 |
| flight | Flyer 또는 Building+FlyingBuilding+inTransit. 기존 raw inTransit가 설정됐다면 해당 valid bit와 건물 능력 필요 |
| 원시 상태 | 지원하지 않는 inTransit는 별도 거절. 임의로 ground/air를 지정하지 않음 |
| 우선순위 | 공통 구조 안전 검사 후, 자료 미확인 > 지원하지 않는 상태 > 알려진 겹침 |
| 좌표 | 점 스냅의 raw 위치는 기존 안전 검사만, 최종 좌표에서 겹침 검사. 건물 정렬도 최종 중심에서 검사 |
| 갱신 | installation/map identity/dispose/explicit reload에서 취소·epoch 변경·cache 폐기 |
| 현재 문서 | hover 결과를 승인으로 저장하지 않음. Apply에서 현재 immutable session으로 재계산 |
| retry | 실패를 cached 성공으로 대체하지 않음. 동기 gateway 예외도 pending/loading을 해제하고 재시도 가능 |

`UnitCollisionCatalog`는 Flutter/I/O/프로세스에 의존하지 않는 순수 도메인이다.
`ObjectEditingController`의 공통 준비 단계가 이를 사용하며 Presentation은
컨트롤러와 번역만 사용한다. 조회의 원시 page와 provenance/diagnostics는
`lastCollisionMetadataPage`에 보관한다. 이전 hover나 다른 설치의 결과는 적용 근거가 아니다.

안정적 진단은 `OBJECT_PLACEMENT_UNIT_OVERLAP`,
`OBJECT_PLACEMENT_COLLISION_UNAVAILABLE`,
`OBJECT_PLACEMENT_COLLISION_STATE_UNSUPPORTED`이며 한영 사유를 제공한다.

## 4. 요구사항 체크리스트

| 요구사항/시나리오 | 구현과 증거 |
| --- | --- |
| UNIT 지상/공중·비행 중 건물·닫힌 경계 | domain의4조합/건물4조합/경계/invalid state 회귀 |
| unknown/extended/누락 profile·snapshot 불일치 | fail-closed, 멀리 있는 unknown과 거절 우선순위 회귀 |
| immutable metadata·ID 불일치 | 입력 변경과 잘못된 key 거절 |
| 공통 preview/Apply·실패 무변경 | command/catalog 회귀, 현재 session identity와 Undo depth |
| 점 스냅·건물 정렬 최종 위치 | 원래 위치가 겹쳐도 최종 비겹침은 허용, 반대 경우는 거절 |
| 설정·snapshot·Undo/Redo | 중복 거절/Undo 재허용/Redo 재거절·snapshot coalescing 회귀 |
| coverage/출처/예외/취소/재시도 | app의 read-only/epoch/동기 예외 회귀 |
| 한영·300px UI·공통 ghost/재시도 | toolbar와 Shell6종, 모든 공통 진단 번역 회귀 |
| Save As·기존 unknown/섹션 순서 | strict UNIT+정렬 건물의 fake gateway 저장 왕복 회귀 |
| 실제 로컬 자료·native MPQ | 선택 스모크. 게임/Windows 클릭 확인과 구분 |
| 지형/자원 거리/전력/크립/EUD/게임 | 미구현 또는 미검증. 전체 정상/자유 모드 완료 아님 |

## 5. 최적화와 주석

동시에 요청한 metadata 조회는 하나의 Future로 합친다. 숫자228개를 현재 설치/맵
epoch 동안 재사용하며 hover마다 프로세스나 그림 요청을 실행하지 않는다.
기존 UNIT 검사는 현재 typed view를 O(N)으로 순회하고 새로운 CHK 파싱은 하지 않는다.
알 수 없는 geometry는 거리만으로 제외할 수 없다는 이유, 최종 좌표 검사와
source/epoch 계약에 주석을 남겼다. 아직 collision index/256맵 profile 최적화는
하지 않았으며 FPS/메모리 개선 수치를 주장하지 않는다. 기존 class ID cache도 유지한다.

## 6. 실행·실패·결과 분석

원시 로그: ignored `.dart_tool/unit_overlap_*.log`. 실행 SDK는 Flutter3.47.5/
Dart3.13.4이며 저장소 기준3.44.8/3.12 재검증은 남는다.

- initial analyze의 컨트롤러 lint1개와 테스트 lint3개를 수정했다.
- initial focused216통과/7skip. 확대 실행에서 Shell의 신규 겹침 안내2개가 실패했다.
  포인터를 같은 스냅 cell로 추정하고 재선택 직후 이전 프레임의 canvas layout을
  사용한 잘못된 테스트 순서였다. 저장 좌표와 controller overlap을 명시적으로
  확인하고 재선택 후 프레임을 반영한 뒤 hover했다. 최종 Shell6/6통과.
- 동기적으로 던지는 gateway에서 pending이 남을 수 있는 경로를 소스 검토로
  발견했다. `Future.sync`와 pending 등록 후 알림 순서로 정리하고 연속2회 실패
  재시도 회귀1개를 추가했다.
- 실제 로컬 helper/CASC와 MPQ 선택 suite138통과. 새 로컬 collision snapshot으로
  배치/중복 거절/Undo를 확인했고 원본 자체 제작 MPQ를 보존했다.
  최종 동기 예외 수정 후에도 실제 로컬 배치/중복 거절/Undo 스모크1개를 다시
  통과했다(`unit_overlap_local_final.log`).
- 최종 전체1252통과/53skip, analyze No issues, Windows Debug 빌드 성공을 확인했다.
  중간 전체 실행은 화면 순서 결함으로2실패했고, 사용자 계속 진행 입력 시 실행
  중이던 재검증은 최종 성공 로그가 없어 인수 증거로 사용하지 않았다. 그 이후
  완주한 `unit_overlap_tests_complete.log`의 결과만 최종 전체 판정으로 사용한다.

이번 변경의 일반 신규 테스트는44개(domain21/catalog15/command8)다. 기존 Shell/
한영 toolbar/Save As/로컬 선택 시나리오도 확장했다. 모든 입력 fixture는 합성 또는
기존 자체 제작 파일이며 게임 자산을 저장소에 추가하지 않았다.

| 최종 검증 | 결과 |
| --- | --- |
| `flutter analyze` | No issues, `unit_overlap_analyze_complete.log` |
| `flutter test --concurrency=4` | 1252통과/53skip, `unit_overlap_tests_complete.log` |
| `flutter build windows --debug` | 성공, `unit_overlap_windows_complete.log` |
| Debug CTest | 7/7통과 |
| 전체 nonwrite format | 441파일 중 기존 미변경 infrastructure3파일 차이로exit1, `unit_overlap_format_complete.log` |
| 변경 Dart14파일 nonwrite format | 0변경, 통과 |
| Windows 직접 조작·SC:R·외부 에디터 | 미실행. 이전 UI 조작 중단을 유지하며 별도 허용 답변 없이 재개하지 않음 |

전체 format 차이는 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`에만
있다. 이번 변경 밖의 파일을 정규화하지 않았다. 기준 SDK/실제 게임 인수는 남는다.

다음 코드 단위는 CV5/VF4 건설·이동 가능성의 versioned read-only snapshot과
footprint 지형 검사다. 충돌 기반 바깥 영역/대규모 성능·자원 거리·전력/크립·EUD
변경·정상/자유 지원표 UI·게임/외부 에디터 인수는 별도로 이어간다.
