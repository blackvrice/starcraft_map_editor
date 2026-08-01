# ADR-0006: 요청별 RGBA 타일 아틀라스와 메모리 캐시

- Status: Accepted
- Date: 2026-08-01

구현 메모: protocol 2와 helper 0.2.0에서 `StarCraftTileAtlasGateway`, 고정
8×4 렌더 매니페스트와 binary envelope를 도입했다. helper 0.3.0은
`CV5`·`VX4EX`·`VR4`·`WPE` 길이와 참조를 검증하고 지원 raw의 32×32 RGBA를
envelope에 기록한다. 캔버스 연결과 메모리 캐시는 후속 단계다.

## Context

[ADR-0005](0005-casclib-helper-process.md)는 StarCraft: Remastered의 로컬
CASC를 별도 helper 프로세스에서 검사하되 원시 게임 자산 바이트를 JSON이나
Dart 계층으로 전달하지 않도록 결정했다. 이 경계는 설치 무결성 검사에는
충분하지만 실제 지형 이미지를 표시하려면 `CV5`, `VX4EX`, `VR4`, `WPE`를
해석하고 `MTXM` raw 값마다 32×32 픽셀을 만들어야 한다.

40개 자산 전체는 현재 로컬 설치에서도 30 MiB를 넘는다. 이를 JSON/base64로
보내면 프로세스 출력 상한과 메모리 복사가 커지고, loose 파일이나 영구 디스크
캐시로 추출하면 게임 데이터 복제, 수명과 무효화 정책이 생긴다. 원시 포맷
파싱을 Flutter 프로세스로 옮기면 손상된 CASC 입력의 인덱스·길이 오류가 열린
맵 문서와 UI 프로세스에 다시 들어온다.

반면 현재 지형 편집은 맵에 이미 존재하는 raw 값을 선택해 칠한다. 열린 맵의
고유 raw 값만 배치로 합성하면 전체 타일셋을 항상 변환하지 않고도 필요한
이미지를 준비할 수 있다.

## Decision

`starcraft_data_helper.exe`가 CASC 원시 자산을 읽고 검증하며, 요청된 타일을
32×32 RGBA 픽셀로 합성한다. Dart에는 원시 `CV5`·`VX4EX`·`VR4`·`WPE`
바이트가 아니라 검증 가능한 정규화 아틀라스만 전달한다.

### 포트와 프로세스 경계

- Application에는 설치 검사와 분리된 `StarCraftTileAtlasGateway` 포트를 둔다.
  UI는 파일 시스템이나 helper 프로세스를 직접 호출하지 않고 타일 이미지
  상태를 관리하는 Application 컨트롤러만 구독한다.
- 기존 `inspectInstallation`과 새 `renderTileAtlas` 작업은 같은 번들 helper를
  사용하지만 서로 다른 요청·응답 스키마를 갖는다. 구현 시 프로토콜을 2로,
  helper 버전을 0.2.0으로 올리고 두 어댑터를 한 릴리스에서 함께 이관한다.
- 각 렌더 요청은 별도 helper 프로세스와 앱 소유 임시 디렉터리를 사용한다.
  helper는 요청을 처리한 뒤 종료하며 네이티브 CASC 핸들을 세션 사이에
  유지하지 않는다.
- 요청은 tileset enum과 정렬·중복 제거된 `u16` raw 값 목록만 받는다. helper가
  고정 매니페스트에서 `CV5`, `VX4EX`, `VR4`, `WPE` 경로를 조합하므로 임의
  CASC 내부 경로는 요청할 수 없다. `VF4`는 설치 검사에는 남지만 픽셀 합성
  입력에는 포함하지 않는다.

### 배치와 출력 계약

- 한 요청은 최대 4,096개 raw 값을 받는다. 더 많은 고유 값은 Application이
  결정적인 정렬 순서로 여러 배치에 나눈다. `0x4000` 이상 값과 실제 `CV5`
  그룹 범위를 벗어난 값은 합성하지 않고 unsupported 결과로 돌려준다.
