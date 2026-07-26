# 테스트와 품질

## 1. 품질 목표

이 프로젝트에서 가장 심각한 결함은 조용한 데이터 손실이다. UI 모양보다 파싱, 저장, 원본 보호, 빌드 결과 검증을 먼저 자동화한다.

우선순위:

1. 원본 맵 불변
2. 알 수 없는 데이터 보존
3. 잘못된 출력의 성공 처리 방지
4. 사용자 편집의 정확한 왕복
5. 진단과 복구 가능성
6. 성능과 UX

## 2. 테스트 계층

### 단위 테스트

대상:

- little-endian 바이너리 읽기/쓰기
- CHK 섹션 파서와 인코더
- typed view와 값 검증
- 편집 명령의 apply/revert
- 문자열 표시와 원시 바이트 분리
- 빌드 로그 진단 파서

특징:

- 파일 시스템, Flutter, 네이티브 라이브러리 없이 실행
- 정상/경계/손상 데이터를 작은 바이트 배열로 표현
- 오류 코드와 위치까지 검증

### 속성 기반/Fuzz 테스트

대상:

- 임의 섹션 목록의 encode(parse(bytes)) 왕복
- 알 수 없는 섹션과 중복 섹션 보존
- 임의 길이/잘린 입력이 프로세스를 크래시시키지 않음
- 편집하지 않은 섹션이 바뀌지 않음

퍼저가 만든 재현 입력은 최소화해 회귀 픽스처로 저장한다.

### 통합 테스트

대상:

- `MapArchiveGateway`로 아카이브 열기/쓰기
- 임시 출력 → 재검증 → 승격
- 크기·UTC 수정 시각·SHA-256 fingerprint와 외부 변경 감지
- euddraft 가짜 프로세스 성공/실패/취소
- 한글, 공백, 긴 경로

외부 도구가 없는 CI에서는 가짜 어댑터를 사용하고, 별도 Windows job에서 실제 도구 스모크 테스트를 실행한다.

### 위젯 테스트

대상:

- 에디터 셸과 패널 상태
- 변경 문서 닫기 확인
- Problems 선택 → 대상 뷰 이동
- Build 상태와 버튼 활성화
- 읽기 전용/제한 편집 표시

### Golden 테스트

안정적인 화면에만 제한적으로 사용한다.

- 빈 에디터
- 맵 열린 상태
- 진단 목록
- 코드 편집기 오류 상태

Flutter/폰트 버전 차이를 줄이기 위해 CI 환경을 고정하고, 픽셀 변경만으로 기능 완료를 판단하지 않는다.

### 수동 스모크 테스트

- 실제 `.scx` 열기와 Save As
- 다른 편집기에서 결과 맵 열기
- euddraft 실제 빌드
- StarCraft: Remastered에서 맵 로드와 시작
- 자동 저장 복구
- 깨끗한 Windows PC에서 설치/실행

## 3. 픽스처 정책

저장소에는 다음 파일만 포함한다.

- 프로젝트가 직접 생성한 최소 CHK/맵
- 저작권과 재배포 허가가 명확한 파일
- 개인 정보, 계정 이름, 개인 경로가 제거된 파일

타인의 배포 맵을 허가 없이 테스트 픽스처로 커밋하지 않는다.

권장 구조:

```text
test/fixtures/
  chk/
    minimal/
    malformed/
    duplicates/
    unknown_sections/
  maps/
    generated/
  eud/
    success/
    compile_error/
```

각 바이너리 픽스처에는 생성 방법, 라이선스, 예상 동작을 설명하는 인접 Markdown 또는 manifest를 둔다.

현재 raw CHK 코어는 `test/fixtures/chk/`의 직접 작성한 `.chk.hex` 바이트
스트림을 사용한다. 이 형식은 바이너리 내용을 코드 리뷰에서 확인할 수 있고,
인접 `README.md`에 각 입력의 의도를 기록한다. 단위 테스트는 고정 시드로 만든
200개 임의 섹션 목록도 왕복해 별도 fuzz 의존성 없이 초기 속성 검사를 수행한다.

