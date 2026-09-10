# 설정 저장 검증 기록

## 자동 검증 범위

| 영역 | 바이트·보존 증거 |
| --- | --- |
| 맵 제목·설명 | object_editing_roundtrip_test: 공유 문자열을 분리하여 이름 추가, 기존 문자열과 원시 tail 보존 |
| 플레이어 | chk_player_settings_editor_test: 슬롯·종족·색상 범위와 미편집 슬롯 보존 |
| 세력 | chk_force_settings_editor_test: 공유 이름·예약 flags·원시 tail 보존 |
| 유닛·무기 | chk_unit_settings_editor_test: UNIS/UNIx 수치 golden bytes, 반대 버전 섹션·사용자 값 보존 |
| 생산 허용 | chk_unit_availability_editor_test: PUNI golden bytes, 예약 플레이어·알 수 없는 값 보존 |
| 업그레이드 | chk_upgrade_settings_editor_test: UPGS/UPGx·UPGR/PUPx offsets, UPGx 예약 byte 61·반대 버전 섹션 보존 |
| 테크 | chk_tech_settings_editor_test: TECS/TECx·PTEC/PTEx offsets, 미편집 값·반대 버전 섹션 보존 |

도메인 테스트는 `test/domain/chk/`, 통합 테스트는 `test/integration/`에 있다.
각 설정의 지원 범위와 입력 거부 정책은 해당 설정 설계 문서를 따른다.

## 실제 MPQ Save As

`object_editing_roundtrip_test.dart`의 `native MPQ` 사례는 기존 가짜 gateway
사례와 같은 편집·golden bytes·Undo/Redo·오래된 스냅샷 거부를 실제 저장 경로로
실행한다. `ProcessMapArchiveGateway`, 로컬 fingerprint와 로컬 Save As gateway를
사용하며, 별도 임시 디렉터리의 자체 제작 맵만 대상으로 한다.

- 합성 CHK를 기존 재배포 가능한 최소 아카이브에 넣어 입력 맵을 준비한다.
- 맵·플레이어·세력·유닛·생산 허용·업그레이드·테크와 객체 편집을 함께 적용한다.
- 한글·공백 경로로 Save As하고 임시 출력 검증·파일 승격·출력 재열기를 거친다.
- 재열린 CHK 전체가 요청한 출력 바이트와 같고 원본 MPQ 전체 바이트가 그대로인지 확인한다.
- 섹션 순서·XTRA·문자열 tail·설정별 예상 payload를 확인한다.
- 테스트 종료 시 자신이 생성한 임시 디렉터리만 정리한다.

실행:

```powershell
$env:MAP_ARCHIVE_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
flutter test test/integration/object_editing_roundtrip_test.dart
```

2026-09-10 Windows 로컬 실행: 가짜 저장·실제 MPQ 저장·배치 왕복 3개 통과.
Flutter 3.47.2 / Dart 3.13.2 사용. 기준 3.44.8 / 3.12는 미검증이다.
환경 변수가 없거나 Windows가 아니면 native MPQ 사례만 명시적으로 건너뛴다.

## 실제 SC:R 적용: 미검증

이 합성 맵은 저장 보존을 검증하기 위한 것이며 플레이 가능한 게임 검증 fixture가
아니다. 아카이브 재열기 성공을 로비·게임 동작 성공으로 취급하지 않는다.
현재 도구는 Windows 네이티브 앱의 화면 조작을 제공하지 않아 게임 내 확인을
이번 자동 검증에 포함하지 않았다. 다음 단계에서 플레이 가능한 자체 제작 맵과
아래 대조 시나리오를 준비하고, 실제 게임 결과를 관찰해 기록해야 한다.

| 영역 | 게임에서 비교할 결과 |
| --- | --- |
| 맵·플레이어·세력 | 제목·설명·슬롯·종족·색상, 세력 배정·동맹·시야·공동 승리·시작 위치 |
| 유닛·무기 | 이름·체력·실드·방어력·비용·생산 시간·기본/추가 피해량, 공유 무기 영향 |
| 생산 허용 | 플레이어 1/2의 허용 차이, 맵 기본값 상속과 개별 값 |
| 업그레이드 | 시작/최대 레벨, 초기 비용·시간과 단계 증가량, 기본값 복원 |
| 테크 | 허용·연구 완료·비용·연구 시간·에너지와 플레이어별 차이 |

실행 기록에는 게임 build, fixture/출력 해시, 변경 전후 값, 관찰 결과와 실패를
포함한다. 원본/확장 섹션 동시 존재 시 선택 규칙, 게임 수치 상한, 한글 인코딩도
별도 관찰이 필요하다. 모든 행의 실제 결과가 확보되기 전 M6.3을 완료로 표시하지 않는다.

전체 회귀: 527개 통과·8개 선택 스모크 건너뜀. 전체 실행에서는 기존 MPQ 스모크도
활성화되므로 MAP_ARCHIVE_TEST_MAP을 최소 fixture의 절대 경로로 설정했다.
정적 분석과 변경 파일 포맷 통과. 전체 포맷은 기존 테스트 4개의 차이로 실패한다.
앱/네이티브 코드는 변경하지 않아 Windows 빌드·실행은 이번에 반복하지 않았다.
