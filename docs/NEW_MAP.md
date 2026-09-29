# 새 맵 생성 정책과 CHK 생성기

2026-09-29: M6.4 생성 규칙 및 도메인 생성기 완료. **New Map 화면과 신규 MPQ
저장은 다음 항목이며 아직 앱에서 새 맵을 생성할 수 없다.**

## 통합 작업 인수인계 (2026-09-29)

`bad4bab`은 아래 도메인 생성기까지만 완료한 커밋이다. 후속 작업 트리에는
`ExtractedMap.inMemory`, nullable 원본 경로/fingerprint, `OpenMapController.createNew`,
새 문서 Save As 분기와 helper `createScenario`(예정 버전 0.5.0)가 추가되어 있다.
이 변경은 아직 커밋·native 검증되지 않았고 New Map UI도 연결하지 않았다.

이어 할 일: 로컬 카탈로그로 검증한 초기 타일 선택 대화상자, 기존 미저장 문서
교체 확인, 취소/실패 시 기존 세션 유지, 신규 MPQ 생성/재열기·출력 보호 테스트,
Windows 빌드·CTest·시작 검증. 도메인 생성기의 테스트 통과를 이 통합의 검증으로
대체하지 않는다. 작업 중인 코드를 제거하거나 신규 기능 완료로 표시하지 않는다.

## 현재 구현

`NewMapOptions`와 `NewMapFactory`는 기존 맵·템플릿·파일 시스템 없이 새 CHK
문서를 만든다. 입력이나 생성이 실패하면 기존 문서를 변경하지 않는다. 생성된
섹션은 모두 dirty다. 성공한 저장 뒤 clean 상태로 전환하는 책임은 다음 단계의
문서 세션에 있으며, 생성기가 디스크 파일이나 가짜 원본 경로를 만들지 않는다.

| 항목 | 최초 지원 정책 |
| --- | --- |
| 버전 | Brood War UMS, `TYPE=RAWB`, `VER=205`, `IVE2=11`, 출력 확장자 `.scx` |
| 크기 | 가로·세로 각각 32~256, 32의 배수; 기본 128×128; 직사각형 허용 |
| 타일셋 | 기존 `ChkTileset` 8종, 기본 Badlands |
| 초기 지형 | 호출자가 명시한 u16 raw 타일 하나로 MTXM·TILE을 동일하게 채움 |
| 플레이어 | 앞에서부터 Human 1~8명, 기본 1명, 초기 종족 Terran; 나머지 비활성, P12 Neutral |
| 시작 위치 | 활성 플레이어마다 UNIT #214 한 개; 한 명이면 중앙, 여러 명이면 서로 다른 사분점/변 중간점 |
| 세력 | 전원 Force 1, 동맹·공동 승리·공유 시야·무작위 시작 옵션은 해제 |
| 안개 | MASK 각 바이트 `0xff`; 플레이어별 편집 도구는 후속 범위 |
| 트리거 | TRIG·MBRF는 빈 목록; 자원·승리·패배·건물·일꾼을 자동 추가하지 않음 |
| 문자열 | 제목·설명 UTF-8, 단일 STR; NUL 금지, 제목 공백만 금지, 65535바이트 초과 거부 |
| 로케이션 | 255개; ID 64 Anywhere만 맵 전체 픽셀 범위, 나머지는 비어 있음 |
| 유닛/비용 | UNIx·UPGx·TECx의 기본값 사용 flags=1; 비활성 사용자 override는 0 |
| 생산/연구 | PUNI 허용/상속=1, PUPx 시작 레벨=0/표준 최대 레벨, PTEx 표준 연구 상태와 플레이어 상속 |

초기 타일 번호의 숫자 범위와 로컬 게임 자산 검증은 별개다. 도메인 생성기는
0~65535만 검사한다. UI 연결 시 해당 타일셋의 CV5 범위·렌더 성공을 검증한
카탈로그 타일만 선택하도록 해야 한다. 시작 위치의 좌표 범위·소유자·중복은
검사하지만 지형의 보행 가능성은 아직 보장하지 않는다.

ISOM은 생성하지 않는다. 등각 지형 생성/전환 기능이 준비되기 전에는 이 경로를
raw 타일 맵으로 표시해야 한다. TILE은 생성 시 MTXM과 일치하지만, 기존 raw
브러시 편집은 MTXM만 변경한다. 외부 에디터의 등각 지형 상호 운용 완료를
뜻하지 않는다. 기존 맵을 이 생성기로 정규화하거나 자동 복구하지 않는다.

