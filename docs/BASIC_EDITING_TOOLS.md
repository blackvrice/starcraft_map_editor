# 기본 편집 도구

2026-10-01 구현. Edit → 기본 편집 도구 또는 Map 화면의 Ctrl+Shift+E로 연다.
배치 객체 속성과 전역 Map Settings/EUD 설정은 별개다. 변경은 기존 Save As 경로로
저장하며 EUD 빌드를 필요로 하지 않는다.

## 현재 지원

| 도구 | 동작과 보존 계약 |
| --- | --- |
| 초기 안개 | 플레이어 1~8 표시, 브러시·사각형·전체 채우기. MASK에서 선택한 비트만 변경하며 다른 플레이어는 보존한다. 없는 MASK의 편집 초깃값은 모두 숨김(255)이다. |
| 유닛 일괄 속성 | 동일 레이어 선택에 소유자·체력/실드/에너지 비율·자원·격납량을 적용한다. 빈 입력은 유지한다. 상태 5종은 유지/명시적 On/Off/기본값 상속을 구분한다. 수치 변경은 해당 valid-field 비트도 설정한다. |
| 시작 위치 | Unit ID 214의 플레이어별 목록·선택·배치/이동, 캔버스 좌표 입력, 누락·중복 표시. 같은 소유자의 중복은 자동 정리하지 않는다. |
| 로케이션 | 이름/ID 검색·목록 선택, 지상/공중 6개 고도 비트와 선택 로케이션 일괄 적용. 이름·경계·알 수 없는 상위 고도 비트는 보존한다. |
| Sprite | 소유자 일괄 변경과 sprite-unit 비활성(0x8000). pure sprite에는 이 상태를 적용하지 않으며 종류/DrawAsSprite 변환은 지원하지 않는다. Doodad overlay 가능성은 별도 경로로 보낸다. |
| Doodad | 로컬 recipe와 footprint·TILE·overlay를 명시적으로 검증한 단일 복합 객체의 활성/비활성. DD2 활성은 0, 비활성은 1이다. sprite-unit의 THG2 비활성도 함께 바꾼다. pure sprite는 DD2 편집기 상태만 변경한다. |
| Addon/Nydus | 호환 종류·동일 소유자·고유 class ID를 검증한 상호 연결/해제. 관계가 있는 유닛은 함께 이동하거나 해제 후 속성을 변경한다. 삭제는 남는 상대 참조를 함께 해제한다. 일반 템플릿 복제는 연결 유닛·시작 위치를 거부하고 새 class ID를 할당한다. |
| 객체 clipboard | 같은 문서의 유닛·Sprite·로케이션 복사/자르기/붙여넣기. 유닛 관계 쌍을 함께 복사하면 새 ID와 상대 참조를 재매핑한다. 로케이션은 빈 슬롯을 사용하고 문자열 ID·고도를 보존한다. Anywhere·시작 위치·불명확한 overlay는 거부한다. |
| Raw 지형 clipboard | 사각형 타일 좌표 선택, MTXM 복사/자르기/붙여넣기. 자르기 채움은 현재 맵에 존재하는 raw 타일만 허용한다. TILE/ISOM을 변경하거나 지형 경계를 계산하지 않으며 Doodad가 있는 맵은 거부한다. |
| Doodad clipboard | 별도 복합 탭에서 recipe·overlay를 지정한 단일 객체를 복사/자른다. 대상의 아래 지형과 타일셋·배치 조건을 검증하고 MTXM/DD2/THG2를 한 번에 적용한다. 자르기는 TILE 아래 지형을 복원하고 overlay를 제거한다. 불명확한 인접 footprint·상태 불일치는 거부한다. |
| 탐색 | 미니맵 클릭/드래그로 화면 이동, viewport 표시. Alt 클릭은 현재 표시/잠금 상태에 맞는 겹친 객체를 순환 선택한다. 캔버스 초점에서 V/B/R은 선택/브러시/사각형, Esc는 진행 중 브러시·사각형 취소다. |

Ctrl+C/X는 Map 화면에서 선택 객체 복사/자르기, Ctrl+V는 위치를 지정하는 clipboard
화면을 연다. 텍스트 입력과 EUD 소스 탭의 기본 단축키를 가로채지 않는다.
Clipboard는 메모리에만 두고 문서 원본 snapshot이 바뀌면 사용할 수 없다.
문서 간 붙여넣기와 운영체제 clipboard 연동은 지원하지 않는다.

## 원자성·안전

