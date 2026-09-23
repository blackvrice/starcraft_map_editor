# 배치 카탈로그 탭 성능 기준선

- 측정 대상: `PlacementCatalogPane`의 첫 페이지 표시, 검색 응답, 연속 스크롤과
  페이지 추가 로딩
- 계측 코드: `test/performance/placement_catalog_performance_test.dart`
- 상태: 합성 Windows profile 기준선과 반복 실행 집계를 추가했다. 실제 자산의
  UI profile·GPU 메모리는 미검증이며 아직 릴리스 성능 판정 기준은 아니다.
  반복 집계 도구는 구현했으나 이번 Windows 실행 차단으로 반복 관측값은 없다.

## 무엇을 재는가

### 잘못된 페이지 연결 차단 (2026-09-23)

개별 페이지의 정렬·개수 검증 외에 controller가 이전 페이지와의 연결도 검사한다.
전체 항목 수 변경, 예상보다 이른 빈 페이지, 이전 마지막 키 이하에서 시작하는
페이지는 `PLACEMENT_CATALOG_INCONSISTENT_PAGE`로 거부한다. 기존 항목·미리보기·
전체 개수를 보존하고 `hasMore`를 false로 처리해 추가 스크롤 요청을 멈춘다.
종류를 다시 선택해 `load`하면 오류를 지우고 첫 페이지부터 재시도한다.

이 검사는 이미 반환된 썸네일을 목록에 누적하기 직전에 수행한다. 잘못된 페이지의
첫 helper/atlas 요청까지 예방하거나 정상 카탈로그의 총 메모리를 제한하지는 않는다.
Tile/Doodad/Unit/Sprite 각각에 대해 겹친 페이지·변경된 전체 개수·조기 종료를
주입한 12개 회귀가 기존 항목 보존, 후속 요청 중단, 재로딩 복구와 CHK 바이트
불변을 확인한다. 정상 페이징 검증은 유지한다.

검증: 전체 690개 통과·21개 선택 환경 skip, 정적 분석·Windows Debug 빌드 통과.
실제 로컬 Unit 228개(8페이지)·Sprite 517개(17페이지)의 전체 로딩과 종료 후 참조
해제 테스트도 별도 통과했다. Flutter 3.47.2/Dart 3.13.2에서 검증했으며 기준 SDK는
미검증이다. 변경 파일 포맷은 통과했고 전체 검사에는 기존 infrastructure 테스트
4개의 차이가 남아 있다. Profile 반복·GPU 실측은 이전 실행 정책 차단으로 대기한다.

### Tile 썸네일 중간 복사 제거 (2026-09-23)

`TilePlacementCatalogLoader`는 atlas의 타일 구간을 임시 `Uint8List.sublistView`로
참조한 뒤 `TilePlacementCatalogBatch` 생성 시 독립적인 불변 버퍼로 한 번 복사한다.
기존 `sublist` → `fromList` → batch 방어 복사의 세 번 중 중간 두 번을 제거했다.
256개 페이지의 썸네일 추출 단계에서 복사하는 픽셀 payload는 코드 경로상 3MiB에서
1MiB로 줄어든다. atlas 생성·역직렬화·UI 디코딩과 객체 할당은 이 계산에 포함하지
않으며 실제 peak 메모리 감소량이나 실행 시간 개선을 측정한 값은 아니다.

최종 썸네일은 atlas 전체의 backing buffer를 보유하지 않고 각각 4,096 bytes만
소유한다. 공개 batch 생성자는 계속 방어 복사하므로 호출자가 원본 버퍼나 입력
map을 수정해도 결과가 바뀌지 않는다. 불변 버퍼의 `buffer.asUint8List()` 경로도
쓰기 불가능하다. 회귀 테스트는 타일별 픽셀, offset 0, backing buffer 크기,
외부 입력 변경과 쓰기 거부를 검증한다. 기존 취소·응답 불일치·진단 테스트도 유지한다.
전체 카탈로그 캐시 상한과 GPU 메모리 계측은 여전히 별도 미완료 항목이다.

