# 앱 동봉 EUD 도구 — 0.10.2.5-editor.1

2026-09-25. Windows 앱 빌드는 관리형 euddraft를 실행 파일 옆
`tools/euddraft/0.10.2.5-editor.1/`에 포함한다. 별도 Python/euddraft 설치나 PATH
설정 없이 기존 epScript 빌드를 실행한다. [ADR-0011](decisions/0011-managed-euddraft-bundle.md).

## 사용

1. `File → EUD Tools… → Use app default`로 동봉 도구를 선택한다.
2. 검사 성공 뒤 `Prepare EUD Build`에서 저장된 원본 맵·epScript·새 출력 경로를 선택한다.
3. 소스 실행 신뢰를 확인하고 준비한 빌드를 실행한다.

저장된 외부 설치 선택은 유지한다. 프로젝트 override → 사용자 외부 선택 → 동봉 순이며,
상위 선택이 잘못돼도 자동 fallback하지 않는다. 손상된 동봉 도구는 파일별 진단으로
차단한다. 정상 앱 패키지를 새 디렉터리에 설치하거나 외부 설치를 명시적으로 선택한다.
앱이 설치 폴더에 다운로드·수리·업데이트를 실행하지 않는다.

이 변경은 도구 공급이다. Save As가 컴파일하거나 후보 EUD 설정 5개를 적용하는
기능은 아니다. 선언적 설정 소스 생성·실드 초기화는 X2에 남는다.

## 재현과 신뢰 경계

- `tool/prepare_eud_bundle.ps1`은 공식 ZIP SHA-256과 경로 탈출을 검사한다.
- 최초 앱 빌드 때만 다운로드한다. 사전 공급 ZIP은 `-ArchivePath`로 지정한다.
- 원본 파일 77개 중 `lib/library.zip`만 재구성한다. `autoupdate.pyc`를 제거하고
  저장소의 읽을 수 있는 `autoupdate.py`를 넣는다. 함수는 안내 출력 후 반환한다.
  네트워크·thread·종료 hook·설치 쓰기가 없으며 checkpoint 우회를 사용하지 않는다.
- 다른 ZIP 내부 항목은 원본 바이트를 보존한다. 압축 없이 고정 시각으로 재포장한다.
- 고지를 보완한 최종 86개 파일의 크기·SHA-256을 검사한다. 기대 manifest는 Dart
  코드에 포함되므로 도구 폴더의 자체 manifest를 신뢰하지 않는다.
- `-WriteInventory`는 검토용 재생성 옵션이다. 정상 CMake/CI에서는 사용하지 않는다.
  목록 변경은 JSON과 Dart 신뢰 목록을 함께 검토·커밋한다.
- PowerShell 7(`pwsh`)은 앱 빌드 머신에 필요하며 실행 사용자에게는 필요하지 않다.

```powershell
pwsh -NoProfile -File tool/prepare_eud_bundle.ps1 `
  -ArchivePath C:\Downloads\euddraft0.10.2.5.zip `
  -OutputDirectory build/eud_bundle/0.10.2.5-editor.1
flutter build windows --debug
```

기존 패키지가 기대 목록과 다르면 덮어쓰지 않고 실패한다. 개발 시 손상된 build 출력은
별도로 보관/제거하고 재생성한다. 외부 설치에는 이 변환을 적용하지 않는다.
앱은 설치 디렉터리를 읽기만 하며 빌드 중간 출력은 기존 사용자 작업 공간을 사용한다.
플러그인은 임의 실행 코드이고 프로세스 분리는 보안 sandbox가 아니다.

## 구성·고지

원래 euddraft/cx_Freeze/부속 고지를 유지한다. Python, eudplib, Pygments, OpenSSL,
libffi, StormLib와 공식 eudplib 소스 Cargo.lock의 65개 registry 의존성 고지 superset을
추가했다. [SOURCES.md](../tool/eud_bundle/licenses/SOURCES.md)에 출처를 기록하고
`editor-licenses/`에 동봉한다. 원본·추가 고지의 원문을 보존한다.

사용자가 Visual Studio Community 사용을 확인했다. 로컬 Community의 정식 redist와
euddraft 루트 VC DLL 10개의 SHA-256이 일치했다. Microsoft 조건은 배포자에게 적용되며,
에디션 확인으로 모든 조직 사용 조건을 추정하지 않는다. freezeMpq는 공식 ZIP의
바이너리를 유지한다. 태그 바이너리와의 차이는 유효한 관찰이며 native 소스 재현 빌드와
전체 전이 의존성의 바이너리 attestation을 주장하지 않는다.

## 검증과 남은 인수

- 앱에 복사된 도구로 실제 epScript 컴파일 → MPQ/CHK 재열기 → 새 출력 승격 통과.
- compiler PATH를 비우고 Python 환경을 전달하지 않은 실행 통과.
- 실행 전후 설치 전체 목록·SHA-256 불변성과 관리형 updater 실행 로그 확인.
- 실제 대기 플러그인의 취소·시간 제한 종료, 출력 미생성, 종료 후 무결성 통과.
- 재생성 동일성, 잘못된 ZIP, 동일 크기 변조·추가 파일 거부 및 기본/외부 선택 UI 검증.
- CI에 패키지와 실제 빌드/종료 스모크를 추가했다. 원격 CI 결과는 별도 확인한다.

개발 PC 검증을 깨끗한 Windows/네트워크 차단 VM 검증으로 대체하지 않는다.
현재 환경에는 Windows Sandbox 실행기가 없어 해당 인수는 남긴다. 읽기 전용 ACL을
강제한 설치, 차단망, 별도 Python/Visual Studio 없는 새 Windows에서 위 흐름을 검증한
뒤 X1 전체를 닫는다. SC:R 게임 적용은 X2의 별도 범위다.

## 통합 게이트 (2026-09-25)

정적 분석 오류 없음. 전체 테스트 704 통과·환경 의존 24 skip. 별도 동봉 집중 검증은
실제 빌드/취소/시간 제한을 포함해 12 통과했다. Windows Debug 빌드와 앱 5초 시작
스모크 통과. 최종 패키지는 86개 파일, 37,874,621바이트다.

전체 비쓰기 포맷 검사는 기존 infrastructure 테스트 4개 차이로 실패했고 해당 파일은
수정하지 않았다. 변경 파일은 포맷 통과. Flutter 3.47.2 / Dart 3.13.2에서 실행했으며
기준 3.44.8 / 3.12 재검증과 원격 CI 결과는 이 로컬 결과에 포함하지 않는다.
