# 공중 유닛 설정 게임 검증 — 첫 번째 비교 사례

## 실행 파일

생성 위치: `build/manual-settings-air-stats/baseline.scx`, `modified.scx`.
두 맵은 같은 지형·배치·플레이어를 사용하고 UNIx의 레이스/스카웃 설정만 다르다.
실제 SC:R 실행은 아직 관찰하지 않았다. 맵 로딩 실패도 검증 결과로 기록한다.

1. 두 파일을 StarCraft에서 선택할 수 있는 Maps 폴더에 복사한다.
2. 사용자 지정 게임에서 **Use Map Settings(맵 설정 사용)**으로 baseline.scx를 연다.
3. Player 1로 시작한다. Player 2는 컴퓨터이며 AI·승리/패배 트리거는 없다.
4. 시작 위치 오른쪽 아래의 레이스, 스카웃, 사이언스 베슬을 각각 선택해 수치를 기록한다.
5. 게임을 나와 modified.scx를 같은 방식으로 실행하고 아래 예상 결과와 비교한다.

| 선택 유닛 | 위치 (맵 픽셀) | 변경 맵 예상 수치 |
| --- | --- | --- |
| 레이스 (Wraith #8) | 224, 224 | 최대 체력 240, 방어력 3 |
| 스카웃 (Scout #70) | 352, 224 | 최대 체력 300, 최대 실드 200, 방어력 4 |
| 사이언스 베슬 (#9) | 480, 224 | 기준 맵과 동일한 게임 기본값 |
| 컴퓨터 오버로드 (#42) | 800, 640 | 기준 맵과 동일한 게임 기본값 |

지형의 지상 이동/건설 적합성을 이 사례의 전제로 삼지 않도록 공중 유닛만 배치했다.
이 맵은 선택 화면의 체력·실드·방어력 확인용이다. 기본 생산 허용과 연구 상태는
열지 않았으며, 사용자 값으로 전환한 유닛의 비용/시간 및 무기 피해량 필드는 0이다.
전투·생산·연구 검증에는 이 사례를 사용하지 않는다. 해당 설정들은 별도 사례로 준비한다.
승리 조건이 없으므로 확인 후 메뉴에서 게임을 종료한다.

## 결과 기록

- 게임 build / 실행일:
- baseline 로비 진입 / 게임 시작: 성공 또는 오류 메시지
- modified 로비 진입 / 게임 시작: 성공 또는 오류 메시지
- 레이스: 기준 HP/방어력 → 변경 HP/방어력
- 스카웃: 기준 HP/실드/방어력 → 변경 HP/실드/방어력
- 사이언스 베슬/오버로드: 기준과 동일 여부
- 스크린샷 또는 관찰한 차이:

위 결과를 알려주면 적용 실패와 표시 차이를 분석한다. 아직 관찰하지 않은 행을
완료로 표시하지 않으며, M6.3의 전체 게임 검증은 계속 미완료다.

## 재생성·자동 검증

```powershell
$helper = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
dart run tool/generate_settings_smoke_fixture.dart --helper $helper --output <새경로>/baseline.scx
dart run tool/generate_settings_smoke_fixture.dart --helper $helper --output <새경로>/modified.scx --modified
$env:MAP_ARCHIVE_HELPER_PATH = $helper
flutter test test/fixtures/settings_game_smoke_test.dart test/fixtures/generated_map_fixture_test.dart
```

기존 출력은 덮어쓰지 않는다. 기존 EUD 컴파일 fixture 생성 결과는 변경하지 않았다.
전체 CHK 비교, 예상 UNIx 바이트, 시작 위치·유닛 ID·대조 유닛 기본값과 실제 MPQ
생성/재열기를 검증했다. 이 자동 검증은 게임 엔진 실행을 대신하지 않는다.
VCOD의 표준 데이터는 [Chkdraft chk.h](https://github.com/TheNitesWhoSay/Chkdraft/blob/master/src/mapping_core/chk.h)
의 seed/opcode를 대조했다. [MIT 고지](licenses/Chkdraft.txt)를 포함한다.
게임 원시 그래픽 자산이나 타인의 맵은 포함하지 않는다.

2026-09-13 생성한 파일 SHA-256:

- baseline.scx: `f915c13922f06b7125afb52e409200bc507510cd6b8d4917727104df1a6b12d2`
- modified.scx: `da3f40435e7463a198e7f02440e28dfc9dd7952b7244b463d5142e151a7e1152`

아카이브 메타데이터 때문에 재생성한 MPQ 해시는 달라질 수 있다. CHK SHA-256:

- baseline: `51d610c4ceccb0d986eb6053ef807ae82e54a5b2b06f7906354019eaad47ccc4`
- modified: `8a8cf42a1a4f0cb6ad56513a3a60ec0d7ec0203ef136ff14f2f8e9a6b07a0e7e`