검증: 타일 로더 8개·전체 678개 통과(21개 선택 환경 skip), 실제 로컬 Tile 배치와
바이트 정확 Undo 별도 1개 통과, 정적 분석·Windows Debug 빌드 통과. Flutter 3.47.2/Dart 3.13.2에서
검증했고 기준 SDK는 미검증이다. 변경 파일 포맷은 통과했으며 전체 포맷 검사에는
기존 infrastructure 테스트 4개의 차이가 남아 있다. Profile 반복 측정은 이전
Windows 앱 제어 정책 차단으로 대기 상태를 유지한다.

### Windows profile 자동 실행 (2026-09-20)

`tool/catalog_profile.dart`는 실제 `PlacementCatalogPane`를 profile 모드에서
실행하는 별도 계측 진입점이다. 합성 Doodad 항목 2,000개와 독립적인 32×32 RGBA
버퍼를 메모리에 준비하고 256개씩 공개한다. 외부 helper·게임 데이터 조회 시간은
포함하지 않는다. 첫 이미지 표시, 검색 상태 반영, 600px/200ms 스크롤 12회,
화면 제거 후 이미지 핸들 해제를 자동 실행한다.

원시 기록: [catalog-profile-2026-09-20.json](catalog-profile-2026-09-20.json).
Flutter 3.47.2/Dart 3.13.2, Windows x64, 실제 view 1264×681·배율 1에서 측정했다.

| 지표 | 첫 관측값 |
| --- | --- |
| 첫 이미지 / 검색 | 22ms / 67ms |
| 스크롤 12회(애니메이션 시간 포함) | 2,724ms |
| 첫 화면 생성 항목 / 스크롤 후 로딩 항목 | 56 / 1,024 |
| 수집 프레임 / build p95 / raster p95 | 171 / 1,417µs / 8,261µs |
| 최대 이미지 핸들 / 닫은 뒤 핸들 | 160 / 0 |
| 공개된 항목의 RGBA 합계 | 4,194,304 bytes |

전체 합성 버퍼 8,192,000 bytes는 계측 fixture가 미리 보유한다. 공개 항목의 합계는
전체 프로세스 메모리나 GPU VRAM이 아니다. 핸들은 렌더러의 복제도 포함한다.
첫 이미지 시간은 프로세스 시작/fixture 준비를 제외하고 첫 이미지 하나가 보일
때까지다. 검색은 텍스트 입력 대신 controller.setQuery를 호출한다. 위의 시간과
아래 debug 테스트의 첫 페이지 시간은 서로 다른 지표로 직접 비교하지 않는다.

도구는 프레임 수집, 초기 항목 128개 미만, 추가 페이지 로딩, 종료 후 핸들 0개를
검사한다. 실패/시간 초과는 JSON에 원인을 남기고 비정상 종료하며 기존 결과 파일은
덮어쓰지 않는다. 단일 관측이므로 시간에 통과/실패 상한은 두지 않았다.

```powershell
$report = Join-Path $env:TEMP ('catalog-profile-' + [guid]::NewGuid().ToString('N') + '.json')
flutter build windows --profile --target tool/catalog_profile.dart "--dart-define=CATALOG_PROFILE_OUTPUT=$report"
$app = Start-Process -FilePath 'build/windows/x64/runner/Profile/starcraft_map_editor.exe' -WindowStyle Hidden -PassThru
$app.WaitForExit()
Get-Content -LiteralPath $report
# 일반 앱을 profile로 실행할 때는 계측 진입점을 되돌려 빌드한다.
flutter build windows --profile --target lib/main.dart
```

profile 빌드 과정에서 발견한 Doodad 네이티브 테스트의 `NDEBUG` 문제도 수정했다.
테스트 대상에만 `/UNDEBUG`를 적용하고 컴파일 가드로 assert 비활성화를 거부한다.
제품 바이너리의 최적화 설정은 바꾸지 않는다. Profile CTest 5개가 통과했다.

