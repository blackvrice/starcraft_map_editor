# 사용자 지형 브러시

## 요구사항과 실행 계획

2026-10-17 EP4 / FR-220. 기존 raw MTXM clipboard와 ISOM diamond/region
solver를 재사용하여 브러시 metadata 저장·다른 문서 재사용·검증된 대칭을
구현한다. 게임/외부 에디터 인수와 전체 잔여 기능 완료는 별도 판정한다.

1. 소스 분석: raw clipboard, mixed clipboard, ISOM paint/catalog, 공통 Undo,
   여러 문서 수명과 I/O 계층을 점검한다.
2. 설계: raw/ISOM을 분리한 schema v1, 크기 예산, 설치 자료 revision,
   append-only 저장과 미리보기/명시적 Apply를 정의한다.
3. 실행: domain 모델, application 제어기/공유 보관함, 저장 포트/로컬 구현,
   기본 편집 도구의 사용자 지형 브러시 탭, 한영 UI를 연결한다.
4. 검증: 손상 입력·자료/문서 변경·잠금·저장 실패·좁은 화면·Undo와 실제
   자체 제작 MPQ Save As/재열기를 자동 테스트한다.

## 지원표

| 프로필 | 저장·재사용 | 좌우/상하 대칭 | 변경/보존 |
| --- | --- | --- | --- |
| raw | ISOM 없는 동일 타일셋 맵 | 미지원, UI 비활성 및 domain 거절 | MTXM만 변경, TILE/unknown/객체 보존 |
| ISOM | 같은 catalog revision의 검증된 완전 diamond 영역 | 검증된 평지 shape만 | 기존 solver로 ISOM/TILE/MTXM 재검증 |
| 전환/경계 ISOM | 검증된 shape 저장·일반 재사용 | 방향 대응 자료가 없으면 거절 | solver 실패 시 전체 무변경 |
| 경사로/두다드 | v1 보관함 미지원 | 미지원 | DD2가 있는 맵은 보관함 capture/paste 거절 |

기존 혼합 clipboard의 검증된 DD2/overlay/raw·ISOM 복사와 맵 간 전송은 그대로
사용한다. 보관함 지원표를 이유로 기존 편집 기능을 제거하지 않았다.
ISOM/raw 자동 변환과 타사 브러시 포맷, raw 타일의 그림 방향 추측은 하지 않는다.

## 데이터 계약

- `UserTerrainBrush` schema v1: 이름(1~80자), profile, tileset 0~7,
  revision, width/height 1~256, raw uint16 배열 또는 상대 diamond/shape 배열.
- raw revision은 `raw-mtxm-v1` 포맷 계약이며 게임 자산/렌더링 검증을 뜻하지
  않는다. ISOM revision은 로컬 catalog revision과 정확히 같아야 한다.
- ISOM 영역과 대상은 x/width 4타일, y/height 2타일 정렬이다. 모든 완전한
  내부 diamond를 저장한다. 누락/중복/범위 밖/미등록 shape는 거절한다.
- 1개 UTF-8 파일 512 KiB, 보관함 64개/4 MiB. 초과 시 기존 브러시를 지우지
  않고 거절한다. 알 수 없는 버전/필드/손상 파일도 조용히 무시하지 않는다.
- game image, CV5 원본, 전체 CHK, 객체/리소스/실행 소스는 저장하지 않는다.
- 좌우 반사는 상대 diamond x를 `width/2-x`, 상하 반사는 y를 `height-y`로
  옮긴다. 검증된 평지 shape와 기존 연결 검증을 사용하며 raw ID를 뒤집지 않는다.

## 저장과 수명

`TerrainBrushStore` 포트 뒤 `LocalTerrainBrushStore`가
`%LOCALAPPDATA%/blackvrice/StarCraftMapEditor/brushes`를 사용한다.
파일명은 이름의 소문자 UTF-8 SHA256이다. 이름을 경로로 사용하지 않는다.
공유 `TerrainBrushLibrary`가 여러 맵의 요청을 직렬화하고 파일 잠금으로 로컬
변경을 보호한다. 정규 디렉터리/파일·링크 이탈과 크기를 확인한다.

추가는 새 임시 디렉터리에 flush → 다시 읽기/검증 → 새 파일로 rename한다.
기존 동일 이름(대소문자 포함 충돌)은 덮어쓰지 않는다. 삭제는 UI 확인 뒤
명시적으로 수행한다. 중단된 임시 디렉터리는 저장된 브러시로 취급하지 않는다.
브러시 저장/삭제는 맵 dirty/Undo에 영향을 주지 않는다.

