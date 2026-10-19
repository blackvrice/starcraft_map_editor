# 두다드 복합 삭제 지원 확대

2026-10-19. 첫 미완료 M6.2 항목의 **미지원 사례 확대** 중 비활성 두다드의
검증된 단일 삭제를 구현했다. 실제 게임/외부 에디터 왕복과 더 넓은 미지원 입력은
미완료로 유지한다. [ADR-0026](decisions/0026-disabled-doodad-deletion.md).

## 계획과 소스 분석

1. 기존 삭제 계획/배치 정의/상태 편집/복합 clipboard/확인 창을 분석한다.
2. 활성 상태로만 제한하던 삭제 검사를 알려진 DD2 0/1 상태로 확장한다.
3. THG2의 정확한 상태 플래그를 UI 후보와 domain에서 같은 규칙으로 검증한다.
4. 거부/바이트 보존·Undo/Redo·한국어/영어 UI·실제 MPQ 왕복과 전체 게이트를 검증한다.

기존 `ChkBasicEditing.setDoodadEnabled`와 복합 clipboard가 이미 DD2 비활성=1,
sprite-unit의 THG2 bit15를 지원한다. 삭제 계획은 DD2=0과 활성 THG2만 허용해
일관된 비활성 입력도 거부했다. 상태 편집이 삭제 계획을 호출하므로 삭제 쪽에서
상태 편집 함수를 호출하면 재귀가 된다. 원문을 활성 상태로 정규화하는 우회 대신
`DoodadOverlayRecipe.flagsForEnabled`에 플래그 계산만 두고 원래 문서에서 검증한다.
순수 스프라이트와 유닛형 오버레이의 차이는 코드 주석으로 명시했다.

새 검사는 상수 시간의 상태/플래그 대조이며 기존 footprint/복원/section 검사를
그대로 사용한다. 추가 전체 문서 복사나 별도 parser/의존성을 도입하지 않았다.
기존 선형 스캔의 인덱스화는 이 작은 변경에서 이익이 확인되지 않아 보류했다.
성능 수치 개선이나 게임 동작을 측정했다고 주장하지 않는다.

## 현재 계약

| DD2 값 | overlay 없음 | pure sprite | sprite-unit |
| --- | --- | --- | --- |
| 0 활성 | 지원 | THG2 flags `0x1000`만 | THG2 flags `0x0000`만 |
| 1 비활성 | 지원 | THG2 flags `0x1000`만 | THG2 flags `0x8000`만 |
| 나머지 | 거부 | 거부 | 거부 |

유효한 단일 DIM/ERA/MTXM/DD2/TILE, 일치한 로컬 recipe/footprint/현재 지형,
검증된 TILE 복원 값이 필요하다. 인근 두다드와 겹칠 가능성은 계속 거부한다.
overlay가 있으면 단일 THG2와 **사용자가 선택한** record의 종류/좌표/owner/
flags/unused가 모두 일치해야 한다. 후보가 한 개여도 자동 선택하지 않는다.
좌표가 같은 다른 레코드나 알 수 없는 플래그를 추측해 정리하지 않는다.

삭제는 MTXM 복원·대상 DD2·확인한 THG2만 한 명령으로 바꾼다. TILE과 다른
레코드/원시 섹션은 유지하며 한 Undo로 복원한다. 준비 이후 문서 변경 또는
필수 레이어 잠금은 적용을 막는다. 다중/혼합 선택·TILE 부재·불일치 상태는 미지원이다.
비활성 DD2에 활성 유닛형 overlay가 남은 불일치 입력도 자동 보정하지 않는다.

확인 창은 대상 DD2 인덱스/종류/원시 상태와 recipe를 표시한다. 한영으로 번역하고
overlay 귀속 선택 전에는 삭제를 비활성화한다. 취소는 맵과 Undo를 바꾸지 않는다.

## 요구사항과 실행 결과

| 요구사항 / 시나리오 | 기대 결과 | 검증 |
| --- | --- | --- |
| FR-203/213 단일 복합 삭제 | 한 Undo/Redo, 다른 객체 보존 | application |
| FR-204/217/218 상태·geometry·복원 정보 | 알려진 일관 상태만 지원, 거부 시 무변경 | domain 13개 |
| FR-203 명시적 overlay 귀속·취소 | 자동 선택 없음, 같은 좌표의 미선택 레코드 보존 | domain/UI |
| NFR-008 한국어 600px/영어 1200px | 문구/버튼 잘림·예외 없음, 확인·취소 가능 | widget |
| FR-101/102/104 실제 MPQ 저장/재열기 | 삭제 결과 bytes 유지, 원본 불변 | 실제 helper 3개 |

- 수정 전 새 domain 테스트는 **9 통과/3 실패**였다. 비활성 3종만 기존 상태
  검사에 걸리는 것을 `.dart_tool/doodad-delete-before.log`로 재현했다.
- 수정 후 domain/상태/clipboard 집중 검사는 15개 통과했다. 이후 geometry/섹션/
  overlay 거부 행렬을 추가한 domain 13개 + 실제 MPQ 3종은 **16개 모두 통과**했다.
  `.dart_tool/doodad-delete-roundtrip.log`.
- 기존 객체 배치/삭제 + 새 비활성 명령 3종/한영 UI 2종 **135개 통과**.
  `.dart_tool/doodad-delete-application.log`.
- 정적 분석에서 테스트 제어문 중괄호 1개를 지적하여 형식 수정 후 재실행했다.
- `flutter analyze`: 무이슈.
- `flutter test`: **2586 통과 / 83 조건부 skip / 실패 0**.
  `.dart_tool/doodad-delete-full-tests.log`. 새 실제 MPQ 3개는 기본 실행에서 환경
  변수 미설정으로 skip되며 위 별도 실행에서 모두 통과했다. 기존 조건부 skip도
  성공으로 계산하지 않는다.
- Windows Debug 빌드 성공, native CTest **7/7 통과**.
  `.dart_tool/doodad-delete-windows-build.log`.
- 필수 `dart format --output=none --set-exit-if-changed lib test tool`은 exit 1.
  기존 미수정 `test/infrastructure/local_map_save_file_gateway_test.dart`,
  `process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`
  3개만 차이가 있으며 이번 변경 파일은 차이가 없다. 관련 없는 파일은 변경하지 않았다.
- 실제 SDK는 **Flutter 3.47.5 / Dart 3.13.4**, 기준 3.44.8/3.12와 다르다.
  기존 CascLib CMake 최소 버전 경고는 빌드 성공을 막지 않았다.

사용자의 자동 테스트·빌드 한정 지시에 따라 실제 열린 앱, SC:R, 외부 에디터를
조작하지 않았다. byte-exact MPQ 왕복은 게임/외부 상호 운용 인수 완료가 아니다.