- helper는 `group = raw / 16`, `member = raw % 16`으로 `CV5` mega-tile을
  고른 뒤 `VX4EX`의 4×4 mini-tile 인덱스·수평 반전, `VR4`의 8×8 팔레트
  인덱스와 `WPE` 색상을 순서대로 검증해 premultiplied RGBA8888로 합성한다.
- 출력은 요청 임시 디렉터리의 새 `tile-atlas.rgba` 파일 하나다. 파일은 magic,
  포맷 버전, 타일 크기, 열·행·타일 수와 raw 값 엔트리 표, 연속 RGBA 픽셀을
  가진 작은 고정 binary envelope를 사용한다. 부분 파일에 쓴 뒤 성공 시에만
  최종 이름으로 바꾼다.
- JSON stdout에는 request ID, 작업, helper/CascLib revision, CASC 제품·빌드,
  tileset, 출력 파일명·크기·아틀라스 치수·타일 수와 unsupported 값만 넣는다.
  게임 자산이나 RGBA 바이트를 JSON과 로그에 포함하지 않는다.
- 앱은 helper 종료 후 응답과 binary header, 실제 파일 크기, raw 엔트리 집합,
  `width × height × 4` 픽셀 길이를 교차 검증한 뒤에만 RGBA를 채택한다.

### 캐시 수명

- 요청 임시 파일은 RGBA가 `ui.Image`로 변환되면 즉시 정리하고 실패, timeout,
  취소에서도 `finally` 경로로 삭제한다. 앱 데이터, 프로젝트, 맵 옆이나
  저장소에는 게임 자산 또는 파생 아틀라스를 영구 저장하지 않는다.
- Presentation은 `ui.Image`만 메모리 LRU에 보관한다. 기본 예산은 RGBA 기준
  128 MiB이며 퇴출, 맵 닫기와 컨트롤러 dispose에서 반드시 `Image.dispose()`를
  호출한다. 검증된 CPU RGBA 버퍼는 이미지 생성 뒤 유지하지 않는다.
- 캐시 키는 정규화한 설치 경로의 프로세스 내부 식별자, CASC 제품·빌드,
  helper/CascLib revision, tileset과 raw 값 배치로 구성한다. 설치 경로,
  검사 snapshot 또는 버전이 바뀌면 이전 엔트리를 재사용하지 않는다.
- 로드 중 다른 맵이나 설치 설정으로 전환되면 오래된 결과가 최신 상태를
  덮어쓰지 않도록 generation ID를 확인하고 결과 이미지를 즉시 폐기한다.

### 상한과 실패 격리

- stdin JSON은 기존 64 KiB 상한을 유지한다. stdout/stderr는 각각 256 KiB,
  요청 timeout은 기본 30초다.
- 아틀라스 픽셀은 요청당 최대 `4096 × 32 × 32 × 4 = 16 MiB`이며 binary
  envelope 전체는 17 MiB를 넘을 수 없다. CASC 원본의 개별 64 MiB·전체
  256 MiB strict-read 상한도 그대로 적용한다.
- 임시 출력 경로는 helper 작업 디렉터리의 직접 자식인 새 파일만 허용한다.
  절대 경로 탈출, symlink/reparse point, 기존 파일, 잘못된 header와 초과
  크기는 모두 실패한다.
- 자산 누락·손상, 인덱스 범위 오류, helper crash·timeout과 이미지 생성 실패는
  구조화된 비차단 렌더링 진단으로 변환한다. 해당 타일은 기존 raw 색상 또는
  unsupported 교차 패턴으로 표시하며 맵 편집과 Save As 성공 조건은 바꾸지
  않는다.

## Alternatives

### 원시 타일셋 파일을 임시 추출해 Dart에서 디코딩