검증: 전체 Flutter 테스트 658개 통과·21개 선택 환경 skip, 정적 분석 통과.
Profile/Debug CTest 각 5개, 일반 Debug 앱 빌드·5초 시작 확인 통과.
Flutter 도구 실행 중 SDK Git 조회 오류로 캐시가 자동 재구성됐고, 이후 깨끗한 SDK
HEAD `d3b14c876900e553bc736ca19295fc09e3853e8e`와 고정 engine
`a804b261645ef8c13eb3d5c44a5c2fb0340c5539`를 확인했다. 후속 빌드는 SDK의
`bin/internal/engine.version`을 프로세스 한정 `FLUTTER_PREBUILT_ENGINE_VERSION`으로
지정했다. 기준 Flutter 3.44.8 검증은 미실행이며 전체 포맷 검사에는 기존
infrastructure 테스트 4개의 차이가 남아 있다.

### 같은 빌드 반복 계측 (2026-09-22)

계측 진입점은 프로세스 환경 변수 `CATALOG_PROFILE_OUTPUT`을 우선하며, 없을 때
기존 dart-define을 사용한다. 한 번 빌드한 실행 파일을 새 프로세스로 반복 실행해
각 결과를 별도 파일에 남길 수 있다. 환경 변수도 절대 경로·기존 파일 거부 규칙을
따른다. 이 변수는 일반 앱 진입점에는 영향을 주지 않는다.

`tool/summarize_catalog_profile.dart`는 최소 3개 결과의 각 지표에 대해
최소/중앙/최대값과 원시 실행 목록을 JSON으로 출력한다. 느린 실행이나 첫 실행을
제외하지 않는다. 실패 결과, 중복 입력 파일, 누락/음수 지표, 남은 이미지 핸들,
가상화·페이징·프레임 수집 실패와 다른 SDK/OS/fixture/화면 크기/배율은 거부한다.
`buildP95Us`와 `rasterP95Us`의 집계는 **각 실행 p95의 분포**이며 전체 프레임을
합친 p95가 아니다. 같은 빌드인지 여부는 호출자가 보장해야 한다.

```powershell
flutter build windows --profile --target tool/catalog_profile.dart
if ($LASTEXITCODE -ne 0) { throw 'Profile build failed' }
$previousOutput = $env:CATALOG_PROFILE_OUTPUT
$reports = @()
try {
  foreach ($i in 1..5) {
    $report = Join-Path $env:TEMP ('catalog-profile-' + [guid]::NewGuid().ToString('N') + '.json')
    $env:CATALOG_PROFILE_OUTPUT = $report
    $app = Start-Process -FilePath 'build/windows/x64/runner/Profile/starcraft_map_editor.exe' -WindowStyle Hidden -PassThru
    $finished = $false
    foreach ($attempt in 1..3) {
      if ($app.WaitForExit(30000)) { $finished = $true; break }
    }
    if (!$finished) { $app.Kill(); $app.WaitForExit(); throw 'Profile run timed out' }
    if ($app.ExitCode -ne 0) { throw "Profile run failed: $report" }
    $reports += $report
  }
  dart run tool/summarize_catalog_profile.dart @reports
  if ($LASTEXITCODE -ne 0) { throw 'Profile summary failed' }
} finally {
  $env:CATALOG_PROFILE_OUTPUT = $previousOutput
  flutter build windows --profile --target lib/main.dart
  if ($LASTEXITCODE -ne 0) { throw 'Normal app restore failed' }
}
```

2026-09-22 검증: 집계 단위 테스트 15개와 Profile 빌드가 통과했다. 실제 반복 실행은
Windows 애플리케이션 제어 정책의 실행 파일 차단으로 시작하지 못했다. 따라서
새 반복 측정 결과 파일이나 변동 폭 수치는 추가하지 않았고 첫 단일 관측값만
유지한다. 실행이 허용된 환경에서 위 명령으로 반복 계측해야 한다. 테스트의
수치 검증은 기존 원시 결과를 입력 형태로 사용하며 새 성능 측정을 뜻하지 않는다.

