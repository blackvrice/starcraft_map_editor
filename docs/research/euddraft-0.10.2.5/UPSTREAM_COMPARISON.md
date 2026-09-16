# 공식 배포본과 네이티브 파일 대조

2026-09-16. 버전 리소스 조사에 이어 Python 공식 embeddable ZIP과 eudplib
공식 PyPI wheel을 내려받아 포함 파일의 SHA-256과 크기를 비교했다.
설치·압축 해제·실행 없이 ZIP 스트림만 읽었다.

## 고정한 입력

| 아티팩트 | 크기(바이트) | SHA-256 |
| --- | --- | --- |
| euddraft0.10.2.5.zip | 15,108,674 | `87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3` |
| python-3.13.5-embed-amd64.zip | 10,903,542 | `7d2650fd9d1b9d002d4a315d5f354247fd6a44f30517c7ef577b08f57a0fb6d9` |
| eudplib-0.80.6-cp310-abi3-win_amd64.whl | 1,875,060 | `9248b4ea16b3a61cc3a559e56e0be90422c1a77c5b14006c41353bf3d684a30e` |

출처와 공개 해시 근거:

- [euddraft 릴리스 파일](https://github.com/armoha/euddraft/releases/expanded_assets/v0.10.2.5)
- [Python 3.13.5 릴리스](https://www.python.org/downloads/release/python-3135/) 및
  [해당 ZIP의 공식 SPDX](https://www.python.org/ftp/python/3.13.5/python-3.13.5-embed-amd64.zip.spdx.json)
- [eudplib 0.80.6 PyPI 메타데이터](https://pypi.org/pypi/eudplib/0.80.6/json)

각 다운로드의 로컬 해시가 위 공개값과 일치했다. 서명 검증 또는 소스 재현 빌드를
수행했다는 뜻은 아니다. 다운로드 URL, 크기, 비교한 파일의 해시는
[upstream-comparison.json](upstream-comparison.json)에 있다.

## 확인 결과

| 비교 대상 | euddraft ZIP과 동일한 파일 |
| --- | --- |
| Python 공식 ZIP | Python DLL 2개, CPython 확장 17개, OpenSSL DLL 2개, libffi DLL 1개: 총 22개 |
| eudplib 공식 wheel | `eudplib/bindings/_rust.pyd` → `lib/eudplib.bindings._rust.pyd`: 1개 |

공식 Python SPDX는 libffi 3.4.4 및 OpenSSL 3.0.16을 기록한다. 위 바이너리 대조와
합쳐 해당 배포본과의 연결 근거로 삼는다. 이 SPDX 전체를 euddraft의 구성 목록으로
복사하지 않는다. 예를 들어 Python ZIP에만 있는 sqlite 파일은 이번 일치 목록에 없다.

다음 차이도 보존했다.

- Python ZIP의 `vcruntime140.dll`, `vcruntime140_1.dll`은 euddraft의 동명 파일과 다르다.
  앞선 euddraft 리소스 값 14.44.35211.0의 출처·고지는 별도로 검토한다.
- eudplib wheel의 `eudplib/epscript/libepScriptLib.dll`은 euddraft 루트 DLL과 다르다.
  루트 DLL은 [앞선 조사](NATIVE_COMPONENTS.md)에서 euddraft 고정 태그 파일과 일치했다.
- freezeMpq의 태그/릴리스 불일치는 이번 두 배포본 비교로 해결되지 않았다.
  임의로 교체하거나 빌드 조건을 추정하지 않았다.

`identicalBundlePaths`가 빈 배열이면 해당 원본 파일과 바이트가 동일한 동봉 파일을
찾지 못했다는 뜻이다. 동명 파일의 존재 여부나 런타임 호환성을 나타내지는 않는다.
eudplib Rust 바이너리의 패키지 연결은 확인했지만 정적으로 링크된 Rust 의존성의
전체 구성·고지는 별도 확인 대상이다.

## 고지 근거와 남은 작업

공식 Python ZIP의 `LICENSE.txt`와 eudplib wheel의
`eudplib-0.80.6.dist-info/licenses/LICENSE`, `eudplib/LICENSE`를 찾았고,
위치·크기·해시를 보고서에 기록했다. Python 고지 본문과 eudplib MIT 고지의
존재를 확인했으나 전체 전이 의존성의 조건 충족 여부를 판정하지 않았다.
최종 앱 고지 묶음을 만들 때 해당 원문 및 구성요소별 조건을 함께 검토한다.

이번 도구의 고지 탐색은 basename이 LICENSE/LICENCE/COPYING인 항목으로 제한된다.
기존 `frozen_application_license.txt` 및 중첩 ZIP의 고지 등은 앞선
[audit.json](audit.json)에 있으며 이번 보고서가 기존 목록을 대체하지 않는다.
`redistributionReview`는 계속 `pending`이다.

## 재현과 테스트

PowerShell 7에서 저장소 루트를 기준으로 실행한다. 출력 경로는 새 파일이어야 한다.
입력은 다운로드해 둔 공식 파일이다. 도구는 네트워크에 접근하지 않는다.

```powershell
pwsh -NoProfile -File tool/compare_euddraft_upstream.ps1 -EuddraftZip build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip -PythonZip build/euddraft-audit-0.10.2.5/python-3.13.5-embed-amd64.zip -EudplibWheel build/euddraft-audit-0.10.2.5/eudplib-0.80.6-cp310-abi3-win_amd64.whl -OutputPath build/upstream-comparison-repeat.json
$env:EUDDRAFT_UPSTREAM_AUDIT_DIRECTORY = (Resolve-Path build/euddraft-audit-0.10.2.5).Path
flutter test test/infrastructure/euddraft_upstream_comparison_test.dart --concurrency=1
```

세 입력을 각각 고정 해시로 검사하고 쓰기 공유를 막은 동일 핸들로 대조한다.
잘못된 입력은 결과를 만들기 전에 거부한다. 기존 출력은 CreateNew로 보호한다.
테스트는 일치/불일치 자료, 입력별 변조 거부, 실제 배포본 재현, 기존 출력 보존을 확인한다.
환경 변수가 없거나 Windows가 아니면 실제 배포본 테스트를 skip한다.

## 검증 기록

2026-09-16 새 대조 테스트 3개와 정적 분석이 통과했다. 실제 세 배포본을 제공한
전체 테스트는 602개 통과·11개 skip으로 완료됐다. 전체 포맷 검사는 기존 infrastructure
테스트 4개의 형식 차이로 실패했고 해당 파일은 수정하지 않았다. 변경 테스트 포맷은 통과했다.
실행 SDK는 Flutter 3.47.2 / Dart 3.13.2로 기준 3.44.8 / 3.12와 다르다.
앱·네이티브 helper를 변경하지 않아 Windows 빌드는 반복하지 않았다. 실제 컴파일·게임·
깨끗한 PC 배포 검증도 수행하지 않았으므로 이번 결과는 X1 전체 완료가 아니다.
