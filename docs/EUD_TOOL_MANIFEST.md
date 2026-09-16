# 동봉 EUD 도구 manifest와 무결성 검사

2026-09-16 X1 첫 구현. 관련: [확장 계획](EUD_TOOLCHAIN_LANGUAGE_PLAN.md).
실제 도구 ZIP 또는 실행 파일을 저장소/앱에 추가하지 않았다. 앱 bootstrap의 동봉 경로와
신뢰 manifest 주입, 도구 선택 UI 및 실제 배포 검증은 후속 작업이다.

## 1. 배포 메타데이터 조사

확인 출처는 [공식 v0.10.2.5 릴리스](https://github.com/armoha/euddraft/releases/tag/v0.10.2.5),
[릴리스 assets](https://github.com/armoha/euddraft/releases/expanded_assets/v0.10.2.5),
[태그의 pyproject](https://github.com/armoha/euddraft/blob/v0.10.2.5/pyproject.toml)이다.

- ZIP 이름: `euddraft0.10.2.5.zip`, 표시 크기 14.4 MB.
- 공개 SHA-256: `87113da1cf8ad48c7ed81ee26a9db47ae236274d74e8f0f24addf0e2ab8280b3`.
- 릴리스 노트는 Python 3.13.5 업데이트를 명시한다.
- 태그 메타데이터는 eudplib `>=0.80.6,<0.81` 및 cx-Freeze/rich/openpyxl/
  typing_extensions 의존성을 선언한다. 이는 실제 ZIP의 확정 구성 목록이 아니다.

2026-09-16 후속 조사에서 공식 ZIP 15,108,674바이트를 내려받아 위 해시와 일치함을
확인했다. [배포물 조사 기록](research/euddraft-0.10.2.5/README.md)에 파일 77개의
해시·크기, Python 배포 메타데이터 12개와 고지 파일 13개의 위치를 남겼다.
이는 조사용 manifest이며 production 신뢰 목록으로 주입하지 않았다. 네이티브 구성요소의
정확한 버전·출처 및 전체 재배포 조건은 추가 검토가 필요하다.

## 2. manifest v1

`EudToolManifest`는 순수 도메인 모델이다. JSON 필드는 `format`, `schemaVersion`,
`version`, `artifactSha256`, `sourceUrl`, `files`이며 format은
`starcraft-map-editor-eud-tool`, schemaVersion은 정수 1이다. files는 상대 경로를 키로
`size`와 `sha256`를 저장한다. encode는 경로 정렬로 결정적이다.

- euddraft 네 자리 버전, HTTPS 출처, 소문자 64자리 SHA-256을 검사한다.
- euddraft.exe, VERSION, license.txt 필수 항목과 최대 4096개 파일을 검사한다.
- 상대 경로는 `/` 구분 ASCII 이름으로 제한한다. 절대 경로, `..`, 백슬래시,
  스트림 구문, 예약 장치 이름, 끝 점/공백, 대소문자 중복 및 파일/디렉터리 충돌을 거부한다.
- JSON 2 MiB 문자 상한, 파일별 2 GiB, 전체 파일 크기 4 GiB 상한을 둔다.
- 알 수 없는 schema/속성/잘못된 자료형을 거부한다. 모델은 불변이다.

이는 앱이 신뢰해서 주입하는 기대 목록이다. 도구 폴더에서 읽은 자기 서명 없는
manifest를 검증 기준으로 신뢰하지 않는다. `artifactSha256`는 출처 기록이며 현재
설치 디렉터리 검사에서 원본 ZIP까지 검증하는 것은 아니다. 실제 아티팩트 검증은
패키징 단계에서 추가한다. 런타임 호환성이나 전체 재배포 승인을 나타내는 모델도 아니다.

## 3. 선택 및 검사 경계

기존 선택 순서인 프로젝트 경로 → 사용자 경로 → 동봉 경로를 유지한다. 상위 경로가
유효하지 않아도 하위 경로로 자동 전환하지 않는다. 외부 도구는 기존 검사 경로를 유지한다.

동봉 후보는 기존 버전 allowlist·필수 동반 파일 검사에 더해 앱의 `bundledManifest`가
필요하다. 없으면 `EUD_TOOL_BUNDLE_MANIFEST_MISSING`으로 차단한다. manifest와 VERSION이
다르거나 파일 크기/해시/목록이 다르면 `EUD_TOOL_BUNDLE_INTEGRITY_FAILED`를 반환한다.
진단에는 해당 설치 경로와 파일별 실패 이유를 보존한다. 현재 호환 프로필은 기존
Windows/SC:R allowlist이며 새 버전을 자동 허용하지 않는다.

`LocalEudBundleVerifier`는 도구를 실행하지 않고 모든 목록 파일의 크기와 SHA-256을
대조한다. 추가 파일과 누락 파일, 링크, 잘못된 상대 경로를 거부한다. 각 파일 읽기는
예상 크기+1바이트로 제한하고 전후 크기/수정 시각도 비교한다. 디렉터리는 4096개로 제한한다.
이 검사는 실행 직전의 원자적 잠금이나 코드 실행 샌드박스가 아니며 검사 이후 변조를
완전히 방지하지 않는다. 빌드 직전 재검사에도 동봉/사용자/프로젝트의 원래 선택 출처를 전달하여 동봉 검사가 빠지지 않도록 했다. 검사 취소/시간 예산과
설치 폴더 권한·배포 신뢰 경계는 실제 동봉 연결 시 추가 검증한다.

## 4. 후속 작업

1. ZIP 조사 자료를 바탕으로 네이티브 구성요소·플러그인의 출처 및 전체 고지 조건 검토.
2. 검토된 패키지에서 production manifest를 만들고 앱 리소스로 제공하는 신뢰 경로 확정.
3. 동봉/외부 선택 UI, 손상 복구 안내, manifest를 사용하는 bootstrap/빌드 경로 연결.
4. 읽기 전용 설치 디렉터리·오프라인·깨끗한 Windows 및 실제 euddraft 스모크 검증.

테스트는 직접 만든 실행 불가능한 파일들로 진행한다. 파일 검사 통과를 실제 컴파일이나
게임 적용 성공으로 표시하지 않는다.

## 5. 검증 기록

추가 테스트 7개를 포함하여 전체 593개 통과·11개 선택 스모크 skip, analyze 통과.
왕복·결정성·경로 탈출/충돌·잘못된 schema, 동봉 목록 부재, 정상 파일 대조,
동일 크기 변조·추가·누락·버전 불일치 및 빌드 재검사의 동봉 출처 유지/컴파일 차단을
확인했다. 실제 euddraft 설치 환경 변수가 없어 실제 설치/컴파일 스모크는 실행하지 않았다.
UI·네이티브 변경이 없어 Windows 빌드/실행은 반복하지 않았다. 변경한 8개 Dart 파일의
포맷은 통과했으며 전체 비쓰기 포맷 검사는 기존 infrastructure 테스트 4개에서 실패했다.
해당 파일들은 수정하지 않았다. SDK는 Flutter 3.47.2 / Dart 3.13.2로 저장소 기준과 다르다.
