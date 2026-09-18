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

실제 설치 관련 집중 테스트 6개 통과(기존 미리보기/무기 참조 사례 포함).
환경 변수가 없는 기본 테스트 실행에서는 배치 검증 4개 사례를 skip한다.
원시 게임 자산과 추출 이미지를 파일이나 저장소에 기록하지 않는다.

Tile/Unit/Sprite 추가 당시 전체 기본 테스트는 647개 통과·19개 skip, 정적 분석 통과. 변경 파일 포맷은 통과했고
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
망라하지 않는다. M6.2의 선택적 실제 설치 배치 스모크는 아래 Doodad 사례를
포함한 자동 검증 범위로 완료한다. 게임 실행이나 기존 Doodad 복합 삭제의
완료를 의미하지 않는다.

## Doodad 복합 배치 후속 검증

2026-09-18 실제 Jungle 카탈로그 첫 페이지(최대 256개)에서 overlay가 있는
검증된 recipe를 선택한다. 자체 제작 32×32 메모리 CHK의 (2, 2)부터 recipe의
requiredTileGroup에 맞는 합성 바닥 지형을 준비한다. 이는 실제 게임에서 자연스럽게
이어지는 지형을 제작한 맵이 아니며, 복합 편집 명령의 조건과 원자성을 확인한다.

- 실제 gateway → controller 카탈로그 → 선택 → 배치 경로를 통과한다.
- 경계 밖 배치는 CHK 바이트와 Undo 깊이를 바꾸지 않는다.
- 정상 배치는 기존 DD2 레코드를 유지하며 새 Doodad 한 개와 THG2 한 개를 추가한다.
  종류 ID·중심 좌표·overlay 의미가 실제 recipe와 일치하는지 확인한다.
- MTXM 전체 배열을 비교해 footprint의 쓰기 셀만 변경됐는지 확인한다.
- Undo 깊이는 1이며 한 번의 Undo로 원본 CHK가 정확히 복원되고 새 THG2 섹션도
  제거된다. Redo는 세 섹션을 포함한 변경 후 CHK 바이트를 정확히 재현한다.

게임 자산이나 추출 이미지는 저장하지 않는다. 이 Doodad 사례는 recipe와 복합
명령을 검증하며 Doodad 썸네일 렌더링·전체 타일셋·겹침·기존 객체 삭제는 포함하지 않는다.

Doodad 추가 후 전체 기본 테스트는 647개 통과·20개 skip, 정적 분석 통과.
실제 설치 관련 집중 6개는 별도 통과했다. SDK·기존 포맷 차이와 이번 변경에서
앱 재빌드/화면 실행을 반복하지 않은 범위는 위와 같다.
