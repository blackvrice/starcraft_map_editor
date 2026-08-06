# 256×256 캔버스 성능 기준선

## 목적과 범위

이 기록은 `MapCanvasPainter`가 256×256 맵의 실제 raw 타일 65,536개를 처리할 때
fit, zoom, pan 경로가 병적으로 느려지지 않는지 확인하는 자동 스모크 기준선이다.
Flutter 테스트 엔진의 debug Canvas 명령 기록 시간을 측정하므로 GPU raster FPS나
실제 StarCraft texture 성능을 인증하지 않는다.

## 재현 방법

```powershell
flutter test test/performance/map_canvas_performance_test.dart
```

테스트는 800×600 viewport, raw 값 64종, texture 0개, fallback 레이어 하나로
실행한다. `MapCanvasPaintObserver`가 paint 시간과 texture/fallback/unsupported
타일 수를 기록하며 성공 로그에 `MAP_CANVAS_256_SMOKE` 한 줄을 남긴다. 각 paint의
1초 상한은 30/60 FPS 기준이 아니라 병적인 동기 렌더링 회귀를 찾는 안전망이다.

## 2026-08-06 기준선

| 항목 | 값 |
| --- | --- |
| OS | Windows NT 10.0.26200.0 |
| CPU | Intel Core i7-14700K, 20 cores / 28 logical processors |
| Memory | 63.8 GiB |
| Flutter / Dart | Flutter 3.47.0-0.4.pre / Dart 3.13.0 dev |
| Build mode | Flutter widget test, debug |
| Viewport / map | 800×600 / 256×256 |

| 동작 | Paint 시간 | 가시·그린 타일 |
| --- | ---: | ---: |
| Fit 100% | 28.394 ms | 65,536 |
| Zoom 156.25% | 19.360 ms | 42,840 |
| Pan after zoom | 13.293 ms | 39,917 |

확대·이동 후에는 `MapCanvasLayout.visibleTiles` 범위만 순회해 그린 타일 수가
감소했다. 이 결과는 해당 개발 PC의 한 번의 debug 실행 기준이며 절대적인 릴리스
성능 보장은 아니다.

## Profile FPS 검증

Windows profile 빌드에서 실제 256×256 맵과 StarCraft texture를 연 뒤 DevTools
Performance 화면의 `MapCanvasPainter.paint` Timeline 범위를 찾는다. 맵 크기,
zoom, grid step, 가시 타일 수와 texture 수를 함께 기록하고 Flutter UI/raster
frame timing으로 목표 60 FPS, 최소 30 FPS를 판정한다. 하드웨어, Flutter revision,
맵·레이어·texture 수가 달라지면 이 문서에 별도 결과를 추가한다.
