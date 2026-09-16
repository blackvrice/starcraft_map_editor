# euddraft 0.10.2.5 배포물 조사

2026-09-16 X1 조사. 공식 ZIP을 읽어 파일과 메타데이터를 확인했다.
압축을 풀거나 포함된 실행 파일·Python 코드·플러그인을 실행하지 않았다.
이 디렉터리는 조사 증거이며 앱 리소스나 production 신뢰 목록이 아니다.

후속 [네이티브 구성요소 조사](NATIVE_COMPONENTS.md)는 파일 39개를 개별 임시 파일에
복사해 버전 리소스를 읽은 후 삭제했다. 후속 조사에서도 패키지 코드는 실행하지 않았다.

## 확인한 아티팩트

- [공식 ZIP](https://github.com/armoha/euddraft/releases/download/v0.10.2.5/euddraft0.10.2.5.zip)
- [공개 해시](https://github.com/armoha/euddraft/releases/expanded_assets/v0.10.2.5)
- SHA-256: `87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3`
- 다운로드 크기: 15,108,674바이트. 로컬 바이트의 해시와 공개 해시가 일치했다.
- 파일 77개, 압축 해제 크기 합계 28,588,887바이트. VERSION은 `0.10.2.5`.
- `lib/library.zip` 내부 항목 1,382개. 내부 파일은 별도로 추출하지 않았다.

[manifest.json](manifest.json)은 바깥 ZIP 파일별 크기와 SHA-256을 기록하며
기존 `EudToolManifest` v1 계약으로 읽을 수 있다. [audit.json](audit.json)은
Python 배포 메타데이터와 고지 위치·해시를 기록한다. 원본 ZIP과 바이너리는
저장소에 포함하지 않고 로컬의 무시되는 `build/` 아래에 보관했다.

## Python 배포 메타데이터

아래 값은 중첩 ZIP의 `.dist-info/METADATA`에서 읽은 Name/Version 및
License/License-Expression 헤더다. 라이선스 전체 내용이나 재배포 승인 판정이 아니다.
빈 헤더는 라이선스가 없다는 의미가 아니다.

| 구성요소 | 버전 | 기록된 라이선스 헤더 |
| --- | --- | --- |
| cx_Freeze | 8.3.0 | PSF-2.0 |
| et_xmlfile | 2.0.0 | MIT |
| euddraft | 0.10.2.5 | MIT |
| eudplib | 0.80.6 | MIT |
| importlib_metadata | 8.0.0 | 없음 |
| markdown-it-py | 3.0.0 | 없음 |
| mdurl | 0.1.2 | 없음 |
| openpyxl | 3.1.5 | MIT |
| Pygments | 2.19.2 | BSD-2-Clause |
| rich | 13.9.4 | MIT |
| typing_extensions | 4.14.1 | PSF-2.0 |
| zipp | 3.19.2 | 없음 |

Python 3.13.5는 [릴리스 노트](https://github.com/armoha/euddraft/releases/tag/v0.10.2.5)의
설명이다. 후속 버전 리소스 조사에서 `python313.dll`의 숫자 버전이 3.13.5 final의
인코딩과 일치함을 확인했다. 공식 Python 바이너리와 동일한 빌드인지는 미확인이다.

## 고지와 미완료 검토

파일명 기반으로 고지 파일 13개를 찾았다. 바깥 ZIP의 `license.txt`,
`frozen_application_license.txt`, VC 재배포 고지 2개와 중첩 ZIP의 고지 9개다.
정확한 위치와 해시는 audit.json에 있다. 이 탐색은 소스 주석·메타데이터 본문·
다른 이름의 문서에 포함된 고지를 모두 찾는 완전한 라이선스 분석이 아니다.

아래 항목을 확인하기 전 `redistributionReview`는 `pending`으로 유지한다.

- Python 표준 라이브러리, eudplib 및 Rust 확장, epScript, freezeMpq 등의 출처·고지.
- `libcrypto-3.dll`, `libssl-3.dll`, `libffi-8.dll` 및 VC 런타임의 정확한 버전·조건.
- epTrace와 관련 BlackBone 고지 및 포함된 각 플러그인의 조건.
- Pygments·typing_extensions 등 메타데이터와 실제 포함 고지의 대응 관계.
- 최종 동봉 범위에 맞춘 사용자 제공 고지 문서와 production manifest 검토.

원본에는 플러그인 및 여러 Python 버전의 `__pycache__` 파일도 포함되어 있다.
이번 목록은 이를 제거하지 않은 원본 전체 기준이다. 패키지 구성을 바꾸면 새 목록과
해시를 생성해야 한다. 실제 동봉 시 읽기 전용 설치 위치에 캐시가 새로 생기지 않도록
실행 환경을 정하고, 추가 파일을 거부하는 무결성 검사와 함께 검증해야 한다.

## 재현

저장소 루트에서 PowerShell 7로 실행한다. 출력 디렉터리는 존재하지 않아야 한다.

```powershell
pwsh -NoProfile -File tool/audit_euddraft_package.ps1 -ZipPath build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip -OutputDirectory build/euddraft-audit-repeat
$env:EUDDRAFT_AUDIT_ZIP = (Resolve-Path build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip).Path
flutter test test/infrastructure/euddraft_package_audit_test.dart --concurrency=1
```

도구는 고정된 공개 해시와 다르면 출력을 만들지 않는다. 출력에는 시간·로컬 경로를
넣지 않으며 기존 출력 디렉터리 덮어쓰기를 거부한다. 테스트는 manifest 계약,
해시 불일치 시 출력 없음, 실제 ZIP 재생성 결과 일치와 덮어쓰기 거부를 확인한다.
실제 ZIP 테스트는 Windows에서 환경 변수가 설정된 경우에만 실행한다.

실제 컴파일·게임 실행·깨끗한 PC 배포 검증은 이번 조사에 포함하지 않았다.

## 검증 기록

2026-09-16 실제 ZIP을 포함한 조사 테스트 3개와 정적 분석이 통과했다.
전체 테스트는 첫 실행에서 Flutter 내부 JIT 컴파일러가 위젯 테스트 도중 종료됐고,
동일 조건 재실행에서 596개 통과·11개 skip으로 완료됐다.
변경 테스트 파일의 포맷은 통과했다. 전체 비쓰기 포맷 검사는 기존 infrastructure
테스트 4개의 형식 차이로 실패했으며 해당 파일은 수정하지 않았다.
실행 SDK는 Flutter 3.47.2 / Dart 3.13.2로 기준 3.44.8 / 3.12와 다르다.
앱·네이티브 코드 변경이 없어 Windows 빌드는 반복하지 않았다. 실제 euddraft 실행과
게임·배포 호환성은 이번 테스트 결과로 보장하지 않는다.
