# 실제 설치 카탈로그 배치 검증

2026-09-18 Windows x64에서 로컬 `C:\Program Files (x86)\StarCraft`와
빌드된 `starcraft_data_helper.exe`로 선택적 자동 검증을 실행했다.
테스트: `test/application/placement_catalog_controller_test.dart`의
`local Tile catalog`, `local StarCraftPlacementKind.unit`,
`local StarCraftPlacementKind.pureSprite` 사례.

## 확인한 범위

- 실제 CASC 카탈로그·썸네일 gateway를 사용한다. Tile은 실제 타일 atlas,
  Unit/Sprite는 실제 객체 atlas를 읽는다.
- 자체 제작한 메모리 CHK는 Jungle 8×8이며 사용자 맵을 열거나 쓰지 않는다.
- 카탈로그를 읽고 항목을 선택하는 동안 원본 CHK 바이트가 유지된다.
- Tile의 첫 페이지에서 0이 아닌 배치 가능 타일을 선택해 (3, 2)에 칠한다.
- Unit/Sprite의 첫 페이지에서 배치 가능한 항목을 선택해 (96, 64)에 배치한다.
  생성 레코드의 종류 ID·좌표와 유닛 HP 100% 또는 pure sprite 플래그를 확인한다.
- 모든 사례에서 Undo는 원래 CHK 바이트를 정확히 복원하고 Redo는 변경 후
  바이트를 정확히 복원한다. Unit/Sprite는 두 번째 Undo도 확인한다.

실제 설치 관련 집중 테스트 5개 통과(기존 미리보기/무기 참조 사례 포함).
환경 변수가 없는 기본 테스트 실행에서는 추가한 3개 사례를 skip한다.
원시 게임 자산과 추출 이미지를 파일이나 저장소에 기록하지 않는다.

전체 기본 테스트는 647개 통과·19개 skip, 정적 분석 통과. 변경 파일 포맷은 통과했고
전체 검사에는 기존 infrastructure 테스트 4개의 차이가 남아 있다.
Flutter 3.47.2/Dart 3.13.2로 검증했으며 기준 SDK 검증은 수행하지 않았다.
이번 변경은 테스트·문서뿐이라 앱 재빌드와 화면 실행은 반복하지 않았다.

## 실행

```powershell
$env:STARCRAFT_TEST_INSTALLATION = 'C:\Program Files (x86)\StarCraft'
$env:STARCRAFT_DATA_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/starcraft_data_helper.exe').Path
flutter test test/application/placement_catalog_controller_test.dart --plain-name 'local'
```

## 남은 범위

이 검증은 앱의 카탈로그→명령→CHK→Undo/Redo 경로다. 실제 화면 클릭,
MPQ Save As/재열기 및 게임 실행을 검증한 것은 아니다. 모든 종류 ID나 타일셋을
망라하지 않으며 Doodad의 실제 recipe 기반 복합 배치도 남아 있다.
M6.2 실제 설치 스모크 항목은 부분 완료로 유지한다.