`ChkBasicEditing`, 객체/Raw 지형/복합 Doodad clipboard는 파일·Flutter·프로세스에
의존하지 않는다. `BasicEditingController`는 현재 문서와 선택·레이어·작업 상태를
검증한 뒤 typed view와 객체 참조를 재검증한다. UI는 이 컨트롤러와 기존 로컬
카탈로그 포트만 사용한다.

안개 브러시는 별도 초안으로 미리보기하며, 완료할 때 한 개의 공통 Undo 명령을
기록한다. Esc·닫기는 초안을 버리고 Redo를 보존한다. 다른 편집/Save As가 활성
브러시에 끼어들지 못한다. 실패·범위 오류·오래된 문서·중복/손상 섹션·보호 맵은
문서와 기록을 변경하지 않는다. 변경이 없는 값은 새 명령을 만들지 않는다.

다른 섹션·중복 미지 섹션·원시 문자열·알 수 없는 상태/고도/flags 비트는 보존한다.
관계 flags의 알 수 없는 값은 연결/해제·삭제 과정에서 추측하지 않는다.
연결 가능한 종류와 플래그는 [고정 CHK 구조](https://raw.githubusercontent.com/TheNitesWhoSay/Chkdraft/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h)를
근거로 확인했다. 이 근거는 런타임 게임 동작 관찰을 대신하지 않는다.

## Doodad 활성값 정정

기존 recipe/helper는 DD2 활성값을 1로 생성했다. 위 고정 구조의 Enabled=0,
Disabled=1을 확인하여 도메인·native recipe·가짜 helper를 0으로 정정했다.
helper 0.10.1, wire protocol 3으로 기록하며 이전 맵을 열 때 자동 재작성하지 않는다.
기존 DD2=1/활성 overlay 조합은 명시적 활성 적용으로 정리할 수 있다.
상태가 서로 다른 composite 복사는 먼저 명시적 활성 적용을 요구한다.

## 남은 별도 범위

등각 지형의 경계·적층·경사로 solver/선택 브러시와 ISOM·Doodad resize는
[등각 지형 계약](ISOMETRIC_TERRAIN.md), [크기 변경](MAP_RESIZE.md)의 후속 작업이다.
다수 Doodad를 섞은 복합 선택과 미지원 Sprite 의미 변환은 제공하지 않는다.
불명확한 footprint/overlay를 복구하거나 추측하지 않는다.
실제 SC:R과 외부 에디터에서 상태·연결·안개·Doodad를 확인하는 인수는 별도다.

## 검증

2026-10-01 작업 트리에서 다음을 확인했다. 사용자 미커밋 설정 테스트도 포함된
결과이며 원격 CI·게임 인수 결과는 아니다.

- `flutter test --concurrency=2`: 863개 통과, 환경 변수 없는 선택 검증 37개 skip.
  이전 전체 실행은 테스트 로드 중 Dart VM의 UTF8 내부 오류로 종료됐고 재실행은 통과했다.
- 별도 순차 실제 스모크 17개 통과: native MPQ Save As/재열기·원본 보존,
  로컬 SC:R build 13515의 8개 타일셋·Doodad recipe/overlay 및 평지 렌더.
  CASC 동시 열기 실패는 `--concurrency=1`로 재검증했고 MPQ fixture는 절대 경로로 지정했다.
- 7개 기본 도구 UI 탭, Esc/탭 이동 시 안개 초안 취소, 비트/바이트 보존,
  관계/복제 ID, Doodad 아래 지형/활성 상태, 미니맵 오편집 방지와 공통 Undo/Redo 통과.
- `flutter analyze` 무이슈, 변경 Dart 38개 포맷 통과, Windows debug 빌드·시작,
  최종 native CTest 6개 통과. 기존 CascLib CMake deprecation 경고는 남아 있다.
- 전체 비쓰기 format 게이트는 기존 infrastructure 테스트 3개
  (`local_map_save_file_gateway`, `process_eud_compiler_gateway`, `process_map_archive_gateway`)의
  차이로 실패했다. 해당 무관한 파일은 보존했다.
- 사용 SDK는 Flutter 3.47.5/Dart 3.13.4다. 기준 3.44.8/3.12, 실제 게임/외부 에디터 인수,
  이번 미니맵을 포함한 Windows profile 성능은 미검증이다.

검증용 맵은 합성 fixture와 임시 MPQ이며 플레이 가능한 게임 인수 맵을 대신하지 않는다.
SC:R 원시 자산·추출 이미지는 저장소나 배포물에 추가하지 않았다.
