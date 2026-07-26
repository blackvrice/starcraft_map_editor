# 파일 포맷과 무손실 정책

## 1. 범위

이 문서는 `.scm`/`.scx` 아카이브와 내부 `staredit\scenario.chk`를 다루는 규칙을 정의한다. 세부 섹션 레이아웃은 실제 픽스처, 공개 구현, 게임 동작으로 검증한 뒤 코드와 함께 확장한다.

초기 구현은 보호되지 않은 맵만 지원한다. 잠금, 손상, 비표준 압축, 의도적인 포맷 교란을 자동으로 우회하지 않는다.

## 2. 처리 계층

```text
.scm / .scx archive
  └─ staredit\scenario.chk
       ├─ section header: 4-byte name + 32-bit little-endian length
       └─ section payload: length bytes
```

- 아카이브 계층은 파일 추출과 교체를 담당한다.
- Raw CHK 계층은 섹션 순서와 바이트를 보존한다.
- Typed view 계층은 지원하는 섹션만 의미 모델로 해석한다.
- 편집 계층은 typed view에 명령을 적용한다.

한 계층의 실패를 다른 계층이 추측으로 복구하지 않는다.

## 3. 아카이브 정책

### 열기

1. 파일을 읽기 전용으로 연다.
2. 파일 크기, UTC 수정 시각과 SHA-256 fingerprint를 기록한다.
3. `staredit\scenario.chk` 존재 여부를 확인한다.
4. CHK를 메모리 또는 안전한 임시 공간으로 추출한다.
5. 추출과 파싱 뒤 fingerprint를 다시 계산해 외부 변경이 없음을 확인한다.
6. 아카이브와 CHK 진단을 분리해 반환한다.

2026-07-26 기준 `ProcessMapArchiveGateway`와 번들
`map_archive_helper.exe`가 이 열기 흐름을 구현한다. helper는 StormLib로
정확히 `staredit\scenario.chk`만 앱 소유 임시 디렉터리에 추출한다. 추출
성공은 아카이브 크기와 전체 항목 수, CHK 압축/비압축 크기를 반환하며 Dart
어댑터가 프로토콜과 실제 파일 크기를 다시 검증한 뒤 읽기 전용 바이트로
노출한다.

저장소의 `test/fixtures/maps/generated/minimal-self-authored.scx`는
`TYPE`, `VER`, `IVER`, `ERA`, `DIM`만 가진 프로젝트 작성 CHK와 네 개의
테스트 바이트로 구성한 비플레이용 MPQ다. 인접 manifest의 SHA-256과 엔트리
목록을 일반 테스트에서 확인하고, Windows CI에서는 실제 번들 helper로 추출과
교체를 검증한다. 제3자 지도나 게임 자산은 포함하지 않는다.

helper `0.2.0`부터 MPQ format version과 최대 1,024개의 엔트리 목록도 함께
반환한다. 항목 메타데이터는 경로, 압축/비압축 크기, MPQ flags, locale과
StormLib가 복원한 합성 이름 여부를 포함한다. 동일 파일 block을 가리키는 locale
hash 항목은 한 번만 노출한다. 목록 수와 전체 수가 다르거나 열거가 중단된 경우
추출 성공을 유지하면서 `ARCHIVE_LISTING_INCOMPLETE` 경고를 반환한다. 내부
listfile 없이 복원한 이름, 대소문자를 무시한 중복 경로, MPQ v1이 아닌 버전은
각각 별도 경고이며 내부 `(listfile)`, `(attributes)`, `(signature)`가 아닌
암호화 항목은 정보 진단이다. 합성 이름은 원본 경로로 간주하지 않는다.

### 저장

1. 입력 맵과 다른 임시 출력 경로를 만든다.
2. 열린 세션의 입력 fingerprint와 현재 파일을 비교한다.
3. 입력 아카이브의 필요한 엔트리를 복사한다.
4. 새 CHK를 임시 아카이브에 기록한다.
5. 임시 아카이브를 다시 열고 CHK를 재추출한다.
6. 구조 및 변경 의도와 임시 출력 fingerprint를 검증한다.
7. 입력과 기존 출력의 fingerprint를 다시 확인한다.
8. 승인된 기존 출력은 같은 디렉터리의 고유 복구 백업으로 이동한다.
9. 모든 검증 성공 후에만 사용자가 지정한 출력 경로로 승격한다.
10. 승격 실패 시 기존 출력 백업을 원래 경로로 복원한다.

