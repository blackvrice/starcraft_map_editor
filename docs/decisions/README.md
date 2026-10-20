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
| [0008](0008-validated-visual-placement-catalog.md) | Accepted | 검증된 로컬 카탈로그와 종류별 배치 recipe |
| [0009](0009-declarative-eud-project.md) | Accepted | 별도 JSON 프로젝트의 EUD 선언적 설정·저장·Undo 경계 |
| [0010](0010-reviewed-doodad-deletion.md) | Superseded by 0026 | 복원 정보와 명시적 overlay 확인에 따른 단일 Doodad 복합 삭제 |
| [0011](0011-managed-euddraft-bundle.md) | Accepted | updater 대체 소스와 신뢰 목록을 포함한 관리형 euddraft 동봉 |
| [0012](0012-generated-eud-test-builds.md) | Accepted | 선언적 EUD 설정의 명시적 테스트 빌드 |
| [0013](0013-localized-editor-ui.md) | Accepted | 시스템 언어를 따르는 한국어·영어 UI |
| [0014](0014-autosave-recovery-checkpoints.md) | Accepted | 원본과 분리된 미저장 문서 체크포인트·명시적 복구 |
| [0015](0015-power-state-models.md) | Accepted | 실제 전력 상태와 명시적인 사전 배치 설계 모델 분리 |
| [0016](0016-creep-source-boundaries.md) | Accepted | 크립 정적 후보 자료·설계 모델과 실제 관찰 분리, 미확인 유지 |
| [0017](0017-creep-observation-evidence.md) | Accepted | 초기 크립 관찰 시점/권한 증거와 미관찰 타일 unknown·legacy 거절 |
| [0018](0018-creep-capture-input-binding.md) | Accepted | 현재 CHK/리소스/setup 지문과 명시적 typed 수집 포트·결과/취소 결합 |
| [0019](0019-owned-creep-capture-map-preparation.md) | Accepted | 원본 재검증·소유 임시 MPQ의 CHK/WAV 검증과 실제 수집 실행 분리 |
| [0020](0020-observed-creep-placement-policy.md) | Accepted | 명시적 전력/크립 조회 UI·실제 수집 미지원·현재 초기 크립의 opt-in 요구 배치 검사 |
| [0021](0021-settings-trigger-editing.md) | Accepted | 일반 DAT 예상값·CRGB·가역 byte token·snapshot 기반 트리거 참조 치환 |
| [0022](0022-multi-map-document-lifetime.md) | Accepted | 문서별 controller/화면 수명·물리 경로 점유·복구/닫기/종료 격리 |
| [0023](0023-portable-trigger-declarations.md) | Accepted | 일반 TRIG의 세 언어 제한 선언·snapshot/raw 보존·격리 분석·원문/새 파일 보호 |
| [0024](0024-eud-source-translation-and-draft-recovery.md) | Accepted | 공식 EPS→Python·native Python 빌드·공통 EUD 액션 모델과 미적용 초안 복구 |
| [0025](0025-static-source-workspace.md) | Accepted | 실행 없는 다중 소스·원문/충돌 보존·schema v3 복구·빌드 의존 지문 |
| [0026](0026-disabled-doodad-deletion.md) | Superseded by 0027 | 일관된 비활성 두다드의 상태별 overlay 검증·단일 복합 삭제 |
| [0027](0027-atomic-batch-doodad-deletion.md) | Superseded by 0028 | 최대 32개 두다드의 원본 인덱스·명시 귀속 기반 일괄 삭제 |
| [0028](0028-doodad-sprite-mixed-deletion.md) | Superseded by 0029 | 두다드·선택 스프라이트의 원본 THG2 합집합·한 Undo 혼합 삭제 |
| [0029](0029-unit-mixed-doodad-deletion.md) | Superseded by 0030 | 유닛 incoming/outgoing 관계 검증·남는 peer 명시 확인·한 Undo 혼합 삭제 |
| [0030](0030-reviewed-location-mixed-deletion.md) | Accepted | 정적 미참조 Location 슬롯 비우기·고정 ID·명시 확인·한 Undo 혼합 삭제 |

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
