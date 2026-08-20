# 256×256 객체 스프라이트 성능 기준선

## 목적과 범위

이 기록은 256×256 맵에 다수 객체가 있을 때 객체 key 중복 제거, RGBA에서
`ui.Image` 생성, 객체 전용 LRU 메모리 계산과 `MapCanvasPainter`의 이미지·marker
경로가 병적으로 느려지지 않는지 확인하는 자동 스모크 기준선이다. Flutter widget
test의 debug Canvas 기록 시간이므로 실제 GPU raster FPS나 CascLib 프로세스 I/O를
인증하지 않는다.

## 재현 방법

```powershell
flutter test test/performance/object_sprite_performance_test.dart
```

테스트는 자체 작성 CHK view에 4,096개 unit placement를 64×64 격자로 만들고,
256개 고유 object key를 반복한다. 가짜 Application gateway는 240개의 32×32 RGBA
프레임과 16개의 unsupported key를 반환한다. 실제 `UiObjectSpriteTextureFactory`가
240개의 `ui.Image`를 생성하며, canvas는 800×600 viewport에서 fit·zoom·pan을
그린다. 게임 자산과 CascLib은 사용하지 않는다.

자동 게이트는 다음 상한을 사용한다.

- 객체 texture synchronize: 2초 미만
- 각 debug paint: 1초 미만
- 객체 LRU 계산 메모리: 64 MiB 이하
- clear 이후 객체 LRU 계산 메모리: 0 bytes

이 상한은 30/60 FPS 목표가 아니라 교착이나 병적인 동기 회귀를 찾는 안전망이다.
`ProcessInfo.currentRss` 변화는 Flutter engine과 테스트 프로세스 할당이 섞이므로
관찰값으로만 기록하고 자동 성공 조건으로 사용하지 않는다.

## 2026-08-20 기준선

| 항목 | 값 |
| --- | --- |
| OS | Windows 11 Pro 10.0.26200 |
| CPU | Intel Core i7-14700K, 20 cores / 28 logical processors |
| Memory | 63.8 GiB |
| Flutter / Dart | Flutter 3.48.0-0.2.pre / Dart 3.13.0 dev |
| Build mode | Flutter widget test, debug |
| Viewport / map | 800×600 / 256×256 |
| Placements / unique keys | 4,096 / 256 |
| Images / fallback keys | 240 / 16 |

| 동작 | 시간 | 객체·메모리 |
| --- | ---: | ---: |
| Texture synchronize | 46.844 ms | cache 983,040 bytes |
| Fit paint | 15.853 ms | 4,096 painted |
| Zoom 156.25% paint | 4.253 ms | 2,681 painted / 1,415 culled |
| Pan after zoom paint | 4.760 ms | 2,540 painted / 1,556 culled |

같은 실행에서 RSS 변화는 +27,213,824 bytes였지만 JIT, codec과 Flutter engine
할당이 포함된 관찰값이다. LRU의 결정적 성공 조건은 240 × 32 × 32 × 4 =
983,040 bytes이고 설정 해제 시 0 bytes로 돌아가는 것이다.

## Profile 검증

Windows profile 빌드에서는 실제 256×256 맵과 로컬 StarCraft 객체 texture를 연
뒤 DevTools에서 `MapCanvasPainter.paint` Timeline의 `objectPointCount`와
`availableObjectTextureCount`를 확인한다. Flutter UI/raster frame timing으로 목표
60 FPS, 최소 30 FPS를 판정하고 helper 실행 시간, 실제 texture 수, LRU bytes와
프로세스 RSS를 함께 기록한다.