helper `0.3.0`의 `replaceScenario`는 원본 MPQ 전체를 새 임시 출력으로 복사한
뒤 정확히 `staredit\scenario.chk`만 교체한다. 애플리케이션은 임시 출력을
`extractScenario`로 다시 열어 인코딩한 CHK와 byte-exact 비교하고 raw 파싱에
성공한 뒤 입력 fingerprint가 변하지 않은 경우에만 같은 디렉터리의 새 최종
경로로 rename한다. 임시 출력의 fingerprint는 승격된 파일의 새 문서 세션에
기록한다. 기존 출력 교체는 Windows Save As 확인을 거친 경우에만 허용하며,
기존 출력 fingerprint가 바뀌지 않았을 때 고유 `.bak`로 이동한다. 승격 실패 시
자동 복원하고 복원 실패 시 백업을 보존한 채 정확한 경로를 진단한다.

열린 원본 덮어쓰기는 지원하지 않는다. Save As에서 다른 기존 출력을 교체할
때에도 명시적 확인, 외부 변경 감지와 복구 백업을 생략할 수 없다.

## 4. Raw CHK 모델

### 필수 보존 정보

- 섹션 이름의 정확한 4바이트
- 선언된 길이
- 페이로드 바이트
- 문서 내 순서
- 동일 이름 섹션의 중복과 순서
- 원본 바이트 오프셋
- 섹션 수정 여부

### 파싱 규칙

- 파일 끝까지 순차적으로 읽는다.
- 헤더가 8바이트보다 짧으면 잘린 헤더 오류를 반환한다.
- 선언된 길이가 남은 파일 범위를 넘으면 경계 오류를 반환한다.
- 섹션 이름이 예상 목록에 없다는 이유만으로 오류 처리하지 않는다.
- 중복 섹션을 자동 병합하거나 마지막 하나만 남기지 않는다.
- 오류에는 최소 섹션 인덱스와 바이트 오프셋을 포함한다.

### 직렬화 규칙

- 수정되지 않은 섹션은 원시 페이로드를 그대로 사용한다.
- 섹션 순서와 중복을 유지한다.
- 사용자가 명시적으로 수행하지 않은 정렬, 압축, 문자열 재인코딩을 하지 않는다.
- typed view가 변경된 경우에만 해당 섹션을 다시 인코딩한다.
- 지원하지 않는 필드가 섹션 내부에 존재하면 부분 패치 또는 원시 필드 보존 전략이 없는 한 편집을 막는다.

### 구현 기준선

2026-07-26 기준 `lib/domain/chk/`에는 파일 시스템이나 Flutter에 의존하지
않는 다음 구현이 있다.

- `RawChkParser`: 8바이트 헤더를 순차 파싱하고 정상 섹션의 원시 정보를 보존
- `RawChkDocument`/`RawChkSection`: 순서, 중복, 이름 4바이트, 선언 길이,
  페이로드, 소스 오프셋, 변경 상태 보관
- `RawChkEncoder`: 현재 문서 순서대로 little-endian 헤더와 페이로드 직렬화
- `RawChkParseResult`: 성공 문서 또는 저장을 차단하는 구조 진단 반환

빈 입력은 raw 구조 단계에서는 섹션이 없는 유효 문서로 취급한다. 필수 섹션
존재 여부는 이후 typed view/의미 검증 단계가 판단한다. 구조적으로 유효하고
수정되지 않은 문서는 헤더를 포함해 byte-exact로 왕복한다.

현재 구조 진단 코드는 다음과 같다.

| 코드 | 기준 위치 | 의미 |
| --- | --- | --- |
| `CHK_TRUNCATED_HEADER` | 불완전한 다음 섹션의 시작 | 남은 데이터가 8바이트 헤더보다 짧음 |
| `CHK_SECTION_OUT_OF_BOUNDS` | 선언 길이 필드의 시작 | 선언된 페이로드가 입력 경계를 벗어남 |

두 진단은 `rawDetails`에 섹션 인덱스를 포함하며, 경계 오류는 선언 길이와 실제
남은 길이도 포함한다. 파서가 성공하기 전까지 부분 문서는 편집 가능한 결과로
노출하지 않는다.

## 5. Typed view 지원 순서

정확한 섹션 의미와 버전별 동작은 픽스처로 검증한다.

### 1단계: 문서 식별

- `VER `, `TYPE`, `IVER`
- `DIM `, `ERA `
- `SPRP`
- `STR ` 또는 `STRx`

#### 구현된 메타데이터 typed view

2026-07-26 기준 다음 고정 크기 섹션을 `ChkMetadataViewDecoder`가
little-endian 값으로 투영한다.

