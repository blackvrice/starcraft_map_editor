# 무기·시작 업그레이드·클로킹 비교

첫 공중 유닛 수치 사례는 사용자 테스트 완료 보고를 받았다. 이번에는 같은 유닛 배치와
체력/실드/방어력을 유지하면서 레이스의 무기·업그레이드·클로킹을 비교한다.
이 사례의 실제 SC:R 결과는 아직 확인하지 않았다.

## 파일과 실행

- `build/manual-settings-combat/baseline.scx`
- `build/manual-settings-combat/modified.scx`

1. 두 파일을 게임의 Maps 폴더에 복사하고 **Use Map Settings(맵 설정 사용)**으로 각각 연다.
2. Player 1로 시작해 레이스(픽셀 224, 224)를 선택한다. 화면 제목은 기존과 같은
   Settings Air Stats이므로 파일 이름·폴더로 구분한다.
3. 무기 아이콘의 공격력/업그레이드 표시와 클로킹 사용 가능 여부를 비교한다.
4. 변경 맵에서 에너지가 충분할 때 클로킹을 켜고 시작 시 에너지 변화를 관찰한다.
5. 공중 공격 동작은 오른쪽 아래의 컴퓨터 오버로드(800, 640)로 확인할 수 있다.
   피해 유형·방어·재생을 고려해야 하므로 실제 HP 감소를 단순 합계와 동일하다고 단정하지 않는다.
6. 승리/패배 트리거가 없으므로 확인 후 게임을 종료한다.

| 설정 | 기준 맵 | 변경 맵 |
| --- | --- | --- |
| Gemini Missiles #15 기본 / 레벨당 추가 피해 | 20 / 2 | 32 / 4 |
| Burst Lasers #16 기본 / 레벨당 추가 피해 | 8 / 1 | 12 / 2 |
| Terran Ship Weapons #9 맵 시작 / 최대 레벨 | 0 / 3 | 2 / 3 |
| Player 1 업그레이드 | 맵 레벨 상속 | 맵 레벨 상속 |
| Player 2 업그레이드 | 개별 시작·최대 0 유지 | 동일 |
| Cloaking Field #9 맵 허용 / 연구 완료 | 허용 / 미완료 | 허용 / 완료 |
| Player 1 테크 | 맵 설정 상속 | 맵 설정 상속 |
| Player 2 테크 | 개별 허용·연구 완료 0 유지 | 동일 |
| Cloaking Field 에너지 설정 | 25 | 10 |

변경 맵의 공격력 계산 목표는 공중 `32 + 4×2 = 40`, 지상 `12 + 2×2 = 16`이다.
게임 UI가 기본값과 추가분을 분리 표시할 수 있으므로 원문 표시를 기록한다.
클로킹의 최초 비용 설정과 활성화 후 지속 에너지 소모는 구분해서 확인한다.

Player 2는 컴퓨터다. 해당 플레이어의 원시 값 보존은 자동 검증했지만 UI·조작 검증을
완료한 것으로 보지 않는다. 이 맵에는 생산·연구 시설이 없어 비용/시간·생산 허용은
검증하지 않는다. 스카웃은 이전 수치 비교의 배치를 유지하며 이번 전투 대상이 아니다.

## 결과 기록

- 게임 build / 실행일:
- 기준·변경 파일의 로비 진입 / 게임 시작:
- 레이스 무기 표시: 기준 → 변경
- 업그레이드 레벨 표시: 기준 → 변경
- 클로킹 사용: 기준 → 변경
- 변경 맵 클로킹 직전/직후 에너지와 이후 변화:
- 오버로드 공격 동작 / 이상 증상:

## 재생성·검증

```powershell
$helper = (Resolve-Path 'build/windows/x64/runner/Debug/map_archive_helper.exe').Path
dart run tool/generate_settings_smoke_fixture.dart --helper $helper --output <새경로>/baseline.scx --combat
dart run tool/generate_settings_smoke_fixture.dart --helper $helper --output <새경로>/modified.scx --combat --modified
$env:MAP_ARCHIVE_HELPER_PATH = $helper
flutter test test/fixtures/settings_game_smoke_test.dart test/fixtures/generated_map_fixture_test.dart
```

앱의 ChkUnitSettingsEditor·ChkUpgradeSettingsEditor·ChkTechSettingsEditor를 사용해
설정을 적용한다. 두 비교 맵 사이의 UNIx/PUPx/TECx/PTEx 예상 바이트와 나머지 섹션
동일성, Player 2 값 보존, 실제 MPQ 생성·재열기를 검증한다. 기존 공중 수치 사례와
EUD fixture 생성은 유지한다. 출력이 이미 있으면 덮어쓰지 않는다.

2026-09-14 생성 SHA-256:

| 파일 | MPQ SHA-256 |
| --- | --- |
| baseline.scx | `001b6dbf8b89f6b5ef654ff4f2be6c0080a0de3d8b2136a49017075608cd6bb8` |
| modified.scx | `00a1f6a22fb144d25a4c93b2c58bc69675f9b5da08521c07d0da5828807044e7` |

CHK SHA-256 (아카이브 메타데이터와 독립적으로 비교):

- baseline: `bf45cd3da2ef9799117aef06422d7af548a435779d7dad540cd0c8789ed50676`
- modified: `c2012985636a8584db2890b00d02e33225263740d0be522cfce1cfd9f7c865ed`
