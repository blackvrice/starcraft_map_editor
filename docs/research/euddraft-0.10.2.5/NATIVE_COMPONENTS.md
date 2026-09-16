# 네이티브 구성요소 버전과 출처 조사

2026-09-16 X1 후속 조사. [원본 ZIP 목록](manifest.json) 중 `.exe`, `.dll`,
`.pyd` 파일 39개를 확인했다. [native-versions.json](native-versions.json)에
경로·크기·해시와 Windows 버전 리소스의 숫자 값을 기록했다.
34개에서 버전 정보를 읽었고 5개는 `null`로 남겼다.

## 관찰한 버전

| 파일군 | 숫자 버전 리소스 | 해석 범위 |
| --- | --- | --- |
| euddraft.exe | 0.10.2.5 | VERSION 및 배포 메타데이터와 일치 |
| python3.dll, python313.dll, CPython 확장 17개 | 3.13.5150.1013 | CPython 3.13.5 final의 버전 인코딩과 일치 |
| libcrypto-3.dll, libssl-3.dll | 3.0.16.0 | OpenSSL 파일 버전 리소스 |
| VC 런타임 12개 | 14.44.35211.0 | 동일한 버전 리소스 |
| epTrace.exe, libepScriptLib.dll, lib/freezeMpq.pyd, lib/eudplib.bindings._rust.pyd, lib/libffi-8.dll | 없음 | 이름이나 동반 패키지 버전으로 추정하지 않음 |

CPython의 [v3.13.5 빌드 설정](https://github.com/python/cpython/blob/v3.13.5/PCbuild/python.props)은
세 번째 숫자를 patch×1000 + release level×10 + serial로 만든다. 따라서 5150은
5×1000 + final(15)×10 + 0에 해당한다. 이 해석은 버전 표시에 대한 것이며
공식 Python 바이너리와 바이트가 같다는 검증은 아니다.
같은 설정은 libffi 3.4.4와 OpenSSL 3.0.16을 참조하지만, 이 선언만으로
euddraft ZIP의 각 파일 출처를 확정하지 않는다.

## 공식 euddraft 태그의 파일과 비교

[v0.10.2.5 setup.py](https://github.com/armoha/euddraft/blob/v0.10.2.5/setup.py)는
cx_Freeze 패키징에 epScript DLL, epTrace, plugins, lib와 VC 런타임을 포함한다.
이 태그의 아래 파일을 별도로 내려받아 SHA-256을 대조했다. 파일은 실행하지 않았다.
태그가 가리키는 커밋은 `761d63fca7a1663eeb7ec00c581269a2a65af5c2`이며
`git ls-remote`로 확인했다. 재현 시 태그 대신 이 커밋의 파일을 사용할 수 있다.

| 태그 내 경로 | 태그 파일 SHA-256 | 배포 ZIP과 일치 |
| --- | --- | --- |
| libepScriptLib.dll | `5d990d71c6d8b3993c63432fe8ffb3fcc49a9bef55baa120996f56bf939b6d7a` | 예 |
| epTrace.exe | `f4caf56fff22c93dd5635eb941e79cd7b178b9cff6030138b2a988da696bd979` | 예 |
| lib/freezeMpq.pyd | `bd108c331d9b6ce28a7625db6fed5f40ee5c43ecdff67c23147fe659400ee255` | 아니오 |

배포 ZIP의 freezeMpq 해시는
`1ed097383fa0525d121f8fa2be38362da8db08321063520ae3c391d07891a8c7`이다.
차이의 원인은 확인하지 않았다. 태그에 있는 바이너리를 배포본 대신 사용하거나,
같은 빌드·라이선스 구성이라고 간주하지 않는다. 일치한 두 파일도 원 소스에서
재현 빌드하거나 전이 의존성 전체를 확인한 것은 아니다.

## 조사 도구와 검증 경계

```powershell
pwsh -NoProfile -File tool/audit_euddraft_native_versions.ps1 -ZipPath build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip -OutputPath build/native-versions-repeat.json
$env:EUDDRAFT_AUDIT_ZIP = (Resolve-Path build/euddraft-audit-0.10.2.5/euddraft0.10.2.5.zip).Path
flutter test test/infrastructure/euddraft_native_audit_test.dart --concurrency=1
```

Windows의 PowerShell 7이 필요하다. 입력 ZIP을 쓰기 공유 없이 연 핸들로 해시
검증하고 끝까지 같은 핸들로 읽는다. 파일별로 OS가 만든 임시 파일에 바이트를
복사해 `FileVersionInfo`로 버전 리소스만 읽고 `finally`에서 삭제한다.
ZIP 경로를 임시 경로로 사용하지 않으며 바이너리·Python을 실행하거나 import하지 않는다.
기존 출력은 거부하고 최종 기록에도 CreateNew를 사용한다. 네트워크 다운로드는 하지 않는다.

자동 테스트는 전체 바이너리 목록과 기존 manifest 해시/크기 일치, 미확인 버전 보존,
잘못된 ZIP 거부, 기존 출력 보존, 실제 ZIP 결과 재현 및 임시 파일 정리를 확인한다.
원본 ZIP이 없는 환경에서는 실제 재현 테스트만 skip한다.
버전 리소스는 서명 검증·빌드 출처 증명·라이선스 승인·실제 실행 호환성을 대신하지 않는다.

다음 작업은 위 5개 파일과 freezeMpq 차이에 대한 소스/빌드 근거 확보,
전이 의존성을 포함한 고지 조건 검토다. 앱 동봉과 production manifest 연결은 대기다.

## 검증 기록

2026-09-16 새 조사 테스트 3개, 정적 분석, 실제 ZIP 조사 테스트를 포함한 전체
테스트 599개가 통과했다(선택 스모크 11개 skip). 전체 포맷 검사는 기존 infrastructure
테스트 4개의 형식 차이로 실패했다. 새 테스트의 포맷은 통과했으며 기존 파일은 변경하지 않았다.
실행 SDK는 Flutter 3.47.2 / Dart 3.13.2로 기준 3.44.8 / 3.12와 다르다.
앱·네이티브 helper 변경이 없으므로 Windows 빌드는 반복하지 않았다.
euddraft 실행·실제 게임·깨끗한 PC 배포 검증은 수행하지 않았으며 호환성은 미확인이다.