| 섹션 | payload 크기 | typed 값 |
| --- | ---: | --- |
| `TYPE` | 4 | `u32 rawValue`, `RAWS`/`RAWB` known type |
| `VER ` | 2 | `u16 rawValue`, 59/63/205/206 known version |
| `IVER` | 2 | `u16 rawValue`, 9/10 known internal version |
| `DIM ` | 4 | `u16 width`, `u16 height` |
| `ERA ` | 2 | `u16 rawValue`, 0~7 known tileset |

- 같은 이름의 섹션을 합치거나 하나만 선택하지 않고 원래 순서의 별도 뷰로
  반환한다. 각 뷰는 raw 섹션과 문서 내 섹션 인덱스를 가진다.
- 알려지지 않은 scalar 값은 진단 없이 `rawValue`로 유지하고 known enum만
  `null`로 둔다. 값의 의미를 모른다는 이유로 원시 데이터를 바꾸지 않는다.
- 고정 payload 크기가 다르면 `CHK_TYPED_SECTION_SIZE_MISMATCH` 오류를 payload
  시작 오프셋에 반환하고 해당 섹션의 typed view만 만들지 않는다. 다른 정상
  섹션 디코딩은 계속한다.
- typed 변경 메서드는 같은 이름과 소스 오프셋을 가진 dirty raw 섹션을
  반환한다. 호출자는 뷰의 정확한 섹션 인덱스에 이 섹션을 교체한다.
- 섹션 누락과 `DIM `의 0 크기처럼 구조적으로 읽을 수 있지만 의미 확인이
  필요한 값은 이후 문서 의미 검증 단계에서 판단한다.

### 2단계: 플레이어와 맵 설정

- `OWNR`, `SIDE`
- `FORC`
- `COLR`, `CRGB`

### 3단계: 지형

- `MTXM`
- `TILE`, `ISOM` 등 존재 가능한 관련 데이터

지형 편집은 한 섹션만 수정했을 때 게임과 다른 에디터가 어떤 데이터를 우선하는지 확인한 뒤 활성화한다.

### 4단계: 객체

- `UNIT`
- `THG2`
- `MRGN`

객체 레코드는 알려지지 않은 비트와 예약 필드를 원본 값으로 유지한다.

### 5단계: 트리거

- `TRIG`
- `MBRF`
- 관련 문자열, 스위치, WAV 참조

EUD 컴파일러가 만든 트리거는 일반 트리거 UI가 임의로 정규화하지 않도록 식별과 소유권 정책이 필요하다.

## 6. 문자열 정책

문자열은 손상 위험이 큰 영역이므로 raw-first로 처리한다.

- 원시 문자열 테이블 바이트를 원본으로 보존한다.
- 표시용 디코딩과 저장용 바이트를 구분한다.
- 인코딩을 확신할 수 없으면 대체 문자를 저장 데이터에 반영하지 않는다.
- null, 제어 코드, 색상 코드, 중복 문자열을 임의 정리하지 않는다.
- `STR `과 `STRx` 변환은 명시적 마이그레이션으로만 수행한다.
- 문자열 제거 전 모든 섹션의 참조를 검사한다.

### 구현된 문자열 typed view

2026-07-26 기준 `ChkStringViewDecoder`가 다음 구조를 투영한다.

| 섹션 | 구조 |
| --- | --- |
| `SPRP` | `u16` 맵 이름 문자열 ID + `u16` 설명 문자열 ID |
| `STR ` | `u16` 문자열 수 + 같은 수의 `u16` section-relative offset |
| `STRx` | `u32` 문자열 수 + 같은 수의 `u32` section-relative offset |

- 문자열 ID는 1부터 시작하고 참조 ID 0은 문자열 없음으로 표현한다.
- 각 엔트리는 ID, 원시 offset, null 종결 여부, 원시 문자열 바이트를 가진다.
- 같은 offset을 공유하는 문자열, 다른 문자열의 중간을 가리키는 부분 문자열,
  빈 문자열, 제어 바이트를 합치거나 정규화하지 않는다.
- 표시 문자열은 저장 데이터가 아니다. 호출자가 명시적으로 전달한 decoder만
  원시 바이트를 표시용 문자열로 변환하며, 변환 결과를 자동 저장하지 않는다.
- 중복 `SPRP`, `STR `, `STRx`는 각각 원래 섹션 인덱스를 가진 별도 뷰로
  반환한다. `STR `과 `STRx`가 함께 있을 때 active table을 임의 선택하지 않는다.

