# 배치 카탈로그 탭 성능 기준선

- 측정 대상: `PlacementCatalogPane`의 첫 페이지 표시, 검색 응답, 연속 스크롤과
  페이지 추가 로딩
- 계측 코드: `test/performance/placement_catalog_performance_test.dart`
- 상태: **기준선 미확정.** 아래 수치는 Linux 컨테이너의 debug 테스트 바이너리에서
  나온 상대 신호이며 릴리스 기준이 아니다.

## 무엇을 재는가

합성 카탈로그 2,000개 항목을 한 종류(Doodad)에 넣고 다음을 잰다.

| 지표 | 의미 |
| --- | --- |
| `firstPage` | 탭 표시 + 종류 전환 + 첫 페이지(256개) 표시까지 |
| `search` | `#숫자 ID` 입력 후 grid가 한 항목으로 좁혀질 때까지 |
| `scroll12` | 600px씩 12회 스크롤과 그동안의 페이지 추가 로딩 |
| `builtTiles` | 실제로 build된 grid 타일 수. 가상화가 동작하는지 판정한다 |
| `loadedEntries` | 스크롤 뒤 컨트롤러가 보유한 항목 수 |

## 자동 판정

이 테스트는 시간에 상한을 걸지 않는다. 시간은 실행 환경마다 크게 달라지므로
회귀 판정은 구조적 성질로 한다.

- `builtTiles`가 한 페이지의 절반 미만이어야 한다. 가상화가 깨지면 실패한다.
- 스크롤 뒤 `loadedEntries`가 한 페이지보다 커야 한다. 페이지 추가 로딩이
  끊기면 실패한다.

## 측정 기록

| 날짜 | 환경 | firstPage | search | scroll12 | builtTiles | loadedEntries |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-09-07 | Linux 컨테이너, Flutter 3.44.8, debug 테스트 바이너리 | 1459ms | 338ms | 1006ms | 29 | 2000 |

## 남은 작업

- Windows 10/11 x64에서 profile 빌드로 같은 지표를 재고 이 표에 기록한다.
- 실제 로컬 SC:R 설치의 Doodad 카탈로그(타일셋당 194~1,217개, 총 6,730개)와
  실제 썸네일로 재측정한다. 위 수치는 썸네일이 없는 합성 항목 기준이다.
- 썸네일 cache 메모리 상한과 탭을 떠난 뒤 GPU 자원 해제를 계측에 포함한다.
- CI 변동 폭을 확인한 뒤 시간 상한을 확정할지 결정한다.

## 실행 방법

```powershell
flutter test test/performance/placement_catalog_performance_test.dart
```

측정값은 테스트 출력의 `placement-catalog perf` 줄에 나온다.
