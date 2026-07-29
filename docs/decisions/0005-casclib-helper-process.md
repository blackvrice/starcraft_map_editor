# ADR-0005: CascLib 기반 로컬 StarCraft 데이터 helper

- Status: Accepted
- Date: 2026-07-29

## Context

지형 이미지를 표시하려면 StarCraft: Remastered 설치의 8개 타일셋에서
`CV5`, `VF4`, `VX4EX`, `VR4`, `WPE` 자산 40개를 읽어야 한다. 리마스터 게임
데이터는 일반 `tileset` 폴더가 아니라 CASC 저장소에 있으므로 사용자에게
파일을 수동 추출하거나 별도 배포본을 구하게 하는 흐름은 설치 출처, 버전,
저작권과 무결성을 일관되게 검증하기 어렵다.

CASC는 신뢰 경계 밖의 복잡한 바이너리 입력이다. 네이티브 파서가 Flutter
프로세스 안에서 실패하면 열린 문서 세션도 함께 종료될 수 있다. 반면 설치
검사와 향후 자산 로딩은 명시적인 저빈도 작업이므로 프로세스 시작 비용을
허용할 수 있다.

## Decision

에디터는 사용자가 선택한 StarCraft: Remastered 설치 경로의 로컬 CASC를
CascLib으로 직접 읽는다. 게임 자산을 별도 폴더로 추출하거나 복사하지 않는다.

- CascLib 3.0의 revision
  `4971d363e665551ac4142f541e5f2d71f1cda653`을 CMake FetchContent에서
  고정하고 `casc_static`을 `starcraft_data_helper.exe`에 정적으로 링크한다.
- Flutter 앱은 CascLib을 FFI로 직접 로드하지 않는다.
  `ProcessStarCraftDataAssetInspector`가 앱 옆의 번들 helper를 요청마다 별도
  프로세스로 실행한다.
- helper 실행 파일은 사용자 입력이나 `PATH`에서 찾지 않으며 셸을 사용하지
  않는다. 요청 경로는 명령줄이 아닌 단일 UTF-8 JSON stdin 레코드로 전달한다.
- helper는 온라인 저장소 API를 사용하지 않고 선택한 로컬 설치를 읽기 전용으로
  연다. 성공 응답에는 CASC 제품 코드, 빌드 번호, found/required, 전체 읽기
  바이트, helper와 CascLib revision이 포함된다.
- 도메인 매니페스트는 SC:R의 `VX4EX`를 포함한 정확한 40개 내부 경로만
  허용한다. 각 파일은 `CASC_STRICT_DATA_CHECK`로 끝까지 읽으며 원시 바이트는
  프로세스 프로토콜이나 Dart 계층으로 전달하지 않는다.
- helper와 CascLib의 MIT 라이선스 및 고지를 Windows 배포물에 포함한다.

## 프로토콜과 안전 경계

- `protocolVersion=1`, `operation=inspectInstallation`, 고유 request ID를
  요청과 응답에서 모두 확인한다.
- 앱은 helper/CascLib 버전, 응답 설치 경로, 필수 개수와 누락·무효 경로 집합을
  자체 도메인 매니페스트와 교차 검증한다.
- 개별 자산은 최대 64 MiB, 전체 자산은 최대 256 MiB다. 프로세스 stdout과
  stderr는 각각 최대 256 KiB만 보관하고 기본 timeout은 15초다.
- 프로세스는 앱이 만든 요청별 임시 디렉터리에서 최소 환경으로 실행된다.
  timeout 또는 오류 뒤에는 해당 helper와 정확한 임시 디렉터리만 정리한다.
- 저장소 열기, 메타데이터, 누락, 읽기 실패, helper 누락·시작 실패·timeout,
  대량 출력과 손상 응답은 서로 다른 안정적인 진단 코드로 반환한다.
- helper는 CASC 저장소를 수정하거나 손상 자산을 복구하지 않는다. 앱도
  자동 다운로드를 수행하지 않으며 Battle.net Scan and Repair를 안내한다.

## Alternatives

### 사용자가 loose 파일을 준비

네이티브 의존성은 줄지만 추출 도구와 출처가 제각각이고 SC:R의 `.vx4ex` 같은
버전 차이를 앱이 확인하기 어렵다. 게임 데이터 복제와 잘못된 폴더 선택을
사용자에게 전가하므로 채택하지 않는다.

### CascLib 직접 FFI

프로세스 시작 비용과 JSON 검증은 없어지지만 네이티브 핸들, 버퍼, ABI와
크래시가 Flutter 프로세스에 들어온다. 현재 검사 빈도에서는 격리와 테스트
가능성이 더 중요하므로 채택하지 않는다.

### 기존 외부 추출 도구 실행

구현 초기 비용은 낮지만 버전, 출력 형식, 쓰기 범위, 라이선스와 자동 업데이트
동작을 통제하기 어렵다. 제한된 자체 helper가 더 작은 권한과 안정적인
프로토콜을 제공하므로 채택하지 않는다.

### 앱이 필요한 자산을 영구 캐시에 추출

후속 렌더링 성능에는 유리할 수 있으나 게임 데이터 복제, 캐시 무효화와 정리
정책이 필요하다. 현재 단계는 검사만 수행하므로 채택하지 않는다. 성능 측정으로
필요성이 확인되면 별도 ADR에서 사용자 동의와 캐시 수명 정책을 결정한다.

## Consequences

장점:

- Battle.net 설치 하나를 선택하면 추가 데이터 다운로드나 수동 추출 없이
  정확한 게임 버전의 자산을 사용할 수 있다.
- 비정상 CASC와 네이티브 라이브러리 실패가 Flutter 문서 세션과 격리된다.
- Dart 계층은 CascLib ABI가 아니라 작고 버전이 있는 검사 계약에 의존한다.
- 가짜 helper로 실패 경계를 결정적으로 테스트하고 실제 설치로 호환성을
  별도 스모크 테스트할 수 있다.

비용:

- C++ helper, 고정 네이티브 의존성, 라이선스 고지와 프로토콜 버전을 관리한다.
- 첫 CMake configure에서 CascLib 소스를 가져와야 하며 Windows 빌드 시간이
  늘어난다.
- 향후 실제 타일 렌더링은 검사와 별도의 제한된 자산 읽기 프로토콜 또는
  검증된 앱 소유 캐시 설계를 추가해야 한다.

## Validation

- 네이티브 테스트는 40개 고정 경로, 중복 없음과 잘못된 저장소 거부를 검증한다.
- Dart 프로세스 테스트는 성공, 누락·무효 자산, 저장소 오류, timeout, 대량
  출력과 손상 응답을 검증한다.
- Windows 앱 빌드는 helper와 CascLib/자체 helper 라이선스 고지를 번들한다.
- 2026-07-29 로컬 SC:R 제품 `s1`, 빌드 `13515`에서 40개 자산
  33,670,360바이트를 strict read해 누락과 무효 자산이 없음을 확인했다.

## References

- [CascLib README](https://github.com/ladislav-zezula/CascLib/blob/4971d363e665551ac4142f541e5f2d71f1cda653/README.md)
- [CascLib API header](https://github.com/ladislav-zezula/CascLib/blob/4971d363e665551ac4142f541e5f2d71f1cda653/src/CascLib.h)
- [CascLib MIT license](https://github.com/ladislav-zezula/CascLib/blob/4971d363e665551ac4142f541e5f2d71f1cda653/LICENSE)
- [Dart Process.start API](https://api.dart.dev/dart-io/Process/start.html)