문자열 수정은 기존 표를 재작성하지 않는 append-only 방식만 제공한다.

1. 기존 payload 전체를 그대로 복사한다.
2. 새 원시 문자열 바이트와 null 종결자를 payload 끝에 추가한다.
3. 사용자가 지정한 한 문자열 ID의 offset 필드만 새 위치로 변경한다.

따라서 공유 offset을 편집해도 다른 ID는 기존 문자열을 계속 가리키고, 미참조
꼬리 데이터와 기존 부분 문자열도 유지된다. 내장 null 바이트, 범위를 벗어난
바이트, 존재하지 않는 ID, `STR `의 `u16`으로 표현할 수 없는 새 offset은
거부한다. 구조 오류가 하나라도 있는 표는 append-only 수정도 차단한다.

현재 문자열 구조 진단은 다음과 같다.

| 코드 | 의미 |
| --- | --- |
| `CHK_STRING_TABLE_HEADER_TRUNCATED` | 문자열 수 필드가 완전하지 않음 |
| `CHK_STRING_TABLE_OFFSETS_TRUNCATED` | 선언 개수에 필요한 offset 표가 잘림 |
| `CHK_STRING_OFFSET_INTO_HEADER` | 문자열 offset이 수/offset 표 내부를 가리킴 |
| `CHK_STRING_OFFSET_OUT_OF_BOUNDS` | 문자열 offset이 payload 범위를 벗어남 |
| `CHK_STRING_UNTERMINATED` | payload 끝까지 null 종결자가 없음 |

손상 표의 원시 섹션은 계속 보존하지만 typed 편집은 읽기 전용으로 제한한다.

## 7. 변경 추적

각 typed view는 다음 중 하나의 상태를 가진다.

- `clean`: 원시 데이터에서 읽은 뒤 변경 없음
- `dirty`: 의미 모델이 변경되어 다시 인코딩 필요
- `unsupported`: 표시할 수 있으나 안전한 편집 불가
- `invalid`: 입력 데이터가 유효하지 않아 저장 차단

문서 전체의 `dirty` 상태는 편집된 섹션으로부터 계산한다. 화면 탐색, 선택, 패널 크기 변경은 맵 변경으로 취급하지 않는다.

## 8. 검증 단계

### 구조 검증

- 섹션 헤더와 길이가 파일 범위 안에 있음
- 필요한 식별/크기 정보가 해석 가능함
- typed view가 요구하는 레코드 크기와 일치함

### 의미 검증

- 객체와 로케이션이 맵 경계 안에 있음
- 문자열, 플레이어, 로케이션 참조가 범위 안에 있음
- 섹션 간 크기와 배열 개수가 모순되지 않음
- 편집기가 만든 데이터가 해당 필드의 범위를 넘지 않음

### 왕복 검증

- 변경 없는 raw CHK는 byte-exact round-trip
- 편집된 CHK는 의도한 섹션만 변경
- 아카이브 저장 후 재추출한 CHK가 예상 결과와 동일
- 원본 아카이브 fingerprint는 변경되지 않음

## 9. 손상 및 보호된 맵

다음 상황에서는 기본적으로 읽기 전용 진단만 제공한다.

- 아카이브를 열 수 없음
- `scenario.chk`가 없거나 여러 후보가 모순됨
- 섹션 길이가 파일 경계를 벗어남
- 의도적인 중복/오버랩 등으로 유효 해석을 결정할 수 없음
- 저장 시 원본 의미를 유지할 수 있다고 보장할 수 없음

앱은 이러한 맵을 “복구했다”고 표현하지 않는다. 향후 복구 도구가 추가되더라도 일반 편집과 분리하고, 원본이 아닌 새 파일로만 출력한다.

## 10. 참고 구현

- [StormLib](https://github.com/ladislav-zezula/StormLib)
- [Chkdraft](https://github.com/TheNitesWhoSay/Chkdraft)
- [eudplib](https://github.com/armoha/eudplib)

메타데이터 필드 크기와 알려진 값은 구현 시점에
[Chkdraft `chk.h`](https://github.com/TheNitesWhoSay/Chkdraft/blob/7ad7c28c15ab404eb6b535433f518f65a7b6e0f8/src/mapping_core/chk.h)와
[eudplib `chktok.py`](https://github.com/armoha/eudplib/blob/f10e069e0008afa3d473b673c4078b6d8765d105/src/eudplib/core/mapdata/chktok.py)를
교차 확인했다.

참고 구현의 동작은 유용한 증거지만 이 프로젝트의 테스트를 대신하지 않는다.
