# ADR-0024: Native Python, Compiler Translation and Draft Recovery

- Status: Accepted
- Date: 2026-10-19

## Context

일반 TRIG 선언과 자유 EUD 코드는 다르다. 문법 치환은 Python 액션 실행 의미를
잃을 수 있으며 모달 안 원문은 기존 맵 자동 저장에 포함되지 않았다.

## Decision

자유 EPS→Python은 고정 관리형 compiler의 별도 no-VM helper로 생성한다.
역방향/Lua는 순서 있는 액션·훅 공통 모델만 지원하고 불확실 코드는 거절한다.
Python native entry는 기존 안전 빌드 파이프라인에 별도 프로필로 합류한다.
편집 문서의 원문을 대체하지 않고 변환 결과를 새 파일로 내보낸다.

미적용 TRIG 초안은 문서 소유 workspace로 옮기고 기존 복구 schema v2에
정확한 CHK 기준·언어·현재 text·loadedText·미저장 원문 이력을 저장한다.
복구는 명시 선택이며 자동 Apply/실행/추측 rebasing을 금지한다.

## Alternatives

임의 Python/Lua 코드를 실행하여 IR을 수집하거나 정규식으로 전체 언어를
번역하는 안은 실행 위험/의미 손실 때문에 채택하지 않는다. 별도 임시 저장소는
체크섬·보관·손상 처리 정책을 중복하므로 기존 RecoveryStore를 재사용한다.

## Consequences

추가 native helper와 프로토콜/예산 검사가 필요하다. 외부 이름 inventory에서
빠진 compiler API는 확장 전 오류로 거절한다. Lua는 native 빌드 언어가 아니다.
checkpoint 완료 이전 마지막 입력의 전원 차단 무손실은 보장하지 않는다.
범위/시나리오/실행 결과는 [구현 계약](../EUD_SOURCE_TRANSLATION_RECOVERY.md)을 따른다.