## 생성 섹션

각 섹션은 정확히 한 번, 아래 순서로 생성한다. 이 목록은 이 제품의 생성
프로파일이며 모든 게임 버전의 최소 필수 섹션 목록이라는 뜻은 아니다.

```text
TYPE VER  IVE2 VCOD IOWN OWNR ERA  DIM  SIDE MTXM PUNI UNIT
TILE DD2  THG2 MASK STR  UPRP UPUS MRGN TRIG MBRF SPRP FORC
WAV  SWNM COLR PUPx PTEx UNIx UPGx TECx
```

- VCOD 1040바이트는 기존 자체 제작 게임 검증 맵의 데이터와 동일하다.
  `default_validation_code.dart`를 fixture 도구와 제품 생성기가 공유한다.
- MTXM/TILE은 폭×높이×2, MASK는 폭×높이, UNIT은 플레이어 수×36,
  MRGN은 255×20바이트다. ISOM과 구버전 설정 대체 섹션은 추가하지 않는다.
- STR의 ID 1은 제목, 2는 설명, 3은 Anywhere, 4~7은 세력 이름이다.
  빈 설명은 SPRP에서 ID 0을 참조한다. 설명을 비워도 이후 문자열 ID는 안정적이다.
- PUNI 5700, PUPx 2318, PTEx 1672, UNIx 4168, UPGx 794, TECx 396바이트.
- UPRP 1280, UPUS 64, WAV 2048, SWNM 1024바이트는 전부 0으로 시작한다.
- 출력은 `RawChkEncoder`로 인코딩하고 `RawChkParser` 및 기존 typed decoder로
  다시 읽을 수 있다. VCOD golden SHA-256과 모든 생성 결과의 바이트 왕복을 검증한다.

## 다음 항목의 연결 계약

1. New Map 대화상자에서 크기·타일셋·검증된 초기 raw 타일·플레이어 수·제목을
   입력한다. 취소/오류/미저장 변경 확인 취소는 기존 문서와 기록을 유지한다.
2. `OpenedMapSession`에 원본 파일이 없는 상태를 명시적으로 추가한다. 없는
   파일의 fingerprint를 만들거나 기존 맵을 복제해 새 문서처럼 표시하지 않는다.
3. MPQ 포트와 helper에 신규 아카이브 생성 연산을 추가한다. 기존 파일 교체 연산과
   구분하고 버전·로그·취소·출력 검증 계약을 유지한다.
4. Save As는 신규 MPQ 임시 출력 → CHK/리소스 재검증 → 승격 → 새 세션 채택을
   수행한다. 실패하면 미저장 문서를 유지하고 목적지 파일을 손상하지 않는다.
5. 실제 MPQ 신규 생성/재열기, 시작 위치·플레이어·타일 검증, 외부 에디터 및
   SC:R 실행을 별도로 확인한다. 생성기 단위 테스트는 게임 인수 검증을 대체하지 않는다.

## 조사 근거와 제품 결정

고정된 Chkdraft commit `32d27861b16dda0b0f3d95e34bad894ea4efb2c3`의
[CHK 구조 및 기본값](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h#L1249-L1600)과
[새 시나리오 생성](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/scenario.cpp#L526-L648)을 대조했다.
섹션 구조, VCOD, 업그레이드·테크 기본 상태, Anywhere ID의 근거로 사용했다.
최초 지원 크기·플레이어·빈 트리거·raw 타일/ISOM 제외는 이 제품의 범위 결정이다.
구현 코드를 복사하거나 게임 DAT/CV5 원시 자산을 포함하지 않았다.

## 검증

`test/domain/chk/new_map_factory_test.dart`에서 결정성, dirty 상태, 바이트 왕복,
기존 설정 편집기로의 읽기, 문자열·객체 참조, 플레이어 시작 위치, 8개 타일셋,
직사각형과 최소/최대 크기, 잘못된 입력/초과 문자열 거부를 검증한다.
새 맵 UI·새 MPQ 생성·실제 게임 검증은 이 단계의 구현에 포함되지 않는다.

2026-09-29 실행 결과: 생성기 10개 포함 전체 774개 통과(선택 환경 27개 skip),
`flutter analyze` 통과. Flutter 3.47.2 / Dart 3.13.2로 검증했으며 기준 SDK는
3.44.8 / 3.12다. 변경 파일 format은 통과했고 전체 format은 기존 무관한
infrastructure 테스트 4개의 차이로 실패했다.
