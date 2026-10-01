# EUD 데이터·영향·충돌 보완

2026-10-01. 개발 계획 M6.3.1/M6.3.2에 남아 있던 로컬 DAT 기본값 조회,
Flingy/Sprite/Image 공유 참조와 일반 TRIG/현재 소스 정적 충돌 진단을 구현했다.
이 문서는 코드 지원 계약이며 전체 SC:R 게임·HD·멀티플레이 인수와 다르다.

## 기본값 조회

StarCraft 설치를 설정하고 EUD Project → All EUD field extensions에서
**로컬 DAT 기본값 조회**를 누른다. unit/weapon/flingy/upgrade/tech/sprite/image의
58개 후보 필드 값을 읽는다. **DAT 값을 입력에 사용**은 입력만 바꾸며 초안 추가와
프로젝트 적용을 별도로 수행한다. 조회 자체는 맵·프로젝트·Undo/Redo를 바꾸지 않는다.
플레이어 인구 제한 3개는 런타임 상태이므로 DAT 기본값을 만들지 않는다.

| 로컬 표 | 고정 바이트 수 | 대상 수 |
| --- | ---: | ---: |
| units.dat | 19876 | 228 (ready/pissed/yes 음성 106) |
| weapons.dat | 5460 | 130 |
| flingy.dat | 3135 | 209 |
| upgrades.dat | 1281 | 61 |
| techdata.dat | 836 | 44 |
| sprites.dat | 3229 | 517 |
| images.dat | 37962 | 999 |

helper **0.11.0**, wire protocol **3**, `readEudDat`, snapshot **1**이다.
고정 경로 7개만 읽고 확장/손상 DAT는 크기 불일치로 거부한다. 자산 SHA-256,
제품/빌드·helper/CascLib 버전과 제한된 stdout/stderr를 기록한다. 원시 DAT 파일이나
이미지를 배포·fixture에 넣지 않는다. 응답의 요청/설치 identity, revision, 표 수,
부분 배열 길이, 정수 폭, 자산 크기/해시를 확인한다. timeout·취소·출력 상한을 적용한다.
미지원 enum/비표준 bool/참조는 원시 수치로 표시하고 입력 복사는 비활성화한다.

`PlacementCatalogController`는 조회를 공유·캐시하고 설치/맵 변경·종료 시 무효화한다.
늦은 응답은 폐기한다. 현재 맵 binding이 검증된 경우 변경 목록에 CHK 또는 로컬 DAT
기준값과 적용 예정 값을 표시한다. CHK 사용자 값이 DAT보다 우선하며 손상·미검증 맵은
미확인을 유지한다. 전역 DAT maxLevel은 플레이어별 CHK 연구 제한을 뜻하지 않는다.

## 공유 영향

영향 카드의 조회 버튼으로 동일한 로컬 자료를 읽는다. 원본과 프로젝트의 유효한
참조 override를 반영한 예정 그래프를 비교한다. 직접 참조와 도달 가능한 참조를
종류·숫자 ID/알려진 기본 이름으로 표시한다. 순환과 중복 경로는 한 번만 방문한다.

- Unit → 지상/공중 Weapon, subunit1/2, Flingy, 건설 Image.
- Weapon → Flingy → Sprite → Image.
- Unit/Weapon/Flingy/Sprite/Image 필드별 원본·예정 사용자 목록과 직접 참조.
- None(Weapon 130/Unit 228)과 미조회·잘못된 연결을 구분한다.

Unit 자신의 변경 대상도 목록에 포함한다. Upgrade/Tech의 연구/사용 유닛 연결은
이 그래픽 그래프의 범위가 아니며 기존 미확인 표시를 유지한다. IScript가 생성하는
오버레이, order/버튼·실시간 생성/변신, HD 자산·경로 탐색 갱신은 정적 DAT 참조로
보증하지 않는다. 잘못된 연결이 있으면 부분 목록과 미확인 연결 수를 함께 표시한다.
기존 유닛 카드의 자동 무기 선택은 원본 DAT 연결을 사용한다.

## 정적 충돌 진단

EUD Project의 **정적 충돌 분석**을 펼친다. 현재 메모리의 맵과 열린 소스를 읽고
TRIG 번호·조건/액션 슬롯 또는 소스 행, 겹치는 필드/규칙을 보여준다.