전체 Flutter 테스트 673개 통과·21개 선택 환경 skip, 정적 분석과 CLI 입력/중복
파일 거부 검사 통과. Flutter 3.47.2/Dart 3.13.2에서 검증했으며 기준 SDK는
미검증이다. 전체 포맷 검사에는 기존 infrastructure 테스트 4개의 차이가 남아
있고 변경한 Dart 파일은 포맷 검사를 통과했다.

### 기존 debug 위젯 계측

#### 검색 결과 재사용 (2026-09-23)

`PlacementCatalogItem`은 이름·종류·ID·분류를 합친 소문자 검색 문자열을 처음
필요할 때 한 번 만든다. `PlacementCatalogState`는 검색어를 한 번 분리하고
불변 상태별 필터 결과를 재사용한다. 빈 검색은 기존 불변 항목 목록을 그대로
반환한다. 같은 화면 상태를 다시 그릴 때 전체 항목 문자열 생성·검색·결과 목록
할당이 반복되지 않는다. 검색어나 페이지가 바뀐 새 상태는 독립적으로 계산한다.

캐시는 각 항목/상태의 수명에 묶여 있으며 전역 검색 이력은 저장하지 않는다.
이전에 조회한 항목에는 정규화 문자열, 검색한 상태에는 결과 참조 목록이 추가로
남는다. 외부에서 이전 상태를 보관하면 그 상태의 결과도 남으며, 이 변경은 전체
썸네일 cache나 GPU 메모리 상한을 설정하지 않는다.

회귀 테스트는 대소문자·여러 공백·분류·ID·모든 검색어 일치 규칙, 2,000개 항목의
100회 조회 시 같은 불변 결과 재사용, 검색/페이지 변경 뒤 이전 결과 오염 방지를
확인한다. 기존 2,000개 카탈로그 위젯 계측도 통과했다(단일 debug 관측: 첫 페이지
739ms, 검색 284ms, 스크롤 750ms, 생성 타일 28개). 이 수치는 Profile 성능 개선의
증거가 아니며, 실제 속도 비교는 반복 Profile 측정이 가능한 환경에서 진행한다.

검증: 집중 5개 및 전체 Flutter 테스트 677개 통과·21개 선택 환경 skip, 정적 분석과
Windows Debug 빌드 통과. Flutter 3.47.2/Dart 3.13.2에서 검증했으며 기준 SDK는 미검증이다. 변경 파일
포맷은 통과했고 전체 검사에는 기존 infrastructure 테스트 4개의 포맷 차이가 남는다.
이전 앱 제어 정책 차단으로 이번 작업에서도 Windows Profile 반복 실측은 수행하지
않았다.

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

## 실제 객체 카탈로그 로딩·보유량 (2026-09-18)

Windows x64, Flutter 3.47.2/Dart 3.13.2 debug 테스트에서 로컬 StarCraft 설치와
실제 catalog/object atlas gateway를 사용했다. Jungle 맵, 페이지 크기 32로
유닛·pure Sprite를 끝까지 읽는다. 측정 코드는
`test/application/placement_catalog_controller_test.dart`의
`profiles complete local object catalogs and clears retained thumbnails`다.

| 종류 | 항목/썸네일 | 페이지 | 보유 RGBA bytes | 최대 한 장 bytes | 첫 페이지 | 전체 |
| --- | --- | --- | --- | --- | --- | --- |
| Unit | 228/228 | 8 | 11,406,144 | 262,144 | 457ms | 3,437ms |
| pure Sprite | 517/517 | 17 | 32,117,728 | 262,144 | 390ms | 6,597ms |

각 페이지의 항목 증가, 전체 ID 중복 없음, 썸네일 크기와 RGBA 길이, 탐색 전후
CHK 바이트 보존을 검사한다. 설치 경로 해제 후 controller의 항목·총 개수·선택이
비워지는 것도 확인한다. 이 검사는 원본 버퍼를 참조하는 목록의 초기화를 확인하며
GC 완료나 GPU 메모리 반환까지 보장하지 않는다.

보유량은 현재 종류의 모든 페이지를 읽은 상태의 RGBA 합계다. 두 종류를 동시에
보유하는 값도, 강제 메모리 상한도 아니다. 임시 복사·helper 프로세스·Dart 객체·
GPU 이미지는 포함하지 않는다. 시간은 파일 시스템 캐시 등 실행 환경에 의존하며
화면 프레임 성능이나 Windows profile 기준선으로 사용하지 않는다.