`test/fixtures/maps/generated/minimal-self-authored.scx`는 위 CHK 중
`metadata.chk.hex`와 네 개의 프로젝트 테스트 바이트로 만든 460바이트 MPQ다.
제3자 맵이나 게임 자산을 포함하지 않으며 저장소의 MIT 라이선스로 재배포한다.
인접 `README.md`는 재생성 방법을, `manifest.json`은 pinned StormLib revision,
아카이브·CHK SHA-256, 크기와 예상 엔트리를 기록한다.
`test/fixtures/generated_map_fixture_test.dart`는 helper 없이도 이 provenance와
해시를 모든 플랫폼에서 검증한다.

문자열 픽스처는 공유/중복 offset, `STR `과 `STRx`의 서로 다른 offset 폭,
UTF-8 및 제어 바이트, 미참조 꼬리 데이터, 잘린 표와 잘못된 offset을 포함한다.
문자열 변경 테스트는 대상 offset과 추가된 바이트 외의 기존 payload가 동일한지
인덱스별로 확인한다.

`test/application/map_archive_gateway_test.dart`는 실제 파일 시스템이나
StormLib 없이 가짜 `MapArchiveGateway`를 대입해 open, 임시 쓰기, 취소 계약을
검증한다. 요청/결과 바이트와 메타데이터의 불변성, 경로·timeout 경계,
바이트 값 범위, 목록 완전성, uint32 entry metadata, `scenario.chk` 항목과
추출 크기의 일치, 성공/실패 진단 불변식을 단위 테스트한다.

`test/application/open_map_controller_test.dart`는 가짜 파일 선택기와
`MapArchiveGateway`로 파일 선택/최근 경로, CHK 파싱과 typed 요약, 성공 시
최근 목록 기록, 아카이브 및 raw CHK 실패, 제한 읽기 전용 열기와 확장자
경계를 검증한다. `test/infrastructure/method_channel_map_file_picker_test.dart`는
Windows runner와 동일한 method channel 계약에서 선택 경로와 취소를
검증한다. `test/widget/editor_shell_test.dart`는 실제 Open Map 명령을 통해
열린 파일명, 맵 크기, 아카이브 목록, Inspector와 읽기 전용 상태가 표시되는지
검증한다.

`test/application/save_map_controller_test.dart`는 임시 아카이브 쓰기, 재열기,
CHK byte-exact 비교, 파싱, 최종 승격과 세션 채택을 검증한다. 원본과 같은 경로,
기존 출력, helper 쓰기 실패, 재열기 바이트 불일치와 승격 실패에서는 최종
승격이 호출되지 않고 작업 공간이 정리되는지도 확인한다.
`test/infrastructure/local_map_save_file_gateway_test.dart`는 최종 출력과 같은
디렉터리의 작업 공간, 새 파일 rename, 기존 파일 보존과 경로 동일성 검사를
실제 파일 시스템에서 확인한다.

`test/infrastructure/process_map_archive_gateway_test.dart`는 셸을 사용하지 않고
고정 PowerShell fixture 프로세스를 실행해 성공, 구조화 오류, 손상 응답,
전체/불완전 목록, 합성 이름, 중복 경로, 예상 밖 MPQ version, 암호화 항목,
대량 stderr, timeout, 취소, 상대 경로 차단, 임시 CHK 교체 요청과 helper
메타데이터/실제 출력 크기 교차 검증을 확인한다.

`map_archive_helper_native_test`는 StormLib로 테스트 중 MPQ를 직접 생성해 한글
경로 추출, 원본 byte-exact 불변, 내부 listfile 기반 완전 목록, listfile 없는
합성 이름, 누락 CHK, 기존 출력 보존, 복사본 CHK 교체, 비대상 엔트리 보존과
원본 byte-exact 불변을 검증한다. Windows CI는 이 native CTest 뒤에 저장소의
고정 3-entry 자체 제작 SCX를 패키지의 실제 helper와
`ProcessMapArchiveGateway`로 열고, 새 CHK를 임시 MPQ에 쓴 뒤 재열어 목록과
교체 바이트 및 원본 불변을 검증한다.

## 4. 필수 회귀 테스트

### CHK

- 빈 입력
- 1~7바이트의 잘린 헤더
- 길이 0 섹션
- 알 수 없는 4바이트 이름
- 동일 이름 중복 섹션
- 선언 길이가 남은 파일보다 큰 섹션
- 최대 허용 범위 근처 길이
- 변경 없는 byte-exact 왕복
- 한 섹션 변경 시 나머지 섹션 동일