| 검사 | 지원 범위 |
| --- | --- |
| TRIG 메모리 | Deaths(15)/SetDeaths(45)의 고정 player/unit 주소, 61개 필드의 byte/word/dword 범위 |
| 마스크 | EUDX `SC` 표식(0x4353)과 마스크의 쓰기/읽기 바이트 교집합 |
| 규칙 쓰기 | SetResources(26), MoveLocation(38), Modify HP/Energy/Shields(49/50/51)와 활성 규칙 대상 |
| 현재 소스 | 리터럴 `TrgUnit/Weapon/Flingy/Upgrade/Tech/TrgPlayer/Sprite/Image(ID).member` 대입·복합 대입 |
| 메모리 소스 | 리터럴 SetMemory/SetMemoryX/SetMemoryEPD/SetMemoryXEPD, 마스크는 보수적으로 dword 전체 |

비활성 트리거/슬롯을 제외한다. 문자열·주석 내부의 코드는 검사하지 않는다.
CurrentPlayer/플레이어 그룹은 확정 주소로 추측하지 않는다. 일반 액션의 위치·그룹·
조건에 따라 실제 쓰기가 서로 만나지 않을 수 있으므로 겹침은 충돌 가능성 안내다.
조건 분기·실행 순서를 평가하거나 값을 자동 병합/수정하지 않는다.

임의 코드의 imports·aliases·동적 주소/ID·외부 플러그인·다른 hook은 미확인으로
남긴다. 검사 결과가 비어도 안전 증명이 아니다. 미지원 raw TRIG, 중복/손상 TRIG도
미확인으로 표시하고 그대로 보존한다. Prepare EUD Build는 binding을 검증한 맵의
진단을 생성 manifest에 포함한다. 빌드에서 사용자 파일 전체를 읽거나 실행해 분석하지
않는다. 화면 미리보기는 현재 열린 소스까지 포함하므로 디스크 파일 진단과 구분한다.
기존 명시적 테스트 빌드·원본 보호·도구 신뢰·임시 출력 재검증 정책은 유지한다.

## 구조와 근거

Domain의 `EudDatSnapshot/EudDatGraph/EudConflictAnalysis`는 순수 데이터 분석이다.
Application 포트와 컨트롤러 뒤에서 Infrastructure가 CASC/helper 프로세스를 사용한다.
UI는 파일/네이티브/프로세스를 직접 호출하지 않는다.

고정 레이아웃은 [PyMS revision bfc5d3aad0b5614a5aff72c223f8efa00afddfa4의 DAT 정의](https://github.com/poiuyqwert/PyMS/tree/bfc5d3aad0b5614a5aff72c223f8efa00afddfa4/PyMS/FileFormats/DAT)와
[고정 eudplib 0.80.6](EUD_EXPANDED_FIELDS.md#근거와-재현)의 실제 SCData 멤버·주소·enum을
대조했다. `EudDatLayout`과 native `eud_dat_layout.h`에 수치 계약을 고정했다.
`HpBar` 등 제외된 enum의 번호 간격을 순번으로 재해석하지 않는다.

## 검증

합성 DAT 크기/독립 오프셋/endian/해시, 58개 필드/부분 음성/enum 간격/정수 폭,
불변성·CHK 우선순위, 그래픽 원본/예정 참조·서브유닛 순환·미확인 연결을 검사했다.
TRIG 메모리 읽기/쓰기·마스크·일반 액션과 규칙, 소스 주석/문자열·큰 숫자를 검사했다.
프로세스 timeout/취소/중복 요청/출력 제한, 출처 무효화·원본/기록 보존과 UI 초안 적용을
검증했다. 실제 설치 s1 build **13515**의 표 7개·조회 열 61개·유닛 참조 228개와
미확인 그래픽 연결 0개를 확인했다. 동봉 euddraft의 모든 필드/enum API 컴파일도 통과했다.

Native CTest 7개, 전체 Flutter 테스트 887개 통과/38개 환경 skip,
analyze 무이슈와 Windows debug 빌드·시작을 확인한다. 최신 결과는
[문서 점검 기록](DOCUMENTATION_REVIEW.md)을 함께 따른다.
SDK Flutter 3.47.5/Dart 3.13.4로 기준 3.44.8/3.12와 다르다.
변경 Dart 파일의 format은 통과하며 전체 비쓰기 게이트는 기존 무관한 infrastructure
테스트 3개의 차이로 미통과다. 기존 CascLib CMake 최소 버전 경고는 남아 있다.
컴파일·DAT 조회는 게임 효과 검증이 아니며 전체 필드 조합·classic/HD·멀티플레이,
배치/신규 생성·변신/회복과 외부 에디터 인수는 남는다.