```powershell
$env:STARCRAFT_TEST_INSTALLATION = 'C:\Program Files (x86)\StarCraft'
$env:STARCRAFT_DATA_HELPER_PATH = (Resolve-Path 'build/windows/x64/runner/Debug/starcraft_data_helper.exe').Path
flutter test test/application/placement_catalog_controller_test.dart --plain-name 'profiles complete local'
```

환경 변수가 없으면 이 실제 설치 계측 한 건을 skip한다. 이미지 파일은 저장하지 않는다.
검증: 실제 설치 계측 1개 통과, 기본 전체 647개 통과·21개 skip, 정적 분석 통과.
변경 파일 포맷은 통과했으며 전체 검사에는 기존 infrastructure 테스트 4개의 차이가
남아 있다. 기준 SDK 검증은 미실행이며 이번 테스트·문서 변경에는 앱 재빌드와
화면 실행을 반복하지 않았다.

## 남은 작업과 후속 수정

### 오래된 Tile 카탈로그 후속 작업 차단 (2026-09-20)

Tile 페이지에도 요청 시작 전, catalog 응답 뒤, atlas 응답 뒤 무효화 확인을
적용했다. 설치·맵·종류 변경 또는 종료 뒤에는 새 타일 atlas 렌더를 시작하지
않고, 이미 받은 atlas에서 32×32 썸네일을 추출/복사하거나 목록에 반영하지 않는다.
로더 진단은 `SC_CATALOG_TILE_REQUEST_CANCELLED`이며 오래된 요청의 진단을
현재 화면에 반영하지 않는다. 진행 중인 helper 강제 종료나 타일 캐시 전체
상한을 추가한 것은 아니다.

로더 회귀는 세 무효화 시점을, controller 회귀는 설치 변경·맵 동기화·종료 뒤
atlas 호출 0회와 빈 상태 유지를 확인한다. 실제 로컬 Tile 브러시 적용과
바이트 정확 Undo/Redo 검증도 통과했다.

검증: 로더 집중 7개·실제 Tile 1개, 전체 658개 통과·21개 선택 환경 skip.
정적 분석과 Windows debug 빌드·5초 시작 스모크 통과. Flutter 3.47.2/Dart 3.13.2로
검증했으며 기준 SDK는 미검증이다. 변경 파일 포맷은 통과했고 전체 검사에는 기존
infrastructure 테스트 4개의 포맷 차이가 남아 있다.

### 오래된 객체 카탈로그 후속 작업 차단 (2026-09-20)

Unit/Sprite 페이지 로더는 요청 시작 전, catalog 응답 뒤, atlas 응답 뒤에
무효화 신호를 확인한다. 설치·맵·종류 변경이나 controller 종료로 요청이 오래되면
새 atlas 렌더를 시작하지 않으며, 이미 받은 atlas에서 썸네일을 복사하지 않는다.
controller도 오래된 결과를 축소/상태 반영 전에 버린다. 로더의 취소 결과는
`SC_CATALOG_OBJECT_REQUEST_CANCELLED`이며 오래된 요청의 진단은 현재 화면에
덮어쓰지 않는다.

진행 중인 외부 프로세스의 강제 종료나 Tile 요청 취소를 추가한 것은 아니다.
기존 타임아웃·프로세스 정책을 유지하며, 이 변경은 더 이상 필요한 결과가 아닌
요청의 다음 단계를 차단한다. 회귀는 시작 전 취소, catalog 대기 중 취소,
atlas 렌더 중 무효화, 설치 변경·종료 시 atlas 호출 0회를 검증한다.

검증: 전체 654개 통과·21개 선택 환경 skip, 실제 설치 관련 7개 별도 통과.
정적 분석과 Windows debug 빌드·5초 시작 스모크 통과. Flutter 3.47.2/Dart 3.13.2에서
검증했으며 기준 SDK는 미검증이다. 변경 파일 포맷은 통과했고 전체 검사에는 기존
infrastructure 테스트 4개의 포맷 차이가 남아 있다.

