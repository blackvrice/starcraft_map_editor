# 한영 번역

2026-10-03 남은 번역 개발 완료. 언어 선택·저장·시스템 언어 대체 규칙은
[ADR-0013](decisions/0013-localized-editor-ui.md)을 따른다.

## 지원 범위

- Map/Unit/Player/Force/Tech/Upgrade/Availability 설정, 유닛 참조/무기 영향,
  StarCraft 데이터·EUD 도구·빌드 준비 화면.
- Resources의 문자열·사운드·참조·검증, 브리핑 액션 속성, epScript 상태/작업 문구.
- 앱이 생성한 CHK·파일·도구 검사·저장/빌드 진단과 다음 행동 안내.
  원문 메시지, 진단 코드, 위치와 rawDetails는 모델에 유지한다.

기본 게임 이름, 맵/세력/유닛 등의 사용자 문자열, 파일 경로, epScript 코드,
외부 도구 로그와 컴파일러 소스 오류는 번역 대상이 아니다. 알 수 없는 메시지는
추측하지 않고 원문을 표시한다. 번역은 저장 바이트나 외부 도구 실행 계약을 바꾸지 않는다.

## 유지보수 계약

UI 문구는 `lib/l10n/app_en.arb`와 `app_ko.arb`에 함께 추가한다. 새 구조화 진단은
`EditorDiagnostic.messageId`와 문자열 인자, 필요하면 remediation ID/인자를 함께
제공한다. Flutter/로캘 의존성은 presentation에만 둔다. ID/인자 해석 실패는 원문으로
대체한다. 기존 편집기 소유 라벨·검증 문자열은 ARB에서 생성한 전체 문자열 매칭
어댑터로 표시하며 사용자 콘텐츠나 rawDetails에 적용하지 않는다.

설정의 Undo/Redo·Cancel 구분은 안정 Key를 사용한다. 언어 변경으로 초안을 다시
초기화하지 않는다. epScript의 긴 경로는 폭이 제한된 줄임표와 전체 경로 툴팁을 사용한다.

```powershell
flutter gen-l10n
dart run tool/generate_editor_messages.dart
dart format lib/l10n lib/presentation/localization/editor_messages.g.dart
flutter test test/widget/editor_translation_test.dart
```

생성 파일도 함께 커밋한다. 새 의존성은 추가하지 않는다.

## Windows 검증

`test/widget/editor_translation_test.dart`의 17개 테스트가 양언어 ID/인자,
영문 기존 출력, 알 수 없는 ID 대체, CHK 진단, 원문 코드/로그 보존,
11개 한국어 화면, 언어 전환 중 플레이어 초안·Undo, 긴 소스 경로를 검사한다.

Windows 엔진의 실제 폰트 렌더링은 자체 제작 맵과 가짜 도구 검사 결과만 사용하는
`tool/localization_windows_smoke.dart`로 재현한다. SC:R 자산을 포함하지 않는다.

```powershell
flutter build windows --debug --target tool/localization_windows_smoke.dart
$app = Start-Process -FilePath build/windows/x64/runner/Debug/starcraft_map_editor.exe `
  -WorkingDirectory (Get-Location).Path -WindowStyle Hidden -PassThru
$app.WaitForExit(60000)
$app.ExitCode
# 스모크 실행 파일을 일반 앱으로 되돌린다.
flutter build windows --debug --target lib/main.dart
```

스크린샷은 `.dart_tool/localization_windows_smoke/`에 600/1000 × 900 크기로 남는다.
11개 화면의 22 PNG를 생성했고 종료 코드 0, `render_errors.txt`가 비어 있음을 확인했다.
설정·리소스·브리핑·도구·소스 화면에서 실제 한글 글꼴과 줄바꿈을 확인했다.

Flutter 3.47.5/Dart 3.13.4 Windows에서 analyze 무이슈, 전체 테스트 943개 통과와
환경 조건부 45개 skip. helper/동봉 도구 경로를 지정한 실제 MPQ 설정 저장 왕복과
euddraft 빌드 통합 테스트 4개, 네이티브 CTest 7개도 통과했다. 처음 EUD 스모크는
버전 상위 폴더를 지정해 설치 검사가 실패했으며 `0.10.2.5-editor.1` 폴더로 재검증했다.
일반 `lib/main.dart` Windows debug 빌드와 실행도 확인했다.
전체 포맷 게이트는 변경 전부터 SDK 포맷 차이가 있는
`local_map_save_file_gateway_test.dart`, `process_eud_compiler_gateway_test.dart`,
`process_map_archive_gateway_test.dart` 3개 때문에 실패했다. 변경 파일은 포맷했다.
기준 SDK 3.44.8/Dart 3.12 재검증은 미실행이며 CI에서 확인해야 한다.
접근성·고대비, 실제 게임·배포 인수는 이 번역 검증으로 완료 표시하지 않는다.