디코더를 순수 Dart로 테스트하기 쉽지만 게임 원본 바이트가 helper 경계를
벗어나고 복잡한 포맷 파싱 실패가 Flutter 프로세스에 들어온다. 임시 파일
정리와 원본 자산 복제 범위도 커지므로 채택하지 않는다.

### binary stdout 또는 JSON/base64로 픽셀 전달

별도 파일 정리는 줄지만 구조화 응답과 대용량 binary를 한 스트림에서
구분해야 한다. base64는 크기와 복사를 늘리고 binary stdout은 현재의 단일
JSON 응답·출력 상한·가짜 helper 테스트 계약을 깨므로 채택하지 않는다.

### 전체 타일셋을 영구 디스크 캐시에 저장

두 번째 실행부터 빠르지만 설치 업데이트 감지, 최대 크기, 사용자 동의와
삭제 정책이 필요하고 파생 게임 데이터를 장기간 복제한다. 실제 계측 전에는
요청별 임시 출력과 메모리 LRU면 충분하므로 채택하지 않는다.

### CascLib FFI 또는 상시 helper 프로세스

프로세스 시작 비용은 줄지만 네이티브 ABI·크래시 또는 장수 CASC 핸들의
수명과 취소 상태가 앱 세션에 결합된다. 타일 배치 단위의 격리와 단순한 정리
계약을 우선하므로 채택하지 않는다.

## Consequences

장점:

- 원시 게임 자산과 복잡한 디코더가 Flutter 프로세스 밖에 남는다.
- 열린 맵에 필요한 타일만 최대 16 MiB 배치로 준비하고 반복 렌더링은 GPU
  이미지 캐시를 사용한다.
- 임시 출력, 메모리, 버전과 실패 범위가 명시적이며 현재 대체 표시를 그대로
  안전망으로 사용할 수 있다.

비용:

- helper protocol v2, C++ 타일 디코더, binary envelope와 Dart 검증 어댑터를
  함께 구현해야 한다.
- 최초 맵 열기에는 CASC 읽기·합성과 이미지 생성 지연이 생기며 여러 배치의
  비동기 상태와 LRU dispose를 관리해야 한다.
- helper가 만든 RGBA와 Chkdraft/게임 렌더링의 방향·팔레트 일치를 실제 설치로
  검증해야 한다.

## Validation

- 자체 생성한 최소 `CV5`·`VX4EX`·`VR4`·`WPE` 바이트로 group/member,
  mega/mini-tile 인덱스, 반전, 팔레트와 RGBA 합성을 네이티브 단위 테스트한다.
- 길이 절단, 잘못된 인덱스, 중복 raw, 4,096개 초과, 임의 tileset/path,
  기존·외부 출력 경로와 17 MiB 초과를 helper 테스트에서 거부한다.
- 가짜 helper 테스트는 protocol/version/path/header/크기/엔트리 불일치,
  timeout, 대량 출력, 취소와 임시 디렉터리 정리를 검증한다.
- Widget 테스트는 준비 중 표시, 실제 이미지 우선, 일부 배치 실패와
  unsupported fallback, 오래된 generation 무시와 LRU dispose를 검증한다.
- 재배포하지 않는 로컬 SC:R 설치 스모크에서 8개 타일셋의 대표 raw 값을
  Chkdraft 렌더링과 비교하고 256×256 맵의 초기 로드·pan·zoom frame timing과
  메모리 예산을 기록한다.

## References

- [ADR-0005](0005-casclib-helper-process.md)
- [CascLib API header](https://github.com/ladislav-zezula/CascLib/blob/4971d363e665551ac4142f541e5f2d71f1cda653/src/CascLib.h)
- [Chkdraft tile composition](https://github.com/TheNitesWhoSay/Chkdraft/blob/7ad7c28c15ab404eb6b535433f518f65a7b6e0f8/src/chkdraft/mapping/sc_gdi_graphics.cpp#L1285-L1327)
- [Flutter `decodeImageFromPixels`](https://api.flutter.dev/flutter/dart-ui/decodeImageFromPixels.html)
