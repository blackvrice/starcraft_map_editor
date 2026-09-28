# EUD 런타임 지원 결정

2026-09-28, euddraft 0.10.2.5 / eudplib 0.80.6 기준.
이 표의 지원은 편집·저장·생성·컴파일 경로를 뜻하며 실제 게임 인증이 아니다.

## 이번 규칙에서 제공하는 범위

| 분야 | 결정 | 근거와 제한 |
| --- | --- | --- |
| 자원 | 지원 | 기본 Accumulate/SetResources, 확장 식은 TrgPlayer의 ore/gas 읽기 |
| 업그레이드·연구 | 지원 | Upgrade/Tech의 플레이어 인덱서. 레벨은 maxLevel, 연구는 0/1로 제한 |
| 개체 HP·실드·에너지 | 제한 지원 | EUDLoopUnit2에서 얻은 CUnit만 사용. HP·실드는 종류별 최대량, 에너지는 250으로 제한 |
| 개체 식별 | 제한 지원 | 최초 유효 개체의 EPD와 uniquenessIdentifier를 보존하고 종류·소유자·order·hp를 매 처리 확인. 유효 개체 미발견 시 영구 무효화 |
| 위치·계산 영역 | 지원 | f_setloc의 위치/사각형 설정. 맵 DIM 크기로 제한하며 Anywhere #64 변경 거부 |
| 대상 추적 | 제한 지원 | 바인딩된 살아 있는 개체 중심을 점 로케이션으로 추적. 소멸·변신·소유 변경 시 중단하며 재탐색하지 않음 |
| 동적 텍스트·소리 | 지원 | 지정 로컬 플레이어에게 표시. 동기화 조건/값 계산·1회 상태 처리는 로컬 분기 전에 완료. CurrentPlayer는 복원 |

개체 상태는 각 선택 훅에서 관찰한다. 같은 훅 사이에 발생했다가 사라진 변신이나
소유 변경을 이벤트 이력으로 복원하지 않는다. uniquenessIdentifier는 1바이트여서
세대 래핑을 무한 수명 식별자로 간주할 수 없다. 기본 1700 슬롯 프로필만 다루며
사용자 Unlimiter/임의 메모리 변조와의 조합은 지원 검증 대상이 아니다.
따라서 편집기에서 영구 개체 ID나 모든 생성/소멸 이벤트 수집을 표방하지 않는다.

## 조사 후 보류하는 범위

| 분야 | 현재 결정 | 보류 이유 / 재개 조건 |
| --- | --- | --- |
| 버튼셋 교체 | 실행 규칙 보류 | CUnit.currentButtonSet 필드는 있지만 버튼 테이블 수명·공유·클라이언트 표시 검증이 없다. 별도 형식/할당 모델과 두 클라이언트 테스트 필요 |
| 생산·연구 요구 조건 | 실행 규칙 보류 | requirementOffset은 요구 조건 프로그램의 위치이지 일반 정수 설정이 아니다. 바이트코드 검증·참조 수명·게임 내 재평가 절차 필요 |
| Order | 기본 트리거 Order 사용 | order 번호 직접 쓰기는 대상·큐·하위 상태를 일관되게 갱신하지 않는다. 기본 Order는 일반 Triggers에 있으며 원시 Order 필드 쓰기는 제공하지 않음 |
| IScript | 런타임 교체 보류 | Image.iscript 참조만으로 이미 실행 중인 애니메이션 VM의 명령 포인터·지역 상태를 안전하게 전환할 근거가 부족함 |
| 지형 | 런타임 변경 보류 | MTXM/TILE 변경과 표시, 충돌, 경로 탐색 데이터 재생성은 같은 작업이 아니다. 검증된 원자적 갱신 API와 멀티플레이 사례 필요 |
| 안개 | 런타임 직접 쓰기 보류 | 초기 MASK와 실제 플레이어별 시야/탐색 상태를 구분해야 한다. 로컬 렌더링과 동기화 상태 갱신 계약을 먼저 검증해야 함 |
| 두다드 | 런타임 복합 변경 보류 | DD2는 초기 배치 자료이며, 런타임 지형/스프라이트/충돌의 생성·제거를 함께 처리하는 검증된 계약이 없음 |

보류 항목을 완료된 편집 기능으로 표시하거나 임의 주소/포인터 입력으로 대체하지 않는다.
조사 완료와 기능 지원 완료를 구분하며, 위 항목은 M7.1의 조사·지원 결정 요구사항에 대한 결과다.

## 근거

로컬 고정 배포 소스 `eudplib-0.80.6.tar.gz`의 다음 파일을 직접 확인했다.
소스 아카이브 SHA-256은 `5be90f655d29198ef9ab6b4f59c51b1fad62b504752fcf51c1c05461fab71da2`다.

- `scdata/cunit.py`: 필드 타입, order/hp/owner/unitType/uniquenessIdentifier와 최대 1700 슬롯 범위
- `eudlib/utilf/listloop.py`: EUDLoopUnit2의 슬롯 검사, EUDLoopNewUnit의 세대 캐시와 조기 종료
- `scdata/upgrade.py`, `scdata/tech.py`: 플레이어별 현재 상태 인덱서와 원본/Brood War 테이블 구분
- `scdata/unit.py`, `scdata/image.py`: maxHp/maxShield와 요구 조건·IScript 참조
- `eudlib/locf/locf.py`: f_setloc의 인수 및 위치 필드 쓰기
- `string/strbuffer.py`, `eudlib/utilf/userpl.py`: 문자열 버퍼, 로컬 플레이어와 CurrentPlayer 처리

공식 저장소: [eudplib](https://github.com/armoha/eudplib),
[euddraft의 실행 훅](https://github.com/armoha/euddraft/blob/v0.10.2.5/applyeuddraft.py).
API 존재는 게임 동작·성능·동기화 검증을 대신하지 않는다.
