# 맵 간 참조 재매핑 복사

## 범위와 요구사항

2026-10-17 FR-222 / EP3b 두 번째 항목의 첫 지원 프로필을 구현했다.
열린 두 맵 사이에서 상단 복사 아이콘으로 대상·좌표 이동·플레이어 매핑·일반
트리거/브리핑을 선택하고 Preview 후 Apply한다. 기존 같은 맵 clipboard와는 별도다.

| 데이터 | 지원 계약 |
| --- | --- |
| UNIT/THG2 | 원본 맵에서 현재 선택한 레코드. UNIT 연결 쌍은 함께 선택하고 새 class ID/peer ID를 함께 생성. 독립 Sprite만 지원 |
| 로케이션 | 선택된 위치와 선택 트리거가 참조하는 위치를 함께 수집. 이름·고도·역전 좌표를 보존하고 빈 대상 슬롯으로 매핑 |
| 빈 슬롯 | 바이트가 0이어도 기존 대상 트리거의 참조가 있으면 사용 중으로 취급. 사용 범위를 모르는 raw/EUD 대상 트리거가 있으면 전역 슬롯 할당 거절 |
| Anywhere | ID 64 유지. 참조 시 양쪽 모두 전체 맵 경계·같은 고도 마스크인지 검사. 임의 수정된 Anywhere는 추측 변환하지 않음 |
| 문자열 | 참조 closure의 원시 바이트를 새 ID에 일괄 추가. 비 UTF-8·제어 코드·공유 참조 유지. 기존 대상 ID·alias·미사용 payload를 정규화하지 않음 |
| 스위치/속성 | 대상 TRIG·SWNM·UPUS·UPRP를 검사하여 미사용 슬롯에 이름/20바이트 속성 복사. 기존 값을 덮어쓰지 않음 |
| TRIG/MBRF | 검증된 일반 opcode와 canonical 필드만 복사. 순서·owner·비활성 상태·Wait/Preserve 유지. 예약/미사용 바이트·unknown/EUDX는 전체 거절 |
| 플레이어 | 12슬롯의 명시적 일대일 순열. UNIT/Sprite 소유자와 트리거 player 인자/owner를 함께 매핑. Force/Current Player 등 집합의 숫자 의미는 유지 |
| 사운드 | 참조하는 ASCII 상대 WAV 경로와 PCM 바이트. source 실제 파일 재검증·중립 locale/유일한 이름 검사. 대상 파일/대기 편집/문자열 경로와 대소문자 무관 충돌 시 전체 거절 |
| 적용 | 양쪽 문서/현재 session·진행 작업·관련 레이어 잠금 재검증. CHK와 사운드를 대상의 한 Undo로 적용. 원본/미리보기는 무변경 |

동일 타일셋만 허용한다. 초기 프로필은 DD2/두다드 overlay·raw/ISOM 영역을
문서 간 전송하지 않는다. 이들은 기존 **같은 맵** 혼합 영역 복사에서만 지원한다.
일반 트리거만 이식하며 EUD 소스/프로젝트나 참조 밖 트리거를 자동 추적하지 않는다.
유닛/플레이어/세력/DAT 등 맵 전역 설정은 대상 값을 유지한다. 문서 간 Move,
OS clipboard, 외부 코드 실행, 게임 동작의 의미 동등성 보증은 제공하지 않는다.

## 계획 → 실행 → 분석

1. 기존 `ChkEditingClipboard`는 문자열 ID가 문서 로컬이라는 계약이므로 직접
   다른 맵에 적용하지 않았다. 별도 `ChkDocumentTransfer`가 검증된 closure와
   읽기 전용 계획을 만들고 기존 복사기의 ID/연결·좌표 검사를 재사용한다.
2. 단순한 빈 MRGN 검사만으로는 기존 TRIG가 참조하는 빈 슬롯을 오염시킬 수
   있었다. 대상의 알려진 참조를 함께 예약하고 opaque 사용자가 있으면 거절한다.