`UserTerrainBrushController`는 현재 문서 session/자료 identity와 레이어 잠금,
진행 작업/트랜잭션/폐기를 검사한다. 이미 발급한 현재 미리보기만 Apply하고
한 번의 공통 Undo에 기록한다. 문서 변경이나 재로드 후에는 재미리보기가 필요하다.
저장된 payload는 원본 문서가 닫힌 뒤에도 같은 지원 프로필에서 재사용할 수 있다.

## 소스 분석과 최적화

raw는 기존 clipboard의 검증·복사를 재사용한다. ISOM도 새 solver를 만들지
않고 기존 paint/region solver를 사용한다. 반사 좌표식과 의미상 무변경 처리에
짧은 계약 주석을 추가했다.

ISOM 의미가 같으면 기존 랜덤 타일 member를 보존해 불필요한 재생성과 Undo를
피한다. 결과 비교에서도 동일한 섹션 객체는 payload 복사/비교를 생략한다.
대용량 성능/RSS 예산과 실제 게임 보이는 결과는 별도 인수 대상이다.

## 테스트 체크리스트

- [x] raw/ISOM encode/decode 및 숫자/버전/크기/diamond 검증
- [x] raw 원본/unknown 중복/객체/TILE 보존, bounds/타일셋/두다드 거절
- [x] ISOM 자료 revision/정렬·평지 대칭·미확인 방향 거절
- [x] 의미상 무변경 시 랜덤 타일 변형과 문서 identity 보존
- [x] 저장/재실행 로드·대소문자 이름 충돌·실패 후 재시도·명시적 삭제
- [x] 손상/미지원 파일 무시 금지·용량 초과 시 기존 보관함 보존
- [x] 문서 교체/잠금/숨김/트랜잭션·늦은 자료 로드/폐기·자산 변경 거절
- [x] 600px/1200px 한국어 UI 저장·선택·읽기 전용 preview·Apply·Undo·삭제 확인
- [x] 실제 helper raw/ISOM 지형 변경·Undo/Redo·MPQ Save As/재열기·입력 해시 보존
- [ ] 실제 앱 수동 조작, 게임/타사 에디터 왕복, clean Windows/DPI 인수

## 실행 결과

집중 테스트 6개 파일 20개 시나리오 중 **19개 통과/1개 조건부 skip**이다.
실제 MPQ 왕복 2개는 통과했고, 심볼릭 링크 생성 권한이 없어 링크 경로 거절
테스트 1개는 skip으로 표시했다. 이를 성공으로 집계하지 않는다.
정적 분석 무이슈, Windows Debug 빌드, native CTest 7/7을 확인했다.
전체 `flutter test`는 **2,284개 통과/72개 조건부 skip**이다. 실행 순서는
집중 회귀 → 전체 회귀 → format/analyze → Windows 빌드 → native CTest →
최종 집중/전체 회귀였으며, 테스트 실행 중 앱 수동 조작은 하지 않았다.
전체 format 검사는 기존 변경하지 않은 인프라 테스트 3개 파일 차이로 exit 1이며
이번 변경 파일의 포맷 차이는 없다. build의 기존 third-party CMake 최소 버전
경고는 유지한다.
자동 테스트는 사용자 변경이 남아 있는 공유 작업 트리에서 실행했으므로,
깨끗한 체크아웃의 기준 SDK CI 통과로 대체하지 않는다. 관련 문서 6개의
상대 링크 192개는 경로 존재 검사를 통과했다.

실행 중 초기 import 위치 오류는 컴파일 실패로 검출해 수정했고, 600px 위젯
테스트의 아직 생성되지 않은 목록 항목 탐색 실패는 `scrollUntilVisible` 후
검사하도록 테스트를 수정했다. 수정 후 두 화면 크기에서 모두 통과했다.
기준 Flutter 3.44.8/Dart 3.12와 달리 이번 환경은 Flutter 3.47.5/Dart 3.13.4다.
실제 앱 조작은 사용자의 자동 테스트·빌드만 진행 결정을 유지했다.
이 기능은 보관함 지원 프로필의 구현이며 FR-219 overlay, EP5 언어/소스,
EP6 출력/출시와 미지원 방향 변환의 완료를 뜻하지 않는다.