### 파일 저장

- 입력과 출력 동일 경로 차단
- 확인 없는 기존 출력 교체 차단
- 확인된 기존 출력의 byte-exact 복구 백업과 승격
- 기존 복구 백업 덮어쓰기 차단
- 승격 실패 시 기존 출력 자동 복원
- 자동 복원 실패 시 백업 보존과 복구 경로 진단
- 저장 중 기존 출력 변경·삭제와 새 출력 충돌
- 디스크 쓰기 실패
- 열린 뒤 입력 변경
- 저장 중 입력 외부 변경
- 저장 중 입력 삭제 또는 fingerprint 읽기 실패
- 같은 크기와 수정 시각을 유지한 내용 변경
- 출력 재열기 실패
- 검증 실패 시 최종 파일 미생성

### EUD

- 프로젝트→사용자 설정→번들 경로 우선순위
- 상위 경로 오류 시 낮은 우선순위 설치로 우회하지 않음
- 도구 없음, 상대 경로, 잘못된 실행 파일
- VERSION 누락/손상/크기 초과와 미지원 버전
- Python/eudplib/epScript companion 누락
- 검사 과정에서 euddraft를 실행하지 않음
- 성공 종료지만 출력 없음
- 실패 종료와 부분 출력 존재
- stdout/stderr 동시 출력
- 컴파일 오류 위치 파싱
- 사용자 취소
- 한글/공백 경로
- 입력 맵 불변

## 5. 성능 기준

초기 측정 기준이며 실제 픽스처와 사용자 환경으로 조정한다.

- 앱 셸 첫 표시: 일반 개발 PC에서 체감 지연 최소화
- 256×256 맵 기본 이동/확대: 목표 60 FPS, 최소 30 FPS
- 장시간 작업: UI 이벤트 처리를 막는 100ms 이상의 동기 작업을 피함
- 큰 파일 작업: 단계 표시와 취소 가능 지점 제공

성능 테스트는 숫자만 기록하지 않고 맵 크기, 레이어 수, 확대 배율, 하드웨어와 빌드 모드를 함께 기록한다.

## 6. 정적 검사와 포맷

기본 명령:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

네이티브 코드가 추가되면 해당 포맷터, 정적 분석, 단위 테스트를 같은 완료 게이트에 포함한다.

## 7. CI 단계

### 모든 커밋/PR

- 의존성 복원
- Dart format 검사
- Flutter analyze
- 단위/위젯 테스트
- 문서 내부 링크 검사

### Windows 통합

- Windows debug/release 빌드
- 네이티브 브리지 테스트
- 자체 제작 `.scx` Open/Save As
- 가짜 euddraft 통합 테스트

### 릴리스 후보

- 실제 euddraft 스모크 테스트
- StarCraft 수동 실행 체크리스트
- 설치/제거
- 라이선스 고지와 배포 파일 목록 검사

공식 euddraft 설치 레이아웃의 선택적 로컬 스모크 테스트:

```powershell
$env:EUDDRAFT_TEST_INSTALLATION = "C:\Tools\euddraft"
flutter test test/infrastructure/local_eud_tool_inspector_test.dart
```

환경 변수가 없으면 해당 한 케이스만 skip되며 합성 설치 레이아웃 회귀 테스트는
항상 실행된다.

## 8. 결함 심각도

| 등급 | 예 |
| --- | --- |
| Blocker | 원본 손상, 조용한 데이터 유실, 악성 프로젝트 자동 실행 |
| Critical | 저장 성공으로 표시했지만 출력이 열리지 않음 |
| Major | 지원 기능의 왕복 불일치, Undo 실패, 빌드 진단 유실 |
| Minor | 잘못된 정렬, 툴팁, 비핵심 단축키 문제 |

Blocker와 Critical이 열려 있으면 릴리스하지 않는다.

## 9. 완료 정의

기능은 다음이 모두 만족될 때 완료다.

- 제품 요구사항과 인수 조건이 명확함
- 정상, 실패, 경계 테스트 존재
- `flutter analyze`와 `flutter test` 통과
- 실제 사용자 흐름을 비례한 수준으로 스모크 테스트
- 데이터 포맷 또는 동작 변경이 문서에 반영됨
- 로그와 오류 메시지가 문제 해결에 충분함
- 관련 변경만 커밋하고 원격에 푸시됨
