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
| 2026-09-17 | Windows x64, Flutter 3.47.2 / Dart 3.13.2, debug 테스트 바이너리 | 932ms | 292ms | 751ms | 28 | 2000 |

## 합성 썸네일 자원 수명 (2026-09-17)

`test/performance/placement_catalog_thumbnail_performance_test.dart`는 1000×700,
배율 1 화면에서 서로 다른 32×32 RGBA 버퍼 2,000개를 가진 합성 controller로
실제 `PlacementCatalogPane`의 이미지 디코딩·12회 스크롤·검색·닫기를 실행한다.
앱의 전체 로더나 실제 SC:R 자산의 메모리 상한을 측정한 것은 아니다.

| 지표 | Windows debug 관측값 |
| --- | --- |
| 항목 RGBA 버퍼 합계 | 8,192,000 bytes |
| 첫 화면 이미지 핸들 | 96 |
| 최대 동시 이미지 핸들 | 132 |
| 핸들당 픽셀 바이트 합의 최대값 | 540,672 bytes |
| 누적 생성 핸들(재열기 포함) | 926 |
| 검색 1개 항목 뒤 핸들 | 2 |
| 닫기 및 디코딩 도중 닫기 뒤 핸들 | 0 |

`ui.Image.onCreate/onDispose`로 핸들을 추적한다. `RawImage` 렌더 객체가 복제한
핸들도 포함하므로 픽셀 바이트 합은 중복을 포함한 상계이며 GPU VRAM 실측치가
아니다. 버퍼·descriptor·codec 또는 드라이버 메모리까지 해제됐다는 판정도 아니다.
테스트의 전체 소요 시간에는 비동기 디코딩 대기가 포함되어 성능 기준으로 쓰지 않는다.

자동 판정은 최대 핸들 수가 256 미만인지, 스크롤 중 새 이미지가 만들어지는지,
검색 후 1~2개 핸들만 남는지, 정상 닫기와 늦은 디코딩 완료 후 핸들이 모두
해제되는지 확인한다. controller의 원본 RGBA 항목은 화면 닫기만으로 지우지 않는다.
실제 페이지 캐시 상한·반복 재열기·profile/실제 설치 검증은 아래 미완료 범위로 남긴다.

## 남은 작업

2026-09-18 후속 수정: 탭·대화상자의 중복 디코더를 `CatalogThumbnail`으로 통합했다.
기존 구현은 최초 생성 때만 이미지를 읽어 상세 선택 변경 뒤 이전 그림이 남을 수
있었다. 버퍼/크기 변경 시 교체하고 요청 revision으로 늦은 결과를 폐기한다.
회귀 테스트는 실제 픽셀 교체, 같은 버퍼의 크기 변경, 배율 변경 시 재사용,
잘못된 버퍼에서 이전 이미지 제거, 빠른 교체·종료 뒤 이미지 핸들 해제를 검증한다.
합성 카탈로그의 기존 자원 수명 판정도 유지한다.
집중 15개·전체 647개 테스트 통과(선택 환경 16개 skip), 정적 분석과 Windows debug
빌드·5초 시작 스모크 통과. Flutter 3.47.2/Dart 3.13.2에서 검증했으며 기준 SDK와
실제 화면 수동 조작은 미검증이다. 변경 파일 포맷은 통과했고 전체 검사에는 기존
infrastructure 테스트 4개의 포맷 차이가 남아 있다.

- Windows 10/11 x64에서 profile 빌드로 같은 지표를 재고 이 표에 기록한다.
- 실제 로컬 SC:R 설치의 Doodad 카탈로그(타일셋당 194~1,217개, 총 6,730개)와
  실제 썸네일로 재측정한다. 위 수치는 썸네일이 없는 합성 항목 기준이다.
- 실제 썸네일 cache 메모리 상한과 탭을 떠난 뒤 GPU 자원 해제를 계측한다.
  합성 화면의 이미지 핸들 해제 회귀는 추가했지만 실제 GPU 메모리는 미측정이다.
- CI 변동 폭을 확인한 뒤 시간 상한을 확정할지 결정한다.

## 실행 방법

```powershell
flutter test test/performance/placement_catalog_performance_test.dart
flutter test test/performance/placement_catalog_thumbnail_performance_test.dart
```

측정값은 테스트 출력의 `placement-catalog perf` 줄에 나온다.