### 컨트롤러 종료 시 보유 참조 해제 (2026-09-18)

`PlacementCatalogController.dispose()`는 썸네일 목록·선택·최근 항목·맵 스냅샷과
설치 경로 참조를 비운 뒤 이벤트 스트림을 닫는다. 종료 뒤 설치/세션 변경과 UI
콜백은 상태를 다시 채우거나 닫힌 스트림에 이벤트를 쓰지 않는다. 대기 중인
카탈로그 응답은 기존 요청 번호 검증으로 폐기하며 반복 종료도 허용한다.

회귀 테스트는 실제 RGBA를 가진 합성 항목을 로딩·선택한 뒤 참조 목록이 비었는지,
늦은 콜백·대기 응답이 종료 상태를 유지하는지와 원본 CHK 바이트 보존을 확인한다.
이 변경은 컨트롤러가 가진 참조를 해제하는 것이며 외부에서 보관한 이전 상태나
GC/GPU의 실제 메모리 회수 시점까지 보장하지 않는다. 카탈로그 탭만 닫고 다시
여는 동안 살아 있는 컨트롤러의 페이지 보존 정책은 유지한다.

검증: 종료 관련 집중 3개, 전체 650개 통과·21개 선택 환경 skip. 정적 분석과
Windows debug 빌드·5초 시작 스모크 통과. Flutter 3.47.2/Dart 3.13.2에서 검증했고
기준 SDK·실제 GPU 메모리 회수는 미검증이다. 변경 파일 포맷은 통과했으며 전체
검사에는 기존 infrastructure 테스트 4개의 포맷 차이가 남아 있다.

### 카탈로그 객체 썸네일 상한 (2026-09-18)

`CatalogThumbnailPixels`를 객체 카탈로그 페이지 수신 시 적용해 한 장을 최대
64×64 / 16,384 bytes로 제한한다. 종횡비를 가능한 정수 크기로 유지하고 최소
축 길이는 1이다. 최근접 샘플링으로 RGBA를 함께 복사해 투명도를 유지한다.
64×64 이하 데이터는 원래 바이트를 그대로 읽기 전용으로 사용한다.
원본 atlas나 배치 metadata를 변경하지 않으며, 지도 렌더와 Settings/EUD
미리보기는 기존 전체 해상도 경로를 유지한다.

동일 실제 설치·페이지 크기 32의 재측정:

| 종류 | 보유 RGBA 이전 → 이후 | 최대 한 장 | 첫 페이지 / 전체 |
| --- | --- | --- | --- |
| Unit 228개 | 11,406,144 → 3,074,624 bytes | 16,384 bytes | 446 / 3,207ms |
| Sprite 517개 | 32,117,728 → 6,467,648 bytes | 16,384 bytes | 412 / 7,254ms |

메모리 감소는 확인했으나 로딩 시간 개선으로 해석하지 않는다. 이 상한은 보유
객체 썸네일 한 장에만 적용한다. 전체 프로세스/GPU, atlas 디코딩 중 임시 메모리,
Tile 카탈로그 전체 캐시의 상한은 아니다. 실제 계측 테스트에서 모든 객체
썸네일의 크기·바이트 상한을 검사한다. 합성 테스트는 가로/세로/정사각/1픽셀
이미지의 크기·RGBA 샘플·잘못된 입력 거부를 검증한다.

검증: 실제 설치를 포함한 집중 26개, 기본 전체 649개 통과·21개 skip.
정적 분석과 Windows debug 빌드·5초 시작 스모크 통과. Flutter 3.47.2/Dart 3.13.2로
검증했고 기준 SDK와 실제 화면 수동 조작은 미검증이다. 변경 파일 포맷은 통과했으며
전체 검사에는 기존 infrastructure 테스트 4개의 포맷 차이가 남아 있다.

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

- Windows profile 자동 하네스는 추가했다. 반복 측정과 실제 자산으로 확대해
  변동 폭과 화면 프레임 성능을 확인한다.
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