3. 기존 string append를 여러 번 호출하면 표를 반복 복사/해석한다. structured
   string view에 batch append를 추가하여 헤더/offset 보정을 한 번만 한다.
   기존 단일 추가 API도 같은 경로를 사용하며 alias/원시/경계 회귀를 추가했다.
   속도 배수나 대용량 RSS 개선은 별도 계측 전 주장하지 않는다.
4. application 컨트롤러가 기존 사운드 조회 포트를 통해 바이트를 모으고
   immutable resource snapshot을 만든다. 양쪽 session identity와 요청 번호가
   달라지면 늦은 결과를 버린다. UI는 파일/네이티브/프로세스를 호출하지 않는다.
5. 기존 자원 편집 명령을 좁게 확장하여 객체·트리거·문자열·사운드를 하나의
   명령으로 적용한다. source Undo와 target Undo를 결합하지 않는다.
6. 600px 회귀에서 기존 고정 sidebars로 중앙 도구 폭이 무너지는 결함과 제목
   넘침을 발견했다. 작업 영역은 최소 1000px의 가로 스크롤로 유지하고 toolbar
   제목은 제한 폭/말줄임 처리했다. wrapper 수명을 고정하여 resize 시 초안을 유지한다.

최초 도메인 실행은 인덱스 제네릭 추론 오류로 컴파일 실패했고 명시적 `int`로
교정했다. 초기 화면 테스트의 언어 설정 key도 실제 `uiLanguage`로 수정했다.
첫 화면 회귀는 위 좁은 창 오류로 실패했으며 수정 후 600/1200px 모두 통과했다.
정적 분석의 중괄호 진단을 수정하고 재실행했다.

## 시나리오 체크리스트

- [x] 동일 숫자 ID의 다른 의미, 새 문자열/위치/스위치/속성/class ID·peer 매핑
- [x] 기존 대상이 참조하는 빈 위치 보호, Anywhere 경계/고도 검사
- [x] 비 UTF-8/제어 바이트·alias·미사용 문자열 payload·unknown CHK 보존
- [x] 불완전 연결 쌍·예약 위치·raw/EUD/예약 트리거·타일셋/용량/좌표 거절
- [x] 원본/미리보기 무변경, 단일 대상 Undo/Redo와 재사용된 Apply 거절
- [x] 변경/닫기/잠금·읽기 완료 전 취소·사운드 충돌/누락/손상·자원 예산 거절
- [x] 한국어 600/1200px Preview → Cancel/Apply
- [x] 실제 자체 제작 MPQ의 사운드 읽기 → 복사 → Undo/Redo → Save As → 재열기·원본 두 개 hash 유지
- [ ] 실제 앱 수동 조작·외부 에디터/SC:R·대용량 profile 인수

## 검증 기록

집중 5파일 **24 PASS / skip 없음**. 자체 제작 실제 MPQ 왕복 1개를 포함하며
다른 테스트 수와 중복 합산하지 않는다. 정적 분석은 No issues found다.
전체 format은 532파일 중 기존 infrastructure 테스트 3파일 차이로 exit 1이며
이번 변경 파일 차이는 없다. 전체 테스트는 **2,259 PASS / 환경 조건부 67 skip**이다.
기존 사용자 설정 테스트가 포함된 현재 작업 트리의 결과이며 깨끗한 CI 결과는 아니다.
`flutter build windows --debug` PASS, native CTest **7/7 PASS**를 확인했다.
Windows 빌드에는 기존 third-party CMake minimum-version 경고만 있었다.
형식 차이는 기존 `local_map_save_file_gateway_test.dart`,
`process_eud_compiler_gateway_test.dart`, `process_map_archive_gateway_test.dart`이며
이번 작업에서 이 파일이나 사용자 설정/플랫폼 변경을 수정하지 않았다.

환경: Flutter 3.47.5 / Dart 3.13.4, Windows. 저장소 기준 3.44.8/3.12와 다르다.
실제 앱/게임 조작은 이전 사용자 지시대로 수행하지 않는다. SC:R 원시 자산이나
추출 이미지를 추가하지 않았고 실제 테스트 입력은 임시 자체 제작 맵/PCM뿐이다.
