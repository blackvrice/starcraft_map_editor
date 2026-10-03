# 기본 맵 에디터 기능 대조표

2026-10-03 검증 갱신. New Map·raw resize·평지 채우기와
[기본 편집 도구](BASIC_EDITING_TOOLS.md)의 현재 지원을 반영한다.
정적 코드·테스트·기존 검증 기록의 대조이며 실제 게임을 다시 실행한 기록은 아니다.

## 판정 기준

구현, 자동 테스트, 실제 도구 컴파일, 게임 관찰, 배포 인수를 구분한다.
기능을 편집·저장할 수 있다는 이유로 전체 게임 호환성 완료를 표시하지 않는다.
상세 일정·체크박스는 [개발 계획](DEVELOPMENT_PLAN.md)이 기준이다.

## 현재 기능과 남은 작업

| 기능 | 구현 상태 | 남은 범위 / 단계 |
| --- | --- | --- |
| 기존 맵 Open / Save As | 원본 보호·해시·임시 출력·재열기·승격 | 릴리스 회귀 M8 |
| 새 맵 | UI·검증된 타일·메모리 세션·신규 MPQ 저장/재열기 구현 | 실제 SC:R/외부 에디터 인수 M6.4 / [정책](NEW_MAP.md) |
| 맵 제목·설명 | Map Settings → Map, 공유 문자열 분리·Undo | 실제 표시/인코딩 사례 M6.3 |
| 크기·타일셋 | 생성기 32~256·8종, raw·ISOM·두다드 resize·영향 미리보기·Undo 구현 | [지원 범위](MAP_RESIZE.md); 타일셋 변환·게임/외부 에디터 인수는 후속 |
| 플레이어·세력 | 슬롯·종족·색상·세력·이름·옵션 편집 | 게임 사례 M6.3 |
| 유닛 설정·생산 허용 | 종류별 수치·이름·기본값·공유 무기·PUNI | 추가 게임 사례 M6.3 |
| 업그레이드·테크 | 비용·시간·레벨·허용/연구·상속 | 추가 게임 사례 M6.3 |
| 설정 UI | 7개 탭·이름/ID·검색·범위 초안 복사·유닛/무기 연결 | DAT 기본 수치 전체 조회는 미구현 |
| EUD 초기 필드 | 8분류·61후보, 초안·프로젝트 저장·코드 생성·테스트 빌드 | 공유 그래픽 영향·전체 게임/멀티 검증 M6.3.1~2 |
| EUD 실행 규칙 | 변수/식·개체/플레이어/위치/표시, schema v3·실제 컴파일 | 게임 생명주기·성능·멀티 검증 M7.1 |
| EUD 도구·언어 | 관리형 euddraft 동봉, epScript entry | 깨끗한 Windows 인수 X1/X5; Python X3·Lua X4 미구현 |
| Tile/Unit/Sprite/Doodad | 카탈로그·썸네일·검증된 factory·배치 | Doodad 삭제 게임/외부 왕복·미지원 확대 M6.2 |
| 지형 | raw MTXM·TILE/ISOM 검사·평지/재계산·[경계/높이·경사로 브러시](ISOM_BRUSHES.md)·선택 영역·시각 미리보기 | 게임 통행·외부 에디터 인수는 별도 |
| 시작 위치 | 소유자별 목록/선택/배치·이동·캔버스 좌표와 누락/중복 표시 | 실제 게임·외부 에디터 인수 M6.4 |
| 객체 속성 | 개별/일괄 수치·상태/valid flags·Addon/Nydus·Sprite-unit/Doodad 상태 | 불명확한 flags/관계/overlay 거부; 실제 게임 인수 M6.4 |
| 로케이션 | 생성·이동·크기·이름·목록/검색·고도·일괄 고도 | 실제 고도 조건·외부 에디터 인수 M6.4 |
| Fog of War | 플레이어별 MASK 표시·브러시/사각형/전체 채우기·Undo/Redo | 게임 인수 M6.4 |
| 선택·탐색 | 이름/종류 ID·레이어/소유자 검색, 전체/반전/관련 선택·좌표/화면 맞춤·겹침 목록 | [지원·검증](SELECTION_NAVIGATION.md), 게임/릴리스 인수 별도 |
| 선택 영역 clipboard | 문서 내 유닛/Sprite/로케이션·Raw MTXM·검증된 단일 Doodad 복합 편집 | 혼합 다수 Doodad/문서 간 복사·등각 경계 계산 제외 |
| 미니맵 | 미니맵 이동/viewport·Alt 겹침 순환·V/B/R·Ctrl+C/X/V | 실제 사용성·접근성 M8 |
| Undo/Redo | 문서 공통 시간순 기록·스냅샷 검사·원자적 복원 | 저장 후 기록 유지 확장 미포함; EUD 프로젝트 기록 별도 |
| 문자열·사운드 | Resources, 참조 보호·PCM WAV 입출력/재생·MPQ 왕복 | 실제 오디오/게임 재생 확인 M6.5/M8 |
| 일반 트리거 | 조건22·액션57·소유자·스위치·UPRP·원시 보존 | 게임 실행 M7 |
| 미션 브리핑 | 별도 Briefing, 액션9·초안·리소스·저장 왕복 | 텍스트/초상화/소리/시간 게임 확인 M7 |
| 자동 저장·복구·배포 | 교체 백업과 별도 체크포인트·재실행 복구 구현 | 크래시 로그 개인정보 제거·설치/제거·릴리스 회귀 M8 |
| 한영 번역 | 설정·리소스·브리핑·epScript·내장 진단, Windows 글꼴/줄바꿈 확인 | 접근성·고대비 M8 |

