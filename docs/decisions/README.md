# 아키텍처 결정 기록

ADR은 되돌리기 어렵거나 여러 컴포넌트에 영향을 주는 결정을 기록한다.

## 상태

- Proposed: 검토 중
- Accepted: 현재 적용
- Superseded: 다른 ADR로 대체
- Deprecated: 더 이상 권장하지 않음

## 목록

| ADR | 상태 | 결정 |
| --- | --- | --- |
| [0001](0001-windows-remastered-first.md) | Accepted | Windows와 StarCraft: Remastered 우선 |
| [0002](0002-lossless-chk-model.md) | Accepted | raw-first 무손실 CHK 모델 |
| [0003](0003-external-euddraft-adapter.md) | Accepted | euddraft 외부 프로세스 어댑터 |
| [0004](0004-stormlib-helper-process.md) | Accepted | StormLib helper process 브리지 |
| [0005](0005-casclib-helper-process.md) | Accepted | CascLib 기반 로컬 StarCraft 데이터 helper |
| [0006](0006-request-scoped-tile-atlas-cache.md) | Accepted | 요청별 RGBA 타일 아틀라스와 메모리 캐시 |
| [0007](0007-object-sprite-atlas-protocol.md) | Accepted | 요청별 객체 스프라이트 아틀라스 프로토콜 |

## 새 ADR 형식

```markdown
# ADR-NNNN: 제목

- Status: Proposed
- Date: YYYY-MM-DD

## Context

## Decision

## Alternatives

## Consequences

## Validation
```

기존 ADR의 결론을 조용히 수정하지 않는다. 결정이 바뀌면 새 ADR을 만들고 이전 문서의 상태를 Superseded로 변경한다.
