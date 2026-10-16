# ADR-0021: 설정과 트리거 작성의 보존 경계

- Status: Accepted (에디터 계약, 게임 인수 미완료)
- Date: 2026-10-16

## Context

EP2/FR-223·224·225·405를 기존 설정·트리거·Undo 위에 보완한다.
이번에는 자동 테스트/빌드만 허용되었으며 게임 동작을 관찰한 것으로 표시하지 않는다.

## Decision

- 기존 readEudDat의 7개 자산/제품/빌드/SHA256을 재사용한다. DAT projection은
  revision v2/68열로 변경하며 이전 revision은 거절한다. EUD manifest는 확대하지 않는다.
- CRGB는 8개 RGB triple(24바이트) 뒤 8개 mode다. 0=random predefined,
  1=player choice, 2=custom RGB, 3=palette ID. 에디터에서는 CRGB가 COLR보다
  우선한다. duplicate/손상 CRGB를 COLR로 조용히 대체하지 않는다.
- 명시적 리마스터 색상 선택은 COLR를 보존하고 CRGB 추가/수정 및 VER 205→206을
  한 번의 Undo로 적용한다. 새 palette ID는 0~11만 허용한다. 기존 다른 값·미편집
  채널은 보존한다. 화면에 변경 바이트와 VER 전환을 미리 표시한다.
- canvas에는 소유자 색상 표식을 표시한다. 원본 sprite 전체 tint, random/player
  choice의 게임 결과, 확장 palette ID의 실제 렌더는 미지원이다.
- `<HH>`는 원시 바이트, `<<`는 문자 `<`인 가역 token 모드다. NUL은 거절한다.
  잘못된 UTF-8도 대체 문자로 손실시키지 않는다. 공유 ID 변경/단일 참조 분리와
  소리 경로 보호는 기존 정책을 재사용한다. preview는 근사 색상/개행이며 게임 폰트,
  정렬/숨김/이후 제거 효과나 CP949 디코딩을 구현한 것은 아니다.
- 트리거 검색 index는 문서 identity/언어별로 cache한다. 필터 변경 시 선택을
  비운다. 치환은 지원 opcode의 선택된 원본 인덱스만 대상으로 한다. 알려진 읽기
  전용 참조는 유지하고 skip 수를 표시한다. 지원 슬롯의 인자가 하나라도 잘못되면
  전체 preview를 거절한다. Apply는 snapshot 재검증과 기존 atomic Undo를 사용한다.

## Sources

고정 Chkdraft의 [chk.h](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/chk.h),
[scenario.cpp](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/scenario.cpp),
[sc.h](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/mapping_core/sc.h)를
레이아웃/모드/전환 근거로 확인했다. 근사 문자 색상은
[string_guide.cpp](https://github.com/TheNitesWhoSay/Chkdraft/blob/32d27861b16dda0b0f3d95e34bad894ea4efb2c3/src/chkdraft/ui/dialog_windows/map_settings/string_editor/string_guide.cpp)의
표를 대조했다. 이는 실제 게임 실행 근거가 아니다.

## Alternatives and Consequences

일반 설정 조회를 EUD 빌드로 대체하거나, 모든 TRIG 숫자/문자열 바이트를 일괄 치환하지
않는다. 데이터 보존 대신 게임 렌더 모의를 추측하지 않는다. 외부 도구 추가 의존성은 없다.

## Validation

[체크리스트·실행 기록](../SETTINGS_TRIGGER_EDITING.md). 에디터 자동 검증과 로컬
CASC/MPQ 왕복, 실제 앱/게임/외부 에디터 인수는 별개다.