## 유닛 설정과 저장의 구분

배치 마린의 체력 50%는 Inspector, 마린 종류의 최대 체력은 Map Settings의
Units, 사거리·실드 활성·피해 유형은 EUD Project의 후보 필드다.
설정의 기본 **이름** 표시와 로컬 DAT의 실제 **기본 수치** 조회는 별도 기능이다.
알 수 없는 항목은 종류와 숫자 ID를 쓰며 0을 게임 기본값으로 표시하지 않는다.

Map Save As는 CHK·리소스를 저장한다. Save Project는 JSON을 저장한다.
EUD 효과는 Prepare EUD Build의 명시적 테스트 빌드로 별도 결과 맵에 반영한다.
사용자의 실드/공격 간격 일부 확인은 [관찰 기록](EUD_GENERATED_BUILD_VALIDATION.md)의
범위만 인정하며 사거리·피해 유형·전체 필드 검증으로 확대하지 않는다.

분야별 남은 구현과 게임/배포 검증은 [남은 작업 요약](REMAINING_WORK.md)을 따른다.

## 완료 기준

새 맵 → 설정 → 배치·지형·안개 → 트리거·브리핑·사운드 → Save As → 재열기 →
SC:R 실행 시나리오가 기본 에디터 완료 기준이다. M0~M6.1의 당시 완료는 이 전체
시나리오 완료를 뜻하지 않는다. 데이터 보존, 취소/실패 무변경, Undo/Redo와
외부 에디터 상호 운용을 도구별로 검증한다.

고급 대칭/사용자 브러시, 기존 맵 타일셋 변환, 문서 간 clipboard, 보호 맵 복구,
범용 DAT/IScript/모드 편집은 별도 범위다. 등각 경계·경사로 구현은 완료했으며 실제 게임 인수는 남는다.

## 5. 외부 비교 근거

- [ScmDraft 공식 기능 비교표](https://www.stormcoast-fortress.net/cntt/software/scmdraft/featuretable/):
  지형·객체·안개·트리거·사운드와 편집 도구의 비교에 사용했다. 오래된 제품 비교표이므로
  최신 버전 전체의 기능 보증이나 바이너리 사양으로 사용하지 않는다.
- [ScmDraft 공식 변경 기록](https://www.stormcoast-fortress.net/news/archive/):
  Unit/Upgrade/Technology Settings와 기본값 복원 기능을 확인했다.
- [Chkdraft 고정 revision의 UI 구성](https://github.com/TheNitesWhoSay/Chkdraft/tree/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/dialog_windows):
  map_settings, new_map, briefing_editor의 분리 구조를 확인했다.
- [Chkdraft 고정 revision의 CHK 구조](https://raw.githubusercontent.com/TheNitesWhoSay/Chkdraft/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h):
  개별 객체와 전역 설정/사용 가능 여부가 별도 데이터라는 점을 확인했다.

외부 구현의 동작을 이 프로젝트에 그대로 복제하거나 손상 데이터 복구 근거로
사용하지 않는다. 개발 순서는 [개발 계획](DEVELOPMENT_PLAN.md), 사용자 요구는
[제품 요구사항](PRODUCT_REQUIREMENTS.md), 섹션 조사 목록은
[파일 포맷](FILE_FORMATS.md)을 따른다.


기존 문서 점검과 현재 작업 트리의 한계는 [점검 기록](DOCUMENTATION_REVIEW.md),
2026-10-03 소스 검토·55개 요구사항·실행 테스트와 수정 결과는
[공학 검증 보고서](ENGINEERING_VERIFICATION_2026-10-03.md)에 기록한다.
