# EUD 생성 빌드와 게임 검증

2026-09-26. **생성·실제 컴파일·출력 아카이브 검증 완료, 게임 관찰은 미완료**.
실제 게임 수치와 멀티플레이 동기화 결과를 자동 테스트 결과로 대신하지 않는다.

## 앱 사용

1. 맵을 저장하고 EUD Project의 설정을 편집한다. 프로젝트 저장도 권장한다.
2. Prepare EUD Build에서 원본 맵과 새로운 출력 `.scx` 경로를 지정한다.
3. 설정만 시험하면 Source folder/Entry를 비운다. 사용자 epScript를 함께 빌드하면
   저장된 entry와 source folder를 지정하고 소스 신뢰 여부를 확인한다.
4. **Include project settings in an unverified test build**를 선택하고 Prepare 후 Build한다.

생성 설정은 사용자 시작 코드보다 먼저 실행된다. 사용자 코드가 같은 값을 다시 쓰면
나중 값이 우선한다. 임의 사용자 코드의 의미 충돌은 자동으로 분석하지 않는다.
현재 실드 정책은 **타입 값만 한 번 변경**한다. 기존 유닛 실드 채우기/클램프/주기 쓰기는 없다.
프로젝트 변경·맵 변경·맵 해시 불일치가 있으면 다시 준비해야 한다. Save As는 빌드가 아니다.

Generation preview에 실제 생성 Python과 manifest가 나온다. 모든 필드는 여전히 게임
미검증 상태이며, 시험 빌드를 일반 배포용 호환성 인증으로 해석하면 안 된다.

## 재현 가능한 비교 맵

```powershell
dart run tool/build_eud_settings_validation.dart `
  build/eud_bundle/0.10.2.5-editor.1 `
  build/windows/x64/runner/Debug/map_archive_helper.exe `
  build/eud-settings-validation-20260926
```

출력 디렉터리는 새 경로여야 한다. 기존 맵을 덮어쓰지 않는다. 자체 제작 air-stat
fixture로 baseline을 만들고 다음 맵·프로젝트 JSON·생성 소스·manifest·원시 로그·
SHA-256 결과를 생성한다. 소스 트리/동봉 설치를 수정하지 않는다.

| 맵 | 목적 및 관찰 항목 |
| --- | --- |
| baseline.scx | EUD 전 원본. 기존 Wraith/Scout/Science Vessel 및 적 Overlord |
| control.scx | 설정 변경 없는 EUD 빌드 + 시작 코드로 Scout 1기 생성 |
| shield.scx | Scout 타입 실드 활성·최대 300. 위쪽 배치 Scout와 아래쪽 신규 Scout의 최대/현재 실드, 피격·재생 비교 |
| weapon.scx | Wraith 공중 무기 #15의 최대 사거리 원시값 224, 쿨다운 11, 피해 유형 Normal. control과 공격 거리·주기·피해 비교 |
| player.scx | Player 1 Terran supply maximum 원시값 600. HUD/엔진의 실제 상한 처리 관찰; 300 표시를 보장하지 않음 |
| settings-only.scx | 사용자 entry 없이 Scout 최대 실드 300만 생성. 신규 Scout 생성 없음 |

위 맵 5종(control부터 settings-only)의 실제 컴파일과 SafeEudBuildPipeline의 MPQ/CHK
재검증, 입력 맵·사용자 entry 보존은 통과했다. `results.json`의 gameObservation은 pending이다.
동일 원본의 반복 빌드, 설정 전용 빌드, 잘못된 binding 거부는
`test/integration/generated_eud_build_test.dart`에서도 실제 도구로 검사한다.

## 게임 관찰 기록 — 미완료

자동 검증 기록: analyze 통과, 전체 테스트 720개 통과·26개 skip, 실제 생성 빌드
통합 테스트 별도 통과(사용자 entry 결합 2회·설정 전용 1회·맵 해시 불일치 거부),
최종 미리보기 위젯 테스트 4개 통과, Windows Debug 빌드·시작 확인 통과.
전체 비쓰기 format은 기존 infrastructure 테스트 4개의 형식 차이로 실패했으며
이번 변경 파일은 포맷을 맞췄다. SDK는 Flutter 3.47.2 / Dart 3.13.2로 저장소 기준과
다르다. 기존 CascLib CMake 최소 버전 경고는 남아 있다.

현재 자동화에는 네이티브 게임 화면을 조작·관찰하는 수단이 없어 SC:R 수치를 확인하지
못했다. 로컬 SC:R 실행 파일 존재는 확인했지만 게임 실행·플레이·멀티플레이 성공으로
기록하지 않는다. 아래 표에 게임 build와 관찰 근거를 기록한 후 지원 상태를 승격한다.

| 사례 | 상태 |
| --- | --- |
| 기본 맵/생성 맵 실행, 배치·신규 Scout 실드 현재량/최대량 | 미관찰 |
| 실드 없는 타입 활성화, UNIT 실드 0/50/100%와 CHK 우선순위 | 추가 비교 맵·관찰 필요 |
| 피해·회복·변신/모드 전환·생산 유닛 | 추가 비교 맵·관찰 필요 |
| 무기 사거리·피해 유형·공유 무기와 업그레이드 상호 작용 | 미관찰 |
| Flingy 이동·가속/회전, 연구 metadata, Sprite/Image classic/HD | 추가 비교 맵·관찰 필요 |
| 2인 이상 멀티플레이에서 동일 결과와 desync 여부 | 미관찰 |

게임에서 이상이 확인되면 해당 조합을 제한하거나 정책을 수정한다. 특히 기존 유닛
실드 보충과 신규 생성/변신 후 초기화는 관찰 전 자동 보정 정책을 추가하지 않는다.
